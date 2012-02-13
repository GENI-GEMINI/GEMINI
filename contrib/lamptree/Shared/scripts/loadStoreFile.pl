#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

loadStoreFile.pl

=head1 DESCRIPTION

Given a well formed store.xml file, commonly used for services such as the
SNMP MA or perfSONARBOUY, load the contents into an XMLDB.  The service may
then use XMLDB API calls to extract information instead of consuming store
file information directly.

=head1 SYNOPSIS

./loadStoreFile.pl [--verbose --help --environment=/path/to/env --container=container.dbxml --filename=/path/to/store.xml]

=cut

use Getopt::Long;
use XML::LibXML;
use Digest::MD5 qw(md5_hex);

use lib "../lib";

use perfSONAR_PS::DB::XMLDB;
use perfSONAR_PS::Services::LS::General;

my $DEBUG = '';
my $HELP  = '';
my %opts  = ();
GetOptions(
    'verbose'       => \$DEBUG,
    'help'          => \$HELP,
    'type=s'        => \$opts{TYPE},
    'environment=s' => \$opts{ENV},
    'container=s'   => \$opts{CONT}
);

if ( !( defined $opts{ENV} and $opts{CONT} ) or $HELP ) {
    print "$0: Loads into the specified container in the XML DB environment the contents of the store file.\n";
    print "$0 [--verbose --help --environment=/path/to/env/xmldb --container=container.dbxml --type=(LSStore|LSStore-control|LSStore-summary)]\n";
    exit( 1 );
}

my $XMLDBENV  = "/var/lib/perfsonar/snmp_ma/xmldb";
my $XMLDBCONT = "snmpstore.dbxml";
my $XMLDBTYPE = "MAStore";
if ( defined $opts{ENV} ) {
    $XMLDBENV = $opts{ENV};
}
if ( defined $opts{CONT} ) {
    $XMLDBCONT = $opts{CONT};
}

if ( defined $opts{TYPE} ) {
    $XMLDBTYPE = $opts{TYPE};
}

my %ns = (
    nmwg          => "http://ggf.org/ns/nmwg/base/2.0/",
    nmtm          => "http://ggf.org/ns/nmwg/time/2.0/",
    ifevt         => "http://ggf.org/ns/nmwg/event/status/base/2.0/",
    snmp          => "http://ggf.org/ns/nmwg/tools/snmp/2.0/",
    iperf         => "http://ggf.org/ns/nmwg/tools/iperf/2.0/",
    bwctl         => "http://ggf.org/ns/nmwg/tools/bwctl/2.0/",
    netutil       => "http://ggf.org/ns/nmwg/characteristic/utilization/2.0/",
    neterr        => "http://ggf.org/ns/nmwg/characteristic/errors/2.0/",
    netdisc       => "http://ggf.org/ns/nmwg/characteristic/discards/2.0/",
    select        => "http://ggf.org/ns/nmwg/ops/select/2.0/",
    average       => "http://ggf.org/ns/nmwg/ops/average/2.0/",
    perfsonar     => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/",
    psservice     => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/",
    xquery        => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/",
    xpath         => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xpath/1.0/",
    nmwgt         => "http://ggf.org/ns/nmwg/topology/2.0/",
    nmwgtopo3     => "http://ggf.org/ns/nmwg/topology/base/3.0/",
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
    sonet         => "http://ogf.org/schema/network/topology/sonet/20070828/",
    transport     => "http://ogf.org/schema/network/topology/transport/20070828/",
    pinger        => "http://ggf.org/ns/nmwg/tools/pinger/2.0/",
    nmwgr         => "http://ggf.org/ns/nmwg/result/2.0/",
    traceroute    => "http://ggf.org/ns/nmwg/tools/traceroute/2.0/",
    ping          => "http://ggf.org/ns/nmwg/tools/ping/2.0/",
    owamp         => "http://ggf.org/ns/nmwg/tools/owamp/2.0/"
);

my $error      = q{};
my $metadatadb = new perfSONAR_PS::DB::XMLDB(
    {
        env  => $XMLDBENV,
        cont => $XMLDBCONT,
        ns   => \%ns
    }
);
my $status = $metadatadb->openDB( { txn => q{}, error => \$error } );
unless ( $status == 0 ) {
    print "There was an error opening \"" . $XMLDBENV . "/" . $XMLDBCONT . "\": " . $error;
    exit( 1 );
}

my $parser = XML::LibXML->new();
my $dom    = $parser->parse_file( $XMLFILE );

my $dbTr = $metadatadb->getTransaction( { error => \$error } );
unless ( $dbTr ) {
    $metadatadb->abortTransaction( { txn => $dbTr, error => \$error } ) if $dbTr;
    undef $dbTr;
    print "There was an error creating a transaction for \"" . $XMLDBENV . "/" . $XMLDBCONT . "\": " . $error . "\n";
    exit( 1 );
}

foreach my $data ( $dom->getDocumentElement->getChildrenByTagNameNS( $ns{"nmwg"}, "data" ) ) {
    my $metadata = $dom->getDocumentElement->find( "./nmwg:metadata[\@id=\"" . $data->getAttribute( "metadataIdRef" ) . "\"]" )->get_node( 1 );
    my $dHash    = md5_hex( $data->toString );
    my $mdHash   = md5_hex( $metadata->toString );
    $metadatadb->insertIntoContainer( { content => wrapStore( $data->toString,     "MAStore" ), name => $dHash,  txn => $dbTr, error => \$error } );
    $metadatadb->insertIntoContainer( { content => wrapStore( $metadata->toString, "MAStore" ), name => $mdHash, txn => $dbTr, error => \$error } );
}

$status = $metadatadb->commitTransaction( { txn => $dbTr, error => \$error } );
if ( $status == 0 ) {
    print "Operation completed.\n";
}
else {
    print "There was an error commiting transaction for \"" . $XMLDBENV . "/" . $XMLDBCONT . "\": " . $error . "\n";
    $metadatadb->abortTransaction( { txn => $dbTr, error => \$error } ) if $dbTr;
}
undef $dbTr;
$metadatadb->closeDB( { error => \$error } );

exit( 1 );

__END__

=head1 SEE ALSO

L<Getopt::Long>, L<XML::LibXML>, L<Digest::MD5>, L<perfSONAR_PS::DB::XMLDB>,
L<perfSONAR_PS::Services::LS::General>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: loadStoreFile.pl 2640 2009-03-20 01:21:21Z zurawski $

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
