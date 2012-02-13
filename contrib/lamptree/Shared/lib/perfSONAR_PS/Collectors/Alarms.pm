package perfSONAR_PS::Collectors::Alarms;

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::Collectors::Base';

use fields 'DB_CLIENT', 'ROUTERS', 'ALARM_TABLE';

=head1 NAME

perfSONAR_PS::Collectors::Alarms - A module that will collect router alarm
information and store the results into a Measurement Archive.

=head1 DESCRIPTION

This module loads a set of links and can be used to collect status information
on those links and store the results into a Link Status MA.

=cut

use Data::Dumper;
use Log::Log4perl qw(get_logger);
use Time::HiRes qw( gettimeofday );
use Module::Load;
use Digest::MD5 qw(md5_hex);

use perfSONAR_PS::Common;
use perfSONAR_PS::DB::File;
use perfSONAR_PS::DB::SQL;
use perfSONAR_PS::Utils::TL1::OME;
use perfSONAR_PS::Utils::TL1::HDXc;
use perfSONAR_PS::Utils::TL1::Ciena;
use perfSONAR_PS::Utils::TL1::Cisco;
use perfSONAR_PS::Utils::TL1::Infinera;

=head2 new($self, $conf, $directory)

TBD

=cut

sub new {
    my ( $self, $conf, $directory ) = @_;

    $self = fields::new( $self ) unless ref $self;
    $self->SUPER::new( $conf, $directory );
    return $self;
}

=head2 init($self)

This function initializes the collector. It returns 0 on success and -1 on
failure.

=cut

sub init {
    my ( $self ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Collectors::Alarms" );

    unless ( $self->{CONF}->{"routers_file"} ) {
        $self->{LOGGER}->error( "No routers file in configuration" );
        return -1;
    }

    my $file = $self->{CONF}->{"routers_file"};
    if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} ) {
        unless ( $file =~ "^/" ) {
            $file = $self->{DIRECTORY} . "/" . $file;
        }
    }

    if ( $self->parseRoutersFile( $file ) != 0 ) {
        $self->{LOGGER}->error( "couldn't load counters to record" );
        return -1;
    }

    if ( exists $self->{CONF}->{"ma_type"} ) {
        if ( lc( $self->{CONF}->{"ma_type"} ) eq "sqlite" ) {
            if ( not defined $self->{CONF}->{"ma_file"} or $self->{CONF}->{"ma_file"} eq q{} ) {
                $self->{LOGGER}->error( "You specified a SQLite Database, but then did not specify a database file(ma_file)" );
                return -1;
            }

            my $file = $self->{CONF}->{"ma_file"};
            if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} ) {
                unless ( $file =~ "^/" ) {
                    $file = $self->{DIRECTORY} . "/" . $file;
                }
            }

            $self->{DB_CLIENT} = perfSONAR_PS::DB::SQL->new( name => "DBI:SQLite:dbname=" . $file );
        }
    }
    else {
        $self->{LOGGER}->error( "Need to specify a location to store the status reports" );
        return -1;
    }

    my ( $status, $res ) = $self->{DB_CLIENT}->openDB();
    if ( $status != 0 ) {
        my $msg = "Couldn't open newly created client: $res";
        $self->{LOGGER}->error( $msg );
        return -1;
    }

    $self->{DB_CLIENT}->closeDB;

    if ( exists $self->{CONF}->{"alarms_table"} and $self->{CONF}->{"alarms_table"} ) {
        $self->{ALARM_TABLE} = $self->{CONF}->{"alarms_table"};
    }
    else {
        $self->{ALARM_TABLE} = "ps_tl1_alarms";
    }

    return 0;
}

=head2 parseRoutersFile($self, $file)

TBD

=cut

sub parseRoutersFile {
    my ( $self, $file ) = @_;
    my $routers_config;

    $self->{LOGGER}->debug( "Reading $file" );

    my $filedb = perfSONAR_PS::DB::File->new( { file => $file } );
    $filedb->openDB;
    $routers_config = $filedb->getDOM();

    my @routers = ();
    foreach my $router ( $routers_config->getElementsByTagName( "router" ) ) {
        my ( $status, $res ) = $self->parseRouter( $router );
        if ( $status != 0 ) {
            my $msg = "Failure parsing element: $res";
            $self->{LOGGER}->error( $msg );
            return -1;
        }
        push @routers, $res;
    }

    $self->{ROUTERS} = \@routers;
    return 0;
}

=head2 parseRouter($self, $router_desc)

TBD

=cut

sub parseRouter {
    my ( $self, $router_desc ) = @_;

    my @counters = ();

    my $type = $router_desc->findvalue( "./type" );
    if ( not $type ) {
        my $msg = "Switch does not have a 'type' field";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    my $username = $router_desc->findvalue( 'username' );
    my $password = $router_desc->findvalue( 'password' );
    my $address  = $router_desc->findvalue( 'address' );
    my $port     = $router_desc->findvalue( 'port' );

    my $id = $router_desc->findvalue( 'id' );

    unless ( $address and $username and $password and $id ) {
        my $msg = "Router is missing elements needed to access the host. Required: type, address, port, username, password, id";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    my $name     = $router_desc->findvalue( 'name' );
    my $hostname = $router_desc->findvalue( 'hostname' );

    my %metadata = ();
    $metadata{"id"} = $id;

    my $new_agent;

    if ( $type eq "ome" ) {
        $new_agent = perfSONAR_PS::Utils::TL1::OME->new();
    }
    elsif ( $type eq "ciena" ) {
        $new_agent = perfSONAR_PS::Utils::TL1::Ciena->new();
    }
    elsif ( $type eq "cisco" ) {
        $new_agent = perfSONAR_PS::Utils::TL1::Cisco->new();
    }
    elsif ( $type eq "infinera" ) {
        $new_agent = perfSONAR_PS::Utils::TL1::Infinera->new();
    }
    else {
        my $msg = "Router has unknown type, $type, must be either 'ome', 'cisco' or 'ciena'";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    my $res = $new_agent->initialize(
        {
            address    => $address,
            port       => $port,
            username   => $username,
            password   => $password,
            cache_time => 300,
        }
    );
    if ( $res != 0 ) {

        # XXX Error
    }

    my %router = ();

    $router{"METADATA"} = \%metadata;
    $router{"AGENT"}    = $new_agent;

    return ( 0, \%router );
}

=head2 collectMeasurements($self)

This function is called by external users to collect and store the status for
all links.
    
=cut

sub collectMeasurements {
    my ( $self, $sleeptime ) = @_;
    my ( $status, $res );

    $self->{LOGGER}->info( "Collecting alarms" );

    ( $status, $res ) = $self->{DB_CLIENT}->openDB();
    if ( $status != 0 ) {
        my $msg = "Couldn't open connection to database: $res";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    foreach my $router ( @{ $self->{ROUTERS} } ) {
        $self->{LOGGER}->info( "Current router: " . $router->{METADATA}->{id} );

        my $localTime = time;
        $self->{LOGGER}->debug( "Pre getAlarms()" );
        my $alarms = $router->{AGENT}->getAlarms();
        $self->{LOGGER}->debug( "Post getAlarms()" );
        my $machineTime = $router->{AGENT}->getMachineTime();
        my $metadataId  = $router->{METADATA}->{id};

        unless ( $alarms ) {
            $self->{LOGGER}->debug( "Get alarms returned junk" );

            # Generate a measurement alarm

            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time );
            $mday++;
            $year += 1900;

            my %alarm = ();
            $alarm{alarmType}        = "MEASUREMENT";
            $alarm{serviceAffecting} = "NSA";
            $alarm{description}      = "Measurement Software Couldn't Connect To Device";
            $alarm{facility}         = "pS-Alarms-Collector";
            $alarm{facility_type}    = "perfSONAR";
            $alarm{severity}         = 'CR';
            $alarm{time}             = $hour . "-" . $min . "-" . $sec;
            $alarm{date}             = $mon . "-" . $mday;
            $alarm{year}             = $year;

            my @tmp = ();
            push @tmp, \%alarm;
            $alarms = \@tmp;

            $machineTime = "$year-$mon-$mday $hour:$min:$sec";
        }

        foreach my $alarm ( @$alarms ) {
            my $alarmId;

            # Correct some differences between the various TL1 dialects

            # Generate an alarm id if one doesn't already exist
            unless ( $alarm->{alarmId} ) {
                my $tmp = q{};
                foreach my $key ( sort keys %{$alarm} ) {
                    $tmp .= $alarm->{$key};
                }
                $alarm->{alarmId} = md5_hex( $tmp );
            }

            # If no 'year' element, guess the year
            unless ( $alarm->{year} ) {

                # guess the year of the interval based on the current machine time
                my ( $month,       $day )         = split( '-', $alarm->{date} );
                my ( $hour,        $minute )      = split( '-', $alarm->{time} );
                my ( $switch_date, $switch_time ) = split( ' ', $machineTime );

                my ( $switch_year, $switch_month,  $switch_day )    = split( '-', $switch_date );
                my ( $switch_hour, $switch_minute, $switch_second ) = split( ':', $switch_time );

                my $year;

                if ( $switch_month eq $month ) {
                    $year = $switch_year;
                }
                elsif ( $switch_month ne $month ) {
                    if ( $switch_month == 1 ) {
                        $year = $switch_year - 1;
                    }
                    else {
                        $year = $switch_year;
                    }
                }

                $alarm->{year} = $year;
            }

            $self->{LOGGER}->debug( Dumper( $alarm ) );

            my $res = $self->{DB_CLIENT}->query( { query => "select alarmId from " . $self->{ALARM_TABLE} . " where alarmId=\'" . $alarm->{alarmId} . "\' and metadataId=\'" . $metadataId . "\'" } );
            if ( $res == -1 ) {

                #                $self->{LOGGER}->error("An error occurred while querying for the identifier needed to add a new data point to host ".$counter->agent->getAddress."/".$pm->{aid});
                next;
            }

            my $foundResult = ( $#{$res} > -1 );

            if ( $foundResult ) {

                # if we've seen it before, just update the "lastObservedTime"

                my %updateValues = ( lastObservedTime => $localTime, );

                my %where = (
                    metadataId => $metadataId,
                    alarmId    => $alarm->{alarmId},
                );

                if ( $self->{DB_CLIENT}->update( { table => $self->{ALARM_TABLE}, wherevalues => \%where, updatevalues => \%updateValues } ) == -1 ) {
                    my $msg = "Couldn't update alarm status for alarm: " . $alarm->{alarmId};
                    $self->{LOGGER}->error( $msg );
                }
            }
            else {
                $self->{LOGGER}->info( "New alarm: " . $alarm->{alarmId} );

                my $serviceAffecting;
                if ( $alarm->{serviceAffecting} eq "SA" ) {
                    $serviceAffecting = "true";
                }
                else {
                    $serviceAffecting = "false";
                }

                # Calculate the difference between the local measurement time and the machine time
                my ( $router_date, $router_time ) = split( ' ', $machineTime );

                my ( $router_year, $router_month,  $router_day )    = split( '-', $router_date );
                my ( $router_hour, $router_minute, $router_second ) = split( ':', $router_time );

                $self->{LOGGER}->debug( "Router: " . $router_date . " " . $router_time );
                $self->{LOGGER}->debug( "Local: " . ( scalar localtime( $localTime ) ) );
                my $currentMachineTimestamp = POSIX::mktime( $router_second, $router_minute, $router_hour, $router_day, $router_month - 1, $router_year - 1900 );
                $self->{LOGGER}->debug( "Post mktime: " . ( scalar localtime( $currentMachineTimestamp ) ) );

                my $diff = $localTime - $currentMachineTimestamp;

                # Convert the start time to a timestamp and use the diff to calculate the 'local' start time
                my $machine_start_year = $alarm->{year};
                my ( $machine_start_month, $machine_start_day ) = split( '-', $alarm->{date} );
                my ( $machine_start_hour, $machine_start_minute, $machine_start_second ) = split( '-', $alarm->{time} );

                my $startMachineTimestamp = POSIX::mktime( $machine_start_second, $machine_start_minute, $machine_start_hour, $machine_start_day, $machine_start_month - 1, $machine_start_year - 1900 );
                my $startLocalTimestamp = $startMachineTimestamp + $diff;

                $self->{LOGGER}->info( "Machine: " . $startMachineTimestamp );
                $self->{LOGGER}->info( "Measured: " . $startLocalTimestamp );
                $self->{LOGGER}->info( "Diff: " . $diff );

                my %insertValues = (
                    metadataId        => $metadataId,
                    facility          => $alarm->{facility},
                    severity          => $alarm->{severity},
                    type              => $alarm->{alarmType},
                    alarmId           => $alarm->{alarmId},
                    description       => $alarm->{description},
                    serviceAffecting  => $serviceAffecting,
                    measuredStartTime => $startLocalTimestamp,
                    machineStartTime  => $startMachineTimestamp,
                    firstObservedTime => $localTime,
                    lastObservedTime  => $localTime,
                );

                if ( $self->{DB_CLIENT}->insert( { table => $self->{ALARM_TABLE}, argvalues => \%insertValues } ) == -1 ) {
                    $self->{LOGGER}->error( "Couldn't add new alarm " . $alarm->{alarmId} );
                    last;
                }
            }
        }
    }

    ( $status, $res ) = $self->{DB_CLIENT}->closeDB();
    if ( $status != 0 ) {
        my $msg = "Couldn't close connection to database: $res";
        $self->{LOGGER}->error( $msg );
    }

    if ( $sleeptime ) {
        $$sleeptime = $self->{CONF}->{"collection_interval"};
    }

    return;
}

1;

__END__

=head1 DETAILS

This module is meant to be used to periodically collect information about Link
Status. It can do this by running scripts or consulting SNMP servers directly.
It reads a configuration file that contains the set of links to track. It can
then be used to periodically obtain the status and then store the results into
a measurement archive. 

It includes a submodule SNMPAgent that provides a caching SNMP poller allowing
easier interaction with SNMP servers.

=head1 SEE ALSO

L<Data::Dumper>, L<Log::Log4perl>, L<Time::HiRes>, L<Module::Load>,
L<Digest::MD5>, L<perfSONAR_PS::Common>, L<perfSONAR_PS::DB::File>,
L<perfSONAR_PS::DB::SQL>, L<perfSONAR_PS::Utils::TL1::OME>,
L<perfSONAR_PS::Utils::TL1::HDXc>, L<perfSONAR_PS::Utils::TL1::Ciena>,
L<perfSONAR_PS::Utils::TL1::Cisco>, L<perfSONAR_PS::Utils::TL1::Infinera>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Alarms.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
