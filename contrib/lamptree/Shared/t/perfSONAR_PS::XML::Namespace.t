use Test::More 'no_plan';
use Data::Compare qw( Compare );
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
 
use_ok('perfSONAR_PS::XML::Namespace');
use   perfSONAR_PS::XML::Namespace;
Log::Log4perl->init("./t/logger.conf");

  my $conf =  undef;
 # 2 
  eval {
     $conf = new perfSONAR_PS::XML::Namespace( ) 
  };
 ok( $conf , "perfSONAR_PS::XML::Namespace create object");
  $@ = undef;

 # 3 
 my $nmwg =  $conf->getNsByKey('nmwg'); 
 ok($nmwg eq 'http://ggf.org/ns/nmwg/base/2.0/'  , "perfSONAR_PS::XML::Namespace  getNsByKey('nmwg')  " );
   
 
 # 3 
 my $nmwgr =  perfSONAR_PS::XML::Namespace::getNsByKey('nmwgr'); 
 ok($nmwgr eq 'http://ggf.org/ns/nmwg/result/2.0/'  , "perfSONAR_PS::XML::Namespace  perfSONAR_PS::XML::Namespace::getNsByKey('nmwgr')  " );
  

print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
