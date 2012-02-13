package perfSONAR_PS::DB::Cacti;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'LOGGER', 'CONF', 'FILE', 'VERSIONS', 'STORE', 'RRDTOOL';

=head1 NAME

perfSONAR_PS::DB::Cacti

=head1 DESCRIPTION

Database wrapper around the Cacti network measurement tool.

=cut

use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use Config::General qw(ParseConfig);
use DBI;
use Socket;

use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::DB::RRD;

=head2 new($package, { conf, file })

Create a new object.  Has options to set the conf/file options and sets the
known working cacti versions.

=cut

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams( @args, { conf => 0, file => 0 } );

    my $self = fields::new( $package );
    $self->{RRDTOOL} = "/usr/bin/rrdtool";
    $self->{LOGGER}  = get_logger( "perfSONAR_PS::DB::Cacti" );
    @{ $self->{VERSIONS} } = ( "0.8.6i", "0.8.6j" );
    if ( exists $parameters->{conf} and $parameters->{conf} ) {
        $self->{CONF} = $parameters->{conf};
    }
    if ( exists $parameters->{file} and $parameters->{file} ) {
        $self->{FILE} = $parameters->{file};
    }
    return $self;
}

=head2 setConf($self, { conf })

Set the cacti configuration file.

=cut

sub setConf {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { conf => 1 } );

    if ( $parameters->{conf} =~ m/\/.*\.conf$/mx ) {
        $self->{CONF} = $parameters->{conf};
        return 0;
    }
    else {
        $self->{LOGGER}->error( "Cannot set configuration file." );
        return -1;
    }
}

=head2 setFile($self, { file })

set the output file.

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

    my %config = ();
    unless ( -f $self->{CONF} ) {
        $self->{LOGGER}->error( "Cannot find config file \"" . $self->{CONF} . "\", aborting." );
        return -1;
    }
    %config = ParseConfig( $self->{CONF} );

    my %attr = ( RaiseError => 1, );
    my $dbh = DBI->connect( "DBI:mysql:database=" . $config{"DB_Database"} . ";host=" . $config{"DB_Host"}, $config{"DB_User"}, $config{"DB_Pass"}, \%attr )
        or print "Database \"" . $config{"DB_Host"} . ":" . $config{"DB_Database"} . "\" unavailable with user \"" . $config{"DB_User"} . "\" and password \"" . $config{DB_Pass} . "\".\n";

    my $query = "select cacti from version";
    my $sth   = $dbh->prepare( $query );
    $sth->execute() or print "Query error on statement \"" . $query . "\".\n";
    my $result = $sth->fetchall_arrayref;

    my $pass = 0;
    my $string;
    foreach my $ver ( @{ $self->{VERSIONS} } ) {
        $string .= " " . $ver;
        if ( $ver eq $result->[0][0] ) {
            $pass = 1;
        }
    }
    unless ( $pass ) {
        $self->{LOGGER}->warn( "Cacti version mismatch.  This script has only been tested with versions \"" . join( ',', @{ $self->{VERSIONS} } ) . "\"." );

        #        return -1;
    }

    my $rrd = new perfSONAR_PS::DB::RRD( { path => $self->{"RRDTOOL"}, error => 1 } );
    $rrd->openDB({});
    $self->{STORE} = $self->printHeader();

    $query = "select id, description, hostname from host order by id";
    $sth   = $dbh->prepare( $query );
    $sth->execute() or print "Query error on statement \"" . $query . "\".\n";
    $result = $sth->fetchall_arrayref;

    my $len = $#{$result};
    for my $a ( 0 .. $len ) {
        my %md = (
            id          => q{},
            description => q{},
            hostName    => q{},
            ifIndex     => q{},
            ifDescr     => q{},
            ifName      => q{},
            ifSpeed     => q{},
            ifHighSpeed => q{},
            ifIP        => q{}
        );

        $md{"id"}          = $result->[$a][0];
        $md{"description"} = $result->[$a][1];
        $md{"hostName"}    = $result->[$a][2];

        my $packed_ip = gethostbyname( $md{"hostName"} );
        if ( defined $packed_ip ) {
            $md{"ipAddress"} = inet_ntoa( $packed_ip );
        }
        else {
            $md{"ipAddress"} = q{};
        }

        if ( not( $md{"hostName"} =~ m/localhost/i ) and ( $md{"hostName"} ne "127.0.0.1" ) ) {
            $query = "select id, snmp_index from data_local where host_id = \"" . $result->[$a][0] . "\" order by id";
            $sth   = $dbh->prepare( $query );
            $sth->execute() or print "Query error on statement \"" . $query . "\".\n";
            my $result2 = $sth->fetchall_arrayref;

            my $len2 = $#{$result2};
            for my $b ( 0 .. $len2 ) {
                next unless $result2->[$b][1] and $result2->[$b][1] =~ m/^\d+$/;
                my @list = ( "ifIndex", "ifDescr", "ifName", "ifSpeed", "ifHighSpeed", "ifIP" );
                my %lookup = ();
                foreach my $l ( @list ) {
                    $query = "select field_value from host_snmp_cache where host_id = \"" . $result->[$a][0] . "\" and field_name = \"" . $l . "\" and snmp_index = \"" . $result2->[$b][1] . "\"";
                    $sth   = $dbh->prepare( $query );
                    $sth->execute() or print "Query error on statement \"" . $query . "\".\n";
                    my $result4 = $sth->fetchall_arrayref;
                    $md{$l} = $result4->[0][0];
                }
                $md{"ifIndex"} = $result2->[$b][1] if not $md{"ifIndex"};
                $md{"ifHighSpeed"} *= 1000000 if $md{"ifHighSpeed"};

                $query = "select rrd_name, rrd_path from poller_item where host_id = \"" . $result->[$a][0] . "\" and local_data_id = \"" . $result2->[$b][0] . "\"";
                $sth   = $dbh->prepare( $query );
                $sth->execute() or print "Query error on statement \"" . $query . "\".\n";
                my $result3 = $sth->fetchall_arrayref;

                for ( my $c = 0; $c <= $#{$result3}; $c++ ) {
                    next unless $result3->[$c][0] =~ m/traffic/;
                    my %d = (
                        id   => q{},
                        ds   => q{},
                        file => q{}
                    );
                    $d{"id"}   = $result2->[$b][0];
                    $d{"ds"}   = $result3->[$c][0];
                    $d{"file"} = $result3->[$c][1];

                    if ( $result3->[$c][0] =~ m/in/ ) {
                        $d{"id"}     = $d{"id"} . "_in";
                        $md{"ifDir"} = "in";
                    }
                    elsif ( $result3->[$c][0] =~ m/out/ ) {
                        $d{"id"}     = $d{"id"} . "_out";
                        $md{"ifDir"} = "out";
                    }
                    $self->{STORE} .= $self->printPair( { rrddb => $rrd, metadata => \%md, data => \%d } );
                }
            }
        }
    }
    $dbh->disconnect();
    $self->{STORE} .= $self->printFooter();
    $rrd->closeDB;

    return 0;
}

=head2 printHeader($self, { })

Print out the store.xml header.

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

=head2 printPair($self, { metadata, data })

Given some metadata and data information, print out the associated XML pair.

=cut

sub printPair {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { rrddb => 0, metadata => 1, data => 1 } );

    my $output = "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata." . $parameters->{metadata}->{"id"} . "-" . $parameters->{data}->{"id"} . "\">\n";
    $output .= "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"subject." . $parameters->{metadata}->{"id"} . "-" . $parameters->{data}->{"id"} . "\">\n";
    $output .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
    $output .= "        <nmwgt:ipAddress type=\"ipv4\">" . $parameters->{metadata}->{"ipAddress"} . "</nmwgt:ipAddress>\n" if defined $parameters->{metadata}->{"ipAddress"};
    $output .= "        <nmwgt:ifAddress type=\"ipv4\">" . $parameters->{metadata}->{"ifIP"} . "</nmwgt:ifAddress>\n" if defined $parameters->{metadata}->{"ifIP"};
    $output .= "        <nmwgt:hostName>" . $parameters->{metadata}->{"hostName"} . "</nmwgt:hostName>\n" if defined $parameters->{metadata}->{"hostName"};
    if ( $parameters->{metadata}->{"ifName"} ) {
        $output .= "        <nmwgt:ifName>" . $parameters->{metadata}->{"ifName"} . "</nmwgt:ifName>\n";
    }
    else {
        $output .= "        <nmwgt:ifName>" . $parameters->{metadata}->{"ifDescr"} . "</nmwgt:ifName>\n" if defined $parameters->{metadata}->{"ifDescr"};
    }
    $output .= "        <nmwgt:ifIndex>" . $parameters->{metadata}->{"ifIndex"} . "</nmwgt:ifIndex>\n"             if defined $parameters->{metadata}->{"ifIndex"};
    $output .= "        <nmwgt:direction>" . $parameters->{metadata}->{"ifDir"} . "</nmwgt:direction>\n"           if defined $parameters->{metadata}->{"ifDir"};
    if ( exists $parameters->{metadata}->{"ifHighSpeed"} and $parameters->{metadata}->{"ifHighSpeed"} ) {
        $output .= "        <nmwgt:capacity>" . $parameters->{metadata}->{"ifHighSpeed"} . "</nmwgt:capacity>\n"           if defined $parameters->{metadata}->{"ifHighSpeed"};
    }
    else {
        $output .= "        <nmwgt:capacity>" . $parameters->{metadata}->{"ifSpeed"} . "</nmwgt:capacity>\n"           if defined $parameters->{metadata}->{"ifSpeed"};
    }
    $output .= "        <nmwgt:description>" . $parameters->{metadata}->{"description"} . "</nmwgt:description>\n" if defined $parameters->{metadata}->{"description"};
    $output .= "        <nmwgt:ifDescription>" . $parameters->{metadata}->{"ifDescr"} . "</nmwgt:ifDescription>\n" if defined $parameters->{metadata}->{"ifDescr"};
    $output .= "      </nmwgt:interface>\n";
    $output .= "    </netutil:subject>\n";
    $output .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>\n";
    $output .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
    $output .= "    <nmwg:parameters id=\"parameters." . $parameters->{metadata}->{"id"} . "-" . $parameters->{data}->{"id"} . "\">\n";
    $output .= "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
    $output .= "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
    $output .= "    </nmwg:parameters>\n";
    $output .= "  </nmwg:metadata>\n\n";
    $output .= "  <nmwg:data xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"data." . $parameters->{data}->{"id"} . "\" metadataIdRef=\"metadata." . $parameters->{metadata}->{"id"} . "-" . $parameters->{data}->{"id"} . "\">\n";
    $output .= "    <nmwg:key id=\"key." . $parameters->{data}->{"id"} . "\">\n";
    $output .= "      <nmwg:parameters id=\"parametersKey." . $parameters->{data}->{"id"} . "\">\n";
    $output .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"type\">rrd</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"file\">" . $parameters->{data}->{"file"} . "</nmwg:parameter>\n" if defined $parameters->{data}->{"file"};
    $output .= "        <nmwg:parameter name=\"valueUnits\">Bps</nmwg:parameter>\n";
    $output .= "        <nmwg:parameter name=\"dataSource\">" . $parameters->{data}->{"ds"} . "</nmwg:parameter>\n" if defined $parameters->{data}->{"ds"};

    if ( exists $parameters->{rrddb} ) {
        $parameters->{rrddb}->setFile( { file => $parameters->{data}->{"file"} } );
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

If the output file has been set, and there is content in the cacti xml storage,
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
    $self->{LOGGER}->error( "Cacti xml content is empty, did you call \"openDB\"?" );
    return -1;
}

=head2 closeDB($self, { })

'Closes' the store.xml database that is created from the cacti data by
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

L<Log::Log4perl>, L<Params::Validate>, L<Config::General>, L<DBI>, L<Socket>,
L<perfSONAR_PS::Utils::ParameterValidation>, L<perfSONAR_PS::DB::RRD>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Cacti.pm 4032 2010-04-23 17:19:23Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut
