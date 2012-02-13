use Test::More 'no_plan';
use Data::Compare qw( Compare );
use XML::LibXML;

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
# use class
use_ok('perfSONAR_PS::MP::Agent::Base');

# instantiate
my $agent = new perfSONAR_PS::MP::Agent::Base;
ok( $agent->isa( 'perfSONAR_PS::MP::Agent::Base'), 'Instantiation');

# error
$agent->error( 'This is an error' );
ok( $agent->error() eq 'This is an error', 'Error okay');

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";


