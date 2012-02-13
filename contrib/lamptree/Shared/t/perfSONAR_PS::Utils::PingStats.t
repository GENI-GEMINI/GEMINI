use Test::More tests => 5;
use Data::Compare qw( Compare );
use FreezeThaw qw(cmpStr);
use Log::Log4perl;
 
use_ok('perfSONAR_PS::Utils::PingStats');
use   perfSONAR_PS::Utils::PingStats;
Log::Log4perl->init("./t/logger.conf");

my @rtts = ( '100', '102', '103', '100', '99');
my $sent = 5;
my $recv = 5;

my $obj; 
 # 2 
  eval {
     $obj =  perfSONAR_PS::Utils::PingStats->new( { rtts =>  \@rtts}) 
  };
  ok( $obj, "perfSONAR_PS::Utils::PingStats create object") or diag(@$);
  $@ = undef;

 # 3
 my @rtts = ();
 eval {
    @rtts =  @{$obj->rtt_stats()} 
 };
 ok( $rtts[0]  ==  99 && $rtts[1]  ==  103 && $rtts[2] == 100.8, " correct rtts " ) or diag(@$);
 $@ = undef;  
 
 # 4
 eval {
     @rtts =  @{$obj->ipdv_stats} 
 };
 ok( $rtts[0]  ==  1 && $rtts[1]  ==   3 && $rtts[2] ==  1.75, " correct ipdvs " ) or diag(join " : ", @rtts);
 $@ = undef;  
  
 # 5 
 my $loss; 
 eval {
     $obj->seqs([qw/1 2 3 4 5/]);
     $obj->sent(5);
     $obj->received(4);
     $loss =  $obj->loss()
 }; 
 ok( $loss == 20, " loss 20% " ) or diag(@$ . " loss =  $loss ");
 $@ = undef;  
 

print "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
