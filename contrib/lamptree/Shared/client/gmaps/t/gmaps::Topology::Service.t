use Test::More 'no_plan';
use Data::Compare qw( Compare );
use Data::Dumper;

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $DEBUG );

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# use
use_ok('gmaps::Topology::Service');

# define a host that shoudl be contactable
my $serviceURI = undef;
my $urnOfPort = undef;

if ( 1 ) {
	$serviceURI = 'http://lhcopnmon1-mgm.fnal.gov:8083/perfSONAR_PS/services/topology';
	$host = 'lhcopnmon1-mgm.fnal.gov';
	$urnOfPort = "urn:ogf:network:domain=shams.edu.eg:node=net";
} else {
	$serviceURI = 'http://packrat.internet2.edu:5800/perfSONAR_PS/services/topology';
	$urnOfPort = "urn:ogf:network:domain=I2:node=oob.sunn";
}

# define the directory
use_ok('gmaps::paths');
${gmaps::paths::templatePath} = '/u/sf/ytl/Work/perfSONAR/perfSONAR-PS/branches/yee/gmaps-with-topologyservice/templates/';

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# create an object
my $topologyService = gmaps::Topology::Service->new( $serviceURI );
ok( $topologyService, "Instantiation" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# is alive
my $alive = $topologyService->isAlive();
ok( $alive eq 1, "Service is alive" );


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# test get all nodes registered
for my $urn ( undef, "$urnOfPort" ) {

	my $nodes = $topologyService->getNodes( $urn );
	ok( scalar @$nodes, "Got " . scalar @$nodes . " nodes for '$urn'");
	
	# don't do it for each node, just for when we define one
	next if ! defined $urn;
	
	foreach my $node ( @$nodes ) {
		# get the ports of the node; returns an array of hashed describg the ports
		my @ports = $topologyService->getPorts( $node );
		ok( scalar @ports, "Found " . scalar @ports . " ports in node '$urnOfPort'\n" . Dumper \@ports);
	}

}


exit;


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# get all domains
my $domains = $topologyService->getDomains();
ok( scalar @$domains, "List of domains: @$domains (" . scalar @$domains . ")" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# get all domains
foreach my $d ( @$domains ) {
	my $nodes = $topologyService->getNodesInDomain( $d );
	ok( scalar @$nodes, "List of nodes in domain '$d'" );
	
	foreach my $node ( @$nodes ) {
		my ( $lat, $long ) = $topologyService->getLatLong( $node );
		my @ports = $topologyService->getPorts( $node );
		ok( defined $lat && defined $long && scalar @ports, "  Found info for " . scalar @ports . " port(s) at $lat,$long");
	}

}






1;
