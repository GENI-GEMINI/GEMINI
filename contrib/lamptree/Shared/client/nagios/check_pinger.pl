#!/usr/bin/perl

use FindBin qw($RealBin);
use lib "$RealBin/../../lib/";
use Nagios::Plugin;
use Data::Validate::IP qw(is_ipv4 is_ipv6);
use Statistics::Descriptive;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::MA;
use XML::LibXML;

my $np = Nagios::Plugin->new( shortname => 'PS_CHECK_PING',
                              usage => "Usage: %s -u|--url <service-url> -s|source=s <source> -d|destination <destination> -k|rttType<RTT type - minRtt,maxRtt,meanRtt> -f|function <function min,max,mean to analyze RTT> -r|--range <time-interval> -w|--warning <threshold> -c|--critical <threshold> -V|--verbose" );

#get arguments
$np->add_arg(spec => "u|url=s",
             help => "URL of the lookup service to contact",
             required => 1 );
$np->add_arg(spec => "s|source=s",
             help => "Source of the test to check",
             required => 1 );
$np->add_arg(spec => "d|destination=s",
             help => "Destination of the test to check",
             required => 1 );
$np->add_arg(spec => "r|range=i",
             help => "Time range (in minutes) in the past to look at data. i.e. 60 means look at last 60 minutes of data.",
             required => 1 );
$np->add_arg(spec => "k|rttType=s",
             help => "RTT type - min,max,mean",
             required => 0);
$np->add_arg(spec => "f|function=s",
             help => "function to analyze the RTT - min,max,mean",
             required => 0);    
$np->add_arg(spec => "w|warning=s",
             help => "threshold of service count that leads to WARNING status",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of service count that leads to CRITICAL status",
             required => 1 );
$np->add_arg(spec=> "v|verbose",
             help => "allow verbose mode for debugging",
             required => 0); 
$np->getopts;                              


my $ma_url = $np->opts->{'u'};
my $function = $np->opts->{'f'};
my $rttType = $np->opts->{'k'};
my $source = $np->opts->{'s'};
my $destination = $np->opts->{'d'};
my $verbose = $np->opts->{'v'};
if(!defined $rttType){
	$rttType = "minRtt";
}
if(!defined $function){
	$function = "min";
}

if($verbose ne ''){
	print "Input parameters:", $function, " of ", $rttType, " Src:", $source, " Dest:",$destination,"\n";
}


#create client
my $ma = new perfSONAR_PS::Client::MA( { instance => $ma_url } );

#create query
my $subject = "<pinger:subject id=\"subject-48\" xmlns:pinger=\"http://ggf.org/ns/nmwg/tools/pinger/2.0\">\n";
$subject .= "    <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
$subject .= "      <nmwgt:src type=\"" . &get_endpoint_type( $np->opts->{'s'} ) . "\" value=\"" . $np->opts->{'s'} . "\"/>\n";
$subject .= "      <nmwgt:dst type=\"" . &get_endpoint_type( $np->opts->{'d'} ) . "\" value=\"" . $np->opts->{'d'} . "\"/>\n";
$subject .= "    </nmwgt:endPointPair>\n";
$subject .= "</pinger:subject>";

if($verbose ne ''){
	print $subject;	
}


my @eventTypes = ("http://ggf.org/ns/nmwg/tools/pinger/2.0/");
my $end = time;
my $start = $end - $np->opts->{'r'}*60;

#send query
my $result = $ma->setupDataRequest(
        {
            resolution => $end-$start,
            subject => $subject,
            #parameters => { timeType => "unix" },
            eventTypes => \@eventTypes,
            start => $start,
            end => $end,

        }
    ) or $np->nagios_die( "Error contacting MA $ma_url" );

#handle response
my $parser = XML::LibXML->new();
my $doc;
eval{
    $doc = $parser->parse_string(@{$result->{data}});
};
if($@){
    $np->nagios_die( "Error parsing MA response" );
}
my @values;
my $root = $doc->getDocumentElement;
my @childnodes = $root->findnodes("//*[local-name()='datum'][\@name=\"$rttType\"]");
if(scalar @childnodes < 1){
	$np->nagios_die("Could not retrieve data");
}

foreach my $child (@childnodes){
	push(@values,$child->getAttribute("value"));
	
}


#determine output code and message
my $stats = Statistics::Descriptive::Sparse->new();
foreach my $i (@values) {
    $stats->add_data( $i );
}

my $label;
my $value;
my $code;
my $msg = "";
if($function eq "min"){
	$label = 'Min';
	$value = $stats->min();
}elsif($function eq "max"){
	$label = 'Max';
	$value = $stats->max();
}elsif($function eq "average"){
	$label = 'average';
	$value = $stats->average();
}elsif($function eq "std_dev"){
	$label = 'std_dev';
	$value = $stats->standard_deviation();
}
$np->add_perfdata(
        label => $label,
        value => $value,
    );
    
$code = $np->check_threshold(
     check => $value,
     warning => $np->opts->{'w'},
     critical => $np->opts->{'c'},
   );
   
   
if($code eq OK || $code eq WARNING || $code eq CRITICAL){
    $msg = $rttType;
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);


#function to determine host id type - hostname, ipv4, ipv6
sub get_endpoint_type(){
    my $endpoint = shift @_;
    my $type = "hostname";
    
    if( is_ipv4($endpoint) ){
        $type = "ipv4";
    }elsif( is_ipv6($endpoint) ){
        $type = "ipv6";
    }
    
    return $type;
}



