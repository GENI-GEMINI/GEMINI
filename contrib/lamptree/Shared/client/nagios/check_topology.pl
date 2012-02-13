#!/usr/bin/perl

use FindBin qw($RealBin);
use lib "$RealBin/../../lib/";
use Nagios::Plugin;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::Topology;
use XML::LibXML;
use LWP::Simple;

my $np = Nagios::Plugin->new( shortname => 'check_topology',
                              usage => "Usage: %s -v|--verbose -d|--domainName<domain-name> -u|--url <topology-service-URL> -i|--initialconfig<initial config file> -w|--warning <warning-threshold> -c|--critical <critical-threshold> -n|--namespace <namespace>" );

#get arguments
$np->add_arg(spec=> "u|url=s",
             help => "URL of the gls hints file",
             required => 1);
             
$np->add_arg(spec=> "d|domainName=s",
             help => "URL of the hls to find in gls",
             required => 1);
                               
$np->add_arg(spec=> "w|warning=s",
             help => "threshold to show warning state",
             required => 1);
            
$np->add_arg(spec=> "c|critical=s",
             help => "threshold to show critical state",
             required => 1); 
             
$np->add_arg(spec=> "n|namespace=s",
             help => "namespace used for specifying topology",
             required => 1); 
             
$np->add_arg(spec=> "v|verbose",
             help => "allow verbose mode for debugging",
             required => 0); 
             
$np->add_arg(spec=> "i|initialConfig=s",
             help => "initialConfig  file",
             required => 0); 

$np->getopts;


my $topologyURL = $np->opts->{'u'};
my $domainName =$np->opts->{'d'};
my $wThresh = $np->opts->{'w'};
my $cThresh = $np->opts->{'c'};
my $verbose = $np->opts->{'v'};
my $namespace = $np->opts->{'n'};
my $configPath = $np->opts->{'i'};


#read contents of service config file and store mapping
my %namespaceMap = ();

if(open(FILEHANDLE, $configPath)){
	my @lines = <FILEHANDLE>;
	close (FILEHANDLE);
	foreach $line (@lines){	
	(my $key, my $value) = split('=>', $line);
	#removing white spaces
	$key =~ s/^\s+//; # removes leading white space
	$key =~ s/\s+$//; #removes trailing white space
	$value =~ s/^\s+//;
	$value =~ s/\s+$//; 
	$namespaceMap{$key}= $value;
   }   		
}else {
	if($verbose ne ''){
		print "WARNING!!! Namespace config file not found - Specify full URIs in type or specify config file path and rerun \n";
	}
}

#Get the namespace from the mapping
if ($namespace =~ m/^http:\/\//){
		if($verbose ne ''){
		print "found service URI"; #for debugging
		}
	}else{
		if($configPath eq ''){
			$np->nagios_die("Specify config file for service name mappings. Else use full URLs");
		}
		my $key = $namespace;
		$namespace = $namespaceMap{$key};
		if($verbose ne ''){
			if($namespace eq ''){
				print "\nnamespace not found in config file!! Check config file or enter the full namespace in command line option"; #for debugging
			}
			
		}
	}

#Create client
my $client = new perfSONAR_PS::Client::Topology($topologyURL);
    
#Create XQuery
my $xquery = '';

		$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "declare namespace topology=\"http://ogf.org/schema/network/topology/base/20070828/\";\n";
		$xquery .= "declare namespace namespace=\"$namespace\";\n";
		$xquery .= "for \$node in //namespace:domain[\@id=\"urn:ogf:network:domain=$domainName\"]/namespace:node\n";
		$xquery .= "    return \$node";


if($verbose ne ''){
		print "XQuery is:\n", $xquery, "\n";
}


#output variables
my $nodecount; 
my $code;

#send query and receive response
my $responsecode, $request, $result;
my($responsecode, $request) = $client->buildQueryRequest($xquery);
my($responsecode, $result) = $client->xQuery($xquery);


#Handle response
if($responsecode != -1){
	my $parser = XML::LibXML->new();
	my $doc = "";
	eval{
        $doc = $parser->parse_string($result);
    };
	my $root = $doc->getDocumentElement;
	my @childnodes = $root->findnodes(".//*[local-name()='node']");

	$nodecount = scalar @childnodes;
	if($verbose ne ''){
		print "Number of nodes: ",$nodecount,"\n";
		print "Nodes are:\n";
		for $child (@childnodes){
			print $child->getAttribute('id'),"\n";
		}	
	}
	
	# check thresholds
	$code = $np->check_threshold(
     	check => $nodecount,
     	warning => $np->opts->{'w'},
     	critical => $np->opts->{'c'},
   	);
   	 
}


#determine output status   
if($code eq OK){
    $msg = "Nodes found";
}elsif ($code eq WARNING || $code eq CRITICAL){
    $msg = "Nodes missing";
}else{
    $msg = "Error analyzing results";
    $nodecount = "ERROR"
}

#add service count to output
$np->add_perfdata(
        'label' => 'count',
        'value' => $nodecount
	);
$np->nagios_exit($code, $msg);




