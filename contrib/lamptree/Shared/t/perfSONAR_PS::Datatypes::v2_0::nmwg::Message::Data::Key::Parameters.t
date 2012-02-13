use warnings;
use strict;    
use Test::More 'no_plan';
use Data::Dumper;
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
use_ok('perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters');
use    perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters;
use perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters::Parameter;
Log::Log4perl->init("/home/netadmin/LHCOPN/perfSONAR-PS/trunk/lib/perfSONAR_PS/logger.conf"); 

my $obj1 = undef;
#2
eval {
$obj1 = perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters->new({
  'id' =>  'value_id',})
};
  ok( $obj1  && !$EVAL_ERROR , "Create object perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#3
 my $ns  =  $obj1->nsmap->mapname('parameters');
 ok($ns  eq 'nmwg', "  mapname('parameters')...  ");
#4
 my $id  =  $obj1->id;
 ok($id  eq 'value_id', " checking accessor  obj1->id ...  ");
#5
 my  $obj_parameter  = undef;
 eval {
      $obj_parameter  =  perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters::Parameter->new({  'value' =>  'valuevalue',  'name' =>  'valuename',});
    $obj1->addParameter($obj_parameter);
  }; 
 ok( $obj_parameter && !$EVAL_ERROR , "Create subelement object parameter and set it  ..." . $EVAL_ERROR);
  $EVAL_ERROR = undef; 
#6
 my $string = undef;
 eval {
      $string =  $obj1->asString 
 };
 ok($string   && !$EVAL_ERROR  , "  Converting to string XML:   $string " . $EVAL_ERROR);
 $EVAL_ERROR = undef;
#7
 my $obj22 = undef; 
 eval {
    $obj22   =   perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters->new({xml => $string});
 };
 ok( $obj22  && !$EVAL_ERROR , "  re-create object from XML string:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
#8
 my $dom1 = $obj1->getDOM();
 my $obj2 = undef; 
 eval {
    $obj2   =   perfSONAR_PS::Datatypes::v2_0::nmwg::Message::Data::Key::Parameters->new($dom1);
 };
 ok( $obj2  && !$EVAL_ERROR , "  re-create object from DOM XML:  ".   $EVAL_ERROR);
 $EVAL_ERROR = undef;
