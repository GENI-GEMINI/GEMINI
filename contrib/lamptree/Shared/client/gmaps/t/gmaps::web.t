use Test::More 'no_plan';
use Data::Compare qw( Compare );
use Data::Dumper;

use Log::Log4perl qw( :easy );

Log::Log4perl->easy_init( $DEBUG );
our $logger = get_logger("test");


print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

use lib '/afs/slac.stanford.edu/u/sf/ytl/Work/perfSONAR/perfSONAR-PS/branches/yee/gmaps-with-topologyservice/lib/';
use lib '/afs/slac.stanford.edu/u/sf/ytl/Work/perfSONAR/perfSONAR-PS/trunk/perfSONAR-PS/lib/';

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# use
use_ok('gmaps::web');
use_ok('gmaps::paths');

# set template path
${gmaps::paths::templatePath} = '/afs/slac.stanford.edu/u/sf/ytl/Work/perfSONAR/perfSONAR-PS/branches/yee/gmaps-with-topologyservice/templates/';

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# create new web app
my $webApp = gmaps::web->new();
ok( $webApp->isa( "CGI::Application"), "Instantiation");


my $url = undef;
my $urn = undef;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# do a topology query
#$url = 'http://packrat.internet2.edu:5800/perfSONAR_PS/services/topology';
#$urn = 'urn:ogf:network:domain=I2:node=oob.sunn:port=Loopback0';
$url = 'http://lhcopnmon1-mgm.fnal.gov:8083/perfSONAR_PS/services/topology';
$urn = undef; #'urn:ogf:network:domain=shams.edu.eg:node=net';
my $topologyXML = $webApp->getMarkersFromTopologyService( $url, $urn );
$logger->fatal( "XML: ($topologyXML)" . $$topologyXML );
ok( $topologyXML, "Getting topology info from '$url' for '$urn'");

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# do a utilisaiton query
my $url = 'http://mea1.es.net:8080/perfSONAR_PS/services/snmpMA';
my $urn = '';
my $utilisationXML = $webApp->getMarkersFromUtilisationService( $url, $urn );
$logger->fatal( "XML: ($utilisationXML)" . $$utilisationXML );
ok( $topologyXML, "Getting utilisation topology info from '$url' for '$urn'");



1;