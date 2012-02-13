use warnings;
use strict;    
use Test::More 'no_plan';
use Data::Dumper;
use English qw( -no_match_vars);
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
use_ok('perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain');
use    perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain;
use perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node;
Log::Log4perl->init("logger.conf"); 

my $obj1 = undef;
#2
eval {
$obj1 = perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain->new({
  'metadataIdRef' =>  'value_metadataIdRef',  'id' =>  'value_id',})
};
  ok( $obj1  && !$EVAL_ERROR , "Create object perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#3
 my $ns  =  $obj1->nsmap->mapname('domain');
 ok($ns  eq 'nmtb', "  mapname('domain')...  ");
#4
 my $metadataIdRef  =  $obj1->metadataIdRef;
 ok($metadataIdRef  eq 'value_metadataIdRef', " checking accessor  obj1->metadataIdRef ...  ");
#5
 my $id  =  $obj1->id;
 ok($id  eq 'value_id', " checking accessor  obj1->id ...  ");
#6
 my  $obj_node  = undef;
 eval {
      $obj_node  =  perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain::Node->new({  'metadataIdRef' =>  'valuemetadataIdRef',  'id' =>  'valueid',});
    $obj1->addNode($obj_node);
  }; 
 ok( $obj_node && !$EVAL_ERROR , "Create subelement object node and set it  ..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#7
 my $string = undef;
 eval {
      $string =  $obj1->asString 
 };
 ok($string   && !$EVAL_ERROR  , "  Converting to string XML:   $string " . $EVAL_ERROR);
 $EVAL_ERROR = undef;
#8
 my $obj22 = undef; 
 eval {
    $obj22   =   perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain->new({xml => $string});
 };
 ok( $obj22  && !$EVAL_ERROR , "  re-create object from XML string:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
#9
 my $dom1 = $obj1->getDOM();
 my $obj2 = undef; 
 eval {
    $obj2   =   perfSONAR_PS::Datatypes::v2_0::nmtb::Topology::Domain->new($dom1);
 };
 ok( $obj2  && !$EVAL_ERROR , "  re-create object from DOM XML:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
