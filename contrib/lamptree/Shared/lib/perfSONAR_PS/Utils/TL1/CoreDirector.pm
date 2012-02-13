package perfSONAR_PS::Utils::TL1::CoreDirector;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Utils::TL1::CoreDirector

=head1 DESCRIPTION

Core Director specific extensions to the TL1 utilities.

=cut

use Params::Validate qw(:all);
use perfSONAR_PS::Utils::ParameterValidation;
use Data::Dumper;

use base 'perfSONAR_PS::Utils::TL1::Base';
use fields 'ALARMS', 'COUNTERS', 'EFLOWSBYNAME', 'CRSSBYNAME', 'ETHSBYAID', 'GTPSBYNAME', 'OCNSBYAID', 'SNCSBYNAME', 'VCGSBYNAME', 'STSSBYNAME', 'ALARMS_CACHE_TIME', 'EFLOWSBYNAME_CACHE_TIME', 'CRSSBYNAME_CACHE_TIME', 'ETHSBYAID_CACHE_TIME', 'GTPSBYNAME_CACHE_TIME', 'OCNSBYAID_CACHE_TIME', 'SNCSBYNAME_CACHE_TIME', 'VCGSBYNAME_CACHE_TIME', 'STSSBYNAME_CACHE_TIME';

=head2 initialize()

Prepare the object

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

    $parameters->{"type"}   = "coredirector";
    $parameters->{"prompt"} = ";" if ( not $parameters->{"prompt"} );
    $parameters->{"port"}   = "10201" if ( not $parameters->{"port"} );

    $self->{ALARMS_CACHE_TIME}       = 0;
    $self->{EFLOWSBYNAME_CACHE_TIME} = 0;
    $self->{CRSSBYNAME_CACHE_TIME}   = 0;
    $self->{ETHSBYAID_CACHE_TIME}    = 0;
    $self->{GTPSBYNAME_CACHE_TIME}   = 0;
    $self->{OCNSBYAID_CACHE_TIME}    = 0;
    $self->{SNCSBYNAME_CACHE_TIME}   = 0;
    $self->{VCGSBYNAME_CACHE_TIME}   = 0;
    $self->{STSSBYNAME_CACHE_TIME}   = 0;

    return $self->SUPER::initialize( $parameters );
}

=head2 get_vcgs($facility_name)

A function to grab the set of virtual concatenation group (VCG) facilities on
the switch. If a facility name is specified, it returns a hash containing the
properties of that facility. If no facility name is specified, it returns a
hash whose keys are the facility names and whose values are hashes with the
facility properties.

=cut

sub get_vcgs {
    my ( $self, $facility_name ) = @_;

    if ( $self->{VCGSBYNAME_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %vcgs = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-VCG::ALL:" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return;
        }

        $self->{LOGGER}->debug( "Got VCG Lines\n" );

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

#"1-A-3-1:189-190,PST=OOS-AU,SST=[ALM,ACT],ALIAS=nms-oexp2.newy:FPGA2_TO_nms-oexp2.hous:FPGA2,SUPPTTP=1-A-3-1,CRCTYPE=CRC_32,SPICHANNEL=,DEGRADETHRESHOLD=2,CONCATIFTYPE=SONET,STSSIZE=STS1,TUNNELPEERTYPE=ETTP,TUNNELPEERNAME=1-A-3-1-9,MEMBERFAILCRITERIA=DLOM&LOP_P&AIS_P,GFPFCSENABLED=NO,DEFAULTJ1ENABLED=YES,LCASENABLED=NO,LCASHOLDOFFTIMER=1,LCASRSACKTIMER=2,CONFIGMONCHANNEL=1-A-3-1:189-190-CTP-189,ACTUALMONCHANNEL=,SCRAMBLINGBITENABLED=YES,FRAMINGMODE=GFP,GROUPMEM=189&&190,PROVBW=2,OPERBW=0,MAPPERBUFFERALLOCATION=AUTO,MAPPERBUFFERSAVAILABLE=56,MEMBERDETAIL={[1-A-3-1:189-190-CTP-190 190  LCAS_NA 255 NA LCAS_NA 255 NA]&[1-A-3-1:189-190-CTP-189 189  LCAS_NA 255 NA LCAS_NA 255 NA]},EFFIBASESEV=NR,VCGFAILUREBASESEV=NR"

            if ( $line =~ /"([^,]*),(.*PST.*)"/ ) {
                my %vcg = ();

                my @pairs = split( ",", $2 );
                foreach my $pair ( @pairs ) {
                    next if ( not $pair );

                    my ( $variable, $value ) = split( "=", $pair );
                    $variable = lc( $variable );

                    $vcg{$variable} = $value;
                }

                $vcg{name} = $1;
                $vcgs{$1} = \%vcg;
            }
        }

        $self->{VCGSBYNAME}            = \%vcgs;
        $self->{VCGSBYNAME_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{VCGSBYNAME} );
    }

    return ( 0, $self->{VCGSBYNAME}->{$facility_name} );
}

=head2 get_sncs($facility_name)

A function to grab the set of subnetwork connections (SNC) on the switch. If a
facility name is specified, it returns a hash containing the properties of that
facility. If no facility name is specified, it returns a hash whose keys are
the facility names and whose values are hashes with the facility properties.

=cut

sub get_sncs {
    my ( $self, $facility_name ) = @_;

    if ( $self->{SNCSBYNAME_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %sncs = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-SNC-STSPC::ALL:" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return;
        }

        $self->{LOGGER}->debug( "Got SNC Lines\n" );

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

#            "T3_1-A-4-1_S190,TYPE=PERM,FROMENDPOINT=T3_1-A-4-1_S190,TOENDPOINT=1-A-5-1-191,RMNODE=CHAR,LEP=GTP_NAMETYPE,EPTYPE=ORIGINATING,ALIAS=T3_1-A-4-1_S190,DTLEXCL=NO,REGROOM=NO,,SDHSE=NO,MESHRST=NO,,BCKOP=0,,TRVRT=0,PST=IS-NR,STATE=TERM_WORKING_CONNECTED,RATE=1,PEERSNC=,PEERORIGIN=,SNCLINETYPE=PROTECT,,,,,,VALIDSIGNALWASDETECTED=NO,REMOTEPATHPROTECTION=SNC_RMT_PATH_PROTECTION_HIGH_ORDER,MAXADMINWEIGHT=0"

            if ( $line =~ /"([^,]*),(.*PST.*)"/ ) {
                my %snc = ();

                my @pairs = split( ",", $2 );
                foreach my $pair ( @pairs ) {
                    next if ( not $pair );

                    my ( $variable, $value ) = split( "=", $pair );
                    $variable = lc( $variable );

                    $snc{$variable} = $value;
                }

                $snc{name} = $1;
                $sncs{$1} = \%snc;
            }
        }

        $self->{SNCSBYNAME}            = \%sncs;
        $self->{SNCSBYNAME_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{SNCSBYNAME} );
    }

    return ( 0, $self->{SNCSBYNAME}->{$facility_name} );
}

=head2 get_ctps($facility_name)

A function to grab the set of connection termination points (CTP) on the
switch. If a facility name is specified, it returns a hash containing the
properties of that facility. If no facility name is specified, it returns a
hash whose keys are the facility names and whose values are hashes with the
facility properties.

=cut

sub get_ctps {
    my ( $self, $facility_name ) = @_;

    if ( $self->{STSSBYNAME_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %stss = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-STSPC:::" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return;
        }

        $self->{LOGGER}->debug( "Got STSPC Lines\n" );

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

#  "1-A-4-1-192,NAME=1-A-4-1:192-CTP-192,STSTYPE=1,ALIAS=1-A-4-1:192-CTP-192,GTPNAME=,STARTCHAN=192,SUPCK=CHIC:1-A-4-1:192_TO_INDI:1-A-5-1:192,SUPTP=1-A-4-1,CRSCONN=CHIC_CHIC:1-A-4-1:192_TO_INDI:1-A-5-1:192_1,SUPCPK=1-A-4-1,EXPTRC=,TRC=,TRCYN=YES,RCVTRC=1-A-5-1:1921c0,FMTPTRC=16_BYTE,INJ=NO,LOPI=NO,RFIIA=NO,SDI=YES,SFI=YES,SDTH=6,SFTH=3,PST=IS-NR,SST=ALM,DIAG=NONE,PLOADTYPE=AU3,PATHPROTSTATE=UNPROTECTED,TIMPI=YES,UNEQPI=YES"

            if ( $line =~ /"([^,]*),(.*PST.*)"/ ) {
                my %sts = ();

                my @pairs = split( ",", $2 );
                foreach my $pair ( @pairs ) {
                    next if ( not $pair );

                    my ( $variable, $value ) = split( "=", $pair );
                    $variable = lc( $variable );

                    $sts{$variable} = $value;
                }

                $sts{name} = $1;
                $stss{$1} = \%sts;
            }
        }

        $self->{STSSBYNAME}            = \%stss;
        $self->{STSSBYNAME_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{STSSBYNAME} );
    }

    return ( 0, $self->{STSSBYNAME}->{$facility_name} );
}

=head2 get_ethernet_facilities()

A function to grab the set of ethernet ports on the switch. If a facility name
is specified, it returns a hash containing the properties of that facility. If
no facility name is specified, it returns a hash whose keys are the facility
names and whose values are hashes with the facility properties.

NOTE: due to a bug that used to exist in the CoreDirector, ethernet ports must
be requested by name instead of grabbing all of them at once.

=cut

sub get_ethernet_facilities {
    my ( $self, $facility_name ) = @_;

#    if ( not defined $facility_name ) {
#        return;
#    }

    $facility_name = "ALL" unless ($facility_name);

    if ( $self->{ETHSBYAID_CACHE_TIME} + $self->{CACHE_DURATION} > time ) {
        if ($facility_name ne "ALL") {
            return ( 0, $self->{ETHSBYAID}->{$facility_name} );
        } else {
            return ( 0, $self->{ETHSBYAID});
        }
    }

    my ( $successStatus, $results ) = $self->send_cmd( "RTRV-GIGE::$facility_name:" . $self->{CTAG} . ";" );
    if ( $successStatus != 1 ) {
        return;
    }

    $self->{LOGGER}->debug( "Got GigE Lines\n" );

    my %eths = ();
    foreach my $line ( @$results ) {
        $self->{LOGGER}->debug( $line . "\n" );

#   "1-A-4-1-1,ALIAS=manlan-switch:Te12/4,,ETHERPHY=10GBASE_R,TUNNELPEERTYPE=VCG,TUNNELPEERNAME=1-A-4-1:1-192,,,,,,RMTLASERSHUTDOWN=IDLE,RMTLASERSHUTDOWNDELAY=3,LOCK=IDLE,LOSIA=CR,ERFIIA=NR,LAGMEMBERSHIP=,DFLTVLANID=1,DFLTCOS=CLASS_OF_SVC_2,COSCFG=SystemDefault,RECEIVECONDITION=NORMAL,PST=IS-NR,SST=[ALM,BUSY]"

        if ( $line =~ /"([^,]*),(.*PST=.*)"/ ) {
            my %eth = ();

            my @pairs = split( ",", $2 );
            foreach my $pair ( @pairs ) {
                next if ( not $pair );

                my ( $variable, $value ) = split( "=", $pair );
                $variable = lc( $variable );

                $eth{$variable} = $value;
            }

            $eth{name} = $1;
            $eths{$1} = \%eth;
        }
    }

    if ($facility_name ne "ALL") {
        return ( 0, $eths{$facility_name} );
    } else {
        $self->{ETHSBYAID} = \%eths;
        $self->{ETHSBYAID_CACHE_TIME} = time;
        return ( 0, \%eths );
    }
}

=head2 get_optical_facilities($facility_name)

A function to grab the set of optical ports on the switch. If a facility name
is specified, it returns a hash containing the properties of that facility. If
no facility name is specified, it returns a hash whose keys are the facility
names and whose values are hashes with the facility properties.

=cut

sub get_optical_facilities {
    my ( $self, $facility_name ) = @_;

    if ( $self->{OCNSBYAID_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %ocns = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-OCN::ALL:" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        $self->{LOGGER}->debug( "Got OCN Lines\n" );

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

#   "1-A-3-1,ITYPE=SONET,RCVTRC=,TRC=,EXPTRC=,FMTSTRC=16_BYTE,ETRC=NO,DCC=NO,UCC=NO,LDCC=YES,XDCC=NO,ISCCMD=Unprotected,,,,PST=OOS-AUMA,SST=ALM,FERFNC=YES,AISIA=YES,LOFIA=NO,LOSIA=NO,SDIA=NO,SFIA=NO,TIMSIA=YES,OPTINHIBITLOWFAIL15MINTCA=NO,,,,,OPRINHIBITHIGHFAIL15MINTCA=NO,,,,,,,LOSDT=100,SDT=7,SDTC=8,SFT=4,SFTC=5,TSTMD=NONE,RATE=OC192,LMTYPE=LM2,FSSM=NO,TSSM=PRS,RSSM=NONE,TIMESLOTMAP=,NOACTP=0,UTILIZATION=0/192,PTYPE=None,LTYPE=Unprotected,PPPADMIN=LOCKED,PPPLINESTATE=PPP_NEGOTIATING,PPPPROTSTATE=NOT_INSERVICE,HDLCXSUM=16_BIT,CONFIGRATE=OC192,TRSCT=NO,SDCCTRNSP=NO,LDCCTRNSP=NO,DROPSIDE=NO,KBYTERESIL=NO,OSIENABLE=NO,,OSILAPDMODE=NETWORK,,OSILAPDPST=NULL,OSILAPDSST=NULL,OSRPLAPD=YES,MAXAPBSTS=,LWPCENABLED=YES,,TXCIRCID=,TXCIRCDESC=,RXCIRCID=,RXCIRCDESC=,SIGNALST=LOS,AU4ONLY=NO,LDCCRATE=576,ALS=NO,MAPPING=AU3,PAUSEOFFWM=,PAUSEONWM=,,,OSPFHELLO=,OSPFDEAD=,OSPFMTU=,OSPFCOST="

            if ( $line =~ /"([^,]*),(.*PST=.*)"/ ) {
                my %ocn = ();

                my @pairs = split( ",", $2 );
                foreach my $pair ( @pairs ) {
                    next if ( not $pair );

                    my ( $variable, $value ) = split( "=", $pair );
                    $variable = lc( $variable );

                    $ocn{$variable} = $value;
                }

                $ocn{name} = $1;
                $ocns{$1} = \%ocn;

            }
        }

        $self->{OCNSBYAID}            = \%ocns;
        $self->{OCNSBYAID_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{OCNSBYAID} );
    }

    return ( 0, $self->{OCNSBYAID}->{$facility_name} );
}

=head2 get_eflows($facility_name)

A function to grab the set of EFLOWs on the switch. If a facility name is
specified, it returns a hash containing the properties of that facility. If no
facility name is specified, it returns a hash whose keys are the facility names
and whose values are hashes with the facility properties.

=cut

sub get_eflows {
    my ( $self, $facility_name ) = @_;

    if ( $self->{EFLOWSBYNAME_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %eflows = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-EFLOW::ALL:" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        $self->{LOGGER}->debug( "Got EFLOW Lines\n" );

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

#      "1-A-3-1-9_1-A-3-1:189-190:INGRESSPORTTYPE=ETTP,INGRESSPORTNAME=1-A-3-1-9,PKTTYPE=ALL,PRIORITY=,EGRESSPORTTYPE=VCG,EGRESSPORTNAME=1-A-3-1:189-190,COSMAPPING=COS_PORT_DEFAULT,ENABLEPOLICING=NO,BWPROFILE=,TAGSTOREMOVE=REMOVE_NONE,TAGSTOADD=ADD_NONE,OUTERTAGTYPE=0x0000,OUTERVLANID=0,SECONDTAGTYPE=0x0000,SECONDVLANID=0,INHERITPRIORITY=NO,NEWPRIORITY=0,COLLECTPM=NO,SYSTEMCREATED=YES"
            if ( $line =~ /"(.+?):(([A-Z]+=[^,]*,)+[A-Z]+=[^,]*)"/ ) {
                my %eflow = ();
                my @pairs = split( ",", $2 );
                foreach my $pair ( @pairs ) {
                    next if ( not $pair );

                    my ( $variable, $value ) = split( "=", $pair );

                    $variable = lc( $variable );

                    $eflow{$variable} = $value;
                }

                $eflow{name} = $1;
                $eflows{$1} = \%eflow;
            }
        }

        $self->{EFLOWSBYNAME}            = \%eflows;
        $self->{EFLOWSBYNAME_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{EFLOWSBYNAME} );
    }

    return ( 0, $self->{EFLOWSBYNAME}->{$facility_name} );
}

=head2 get_gtps ($facility_name)

A function to grab the set of group termination points (GTPs) on the switch. If
a facility name is specified, it returns a hash containing the properties of
that facility. If no facility name is specified, it returns a hash whose keys
are the facility names and whose values are hashes with the facility
properties.

=cut

sub get_gtps {
    my ( $self, $facility_name ) = @_;

    if ( $self->{GTPSBYNAME_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %gtps = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-GTP::ALL:" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        $self->{LOGGER}->debug( "Got GTP Lines\n" );

        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

            #    "CHIC_CHIC:1-A-4-1:192_TO_INDI:1-A-5-1:192_002-,LBL=CHIC_CHIC:1-A-4-1:192_TO_INDI:1-A-5-1:192_002-,OWN=,CIRC=CHIC:1-A-4-1:192_TO_INDI:1-A-5-1:192,XCONN=CHIC_CHIC:1-A-4-1:192_TO_INDI:1-A-5-1:192_1,PST=IS-NR,SST=ALM,CTP=CHIC_CHIC:1-A-4-1:192_TO_INDI:1-A-5-1:192_002-1,RATE=1"

            if ( $line =~ /"([^,]*),(.*PST=.*)"/ ) {
                my %gtp = ();

                my @pairs = split( ",", $2 );
                foreach my $pair ( @pairs ) {
                    next if ( not $pair );

                    my ( $variable, $value ) = split( "=", $pair );
                    $variable = lc( $variable );

                    $gtp{$variable} = $value;
                }

                $gtp{name} = $1;
                $gtps{$1} = \%gtp;
            }
        }

        $self->{GTPSBYNAME}            = \%gtps;
        $self->{GTPSBYNAME_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{GTPSBYNAME} );
    }

    return ( 0, $self->{GTPSBYNAME}->{$facility_name} );
}

=head2 get_crossconnects()

A function to grab the cross connects on the switch. If a facility name is
specified, it returns a hash containing the properties of that facility. If no
facility name is specified, it returns a hash whose keys are the facility names
and whose values are hashes with the facility properties.

=cut

sub get_crossconnects {
    my ( $self, $facility_name ) = @_;

    if ( $self->{CRSSBYNAME_CACHE_TIME} + $self->{CACHE_DURATION} < time ) {
        my %crss = ();

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-CRS:::" . $self->{CTAG} . ";" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        $self->{LOGGER}->debug( "Got CRS Lines\n" );

        #     "FROMENDPOINT=JACK_I2:STS-1-1v:JACK:KANS:0001_002-,TOENDPOINT=JACK_I2:STS-1-1v:JACK:KANS:0001_009-:NAME=JACK_I2:STS-1-1v:JACK:KANS:0001_13,FROMTYPE=GTP,TOTYPE=GTP,ALIAS=,SIZE=1,USRC=NO,CKTID=I2:STS-1-1v:JACK:KANS:0001,PRIOR=1023,CONNSTND=SONET,PREEMPTING=NO,PREEMPTABLE=NO::PST=IS-NR,"
        foreach my $line ( @$results ) {
            $self->{LOGGER}->debug( $line . "\n" );

            if ( $line =~ /NAME=([^,]*)/ ) {
                my %crs = ();

                $crs{name} = $1;

                if ( $line =~ /FROMENDPOINT=([^,]*)/ ) {
                    $crs{fromendpoint} = $1;
                }
                if ( $line =~ /FROMTYPE=([^,]*)/ ) {
                    $crs{fromtype} = $1;
                }
                if ( $line =~ /TOENDPOINT=(.*):NAME=/ ) {
                    $crs{toendpoint} = $1;
                }
                if ( $line =~ /TOTYPE=([^,]*)/ ) {
                    $crs{totype} = $1;
                }
                if ( $line =~ /CKTID=([^,]*)/ ) {
                    $crs{cktid} = $1;
                }
                if ( $line =~ /PST=([^,]*)/ ) {
                    $crs{pst} = $1;
                }

                $crss{ $crs{name} } = \%crs;
            }
        }

        $self->{CRSSBYNAME}            = \%crss;
        $self->{CRSSBYNAME_CACHE_TIME} = time;
    }

    if ( not defined $facility_name ) {
        return ( 0, $self->{CRSSBYNAME} );
    }

    return ( 0, $self->{CRSSBYNAME}->{$facility_name} );
}

=head2 get_ctp_pms($facility_name, $pm_type)

A function which returns the current performance counters for the connection
termination points on the switch. If the facility name is specified, it only
returns the performance counters for that facility. If a $pm_type is specified,
it will only return performance counters of that type.

=cut

sub get_ctp_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    my ( $successStatus, $results );
    if ( not $facility_name or $facility_name eq "ALL" ) {
        ( $successStatus, $results ) = $self->send_cmd( "RTRV-PM-STSPC::ALL:" . $self->{CTAG} . ";" );
    }
    else {
        ( $successStatus, $results ) = $self->send_cmd( "RTRV-PM-STSPC::\"$facility_name\":" . $self->{CTAG} . ";" );
    }

    if ( $successStatus != 1 ) {
        return ( -1, $results );
    }

    my %pm_results = ();

    foreach my $line ( @$results ) {

        #    "1-A-2-1-157,STSPC:ESP,0,CMPL,NEND,RCV,15-MIN,01-28,21-45"
        if ( $line =~ /"([^,]*),STSPC:([^,]*),([^,]*),([^,]*),([^,]),([^,]),([^,]*),([^,])*,([^"])*"/ ) {
            my $facility_name  = $1;
            my $monitoredType  = $2;
            my $monitoredValue = $3;
            my $validity       = $4;
            my $location       = $5;
            my $direction      = $6;
            my $timeperiod     = $7;
            my $monitordate    = $8;
            my $monitortime    = $9;

            if ( not defined $pm_results{$facility_name} ) {
                $pm_results{$facility_name} = ();
            }

            my $monitoredPeriodStart = $self->convertPMDateTime( $monitordate, $monitortime );

            my %result = (
                facility         => $facility_name,
                facility_type    => "sts",
                type             => $monitoredType,
                value            => $monitoredValue,
                measurement_type => "bucket",
                measurement_time => time,
                machine_time     => $self->getMachineTime_TS(),

                time_period       => $timeperiod,
                time_period_start => $monitoredPeriodStart,
                date              => $monitordate,
                time              => $monitortime,
                validity          => $validity,
            );
            $pm_results{$facility_name}->{$monitoredType} = \%result;
        }
    }

    if ( $pm_type ) {
        return ( 0, $pm_results{$facility_name}->{$pm_type} );
    }
    elsif ( $facility_name and $facility_name ne "ALL" ) {
        return ( 0, $pm_results{$facility_name} );
    }
    else {
        return ( 0, \%pm_results );
    }
}

=head2 get_ethernet_pms($facility_name, $pm_type)

A function which returns the current performance counters for the ethernet
ports on the switch. If the facility name is specified, it only returns the
performance counters for that facility. If a $pm_type is specified, it will
only return performance counters of that type.

=cut

sub get_ethernet_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    if ( not $facility_name ) {
        $facility_name = "ALL";
    }

    if ( not $self->{COUNTERS}->{eth}->{$facility_name}->{CACHE_TIME}
        or $self->{COUNTERS}->{eth}->{$facility_name}->{CACHE_TIME} + $self->{CACHE_DURATION} < time )
    {

        my ( $successStatus, $results );
        if ( $facility_name eq "ALL" ) {
            ( $successStatus, $results ) = $self->send_cmd( "RTRV-MIB-GIGE::ALL:" . $self->{CTAG} . "::;" );
        }
        else {
            ( $successStatus, $results ) = $self->send_cmd( "RTRV-PM-GIGE::\"$facility_name\":" . $self->{CTAG} . "::;" );
        }

        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        my %pm_results = ();

        foreach my $line ( @$results ) {

            # "1-A-1-1:OVER_SIZE,0,PRTL,15-MIN,08-01,16-00"

            if ( $line =~ /"(.*):([^:,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)"/ ) {
                my $facility_name  = $1;
                my $monitoredType  = $2;
                my $monitoredValue = $3;
                my $validity       = $4;
                my $timeperiod     = $5;
                my $monitordate    = $6;
                my $monitortime    = $7;

                my $monitoredPeriodStart = $self->convertPMDateTime( $monitordate, $monitortime );

                my %result = (
                    facility         => $facility_name,
                    facility_type    => "ethernet",
                    type             => $monitoredType,
                    value            => $monitoredValue,
                    measurement_type => "bucket",
                    measurement_time => time,
                    machine_time     => $self->getMachineTime_TS(),

                    time_period       => $timeperiod,
                    time_period_start => $monitoredPeriodStart,
                    date              => $monitordate,
                    time              => $monitortime,
                    validity          => $validity,
                );
                if ( not defined $pm_results{$facility_name} ) {
                    my %new = ();
                    $pm_results{$facility_name} = \%new;
                }

                $pm_results{$facility_name}->{$monitoredType} = \%result;
            }
        }

        $self->{COUNTERS}->{eth}->{$facility_name}->{CACHE_TIME} = time;
        $self->{COUNTERS}->{eth}->{$facility_name}->{COUNTERS}   = \%pm_results;
    }
    else {
        $self->{LOGGER}->debug( "Returning cached" );
    }

    if ( $pm_type ) {
        return ( 0, $self->{COUNTERS}->{eth}->{$facility_name}->{COUNTERS}->{$facility_name}->{$pm_type} );
    }
    elsif ( $facility_name ne "ALL" ) {
        return ( 0, $self->{COUNTERS}->{eth}->{$facility_name}->{COUNTERS}->{$facility_name} );
    }
    else {
        return ( 0, $self->{COUNTERS}->{eth}->{$facility_name}->{COUNTERS} );
    }
}

=head2 
=cut

sub get_ethernet_mib_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    return ( -1, "Must specify facility" ) unless ( $facility_name );

    my ( $successStatus, $results ) = $self->send_cmd( "RTRV-MIB-GIGE::\"$facility_name\":" . $self->{CTAG} . "::;" );

    if ( $successStatus != 1 ) {
        return ( -1, $results );
    }

    my %pm_results = ();

    foreach my $line ( @$results ) {

        # "1-A-1-1:OVER_SIZE,0,PRTL,15-MIN,08-01,16-00"
        #    "dcs_vcg_47089:INTF_IN_OCTETS,56380056942"
        #    "1-A-7-1-1:INTF_OUT_OCTETS,177104521147"

        if ( $line =~ /"(.*):([^:,]*),([^,]*)"/ ) {
            my $facility_name  = $1;
            my $monitoredType  = $2;
            my $monitoredValue = $3;

            my %result = (
                facility         => $facility_name,
                facility_type    => "ethernet",
                type             => $monitoredType,
                value            => $monitoredValue,
                measurement_type => "counter",
                measurement_time => time,
                machine_time     => $self->getMachineTime_TS(),
            );
            if ( not defined $pm_results{$facility_name} ) {
                my %new = ();
                $pm_results{$facility_name} = \%new;
            }

            $pm_results{$facility_name}->{$monitoredType} = \%result;
        }
    }

    if ( $pm_type ) {
        return ( 0, $pm_results{$facility_name}->{$pm_type} );
    }
    else {
        return ( 0, $pm_results{$facility_name} );
    }
}

=head2 
=cut

sub get_vcg_mib_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    return ( -1, "Must specify facility" ) unless ( $facility_name );

    my ( $successStatus, $results ) = $self->send_cmd( "RTRV-MIB-VCG::\"$facility_name\":" . $self->{CTAG} . "::;" );

    if ( $successStatus != 1 ) {
        return ( -1, $results );
    }

    my %pm_results = ();

    foreach my $line ( @$results ) {

        # "1-A-1-1:OVER_SIZE,0,PRTL,15-MIN,08-01,16-00"
        #    "dcs_vcg_47089:INTF_IN_OCTETS,56380056942"
        #    "1-A-7-1-1:INTF_OUT_OCTETS,177104521147"

        if ( $line =~ /"(.*):([^:,]*),([^"]*)"/ ) {
            my $facility_name  = $1;
            my $monitoredType  = $2;
            my $monitoredValue = $3;

            my %result = (
                facility         => $facility_name,
                facility_type    => "vcg",
                type             => $monitoredType,
                value            => $monitoredValue,
                measurement_type => "counter",
                measurement_time => time,
                machine_time     => $self->getMachineTime_TS(),
            );
            if ( not defined $pm_results{$facility_name} ) {
                my %new = ();
                $pm_results{$facility_name} = \%new;
            }

            $pm_results{$facility_name}->{$monitoredType} = \%result;
        }
    }

    if ( $pm_type ) {
        return ( 0, $pm_results{$facility_name}->{$pm_type} );
    }
    else {
        return ( 0, $pm_results{$facility_name} );
    }
}

=head2 
=cut

sub get_eflow_mib_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    return ( -1, "Must specify facility" ) unless ( $facility_name );

    my ( $successStatus, $results ) = $self->send_cmd( "RTRV-MIB-EFLOW::\"$facility_name\":" . $self->{CTAG} . "::;" );

    if ( $successStatus != 1 ) {
        return ( -1, $results );
    }

    my %pm_results = ();

    foreach my $line ( @$results ) {

        # "1-A-1-1:OVER_SIZE,0,PRTL,15-MIN,08-01,16-00"
        #    "dcs_vcg_47089:INTF_IN_OCTETS,56380056942"
        #    "1-A-7-1-1:INTF_OUT_OCTETS,177104521147"

        if ( $line =~ /"(.*):([^:,]*),([^"]*)"/ ) {
            my $facility_name  = $1;
            my $monitoredType  = $2;
            my $monitoredValue = $3;

            my %result = (
                facility         => $facility_name,
                facility_type    => "eflow",
                type             => $monitoredType,
                value            => $monitoredValue,
                measurement_type => "counter",
                measurement_time => time,
                machine_time     => $self->getMachineTime_TS(),
            );
            if ( not defined $pm_results{$facility_name} ) {
                my %new = ();
                $pm_results{$facility_name} = \%new;
            }

            $pm_results{$facility_name}->{$monitoredType} = \%result;
        }
    }

    if ( $pm_type ) {
        return ( 0, $pm_results{$facility_name}->{$pm_type} );
    }
    else {
        return ( 0, $pm_results{$facility_name} );
    }
}

=head2 get_eflow_pms($facility_name, $pm_type)

A function which returns the current performance counters for the EFLOWS on the
switch. If the facility name is specified, it only returns the performance
counters for that facility. If a $pm_type is specified, it will only return
performance counters of that type.

=cut

sub get_eflow_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    if ( not $facility_name ) {
        $facility_name = "ALL";
    }

    if ( not $self->{COUNTERS}->{eflow}->{$facility_name}->{CACHE_TIME}
        or $self->{COUNTERS}->{eflow}->{$facility_name}->{CACHE_TIME} + $self->{CACHE_DURATION} < time )
    {

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-PM-EFLOW::\"$facility_name\":" . $self->{CTAG} . "::;" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        my %pm_results = ();

        foreach my $line ( @$results ) {

            # "dcs_eflow_dcs_vcg_39610_in:OUT_GREEN,7,CMPL,15-MIN,09-11,19-00"

            if ( $line =~ /"(.*):([^:,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)"/ ) {
                my $facility_name  = $1;
                my $monitoredType  = $2;
                my $monitoredValue = $3;
                my $validity       = $4;
                my $timeperiod     = $5;
                my $monitordate    = $6;
                my $monitortime    = $7;

                my $monitoredPeriodStart = $self->convertPMDateTime( $monitordate, $monitortime );

                my %result = (
                    facility         => $facility_name,
                    facility_type    => "eflow",
                    type             => $monitoredType,
                    value            => $monitoredValue,
                    measurement_type => "bucket",
                    measurement_time => time,
                    machine_time     => $self->getMachineTime_TS(),

                    time_period       => $timeperiod,
                    time_period_start => $monitoredPeriodStart,
                    date              => $monitordate,
                    time              => $monitortime,
                    validity          => $validity,
                );

                if ( not defined $pm_results{$facility_name} ) {
                    my %new = ();
                    $pm_results{$facility_name} = \%new;
                }

                $pm_results{$facility_name}->{$monitoredType} = \%result;
            }
        }

        $self->{COUNTERS}->{eflow}->{$facility_name}->{CACHE_TIME} = time;
        $self->{COUNTERS}->{eflow}->{$facility_name}->{COUNTERS}   = \%pm_results;
    }
    else {
        $self->{LOGGER}->debug( "Returning cached" );
    }

    if ( $pm_type ) {
        return ( 0, $self->{COUNTERS}->{eflow}->{$facility_name}->{COUNTERS}->{$facility_name}->{$pm_type} );
    }
    elsif ( $facility_name ne "ALL" ) {
        return ( 0, $self->{COUNTERS}->{eflow}->{$facility_name}->{COUNTERS}->{$facility_name} );
    }
    else {
        return ( 0, $self->{COUNTERS}->{eflow}->{$facility_name}->{COUNTERS} );
    }
}

=head2 get_vcg_pms($facility_name, $pm_type)

A function which returns the current performance counters for the virtual
concatenation groups on the switch. If the facility name is specified, it only
returns the performance counters for that facility. If a $pm_type is specified,
it will only return performance counters of that type.

=cut

sub get_vcg_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    if ( not $facility_name ) {
        $facility_name = "ALL";
    }

    $self->{LOGGER}->debug( "VCG: '$facility_name'\n" );

    if ( not $self->{COUNTERS}->{vcg}->{$facility_name}->{CACHE_TIME}
        or $self->{COUNTERS}->{vcg}->{$facility_name}->{CACHE_TIME} + $self->{CACHE_DURATION} < time )
    {

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-PM-VCG::\"$facility_name\":" . $self->{CTAG} . "::;" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        my %pm_results = ();

        foreach my $line ( @$results ) {

            #    "1-A-4-1:1-96:IN_PACKETS,0,CMPL,15-MIN,09-11,19-00"
            $self->{LOGGER}->debug( "Checking $line" );
            if ( $line =~ /"$facility_name:([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^"]*)"/ ) {
                $self->{LOGGER}->debug( "PM found" );
                my $monitoredType  = $1;
                my $monitoredValue = $2;
                my $validity       = $3;
                my $timeperiod     = $4;
                my $monitordate    = $5;
                my $monitortime    = $6;

                my $monitoredPeriodStart = $self->convertPMDateTime( $monitordate, $monitortime );

                my %result = (
                    facility         => $facility_name,
                    facility_type    => "vcg",
                    type             => $monitoredType,
                    value            => $monitoredValue,
                    measurement_type => "bucket",
                    measurement_time => time,
                    machine_time     => $self->getMachineTime_TS(),

                    time_period       => $timeperiod,
                    time_period_start => $monitoredPeriodStart,
                    date              => $monitordate,
                    time              => $monitortime,
                    validity          => $validity,
                );

                if ( not defined $pm_results{$facility_name} ) {
                    my %new = ();
                    $pm_results{$facility_name} = \%new;
                }

                $pm_results{$facility_name}->{$monitoredType} = \%result;

                $self->{LOGGER}->debug( "PM found" );
            }
        }

        $self->{COUNTERS}->{vcg}->{$facility_name}->{CACHE_TIME} = time;
        $self->{COUNTERS}->{vcg}->{$facility_name}->{COUNTERS}   = \%pm_results;
    }
    else {
        $self->{LOGGER}->debug( "Returning cached" );
    }

    if ( $pm_type ) {
        return ( 0, $self->{COUNTERS}->{vcg}->{$facility_name}->{COUNTERS}->{$facility_name}->{$pm_type} );
    }
    elsif ( $facility_name ne "ALL" ) {
        return ( 0, $self->{COUNTERS}->{vcg}->{$facility_name}->{COUNTERS}->{$facility_name} );
    }
    else {
        return ( 0, $self->{COUNTERS}->{vcg}->{$facility_name}->{COUNTERS} );
    }
}

=head2 get_optical_pms($facility_name, $pm_type)

A function which returns the current performance counters for the optical ports
on the switch. If the facility name is specified, it only returns the
performance counters for that facility. If a $pm_type is specified, it will
only return performance counters of that type.

=cut

sub get_optical_pms {
    my ( $self, $facility_name, $pm_type ) = @_;

    if ( not $facility_name ) {
        $facility_name = "ALL";
    }

    if ( not $self->{COUNTERS}->{ocn}->{$facility_name}->{CACHE_TIME}
        or $self->{COUNTERS}->{ocn}->{$facility_name}->{CACHE_TIME} + $self->{CACHE_DURATION} < time )
    {

        my ( $successStatus, $results ) = $self->send_cmd( "RTRV-PM-OCN::$facility_name:" . $self->{CTAG} . "::;" );
        if ( $successStatus != 1 ) {
            return ( -1, $results );
        }

        my %pm_results = ();

        foreach my $line ( @$results ) {

            #   "1-A-3-1,OC192:OPR,0,PRTL,NEND,RCV,15-MIN,05-30,01-00,LOW,LOW,LOW,LOW,0"
            if ( $line =~ /"([^,]*),OC([0-9]+):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)"/ ) {
                my $facility_name      = $1;
                my $facility_name_type = $2;
                my $monitoredType      = $3;
                my $monitoredValue     = $4;
                my $validity           = $5;
                my $location           = $6;
                my $direction          = $7;
                my $timeperiod         = $8;
                my $monitordate        = $9;
                my $monitortime        = $10;
                my $actual             = $11;
                my $low                = $12;
                my $high               = $13;
                my $average            = $14;
                my $normalized         = $15;

                my $monitoredPeriodStart = $self->convertPMDateTime( $monitordate, $monitortime );

                my %result = (
                    facility         => $facility_name,
                    facility_type    => "optical",
                    type             => $monitoredType,
                    value            => $monitoredValue,
                    measurement_type => "bucket",
                    measurement_time => time,
                    machine_time     => $self->getMachineTime_TS(),

                    time_period       => $timeperiod,
                    time_period_start => $monitoredPeriodStart,
                    date              => $monitordate,
                    time              => $monitortime,
                    validity          => $validity,
                    actual            => $actual,
                    low               => $low,
                    high              => $high,
                    average           => $average,
                    normalized        => $normalized,
                );

                if ( not defined $pm_results{$facility_name} ) {
                    my %new = ();
                    $pm_results{$facility_name} = \%new;
                }

                $pm_results{$facility_name}->{$monitoredType} = \%result;
            }
        }

        $self->{COUNTERS}->{ocn}->{$facility_name}->{CACHE_TIME} = time;
        $self->{COUNTERS}->{ocn}->{$facility_name}->{COUNTERS}   = \%pm_results;
    }
    else {
        $self->{LOGGER}->debug( "Returning cached" );
    }

    if ( $pm_type ) {
        return ( 0, $self->{COUNTERS}->{ocn}->{$facility_name}->{COUNTERS}->{$facility_name}->{$pm_type} );
    }
    elsif ( $facility_name ne "ALL" ) {
        return ( 0, $self->{COUNTERS}->{ocn}->{$facility_name}->{COUNTERS}->{$facility_name} );
    }
    else {
        return ( 0, $self->{COUNTERS}->{ocn}->{$facility_name}->{COUNTERS} );
    }
}

# - RTRV-OSRP-LTP::NEWY:1234::;
#    "NEWY,2:ALIAS=,RMTNM=,RMTLID=0,RMTALIAS=,LOCAL=LOCAL,ADMW=5040,DELAY=1,PBID=0,OSRPCTPS=1-A-1-2,HSTATE=ATTEMPT,OOBENABLED=NO,OOBREMOTENODEID=10,OOBREMOTEADDR=255.255.255.255,OOBREMOTEPORT=51001"
#    "NEWY,9:ALIAS=,RMTNM=PHIL,RMTLID=9,RMTALIAS=,LOCAL=LOCAL,ADMW=5040,DELAY=1,PBID=0,OSRPCTPS=1-A-2-1,HSTATE=2WAYINSIDE,OOBENABLED=NO,OOBREMOTENODEID=10,OOBREMOTEADDR=255.255.255.255,OOBREMOTEPORT=51001"
#    "NEWY,129:ALIAS=,RMTNM=BOST,RMTLID=129,RMTALIAS=,LOCAL=LOCAL,ADMW=5040,DELAY=1,PBID=0,OSRPCTPS=1-A-1-1,HSTATE=2WAYINSIDE,OOBENABLED=NO,OOBREMOTENODEID=1,OOBREMOTEADDR=0.0.0.0,OOBREMOTEPORT=51001"
#      ;
#
#      or
# - RTRV-OSRP-LTP::CHIC:1234::; (from NEWY)
#   "CHIC,1:ALIAS=,RMTNM=CLEV,RMTLID=9,RMTALIAS=,LOCAL=REMOTE,ADMW=5040,DELAY=1,PBID=0,OSRPCTPS=,HSTATE=NOTAPPL,,"
#   "CHIC,2:ALIAS=,RMTNM=INDI,RMTLID=1,RMTALIAS=,LOCAL=REMOTE,ADMW=5040,DELAY=1,PBID=0,OSRPCTPS=,HSTATE=NOTAPPL,,"
#   "CHIC,9:ALIAS=,RMTNM=KANS,RMTLID=1,RMTALIAS=,LOCAL=REMOTE,ADMW=5040,DELAY=1,PBID=0,OSRPCTPS=,HSTATE=NOTAPPL,,"

sub rtrv_osrp_ltp {
    my ( $self, $node_name ) = @_;

    unless ( $node_name ) {
        $node_name = $self->getMachineName();
    }

    unless ( $node_name ) {
        return ( -1, "No node name specified, and current machine name is unknown" );
    }

    my ( $successStatus, $results ) = $self->send_cmd( " RTRV-OSRP-LTP::" . $node_name . ":" . $self->{CTAG} . "::;" );
    if ( $successStatus != 1 ) {
        return ( -1, $results );
    }

    my @retval = ();

    foreach my $line ( @$results ) {

        if ( $line =~ /"([^,]*),([0-9]+):(.*)"/ ) {
            my %port_info = ();

            $port_info{node} = $1;
            $port_info{port} = $2;

            my @pairs = split( ",", $3 );
            foreach my $pair ( @pairs ) {
                my ( $key, $value ) = split( "=", $pair );
                $port_info{ lc( $key ) } = $value;
            }

            push @retval, \%port_info;
        }
    }

    return ( 0, \@retval );
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

        #   "TimingInput_BITS_2,REF:MN,SYNCCLK,NSA,2008-08-28,15:12:03,,:\"LOS on synchronization reference as seen by TM1\","
        #   "TimingInput_BITS_2,REF:MN,SYNCCLK,NSA,2008-08-28,15:12:11,,:\"LOS on synchronization reference as seen by TM2\","

        foreach my $line ( @$results ) {
            if ( $line =~ /"([^,]*),([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):(\\".*\\"),(.*)"/ ) {
                my $facility         = $1;
                my $facility_type    = $2;
                my $severity         = $3;
                my $alarmType        = $4;
                my $serviceAffecting = $5;
                my $date             = $6;
                my $time             = $7;
                my $unknown1         = $8;
                my $unknown2         = $9;
                my $description      = $10;
                my $unknown3         = $11;

                $description =~ s/\\"//g;

                my $timestamp = $self->convertTimeStringToTimestamp( $date . " " . $time );

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

        # "EMSUser:LOGBUFR90,TC,01-28,23-00-23,,,,,:\"The Audit Log Buffer has reached 90 percent full\""
        if ( $line =~ /"([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):(\\".*\\")/ ) {
            my $facility    = $1;
            my $condtype    = $2;
            my $effect      = $3;
            my $date        = $4;
            my $time        = $5;
            my $unknown1    = $6;
            my $unknown2    = $7;
            my $unknown3    = $8;
            my $unknown4    = $9;
            my $unknown5    = $10;
            my $description = $11;

            $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );
            $description =~ s/\\"//g;
            $self->{LOGGER}->debug( "DESCRIPTION: '$description'\n" );

            my %event = (
                facility         => $facility,
                eventType        => $condtype,
                effect           => $effect,
                event_time       => $self->convertPMDateTime( $date, $time ),
                measurement_time => time,
                date             => $date,
                time             => $time,

                #                location => $location,
                #                direction => $direction,
                #                value => $monitoredValue,
                #                threshold => $thresholdLevel,
                #                period => $timePeriod,
                description => $description,
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
    if ( $args->{timeout} ) {
        ( $status, $lines ) = $self->waitMessage( { type => "alarm", timeout => $args->{timeout} } );
    }
    else {
        ( $status, $lines ) = $self->waitMessage( { type => "alarm" } );
    }

    if ( $status != 0 or not defined $lines ) {
        return ( $status, undef );
    }

    foreach my $line ( @$lines ) {
        if ( $line =~ /"([^,]*),([^:]*):([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^:]*):(\\".*\\"),(.*)"/ ) {
            my $facility         = $1;
            my $facility_type    = $2;
            my $severity         = $3;
            my $alarmType        = $4;
            my $serviceAffecting = $5;
            my $date             = $6;
            my $time             = $7;
            my $unknown1         = $8;
            my $unknown2         = $9;
            my $description      = $10;
            my $unknown3         = $11;

            $description =~ s/\\"//g;

            my $timestamp = $self->convertTimeStringToTimestamp( $date . " " . $time );

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
            );

            return ( 0, \%alarm );
        }
    }

    return ( -1, undef );
}

=head2 logout()

A function to enable proper logouts from the CoreDirector, the session should
get cancelled so the base function is overriden to make sure this happens.

=cut

sub logout {
    my ( $self ) = @_;

    $self->send_cmd( "CANC-USER::" . $self->{USERNAME} . ":" . $self->{CTAG} . ";" );

    return;
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

$Id: CoreDirector.pm 3663 2009-09-01 16:22:46Z aaron $

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
