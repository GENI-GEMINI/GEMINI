#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

makeStore.pl

=head1 DESCRIPTION

Create a temporary store file to ensure that the SNMP MA service
works properly.

=head1 SYNOPSIS

makeStore.pl

=cut

use English qw( -no_match_vars );
use File::Temp qw(tempfile);
use Carp;

my $confdir = shift;
unless ( $confdir ) {
    croak "Configuration directory not provided, aborting.\n";
    exit( 1 );
}

my $load = shift;

no strict 'refs';
eval {
    require RRDp;
    ${'RRDp::error_mode'} = 'catch';

    my $rrdtool = q{};
    if ( open( RRDTOOL, "which rrdtool |" ) ) {
        $rrdtool = <RRDTOOL>;
        $rrdtool =~ s/rrdtool:\s+//mx;
        $rrdtool =~ s/\n//gmx;
        unless ( close( RRDTOOL ) ) {
            croak "Cannot close RRDTool\n";
            exit( 1 );
        }
    }

    RRDp::start( $rrdtool );
    my $cmd .= "create " . $confdir . "/localhost.rrd --start N --step 1 ";
    $cmd    .= "DS:ifinoctets:COUNTER:10:U:U ";
    $cmd    .= "DS:ifoutoctets:COUNTER:10:U:U ";
    $cmd    .= "DS:ifinerrors:COUNTER:10:U:U ";
    $cmd    .= "DS:ifouterrors:COUNTER:10:U:U ";
    $cmd    .= "DS:ifindiscards:COUNTER:10:U:U ";
    $cmd    .= "DS:ifoutdiscards:COUNTER:10:U:U ";
    $cmd    .= "RRA:AVERAGE:0.5:1:241920 ";
    $cmd    .= "RRA:AVERAGE:0.5:2:120960 ";
    $cmd    .= "RRA:AVERAGE:0.5:6:40320 ";
    $cmd    .= "RRA:AVERAGE:0.5:12:20160 ";
    $cmd    .= "RRA:AVERAGE:0.5:24:10080 ";
    $cmd    .= "RRA:AVERAGE:0.5:36:6720 ";
    $cmd    .= "RRA:AVERAGE:0.5:48:5040 ";
    $cmd    .= "RRA:AVERAGE:0.5:60:4032 ";
    $cmd    .= "RRA:AVERAGE:0.5:120:2016";
    RRDp::cmd( $cmd );
    my $answer = RRDp::read();

};
if ( $EVAL_ERROR ) {
    print "RRD generation error: \"" . $EVAL_ERROR . "\", aborting.\n";
    exit ( 1 );
}

my ( $fileHandle, $fileName ) = tempfile();
print $fileHandle "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
print $fileHandle "<nmwg:store  xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
print $fileHandle "             xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\"\n";
print $fileHandle "             xmlns:neterr=\"http://ggf.org/ns/nmwg/characteristic/errors/2.0/\"\n";
print $fileHandle "             xmlns:netdisc=\"http://ggf.org/ns/nmwg/characteristic/discards/2.0/\"\n";
print $fileHandle "             xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"\n";
print $fileHandle "             xmlns:snmp=\"http://ggf.org/ns/nmwg/tools/snmp/2.0/\"\n";
print $fileHandle "             xmlns:nmtm=\"http://ggf.org/ns/nmwg/time/2.0/\">\n\n";

foreach my $et ( ( "netutil", "neterr", "netdisc" ) ) {
    foreach my $dir ( ( "in", "out" ) ) {
        print $fileHandle "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"m-" . $dir . "-" . $et . "-1\">\n";
        if ( $et eq "netutil" ) {
            print $fileHandle "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"s-" . $dir . "-" . $et . "-1\">\n";
        }
        elsif ( $et eq "neterr" ) {
            print $fileHandle "    <neterr:subject xmlns:neterr=\"http://ggf.org/ns/nmwg/characteristic/errors/2.0/\" id=\"s-" . $dir . "-" . $et . "-1\">\n";
        }
        elsif ( $et eq "netdisc" ) {
            print $fileHandle "    <netdisc:subject xmlns:netdisc=\"http://ggf.org/ns/nmwg/characteristic/discards/2.0/\" id=\"s-" . $dir . "-" . $et . "-1\">\n";
        }
        else {
            print $fileHandle "    <nmwg:subject id=\"s-" . $dir . "-" . $et . "-1\">\n";
        }
        print $fileHandle "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
        print $fileHandle "        <nmwgt:ifAddress type=\"ipv4\">127.0.0.1</nmwgt:ifAddress>\n";
        print $fileHandle "        <nmwgt:hostName>localhost</nmwgt:hostName>\n";
        print $fileHandle "        <nmwgt:ifName>eth0</nmwgt:ifName>\n";
        print $fileHandle "        <nmwgt:ifIndex>2</nmwgt:ifIndex>\n";
        print $fileHandle "        <nmwgt:direction>" . $dir . "</nmwgt:direction>\n";
        print $fileHandle "        <nmwgt:capacity>1000000000</nmwgt:capacity>\n";
        print $fileHandle "      </nmwgt:interface>\n";

        if ( $et eq "netutil" ) {
            print $fileHandle "    </netutil:subject>\n";
            print $fileHandle "    <nmwg:parameters id=\"p-" . $dir . "-" . $et . "-1\">\n";
            print $fileHandle "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
            print $fileHandle "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
            print $fileHandle "    </nmwg:parameters>\n";
            print $fileHandle "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
        }
        elsif ( $et eq "neterr" ) {
            print $fileHandle "    </neterr:subject>\n";
            print $fileHandle "    <nmwg:parameters id=\"p-" . $dir . "-" . $et . "-1\">\n";
            print $fileHandle "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/errors/2.0</nmwg:parameter>\n";
            print $fileHandle "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
            print $fileHandle "    </nmwg:parameters>\n";
            print $fileHandle "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/errors/2.0</nmwg:eventType>\n";
        }
        elsif ( $et eq "netdisc" ) {
            print $fileHandle "    </netdisc:subject>\n";
            print $fileHandle "    <nmwg:parameters id=\"p-" . $dir . "-" . $et . "-1\">\n";
            print $fileHandle "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/discards/2.0</nmwg:parameter>\n";
            print $fileHandle "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
            print $fileHandle "    </nmwg:parameters>\n";
            print $fileHandle "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/discards/2.0</nmwg:eventType>\n";
        }
        else {
            print $fileHandle "    </nmwg:subject>\n";
            print $fileHandle "    <nmwg:parameters id=\"p-" . $dir . "-" . $et . "-1\">\n";
            print $fileHandle "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
            print $fileHandle "    </nmwg:parameters>\n";
            print $fileHandle "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/discards/2.0</nmwg:eventType>\n";
        }

        print $fileHandle "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>\n";
        print $fileHandle "  </nmwg:metadata>\n\n";

        print $fileHandle "  <nmwg:data xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"d-" . $dir . "-" . $et . "-1\" metadataIdRef=\"m-" . $dir . "-" . $et . "-1\">\n";
        print $fileHandle "    <nmwg:key id=\"k-" . $dir . "-" . $et . "-1\">\n";
        print $fileHandle "      <nmwg:parameters id=\"pk-" . $dir . "-" . $et . "-1\">\n";
        print $fileHandle "        <nmwg:parameter name=\"eventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
        if ( $et eq "netutil" ) {
            print $fileHandle "        <nmwg:parameter name=\"eventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
        }
        elsif ( $et eq "neterr" ) {
            print $fileHandle "        <nmwg:parameter name=\"eventType\">http://ggf.org/ns/nmwg/characteristic/errors/2.0</nmwg:parameter>\n";
        }
        elsif ( $et eq "netdisc" ) {
            print $fileHandle "        <nmwg:parameter name=\"eventType\">http://ggf.org/ns/nmwg/characteristic/discards/2.0</nmwg:parameter>\n";
        }
        print $fileHandle "        <nmwg:parameter name=\"type\">rrd</nmwg:parameter>\n";
        print $fileHandle "        <nmwg:parameter name=\"file\">" . $confdir . "/localhost.rrd</nmwg:parameter>\n";
        if ( $et eq "netutil" ) {
            print $fileHandle "        <nmwg:parameter name=\"valueUnits\">Bps</nmwg:parameter>\n";
            print $fileHandle "        <nmwg:parameter name=\"dataSource\">if" . $dir . "octets</nmwg:parameter>\n";
        }
        elsif ( $et eq "neterr" ) {
            print $fileHandle "        <nmwg:parameter name=\"valueUnits\">Eps</nmwg:parameter>\n";
            print $fileHandle "        <nmwg:parameter name=\"dataSource\">if" . $dir . "errors</nmwg:parameter>\n";
        }
        elsif ( $et eq "netdisc" ) {
            print $fileHandle "        <nmwg:parameter name=\"valueUnits\">Dps</nmwg:parameter>\n";
            print $fileHandle "        <nmwg:parameter name=\"dataSource\">if" . $dir . "discards</nmwg:parameter>\n";
        }
        print $fileHandle "      </nmwg:parameters>\n";
        print $fileHandle "    </nmwg:key>\n";
        print $fileHandle "  </nmwg:data>\n\n";
    }
}
print $fileHandle "</nmwg:store>\n";
close( $fileHandle );

if ( $load ) {
    system( "mv " . $fileName . " " . $confdir . "/store.xml" );
}
else {
    print $fileName;
}

__END__

=head1 SEE ALSO

L<English>, L<File::Temp>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: makeStore.pl 2754 2009-04-13 14:46:03Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2

All rights reserved.

=cut
