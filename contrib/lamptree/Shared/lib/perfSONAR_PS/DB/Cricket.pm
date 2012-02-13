package perfSONAR_PS::DB::Cricket;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'LOGGER', 'FILE', 'STORE', 'RRDTOOL', 'CRICKET_HOME', 'CRICKET_INSTALL', 'CRICKET_DATA', 'CRICKET_CONFIG', 'CRICKET_HINTS';

=head1 NAME

perfSONAR_PS::DB::Cricket

=head1 DESCRIPTION

Module used to interact with the cricket network monitoring system.  This
module acts as a conduit between the format installed via cricket, and the
required perfSONAR specification.  The overall flow is to find the cricket
environment, read the necessary configuration files, and finally generate a
store file that may be used by the SNMP MA.

=cut

use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use English qw( -no_match_vars );

use perfSONAR_PS::Utils::ParameterValidation;

=head2 new($package, { file })

Create a new object.  

=cut

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams( @args, { conf => 0, file => 0, home => 1, install => 1, data => 1, config => 1, hints => 0 } );

    my $self = fields::new( $package );
    $self->{STORE}   = q{};
    $self->{RRDTOOL} = "/usr/bin/rrdtool";
    $self->{LOGGER}  = get_logger( "perfSONAR_PS::DB::Cricket" );
    if ( exists $parameters->{file} and $parameters->{file} ) {
        $self->{FILE} = $parameters->{file};
    }

    $self->{CRICKET_HOME}    = $parameters->{home};
    $self->{CRICKET_INSTALL} = $parameters->{install};
    $self->{CRICKET_DATA}    = $parameters->{data};
    $self->{CRICKET_CONFIG}  = $parameters->{config};
    if ( exists $parameters->{hints} and $parameters->{hints} ) {
        open( HINTS, $parameters->{hints} );
        my @hints = <HINTS>;
        close( HINTS );
        $self->{CRICKET_HINTS} = ();
        foreach my $h ( @hints ) {
            my @line = split( /:/, $h );
            my $counter = -1;
            foreach my $l ( @line ) {
                $counter++;
                next if $counter < 2;
                $l =~ s/(\n|\s)+//;
                push @{ $self->{CRICKET_HINTS}{ $line[0] }{ $line[1] } }, $l;
            }
        }
    }

    # Fake a 'use lib' (N.B. that use lib is evaluated at compile time, we
    #  don't want that here since this is based on a configuration option
    unshift @INC, $self->{CRICKET_INSTALL} . "/lib";

    # Try To use the cricket-conf script, note that its related to the specified
    #  directories
    my $res = eval "require '$self->{CRICKET_INSTALL}/cricket-conf.pl'";
    if ( $EVAL_ERROR or ( not $res ) ) {
        $self->{LOGGER}->error( "Couldn't load cricket lib '$self->{CRICKET_INSTALL}/cricket-conf.pl': $EVAL_ERROR" );
        return -1;
    }

    if ( !$Common::global::gInstallRoot && -l $PROGRAM_NAME ) {
        $res = eval {
            my $link = readlink( $PROGRAM_NAME );
            my $dir = ( ( $link =~ m:^(.*/): )[0] || "./" ) . ".";
            require "$dir/cricket-conf.pl";
        };
        if ( $EVAL_ERROR or ( not $res ) ) {
            $self->{LOGGER}->error( "Couldn't load cricket lib '/home/cricket/cricket/cricket-conf.pl': $EVAL_ERROR" );
            return -1;
        }
    }

    unless ( $Common::global::gInstallRoot ) {
        $res = eval "require '/home/cricket/cricket/cricket-conf.pl'";
        if ( $EVAL_ERROR or ( not $res ) ) {
            $self->{LOGGER}->error( "Couldn't load cricket lib '/home/cricket/cricket/cricket-conf.pl': $EVAL_ERROR" );
            return -1;
        }
    }

    # Finally set some other values, note that avoiding 'use' is really a pain
    #  in this case
    $Common::global::gInstallRoot ||= $self->{CRICKET_INSTALL};
    $Common::global::gConfigRoot = q{};
    $Common::global::gConfigRoot ||= $self->{CRICKET_CONFIG};
    require ConfigTree::Cache;

    return $self;
}

=head2 setFile($self, { file })

set the output store file.

=cut

sub setFile {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { file => 1 } );

    if ( $parameters->{file} =~ m/\.xml$/mx ) {
        $self->{FILE} = $parameters->{file};
        return 0;
    }
    else {
        $self->{LOGGER}->error( "Cannot set filename." );
        return -1;
    }
}

=head2 openDB($self, {  })

Open the connection to the cacti databases, iterate through making the store.xml
file.

=cut

sub openDB {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    $Common::global::gCT = new ConfigTree::Cache;
    my $gCT = $Common::global::gCT;
    $gCT->Base( $Common::global::gConfigRoot );

    unless ( $gCT->init() ) {
        $self->{LOGGER}->error( "Failed to open compiled config tree from $Common::global::gConfigRoot/config.db: $!" );
    }

    my $gError = q{};
    my ( $recomp, $why ) = $gCT->needsRecompile();
    if ( $recomp ) {
        $gError .= "Config tree needs to be recompiled: $why";
    }

    my $dataDir = $self->{CRICKET_DATA};

    my %master = ();
    foreach my $branch ( keys %{$gCT} ) {
        if ( $branch eq "DbRef" ) {
            foreach my $entry ( keys %{ $gCT->{$branch} } ) {
                if ( $entry =~ m/^d:/mx and not( $entry =~ m/chassis/mx ) and not( $entry =~ m/device-traffic/mx ) ) {
                    my @line = split( /:/, $entry );
                    if ( -f $dataDir . $line[1] . ".rrd" ) {
                        $master{ $dataDir . $line[1] }->{ $line[4] } = $gCT->{$branch}->{$entry};
                    }
                }
            }
        }
    }

    my $rrd = new perfSONAR_PS::DB::RRD( { path => $self->{"RRDTOOL"}, error => 1 } );
    $rrd->openDB;

    $self->{STORE} .= $self->printHeader();
    my $counter = 0;
    foreach my $item ( keys %master ) {

        my @temp = split( /\//, $item );
        my @address = ();
        push @address, $temp[ $#temp - 1 ];
        push @address, $temp[$#temp];

        if ( not( $temp[ $#temp - 1 ] =~ m/.*\.\w+\.\w+$/ ) ) {
            @address = ();
            push @address, $temp[$#temp];
            push @address, $temp[$#temp];
            if ( not( $temp[$#temp] =~ m/.*\.\w+\.\w+$/ ) ) {
                next;
            }
        }

        # XXX jz 1/23/09 - Should use an html cleanser
        my $okChar = '-a-zA-Z0-9_.@\s';
        my $des    = q{};
        my $des2   = q{};

        if ( exists $master{$item}->{"long-desc"} and $master{$item}->{"long-desc"} ) {
            ( $des = $master{$item}->{"long-desc"} ) =~ s/<BR>/ /g;
            $des =~ s/&/&amp;/g;
            $des =~ s/</&lt;/g;
            $des =~ s/>/&gt;/g;
            $des =~ s/'/&apos;/g;
            $des =~ s/"/&quot;/g;
            $des =~ s/[^$okChar]/ /go;
        }

        if ( exists $master{$item}->{"short-desc"} and $master{$item}->{"short-desc"} ) {
            ( $des2 = $master{$item}->{"short-desc"} ) =~ s/<BR>/ /g;
            $des2 =~ s/&/&amp;/g;
            $des2 =~ s/</&lt;/g;
            $des2 =~ s/>/&gt;/g;
            $des2 =~ s/'/&apos;/g;
            $des2 =~ s/"/&quot;/g;
            $des2 =~ s/[^$okChar]/ /go;
        }

        if ( exists $self->{CRICKET_HINTS} and exists $self->{CRICKET_HINTS}{ $temp[ $#temp - 1 ] }{"ds"} ) {
            my $dsc = 0;
            foreach my $ds ( @{ $self->{CRICKET_HINTS}{ $temp[ $#temp - 1 ] }{"ds"} } ) {
                $master{$item}->{"interface-name"} = $ds . "_" . $dsc;
                $self->{STORE} .= $self->printInterface(
                    {
                        ipAddress => $master{$item}->{"ip"},
                        rrddb     => $rrd,
                        id        => $counter . "-" . $dsc,
                        hostName  => $address[0],
                        ifName    => $master{$item}->{"interface-name"},
                        capacity  => $master{$item}->{"rrd-max"},
                        des       => $des . " - " . $ds,
                        des2      => $des2 . " - " . $ds,
                        file      => $item,
                        ds        => "ds" . $dsc,
                        direction => $ds
                    }
                );
                $dsc++;
            }
        }
        else {
            $self->{STORE} .= $self->printInterface(
                { ipAddress => $master{$item}->{"ip"}, rrddb => $rrd, id => $counter, hostName => $address[0], ifName => $master{$item}->{"interface-name"}, direction => "in", capacity => $master{$item}->{"rrd-max"}, des => $des, des2 => $des2, file => $item, ds => "ds0" } );
            $self->{STORE} .= $self->printInterface(
                { ipAddress => $master{$item}->{"ip"}, rrddb => $rrd, id => $counter, hostName => $address[0], ifName => $master{$item}->{"interface-name"}, direction => "out", capacity => $master{$item}->{"rrd-max"}, des => $des, des2 => $des2, file => $item, ds => "ds1" } );
        }
        $counter++;

    }
    $self->{STORE} .= $self->printFooter();
    $rrd->closeDB;

    return 0;
}

=head2 printHeader($self, { })

Print out the store header

=cut

sub printHeader {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    my $output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    $output .= "<nmwg:store  xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
    $output .= "             xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\"\n";
    $output .= "             xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"\n";
    $output .= "             xmlns:snmp=\"http://ggf.org/ns/nmwg/tools/snmp/2.0/\">\n\n";
    return $output;
}

=head2 printInterface($self, { })

Print out the interface direction

=cut

sub printInterface {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { rrddb => 0, id => 1, hostName => 1, ifName => 1, ipAddress => 0, direction => 0, capacity => 1, des => 0, des2 => 0, file => 1, ds => 1 } );

    my $output = "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata-" . $parameters->{direction} . "-" . $parameters->{id} . "\">\n";
    $output .= "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"subject-" . $parameters->{direction} . "-" . $parameters->{id} . "\">\n";
    $output .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
    $output .= "        <nmwgt:ipAddress>" . $parameters->{ipAddress} . "</nmwgt:ipAddress>\n" if $parameters->{ipAddress};
    $output .= "        <nmwgt:hostName>" . $parameters->{hostName} . "</nmwgt:hostName>\n" if $parameters->{hostName};
    $output .= "        <nmwgt:ifName>" . $parameters->{ifName} . "</nmwgt:ifName>\n" if $parameters->{ifName};
    $output .= "        <nmwgt:ifIndex>" . $parameters->{ifName} . "</nmwgt:ifIndex>\n" if $parameters->{ifIndex};
    $output .= "        <nmwgt:direction>" . $parameters->{direction} . "</nmwgt:direction>\n" if $parameters->{direction};
    if ( $parameters->{capacity} ) {

        if ( $parameters->{capacity} eq "4294967295" ) {
            $output .= "        <nmwgt:capacity>10000000000</nmwgt:capacity>\n";
        }
        else {
            $output .= "        <nmwgt:capacity>" . $parameters->{capacity} . "</nmwgt:capacity>\n";
        }
    }

    if ( $parameters->{des} and ( not $parameters->{des} =~ m/short-desc/ ) and ( not $parameters->{des} =~ m/long-desc/ ) ) {
        $output .= "        <nmwgt:description>" . $parameters->{des} . "</nmwgt:description>\n";
        if ( $parameters->{des2} and ( not $parameters->{des2} =~ m/short-desc/ ) and ( not $parameters->{des2} =~ m/long-desc/ ) ) {
            $output .= "        <nmwgt:ifDescription>" . $parameters->{des2} . "</nmwgt:ifDescription>\n";
        }
        else {
            $output .= "        <nmwgt:ifDescription>" . $parameters->{des} . "</nmwgt:ifDescription>\n";
        }
    }
    elsif ( $parameters->{des2} and ( not $parameters->{des2} =~ m/short-desc/ ) and ( not $parameters->{des2} =~ m/long-desc/ ) ) {
        $output .= "        <nmwgt:description>" . $parameters->{des2} . "</nmwgt:description>\n";
        $output .= "        <nmwgt:ifDescription>" . $parameters->{des2} . "</nmwgt:ifDescription>\n";
    }

    $output .= "      </nmwgt:interface>\n";
    $output .= "    </netutil:subject>\n";
    $output .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>\n";
    $output .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
    $output .= "    <nmwg:parameters id=\"parameters-" . $parameters->{direction} . "-" . $parameters->{id} . "\">\n";
    $output .= "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
    $output .= "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
    $output .= "    </nmwg:parameters>\n";
    $output .= "  </nmwg:metadata>\n\n";

    $output .= "  <nmwg:data xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"data-" . $parameters->{direction} . "-" . $parameters->{id} . "\" metadataIdRef=\"metadata-" . $parameters->{direction} . "-" . $parameters->{id} . "\">\n";
    $output .= "    <nmwg:key id=\"key-" . $parameters->{direction} . "-" . $parameters->{id} . "\">\n";
    $output .= "      <nmwg:parameters id=\"pkey-" . $parameters->{direction} . "-" . $parameters->{id} . "\">\n";
    $output .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"type\">rrd</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"file\">" . $parameters->{file} . ".rrd</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"valueUnits\">Bps</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"dataSource\">" . $parameters->{ds} . "</nmwg:parameter>\n";

    if ( exists $parameters->{rrddb} ) {
        $parameters->{rrddb}->setFile( { file => $parameters->{file} . ".rrd" } );
        my $first      = $parameters->{rrddb}->firstValue();
        my $rrd_result = $parameters->{rrddb}->info();
        unless ( $parameters->{rrddb}->getErrorMessage ) {
            my %lookup = ();
            foreach my $rra ( sort keys %{ $rrd_result->{"rra"} } ) {
                push @{ $lookup{ $rrd_result->{"rra"}->{$rra}->{"cf"} } }, ( $rrd_result->{"rra"}->{$rra}->{"pdp_per_row"} * $rrd_result->{"step"} );
            }

            foreach my $cf ( keys %lookup ) {
                $output .= "        <nmwg:parameter name=\"consolidationFunction\" value=\"" . $cf . "\">\n";
                foreach my $res ( @{ $lookup{$cf} } ) {
                    $output .= "          <nmwg:parameter name=\"resolution\">" . $res . "</nmwg:parameter>\n";
                }
                $output .= "        </nmwg:parameter>\n";
            }
        }
        $output .= "        <nmwg:parameter name=\"lastTime\">" . $rrd_result->{"last_update"} . "</nmwg:parameter>\n" if $rrd_result->{"last_update"};
        $output .= "        <nmwg:parameter name=\"firstTime\">" . $first . "</nmwg:parameter>\n" if $first;
    }
    $output .= "      </nmwg:parameters>\n";
    $output .= "    </nmwg:key>\n";
    $output .= "  </nmwg:data>\n\n";

    return $output;
}

=head2 printFooter($self, { })

Print the closing of the store.xml file.

=cut

sub printFooter {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );
    return "</nmwg:store>\n";
}

=head2 commitDB($self, { })

If the output file has been set, and there is content in the cricket xml storage,
write this to the output file.

=cut

sub commitDB {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    unless ( $self->{FILE} ) {
        $self->{LOGGER}->error( "Output file not set, aborting." );
        return -1;
    }
    if ( $self->{STORE} ) {
        open( OUTPUT, ">" . $self->{FILE} );
        print OUTPUT $self->{STORE};
        close( OUTPUT );
        return 0;
    }
    $self->{LOGGER}->error( "Cricket xml content is empty, did you call \"openDB\"?" );
    return -1;
}

=head2 closeDB($self, { })

'Closes' the store.xml database that is created from the cricket data by
commiting the changes.

=cut

sub closeDB {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );
    $self->commitDB();
    return;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<Params::Validate>, L<English>,
L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Cricket.pm 4018 2010-04-07 17:35:12Z aaron $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut
