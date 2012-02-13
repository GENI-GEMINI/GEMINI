use warnings;
use strict;    
use Test::More 'no_plan';
use Data::Dumper;
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
use_ok('perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology');
use    perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology;
use perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology::Domain;
Log::Log4perl->init("/home/netadmin/LHCOPN/perfSONAR-PS/trunk/lib/perfSONAR_PS/logger.conf"); 

my $obj1 = undef;
#2
eval {
$obj1 = perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology->new({
})
};
  ok( $obj1  && !$EVAL_ERROR , "Create object perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#3
 my $ns  =  $obj1->nsmap->mapname('topology');
 ok($ns  eq 'pingertopo', "  mapname('topology')...  ");
#4
 my  $obj_domain  = undef;
 eval {
      $obj_domain  =  perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology::Domain->new({  'id' =>  'valueid',});
    $obj1->addDomain($obj_domain);
  }; 
 ok( $obj_domain && !$EVAL_ERROR , "Create subelement object domain and set it  ..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#5
 my $string = undef;
 eval {
      $string =  $obj1->asString 
 };
 ok($string   && !$EVAL_ERROR  , "  Converting to string XML:   $string " . $EVAL_ERROR);
 $EVAL_ERROR = undef;
#6
 my $obj22 = undef; 
 eval {
    $obj22   =   perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology->new({xml => $string});
 };
 ok( $obj22  && !$EVAL_ERROR , "  re-create object from XML string:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
#7
 my $dom1 = $obj1->getDOM();
 my $obj2 = undef; 
 eval {
    $obj2   =   perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology->new($dom1);
 };
 ok( $obj2  && !$EVAL_ERROR , "  re-create object from DOM XML:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
