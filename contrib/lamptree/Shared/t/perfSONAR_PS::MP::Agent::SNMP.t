use Test::More 'no_plan';
use Log::Log4perl qw( :levels);

Log::Log4perl->easy_init($DEBUG);

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
# use class
use_ok('perfSONAR_PS::MP::Agent::SNMP');

# instantiate
my $agent = perfSONAR_PS::MP::Agent::SNMP->new( );
ok( $agent->isa( 'perfSONAR_PS::MP::Agent::SNMP'), 'Instantiation');

# add fields
my $host = 'swh-core1';
ok( $agent->host( $host ) eq $host, 'set host' );
my $port = 161;
ok( $agent->port( $port ) eq $port, 'set port' );
my $community = `cat /afs/slac.stanford.edu/g/scs/net/cisco/config/etc/snmp.community.read`;
chomp( $community );
ok( $agent->community( $community ) eq $community, 'set community string' );
my $version = '2c';
ok( $agent->version( $version ) eq $version, 'set version' );

# init
ok( $agent->init() eq 0, "initialisation okay");


# try without any defined
my $status = $agent->collectMeasurements();
ok( $status eq -1 , 'collectMeasurements() with no variables' );

# clear the list of variables to get
$agent->removeVariables();
ok( keys %{$agent->variables()} eq 0, "Cleared variables" );

# try with single for sysdescr
my $oid = '.1.3.6.1.2.1.1.1.0';
$status = $agent->collectMeasurements( $oid );
ok( $status eq 0 , 'collectMeasurements() for sysdescr: ' );

# clear the list of variables to get
$agent->removeVariables();
ok( keys %{$agent->variables()} eq 0, "Cleared variables" );


print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";

1;