use warnings;
use strict;    
use Test::More 'no_plan';
use Data::Dumper;
use English qw( -no_match_vars);
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
use_ok('perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node');
use    perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node;
use perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node::Name;
use perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology::Domain::Node::Test;
use perfSONAR_PS::Datatypes::v2_0::nmtl3::Topology::Domain::Node::Port;
Log::Log4perl->init("logger.conf"); 

my $obj1 = undef;
#2
eval {
$obj1 = perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node->new({
  'metadataIdRef' =>  'value_metadataIdRef',  'id' =>  'value_id',})
};
  ok( $obj1  && !$EVAL_ERROR , "Create object perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#3
 my $ns  =  $obj1->nsmap->mapname('node');
 ok($ns  eq 'nmtb', "  mapname('node')...  ");
#4
 my $metadataIdRef  =  $obj1->metadataIdRef;
 ok($metadataIdRef  eq 'value_metadataIdRef', " checking accessor  obj1->metadataIdRef ...  ");
#5
 my $id  =  $obj1->id;
 ok($id  eq 'value_id', " checking accessor  obj1->id ...  ");
#6
 my  $obj_name  = undef;
 eval {
      $obj_name  =  perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node::Name->new({  'type' =>  'valuetype',});
    $obj1->name($obj_name);
   }; 
 ok( $obj_name && !$EVAL_ERROR , "Create subelement object name and set it  ..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#7
 my  $obj_test  = undef;
 eval {
      $obj_test  =  perfSONAR_PS::Datatypes::v2_0::pingertopo::Topology::Domain::Node::Test->new({  'id' =>  'valueid',});
    $obj1->test($obj_test);
   }; 
 ok( $obj_test && !$EVAL_ERROR , "Create subelement object test and set it  ..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#8
 my  $obj_port  = undef;
 eval {
      $obj_port  =  perfSONAR_PS::Datatypes::v2_0::nmtl3::Topology::Domain::Node::Port->new({  'metadataIdRef' =>  'valuemetadataIdRef',  'id' =>  'valueid',});
    $obj1->port($obj_port);
   }; 
 ok( $obj_port && !$EVAL_ERROR , "Create subelement object port and set it  ..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#9
 my $string = undef;
 eval {
      $string =  $obj1->asString 
 };
 ok($string   && !$EVAL_ERROR  , "  Converting to string XML:   $string " . $EVAL_ERROR);
 $EVAL_ERROR = undef;
#10
 my $obj22 = undef; 
 eval {
    $obj22   =   perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node->new({xml => $string});
 };
 ok( $obj22  && !$EVAL_ERROR , "  re-create object from XML string:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
#11
 my $dom1 = $obj1->getDOM();
 my $obj2 = undef; 
 eval {
    $obj2   =   perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node->new($dom1);
 };
 ok( $obj2  && !$EVAL_ERROR , "  re-create object from DOM XML:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
