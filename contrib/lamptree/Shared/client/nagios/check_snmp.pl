#!/usr/bin/perl
use strict;

use FindBin qw($RealBin);
use lib "$RealBin/../../lib/";
use Nagios::Plugin;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::MA;
use XML::LibXML;
use LWP::Simple;

my $np = Nagios::Plugin->new( shortname => 'check_snmp',
                              usage => "Usage: %s   -u|--url <pinger-MA-URL> -i|--interface<interface-address> -t|--timeInterval<time-interval-in-minutes> -d|--direction<traffic-direction> -w|--warning <warning-threshold> -c|--critical <critical-threshold> -v|--verbose" );

#get arguments 
$np->add_arg(spec=> "u|url=s",
             help => "URL of the snmp MA to contact",
             required => 1);
 
 $np->add_arg(spec=> "d|direction=s",
             help => "traffic direction - in(inbound) or out(outbound)",
             required => 1);
             
$np->add_arg(spec=> "i|interface=s",
             help => "interface address of the required measurement statistics",
             required => 1);
             
$np->add_arg(spec=> "t|timeInterval=i",
             help => "time interval in minutes for the measurement statistics",
             required => 1);
                               
$np->add_arg(spec=> "w|warning=s",
             help => "average utilization threshold to show warning state",
             required => 1);
            
$np->add_arg(spec=> "c|critical=s",
             help => "average utilization threshold to show critical state",
             required => 1); 
             
$np->add_arg(spec=> "v|verbose",
             help => "allow verbose mode for debugging",
             required => 0); 

$np->getopts;

my $snmpURL = $np->opts->{'u'};
my $interface =$np->opts->{'i'};
my $interval =$np->opts->{'t'};
my $wThresh = $np->opts->{'w'};
my $cThresh = $np->opts->{'c'};
my $verbose = $np->opts->{'v'};
my $direction = $np->opts->{'d'};

# Create client
my $ma = new perfSONAR_PS::Client::MA( { instance => $snmpURL } );

# Set subject
my $subject = "<netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0\" id=\"s\">\n";
$subject .= "    <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
$subject .= "       <nmwgt:ifAddress type=\"ipv4\">$interface</nmwgt:ifAddress>\n";
$subject .= "       <nmwgt:direction>$direction</nmwgt:direction>\n";
$subject .= "    </nmwgt:interface>";
$subject .= "</netutil:subject>\n";

#Set event type
my @eventTypes = ("http://ggf.org/ns/nmwg/characteristic/utilization/2.0");

# Set time range
my $range = $interval*60;
my $end = time;
my $start = $end - $range; #1min = 60s
my $cFunction = "AVERAGE";
# Send request        
my $result = $ma->setupDataRequest(
        {
            subject    => $subject,
            eventTypes => \@eventTypes,
            start => $start,
            end  => $end,
            resolution => $range,
            consolidationFunction => $cFunction
            
            
        }
    );
#Print request parameters
if($verbose ne ''){
	print "Request parameters: \n";
	print "Subject:", $subject,"\n eventTypes: ", @eventTypes,"\n Start time: ", $start, "\n End time: ", $end;
	print "Resolution:",$range,",\n cFunction: ", $cFunction; 
}
#used in output   
my $averageValue;
my $code;

#Output XML
my $parser = XML::LibXML->new();

foreach my $data(@{$result->{"data"}}){
	my $doc = $parser->parse_string($data);
	my $root = $doc->getDocumentElement();
	
	my @childnodes = $root->findnodes(".//*[local-name()='datum']");
	my $units = $childnodes[0]->getAttribute("valueUnits");
	$averageValue= $childnodes[0]->getAttribute("value");
	if($verbose ne ''){
		print "\n\nResult: Average utilization: ", $averageValue,"$units\n";
	}	
}

if($averageValue ne ''){

$code = $np->check_threshold(
     check => $averageValue,
     warning => $np->opts->{'w'},
     critical => $np->opts->{'c'},
   );
   
}else{
	$averageValue = "ERROR";
}
 
 
$np->add_perfdata(
        'label' => 'Utilization',
        'value' => $averageValue
    );
    
$np->add_perfdata(
        'label' => 'Direction',
        'value' => $direction
    );  

#determine status
my $msg; 
if($code eq OK){
	$code = OK;
	$msg = "Avg Util is normal";
    
}elsif ($code eq WARNING){
    $msg = "Avg Util is slightly beyond normal levels";
}elsif ($code eq CRITICAL){
    $msg = "Avg Util has crossed threshold!!!";
}else{
	$msg = "Error analyzing results";
}

$np->nagios_exit($code, $msg);

