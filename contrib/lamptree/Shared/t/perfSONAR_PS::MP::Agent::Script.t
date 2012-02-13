use Test::More 'no_plan';
use Log::Log4perl qw( :levels);

Log::Log4perl->easy_init($DEBUG);

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
# use class
use_ok('perfSONAR_PS::MP::Agent::Script');

# instantiate
my $script = 'testfiles/mp-agent-script.sh';
my $args = 'this is a list of arguments';
my $agent = perfSONAR_PS::MP::Agent::Script->new( $script, $args );
ok( $agent->isa( 'perfSONAR_PS::MP::Agent::Script'), 'Instantiation');

# find cmd
ok( $agent->command() eq $script, "Command okay");

# options
ok( $agent->arguments() eq $args, 'Options okay' );


# init
ok( $agent->init() eq 0, "initialisation okay");


# run the command
my $status = $agent->collectMeasurements();
ok( $status eq 0 , 'collectMeasurements()' );

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";


1;