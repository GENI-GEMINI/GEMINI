#!/usr/bin/perl

use strict;
use warnings;

=head1 NAME

ls_registration_daemon.pl - Registers services (e.g. daemons such as owamp,
bwctl) into the global information service.

=head1 DESCRIPTION

This daemon reads a configuration file consisting of sites and the services
those sites are running. It will then check those services and register them
with the specified lookup service.

=cut

use FindBin qw($Bin);
use lib "$Bin/../lib";

use perfSONAR_PS::Common;
use perfSONAR_PS::Utils::Daemon qw/daemonize setids lockPIDFile unlockPIDFile/;
use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::LSRegistrationDaemon::Phoebus;
use perfSONAR_PS::LSRegistrationDaemon::REDDnet;
use perfSONAR_PS::LSRegistrationDaemon::BWCTL;
use perfSONAR_PS::LSRegistrationDaemon::OWAMP;
use perfSONAR_PS::LSRegistrationDaemon::NDT;
use perfSONAR_PS::LSRegistrationDaemon::NPAD;
use perfSONAR_PS::LSRegistrationDaemon::Ping;
use perfSONAR_PS::LSRegistrationDaemon::Traceroute;

use Getopt::Long;
use Config::General;
use Log::Log4perl qw/:easy/;

# set the process name
$0 = "ls_registration_daemon.pl";

my @child_pids = ();

$SIG{INT}  = \&signalHandler;
$SIG{TERM} = \&signalHandler;

my $CONFIG_FILE;
my $LOGOUTPUT;
my $LOGGER_CONF;
my $PIDFILE;
my $DEBUGFLAG;
my $HELP;
my $RUNAS_USER;
my $RUNAS_GROUP;
my $SERVER_CERT;
my $SERVER_KEYFILE;

my ( $status, $res );

$status = GetOptions(
    'config=s'          => \$CONFIG_FILE,
    'output=s'          => \$LOGOUTPUT,
    'logger=s'          => \$LOGGER_CONF,
    'pidfile=s'         => \$PIDFILE,
    'verbose'           => \$DEBUGFLAG,
    'user=s'            => \$RUNAS_USER,
    'group=s'           => \$RUNAS_GROUP,
    'ssl-servercert'    => \$SERVER_CERT,
    'ssl-serverkeyfile' => \$SERVER_KEYFILE,
    'help'              => \$HELP
);

if ( not $CONFIG_FILE ) {
    print "Error: no configuration file specified\n";
    exit( -1 );
}

my %conf = Config::General->new( $CONFIG_FILE )->getall();

if ( not $PIDFILE ) {
    $PIDFILE = $conf{"pid_file"};
}

if ( not $PIDFILE ) {
    $PIDFILE = "/var/run/ls_registration_daemon.pid";
}

( $status, $res ) = lockPIDFile( $PIDFILE );
if ( $status != 0 ) {
    print "Error: $res\n";
    exit( -1 );
}

my $fileHandle = $res;

unless ( $SERVER_CERT ) {
    if ( exists $conf{"ssl_server_cert_file"} and $conf{"ssl_server_cert_file"} ) {
        $SERVER_CERT = $conf{"ssl_server_cert_file"};
    }
}
    
unless ( $SERVER_KEYFILE ) {
    if ( exists $conf{"ssl_server_key_file"} and $conf{"ssl_server_key_file"} ) {
        $SERVER_KEYFILE = $conf{"ssl_server_key_file"};
    }
}

# We might need to talk to other SSL services.
# Crypt::SSLeay (under LWP::UserAgent) will look for these.
$ENV{'HTTPS_CERT_FILE'} = $SERVER_CERT if $SERVER_CERT and -e $SERVER_CERT;
$ENV{'HTTPS_KEY_FILE'}  = $SERVER_KEYFILE if $SERVER_KEYFILE and -e $SERVER_KEYFILE;

# Check if the daemon should run as a specific user/group and then switch to
# that user/group.
if ( not $RUNAS_GROUP ) {
    if ( $conf{"group"} ) {
        $RUNAS_GROUP = $conf{"group"};
    }
}

if ( not $RUNAS_USER ) {
    if ( $conf{"user"} ) {
        $RUNAS_USER = $conf{"user"};
    }
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
    if ( $DEBUGFLAG ) {
        $output_level = $DEBUG;
    }

    my %logger_opts = (
        level  => $output_level,
        layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
    );

    if ( defined $LOGOUTPUT and $LOGOUTPUT ne q{} ) {
        $logger_opts{file} = $LOGOUTPUT;
    }

    Log::Log4perl->easy_init( \%logger_opts );
    $logger = get_logger( "perfSONAR_PS" );
}
else {
    use Log::Log4perl qw(get_logger :levels);

    my $output_level = $INFO;
    if ( $DEBUGFLAG ) {
        $output_level = $DEBUG;
    }

    my %logger_opts = (
        level  => $output_level,
        layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
    );

    if ( $LOGOUTPUT ) {
        $logger_opts{file} = $LOGOUTPUT;
    }

    Log::Log4perl->init( $LOGGER_CONF );
    $logger = get_logger( "perfSONAR_PS" );
    $logger->level( $output_level ) if $output_level;
}

if ( not $conf{"ls_instance"} ) {
    $logger->error( "You must specify which LS Registration Daemon to register with." );
    exit(-1);
} elsif (ref $conf{"ls_instance"} eq "ARRAY" or $conf{"ls_instance"} =~ /,/ or $conf{"ls_instance"} =~ / /) {
    $logger->error( "You can only specify a single LS Registration Daemon to register with.");
    exit(-1);
}

if ( not $conf{"ls_interval"} ) {
    $logger->info( "No LS interval specified. Defaulting to 24 hours" );
    $conf{"ls_interval"} = 24;
}

if ( not $conf{"check_interval"} ) {
    $logger->info( "No service check interval specified. Defaulting to 5 minutes" );
    $conf{"check_interval"} = 300;
}

# the interval is configured in hours
$conf{"ls_interval"} = $conf{"ls_interval"} * 60 * 60;

my $site_confs = $conf{"site"};
if ( not $site_confs ) {
    $logger->error( "No sites defined in configuration file" );
    exit( -1 );
}

if ( ref( $site_confs ) ne "ARRAY" ) {
    my @tmp = ();
    push @tmp, $site_confs;
    $site_confs = \@tmp;
}

my @site_params = ();

foreach my $site_conf ( @$site_confs ) {
    my $site_merge_conf = mergeConfig( \%conf, $site_conf );

    my $services = init_site( $site_merge_conf );

    if ( not $services ) {
        print "Couldn't initialize site. Exitting.";
        exit( -1 );
    }

    my %params = ( conf => $site_merge_conf, services => $services );

    push @site_params, \%params;
}

# Before daemonizing, set die and warn handlers so that any Perl errors or
# warnings make it into the logs.
my $insig = 0;
$SIG{__WARN__} = sub {
    $logger->warn("Warned: ".join( '', @_ ));
    return;
};

$SIG{__DIE__} = sub {                       ## still dies upon return
	die @_ if $^S;                      ## see perldoc -f die perlfunc
	die @_ if $insig;                   ## protect against reentrance.
	$insig = 1;
	$logger->error("Died: ".join( '', @_ ));
	$insig = 0;
	return;
};
										    #
if ( not $DEBUGFLAG ) {
    ( $status, $res ) = daemonize();
    if ( $status != 0 ) {
        $logger->error( "Couldn't daemonize: " . $res );
        exit( -1 );
    }
}

unlockPIDFile( $fileHandle );

foreach my $params ( @site_params ) {

    # every site will register separately
    my $pid = fork();
    if ( $pid != 0 ) {
        push @child_pids, $pid;
        next;
    }
    else {
        handle_site( $params->{conf}, $params->{services} );
    }
}

foreach my $pid ( @child_pids ) {
    waitpid( $pid, 0 );
}

exit( 0 );

=head2 init_site ($site_conf)

This function takes a configuration for a site, and generates agents for each
service it finds. It returns that as an array of service agents.

=cut

sub init_site {
    my ( $site_conf ) = @_;

    my @services = ();

    my $services_conf = $site_conf->{service};
    if ( ref( $services_conf ) ne "ARRAY" ) {
        my @tmp = ();
        push @tmp, $services_conf;
        $services_conf = \@tmp;
    }

    foreach my $curr_service_conf ( @$services_conf ) {

        my $service_conf = mergeConfig( $site_conf, $curr_service_conf );

        if ( not $service_conf->{type} ) {

            # complain
            $logger->error( "Error: No service type specified" );
            exit( -1 );
        }
        elsif ( lc( $service_conf->{type} ) eq "bwctl" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::BWCTL->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize bwctl watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        elsif ( lc( $service_conf->{type} ) eq "owamp" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::OWAMP->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize owamp watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        elsif ( lc( $service_conf->{type} ) eq "ping" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::Ping->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize ping watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        elsif ( lc( $service_conf->{type} ) eq "traceroute" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::Traceroute->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize traceroute watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        elsif ( lc( $service_conf->{type} ) eq "phoebus" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::Phoebus->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize Phoebus watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        elsif ( lc( $service_conf->{type} ) eq "reddnet" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::REDDnet->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize REDDnet watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        elsif ( lc( $service_conf->{type} ) eq "ndt" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::NDT->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize NDT watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        elsif ( lc( $service_conf->{type} ) eq "npad" ) {
            my $service = perfSONAR_PS::LSRegistrationDaemon::NPAD->new();
            if ( $service->init( $service_conf ) != 0 ) {

                # complain
                $logger->error( "Error: Couldn't initialize NPAD watcher" );
                exit( -1 );
            }
            push @services, $service;
        }
        else {

            # error
            $logger->error( "Error: Unknown service type: " . $conf{type} );
            exit( -1 );
        }
    }

    return \@services;
}

=head2 handle_site ($site_conf, \@services )

This function is the main loop for a ls registration daemon process. It goes
through and refreshes the services, and pauses for "check_interval" seconds.

=cut

sub handle_site {
    my ( $site_conf, $services ) = @_;

    while ( 1 ) {
        foreach my $service ( @$services ) {
            $service->refresh();
        }

        sleep( $site_conf->{"check_interval"} );
    }

    return;
}

=head2 killChildren

Kills all the children for this process off. It uses global variables
because this function is used by the signal handler to kill off all
child processes.

=cut

sub killChildren {
    foreach my $pid ( @child_pids ) {
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

__END__

=head1 SEE ALSO

L<FindBin>, L<Getopt::Long>, L<Config::General>, L<Log::Log4perl>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Utils::Daemon>,
L<perfSONAR_PS::Utils::Host>, L<perfSONAR_PS::LSRegistrationDaemon::Phoebus>,
L<perfSONAR_PS::LSRegistrationDaemon::BWCTL>,
L<perfSONAR_PS::LSRegistrationDaemon::OWAMP>,
L<perfSONAR_PS::LSRegistrationDaemon::NDT>,
L<perfSONAR_PS::LSRegistrationDaemon::NPAD>,
L<perfSONAR_PS::LSRegistrationDaemon::Ping>,
L<perfSONAR_PS::LSRegistrationDaemon::Traceroute>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: daemon.pl 4015 2010-04-07 16:04:22Z aaron $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2009, Internet2

All rights reserved.

=cut
