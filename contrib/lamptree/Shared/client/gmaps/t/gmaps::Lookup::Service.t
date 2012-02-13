use Test::More 'no_plan';
use Data::Compare qw( Compare );

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $DEBUG );

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# use
use_ok('gmaps::Lookup::Service');
use gmaps::Lookup::Service;

# define a host that shoudl be contactable
my $serviceURI = 'http://patdev0.internet2.edu:6666/perfSONAR_PS/services/LS';

# define the directory
use_ok('gmaps::paths');
${gmaps::paths::templatePath} = '/u/sf/ytl/Work/perfSONAR/perfSONAR-PS/branches/yee/gmaps-with-topologyservice/templates/';

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# create an object
my $lookupService = gmaps::Lookup::Service->new( $serviceURI );
ok( $lookupService, "Instantiation" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# is alive
my $alive = $lookupService->isAlive();
ok( $alive eq 1, "Service is alive" );


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# query for all topology services
my @topologyServices = $lookupService->getTopologyServices();





1;
