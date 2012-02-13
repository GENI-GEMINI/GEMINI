#!/usr/bin/perl -w
# ex: set tabstop=4 ai expandtab softtabstop=4 shiftwidth=4:
# -*- mode: c-basic-indent: 4; tab-width: 4; indent-tabs-mode: nil -*-

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

bwcollector.pl - program that collects BWCTL data

=head1 DESCRIPTION

bwcollector.pl is a daemon process that listens on a socket and accepts
connections from powmaster.pl. powmaster sends throughput session data.
bwcollector.pl summarizes the throughput sessions and inserts the summaries into
an SQL database using the DBI interface. It also saves the session file
in an "archive" directory.

=head1 SYNOPSIS

bwcollector.pl [B<-a> add_this_file][B<-o>][B<-c> confdir/][B<-Z>][B<-k>][B<-h>][B<-p>][B<-d>][B<-v>]

=over

=item B<-a> add_this_file

Take the single owp file specified on the command line and add it into
the database.

=item B<-o>

Only accept a single connection from powmaster, and exit after the first
owp file is submitted to the database. (Useful for debugging.)

=item B<-c> confdir

Specify the directory to find the owmesh.conf file.

=item B<-Z>

Run bwcollector.pl in the foreground.

=item B<-k>

Send a SIGTERM to a currently running bwcollector.pl. i.e. Gracefully
shutdown.

=item B<-h>

Send a SIGHUP to a currently running bwcollector.pl. This causes any current
connections to be closed, and the owmesh.conf file to be re-read before
bwcollector.pl continues.

=item B<-p>

Debugging option to profile performance.

=item B<-d>

Print debugging messages. 

=item B<-v>

Print verbose messages.

=back

=cut

use Carp qw(cluck);
use FindBin;

my @SAVEARGV = @ARGV;

# BEGIN FIXMORE HACK - DO NOT EDIT
# %amidefaults is initialized by fixmore MakeMaker hack
my %amidefaults;

BEGIN {
    %amidefaults = (
        CONFDIR => "$FindBin::Bin/../etc",
        LIBDIR  => "$FindBin::Bin/../lib",
    );
}

# END FIXMORE HACK - DO NOT EDIT

# Set script as process name (unneeded on some OS's, but shouldn't hurt)
my $scriptname = "$0";
$0 = "$scriptname:master";

use lib ( $amidefaults{'LIBDIR'} );
use Getopt::Std;
use Socket;
use POSIX;
use File::Path;
use Digest::MD5;
use OWP;
use OWP::Syslog;
use OWP::RawIO;
use OWP::Archive;
use OWP::Utils;
use OWP::Helper;
use Sys::Syslog;
use File::Basename;
use File::Temp qw(tempfile);
use Fcntl ':flock';
use FileHandle;
use IO::Socket;
use DB_File;
use DBI;
use Math::Int64 qw(uint64);

my %options = (
    ADDFILE    => "a:",
    ONEREQ     => "o",
    CONFDIR    => "c:",
    FOREGROUND => "Z",
    KILL       => "k",
    HUP        => "h",
    PROFILE    => "p",
    DEBUG      => "d",
    VERBOSE    => "v"
);

my %optnames;
foreach ( keys %options ) {
    my $key = substr( $options{$_}, 0, 1 );
    $optnames{$key} = $_;
}
my $options = join '', values %options;
my %setopts;
getopts( $options, \%setopts );
foreach ( keys %optnames ) {
    $amidefaults{ $optnames{$_} } = $setopts{$_} if ( defined( $setopts{$_} ) );
}

# Don't daemonize any re-exec'd children
push @SAVEARGV, "-Z" if ( !defined( $setopts{'Z'} ) );

# Fetch configuration options.
my $conf = new OWP::Conf( %amidefaults );

#
# data path information
#
my $ttype   = 'BW';
my $datadir = $conf->must_get_val( ATTR => 'CentralDataDir', TYPE => $ttype );
my $archdir = $conf->must_get_val( ATTR => 'CentralArchDir', TYPE => $ttype );

my $facility = $conf->must_get_val( ATTR => 'SyslogFacility', TYPE => $ttype );
my $profile = $conf->get_val( ATTR => 'PROFILE', TYPE => $ttype );

#
# Send current running process a signal.
#
my $kill = $conf->get_val( ATTR => 'KILL' );
my $hup  = $conf->get_val( ATTR => 'HUP' );
if ( $kill || $hup ) {
    my $pidfile = new FileHandle "$datadir/bwcollector.pid", O_RDONLY;
    die "Unable to open($datadir/bwcollector.pid): $!"
        unless ( $pidfile );

    my $pid = <$pidfile>;
    die "Unable to retrieve PID from $datadir/bwcollector.pid"
        if !defined( $pid );
    chomp $pid;
    my $sig = ( $kill ) ? 'TERM' : 'HUP';
    if ( kill( $sig, $pid ) ) {
        warn "Sent $sig to $pid\n";
        exit( 0 );
    }
    die "Unable to send $sig to $pid: $!";
}

# Set uid to lesser permissions immediately if we are running as root.
setids(
    USER  => $conf->get_val( ATTR => 'UserName',  TYPE => $ttype ) || undef,
    GROUP => $conf->get_val( ATTR => 'GroupName', TYPE => $ttype ) || undef
);

local ( *MYLOG );

# setup syslog
my $slog = tie(
    *MYLOG, 'OWP::Syslog',
    facility   => $conf->must_get_val( ATTR => 'SyslogFacility', TYPE => $ttype ),
    log_opts   => 'pid',
    setlogsock => 'unix'
);

# make die/warn goto syslog, and also to STDERR.
$slog->HandleDieWarn( *STDERR );

# Don't need the ref anymore, and untie won't work if I keep the ref.
undef $slog;

#
# Globals...
#
my $debug   = $conf->get_val( ATTR => 'DEBUG',   TYPE => $ttype );
my $verbose = $conf->get_val( ATTR => 'VERBOSE', TYPE => $ttype );
my $sessionsuffix = $conf->must_get_val( ATTR => 'SessionSuffix', TYPE => $ttype );

#
# Initialize list of nodes (Only needed to implement debugging/peer validation)
#
my @nodes = $conf->must_get_sublist( LIST => 'NODE' );
my %ignore_node;
my @ignodes = $conf->get_sublist( LIST => 'NODE', ATTR => 'IGNORE' );
my %ignodename;

my $node;
foreach $node ( @ignodes ) {
    my $naddr = $conf->get_val( NODE => $node, ATTR => 'CONTACTADDR', TYPE => $ttype );
    if ( !$naddr ) {
        $naddr = $conf->get_val( NODE => $node, ATTR => 'ADDR', TYPE => $ttype );
    }
    if ( $naddr ) {
        $ignore_node{$naddr} = $node;
        $ignodename{$node}   = $naddr;
    }
    else {
        warn "Unable to fetch addr for $node";
    }
}

#
# Complete list of contact addresses for nodes. Only accept data
# from these addresses - if VerifyPeerAddr is set.
my %listen_nodes;
my %listen_addrs;
my $verify_addrs = $conf->get_val( ATTR => 'VERIFYPEERADDR', TYPE => $ttype );
foreach $node ( @nodes ) {
    my $naddr = $conf->get_val( NODE => $node, ATTR => 'CONTACTADDR', TYPE => $ttype );
    if ( !$naddr ) {
        $naddr = $conf->get_val( NODE => $node, ATTR => 'ADDR', TYPE => $ttype );
    }
    if ( $naddr ) {
        $listen_nodes{$naddr} = $node;
        $listen_addrs{$node}  = $naddr;
    }
    else {
        warn "Unable to fetch CONTACTADDR for $node";
        if ( $verify_addrs ) {
            warn "Unable to accept data from $node";
        }
    }
}

my @dbgnodes = $conf->get_sublist( LIST => 'NODE', ATTR => 'DEBUG' );
my %debug_node;

foreach $node ( @dbgnodes ) {
    my $naddr = $conf->get_val( NODE => $node, ATTR => 'CONTACTADDR', TYPE => $ttype );
    if ( !$naddr ) {
        $naddr = $conf->get_val( NODE => $node, ATTR => 'ADDR', TYPE => $ttype );
    }
    if ( $naddr ) {
        $debug_node{$naddr} = $node;
    }
    else {
        warn "Unable to fetch addr for $node";
    }
}

# XXX: Add back in eventually?
#
# archive setup
#
#my $archive = OWP::Archive->new(
#    DATADIR => $datadir,
#    ARCHDIR => $archdir,
#    SUFFIX  => $sessionsuffix
#);
my $archive = undef;

#
# deamon values
#
my $foreground = $conf->get_val( ATTR => 'FOREGROUND' );
my $full_central_host = $conf->must_get_val(
    ATTR => 'CentralHost',
    TYPE => $ttype
);
my ( $serverhost, $serverport ) = split_addr( $full_central_host );
die "Invalid CentralHost value: $full_central_host" if !defined( $serverport );

my $timeout = $conf->must_get_val( ATTR => 'CentralHostTimeout', TYPE => $ttype );
my $onereq = $conf->get_val( 'ATTR' => 'ONEREQ' );

#
# database values
#
my $dbuser   = $conf->must_get_val( ATTR => 'CentralDBUser', TYPE => $ttype );
my $dbpass   = $conf->must_get_val( ATTR => 'CentralDBPass', TYPE => $ttype );
my $dbsource = $conf->must_get_val( ATTR => 'CentralDBType', TYPE => $ttype ) . ":" . $conf->must_get_val( ATTR => 'CentralDBName', TYPE => $ttype );
my $dbhost = $conf->get_val( ATTR => 'CentralDBHost', TYPE => $ttype ) || "localhost";
$dbsource .= ":" . $dbhost;

# globals used by "both" update and handle_req processes

sub init_database;
sub add_session;

# XXX: Need to figure out a way to add the 'req' args to enable this...
# (can probably just lookup the MSet/TestSpec from the name?)
# -- until then die immediately if this option is tried.
# Do the one file case
my $addonefile;
if ( ( $addonefile = $conf->get_val( ATTR => 'AddFile' ) ) ) {

    die "$0: -a add_one_file option not currently supported";

    my $dbh = init_database() || die "Unable to contact database";
    add_session(
        'DBH'    => $dbh,
        'FNAME'  => $addonefile,
        'SUFFIX' => $sessionsuffix
    ) || die "Unable to add $addonefile";

    undef $dbh;

    exit 0;
}

mkpath( [$datadir], 0, 0775 );
chdir $datadir || die "Unable to chdir to $datadir";

#
# setup server socket.
#
my $Server = IO::Socket::INET->new(
    LocalPort => $serverport,
    Proto     => 'tcp',
    Type      => SOCK_STREAM,
    ReuseAddr => 1,
    Reuse     => 1,
    Timeout   => $timeout,
    Listen    => SOMAXCONN
) or die "Unable to create server socket for sessiondata: $!";

if ( !$foreground ) {
    daemonize( PIDFILE => 'bwcollector.pid' )
        || die "Unable to daemonize process";
}

my ( %children );

my ( $reset, $die, $sigchld ) = ( 0, 0, 0 );
my $interrupt = 0;

sub catch {
    my ( $signame ) = @_;

    return if !defined $signame;

    if ( $signame =~ /HUP/ ) {
        $reset = 1;
    }
    elsif ( $signame =~ /CHLD/ ) {
        $sigchld++;
    }
    else {
        $die = 1;
    }

    #
    # If we are in an eval - die from here to make the function return
    # and not automatically restart: ie accept.
    #
    die "SIG$signame\n" if ( $^S && $interrupt );

    #
    # If we are not in an eval - we have already set our global vars
    # so things should happen properly in the main loop.

    return;
}

sub handle_req;

$SIG{CHLD} = $SIG{HUP} = $SIG{TERM} = $SIG{INT} = \&catch;

while ( 1 ) {
    my $paddr;
    my ( $func );

    $@ = '';
    undef $paddr;
    if ( $reset || $die ) {
        undef $Server;
        undef $paddr;
        if ( $reset == 1 ) {
            $reset++;
            warn "Handling SIGHUP... Stop processing...\n";
        }
        elsif ( $die == 1 ) {
            $die++;
            warn "Exiting... Deleting sub-processes...\n";
        }
        $func      = "kill";
        $interrupt = 1;
        eval { kill 'TERM', ( keys %children ); };
        $interrupt = 0;
    }
    elsif ( $sigchld ) {
        ;
    }
    else {
        $func      = "accept";
        $interrupt = 1;
        eval { $paddr = $Server->accept; };
        $interrupt = 0;
    }
    for ( $@ ) {
        ( /^$/ || /^SIG/ )
            and $! = 0, last;
        die "$func(): $!";
    }

    #
    # Not a connection - do error handling.
    #
    if ( !defined( $paddr ) ) {
        if ( $sigchld || $reset || $die ) {
            my $wpid;
            my $opts = 0;

            while ( ( $wpid = waitpid( -1, WNOHANG ) ) > 0 ) {
                next unless ( exists $children{$wpid} );

                syslog( 'debug', "$children{$wpid}:$wpid exited: $?" );
                $die++ if ( $onereq );

                delete $children{$wpid};
            }
            $sigchld = 0;
        }

        if ( $reset ) {
            next if ( ( keys %children ) > 0 );
            next if ( defined $Server );
            warn "Restarting...\n";
            exec $FindBin::Bin. "/" . $FindBin::Script, @SAVEARGV;
        }

        if ( $die > 1 ) {
            if ( ( keys %children ) > 0 ) {
                sleep( 1 );
                next;
            }
            die "Dead\n";
        }

        next;
    }

    #
    # Handle the new connection
    #
    my $newpid = handle_req( $paddr ) || next;
    $children{$newpid} = 'handle_req';
    undef $paddr;
}

sub read_req {
    my ( $fh, $md5 ) = @_;
    my %req;
    my $vers;

    $md5->reset;

    # read version - ignored for now.
    $_ = sys_readline( FILEHANDLE => $fh, TIMEOUT => $timeout );
    if ( !defined $_ ) {
        die "read_req: Connection Closed";
    }
    if ( !( ( $vers ) = /BW\s+(\d+)/ ) ) {
        die "Invalid request version: $_";
    }
    $md5->add( $_ );

    while ( ( $_ = sys_readline( FILEHANDLE => $fh, TIMEOUT => $timeout ) ) ) {
        my ( $pname, $pval );

        $md5->add( $_ );
        next if ( /^\s*#/ );    # comments
        next if ( /^\s*$/ );    # blank lines.

        if ( ( $pname, $pval ) = /^(\w+)\s+(.*)/o ) {
            $pname =~ tr/a-z/A-Z/;
            $req{$pname} = $pval;
            warn "req\{$pname\} = $pval" if defined( $debug );

            next;
        }

        # Invalid message!
        die "Invalid request from socket: $_";
    }
    if ( !defined $_ ) {
        die "read_req: Empty request?";
    }
    die "No secretname!" if ( !exists $req{'SECRETNAME'} );
    $req{'SECRET'} = $conf->must_get_val( ATTR => $req{'SECRETNAME'} );
    $md5->add( $req{'SECRET'} );

    $_ = sys_readline( FILEHANDLE => $fh, TIMEOUT => $timeout );
    if ( !defined $_ ) {
        die "read_req: No hex sent.";
    }
    die "Invalid auth hash: $_" if ( $md5->hexdigest ne $_ );

    $_ = sys_readline( FILEHANDLE => $fh, TIMEOUT => $timeout );
    die "Invalid end Message: $_" if ( !defined $_ || ( "" ne $_ ) );

    return %req;
}

my $ldiefile = undef;

sub ldie {
    my $msg = shift;
    my ( $dummy, $fname, $line ) = caller;
    unlink $ldiefile if ( defined( $ldiefile ) );
    die "$msg :$fname\:$line\n";
}

sub print_table {
    my ( %args ) = @_;

    my $sql = "SELECT * from $args{'TABLE'}";
    my $sth = $args{'DBH'}->prepare( $sql ) || die "Can't prepare!";
    $sth->execute() || die "Can't execute SELECT of $args{'TABLE'}";
    warn "TABLE:$args{'TABLE'}\n";
    my ( $i, @row );
    $i = 0;
    while ( @row = $sth->fetchrow_array ) {
        $i++;
        warn "$i\t@row\n";
    }

    return 1;
}

sub init_database {

    my $dbh = DBI->connect(
        $dbsource,
        $dbuser, $dbpass,
        {
            RaiseError => 1,
            PrintError => 1
        }
    ) || die "Connecting to database";
    if ( $profile ) {

        #		use DBI::Profile qw(DBIprofile_Statement);
        #		$dbh->{Profile} = DBI::ProfileDumper->new(
        #				{ Path => [ DBIprofile_Statement ],
        #				  File => 'dbi.prof' });
        warn "Profiling...\n";
        $dbh->{Profile} = "DBI::ProfileDumper";
    }

    return $dbh;
}

my %ca_month;

sub get_tprefix {
    my $time = shift;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = owpgmtime( $time );
    my @ret = ( sprintf( "%4.4d%2.2d", $year + 1900, $mon + 1 ), $year + 1900, $mon + 1 );
    return @ret;
}

sub get_prev_tprefix {
    my $time = shift;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = owpgmtime( $time );
    if ( $mon < 1 ) {
        $mon = 11;
        $year -= 1;
    }
    else {
        $mon--;
    }

    return ( sprintf( '%4.4d%2.2d', $year + 1900, $mon + 1 ), $year + 1900, $mon + 1 );
}

sub init_month {
    my ( %args )         = @_;
    my ( @mustargnames ) = qw(DBH TIMESTAMP);
    my ( @argnames )     = undef;
    if ( !( %args = owpverify_args( undef, \@mustargnames, %args ) ) ) {
        ldie "init_month: Invalid args";
    }

    my $dbh = $args{'DBH'};
    my ( $lname, $year, $month ) = get_tprefix( $args{'TIMESTAMP'} );

    if ( $ca_month{$lname} ) {
        return $lname;
    }

    # XXX: configurable description length?
    my $sql = "CREATE TABLE IF NOT EXISTS ${lname}_TESTSPEC (
        tspec_id            INT UNSIGNED NOT NULL,
        description         TEXT(1024),
        duration            INT UNSIGNED NOT NULL DEFAULT 10,
        len_buffer          INT UNSIGNED,
        window_size         INT UNSIGNED,
        tos                 TINYINT UNSIGNED,
        parallel_streams    TINYINT UNSIGNED NOT NULL DEFAULT 1,
        udp                 BOOL NOT NULL DEFAULT 0,
        udp_bandwidth       BIGINT UNSIGNED,
        PRIMARY KEY(tspec_id)
        )";
    $dbh->do( $sql ) || ldie "Creating ${lname}_TESTSPEC";

    $sql = "CREATE TABLE IF NOT EXISTS ${lname}_NODES (
        node_id     INT UNSIGNED NOT NULL,
        node_name   TEXT(128),
        longname    TEXT(1024),
        addr        TEXT(128),
        first       INT UNSIGNED NOT NULL,
        last        INT UNSIGNED NOT NULL,
        PRIMARY KEY(node_id),
        INDEX(last)
        )";
    $dbh->do( $sql ) || ldie "Creating ${lname}_NODES";

    $sql = "CREATE TABLE IF NOT EXISTS ${lname}_DATA (
        send_id     INT UNSIGNED NOT NULL,
        recv_id     INT UNSIGNED NOT NULL,
        tspec_id    INT UNSIGNED NOT NULL,
        ti          INT UNSIGNED NOT NULL,
        timestamp   BIGINT UNSIGNED NOT NULL,
        throughput  FLOAT,
        jitter      FLOAT,
        lost        BIGINT UNSIGNED,
        sent        BIGINT UNSIGNED,
        PRIMARY KEY (ti,send_id,recv_id),
        INDEX(send_id),
        INDEX(recv_id),
        INDEX(tspec_id)
    )";
    $dbh->do( $sql ) || ldie "Creating ${lname}_DATA";

    $sql = "INSERT IGNORE INTO DATES (year, month) VALUES(?,?)";
    my $sth = $dbh->prepare( $sql ) || ldie "Prep: Insert DATES";
    $sth->execute( $year, $month ) || ldie "Exec: Insert DATES";

    return $ca_month{$lname} = $lname;
}

#
# XXX: When generalizing this for multiple data types, look at
# $req{'TOOL'} to determine what kind of 'tspec' to create.
#
sub save_tspec {
    my ( %args )         = @_;
    my ( @mustargnames ) = qw(DBH TIMESTAMP REQUEST);
    my ( @argnames )     = undef;
    if ( !( %args = owpverify_args( undef, \@mustargnames, %args ) ) ) {
        ldie "save_tspec: Invalid args";
    }

    my $dbh = $args{'DBH'};
    my ( $lname, $year, $mon ) = get_tprefix( $args{'TIMESTAMP'} );
    my $req = $args{'REQUEST'};

    my $md5 = Digest::MD5->new;
    my $key;

    # compute an MD5 hash for this testspec
    foreach $key ( qw(DESCRIPTION BWTESTDURATION BWBUFFERLEN BWWINDOWSIZE BWTOS BWPARALLELSTREAMS BWTCP BWUDP BWUDPBANDWIDTHLIMIT) ) {
        if ( exists $req->{$key} ) {
            $md5->add( $key );
            $md5->add( $req->{$key} );
        }
    }

    my $hexdigest = $md5->hexdigest;
    my $digest = hex( substr( $hexdigest, -8, 8 ) );

    my $sql = "INSERT IGNORE INTO ${lname}_TESTSPEC
            (
            tspec_id,
            description,
            duration,
            len_buffer,
            window_size,
            tos,
            parallel_streams,
            udp,
            udp_bandwidth
            )
            VALUES(?,?,?,?,?,?,?,?,?)";
    my $sth = $dbh->prepare( $sql ) || ldie "Prep: Insert ${lname}_TESTSPEC";

    $sth->execute( $digest, $req->{'DESCRIPTION'}, $req->{'BWTESTDURATION'}, $req->{'BWBUFFERLEN'}, $req->{'BWWINDOWSIZE'}, $req->{'BWTOS'}, $req->{'BWPARALLELSTREAMS'} || 1, ( $req->{'BWUDP'} ) ? 1 : 0, $req->{'BWUDPBANDWIDTHLIMIT'} )
        || ldie "Exec: Insert ${lname}_TESTSPEC";
    return $digest;
}

my %ca_pnode;

sub save_node {
    my ( %args )         = @_;
    my ( @mustargnames ) = qw(DBH TIMESTAMP NODE ADDR);
    my ( @argnames )     = qw(LONGNAME);
    if ( !( %args = owpverify_args( \@argnames, \@mustargnames, %args ) ) ) {
        ldie "save_tspec: Invalid args";
    }

    my $dbh = $args{'DBH'};
    my ( $addr, $port ) = split_addr( $args{'ADDR'} );
    my ( $lname,  $year,  $month )  = get_tprefix( $args{'TIMESTAMP'} );
    my ( $plname, $pyear, $pmonth ) = get_prev_tprefix( $args{'TIMESTAMP'} );
    my ( $sql, $i, $sth, @row, $first, $last );

    # compute an MD5 hash for this testspec
    my $md5 = Digest::MD5->new;
    $md5->add( $args{'NODE'} );
    $md5->add( $args{'HOST'} );
    $md5->add( $args{'ADDR'} );
    my $hexdigest = $md5->hexdigest;
    my $digest = hex( substr( $hexdigest, -8, 8 ) );

    # Look for prev month (see if 'first' existed before this month)
    $first = $last = owptime2time( $args{'TIMESTAMP'} );
    if ( $ca_pnode{$plname} ) {
        $first = $ca_pnode{$plname};
    }
    else {
        $sql = "SELECT year,month
        FROM DATES
        WHERE year=? AND month=?";
        $sth = $dbh->prepare( $sql ) || ldie "Prep: Select $plname from DATES";
        $sth->execute( $pyear, $pmonth ) || ldie "Exec: Select $plname from DATES";
        $i = 0;
        while ( @row = $sth->fetchrow ) { $i++ }

        # If prev month existed, see if this node has been defined before
        # and fetch the 'first' timestamp from it.
        if ( $i > 0 ) {
            $sql = "SELECT first
            FROM ${plname}_NODES
            WHERE node_id=?";
            $sth = $dbh->prepare( $sql )
                || ldie "Prep: Select first from ${plname}_NODES";
            $sth->execute( $digest )
                || ldie "Exec: Select first from ${plname}_NODES";
            $i = 0;
            while ( @row = $sth->fetchrow ) { $i++ }
            if ( $i > 1 ) {
                warn "${plname}_NODES: Duplicate hash entry for $args{'NODE'}";
            }
            if ( $i > 0 ) {
                $first = $row[0];
            }
        }
    }

    # Now update this months table with this node information
    #
    # First insert-ignore the full information, if this node_id already
    # exists - it will silently be ignored. Then update 'last' in the
    # event this is not a new node definition and we only want to update the
    # entry.
    $sql = "INSERT IGNORE INTO ${lname}_NODES
            (
            node_id,
            node_name,
            longname,
            addr,
            first,
            last
            )
            VALUES(?,?,?,?,?,?)";
    $sth = $dbh->prepare( $sql ) || ldie "Prep: Insert ${lname}_NODES";

    $sth->execute( $digest, $args{'NODE'}, $args{'LONGNAME'}, $addr, $first, $last ) || ldie "Exec: Insert ${lname}_NODES";

    $sql = "UPDATE ${lname}_NODES
            SET last = ?
            WHERE node_id = ? AND ? > last";
    $sth = $dbh->prepare( $sql ) || ldie "Prep: UPDATE ${lname}_NODES";

    $sth->execute( $last, $digest, $last ) || ldie "Exec: UPDATE ${lname}_NODES";

    return $digest;
}

sub add_session {
    my ( %args )         = @_;
    my ( @mustargnames ) = qw(DBH FNAME REQUEST);
    my ( @argnames )     = undef;
    if ( !( %args = owpverify_args( \@argnames, \@mustargnames, %args ) ) ) {
        ldie "add_session: Invalid args.";
    }

    my ( $sql, $sth, $rc, $i, @row );
    my ( $dbh, $add_file, $reqh, $fttime );
    my ( %bwstats );

    $dbh      = $args{'DBH'};
    $add_file = $args{'FNAME'};
    $reqh     = $args{'REQUEST'};
    $fttime   = $reqh->{'TIMESTAMP'};
    my $arch = undef;    # XXX: put back in after demo... 080720-jwb
                         # convert string to a bigint
    $fttime = uint64( $fttime );

    my $tprefix;
    $tprefix = init_month(
        DBH       => $dbh,
        TIMESTAMP => $fttime
    );

    my $testname = $reqh->{'MEASUREMENTSET'} || "GENERAL";
    $testname .= "_" . $reqh->{'RECVNODE'} . "_" . $reqh->{'SENDNODE'};

    warn "ADD_SESSION: Adding $fttime to $testname\n"
        if defined( $debug );

    # parse iperf data
    my ( $sess_id, $min_si, $max_si, $max_ei );
    my %sess_summ;

    local *SESS;
    open( SESS, "<$add_file" )
        || ldie "Unable to open $add_file";
    while ( <SESS> ) {
        my ( $id, $si, $ei, $txfr, $bw, $jitter, $nlost, $nsent );

        ( $jitter, $nlost, $nsent ) = ( undef, undef, undef );

        # ignore bogus sessions
        if ( m#\(nan\%\)# ) {    #"nan" displayed for number
            warn "IGNORED: nan in $testname file = $add_file\n";
            %sess_summ = ();
            last;
        }
        if ( m#read failed: Connection refused# ) {
            warn "IGNORED: connrefused in $testname file = $add_file\n";
            %sess_summ = ();
            last;
        }

        if (   ( ( $id, $si, $ei, $txfr, $bw, $jitter, $nlost, $nsent ) = m#\[\s*(\d+)\s*\]\s+([0-9\.]+)\s*\-\s*([0-9\.]+)\s+sec\s+(\d+)\s+Bytes\s+(\d+)\s+bits/sec\s+([0-9\.]+)\s+ms\s+(\d+)/(\d+)\s+# )
            || ( ( $id, $si, $ei, $txfr, $bw ) = m#\[\s*(\d+)\s*\]\s+([0-9\.]+)\s*\-\s*([0-9\.]+)\s+sec\s+(\d+)\s+Bytes\s+(\d+)\s+bits/sec# ) )
        {
            $sess_id = $id if ( !defined( $sess_id ) );
            next if ( $id != $sess_id );

            if ( !defined( $min_si ) ) {
                $min_si = $si;
            }
            else {
                $min_si = $si if ( $si < $min_si );
            }
            if ( !defined( $max_si ) ) {
                $max_si = $si;
            }
            else {
                $max_si = $si if ( $si > $max_si );
            }
            if ( !defined( $max_ei ) ) {
                $max_ei = $ei;
            }
            else {
                $max_ei = $ei if ( $ei > $max_ei );
            }
            @{ $sess_summ{"${si}_${ei}"} } = ( $si, $ei, $bw, $jitter, $nlost, $nsent );
        }
    }

    # validation checks for data - throw out nonsense data
    if ( ( keys %sess_summ ) <= 0 ) {
        warn "BEGIN IGNORED: empty $testname file = $add_file";
        seek SESS, 0, 0;
        while ( <SESS> ) {
            warn "$add_file: $_\n";
        }
        warn "END IGNORED: empty $testname file = $add_file";
        return 1;
    }
    if ( !exists( $sess_summ{"${min_si}_${max_ei}"} ) ) {
        warn "BEGIN IGNORED: NO SESS Summary: $testname: $add_file";
        seek SESS, 0, 0;
        while ( <SESS> ) {
            warn "$add_file: $_\n";
        }
        warn "END IGNORED: NO SESS Summary: $testname: $add_file";
        return 1;
    }

    my $testlen = $reqh->{'BWTESTDURATION'};
    if ( ( $max_ei < $testlen ) || ( ( $max_ei - $testlen ) > 1.0 ) ) {
        warn "IGNORED: termination problem $testname file = $add_file";
        return 1;
    }

    #data is good - now save session into the database.

    #    # XXX: Archiving needs to be redone...
    #    if ( defined($arch) ) {
    #        $arch->add(
    #            DBH      => $dbh,
    #            DATAFILE => $add_file,
    #            TESTID   => $testid_ca{$testname},
    #            MESH     => $mtype,
    #            RECV     => $recv,
    #            SEND     => $send,
    #            START    => $fttime,
    #            'END'    => $fttime
    #        ) || ldie "Unable to archive $add_file";
    #    }

    # First save metadata (host and testspec info)
    my ( $tspec_id, $recv_id, $send_id );
    if (
        !(
            $tspec_id = save_tspec(
                DBH       => $dbh,
                TIMESTAMP => $fttime,
                REQUEST   => $reqh,
            )
        )
        )
    {
        ldie "Unable to save testspec for test=$testname";
    }

    if (
        !(
            $recv_id = save_node(
                DBH       => $dbh,
                NODE      => $reqh->{'RECVNODE'},
                ADDR      => $reqh->{'RECVADDR'},
                LONGNAME  => $reqh->{'RECVLONGNAME'},
                TIMESTAMP => $fttime,
            )
        )
        )
    {
        ldie "Unable to save NODE=$reqh->{'RECVNODE'}";
    }

    if (
        !(
            $send_id = save_node(
                DBH       => $dbh,
                NODE      => $reqh->{'SENDNODE'},
                ADDR      => $reqh->{'SENDADDR'},
                LONGNAME  => $reqh->{'SENDLONGNAME'},
                TIMESTAMP => $fttime,
            )
        )
        )
    {
        ldie "Unable to save NODE=$reqh->{'SENDNODE'}";
    }

    $sql = "INSERT IGNORE INTO ${tprefix}_DATA(
                send_id,
                recv_id,
                tspec_id,
		ti,
		timestamp,
		throughput,
		jitter,
		lost,
		sent
	)
	VALUES(?,?,?,?,?,?,?,?,?)";
    if ( !( $sth = $dbh->prepare( $sql ) ) ) {
        ldie "Prep: Insert $testname";
    }

    my @vals = @{ $sess_summ{"${min_si}_${max_ei}"} };
    shift @vals;
    shift @vals;
    if ( !( $rc = $sth->execute( $send_id, $recv_id, $tspec_id, owptstampi( $fttime ), $fttime, @vals ) ) ) {
        ldie "Insert $testname";
    }

    warn "ADD_SESSION: $testname: inserted $add_file"
        if defined( $verbose );

    #ERROR:
    #    if ( defined($arch) ) {
    #        if ( !$rollback ) {
    #            $arch->validate(
    #                DBH    => $dbh,
    #                TESTID => $testid_ca{$testname},
    #                TO     => $fttime
    #            );
    #        }
    #        else {
    #            $arch->rm(
    #                DBH      => $dbh,
    #                DATAFILE => $add_file,
    #                TESTID   => $testid_ca{$testname},
    #                MESH     => $mtype,
    #                RECV     => $recv,
    #                SEND     => $send,
    #                START    => $fttime,
    #                'END'    => $fttime
    #            );
    #        }
    #    }

    return 1;
}

sub do_req {
    my ( $fh, $md5, $dbh, %req ) = @_;
    my ( %resp );

    die "Invalid OP request"
        if ( !exists $req{'OP'} || $req{'OP'} ne 'TXFR' );

    die "Invalid filesize"
        if ( !exists $req{'FILESIZE'} );
    die "Invalid file MD5"
        if ( !exists $req{'FILEMD5'} );

    my $len = $req{'FILESIZE'} + 0;

    my ( $tfh, $tfname ) = tempfile( DIR => $datadir );

    $ldiefile = $tfname;

RLOOP:
    while ( $len ) {

        # all read/write errors are fatal - make the client reconnect.
        my ( $written, $buf, $rlen, $offset );
        undef $rlen;
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            local $SIG{PIPE} = sub { die "pipe\n" };
            alarm $timeout;
            $rlen = sysread $fh, $buf, $len;
            alarm 0;
        };
        if ( !defined $rlen ) {
            if ( ( $! == EINTR ) && ( $@ ne "alarm\n" ) && ( $@ ne "pipe\n" ) ) {
                next RLOOP;
            }
            ldie "Read error from socket: $!\n";
        }
        if ( $rlen < 1 ) {
            ldie "0 length read from socket: $!\n";
        }
        $len -= $rlen;
        $offset = 0;
    WLOOP:
        while ( $rlen ) {
            undef $written;
            eval {
                local $SIG{ALRM} = sub { die "alarm\n" };
                local $SIG{PIPE} = sub { die "pipe\n" };
                alarm $timeout;
                $written = syswrite $tfh, $buf, $rlen, $offset;
                alarm 0;
            };
            if ( !defined $written ) {
                if ( ( $! == EINTR ) && ( $@ ne "alarm\n" ) && ( $@ ne "pipe\n" ) ) {
                    next WLOOP;
                }
                ldie "Write error to file $tfname: $!";
            }
            if ( $written < 1 ) {
                ldie "0 length write to $tfname: $!\n";
            }
            $rlen -= $written;
            $offset += $written;
        }
    }
    undef $tfh;

    # close and reopen to ensure flushing of file, and because
    # I don't want to try and mix read/sysread here.
    $tfh = new IO::File "<$tfname";
    if ( !defined( $tfh ) ) {
        ldie "Unable to open $tfname for md5 check: $!";
    }

    $md5->reset;
    $md5->addfile( $tfh );
    undef $tfh;
    if ( $md5->hexdigest ne $req{'FILEMD5'} ) {
        ldie "Failed File MD5!";
    }

    my %add_args = (
        'DBH'   => $dbh,
        'FNAME' => $tfname,

        #        'SUFFIX'   => "$sessionsuffix.i",
        #        'ARCHFILE' => $req{'FNAME'},
        #        'ARCHIVE'  => $archive,
        'REQUEST' => \%req,
    );

    add_session( %add_args ) || ldie "Unable to add $tfname";

    if ( $profile ) {
        my $pfh = $dbh->{Profile};
        warn "Flushing profile to disk!\n";
    }

    unlink $ldiefile;
    $ldiefile = undef;

    $resp{'STATUS'}  = 'OK';
    $resp{'FILEMD5'} = $req{'FILEMD5'};
    $resp{'SECRET'}  = $req{'SECRET'};

    return %resp;
}

sub write_response {
    my ( $fh, $md5, %resp ) = @_;

    my $line   = "BW 2.0";
    my $secret = $resp{'SECRET'};

    delete $resp{'SECRET'};

    $md5->reset;
    return if (
        !sys_writeline(
            FILEHANDLE => $fh,
            MD5        => $md5,
            TIMEOUT    => $timeout,
            LINE       => $line
        )
    );
    foreach ( keys %resp ) {
        return if (
            !sys_writeline(
                FILEHANDLE => $fh,
                MD5        => $md5,
                TIMEOUT    => $timeout,
                LINE       => "$_\t$resp{$_}"
            )
        );
    }
    return if (
        !sys_writeline(
            FILEHANDLE => $fh,
            TIMEOUT    => $timeout
        )
    );
    $md5->add( $secret );
    return if (
        !sys_writeline(
            FILEHANDLE => $fh,
            MD5        => $md5,
            TIMEOUT    => $timeout,
            LINE       => $md5->hexdigest
        )
    );
    return if (
        !sys_writeline(
            FILEHANDLE => $fh,
            TIMEOUT    => $timeout
        )
    );

    return 1;
}

sub child_catch {
    my ( $signame ) = @_;

    return if ( $signame =~ /CHLD/ );

    $die = 1;

    die "SIG$signame caught...\n";
}

sub handle_req {
    my ( $fh ) = @_;
    my $nname;

    if ( $nname = $ignore_node{ $fh->peerhost } ) {
        syslog( 'debug', "IGNORE connect from $nname:[" . $fh->peerhost . "]" );
        $fh->close;
        return undef;
    }

    if ( $verify_addrs && !exists( $listen_nodes{ $fh->peerhost } ) ) {
        warn( "IGNORE connect from [" . $fh->peerhost . "]: Could not verify" );
        $fh->close;
        return undef;
    }

    my $pid = fork;

    # error
    die "fork(): $!" if ( !defined( $pid ) );

    # parent
    return $pid if ( $pid );

    # child continues

    # Set new process name
    if ( !( $nname = $listen_nodes{ $fh->peerhost } ) ) {
        $nname = "unknown";
    }
    $0 = "$scriptname:handle_req[$nname]";

    if ( $nname = $debug_node{ $fh->peerhost } ) {
        syslog( 'debug', "Extra debugging for $nname:[" . $fh->peerhost . "]" );
        $debug = 1;
    }

    undef $Server;
    my $md5 = new Digest::MD5
        || die "Unable to create md5 context";
    $die = 0;
    $SIG{CHLD} = $SIG{HUP} = $SIG{TERM} = $SIG{INT} = \&child_catch;

    syslog( 'info', "connect from [" . $fh->peerhost . "]" );

    my $dbh = init_database
        || die "Unable to initialize database";

    my ( $rin, $rout, $ein, $eout, $nfound );

    $rin = '';
    vec( $rin, $fh->fileno, 1 ) = 1;
    $ein = $rin;

    my ( $nreqs ) = 0;

REQ_LOOP:
    while ( 1 ) {
        my ( %req, %response );

        $die++ if ( ( $nreqs > 0 ) && ( $onereq ) );

        last           if ( $die );
        last           if ( $die );
        die "\$@ = $@" if ( $@ );
        eval { ( $nfound ) = select( $rout = $rin, undef, $eout = $ein, $timeout ); };
        last           if ( $die );
        die "\$@ = $@" if ( $@ );
        last           if ( vec( $eout, $fh->fileno, 1 ) );
        last           if ( !vec( $rout, $fh->fileno, 1 ) );

        $nreqs++;

        undef %req;
        %req = read_req( $fh, $md5 );
        last if ( $die );

        $req{'REQUEST_HOST'} = $fh->peerhost;
        last if ( $die );
        die "\$@ = $@" if ( $@ );

        undef %response;
        if ( !( %response = do_req( $fh, $md5, $dbh, %req ) ) ) {
            warn "do_req: failed";
            next;
        }
        elsif ( write_response( $fh, $md5, %response ) ) {
            next;
        }
        else {
            warn "write_response: failed";
        }

        last;
    }

    exit 0;
}

1;

__END__

=head1 SEE ALSO

L<Carp>, L<FindBin>, L<Getopt::Std>, L<Socket>, L<POSIX>, L<File::Path>,
L<Digest::MD5>, L<OWP>, L<OWP::Syslog>, L<OWP::RawIO>, L<OWP::Archive>,
L<OWP::Utils>, L<OWP::Helper>, L<Sys::Syslog>, L<File::Basename>, L<File::Temp>,
L<Fcntl>, L<FileHandle>, L<IO::Socket>, L<DB_File>, L<DBI>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: bwcollector.pl 3831 2010-01-15 21:02:23Z alake $

=head1 AUTHOR

Jeff W. Boote <boote@internet2.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2002-2009, Internet2

All rights reserved.

=cut
