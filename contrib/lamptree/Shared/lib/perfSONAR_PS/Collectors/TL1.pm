package perfSONAR_PS::Collectors::TL1;

use Data::Dumper;

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::Collectors::Base';
use fields 'DB_CLIENT', 'COUNTERS', 'TL1AGENTS';

=head1 NAME

perfSONAR_PS::Collectors::TL1 - A module that will collect link status
information and store the results into a Link Status MA.

=head1 DESCRIPTION

This module loads a set of links and can be used to collect status information
on those links and store the results into a Link Status MA.

=cut

use Log::Log4perl qw(get_logger);
use Time::HiRes qw( gettimeofday );
use Module::Load;

use perfSONAR_PS::Common;
use perfSONAR_PS::DB::File;
use perfSONAR_PS::DB::SQL;
use perfSONAR_PS::Collectors::TL1::Agent::OME;
use perfSONAR_PS::Collectors::TL1::Agent::HDXc;

=head2 new($self, $conf, $directory)

This function initializes the collector. It returns 0 on success and -1 on
failure.

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
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Collectors::TL1" );

    unless ( $self->{CONF}->{"counters_file"} ) {
        $self->{LOGGER}->error( "No counters file in configuration" );
        return -1;
    }

    my $file = $self->{CONF}->{"counters_file"};
    if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} ) {
        unless ( $file =~ "^/" ) {
            $file = $self->{DIRECTORY} . "/" . $file;
        }
    }

    if ( $self->parseCountersFile( $file ) != 0 ) {
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

    return 0;
}

=head2 parseCountersFile($self, $file)

TBD
    
=cut

sub parseCountersFile {
    my ( $self, $file ) = @_;
    my $counters_config;

    my $filedb = perfSONAR_PS::DB::File->new( { file => $file } );
    $filedb->openDB;
    $counters_config = $filedb->getDOM();

    my @counters = ();
    my %agents   = ();

    foreach my $switch ( $counters_config->getElementsByTagName( "switch" ) ) {
        my ( $status, $res ) = $self->parseSwitch( $switch, \%agents );
        if ( $status != 0 ) {
            my $msg = "Failure parsing element: $res";
            $self->{LOGGER}->error( $msg );
            return -1;
        }

        foreach my $counter ( @$res ) {
            push @counters, $counter;
        }
    }

    $self->{COUNTERS}  = \@counters;
    $self->{TL1AGENTS} = \%agents;

    return 0;
}

=head2 parseSwitch($self, $switch_desc, $agents)

TBD
    
=cut

sub parseSwitch {
    my ( $self, $switch_desc, $agents ) = @_;

    my @counters = ();

    my $type = $switch_desc->findvalue( "./type" );
    unless ( $type ) {
        my $msg = "Switch does not have a 'type' field";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    if ( $type ne "hdxc" and $type ne "ome" ) {
        my $msg = "Only 'ome' and 'hdxc' switches available";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    my $username = $switch_desc->findvalue( 'username' );
    my $password = $switch_desc->findvalue( 'password' );
    my $address  = $switch_desc->findvalue( 'address' );
    my $port     = $switch_desc->findvalue( 'port' );

    if ( not $address or not $port or not $username or not $password ) {
        my $msg = "Switch is missing elements needed to access the host. Required: type, address, port, username, password";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    my $key = $address . "|" . $port . "|" . $username . "|" . $password;

    my $tl1agent = $agents->{$key};

    foreach my $counter ( $switch_desc->getElementsByTagName( "counter" ) ) {
        my $aid          = $counter->getAttribute( "aid" );
        my $aid_type     = $counter->getAttribute( "aid_type" );
        my $counter_name = $counter->getAttribute( "counter" );

        if ( not $aid or not $aid_type or not $counter_name ) {
            my $msg = "Counter is missing a required attribute. Must have 'aid', 'aid_type' and 'counter'";
            $self->{LOGGER}->error( $msg );
            return ( -1, $msg );
        }

        my $new_counter;

        if ( $type eq "ome" ) {
            $new_counter = perfSONAR_PS::Collectors::TL1::Agent::OME->new(
                address  => $address,
                port     => $port,
                username => $username,
                password => $password,
                agent    => $tl1agent,
                aid      => $aid,
                aid_type => $aid_type,
                counter  => $counter_name,
            );
        }
        elsif ( $type eq "hdxc" ) {
            $new_counter = perfSONAR_PS::Collectors::TL1::Agent::HDXc->new(
                address  => $address,
                port     => $port,
                username => $username,
                password => $password,
                agent    => $tl1agent,
                aid      => $aid,
                aid_type => $aid_type,
                counter  => $counter_name,
            );
        }

        unless ( $tl1agent ) {
            $tl1agent = $new_counter->agent;
            $agents->{$key} = $tl1agent;
        }

        push @counters, $new_counter;
    }

    return ( 0, \@counters );
}

=head2 collectMeasurements($self)

This function is called by external users to collect and store the status for
all links.
    
=cut

sub collectMeasurements {
    my ( $self, $sleeptime ) = @_;
    my ( $status, $res );

    ( $status, $res ) = $self->{DB_CLIENT}->openDB();
    if ( $status != 0 ) {
        my $msg = "Couldn't open connection to database: $res";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }

    foreach my $counter ( @{ $self->{COUNTERS} } ) {
        my $pm = $counter->run();

        if ( not $pm ) {
            $self->{LOGGER}->error( "Didn't get any value from counter\n" );
        }
        else {
            my $id;

            do {
                my $ids = $self->{DB_CLIENT}->query( { query => "select id from ps_tl1_interfaces where host=\'" . $counter->agent->getAddress . "\' and aid=\'" . $pm->{aid} . "\'" } );
                if ( $ids == -1 ) {
                    $self->{LOGGER}->error( "An error occurred while querying for the identifier needed to add a new data point to host " . $counter->agent->getAddress . "/" . $pm->{aid} );
                    last;
                }

                foreach my $id_ref ( @{$ids} ) {
                    my @fields = @{$id_ref};
                    $id = $fields[0];
                }

                unless ( $id ) {
                    $self->{LOGGER}->info( "No index currently available for interface: " . $counter->agent->getAddress . "/" . $pm->{aid} );

                    my %insertValues = (
                        host     => $counter->agent->getAddress,
                        aid      => $pm->{aid},
                        aid_type => $pm->{aid_type},
                    );

                    if ( $self->{DB_CLIENT}->insert( { table => "ps_tl1_interfaces", argvalues => \%insertValues } ) == -1 ) {
                        $self->{LOGGER}->error( "Couldn't add new interface: " . $counter->agent->getAddress . "/" . $pm->{aid} );
                        last;
                    }
                }
            } while ( not $id );

            unless ( $id ) {
                $self->{LOGGER}->error( "We got a measurement, but can't add it to the database because no identifier existed for it, and we can't add one" );
                next;
            }

            # guess the year of the interval based on the current machine time
            my ( $month,       $day )         = split( '-', $pm->{monitoring_date} );
            my ( $hour,        $minute )      = split( '-', $pm->{monitoring_time} );
            my ( $switch_date, $switch_time ) = split( ' ', $counter->agent->getMachineTime );

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

            my $counter_start_time = POSIX::mktime( 0, $minute, $hour, $day, $month, $year - 1900 );

            $self->{LOGGER}->info( ( $year - 1900 ) . "-" . $month . "-" . $day . " " . $hour . ":" . $minute . ":00" );
            my %insertValues = (
                interface_id => $id,
                type         => $pm->{type},
                value        => $pm->{value},
                validity     => $pm->{validity},
                location     => $pm->{location},
                direction    => $pm->{direction},
                time_period  => $pm->{time_period},
                start_time   => $counter_start_time,
            );

            if ( $self->{DB_CLIENT}->insert( { table => "ps_tl1_counters", argvalues => \%insertValues } ) == -1 ) {
                $self->{LOGGER}->error( "Couldn't add counter " . $pm->{type} . " for element " . $pm->{aid} . " to the database" );
            }
        }
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

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: TL1.pm 2640 2009-03-20 01:21:21Z zurawski $

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
