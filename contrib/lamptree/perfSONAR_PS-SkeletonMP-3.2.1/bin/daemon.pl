#!/usr/bin/perl -w -I ./lib ../lib

use warnings;
use strict;

our $VERSION = 3.2;

=head1 NAME

perfsonar-daemon.pl - The main daemon that dispatches requests to the backend
perfSONAR-PS functionality.

=head1 DESCRIPTION

Each perfSONAR-PS module should be designed to be run by this daemon.  

=head1 SYNOPSIS

./perfsonar-daemon.pl [--verbose --help --config=config.file --piddir=/path/to/pid/dir --pidfile=filename.pid --logger=logger.conf --user=[user to run as] --group=[group to run as]]\n";

=cut

use Getopt::Long;
use Time::HiRes qw( gettimeofday );
use POSIX qw( setsid );
use File::Basename;
use Fcntl qw(:DEFAULT :flock);
use POSIX ":sys_wait_h";
use Cwd;
use Config::General;
use Module::Load;
use HTTP::Daemon;
use English '-no_match_vars';
use Carp;

use FindBin qw($Bin);
use lib "$Bin/../lib";

my $confdir = "$Bin/../etc";

my %ns = (
    nmwg          => "http://ggf.org/ns/nmwg/base/2.0/",
    nmtm          => "http://ggf.org/ns/nmwg/time/2.0/",
    ifevt         => "http://ggf.org/ns/nmwg/event/status/base/2.0/",
    iperf         => "http://ggf.org/ns/nmwg/tools/iperf/2.0/",
    bwctl         => "http://ggf.org/ns/nmwg/tools/bwctl/2.0/",
    owamp         => "http://ggf.org/ns/nmwg/tools/owamp/2.0/",
    netutil       => "http://ggf.org/ns/nmwg/characteristic/utilization/2.0/",
    neterr        => "http://ggf.org/ns/nmwg/characteristic/errors/2.0/",
    netdisc       => "http://ggf.org/ns/nmwg/characteristic/discards/2.0/",
    snmp          => "http://ggf.org/ns/nmwg/tools/snmp/2.0/",
    select        => "http://ggf.org/ns/nmwg/ops/select/2.0/",
    average       => "http://ggf.org/ns/nmwg/ops/average/2.0/",
    perfsonar     => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/",
    psservice     => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/",
    xquery        => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/",
    xpath         => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xpath/1.0/",
    nmwgt         => "http://ggf.org/ns/nmwg/topology/2.0/",
    nmwgtopo3     => "http://ggf.org/ns/nmwg/topology/base/3.0/",
    nmwgt3        => "http://ggf.org/ns/nmwg/topology/base/3.0/",
    pinger        => "http://ggf.org/ns/nmwg/tools/pinger/2.0/",
    nmwgr         => "http://ggf.org/ns/nmwg/result/2.0/",
    traceroute    => "http://ggf.org/ns/nmwg/tools/traceroute/2.0/",
    tracepath     => "http://ggf.org/ns/nmwg/tools/traceroute/2.0/",
    ping          => "http://ggf.org/ns/nmwg/tools/ping/2.0/",
    summary       => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/",
    ctrlplane     => "http://ogf.org/schema/network/topology/ctrlPlane/20070707/",
    CtrlPlane     => "http://ogf.org/schema/network/topology/ctrlPlane/20070626/",
    ctrlplane_oct => "http://ogf.org/schema/network/topology/ctrlPlane/20071023/",
    ethernet      => "http://ogf.org/schema/network/topology/ethernet/20070828/",
    ipv4          => "http://ogf.org/schema/network/topology/ipv4/20070828/",
    ipv6          => "http://ogf.org/schema/network/topology/ipv6/20070828/",
    nmtb          => "http://ogf.org/schema/network/topology/base/20070828/",
    nmtl2         => "http://ogf.org/schema/network/topology/l2/20070828/",
    nmtl3         => "http://ogf.org/schema/network/topology/l3/20070828/",
    nmtl4         => "http://ogf.org/schema/network/topology/l4/20070828/",
    nmtopo        => "http://ogf.org/schema/network/topology/base/20070828/",
    nmtb          => "http://ogf.org/schema/network/topology/base/20070828/",
    sonet         => "http://ogf.org/schema/network/topology/sonet/20070828/",
    transport     => "http://ogf.org/schema/network/topology/transport/20070828/"
);

use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Request;
use perfSONAR_PS::RequestHandler;
use perfSONAR_PS::Error_compat qw/:try/;
use perfSONAR_PS::Error;
use perfSONAR_PS::Services::Echo;

my %child_pids = ();

$SIG{CHLD} = \&REAPER;
$SIG{PIPE} = 'IGNORE';
$SIG{ALRM} = 'IGNORE';
$SIG{INT}  = \&signalHandler;
$SIG{TERM} = \&signalHandler;

my $CLEANFLAG   = q{};
my $DEBUGFLAG   = q{};
my $READ_ONLY   = q{};
my $HELP        = q{};
my $CONFIG_FILE = q{};
my $LOGGER_CONF = q{};
my $PIDDIR      = q{};
my $PIDFILE     = q{};
my $LOGOUTPUT   = q{};
my $RUNAS_USER  = q{};
my $RUNAS_GROUP = q{};

my $status = GetOptions(
    'verbose'   => \$DEBUGFLAG,
    'help'      => \$HELP,
    'config=s'  => \$CONFIG_FILE,
    'piddir=s'  => \$PIDDIR,
    'pidfile=s' => \$PIDFILE,
    'logger=s'  => \$LOGGER_CONF,
    'user=s'    => \$RUNAS_USER,
    'group=s'   => \$RUNAS_GROUP,
    'output=s'  => \$LOGOUTPUT,
    'noclean'   => \$CLEANFLAG
);

if ( not $status or $HELP ) {
    print "$0: starts the MA daemon.\n";
    print "\t$0 [--verbose --help --config=config.file --piddir=/path/to/pid/dir --pidfile=filename.pid --logger=logger/filename.conf --user=[user to run as] --group=[group to run as] --output=/path/to/log/output --noclean\n";
    exit( 1 );
}

$CONFIG_FILE = $confdir . "/daemon.conf" unless $CONFIG_FILE;

# The configuration directory gets passed to the modules so that relative paths
# defined in their configurations can be resolved.
$CONFIG_FILE = getcwd . "/" . $CONFIG_FILE unless $CONFIG_FILE =~ /^\//;

$confdir = dirname( $CONFIG_FILE );

# Read in configuration information
my $config = new Config::General( $CONFIG_FILE );
my %conf   = $config->getall;

#
# Check/open the PID file while we're still running as root
#
unless ( $PIDDIR ) {
    if ( exists $conf{"pid_dir"} and $conf{"pid_dir"} ) {
        $PIDDIR = $conf{"pid_dir"};
    }
    else {
        $PIDDIR = "/tmp";
    }
}

unless ( $PIDFILE ) {
    if ( exists $conf{"pid_file"} and $conf{"pid_file"} ) {
        $PIDFILE = $conf{"pid_file"};
    }
    else {
        $PIDFILE = "ps.pid";
    }
}

my $pidfile = lockPIDFile( $PIDDIR, $PIDFILE );

# Check if the daemon should run as a specific user/group and then switch to
# that user/group.
unless ( $RUNAS_GROUP ) {
    $RUNAS_GROUP = $conf{"group"} if exists $conf{"group"} and $conf{"group"};
}

unless ( $RUNAS_USER ) {
    $RUNAS_USER = $conf{"user"} if exists $conf{"user"} and $conf{"user"};
}

if ( $RUNAS_USER and $RUNAS_GROUP ) {
    if ( setids( USER => $RUNAS_USER, GROUP => $RUNAS_GROUP ) != 0 ) {
        print "Error: Couldn't drop priviledges\n";
        exit( -1 );
    }
}
elsif ( $RUNAS_USER or $RUNAS_GROUP ) {

    # they need to specify both the user and group
    print "Error: You need to specify both the user and group if you specify either\n";
    exit( -1 );
}

# Now that we've dropped privileges, create the logger. If we do it in reverse
# order, the daemon won't be able to write to the logger.
my $logger;
if ( not defined $LOGGER_CONF or $LOGGER_CONF eq q{} ) {
    use Log::Log4perl qw(:easy);

    my $output_level = $INFO;
    $output_level = $DEBUG if $DEBUGFLAG;

    my %logger_opts = (
        level  => $output_level,
        layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
    );
    $logger_opts{file} = $LOGOUTPUT if $LOGOUTPUT;

    Log::Log4perl->easy_init( \%logger_opts );
    $logger = get_logger( "perfSONAR_PS" );
}
else {
    use Log::Log4perl qw(get_logger :levels);

    my $output_level;
    $output_level = $DEBUG if $DEBUGFLAG;

    Log::Log4perl->init( $LOGGER_CONF );
    $logger = get_logger( "perfSONAR_PS" );
    $logger->level( $output_level ) if $output_level;
}

unless ( exists $conf{"max_worker_lifetime"} and $conf{"max_worker_lifetime"} ) {
    $logger->warn( "Setting maximum worker lifetime at 60 seconds" );
    $conf{"max_worker_lifetime"} = 60;
}

unless ( exists $conf{"max_worker_processes"} and $conf{"max_worker_processes"} ) {
    $logger->warn( "Setting maximum worker processes at 32" );
    $conf{"max_worker_processes"} = 32;
}

unless ( exists $conf{"listener_queue_size"} and $conf{"listener_queue_size"} ) {
    $logger->warn( "Setting listener queue size to 100" );
    $conf{"listener_queue_size"} = 100;
}

unless ( exists $conf{"ls_registration_interval"} and $conf{"ls_registration_interval"} ) {
    $logger->warn( "Setting LS registration interval at 60 minutes" );
    $conf{"ls_registration_interval"} = 3600;
}

unless ( exists $conf{"disable_echo"} and $conf{"disable_echo"} ) {
    $logger->warn( "Enabling echo service for each endpoint unless specified otherwise" );
    $conf{"disable_echo"} = 0;
}

unless ( exists $conf{"reaper_interval"} and $conf{"reaper_interval"} ) {
    $logger->warn( "Setting reaper interval to 20 seconds" );
    $conf{"reaper_interval"} = 20;
}

$logger->debug( "Starting perfSONAR-PS daemon as '" . $PROCESS_ID . "'" );

my @ls_services;
my @maintenance;
my @collection;
my %loaded_modules = ();
my $echo_module    = "perfSONAR_PS::Services::Echo";

my %handlers        = ();
my %services        = ();
my %listeners       = ();
my %modules_loaded  = ();
my %port_configs    = ();
my %service_configs = ();

unless ( exists $conf{"port"} and $conf{"port"} ) {
    $logger->error( "No ports defined" );
    exit( -1 );
}

$modules_loaded{$echo_module} = 1;

foreach my $port ( keys %{ $conf{"port"} } ) {
    my %port_conf = %{ mergeConfig( \%conf, $conf{"port"}->{$port} ) };

    next if exists $port_conf{"disabled"} and $port_conf{"disabled"} == 1;

    $service_configs{$port} = \%port_conf;

    unless ( exists $conf{"port"}->{$port}->{"endpoint"} and $conf{"port"}->{$port}->{"endpoint"} ) {
        $logger->warn( "No endpoints specified for port $port" );
        next;
    }

    my $listener = HTTP::Daemon->new(
        LocalPort => $port,
        ReuseAddr => 1,
        Timeout   => $port_conf{"reaper_interval"},
        Listen    => $port_conf{"listener_queue_size"},
    );
    if ( not defined $listener != 0 ) {
        $logger->error( "Couldn't start daemon on port $port" );
        exit( -1 );
    }

    $listeners{$port}                     = $listener;
    $handlers{$port}                      = ();
    $services{$port}                      = ();
    $service_configs{$port}->{"endpoint"} = ();

    my $num_endpoints = 0;
    foreach my $key ( keys %{ $conf{"port"}->{$port}->{"endpoint"} } ) {
        my $fixed_endpoint = $key;
        $fixed_endpoint = "/" . $key if $key =~ /^[^\/]/;

        my %endpoint_conf = %{ mergeConfig( \%port_conf, $conf{"port"}->{$port}->{"endpoint"}->{$key} ) };

        $service_configs{$port}->{"endpoint"}->{$fixed_endpoint} = \%endpoint_conf;

        next if exists $endpoint_conf{"disabled"} and $endpoint_conf{"disabled"} == 1;

        $logger->debug( "Adding endpoint $fixed_endpoint to $port" );

        $handlers{$port}->{$fixed_endpoint} = perfSONAR_PS::RequestHandler->new();

        unless ( exists $endpoint_conf{"module"} and $endpoint_conf{"module"} ) {
            $logger->error( "No module specified for $port:$fixed_endpoint" );
            exit( -1 );
        }

        my @endpoint_modules = ();

        if ( ref $endpoint_conf{"module"} eq "ARRAY" ) {
            @endpoint_modules = @{ $endpoint_conf{"module"} };
        }
        else {
            $logger->debug( "Modules is not an array: " . ref( $endpoint_conf{"module"} ) );
            push @endpoint_modules, $endpoint_conf{"module"};
        }

        # the echo module is loaded by default unless otherwise specified
        if ( not $endpoint_conf{"disable_echo"} and not $conf{"disable_echo"} ) {
            my $do_load = 1;
            foreach my $curr_module ( @endpoint_modules ) {
                $do_load = 0 if $curr_module eq $echo_module;
            }

            if ( $do_load ) {
                push @endpoint_modules, $echo_module;
            }
        }

        foreach my $module ( @endpoint_modules ) {
            unless ( exists $modules_loaded{$module} and $modules_loaded{$module} ) {
                load $module;
                $modules_loaded{$module} = 1;
            }

            my $service = $module->new( \%endpoint_conf, $port, $fixed_endpoint, $confdir );
            if ( $service->init( $handlers{$port}->{$fixed_endpoint} ) != 0 ) {
                $logger->error( "Failed to initialize module " . $module . " on $port:$fixed_endpoint" );
                exit( -1 );
            }

            push @{ $services{$port} }, $service;

            if ( $service->needLS() ) {
                my %ls_child_args = ();
                $ls_child_args{"service"}  = $service;
                $ls_child_args{"conf"}     = \%endpoint_conf;
                $ls_child_args{"port"}     = $port;
                $ls_child_args{"endpoint"} = $fixed_endpoint;
                push @ls_services, \%ls_child_args;
            }

            if ( $service->can( "maintenance" ) ) {
                my %maintenance_args = ();
                $maintenance_args{"service"} = $service;
                $maintenance_args{"conf"}    = \%endpoint_conf;
                push @maintenance, \%maintenance_args;
            }

            if ( $service->can( "collection" ) ) {
                my %collection_args = ();
                $collection_args{"service"} = $service;
                $collection_args{"conf"}    = \%endpoint_conf;
                push @collection, \%collection_args;
            }
        }

        $num_endpoints++;
    }

    if ( $num_endpoints == 0 ) {
        $logger->warn( "No endpoints enabled for port $port" );

        delete( $services{$port} );
        delete( $listeners{$port} );
        delete( $handlers{$port} );
        delete( $service_configs{$port} );
    }
}

if ( scalar( keys %listeners ) == 0 ) {
    $logger->error( "No ports enabled" );
    exit( -1 );
}

# Before daemonizing, set die and warn handlers so that any Perl errors or
# warnings make it into the logs.
my $insig = 0;
$SIG{__WARN__} = sub {
    $logger->warn( "Warned: " . join( '', @_ ) );
    return;
};

$SIG{__DIE__} = sub {    ## still dies upon return
    die @_ if $^S;       ## see perldoc -f die perlfunc
    die @_ if $insig;    ## protect against reentrance.
    $insig = 1;
    $logger->error( "Died: " . join( '', @_ ) );
    $insig = 0;
    return;
};

# Daemonize if not in debug mode. This must be done before forking off children
# so that the children are daemonized as well.
if ( not $DEBUGFLAG ) {

    # flush the buffer
    $OUTPUT_AUTOFLUSH = 1;
    &daemonize;
}

$SIG{CHLD} = \&REAPER;

$PROGRAM_NAME = "perfsonar-daemon.pl ($PROCESS_ID)";

foreach my $port ( keys %listeners ) {
    my $pid = fork();
    if ( $pid == 0 ) {
        %child_pids = ();
        $PROGRAM_NAME .= " - Listener ($port)";
        psService( $listeners{$port}, $handlers{$port}, $services{$port}, $service_configs{$port} );
        exit( 0 );
    }
    elsif ( $pid < 0 ) {
        $logger->error( "Couldn't spawn listener child" );
        killChildren();
        exit( -1 );
    }
    else {
        $child_pids{$pid} = q{};
    }
}

foreach my $collection_args ( @collection ) {
    my $collection_pid = fork();
    if ( $collection_pid == 0 ) {
        %child_pids = ();
        $PROGRAM_NAME .= " - Service Data Collection";
        collection( $collection_args );
        exit( 0 );
    }
    elsif ( $collection_pid < 0 ) {
        $logger->error( "Couldn't spawn Service Data Collection" );
        killChildren();
        exit( -1 );
    }
    $child_pids{$collection_pid} = q{};
}

foreach my $maintenance_args ( @maintenance ) {
    my $maintenance_pid = fork();
    if ( $maintenance_pid == 0 ) {
        %child_pids = ();
        $PROGRAM_NAME .= " - Service Maintenance";
        maintenance( $maintenance_args );
        exit( 0 );
    }
    elsif ( $maintenance_pid < 0 ) {
        $logger->error( "Couldn't spawn Service Maintenance" );
        killChildren();
        exit( -1 );
    }
    $child_pids{$maintenance_pid} = q{};
}

foreach my $ls_args ( @ls_services ) {
    my $ls_pid = fork();
    if ( $ls_pid == 0 ) {
        %child_pids = ();
        $PROGRAM_NAME .= " - LS Registration (" . $ls_args->{"port"} . ":" . $ls_args->{"endpoint"} . ")";
        registerLS( $ls_args );
        exit( 0 );
    }
    elsif ( $ls_pid < 0 ) {
        $logger->error( "Couldn't spawn LS Registration" );
        killChildren();
        exit( -1 );
    }
    $child_pids{$ls_pid} = q{};
}

unlockPIDFile( $pidfile );

foreach my $pid ( keys %child_pids ) {
    waitpid( $pid, 0 );
}

=head2 psService

This function will wait for requests using the specified listener. It will then
select the appropriate endpoint request handler, spawn a new process to handle
the request and pass the request to the request handler.  The function also
tracks the processes spawned and kills them if they go on for too long,
responding to the request with an error.

=cut

sub psService {
    my ( $listener, $handlers, $services, $service_config ) = @_;
    my $max_worker_processes;

    $logger->debug( "Starting '" . $PROCESS_ID . "' as a service." );

    $max_worker_processes = $service_config->{"max_worker_processes"};

    while ( 1 ) {
        if ( $max_worker_processes > 0 ) {
            while ( %child_pids and scalar( keys %child_pids ) >= $max_worker_processes ) {
                $logger->debug( "Waiting for a slot to open" );
                my $kid = waitpid( -1, 0 );
                delete $child_pids{$kid} if $kid > 0;
            }
        }

        if ( %child_pids ) {
            my $time = time;

            $logger->debug( "Reaping children (total: " . scalar( keys %child_pids ) . ") at time " . $time );

            # reap any children that have finished or outlived their allotted time
            foreach my $pid ( keys %child_pids ) {
                if ( waitpid( $pid, WNOHANG ) ) {
                    $logger->debug( "Child $pid exited." );
                    delete $child_pids{$pid};
                }
                elsif ( $child_pids{$pid}->{"timeout_time"} <= $time and $child_pids{$pid}->{"child_timeout_length"} > 0 ) {
                    $logger->error( "Pid $pid timed out." );
                    kill 9, $pid;

                    my $msg      = "Timeout occurred, current limit is " . $child_pids{$pid}->{"child_timeout_length"} . " seconds. Try decreasing the breadth of your search if possible.";
                    my $resMsg   = getErrorResponseMessage( eventType => "error.common.timeout", description => $msg );
                    my $response = HTTP::Response->new();
                    $response->message( "success" );
                    $response->header( 'Content-Type' => 'text/xml' );
                    $response->header( 'user-agent'   => 'perfSONAR-PS/1.0b' );
                    $response->content( makeEnvelope( $resMsg ) );
                    $child_pids{$pid}->{"listener"}->send_response( $response );
                    $child_pids{$pid}->{"listener"}->close();
                }
            }
        }

        my $handle = $listener->accept;
        if ( not defined $handle ) {
            my $msg = "Accept returned nothing, likely a timeout occurred or a child exited";
            $logger->debug( $msg );
        }
        else {
            $logger->info( "Received incoming connection from:\t" . $handle->peerhost() );
            my $pid = fork();
            if ( $pid == 0 ) {
                %child_pids = ();

                $PROGRAM_NAME .= " - " . $handle->peerhost();

                my $http_request = $handle->get_request;
                unless ( $http_request ) {
                    my $msg = "No HTTP Request received from host:\t" . $handle->peerhost();
                    $logger->error( $msg );
                    $handle->close;
                    exit( -1 );
                }

                my $request = perfSONAR_PS::Request->new( $handle, $http_request );
                if ( not exists $handlers->{ $request->getEndpoint() } ) {
                    my $msg = "Received message with has invalid endpoint: " . $request->getEndpoint();
                    $request->setResponse( getErrorResponseMessage( eventType => "error.common.transport", description => $msg ) );
                    $request->finish();
                }
                else {
                    $PROGRAM_NAME .= " - " . $request->getEndpoint();
                    handleRequest( $handlers->{ $request->getEndpoint() }, $request, $service_config->{"endpoint"}->{ $request->getEndpoint() } );
                }
                exit( 0 );
            }
            elsif ( $pid < 0 ) {
                $logger->error( "Error spawning child" );
            }
            else {
                my $max_worker_lifetime = $service_config->{"max_worker_lifetime"};
                my %child_info          = ();
                $child_info{"listener"}             = $handle;
                $child_info{"timeout_time"}         = time + $max_worker_lifetime;
                $child_info{"child_timeout_length"} = $max_worker_lifetime;
                $child_pids{$pid}                   = \%child_info;
            }
        }

        foreach my $service ( @{$services} ) {
            if ( $service->can( "inline_maintenance" ) ) {
                $logger->debug( "Calling inline maintance function" );
                eval { $service->inline_maintenance(); };
                if ( $EVAL_ERROR ) {
                    $logger->error( "Failure in inline maintenance: $EVAL_ERROR" );
                }
            }
        }
    }

    return;
}

=head2 registerLS($args)

The registerLS function is called in a separate process or thread and is
responsible for calling the specified service's 'registerLS' function regularly.

=cut

sub registerLS {
    my ( $args ) = @_;

    my $service = $args->{"service"};
    $logger->debug( "Starting '" . $PROCESS_ID . "' for LS registration" );

    my $sleep_time = q{};
    if ( exists $args->{"conf"}->{"ls_registration_interval"} and $args->{"conf"}->{"ls_registration_interval"} ) {
        $sleep_time = $args->{"conf"}->{"ls_registration_interval"};
    }
    elsif ( exists $args->{"conf"}->{"ls"}->{"ls_registration_interval"} and $args->{"conf"}->{"ls"}->{"ls_registration_interval"} ) {
        $sleep_time = $args->{"conf"}->{"ls"}->{"ls_registration_interval"};
    }
    elsif ( exists $args->{"conf"}->{"gls"}->{"ls_registration_interval"} and $args->{"conf"}->{"gls"}->{"ls_registration_interval"} ) {
        $sleep_time = $args->{"conf"}->{"gls"}->{"ls_registration_interval"};
    }
    else {
        $sleep_time = 3600;
    }

    unless ( $sleep_time ) {
        $logger->error( "LS Registration Disabled." );
        return;
    }

    while ( 1 ) {
        eval { $service->registerLS( \$sleep_time ); };
        if ( $EVAL_ERROR ) {
            $logger->error( "Problem running register LS: " . $EVAL_ERROR );
        }

        if ( $service->can( "inline_maintenance" ) ) {
            $logger->debug( "Calling inline maintance function" );
            eval { $service->inline_maintenance(); };
            if ( $EVAL_ERROR ) {
                $logger->error( "Failure in inline maintenance: $EVAL_ERROR" );
            }
        }

        $logger->debug( "Sleeping for $sleep_time" );
        sleep( $sleep_time );
    }
    return;
}

=head2 collection($args)

TBD

=cut

sub collection {
    my ( $args )   = @_;
    my $service    = $args->{"service"};
    my $sleep_time = q{};
    my $error      = q{};

    if ( exists $args->{"conf"}->{"skeleton"}->{"collection_interval"} and $args->{"conf"}->{"skeleton"}->{"collection_interval"} ) {
        $sleep_time = $args->{"conf"}->{"skeleton"}->{"collection_interval"};
    }
    else {
        $sleep_time = 1800;
    }

    unless ( $sleep_time ) {
        $logger->error( "Service Data Collection Disabled." );
        return;
    }

    while ( 1 ) {
        if ( $service->can( "makeMeasurement" ) ) {
            my $loadStatus = 0;
            eval { $loadStatus = $service->makeMeasurement( { error => \$error } ) if $service->can( "makeMeasurement" ); };
            if ( $EVAL_ERROR ) {
                $logger->error( "Problem running data collection: " . $EVAL_ERROR );
            }

            $logger->error( "Error returned: $error" ) if $loadStatus == -1;
        }

        $logger->debug( "Sleeping for $sleep_time" );
        sleep( $sleep_time );
    }
    return 0;
}

=head2 maintenance($args)

The maintenanceLS function is used (currently only by the LS) to perform routine
tasks.

=cut

sub maintenance {
    my ( $args )   = @_;
    my $service    = $args->{"service"};
    my $sleep_time = q{};
    my $error      = q{};

    if ( exists $args->{"conf"}->{"gls"}->{"maintenance_interval"} and $args->{"conf"}->{"gls"}->{"maintenance_interval"} ) {
        $sleep_time = $args->{"conf"}->{"gls"}->{"maintenance_interval"};
    }
    elsif ( exists $args->{"conf"}->{"ls"}->{"maintenance_interval"} and $args->{"conf"}->{"ls"}->{"maintenance_interval"} ) {
        $sleep_time = $args->{"conf"}->{"ls"}->{"maintenance_interval"};
    }
    elsif ( exists $args->{"conf"}->{"perfsonarbuoy"}->{"maintenance_interval"} and $args->{"conf"}->{"perfsonarbuoy"}->{"maintenance_interval"} ) {
        $sleep_time = $args->{"conf"}->{"perfsonarbuoy"}->{"maintenance_interval"};
    }
    elsif ( exists $args->{"conf"}->{"snmp"}->{"maintenance_interval"} and $args->{"conf"}->{"snmp"}->{"maintenance_interval"} ) {
        $sleep_time = $args->{"conf"}->{"snmp"}->{"maintenance_interval"};
    }
    else {
        $sleep_time = 1800;
    }

    unless ( $sleep_time ) {
        $logger->error( "Service Maintenance Disabled." );
        return;
    }

    while ( 1 ) {
        if ( $service->can( "cleanLS" ) or $service->can( "summarizeLS" ) ) {
            my $cleanStatus = 0;
            my $sumStatus   = 0;
            eval {
                $cleanStatus = $service->cleanLS( { error => \$error, noclean => $CLEANFLAG } ) if $service->can( "cleanLS" );
                $sumStatus = $service->summarizeLS( { error => \$error } ) if $service->can( "summarizeLS" );
            };
            if ( my $e = catch std::exception ) {
                $logger->error( "Problem running service maintenance: " . $e->what() );
            }
            elsif ( $EVAL_ERROR ) {
                $logger->error( "Problem running service maintenance: " . $EVAL_ERROR );
            }

            $logger->error( "Error returned: $error" ) if $cleanStatus == -1 or $sumStatus == -1;
        }

        if ( $service->can( "createStorage" ) ) {
            my $loadStatus = 0;
            eval { $loadStatus = $service->createStorage( { error => \$error } ) if $service->can( "createStorage" ); };
            if ( $EVAL_ERROR ) {
                $logger->error( "Problem running service maintenance: " . $EVAL_ERROR );
            }

            $logger->error( "Error returned: $error" ) if $loadStatus == -1;
        }

        $logger->debug( "Sleeping for $sleep_time" );
        sleep( $sleep_time );
    }
    return 0;
}

=head2 handleRequest($handler, $request, $endpoint_conf);

This function is a wrapper around the handler's handleRequest function.  It's
purpose is to ensure that if a crash occurs or a perfSONAR_PS::Error_compat
message is thrown, the client receives a proper response.

=cut

sub handleRequest {
    my ( $handler, $request, $endpoint_conf ) = @_;

    my $messageId = q{};
    try {
        my $error = q{};
        if ( $request->getRawRequest->method ne "POST" ) {
            my $msg = "Received message with an invalid HTTP request, are you using a web browser?";
            $logger->error( $msg );
            throw perfSONAR_PS::Error_compat( "error.common.transport", $msg );
        }

        $request->parse( \%ns, \$error );
        throw perfSONAR_PS::Error_compat( "error.transport.parse_error", "Error parsing request: $error" ) if $error;

        my $message = $request->getRequestDOM()->getDocumentElement();
        $messageId = $message->getAttribute( "id" );
        $handler->handleMessage( $message, $request, $endpoint_conf );
    }
    catch perfSONAR_PS::Error_compat with {
        my $ex = shift;

        my $msg = "Error handling request: " . $ex->eventType . " => \"" . $ex->errorMessage . "\"";
        $logger->error( $msg );

        $request->setResponse( getErrorResponseMessage( messageIdRef => $messageId, eventType => $ex->eventType, description => $ex->errorMessage ) );
    }
    catch perfSONAR_PS::Error with {
        my $ex = shift;

        my $msg = "Error handling request: " . $ex->eventType . " => \"" . $ex->errorMessage . "\"";
        $logger->error( $msg );

        $request->setResponse( getErrorResponseMessage( messageIdRef => $messageId, eventType => $ex->eventType, description => $ex->errorMessage ) );
    }
    otherwise {
        my $ex  = shift;
        my $msg = "Unhandled exception or crash: $ex";
        $logger->error( $msg );

        $request->setResponse( getErrorResponseMessage( messageIdRef => $messageId, eventType => "error.common.internal_error", description => "An internal error occurred" ) );
    };

    $request->finish();
    return;
}

=head2 daemonize

Sends the program to the background by eliminating ties to the calling terminal.

=cut

sub daemonize {
    chdir '/' or croak "Can't chdir to /: $!";
    open STDIN,  '/dev/null'   or croak "Can't read /dev/null: $!";
    open STDOUT, '>>/dev/null' or croak "Can't write to /dev/null: $!";
    open STDERR, '>>/dev/null' or croak "Can't write to /dev/null: $!";
    defined( my $pid = fork ) or croak "Can't fork: $!";
    exit if $pid;
    setsid or croak "Can't start a new session: $!";
    umask 0;
    return;
}

=head2 lockPIDFile($piddir, $pidfile);

The lockPIDFile function checks for the existence of the specified file in the
specified directory. If found, it checks to see if the process in the file still
exists. If there is no running process, it returns the filehandle for the open
pidfile that has been flock(LOCK_EX).

=cut

sub lockPIDFile {
    my ( $piddir, $pidfile ) = @_;
    croak "Can't write pidfile: $piddir/$pidfile\n" unless -w $piddir;
    $pidfile = $piddir . "/" . $pidfile;
    sysopen( PIDFILE, $pidfile, O_RDWR | O_CREAT ) or croak( "Couldn't open pidfile" );
    flock( PIDFILE, LOCK_EX ) or croak( "Couldn't lock pidfile" );
    my $p_id = <PIDFILE>;
    chomp( $p_id ) if $p_id;
    if ( $p_id ) {
        open( PSVIEW, "ps -p " . $p_id . " |" );
        my @output = <PSVIEW>;
        close( PSVIEW );
        if ( !$CHILD_ERROR ) {
            croak "$PROGRAM_NAME already running: $p_id\n";
        }
    }

    # write the current process in if we're locking it, and then unlock the PID
    # file so that others can try their luck. XXX: there's a minor race
    # condition during the 'daemonize' call.

    truncate( PIDFILE, 0 );
    seek( PIDFILE, 0, 0 );
    print PIDFILE "$PROCESS_ID\n";
    flock( PIDFILE, LOCK_UN );

    return *PIDFILE;
}

=head2 unlockPIDFile

This file writes the pid of the call process to the filehandle passed in,
unlocks the file and closes it.

=cut

sub unlockPIDFile {
    my ( $filehandle ) = @_;

    flock( PIDFILE, LOCK_EX ) or croak( "Couldn't lock pidfile" );

    truncate( $filehandle, 0 );
    seek( $filehandle, 0, 0 );
    print $filehandle "$PROCESS_ID\n";
    flock( $filehandle, LOCK_UN );
    close( $filehandle );

    $logger->debug( "Unlocked pid file" );

    return;
}

=head2 killChildren

Kills all the children for this process off. It uses global variables because
this function is used by the signal handler to kill off all child processes.

=cut

sub killChildren {
    foreach my $pid ( keys %child_pids ) {
        kill( "SIGINT", $pid );
    }
    return;
}

=head2 signalHandler

Kills all the children for the process and then exits

=cut

sub signalHandler {
    killChildren;
    exit( 0 );
}

sub REAPER {

    # We have to get the signal when children exit so that we can close our
    # reference to that child's socket. Otherwise, the TCP connection will
    # remain open until the accept call times out and the reaper kicks in.
    # We could have the reaper clean up the processes, but by handling the
    # SIGCHLD, it will cause the accept call to return, triggering a process
    # cleanup. Since this process cleanup must exist (to handle timeouts), we
    # may as well reuse it to clean up the exiting children as well.

    $SIG{CHLD} = \&REAPER;
    return;
}

=head2 setids

Sets the user/group for the daemon to run as. Returns 0 on success and -1 on
failure.

=cut

sub setids {
    my ( %args ) = @_;
    my ( $uid,  $gid );
    my ( $unam, $gnam );

    $uid = $args{'USER'}  if exists $args{'USER'}  and $args{'USER'};
    $gid = $args{'GROUP'} if exists $args{'GROUP'} and $args{'GROUP'};
    return -1 unless $uid;

    # Don't do anything if we are not running as root.
    return if ( $EFFECTIVE_USER_ID != 0 );

    # set GID first to ensure we still have permissions to.
    if ( $gid ) {
        if ( $gid =~ /\D/ ) {

            # If there are any non-digits, it is a groupname.
            $gid = getgrnam( $gnam = $gid );
            if ( not $gid ) {
                $logger->error( "Can't getgrnam($gnam): $!" );
                return -1;
            }
        }
        elsif ( $gid < 0 ) {
            $gid = -$gid;
        }

        if ( not getgrgid( $gid ) ) {
            $logger->error( "Invalid GID: $gid" );
            return -1;
        }

        $EFFECTIVE_GROUP_ID = $REAL_GROUP_ID = $gid;
    }

    # Now set UID
    if ( $uid =~ /\D/ ) {

        # If there are any non-digits, it is a username.
        $uid = getpwnam( $unam = $uid );
        if ( not $uid ) {
            $logger->error( "Can't getpwnam($unam): $!" );
            return -1;
        }
    }
    elsif ( $uid < 0 ) {
        $uid = -$uid;
    }

    if ( not getpwuid( $uid ) ) {
        $logger->error( "Invalid UID: $uid" );
        return -1;
    }

    $EFFECTIVE_USER_ID = $REAL_USER_ID = $uid;

    return 0;
}

__END__

=head1 SEE ALSO

L<Getopt::Long>, L<Time::HiRes>, L<POSIX>, L<File::Basename>, L<Fcntl>, L<Cwd>,
L<Config::General>, L<Module::Load>, L<HTTP::Daemon>, L<English>, L<Carp>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Messages>, L<perfSONAR_PS::Request>,
L<perfSONAR_PS::RequestHandler>, L<perfSONAR_PS::Error_compat>,
L<perfSONAR_PS::Error>, L<perfSONAR_PS::Services::Echo>

To join the 'perfSONAR Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: perfsonar-daemon.pl 4475 2010-09-29 13:18:06Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
