use Test::More 'no_plan';
use Log::Log4perl qw( :levels);

Log::Log4perl->easy_init($DEBUG);

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
# use class
use_ok('perfSONAR_PS::MP::Agent::Ping');

# instantiate
my $agent = perfSONAR_PS::MP::Agent::Ping->new();
ok( $agent->isa( 'perfSONAR_PS::MP::Agent::Ping'), 'Instantiation');

# setup options
my $host = 'localhost';
$agent->destination( $host );
ok( $agent->destination() eq $host, 'setup destination');

my $count = 5;
$agent->count( $count );
ok( $agent->count() eq $count, 'setup count');
my $ttl = 64;

my $packetSize = 1000;
$agent->packetSize( $packetSize );
ok( $agent->packetSize() eq $packetSize, 'setup packetSize');

my $ttl = 64;
$agent->ttl( $ttl );
ok( $agent->ttl() eq $ttl, 'setup ttl');

my $interval = 1;
$agent->interval( $interval );
ok( $agent->interval() eq $interval, 'setup interval');

# need to do something about this, so it doesn't add it 
my $deadline = 10;
$agent->deadline( $deadline );
ok( $agent->deadline() eq $deadline, 'setup deadline');

# do the measurement
my $status = $agent->collectMeasurements();
ok( $status eq 0 , 'collectMeasurements()' );

use Data::Dumper;
print Dumper $agent->results();

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

1;