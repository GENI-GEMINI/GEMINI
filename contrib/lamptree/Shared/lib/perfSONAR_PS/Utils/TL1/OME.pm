package perfSONAR_PS::Utils::TL1::OME;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Utils::TL1::OME

=head1 DESCRIPTION

OME specific extensions to the TL1 utilities.

=cut

use Params::Validate qw(:all);
use Data::Dumper;
use perfSONAR_PS::Utils::ParameterValidation;

use base 'perfSONAR_PS::Utils::TL1::Base';
use fields 'PMS', 'PM_CACHE_TIME', 'OMS', 'OM_CACHE_TIME', 'ALARMS', 'ALARMS_CACHE_TIME', 'CROSSCONNECTS', 'CROSSCONNECTS_CACHE_TIME', 'ETHERNET_PORTS', 'ETHERNET_PORTS_CACHE_TIME', 'OPTICAL_PORTS', 'OPTICAL_PORTS_CACHE_TIME', 'WAN_PORTS', 'WAN_PORTS_CACHE_TIME';

=head2 initialize()

TBD

=cut

sub initialize {
    my ( $self, @params ) = @_;

    my $parameters = validate(
        @params,
        {
            address    => 1,
            port       => 0,
            username   => 1,
            password   => 1,
            cache_time => 1,
        }
    );

    $parameters->{"type"}   = "ome";
    $parameters->{"prompt"} = "<" if ( not $parameters->{"prompt"} );
    $parameters->{"port"}   = "23" if ( not $parameters->{"port"} );

    $self->{OPTICAL_PORTS_CACHE_TIME}  = 0;
    $self->{ETHERNET_PORTS_CACHE_TIME} = 0;
    $self->{WAN_PORTS_CACHE_TIME}      = 0;
    $self->{PM_CACHE_TIME}             = 0;
    $self->{OM_CACHE_TIME}             = 0;
    $self->{CROSSCONNECTS_CACHE_TIME}  = 0;

    return $self->SUPER::initialize( $parameters );
}

=head2 get_optical_facilities($facility_name)

A function to grab the set of optical facilities on the switch. If a facility
name is specified, it returns a hash containing the properties of that
facility. If no facility name is specified, it returns a hash whose keys are
the facility names and whose values are hashes with the facility properties.

=cut

sub get_optical_facilities {
    my ( $self, $facility_name ) = @_;

    if ( $self->{OPTICAL_PORTS_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %ocns = ();

        foreach my $i ( 3, 12, 48, 192 ) {
            my ( $successStatus, $results ) = $self->send_cmd( "RTRV-OC" . $i . "::ALL:" . $self->{CTAG} . ";" );
            if ( $successStatus != 1 ) {
                return ( -1, $results );
            }

            $self->{LOGGER}->debug( "Got OC$i line\n" );

            foreach my $line ( @$results ) {
                $self->{LOGGER}->debug( $line . "\n" );

                #   "OC192-1-5-1::TMGREF=Y,DCC=N,,SDTH=6,,,,,ALS=DISABLED,DUSOVERRIDE=DISABLED,EBERTH=3,PORTMODE=SONET,UNEQMODE=STS1,,:IS,DISCD"
                #   "OC192-1-6-1::TMGREF=Y,DCC=N,,SDTH=6,,,,,ALS=DISABLED,DUSOVERRIDE=DISABLED,EBERTH=3,PORTMODE=SONET,UNEQMODE=STS1,,:IS,"
                #   "OC192-1-9-1::TMGREF=Y,DCC=N,,SDTH=6,,,,,ALS=DISABLED,DUSOVERRIDE=DISABLED,EBERTH=3,PORTMODE=SONET,UNEQMODE=STS1,,:IS,DISCD"

                if ( $line =~ /"([^:]*:[^:]*:[^:]*:[^"]*)"/ ) {
                    $line = $1;

                    my %ocn = ();

                    my @fields = split( ':', $line );
                    my $aid = $fields[0];
                    my ( $pst, $sst ) = split( ',', $fields[3] );

                    $ocn{facility}      = $aid;
                    $ocn{facility_type} = "oc" . $i;

                    foreach my $pair ( split( ',', $fields[2] ) ) {
                        next if ( not $pair );

                        my ( $key, $value ) = split( '=', $pair );

                        $ocn{ lc( $key ) } = $value;
                    }

                    $ocn{pst} = $pst;
                    $ocn{sst} = $sst;

                    $ocns{$aid} = \%ocn;
                }
            }
        }

        $self->{OPTICAL_PORTS}            = \%ocns;
        $self->{OPTICAL_PORTS_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{OPTICAL_PORTS} );
    }

    return ( 0, $self->{OPTICAL_PORTS}->{$facility_name} );
}

=head2 get_ethernet_facilities($facility_name)

A function to grab the set of ethernet facilities on the switch. If a facility
name is specified, it returns a hash containing the properties of that
facility. If no facility name is specified, it returns a hash whose keys are
the facility names and whose values are hashes with the facility properties.

=cut

sub get_ethernet_facilities {
    my ( $self, $facility_name ) = @_;

    if ( $self->{ETHERNET_PORTS_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %eths = ();

        foreach my $type ( "ETH", "ETH10G" ) {
            my ( $successStatus, $results ) = $self->send_cmd( "RTRV-" . $type . "::" . $type . "-1-ALL:" . $self->{CTAG} . ";" );
            if ( $successStatus != 1 ) {
                return ( -1, $results );
            }

#   "ETH-1-4-3::AN=ENABLE,ANSTATUS=INPROGRESS,ANETHDPX=UNKNOWN,ANSPEED=UNKNOWN,ANPAUSETX=UNKNOWN,ANPAUSERX=UNKNOWN,ADVETHDPX=UNKNOWN,ADVSPEED=UNKNOWN,ADVFLOWCTRL=UNKNOWN,ETHDPX=FULL,SPEED=1000,FLOWCTRL=ASYM,PAUSETX=ENABLE,PAUSERX=DISABLE,PAUSERXOVERRIDE=ENABLE,MTU=9600,TXCON=ENABLE,PASSCTRL=DISABLE,PAUSETXOVERRIDE=DISABLE,RXIDLE=0,CFPRF=CFPRF-1-4,PHYSADDR=00140D034877:OOS-MA,DISCD"
#   "ETH-1-4-4::AN=ENABLE,ANSTATUS=INPROGRESS,ANETHDPX=UNKNOWN,ANSPEED=UNKNOWN,ANPAUSETX=UNKNOWN,ANPAUSERX=UNKNOWN,ADVETHDPX=UNKNOWN,ADVSPEED=UNKNOWN,ADVFLOWCTRL=UNKNOWN,ETHDPX=FULL,SPEED=1000,FLOWCTRL=ASYM,PAUSETX=ENABLE,PAUSERX=DISABLE,PAUSERXOVERRIDE=ENABLE,MTU=9600,TXCON=ENABLE,PASSCTRL=DISABLE,PAUSETXOVERRIDE=DISABLE,RXIDLE=0,CFPRF=CFPRF-1-4,PHYSADDR=00140D034878:OOS-MA,DISCD"

            foreach my $line ( @$results ) {
                $self->{LOGGER}->debug( $line );
                if ( $line =~ /"([^:]*:[^:]*:[^:]*:[^"]*)"/ ) {
                    $line = $1;

                    my %eth = ();

                    my @fields = split( ':', $line );
                    my $aid = $fields[0];
                    my ( $pst, $sst ) = split( ',', $fields[3] );

                    $eth{facility}      = $aid;
                    $eth{facility_type} = "ethernet";

                    foreach my $pair ( split( ',', $fields[2] ) ) {
                        next if ( not $pair );

                        my ( $key, $value ) = split( '=', $pair );

                        $eth{ lc( $key ) } = $value;
                    }

                    $eth{pst} = $pst;
                    $eth{sst} = $sst;

                    $eths{$aid} = \%eth;
                }
            }
        }

        $self->{ETHERNET_PORTS}            = \%eths;
        $self->{ETHERNET_PORTS_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{ETHERNET_PORTS} );
    }

    return ( 0, $self->{ETHERNET_PORTS}->{$facility_name} );
}

=head2 get_wan_facilities()

A function to grab the set of WAN facilities on the switch. If a facility
name is specified, it returns a hash containing the properties of that
facility. If no facility name is specified, it returns a hash whose keys are
the facility names and whose values are hashes with the facility properties.

=cut

sub get_wan_facilities {
    my ( $self, $facility_name ) = @_;

    if ( $self->{WAN_PORTS_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %wans = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-WAN::WAN-1-ALL:" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        $self->{LOGGER}->debug( "Got OCN Lines\n" );

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

            #   "WAN-1-10-1::MAPPING=GFP-F,FCS=0,CONDTYPE=GFPCMF,GFPRFI=ENABLE,PROVRXUNITS=0,GFPRTDELAY=ENABLE,RATE=NONE,LCAS=DISABLE,VCAT=ENABLE,PROVUNITS=0,ACTUALUNITS=0,LANFCS=ENABLE,RTDELAY=UNKNOWN,MAXVCDEL=0,CURRVCDEL=0,SCRAMBLE=ENABLE,ACTUALRXUNITS=0:OOS-MA,DISCD"
            #   "WAN-1-12-1::MAPPING=GFP-F,FCS=32,CONDTYPE=GFPCMF,GFPRFI=ENABLE,PROVRXUNITS=0,GFPRTDELAY=ENABLE,RATE=NONE,LCAS=DISABLE,VCAT=DISABLE,PROVUNITS=0,ACTUALUNITS=0,LANFCS=ENABLE,RTDELAY=UNKNOWN,MAXVCDEL=0,CURRVCDEL=0,SCRAMBLE=ENABLE,ACTUALRXUNITS=0:OOS-MA,DISCD"
            if ( $line =~ /"([^:]*:[^:]*:[^:]*:[^"]*)"/ ) {
                $line = $1;
                my %wan = ();

                my @fields = split( ':', $line );
                my $aid = $fields[0];
                my ( $pst, $sst ) = split( ',', $fields[3] );

                $wan{facility}      = $aid;
                $wan{facility_type} = "wan";

                foreach my $pair ( split( ',', $fields[2] ) ) {
                    next if ( not $pair );

                    my ( $key, $value ) = split( '=', $pair );

                    $wan{ lc( $key ) } = $value;
                }

                $wan{pst} = $pst;
                $wan{sst} = $sst;

                $wans{$aid} = \%wan;
            }
        }

        $self->{WAN_PORTS}            = \%wans;
        $self->{WAN_PORTS_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{WAN_PORTS} );
    }

    return ( 0, $self->{WAN_PORTS}->{$facility_name} );
}

=head2 get_crossconnects()

A function to grab the crossconnect facilities on the switch. The function
returns a hash whose keys are of the form "[source facility]_[destination
facility]" and whose values are hashes with the crossconnects properties.

=cut

sub get_crossconnects {
    my ( $self ) = @_;

    if ( $self->{CROSSCONNECTS_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %crss = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-CRS-ALL:::" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        $self->{LOGGER}->debug( "Got CRS Lines\n" );

        #   "STS3C-1-6-1-37,STS3C-1-1-4-16:2WAY::STS3C:"
        #   "STS24C-1-6-1-169,STS24C-1-1-1-1:2WAY::STS24C:"
        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

            if ( $line =~ /"([^,]*),([^:]*):([^:]*):([^:]*):([^:]*):([^"]*)"/ ) {
                my %crs = ();
                $crss{ $1 . "-" . $2 } = \%crs;

                $crs{fromendpointname} = $1;
                $crs{fromendpointtype} = lc( $5 );
                $crs{toendpointname}   = $2;
                $crs{toendpointtype}   = lc( $5 );
                $crs{direction}        = $3;
                $crs{rate}             = lc( $5 );

                if ( $4 and $4 =~ /CKTID=([^,])*/ ) {
                    $crs{cktid} = $1;
                }
            }
        }

        $self->{CROSSCONNECTS}            = \%crss;
        $self->{CROSSCONNECTS_CACHE_TIME} = time;
    }

    return ( 0, $self->{CROSSCONNECTS} );
}

=head2 get_alarms()

A function to return the current alarms on the switch. It returns the alarms as
an array of hashes with each hash describing a different alarm.

=cut

sub get_alarms {
    my ( $self ) = @_;

    if ( $self->{ALARMS_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my @alarms = ();

        $self->{LOGGER}->debug( "looking up alarms" );

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-ALM-ALL:::" . $self->{CTAG} . "::;" );

        $self->{LOGGER}->debug( "Results: " . Dumper( $results ) );

        if ( $successStatus != 1 ) {
            $self->{ALARMS} = undef;
            return ( -1, $results );
        }

        #   "ETH10G-1-10-4,ETH10G:CR,LOS,SA,01-07,07-34-55,NEND,RCV:\"Loss Of Signal\",NONE:0100000295-0008-0673,:YEAR=2006,MODE=NONE"
        foreach my $line ( @{$results} ) {
            if ( $line =~ /"([^,]*),([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):([^,]*),([^:]*):([^,]*),([^:]*):YEAR=([^,]*),MODE=([^"]*)"/ ) {
                my $facility         = $1;
                my $facility_type    = $2;
                my $severity         = $3;
                my $alarmType        = $4;
                my $serviceAffecting = $5;
                my $date             = $6;
                my $time             = $7;
                my $location         = $8;
                my $direction        = $9;
                my $description      = $10;
                my $something1       = $11;
                my $alarmId          = $12;
                my $something2       = $13;
                my $year             = $14;
                my $mode             = $15;

                $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );
                $description =~ s/\\"//g;
                $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );

                my $timestamp = $self->convertTimeStringToTimestamp( $self->convertPMDateTime( $date, $time ) );

                my %alarm = (
                    facility          => $facility,
                    facility_type     => $facility_type,
                    severity          => $severity,
                    alarm_type        => $alarmType,
                    alarm_time        => $timestamp,
                    alarm_time_local  => $self->convertMachineTSToLocalTS( $timestamp ),
                    description       => $description,
                    service_affecting => $serviceAffecting,
                    measurement_time  => time,
                    date              => $date,
                    time              => $time,
                    location          => $location,
                    direction         => $direction,
                    alarm_id          => $alarmId,
                    year              => $year,
                    mode              => $mode,
                );

                push @alarms, \%alarm;
            }
        }

        $self->{ALARMS}            = \@alarms;
        $self->{ALARMS_CACHE_TIME} = time;
    }

    my @ret_alarms = ();

    foreach my $alarm ( @{ $self->{ALARMS} } ) {
        push @ret_alarms, $alarm;
    }

    return ( 0, \@ret_alarms );
}

=head2 wait_event({ timeout => 0 })

A function that will wait for an autonymous event to come from the switch and
will return that a hash containing that event's properties. If a timeout value is
specified, the function will return after that many seconds if no events have
occurred.

=cut

sub wait_event {
    my ( $self, @args ) = @_;
    my $args = validateParams( @args, { timeout => { type => SCALAR }, } );

    my ( $status, $lines );
    if ( $args->{timeout} ) {
        ( $status, $lines ) = $self->waitMessage( { type => "event", timeout => $args->{timeout} } );
    }
    else {
        ( $status, $lines ) = $self->waitMessage( { type => "event" } );
    }

    if ( $status != 0 or not defined $lines ) {
        return ( -1, undef );
    }

    foreach my $line ( @{$lines} ) {

        # "WAN-1-4-1:T-UAS-W,TC,01-14,17-30-21,NEND,RCV,10,10,15-MIN:\"T-UAS-W\":0100000000-0000-0000,:YEAR=2009,MODE=NONE"
        if ( $line =~ /"([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):([^:]*):([^,]*),([^:]*):YEAR=([^,]*),MODE=([^"]*)"/ ) {
            my $aid            = $1;
            my $condtype       = $2;
            my $effect         = $3;
            my $date           = $4;
            my $time           = $5;
            my $location       = $6;
            my $direction      = $7;
            my $monitoredValue = $8;
            my $thresholdLevel = $9;
            my $timePeriod     = $10;
            my $description    = $11;
            my $eventId        = $12;
            my $something      = $13;
            my $year           = $14;
            my $mode           = $15;

            $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );
            $description =~ s/\\"//g;
            $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );

            my %event = (
                facility    => $aid,
                eventType   => $condtype,
                effect      => $effect,
                date        => $date,
                time        => $time,
                location    => $location,
                direction   => $direction,
                value       => $monitoredValue,
                threshold   => $thresholdLevel,
                period      => $timePeriod,
                description => $description,
                eventId     => $eventId,
                year        => $year,
                mode        => $mode,
            );

            return ( 0, \%event );
        }
    }

    return ( -1, undef );
}

=head2 wait_alarm({ timeout => 0 })

A function that will wait for an alarm to be signaled from the switch and will
return that a hash containing that alarms's properties. If a timeout value is
specified, the function will return after that many seconds if no alarms have
occurred.

=cut

sub wait_alarm {
    my ( $self, @args ) = @_;
    my $args = validateParams( @args, { timeout => { type => SCALAR }, } );

    my ( $status, $lines );
    if ( defined $args->{timeout} ) {
        ( $status, $lines ) = $self->waitMessage( { type => "alarm", timeout => $args->{timeout} } );
    }
    else {
        ( $status, $lines ) = $self->waitMessage( { type => "alarm" } );
    }

    if ( $status != 0 or not defined $lines ) {
        return ( -1, undef );
    }

    foreach my $line ( @{$lines} ) {
        if ( $line =~ /"([^,]*),([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):([^,]*),([^:]*):([^,]*),([^:]*):YEAR=([^,]*),MODE=([^"]*)"/ ) {
            my $facility         = $1;
            my $facility_type    = $2;
            my $severity         = $3;
            my $alarmType        = $4;
            my $serviceAffecting = $5;
            my $date             = $6;
            my $time             = $7;
            my $location         = $8;
            my $direction        = $9;
            my $description      = $10;
            my $something1       = $11;
            my $alarmId          = $12;
            my $something2       = $13;
            my $year             = $14;
            my $mode             = $15;

            $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );
            $description =~ s/\\"//g;
            $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );

            my $timestamp = $self->convertTimeStringToTimestamp( $self->convertPMDateTime( $date, $time ) );

            my %alarm = (
                facility          => $facility,
                facility_type     => $facility_type,
                severity          => $severity,
                alarm_type        => $alarmType,
                alarm_time        => $timestamp,
                alarm_time_local  => $self->convertMachineTSToLocalTS( $timestamp ),
                description       => $description,
                service_affecting => $serviceAffecting,
                measurement_time  => time,
                date              => $date,
                time              => $time,
                location          => $location,
                direction         => $direction,
                alarm_id          => $alarmId,
                year              => $year,
                mode              => $mode,
            );

            return ( 0, \%alarm );
        }
    }

    return ( -1, undef );
}

=head2 get_ethernet_pms($facility_name, $pm_type)

A function which returns the current ethernet performance counters for a
switch. If the facility name is specified, it only returns the performance
counters for that facility. If a $pm_type is specified, it will only return
performance counters of that type.

=cut

sub get_ethernet_pms {
    my ( $self, $aid, $pm_type ) = @_;

    my %facility_types = ( "eth" => 1, "eth10g" => 1 );

    if ( $self->{OM_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my ( $status, $res ) = $self->readETH_OMs();
        if ( $status != 0 ) {
            return ( $status, $res );
        }

        $self->{OMS} = $res;
    }

    if ( $aid and $pm_type ) {
        $self->{LOGGER}->debug( "Returning $aid/$pm_type" );
        return ( 0, $self->{OMS}->{$aid}->{$pm_type} );
    }

    my %pm = ();
    foreach my $curr_aid ( keys %{ $self->{OMS} } ) {
        next if ( $aid and $aid ne $curr_aid );

        foreach my $curr_type ( keys %{ $self->{OMS}->{$curr_aid} } ) {
            next if ( $pm_type and $pm_type ne $curr_type );

            $self->{LOGGER}->debug( "Found $curr_type for $aid" );

            my $pm = $self->{OMS}->{$curr_aid}->{$curr_type};

            $pm{$curr_aid}->{$curr_type} = $pm;
        }
    }

    if ( $aid ) {
        return ( 0, $pm{$aid} );
    }
    else {
        return ( 0, \%pm );
    }
}

=head2 get_optical_pms($facility_name, $pm_type)

A function which returns the current optical performance counters for a
switch. If the facility name is specified, it only returns the performance
counters for that facility. If a $pm_type is specified, it will only return
performance counters of that type.

=cut

sub get_optical_pms {
    my ( $self, $aid, $pm_type ) = @_;

    my %facility_types = ( "oc3" => 1, "oc12" => 1, "oc48" => 1, "oc192" => 1 );

    return $self->__get_PM( $aid, $pm_type, \%facility_types );
}

=head2 __get_PM ()

An internal function which can be used to grab any of the PM counters. Since
the PM counters are grabbed in mass, this allows the construction of functions
to grab subsets of the PM counters.

=cut

sub __get_PM {
    my ( $self, $aid, $pm_type, $valid_facility_types ) = @_;

    if ( $self->{PM_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my ( $status, $res ) = $self->readPMs();
        if ( $status != 0 ) {
            return ( $status, $res );
        }

        $self->{PMS} = $res;
    }

    if ( $aid and $pm_type ) {
        $self->{LOGGER}->debug( "Returning $aid/$pm_type" );
        return ( 0, $self->{PMS}->{$aid}->{$pm_type} );
    }

    my %pm = ();
    foreach my $curr_aid ( keys %{ $self->{PMS} } ) {
        next if ( $aid and $aid ne $curr_aid );

        foreach my $curr_type ( keys %{ $self->{PMS}->{$curr_aid} } ) {
            next if ( $pm_type and $pm_type ne $curr_type );

            my $pm = $self->{PMS}->{$curr_aid}->{$curr_type};

            next unless ( $valid_facility_types->{ lc( $pm->{facility_type} ) } );

            $pm{$curr_aid}->{$curr_type} = $pm;
        }
    }

    if ( $aid ) {
        return ( 0, $pm{$aid} );
    }
    else {
        return ( 0, \%pm );
    }
}

=head2 readPMs()

A function to read all the performance counters on the machine and cache them.
This is called by the functions to get optical performance counters whenever
the users requests more up to date statistics.

=cut

sub readPMs {
    my ( $self ) = @_;
    my %pms = ();

    my ( $successStatus, $results );

    ( $successStatus, $results ) = $self->send_cmd( "RTRV-PM-ALL::ALL:" . $self->{CTAG} . ":::;" );
    if ( $successStatus != 1 ) {
        return ( -1, $results );
    }

    foreach my $line ( @$results ) {
        $self->{LOGGER}->debug( $line . "\n" );

        #       "OC192-1-5-1,OC192:OPR-OCH,-3.06,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
        if ( $line =~ /"([^,]*),([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^",]*),?\d?"/ ) {
            my $facility        = $1;
            my $facility_type   = $2;
            my $pm_type         = $3;
            my $pm_value        = $4;
            my $validity        = $5;
            my $location        = $6;
            my $direction       = $7;
            my $time_period     = $8;
            my $monitoring_date = $9;
            my $monitoring_time = $10;

            my $monitoredPeriodStart = $self->convertPMDateTime( $monitoring_date, $monitoring_time );

            my %pm = (
                facility          => $facility,
                facility_type     => $facility_type,
                type              => $pm_type,
                value             => $pm_value,
                time_period       => $time_period,
                time_period_start => $monitoredPeriodStart,
                measurement_type  => "bucket",
                measurement_time  => time,
                machine_time      => $self->getMachineTime_TS(),
                date              => $monitoring_date,
                time              => $monitoring_time,
                validity          => $validity,
                location          => $location,
                direction         => $direction,
            );

            $pms{$facility}->{$pm_type} = \%pm;
        }
    }

    return ( 0, \%pms );
}

=head2 readETH_OMs()

A function to read all the ethernet performance counters on the machine and cache them.
This is called by the functions to get ethernet performance counters whenever
the users requests more up to date statistics.

=cut

sub readETH_OMs {
    my ( $self ) = @_;
    my %pms = ();

    foreach my $type ( "ETH", "ETH10G" ) {
        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-OM-" . $type . "::" . $type . "-1-ALL:" . $self->{CTAG} . ":::;" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

#   "ETH10G-1-10-1::INFRAMES=104322825591,INFRAMESERR=0,INOCTETS=107554715270446,INDFR=88963,INFRAMESDISCDS=12109,INPAUSEFR=0,INCFR=0,FRTOOSHORTS=0,FCSERR=0,FRTOOLONGS=76854,FRAG=0,JAB=0,SYMBOLERR=0,OUTFRAMES=108023304001,OUTFRAMESERR=163,OUTOCTETS=107341268770788,OUTFRAMESDISCDS=0,OUTPAUSEFR=536,OUTDFR=0,INTERNALMACRXERR=0,INTERNALMACTXERR=0"

            if ( $line =~ /"([^:]*):([^:]*):([^"]*)"/ ) {
                my $facility      = $1;
                my $facility_type = "ethernet";
                foreach my $pair ( split( ',', $3 ) ) {
                    my ( $type, $value ) = split( '=', $pair );

                    my %pm = (
                        facility         => $facility,
                        facility_type    => $facility_type,
                        type             => $type,
                        value            => $value,
                        measurement_type => "counter",
                        measurement_time => time,
                        machine_time     => $self->getMachineTime_TS(),
                    );

                    $pms{$facility}->{$type} = \%pm;
                }
            }
        }
    }

    return ( 0, \%pms );
}

# Possible monitoring types:
# CV-S - Coding Violations
# ES-S - Errored Seconds - Section
# SES-S - Severely Errored Seconds - Section
# SEFS-S - Severely Errored Frame Seconds - Section
# CV-L - Coding Violations - Line
# ES-L - Errored Seconds - Line
# SES-L - Severely Errored Seconds - Line
# UAS-L - Unavailable Seconds - Line
# FC-L - Failure Count - Line
# OPR-OCH - Optical Power Receive - Optical Channel. When tmper=1- UNT this is a gauge value; when tmper=1-15-MIN, 1-DAY this is a snapshot value
# OPT-OCH - Optical Power Transmit - Optical Channel
# OPRN-OCH - Optical Power Receive - Normalised - Optical Channel
# OPTN-OCH - Optical Power Transmit - Normalised - Optical Channel
# CV-OTU - Coding Violations - OTU
# ES-OTU - Errored Seconds - OTU
# SES-OTU Severely Errored Seconds - OTU
# SEFS-OTU Severely Errored Framing Seconds - OTU
# FEC-OTU Forward Error Corrections - OTU
# HCCS-OTU High Correction Count Seconds - OTU
# CV-ODU Coding Violations - ODU
# ES-ODU Errored Seconds - ODU
# SES-ODU Severely Errored Seconds - ODU
# UAS-ODU Unavailable Seconds - ODU
# FC-ODU Failure Count - ODU
# CV-PCS Coding Violations ? Physical Coding Sublayer
# ES-PCS Errored Seconds - Physical Coding Sublayer
# SES-PCS Severely Errored Seconds - Physical Coding Sublayer
# UAS-PCS Unavailable Seconds - Physical Coding Sublayer
# ES-E Errored Seconds ? ETH
# SES-E Severely Errored Seconds ? ETH
# UAS-E Unavailable Seconds ? ETH
# INFRAMES-E Number of frames received (binned OM) - Ethernet, valid only for Ethernet and WAN
# INFRAMESERR-E Number of errored frames received ? ETH
# INFRAMEDISCDS-E Number of ingress discarded frames due to congestion or overflow ? ETH
# DFR-E Aggregate count of discarded frames ? ETH
# OUTFRAMES-E Number of frames transmitted (binned OM)- Ethernet
# FCSERR-E Frame Check Sequence Errors (binned OM) - Ethernet
# PFBERE-OTU Post-FEC Bit Error Rate Estimates - OTU. When tmper=1-UNT this is a gauge value; when tmper=1-15-MIN, 1-DAY this is a snapshot value
# PRFBER-OTU Pre-FEC Bit Error Rate - OTU
# ES-W Errored Seconds - WAN
# SES-W Severely Errored Seconds ? WAN
# UAS-W Unavailable Seconds ? WAN
# INFRAMES-W Number of frames received (binned OM) - WAN
# INFRAMESERR-W Number of errored frames received ? WAN
# OUTFRAMES-W ANumber of frames transmitted (binned OM)- WAN
# ES-W Errored Seconds ? WAN
# SES-W Severely Errored Seconds ? WAN
# UAS-W Unavailable Seconds ? WAN
# INFRAMES-W Number of frames received (binned OM) - WAN
# INFRAMESERR-W Number of errored frames received ? WAN
# OUTFRAMES-W ANumber of frames transmitted (binned OM)- WAN

#   "OC192-1-5-1,OC192:OPR-OCH,-3.06,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-5-1,OC192:OPT-OCH,-2.15,PRTL,NEND,TRMT,15-MIN,06-16,15-15,0"
#   "OC192-1-5-1,OC192:OPRN-OCH,58,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-6-1,OC192:OPR-OCH,-2.78,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-6-1,OC192:OPT-OCH,-2.25,PRTL,NEND,TRMT,15-MIN,06-16,15-15,0"
#   "OC192-1-6-1,OC192:OPRN-OCH,64,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-9-1,OC192:OPR-OCH,0.36,ADJ,NEND,RCV,15-MIN,06-16,15-15,0"
#   "OC192-1-9-1,OC192:OPT-OCH,-2.27,PRTL,NEND,TRMT,15-MIN,06-16,15-15,0"
#   "OC192-1-9-1,OC192:OPRN-OCH,100,ADJ,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-64,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-67,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-70,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-73,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-76,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-79,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "STS3C-1-6-1-82,STS3C:UAS-P,311,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "WAN-1-2-2,WAN:UAS-W,314,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"
#   "ETH-1-2-2,ETH:UAS-E,314,PRTL,NEND,RCV,15-MIN,06-16,15-15,0"

=head2 login()

A function for logging into the OME. The OMEs require that passwords be in
quotes so this function overrides the normal login function to handle that
case.

=cut

sub login {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { inhibit_messages => { type => SCALAR, optional => 1, default => 1 }, } );

    #    my ($status, $lines) = $self->waitMessage({ type => "other" });
    #    if ($status != 0 or not defined $lines) {
    #        $self->{LOGGER}->debug("login failed");
    #        return -1;
    #    }

    $self->{LOGGER}->debug( "PASSWORD: $self->{PASSWORD}\n" );

    my ( $status, $lines ) = $self->send_cmd( "ACT-USER::" . $self->{USERNAME} . ":" . $self->{CTAG} . "::\"" . $self->{PASSWORD} . "\";" );

    if ( $status != 1 ) {
        return 0;
    }

    if ( $parameters->{inhibit_messages} ) {
        $self->send_cmd( "INH-MSG-ALL:::" . $self->{CTAG} . ";" );
    }

    return 1;
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: OME.pm 2666 2009-03-24 14:17:20Z aaron $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
