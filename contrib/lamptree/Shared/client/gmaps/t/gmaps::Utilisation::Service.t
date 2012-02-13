use Test::More 'no_plan';
use Data::Compare qw( Compare );

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $DEBUG );

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# use
use_ok('gmaps::Utilisation::Service');

# define the directory
use_ok('gmaps::paths');
my $path = `pwd`;
chomp $path;
${gmaps::paths::templatePath} = $path . '/../templates/';



# define a host that shoudl be contactable
my $serviceURI = 'http://mea1.es.net:8080/perfSONAR_PS/services/snmpMA';
my $urn = undef;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# create an object
my $utilService = gmaps::Utilisation::Service->new( $serviceURI );
ok( $utilService, "Instantiation" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# is alive
my $alive = $utilService->isAlive();
ok( $alive eq 1, "Service is alive" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# query for ports registered with Ma
my $ports = $utilService->getPorts( $urn );
ok( scalar @$ports, "Service has " . scalar @$ports . " for urn '$urn'" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# fetch for some data for the port
my $urn = 'urn:ogf:network:domain=ESnet-Public:node=atl-cr1.es.net:port=t3-2/0/0.0';
my $data = $utilService->fetch2( $urn );
my $size = scalar keys %{$data};
ok( $size > 0, "Port has data: $size" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# graph that data
my $graph = '/tmp/graph.png';
open ( PNG, ">$graph" ) or $logger->logdie( "could not open a temporary file to write to" );
print PNG ${$utilService->graph( $data )};

ok( -e $graph, "Successfully created a png for utilisation" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# do a full fetch




1;
