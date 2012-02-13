use Test::More 'no_plan';

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
# use class
use_ok('perfSONAR_PS::MP::Agent::ConstantValue');

# instantiate
my $agent =  perfSONAR_PS::MP::Agent::ConstantValue->new( 42 );
ok( $agent->isa( 'perfSONAR_PS::MP::Agent::ConstantValue'), 'Instantiation');

# get
ok( $agent->results() eq '42', "value ok");


print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";


