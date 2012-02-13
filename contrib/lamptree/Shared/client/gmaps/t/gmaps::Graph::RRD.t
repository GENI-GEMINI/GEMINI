use Test::More 'no_plan';
use Data::Compare qw( Compare );

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init( $DEBUG );

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# use
use_ok('gmaps::Graph::RRD');

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# create an object
my $file = '/tmp/test.rrd';
my $start = '1197178025';
my $entries = '4';
my $resolution = 300;

`rm $file`;

my $graph = gmaps::Graph::RRD->new( $file, $start, $resolution, $entries, 'minRtt', 'maxRtt' );
ok( $graph->isa( 'gmaps::Graph::RRD'), "Instantiation" );

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# add data
my $res = undef;
$res = $graph->add( 1197178025, { minRtt => 25.4, maxRtt => 28.5 } );
ok( $res eq 0, "Adding data");

$res = $graph->add( 1197178335, { minRtt => 23.2, maxRtt => 26.3 } );
ok( $res eq 0, "Adding data");

$res = $graph->add( 1197178645, { minRtt => 24.8, maxRtt => 29.6 } );
ok( $res eq 0, "Adding data");

$res = $graph->add( 1197178955, { minRtt => 23.1, maxRtt => 29.1 } );
ok( $res eq 0, "Adding data");


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# graph

my $png = $graph->getGraph( 1197178025, 1197178955 );
ok( $png, "Create png file");

1;
