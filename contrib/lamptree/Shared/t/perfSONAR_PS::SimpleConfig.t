use Test::More 'no_plan';
use Data::Compare qw( Compare );
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
 
use_ok('perfSONAR_PS::SimpleConfig');
use   perfSONAR_PS::SimpleConfig;
Log::Log4perl->init("./t/logger.conf");

my %CONF_VALID = (PORT => '^\d+$', DB_NAME => '^\w+$', DB_DRIVER => '^SQLite|mysql|Pg$');

my %CONF_KEYS = (PORT => ' enter any number  and press Enter ');

  
  my $cfg = "./t/testfiles/test.conf";
  my $conf =  undef;
 # 2 
  eval {
     $conf = new perfSONAR_PS::SimpleConfig(-FILE => $cfg ) 
  };
  ok( $conf , "perfSONAR_PS::SimpleConfig create object");
  $@ = undef;

 # 3 
 my $hashref1 =  $conf->parse; 
 ok($hashref1  , " perfSONAR_PS::SimpleConfig parse file  " );
   
 
   
 
#  4 
  my $hashref3 =  $conf->getNormalizedData;
  ok( $hashref3 , "perfSONAR_PS::SimpleConfig  getNormalizedData OK " );
  
 
# 5
  eval {  
    $conf->store("/tmp/test.conf")
  };
  ok(!$@, "perfSONAR_PS::SimpleConfig store file ". $@);  
  $@ = undef;
 
 
  # 6
    
   $conf = new perfSONAR_PS::SimpleConfig(-FILE=> $cfg, -DIALOG => '1',   -VALIDKEYS => \%CONF_VALID, -PROMPTS => \%CONF_KEYS); 
   ok( $conf , "perfSONAR_PS::SimpleConfig create object with patterns and prompts");
  
 # 7
    
  ok( $conf->parse , "perfSONAR_PS::SimpleConfig parse with prompts file   " );
  

print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
