use warnings;
use strict;    
use Test::More 'no_plan';
use Data::Dumper;
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
use_ok('perfSONAR_PS::Datatypes::v2_0::nmwgr::Message::Data::Datum');
use    perfSONAR_PS::Datatypes::v2_0::nmwgr::Message::Data::Datum;
Log::Log4perl->init("/home/netadmin/LHCOPN/perfSONAR-PS/trunk/lib/perfSONAR_PS/logger.conf"); 

my $obj1 = undef;
#2
eval {
$obj1 = perfSONAR_PS::Datatypes::v2_0::nmwgr::Message::Data::Datum->new({
  'type' =>  'value_type',})
};
  ok( $obj1  && !$EVAL_ERROR , "Create object perfSONAR_PS::Datatypes::v2_0::nmwgr::Message::Data::Datum..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#3
 my $ns  =  $obj1->nsmap->mapname('datum');
 ok($ns  eq 'nmwgr', "  mapname('datum')...  ");
#4
 my $type  =  $obj1->type;
 ok($type  eq 'value_type', " checking accessor  obj1->type ...  ");
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
    $obj22   =   perfSONAR_PS::Datatypes::v2_0::nmwgr::Message::Data::Datum->new({xml => $string});
 };
 ok( $obj22  && !$EVAL_ERROR , "  re-create object from XML string:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
#7
 my $dom1 = $obj1->getDOM();
 my $obj2 = undef; 
 eval {
    $obj2   =   perfSONAR_PS::Datatypes::v2_0::nmwgr::Message::Data::Datum->new($dom1);
 };
 ok( $obj2  && !$EVAL_ERROR , "  re-create object from DOM XML:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
