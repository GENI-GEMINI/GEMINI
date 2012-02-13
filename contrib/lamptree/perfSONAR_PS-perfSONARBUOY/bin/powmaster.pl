#!/usr/bin/perl -w
# ex: set tabstop=4 ai expandtab softtabstop=4 shiftwidth=4:
# -*- mode: c-basic-indent: 4; tab-width: 4; indent-tabs-mode: nil -*-

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

powmaster.pl - Control OWAMP measurement in perfSONAR-BUOY

=head1 DESCRIPTION

Using the owmesh.conf file as a guide, perform specified measurements and store
the results in a database.  This script is to be run on machines that will
perform measurements.  

=head1 SYNOPSIS

powmaster.pl [B<-c> confdir/][B<-n> nodename][B<-Z>][B<-x>][B<-h>][B<-k>][B<-d>][B<-v>]

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
use OWP::Sum;
use OWP::RawIO;
use OWP::MeasSet;
use OWP::Syslog;
use OWP::Helper;
use Sys::Syslog;
use Digest::MD5;
use Socket;
use IO::Socket;
use Fcntl qw(:flock);
use Params::Validate qw(:all);

my @SAVEARGV = @ARGV;
my %options  = (
    CONFDIR    => "c:",
    LOCALNODES => "n:",
    FOREGROUND => "Z",
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

my $conf  = new OWP::Conf( %amidefaults );
my $ttype = 'OWP';

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
    my $pidfile = new FileHandle "$datadir/powmaster.pid", O_RDONLY;
    die "Unable to open($datadir/powmaster.pid): $!"
        unless ( $pidfile );

    my $pid = <$pidfile>;
    die "Unable to retrieve PID from $datadir/powmaster.pid"
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
my $owpsuffix = $conf->must_get_val( ATTR => "SessionSuffix", TYPE => $ttype );
my $sumsuffix = $conf->must_get_val( ATTR => "SummarySuffix", TYPE => $ttype );

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
my $powcmd = $conf->must_get_val( ATTR => "BinDir", TYPE => $ttype );
$powcmd .= "/";
$powcmd .= $conf->must_get_val( ATTR => "cmd", TYPE => $ttype );

#
# pid2info - used to determine nature of child process that dies.
my ( %pid2info, $dir );

#
# First determine the set of tests that need to be configured from this
# host.
#
my @powtests = $conf->get_list(
    LIST  => 'TESTSPEC',
    ATTR  => 'TOOL',
    VALUE => 'powstream'
);

if ( defined( $debug ) ) {
    warn "Found " . scalar( @powtests ) . " powstream related TESTSPEC blocks";
}

#
# now find the actual measurement sets
#
my ( @meassets, $ttest );
foreach $ttest ( @powtests ) {
    push @meassets,
        $conf->get_list(
        LIST  => 'MEASUREMENTSET',
        ATTR  => 'TESTSPEC',
        VALUE => $ttest
        );
}

if ( defined( $debug ) ) {
    warn "Found " . scalar( @meassets ) . " powstream related MEASUREMENTSET blocks";
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
    # XXX: Need to implement this in powcollector still!
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

                # bwctl always excludes self tests, but powstream doesn't.
                # XXX: Need to add a 'tool' definition somewhere where
                # defaults like 'tool-can-do-self-tests' can be
                # specified
                # next if ( $recv eq $send );

                push @dirlist, "$mset/$recv/$send";
            }
        }

        # determine path for send-relative tests started from this host
        # (If the remote host does not run powmaster.)
        foreach $send ( keys %{ $msetdesc->{'SENDERS'} } ) {

            #
            #
            # If send is not the localnode currently doing, skip.
            #
            next if ( $me ne $send );

            foreach $recv ( @{ $msetdesc->{'SENDERS'}->{$send} } ) {

                # bwctl always excludes self tests, but powstream doesn't.
                # XXX: tool def for self-tests again... see above.
                #next if ( $recv eq $send );

                # run 'sender' side tests for noagent receivers
                next if ( !defined( $conf->get_val( NODE => $recv, ATTR => 'NOAGENT' ) ) );

                push @dirlist, "$mset/$recv/$send";
            }
        }
    }
}
die "No tests to be run by the nodes (@localnodes)." if ( !scalar @dirlist );

mkpath( [ map { join '/', $datadir, $_ } @dirlist ], 0, 0775 );

chdir $datadir or die "Unable to chdir to $datadir";

# Wait for chdir to $datadir to test powcmd -x so relative paths checked
die "$powcmd not executable" if ( !-x $powcmd );

my ( $MD5 ) = new Digest::MD5
    or die "Unable to create md5 context";

if ( !$foreground ) {
    daemonize( PIDFILE => 'powmaster.pid', DEVNULL => $devnull )
        or die "Unable to daemonize process";
}

# setup pipe - read side used by send_data, write side used by all
# powsteam children.
my ( $rfd, $wfd ) = POSIX::pipe();
local ( *WRITEPIPE );
open( WRITEPIPE, ">&=$wfd" ) || die "Can't fdopen write end of pipe";

# setup signal handling before starting child processes to catch
# SIG_CHLD
my ( $reset, $death, $sigchld ) = ( 0, 0, 0 );

# interrupt var is used to make signal handler throw a 'die'
# so that perl doesn't restart interrupted system calls.
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
        $death = 1;
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
# and returns. (As powsteam finishes files, send_data adds each file
# to it's work que.)
my $pid = send_data( $conf, $rfd, @dirlist );
@{ $pid2info{$pid} } = ( "send_data" );

#
# powstream setup loop - creates a powstream process for each path that should
# be started from this node. (In general, that is recv-side tests, but
# send-side is started if it is known that the 'other' side is not
# running an agent.
# This sets the STDOUT of powstream to point at the send_data process, so
# that process can forward the data onto the 'collector' running
# at the database.
# (powstream outputs the filenames it produces on stdout.)
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
        
        #get test ports if specified
        my $testports = 0;
        if( defined( $conf->get_val( NODE => $me, ATTR => 'OWPTESTPORTS' ) ) ){
            $testports = $conf->get_val( NODE => $me, ATTR => 'OWPTESTPORTS' );
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
                die "Invalid owampd addr:port value: $myaddr";
            }
            if ( !defined( $rport ) ) {
                $raddr = $rhost;
            }
            else {
                $raddr = "[$rhost]:$rport";
            }

            foreach $send ( @{ $msetdesc->{'RECEIVERS'}->{$recv} } ) {
                my $starttime;

                # bwctl always excludes self tests, but powstream doesn't.
                # XXX: Add tool config!
                # next if ( $recv eq $send );

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
                    die "Invalid owampd addr:port value: $oaddr";
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
                my $powstream_args = { measurement_set => $msetdesc, local_node => $me, local_address => $bindaddr, remote_node => $send, remote_address => $saddr, test_ports => $testports, do_send => 0 };
                $pid = powstream(%$powstream_args);
                @{ $pid2info{$pid} } = ( "powstream", $starttime, $powstream_args );
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
                die "Invalid owampd addr:port value: $myaddr";
            }
            if ( !defined( $sport ) ) {
                $saddr = $shost;
            }
            else {
                $saddr = "[$shost]:$sport";
            }

            foreach $recv ( @{ $msetdesc->{'SENDERS'}->{$send} } ) {
                my $starttime;

                # bwctl always excludes self tests, but powstream doesn't.
                # XXX: Add tool config!
                # next if ( $recv eq $send );

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

                my $powstream_args = { measurement_set => $msetdesc, local_node => $me, local_address => $bindaddr, remote_node => $recv, remote_address => $raddr, test_ports => $testports, do_send => 1 };
                $pid = powstream(%$powstream_args);
                @{ $pid2info{$pid} } = ( "powstream", $starttime, $powstream_args );

            }
        }
    }
}

#
# Main control loop. Gets uptime reports from all other nodes. If it notices
# a node has restarted since a current powstream has been notified, it sends
# a HUP to that powstream to make it reset tests with that node.
# This loop also watches all child processes and restarts them as necessary.
MESSAGE:
while ( 1 ) {
    my $funcname;
    my $fullmsg;

    $@ = '';
    if ( $reset || $death ) {
        if ( $reset == 1 ) {
            $reset++;
            warn "Handling SIGHUP... Stop processing...\n";
        }
        elsif ( $death == 1 ) {
            $death++;
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
        eval { select( undef, undef, undef, undef ); };
        $interrupt = 0;
    }
    for ( $@ ) {
        last if ( /^$/ || /^SIG/ );
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
        unless ( $reset || $death ) {
            # restart everything if send_data died.
            if ( $$info[0] =~ /send_data/ ) {
                warn "send_data died, restarting!";
                kill 'HUP', $$;
            }
            elsif ( $$info[0] =~ /powstream/ ) {
                my $powstream_args = $info->[2];

                warn "Restart powstream->".$powstream_args->{remote_node}.":!";

                my $starttime = OWP::Utils::time2owptime( time );
                $pid = powstream( %$powstream_args );
                @{ $pid2info{$pid} } = ( "powstream", $starttime, $powstream_args );
            }
        }
    }

    if ( $death ) {
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
    my ( $fh, %req ) = @_;
    my ( %resp );

    OpenServer;
    if ( !$SendServer ) {
        warn "Server currently unreachable..." if defined( $verbose );
        return undef;
    }

    my ( $line ) = "OWP 3.0";
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
    my ( $len ) = 0;
    if ( $req{'OP'} eq 'TXFR' ) {
        $len = $req{'FILESIZE'};
    }
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
            die "Error reading $req{'FILENAME'}: $!";
        }
        if ( $rlen < 1 ) {
            die "0 length read $req{'FILENAME'}: $!";
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
            $rlen -= $written;
            $offset += $written;
        }
    }

    $MD5->reset;
    my ( $pname, $pval );
    while ( 1 ) {
        $_ = sys_readline( FILEHANDLE => $SendServer );
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

    my ( $bname, $path, $suffix ) = fileparse( $fname, ( $owpsuffix, $sumsuffix ) );

    #    my ( $msname, $recv, $send ) = ( $path =~ m#(\w+)/(\w+)/(\w+)/$# );
    my ( $msname, $recv, $send ) = ( $path =~ m#([^\/\s]+)/([^\/\s]+)/([^\/\s]+)/$# );

    die "Unable to decode Mesh-Path from filepath $path" if ( !$msname );

    warn "Sending file from MeasurementSet $msname" if ( $debug );
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
    my ( $fstart, $fend ) = split /_/, $bname;

    $req{'START'} = $fstart;
    $req{'END'}   = $fend;

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

    # XXX: Make this plugable... load a handler per tooltype. Each
    # 'tool' can add appropriate args into the transfer.
    my $val;

    $req{'OWPSESSIONCOUNT'} = $conf->must_get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPSESSIONCOUNT'
    );

    $req{'OWPSAMPLECOUNT'} = $conf->get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPSAMPLECOUNT'
    ) || $req{'OWPSESSIONCOUNT'};

    $req{'OWPINTERVAL'} = $conf->must_get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPINTERVAL'
    );

    $req{'OWPLOSSTHRESH'} = $conf->get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPLOSSTHRESH'
    ) || 10;    # powstream default

    $req{'OWPPACKETPADDING'} = $conf->get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPPACKETPADDING'
    ) || 0;     # powstream default

    $req{'OWPBUCKETWIDTH'} = $conf->get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPBUCKETWIDTH'
    ) || 0.0001;    # powstream default

    my $opname = $path . $bname . $owpsuffix;
    my $sfname = $path . $bname . $sumsuffix;

TRY:
    {
        if ( $suffix =~ /^$owpsuffix$/ ) {
            open( SENDFILE, "<" . $opname ) || die "Unable to open $opname";
            binmode SENDFILE;

            # compute the md5 of the file.
            $MD5->reset;
            $MD5->addfile( *SENDFILE );
            $req{'FILEMD5'} = $MD5->hexdigest();

            $req{'FILESIZE'} = sysseek SENDFILE, 0, SEEK_END;

            # seek the file to the beginning for transfer
            if ( !$req{'FILESIZE'} || !sysseek SENDFILE, 0, SEEK_SET ) {
                return undef;
            }
            $req{'OP'}    = 'TXFR';
            $req{'FNAME'} = $fname;
        }
        else {

            # Summary info only
            local *SUMFILE;
            if ( open( SUMFILE, "<" . $sfname ) ) {
                if ( !parsesum( \*SUMFILE, \%req ) ) {
                    warn "Invalid Summary: $sfname";
                    if ( defined( $debug ) ) {
                        warn "Start Invalid Summary: $sfname";
                        print_hash( "summary", %req );
                        warn "End Invalid Summary: $sfname";
                    }
                    last TRY;
                }

                #
                # Data validation
                #
                if ( !defined( $req{'SUMMARY'} ) ) {
                    if ( defined( $verbose ) ) {
                        warn "Skipping $sfname: Invalid summary information";
                    }
                    last TRY;
                }
                if ( $req{'SUMMARY'} < 3.0 ) {
                    if ( defined( $verbose ) ) {
                        warn "Skipping $sfname: Invalid summary - upgrade owamp (powstream)? ";
                    }
                    last TRY;
                }

                # Only want to send sum sessions
                # back if SAMPLE_PACKET_COUNT == OWPSAMPLECOUNT
                #

                if ( $req{'SAMPLE_PACKET_COUNT'} != $req{'OWPSAMPLECOUNT'} ) {
                    if ( defined( $verbose ) ) {
                        warn "Skipping $sfname: (unneeded dataset)";
                    }
                    last TRY;
                }
                $req{'OP'} = 'SUM';
            }
            else {
                warn "Sum file $sfname unreadable: $!\n" if defined( $verbose );
                undef $sfname;
                last TRY;
            }
        }

        # Set all the req options.
        $req{'SECRETNAME'} = $secretname;

        if ( !( $response = txfr( \*SENDFILE, %req ) ) ) {
            warn "txfr() failed to transfer information to $central_host";
            return undef;
        }

        if (
            exists $req{'FILEMD5'}
            && ( !exists $response->{'FILEMD5'}
                || ( $response->{'FILEMD5'} ne $req{'FILEMD5'} ) )
            )
        {
            warn "MD5 data validation failed in transfer to $central_host";
            return undef;
        }
    }

    if ( defined( $opname ) ) {
        if ( defined( $debug ) && ( $debug > 1 ) ) {
            rename $opname, $opname . ".debug";
        }
        else {
            unlink $opname || warn "unlink: $!";
        }
    }
    if ( defined( $sfname ) ) {
        if ( defined( $debug ) && ( $debug > 1 ) ) {
            rename $sfname, $sfname . ".debug";
        }
        else {
            unlink $sfname || warn "unlink: $!";
        }
    }

    warn "Done SEND_FILE:$fname\n" if defined( $verbose );

    return 1;
}

sub send_data {
    my ( $conf, $rfd, @dirlist ) = @_;

    # @flist is the workque.
    my ( @flist, $ldir );
    foreach $ldir ( @dirlist ) {
        local *DIR;
        opendir( DIR, $ldir ) || die "can't opendir $_:$!";
        push @flist, map { join '/', $ldir, $_ }
            grep {/($owpsuffix|$sumsuffix)$/} readdir( DIR );
        closedir DIR;
    }

    #
    # Sort list with owp/sum files in correct order.
    #
    # If the "end time" match, then the order we want returned
    # for suffixes is as follows:
    #
    #   A   B
    #   -----------------------------------------
    #   owp owp     - 0 invalid (dbase will reject)
    #   owp sum     <
    #   sum owp     >
    #   sum sum     - 0 invalid (dbase will reject)
    #
    if ( @flist ) {

        sub byend {
            my ( $aend, $asuffix ) = ( $a =~ m#/\d+_(\d+)($owpsuffix|$sumsuffix)$# );
            my ( $bend, $bsuffix ) = ( $b =~ m#/\d+_(\d+)($owpsuffix|$sumsuffix)$# );

            return ( ( $aend <=> $bend ) || ( $asuffix cmp $sumsuffix ) || ( $asuffix cmp $owpsuffix ) );
        }
        @flist = sort byend @flist;
    }

    if ( defined( $debug ) && ( $debug > 1 ) ) {
        warn "Sorted file list:\n";
        foreach ( @flist ) {
            warn "$_\n";
        }
        warn "End file list\n";
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

    open( STDIN, "<&=$rfd" ) || die "Can't fdopen read end of pipe";

    my ( $rin, $rout, $ein, $eout, $tmout, $nfound );

    $rin = '';
    vec( $rin, $rfd, 1 ) = 1;
    $ein = $rin;

SEND_DATA:
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
            push @flist, $newfile;
            next SEND_DATA;
        }

        next if ( !scalar @flist );

        my ( $nextfile ) = ( $flist[0] =~ /^(.*)$/ );
        if ( send_file( $nextfile ) ) {
            shift @flist;
        }
        else {

            # upload not working.. wait before trying again.
            warn "Unable to send $nextfile" if ( $verbose || $debug );
            sleep $timeout;
        }
    }
}

# XXX: Create a configuration validity module, and move below checks there.
# (Want it to happen before forking, and done once instead of for each
# process.)
sub powstream {
    my $args = validate(@_, { measurement_set => 1, local_node => 1, local_address => 1, remote_node => 1, remote_address => 1, test_ports => 1, do_send => 1 });

    my $ms = $args->{measurement_set};
    my $me = $args->{local_node};
    my $myaddr = $args->{local_address};
    my $onode = $args->{remote_node};
    my $oaddr = $args->{remote_address};
    my $testports = $args->{test_ports};
    my $do_send = $args->{do_send};

    local ( *CHWFD, *CHRFD );
    my $val;

    my $interval = $conf->must_get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPINTERVAL'
    );
    if ( $interval < 0 ) {
        die "TestSpec($ms->{'TESTSPEC'}): OWPINTERVAL must be greater than 0";
    }

    my $packet_count = $conf->must_get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPSESSIONCOUNT'
    );

    my @cmd = ( $powcmd, "-e", $facility, "-p", "-S", $myaddr );
    push @cmd, ( "-i", $interval );
    push @cmd, ( "-c", $packet_count );
    push @cmd, ( "-P", $testports ) if ($testports);

    if ( $do_send ) {
        push @cmd, ( "-t" );
        push @cmd, ( "-d", "$ms->{'MEASUREMENTSET'}/$onode/$me" );
    }
    else {
        push @cmd, ( "-d", "$ms->{'MEASUREMENTSET'}/$me/$onode" );
    }

    my $sample_count = $conf->get_val(
        TESTSPEC => $ms->{'TESTSPEC'},
        ATTR     => 'OWPSAMPLECOUNT'
    ) || $packet_count;

    if ( $packet_count % $sample_count ) {
        die "TestSpec($ms->{'TESTSPEC'}): OWPSAMPLECOUNT must be an even multiple of OWPSESSIONCOUNT";
    }
    if ( $sample_count > $packet_count ) {
        die "TestSpec($ms->{'TESTSPEC'}): OWPSESSIONCOUNT must be greater than OWPSAMPLECOUNT";
    }

    push @cmd, ( "-N", $sample_count );

    push @cmd, ( "-L", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'OWPLOSSTHRESH'
        )
    );
    push @cmd, ( "-s", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'OWPPACKETPADDING'
        )
    );
    push @cmd, ( "-b", $val ) if (
        $val = $conf->get_val(
            TESTSPEC => $ms->{'TESTSPEC'},
            ATTR     => 'OWPBUCKETWIDTH'
        )
    );

    push @cmd, ( $oaddr );

    my $cmd = join " ", @cmd;
    warn "Executing: $cmd" if ( defined( $debug ) );

    open( \*CHWFD, ">&WRITEPIPE" ) || die "Can't dup pipe";
    open( \*CHRFD, "<$devnull" )   || die "Can't open $devnull";
    my $powpid = open3( "<&CHRFD", ">&CHWFD", ">&STDERR", @cmd );

    return $powpid;
}

1;

__END__

=head1 SEE ALSO

L<FindBin>, L<Getopt::Std>, L<POSIX>, L<IPC::Open3>, L<File::Path>,
L<File::Basename>, L<FileHandle>, L<OWP>, L<OWP::Sum>, L<OWP::RawIO>,
L<OWP::MeasSet>, L<OWP::Syslog>, L<OWP::Helper>, L<Sys::Syslog>,
L<Digest::MD5>, L<Socket>, L<IO::Socket>, L<DB_File>, L<Fcntl>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: powmaster.pl 4020 2010-04-07 17:42:18Z aaron $

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
