#!/usr/bin/perl -w
# ex: set tabstop=4 ai expandtab softtabstop=4 shiftwidth=4:
# -*- mode: c-basic-indent: 4; tab-width: 4; indent-tabs-mode: nil -*-

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

bwmaster.pl - Control BWCTL measurement in perfSONAR-BUOY

=head1 DESCRIPTION

Using the owmesh.conf file as a guide, perform specified measurements and store
the results in a database.  This script is to be run on machines that will
perform measurements.  

=head1 SYNOPSIS

bwmaster.pl [B<-c> confdir/][B<-n> nodename][B<-Z>][B<-x>][B<-h>][B<-k>][B<-d>][B<-v>]

=over

=item B<-c> confdir

Specify the directory to find the owmesh.conf file.

=item B<-n> nodename

Use a specific node, specified in the owmesh, that this host will run tests as.
Useful in situations where the <HOST> directives are not used.

=item B<-Z>

Run bwcollector.pl in the foreground.

=item B<-x>

Exit the script immediatly after loading (debug option).  

=item B<-h>

Send a SIGHUP to a currently running bwcollector.pl. This causes any current
connections to be closed, and the owmesh.conf file to be re-read before
bwcollector.pl continues.

=item B<-k>

Send a SIGTERM to a currently running bwcollector.pl. i.e. Gracefully
shutdown.

=item B<-d>

Print debugging messages. 

=item B<-v>

Print verbose messages.

=back

=cut

use FindBin;

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

my $scriptname = "$0";
$0 = "$scriptname:master";

# use amidefaults to find other modules $env('PERL5LIB') still works...
use lib $amidefaults{'LIBDIR'};
use Getopt::Std;
use POSIX;
use IPC::Open3;
use File::Path;
use File::Basename;
use FileHandle;
use OWP;
use OWP::RawIO;
use OWP::MeasSet;
use OWP::Syslog;
use OWP::Helper;
use Sys::Syslog;
use Digest::MD5;
use Socket;
use IO::Socket;
use Fcntl qw(:flock);

my @SAVEARGV = @ARGV;
my %options  = (
    CONFDIR    => "c:",
    LOCALNODES => "n:",
    FOREGROUND => "Z",
    PAREXIT    => "x",    # Used to make script exit immediately after loading
    HUP        => "h",
    KILL       => "k",
    DEBUG      => "d",
    VERBOSE    => "v"
);

my %optnames;
foreach ( keys %options ) {
    my $key = substr( $options{$_}, 0, 1 );
    $optnames{$key} = $_;
}
my $options = join "", values %options;
my %setopts;
getopts( $options, \%setopts );
foreach ( keys %optnames ) {
    $amidefaults{ $optnames{$_} } = $setopts{$_} if ( defined( $setopts{$_} ) );
}

# Add -Z flag for re-exec - don't need to re-daemonize.
push @SAVEARGV, '-Z' if ( !defined( $setopts{'Z'} ) );

if ( defined( $amidefaults{"LOCALNODES"} ) ) {
    my @tarr;
    my $tnodes;
    $tnodes = $amidefaults{"LOCALNODES"};
    if ( $tnodes =~ /:/ ) {
        @tarr = split ':', $tnodes;
        foreach ( @tarr ) {
            tr/a-z/A-Z/;
        }
    }
    else {
        $tnodes =~ tr/a-z/A-Z/;
        @tarr = ( $tnodes );
    }

    $amidefaults{"LOCALNODES"} = \@tarr;
}

my $conf = new OWP::Conf( %amidefaults );

my $parexit = $conf->get_val( ATTR => 'PAREXIT' );
if ( $parexit ) {
    warn "Exiting just after loading everything... (-x specified)\n";
    exit 0;
}

my $ttype = 'BW';

my @localnodes = $conf->get_val( ATTR => 'LOCALNODES' );
if ( !defined( $localnodes[0] ) ) {
    my $me = $conf->must_get_val( ATTR => 'NODE' );
    @localnodes = ( $me );
}

my $datadir = $conf->must_get_val( ATTR => "DataDir", TYPE => $ttype );

#
# Send current running process a signal.
#
my $kill = $conf->get_val( ATTR => 'KILL' );
my $hup  = $conf->get_val( ATTR => 'HUP' );
if ( $kill || $hup ) {
    my $pidfile = new FileHandle "$datadir/bwmaster.pid", O_RDONLY;
    die "Unable to open($datadir/bwmaster.pid): $!"
        unless ( $pidfile );

    my $pid = <$pidfile>;
    die "Unable to retrieve PID from $datadir/bwmaster.pid"
        if !defined( $pid );
    chomp $pid;

    if ($hup) {
        if ( kill( 'HUP', $pid ) ) {
            warn "Sent HUP to $pid\n";
            exit( 0 );
        }
        die "Unable to send HUP to $pid: $!";
    }
    else {
        unless ( kill( 0, $pid ) ) {
            die "Unable to find process $pid: $!";
        }

        for (1..5) {
            unless ( kill( 0, $pid ) ) {
                warn "Sent TERM to $pid, and process appears to have exited\n";
                exit( 0 );
            }

            unless ( kill( 'TERM', $pid ) ) {
                die "Unable to send TERM to $pid: $!";
            }

            warn "Sent TERM to $pid\n";

            my $wpid = waitpid( $pid, WNOHANG );
            if ($wpid > 0) {
                warn "Sent TERM to $pid, and process exited\n";
                exit( 0 );
            }

            warn "Waiting for $pid to exit\n";
            sleep(1);
        }
    }
}

# Set uid to lesser permissions immediately if we are running as root.
my $uid = $conf->get_val( ATTR => 'UserName',  TYPE => $ttype );
my $gid = $conf->get_val( ATTR => 'GroupName', TYPE => $ttype );
setids(
    USER  => $uid,
    GROUP => $gid
);

my $facility = $conf->must_get_val( ATTR => 'SyslogFacility', TYPE => $ttype );

# setup syslog
local ( *MYLOG );
my $slog = tie *MYLOG, 'OWP::Syslog',
    facility   => $facility,
    log_opts   => 'pid',
    setlogsock => 'unix';

# make die/warn goto syslog, and also to STDERR.
$slog->HandleDieWarn( *STDERR );
undef $slog;    # Don't keep tie'd ref's around unless you need them...

#
# fetch "global" values needed.
#
my $debug   = $conf->get_val( ATTR => 'DEBUG',   TYPE => $ttype );
my $verbose = $conf->get_val( ATTR => 'VERBOSE', TYPE => $ttype );
my $foreground = $conf->get_val( ATTR      => 'FOREGROUND' );
my $devnull    = $conf->must_get_val( ATTR => "devnull" );
my $suffix = $conf->must_get_val( ATTR => "SessionSuffix", TYPE => $ttype );

#
# Central server values
#
my $secretname = $conf->must_get_val(
    ATTR => 'SECRETNAME',
    TYPE => $ttype
);
my $secret = $conf->must_get_val(
    ATTR => $secretname,
    TYPE => $ttype
);
my $fullcentral_host = $conf->must_get_val(
    ATTR => 'CentralHost',
    TYPE => $ttype
);
my $timeout = $conf->must_get_val(
    ATTR => 'SendTimeout',
    TYPE => $ttype
);

my ( $central_host, $central_port ) = split_addr( $fullcentral_host );
if ( !defined( $central_port ) ) {
    die "Invalid CentralHost value: $fullcentral_host";
}

#
# local data/path information
#
my $bwcmd = $conf->must_get_val( ATTR => "BinDir", TYPE => $ttype );
$bwcmd .= "/";
$bwcmd .= $conf->must_get_val( ATTR => "Cmd", TYPE => $ttype );

#
# pid2info - used to determine nature of child process that dies.
my ( %pid2info, $dir );

#
# First determine the set of tests that need to be configured from this
# host.
#
my @bwctltests = $conf->get_list(
    LIST  => 'TESTSPEC',
    ATTR  => 'TOOL',
    VALUE => 'bwctl/iperf'
);

if ( defined( $debug ) ) {
    warn "Found " . scalar( @bwctltests ) . " bwctl/iperf related TESTSPEC blocks";
}

#
# now find the actual measurement sets
#
my ( @meassets, $ttest );
foreach $ttest ( @bwctltests ) {
    push @meassets,
        $conf->get_list(
        LIST  => 'MEASUREMENTSET',
        ATTR  => 'TESTSPEC',
        VALUE => $ttest
        );
}

if ( defined( $debug ) ) {
    warn "Found " . scalar( @meassets ) . " bwctl/iperf related MEASUREMENTSET blocks";
}

#
# setup loop - build the directories needed for holding temporary data.
# - data is held in datadir/$msetname/$recv/$send
#
my ( $mset, $myaddr, $oaddr, $raddr, $saddr );
my ( $recv, $send );
my @dirlist;
foreach $mset ( @meassets ) {
    my $me;

    my $msetdesc = new OWP::MeasSet(
        CONF           => $conf,
        MEASUREMENTSET => $mset
    );

    # skip msets that are invoked centrally
    # XXX: Need to implement this in the collector still.
    next if ( $msetdesc->{'CENTRALLY_INVOLKED'} );

    foreach $me ( @localnodes ) {

        if ( defined( $conf->get_val( NODE => $me, ATTR => 'NOAGENT' ) ) ) {
            die "configuration specifies NODE=$me should not run an agent";
        }

        # determine path for recv-relative tests started from this host
        foreach $recv ( keys %{ $msetdesc->{'RECEIVERS'} } ) {

            #
            # If recv is not the localnode currently doing, skip.
            #
            next if ( $me ne $recv );

            foreach $send ( @{ $msetdesc->{'RECEIVERS'}->{$recv} } ) {

                # bwctl always excludes self tests.
                next if ( $recv eq $send );

                push @dirlist, "$mset/$recv/$send";
            }
        }

        # determine path for send-relative tests started from this host
        # (If the remote host does not run bwmaster.)
        foreach $send ( keys %{ $msetdesc->{'SENDERS'} } ) {

            #
            #
            # If send is not the localnode currently doing, skip.
            #
            next if ( $me ne $send );

            foreach $recv ( @{ $msetdesc->{'SENDERS'}->{$send} } ) {

                # bwctl always excludes self tests.
                next if ( $recv eq $send );

                # run 'sender' side tests for noagent receivers
                next if ( !defined( $conf->get_val( NODE => $recv, ATTR => 'NOAGENT' ) ) );

                push @dirlist, "$mset/$recv/$send";
            }
        }
    }
}
die "No tests to be run by this host." if ( !scalar @dirlist );

mkpath( [ map { join '/', $datadir, $_ } @dirlist ], 0, 0775 );

chdir $datadir || die "Unable to chdir to $datadir";

# Test $bwcmd after chdir so relative paths are checked from there
die "$bwcmd not executable" if ( !-x $bwcmd );

my ( $MD5 ) = new Digest::MD5
    or die "Unable to create md5 context";

if ( !$foreground ) {
    daemonize( PIDFILE => 'bwmaster.pid', DEVNULL => $devnull )
        or die "Unable to daemonize process";
}

# setup pipe - read side used by send_data, write side used by all
# bwctl children.
my ( $rfd, $wfd ) = POSIX::pipe();
local ( *WRITEPIPE );
open( WRITEPIPE, ">&=$wfd" ) || die "Can't fdopen write end of pipe";

# setup signal handling before starting child processes to catch
# SIG_CHLD
my ( $reset, $die, $sigchld ) = ( 0, 0, 0 );

# interrupt var used to make sighandler throw a die when we
# don't want system calls to be automatically restarted.
my $interrupt = 0;

sub catch_sig {
    my ( $signame ) = @_;

    return if !defined $signame;

    if ( $signame =~ /CHLD/ ) {
        $sigchld++;
    }
    elsif ( $signame =~ /HUP/ ) {
        $reset = 1;
    }
    else {
        $die = 1;
    }

    #
    # If we are in an eval ($^S) and we don't want perl to re-call
    # an interrupted system call ($interrupt), then die from here to
    # make the funciton return
    # and not automatically restart: ie accept.
    #
    die "SIG$signame" if ( $^S && $interrupt );

    return;
}

my $nomask = new POSIX::SigSet;
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = $SIG{CHLD} = \&catch_sig;
$SIG{PIPE} = 'IGNORE';

#
# send_data first adds all files in dirlist onto it's workque, then forks
# and returns. (As bwctl finishes files, send_data adds each file
# to it's work que.)
my $pid = send_data( $conf, $rfd, @dirlist );
@{ $pid2info{$pid} } = ( "send_data" );

#
# bwctl setup loop - creates a bwctl process for each path that should
# be started from this node. (In general, that is recv-side tests, but
# send-side is started if it is known that the 'other' side is not
# running an agent.
# This sets the STDOUT of bwctl to point at the send_data process, so
# that process can forward the data onto the 'collector' running
# at the database.
# (bwctl outputs the filenames it produces on stdout.)
#
foreach $mset ( @meassets ) {
    my $me;

    my $msetdesc = new OWP::MeasSet(
        CONF           => $conf,
        MEASUREMENTSET => $mset
    );

    # skip msets that are invoked centrally
    next if ( $msetdesc->{'CENTRALLY_INVOLKED'} );

    if ( defined( $debug ) ) {
        warn "Starting MeasurementSet=$mset\n";
    }

    foreach $me ( @localnodes ) {

        if ( defined( $conf->get_val( NODE => $me, ATTR => 'NOAGENT' ) ) ) {
            die "configuration specifies NODE=$me should not run an agent";
        }

        # determine addresses for recv-relative tests started from this host
        foreach $recv ( keys %{ $msetdesc->{'RECEIVERS'} } ) {

            #
            # If recv is not the localnode currently doing, skip.
            #
            next if ( $me ne $recv );

            next if (
                !(
                    $myaddr = $conf->get_val(
                        NODE => $me,
                        TYPE => $msetdesc->{'ADDRTYPE'},
                        ATTR => 'ADDR'
                    )
                )
            );

            my ( $rhost, $rport ) = split_addr( $myaddr );
            if ( !defined( $rhost ) ) {
                die "Invalid bwctld addr:port value: $myaddr";
            }
            if ( !defined( $rport ) ) {
                $raddr = $rhost;
            }
            else {
                $raddr = "[$rhost]:$rport";
            }

            foreach $send ( @{ $msetdesc->{'RECEIVERS'}->{$recv} } ) {
                my $starttime;

                # bwctl always excludes self tests.
                next if ( $recv eq $send );

                next if (
                    !(
                        $oaddr = $conf->get_val(
                            NODE => $send,
                            TYPE => $msetdesc->{'ADDRTYPE'},
                            ATTR => 'ADDR'
                        )
                    )
                );

                my ( $shost, $sport ) = split_addr( $oaddr );
                if ( !defined( $shost ) ) {
                    die "Invalid bwctld addr:port value: $oaddr";
                }
                if ( !defined( $sport ) ) {
                    $saddr = $shost;
                }
                else {
                    $saddr = "[$shost]:$sport";
                }

                my ( $bindaddr ) = $rhost;

                warn "Starting Test=$send:$saddr ===> $recv:$raddr\n" if ( defined( $debug ) );
                $starttime = OWP::Utils::time2owptime( time );
                $pid = bwctl( $msetdesc, $bindaddr, $recv, $raddr, $send, $saddr );
                @{ $pid2info{$pid} } = ( "bwctl", $starttime, $msetdesc, $bindaddr, $recv, $raddr, $send, $saddr );
            }
        }

        # determine path for send-relative tests started from this host
        # (If the remote host does not run bwmaster.)
        foreach $send ( keys %{ $msetdesc->{'SENDERS'} } ) {

            #
            # If send is not the localnode currently doing, skip.
            #
            next if ( $me ne $send );

            #
            # If send does not have appropriate addrtype, skip.
            next if (
                !(
                    $myaddr = $conf->get_val(
                        NODE => $me,
                        TYPE => $msetdesc->{'ADDRTYPE'},
                        ATTR => 'ADDR'
                    )
                )
            );
            my ( $shost, $sport ) = split_addr( $myaddr );
            if ( !defined( $shost ) ) {
                die "Invalid bwctld addr:port value: $myaddr";
            }
            if ( !defined( $sport ) ) {
                $saddr = $shost;
            }
            else {
                $saddr = "[$shost]:$sport";
            }

            foreach $recv ( @{ $msetdesc->{'SENDERS'}->{$send} } ) {
                my $starttime;

                # bwctl always excludes self tests.
                next if ( $recv eq $send );

                # only run 'sender' side tests for noagent receivers
                next if ( !defined( $conf->get_val( NODE => $recv, ATTR => 'NOAGENT' ) ) );

                next if (
                    !(
                        $oaddr = $conf->get_val(
                            NODE => $recv,
                            TYPE => $msetdesc->{'ADDRTYPE'},
                            ATTR => 'ADDR'
                        )
                    )
                );

                my ( $rhost, $rport ) = split_addr( $oaddr );
                if ( !defined( $rhost ) ) {
                    die "Invalid bwctld addr:port value: $oaddr";
                }
                if ( !defined( $rport ) ) {
                    $raddr = $rhost;
                }
                else {
                    $raddr = "[$rhost]:$rport";
                }

                my ( $bindaddr ) = $shost;

                warn "Starting Test=$send:$saddr ===> $recv:$raddr\n" if ( defined( $debug ) );
                $starttime = OWP::Utils::time2owptime( time );
                $pid = bwctl( $msetdesc, $bindaddr, $recv, $raddr, $send, $saddr );
                @{ $pid2info{$pid} } = ( "bwctl", $starttime, $msetdesc, $bindaddr, $recv, $raddr, $send, $saddr );

            }
        }
    }
}

#
# Main control loop. Gets uptime reports from all other nodes. If it notices
# a node has restarted since a current bwctl has been notified, it sends
# a HUP to that bwctl to make it reset tests with that node.
# This loop also watches all child processes and restarts them as necessary.
MESSAGE:
while ( 1 ) {
    my $funcname;
    my $fullmsg;

    $@ = '';
    if ( $reset || $die ) {
        if ( $reset == 1 ) {
            $reset++;
            warn "Handling SIGHUP... Stop processing...\n";
        }
        elsif ( $die == 1 ) {
            $die++;
            warn "Exiting... Deleting sub-processes...\n";
            my $pidlist = join " ", keys %pid2info;
            warn "Deleting: $pidlist" if ( defined( $debug ) );
        }
        $funcname  = "kill";
        kill 'TERM', keys %pid2info;
    }
    elsif ( $sigchld ) {
        ;
    }
    else {
        # sleep until a signal wakes us
        $funcname  = "select";
        $interrupt = 1;
        eval { select( undef, undef, undef, undef ) };
        $interrupt = 0;
    }
    for ( $@ ) {
        ( /^$/ || /^SIG/ ) and last;
        last if ( $! == EINTR );
        die "$funcname(): $!";
    }

    #
    # Signal received - update run-state.
    #
    my $wpid;
    $sigchld = 0;
    while ( ( $wpid = waitpid( -1, WNOHANG ) ) > 0 ) {
        next unless ( exists $pid2info{$wpid} );

        my $info = $pid2info{$wpid};
        warn( "$$info[0]:$wpid exited: $?" ) if ( $debug );

        #
        # Remove old state for this pid
        #
        delete $pid2info{$wpid};

        #
        # Unless exiting or restarting, restart
        # processes
        #
        unless ( $reset || $die ) {
            # restart everything if send_data died.
            if ( $$info[0] =~ /send_data/ ) {
                warn "send_data($wpid) died, restarting!";
                kill 'HUP', $$;
            }
            elsif ( $$info[0] =~ /bwctl/ ) {
                shift @$info;
                shift @$info;

                # $$info[2] is now "node"
                warn "Restart bwctl->$$info[2]:!";

                my $starttime = OWP::Utils::time2owptime( time );
                $pid = bwctl( @$info );
                @{ $pid2info{$pid} } = ( "bwctl", $starttime, @$info );
            }
        }
    }

    if ( $die ) {
        if ( ( keys %pid2info ) > 0 ) {
            next;
        }
        die "Dead\n";
    }
    elsif ( $reset ) {
        next if ( ( keys %pid2info ) > 0 );
        warn "Restarting...: ".$FindBin::Bin. "/" . $FindBin::Script." ".join(" ", @SAVEARGV);
        exec $FindBin::Bin. "/" . $FindBin::Script, @SAVEARGV;
    }
}

my ( $SendServer ) = undef;

sub OpenServer {
    return if ( defined $SendServer );

    eval {
        local $SIG{'__DIE__'}  = sub { die $_[0]; };
        local $SIG{'__WARN__'} = sub { die $_[0]; };
        $SendServer = IO::Socket::INET->new(
            PeerAddr => $central_host,
            PeerPort => $central_port,
            Type     => SOCK_STREAM,
            Timeout  => $timeout,
            Proto    => 'tcp'
        );
    };

    if ( $@ ) {
        warn "Unable to contact Home($central_host):$@\n";
    }

    return;
}

sub fail_server {
    my ( $nbytes, $message ) = @_;
    return undef if ( !defined $SendServer );

    $message = "" if ( !$message );
    warn "Server socket unwritable: $message : Closing";
    $SendServer->close;
    undef $SendServer;

    return undef;
}

sub txfr {
    my ( $fh, $fname, %req ) = @_;
    my ( %resp );

    OpenServer;
    if ( !$SendServer ) {
        warn "Server currently unreachable..." if defined( $verbose );
        return undef;
    }

    my ( $line ) = "BW 2.0";
    $MD5->reset;
    return undef if (
        !sys_writeline(
            FILEHANDLE => $SendServer,
            LINE       => $line,
            MD5        => $MD5,
            TIMEOUT    => $timeout,
            CALLBACK   => \&fail_server
        )
    );
    foreach ( keys %req ) {
        my $val = $req{$_};
        warn "req\{$_\} = $val" if ( $debug );
        return undef            if (
            !sys_writeline(
                FILEHANDLE => $SendServer,
                LINE       => "$_\t$req{$_}",
                MD5        => $MD5,
                TIMEOUT    => $timeout,
                CALLBACK   => \&fail_server
            )
        );
    }
    return undef if (
        !sys_writeline(
            FILEHANDLE => $SendServer,
            TIMEOUT    => $timeout,
            CALLBACK   => \&fail_server
        )
    );
    $MD5->add( $secret );
    return undef if (
        !sys_writeline(
            FILEHANDLE => $SendServer,
            TIMEOUT    => $timeout,
            CALLBACK   => \&fail_server,
            LINE       => $MD5->hexdigest
        )
    );
    return undef if (
        !sys_writeline(
            FILEHANDLE => $SendServer,
            TIMEOUT    => $timeout,
            CALLBACK   => \&fail_server
        )
    );
    my ( $len ) = $req{'FILESIZE'};
RLOOP:
    while ( $len ) {

        # local read errors are fatal
        my ( $written, $buf, $rlen, $offset );
        undef $rlen;
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            local $SIG{PIPE} = sub { die "pipe\n" };
            alarm $timeout;
            $rlen = sysread $fh, $buf, $len;
            alarm 0;
        };
        if ( !defined( $rlen ) ) {
            if ( ( $! == EINTR ) && ( $@ ne "alarm\n" ) && ( $@ ne "pipe\n" ) ) {
                next RLOOP;
            }
            die "Error reading $fname: $!";
        }
        if ( $rlen < 1 ) {
            die "0 length read from $fname: $!\n";
        }
        $len -= $rlen;
        $offset = 0;
    WLOOP:
        while ( $rlen ) {

            # socket write errors cause eventual retry.
            undef $written;
            eval {
                local $SIG{ALRM} = sub { die "alarm\n" };
                local $SIG{PIPE} = sub { die "pipe\n" };
                alarm $timeout;
                $written = syswrite $SendServer, $buf, $rlen, $offset;
                alarm 0;
            };
            if ( !defined( $written ) ) {
                if ( ( $! == EINTR ) && ( $@ ne "alarm\n" ) && ( $@ ne "pipe\n" ) ) {
                    next WLOOP;
                }
                return fail_server;
            }
            if ( $written < 1 ) {
                die "0 length write to socket: $!\n";
            }
            $rlen -= $written;
            $offset += $written;
        }
    }

    $MD5->reset;
    my ( $pname, $pval );
    while ( 1 ) {
        $_ = sys_readline( FILEHANDLE => $SendServer, TIMEOUT => $timeout );
        if ( defined $_ ) {
            last if ( /^$/ );    # end of message
            $MD5->add( $_ );
            next if ( /^\s*#/ );    # comments
            next if ( /^\s*$/ );    # blank lines

            if ( ( $pname, $pval ) = /^(\w+)\s+(.*)/o ) {
                $pname =~ tr/a-z/A-Z/;
                $resp{$pname} = $pval;
                next;
            }

            # Invalid message!
            warn( "Invalid message \"$_\" from server!" );
        }
        else {
            warn( "Socket closed to server!" );
        }
        return fail_server;
    }
    $MD5->add( $secret );
    if ( $MD5->hexdigest ne sys_readline( FILEHANDLE => $SendServer, TIMEOUT => $timeout ) ) {
        warn( "Invalid MD5 for server response!" );
        return fail_server;
    }
    if ( "" ne sys_readline( FILEHANDLE => $SendServer, TIMEOUT => $timeout ) ) {
        warn( "Invalid End Message from Server!" );
        return fail_server;
    }

    return \%resp;
}

my %mscache;

sub send_file {
    my ( $fname ) = @_;
    my ( %req, $response );
    local *SENDFILE;

    warn "SEND_FILE:$fname\n" if defined( $verbose );

    open( SENDFILE, "<" . $fname ) || die "Unable to open $fname";
    binmode SENDFILE;

    # compute the md5 of the file.
    $MD5->reset;
    $MD5->addfile( *SENDFILE );
    $req{'FILEMD5'} = $MD5->hexdigest();

    $req{'FILESIZE'} = sysseek SENDFILE, 0, SEEK_END;

    # seek the file to the beginning for transfer
    return undef
        if ( !$req{'FILESIZE'} || !sysseek SENDFILE, 0, SEEK_SET );

    if ( $req{'FILESIZE'} < 1 ) {
        warn "Ignoring empty file: $fname";
        goto DONE;
    }

    # TODO: parse file and set "summary" variables to send.
    # TODO: all testspec stuff being added into $req here could be cached
    #       and added in req in one statement (could be easier to make
    #       protocol specific plugin to combine owamp/bwctl...

    # Send testspec information
    my ( $fttime, $dir ) = fileparse( $fname, $suffix );
    $dir =~ s#/$##;
    my ( $msname, $recv, $send ) = ( $dir =~ m#([^/]+)/([^/]+)/([^/]+)$# );
    die "Unable to decode Mesh-Path from filepath $dir" if ( !$msname );

    my $ms;
    if ( !( $ms = $mscache{$msname} ) ) {
        $ms = $mscache{$msname} = new OWP::MeasSet(
            CONF           => $conf,
            MEASUREMENTSET => $msname
        );
    }
    die "Unable to create MeasSet for MEASUREMENTSET $msname" if !defined( $ms );

    $req{'MEASUREMENTSET'} = $msname;
    $req{'DESCRIPTION'}    = $ms->{'DESCRIPTION'} || $msname;
    $req{'ADDRTYPE'}       = $ms->{'ADDRTYPE'};
    $req{'TOOL'}           = $conf->must_get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'TOOL'
    );
    $req{'TIMESTAMP'} = $fttime;

    # XXX: Add RECVHOST/SENDHOST - need dns interaction so not yet...
    # Plus - probably want to add some caching for all this stuff.
    $req{'RECVNODE'} = $recv;
    $req{'RECVADDR'} = $conf->must_get_val(
        NODE => $recv,
        ATTR => 'ADDR',
        TYPE => $ms->{'ADDRTYPE'}
    );
    $req{'RECVLONGNAME'} = $conf->get_val(
        NODE => $recv,
        ATTR => 'LONGNAME',
        TYPE => $ms->{'ADDRTYPE'}
    ) || $req{'RECVNODE'};

    $req{'SENDNODE'} = $send;
    $req{'SENDADDR'} = $conf->must_get_val(
        NODE => $send,
        ATTR => 'ADDR',
        TYPE => $ms->{'ADDRTYPE'}
    );
    $req{'SENDLONGNAME'} = $conf->get_val(
        NODE => $send,
        ATTR => 'LONGNAME',
        TYPE => $ms->{'ADDRTYPE'}
    ) || $req{'SENDNODE'};

    #TODO: make this plugable - each 'tool' can add appropriate args
    my $val;

    if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWTestDuration'
        )
        )
    {
        $req{'BWTESTDURATION'} = $val;
    }

    if (
        $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWUDP'
        )
        )
    {
        $req{'BWUDP'} = 1;
        if (
            $val = $conf->get_val(
                TESTSPEC => $ms->{'TESTSPEC'},
                ATTR     => 'BWUDPBandwidthLimit'
            )
            )
        {
            $req{'BWUDPBANDWIDTHLIMIT'} = $val;
        }
    }

    if (
        $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWTCP'
        )
        )
    {
        $req{'BWTCP'} = 1;
    }

    if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWBufferLen'
        )
        )
    {
        $req{'BWBUFFERLEN'} = $val;
    }

    if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWWindowSize'
        )
        )
    {
        $req{'BWWINDOWSIZE'} = $val;
    }

    # Set all the req options.
    $req{'OP'}         = 'TXFR';
    $req{'SECRETNAME'} = $secretname;

    return undef if ( !( $response = txfr( \*SENDFILE, $fname, %req ) ) );

    return undef if ( !exists $response->{'FILEMD5'}
        || ( $response->{'FILEMD5'} ne $req{'FILEMD5'} ) );

DONE:

    unlink $fname || warn "unlink: $!";

    return 1;
}

# TODO: Check to determine if sender paths will mess this up
sub send_data {
    my ( $conf, $rfd, @dirlist ) = @_;

    # @flist is the workque.
    my ( @flist, $ldir );
    foreach $ldir ( @dirlist ) {
        local *DIR;
        opendir( DIR, $ldir ) || die "can't opendir $_:$!";
        push @flist, map { join '/', $ldir, $_ }
            grep {/$suffix$/} readdir( DIR );
        closedir DIR;
    }

    #
    # Sort the list by "start time" of the sessions instead of
    # by directory so data is sent to central server in a more
    # time relevant way.
    #
    if ( @flist ) {

        sub bystart {
            my ( $astart ) = ( $a =~ m#/(\d+)$suffix$# );
            my ( $bstart ) = ( $b =~ m#/(\d+)$suffix$# );

            return $astart <=> $bstart;
        }
        @flist = sort bystart @flist;
    }

    my $pid = fork;

    # error
    die "Can't fork send_data: $!" if ( !defined( $pid ) );

    #parent
    return $pid if ( $pid );

    # child continues.
    $0 = "$scriptname:send_data";
    $SIG{INT} = $SIG{TERM} = $SIG{HUP} = $SIG{CHLD} = 'DEFAULT';
    $SIG{PIPE} = 'IGNORE';
    my $nomask = new POSIX::SigSet;
    exit if ( sigprocmask( SIG_SETMASK, $nomask ) != 0 );

    open( STDIN, "<&=$rfd" ) || die "Can't fdopen read end of pipe";

    warn "Redirected STDIN from pipe" if ( $debug );
    my ( $rin, $rout, $ein, $eout, $tmout, $nfound );

    $rin = '';
    vec( $rin, $rfd, 1 ) = 1;
    $ein = $rin;

SEND_FILES:
    while ( 1 ) {

        if ( scalar @flist ) {

            # only poll with select if we have work to do.
            $tmout = 0;
        }
        else {
            undef $tmout;
        }

        warn "Calling select with tmout=", $tmout ? $tmout : "nil"
            if ( $debug );
        if ( $nfound = select( $rout = $rin, undef, $eout = $ein, $tmout ) ) {
            my $newfile = sys_readline();
            warn "push \@flist, $newfile" if ( $debug );
            push @flist, $newfile;
            next SEND_FILES;
        }

        next if ( !scalar @flist );

        my ( $nextfile ) = ( $flist[0] =~ /^(.*)$/ );
        if ( send_file( $nextfile ) ) {
            shift @flist;
        }
        else {

            # upload not working.. wait before trying again.
            warn "Unable to send $nextfile" if ( $verbose );
            sleep $timeout;
        }
    }
}

sub bwctl {
    my ( $ms, $myaddr, $recv, $raddr, $send, $saddr ) = @_;
    local ( *CHWFD, *CHRFD );
    my $val;
    my @cmd = ( $bwcmd, "-T", "iperf", "-e", $facility, "-p", "-B", $myaddr );
    if ( defined( $debug ) ) {
        push @cmd, ( "-rvv" );
    }
    else {
        push @cmd, ( "-q" );
    }

    push @cmd, ( "-R", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWTestIntervalStartAlpha'
        )
    );
    push @cmd, ( "-I", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWTestInterval'
        )
    );
    push @cmd, ( "-i", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWReportInterval'
        )
    );

    #
    # bwmaster uses the -W instead of -w so the window size is configured
    # dynamically if possible.
    #
    push @cmd, ( "-W", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWWindowSize'
        )
    );

    if ( $conf->get_val( TESTSPEC => $ms->{'TESTSPEC'}, ATTR => 'BWUDP' ) ) {
        if ( $conf->get_val( TESTSPEC => $ms->{'TESTSPEC'}, ATTR => 'BWTCP' ) ) {
            die "Conflicting BWTCP/BWUDP parameters TESTSPEC=$ms->{'TESTSPEC'}";
        }

        push @cmd, ( "-u" );
        push @cmd, ( "-b", $val ) if (
            $val = $conf->get_val(
                TESTSPEC => $ms->{'TESTSPEC'},
                ATTR     => 'BWUDPBandwidthLimit'
            )
        );
    }

    push @cmd, ( "-S", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWTosBits'
        )
    );

    push @cmd, ( "-l", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWBufferLen'
        )
    );
    push @cmd, ( "-t", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'BWTestDuration'
        )
    );
    push @cmd, ( "-d", "$ms->{'MEASUREMENTSET'}/$recv/$send", "-s", $saddr, "-c", $raddr );

    my $cmd = join " ", @cmd;
    warn "Executing: $cmd" if ( defined( $debug ) );

    open( \*CHWFD, ">&WRITEPIPE" ) || die "Can't dup pipe";
    open( \*CHRFD, "<$devnull" )   || die "Can't open $devnull";
    my $bwpid = open3( "<&CHRFD", ">&CHWFD", ">&STDERR", @cmd );

    return $bwpid;
}

1;

__END__

=head1 SEE ALSO

L<FindBin>, L<Getopt::Std>, L<POSIX>, L<IPC::Open3>, L<File::Path>,
L<File::Basename>, L<FileHandle>, L<OWP>, L<OWP::Helper>, L<OWP::MeasSet>,
L<OWP::RawIO>, L<OWP::Syslog>, L<Sys::Syslog>, L<Digest::MD5>, L<Socket>,
L<IO::Socket>, L<Fcntl>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: bwmaster.pl 4020 2010-04-07 17:42:18Z aaron $

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
