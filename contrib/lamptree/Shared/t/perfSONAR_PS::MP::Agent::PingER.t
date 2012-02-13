use Test::More 'no_plan';
use Log::Log4perl qw( :levels);

Log::Log4perl->easy_init($DEBUG);

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
# use class
use_ok('perfSONAR_PS::MP::Agent::PingER');

# instantiate
my $agent = perfSONAR_PS::MP::Agent::PingER->new();
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

# do the measurement
my $status = $agent->collectMeasurements();
ok( $status eq 0 , 'collectMeasurements()' );

# check commonTime object type for the results
ok( $agent->results()->isa( 'perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::CommonTime' ), "Results okay" );

# output commontime as xml
#print $agent->results()->asString();

# create the message
ok( $agent->toDOM()->isa( XML::LibXML::Element ) eq 1, "toDOM: " . $agent->toDOM()->toString()  );



print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

1;