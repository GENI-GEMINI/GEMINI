#!/usr/local/bin/perl -w
use lib qw(../lib);
use strict;
use warnings;
use perfSONAR_PS::Client::PingER;
use Data::Dumper;
use Getopt::Long;
use POSIX qw(strftime);

use  Log::Log4perl  qw(:easy);

my $debug;
my $url = 'http://localhost:8075/perfSONAR_PS/services/pinger/ma';
my $help;
my $data;
my $ok = GetOptions (
                'debug|d'         => \$debug,       
                'url=s'    => \$url,
		'data' => \$data,
                'help|?|h'          => \$help,
        );
if(!$ok || !$url  || $help) {
   print " $0: sends an  XML request over SOAP to the pinger MA and prints response \n";
   print " $0   [--url=<pinger_MA_url, default is localhost> --debug|-d ] \n";
   exit 0;
}
my $level = $INFO;

if ($debug) {
        $level = $DEBUG;    
}

Log::Log4perl->easy_init($level);
my $logger = get_logger("pinger_client");
  
my $ma = new perfSONAR_PS::Client::PingER( { instance => $url } );

my $result = $ma->metadataKeyRequest();

my  $metaids = $ma->getMetaData($result);

my   $time_start =	time() -  1800;
my   $time_end   =	time();
my $ptime = sub {strftime " %Y-%m-%d %H:%M", localtime(shift)};
my %keys =();
foreach  my $meta  (keys %{$metaids}) {
    print "Metadata: src=$metaids->{$meta}{src_name} dst=$metaids->{$meta}{dst_name}  packetSize=$metaids->{$meta}{packetSize}\nMetadata Key(s):";
    map { print " $_ :"} @{$metaids->{$meta}{keys}};
    print "\n";    
    map {$keys{$_}++} @{$metaids->{$meta}{keys}};
}
if($data && %keys) {
   $ma = new perfSONAR_PS::Client::PingER( { instance => $url } );

   my $dresult = $ma->setupDataRequest( { 
	     start => $time_start, 
	     end =>   $time_end,  
	     keys =>  [keys %keys],
   	     cf => 'AVERAGE',
   	     resolution => 5,
    }); 
    
    my $data_md = $ma->getData($dresult);
    foreach my $key_id  (keys %{$data_md }) {
         print "\n---- Key: $key_id \n";
   	foreach my $id ( keys %{$data_md->{$key_id}{data}}) {
   	    foreach my $timev	(sort {$a <=> $b} keys %{$data_md->{$key_id}{data}{$id}}) {
   		  print "Data: tm=" . $ptime->($timev) . " datums: ";
   		  map { print "$_ = $data_md->{$key_id}{data}{$id}{$timev}{$_} "} keys %{$data_md->{$key_id}{data}{$id}{$timev}};
   	   }  
      
   	} 
     } 
}
 
__END__
