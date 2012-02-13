#!/usr/bin/perl

use FindBin qw($RealBin);
use lib "$RealBin/../../lib/";
use Nagios::Plugin;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::LS;
use XML::LibXML;
use LWP::Simple;


my $np = Nagios::Plugin->new( shortname => 'PS_HLS_COUNT',
                              usage => "Usage: %s -u|--url <HLS-service-url> -t|--type <service-type> -k|--keyword <keyword search> -g|--glsMode <glsURl or \"many\"> -h|--hintsURL<hintsURL> -i|--initialConfig <Config file for service mapping> -w|--warning <threshold> -c|--critical <threshold>" );

#get arguments
$np->add_arg(spec => "u|url=s",
             help => "URL of the lookup service(HLS) to contact. If more than one specify 'many' and use -f option",
             required => 0 );
$np->add_arg(spec => "t|type=s",
             help => "type of service. Specify more than separated by comma. 'all'- all services",
             required => 0);
$np->add_arg(spec => "w|warning=s",
             help => "threshold of service count that leads to WARNING status",
             required => 1 );
$np->add_arg(spec => "c|critical=s",
             help => "threshold of service count that leads to CRITICAL status",
             required => 1 );
$np->add_arg(spec=> "f|hlsurlfile=s",
             help => "list of hls urls to search for services",
             required => 0);
$np->add_arg(spec=> "k|keyword=s",
             help => "keyword to search in hLS",
             required => 0); 
$np->add_arg(spec=> "i|initialConfig=s",
             help => "initial config file path",
             required => 0);
$np->add_arg(spec=> "v|verbose",
             help => "allow verbose mode for debugging",
             required => 0); 
$np->add_arg(spec=> "g|glsMode=s",
             help => "specify gls hints URL",
             required => 0);
$np->add_arg(spec=> "h|hintsURL=s",
             help => "URL of the gls hints file",
             required => 0);    
$np->getopts;

my $hls_url = $np->opts->{'u'};
my $urlfile = $np->opts->{'f'};
my $type = $np->opts->{'t'};
my $keywordsearch = $np->opts->{'k'};
my $configPath = $np->opts->{'i'};
my $verbose = $np->opts->{'v'};
my $glsURL = $np->opts->{'g'};
my $hintsURL = $np->opts->{'h'};
my @serviceslist;
if($type ne "all"){
	@serviceslist = split(',',$type); #need not worry about spaces (it is command line separator)
}

#check for inconsistencies in input
if($glsURL ne '' && $hintsURL ne ''){
	$np->nagios_die("Conflicting options specified for glsmode");
}elsif($hls_url ne '' && $urlfile ne ''){
	$np->nagios_die("Conflicting options specified for hlsmode");
}elsif($glsURL ne '' && ($hls_url ne '' || $urlfile ne '')){
	$np->nagios_die("Conflicting options. Both gls and hls urls have been specified");
}elsif($hintsURL ne '' && ($hls_url ne '' || $urlfile ne '')){
	$np->nagios_die("Conflicting options. Both gls and hls urls have been specified");
}

#find the mode
my $mode;
if($type eq "all" || $type eq ''){
	$mode = "AllServices";
}else{
	$mode = "SpecifiedServices";
}


#read contents of service config file and store mapping
my %serviceMap = ();
if($configPath eq ''){
	if($verbose ne ''){
		print "WARNING!!! Service config file not found - Specify full URIs in type or specify config file path and rerun \n";
	}
}

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
	$serviceMap{$key}= $value;
   }   		
}else {
	if($verbose ne ''){
		print "WARNING!!! Service config file not found - Specify full URIs in type or specify config file path and rerun \n";
	}
}


my $service_count = 0; #used for output
#create a service map to keep track of services found and list of serviceQueries
my %serviceCount = ();
my @serviceQuery = ();
#if($mode eq "AllServices"){	
#	foreach $key(keys %serviceMap){
#		my $value = $serviceMap{$key};
#		push(@serviceQuery,$value);
#	}
#}elsif($mode eq "SpecifiedServices"){
if($mode eq "SpecifiedServices"){
	my $value;
	foreach $key(@serviceslist){
		if ($key =~ m/^http:\/\//){
		if($verbose ne ''){
			print "found service URI"; #for debugging
		}
		$value = $key;
	}else{
		if($configPath eq ''){
			$np->nagios_die("Specify config file for service name mappings. Else use full URLs");
		}
		$value = $serviceMap{$key};
	}
		push(@serviceQuery,$value);
	
	}
}


#if glsMode then find the hlslist using gls and not from the file
#if hlsMode retrieve HLS URL to contact
my @hlsList;

if($glsURL ne '' || $hintsURL ne ''){
	
	@hlsList = contactGLS($glsURL, $hintsURL, $keywordsearch, @serviceQuery);
	
	if($verbose ne ''){
			print "\n GLSmode HLS List: ", @hlsList,"\n";
	 	}
	
}else{
	if($hls_url eq '' && $urlfile ne ''){
	open(FILEHANDLE, $urlfile) || die("Could not open file!");
	while(<FILEHANDLE>){
		chomp;
		$test =$_;
		$test =~ s/^\s+//;
		push(@hlsList, $test);
	}
	#@hlsList = <FILEHANDLE>;
 	close (FILEHANDLE);
 	
	}elsif($hls_url ne ''){
	@hlsList = $hls_url;
	}else{
		if($verbose ne ''){
			print "\n Did not find HLS or GLS URL!!! Please check config file!!\n";
	 	}
	 $np->nagios_die("Did not find HLS or GLS URL!!!");
	}

	if($verbose ne ''){
	print "List of HLS URLS to contact: ", @hlsList, "\n";
	}
}



#Create client - HLS Query
#for loop is used since one or many URLs are stored in the same array
if(@hlsList ne '' && $hlsList[0] ne "None" ){
HLSLIST: foreach $url (@hlsList){
	if($verbose ne ''){
		print "HLS URL: $url";
	}
	
my $client = new perfSONAR_PS::Client::LS(
        {
           	instance => $url
        }
    );
    
# Create XQuery
		my $xquery='';
		$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n";
		$xquery .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
		$xquery .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
		$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata \n";
		$xquery .= "let \$id := \$metadata/\@id \n";
		$xquery .= "let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef =\$id]\n";
		
		if($mode eq "SpecifiedServices" && $keywordsearch eq ''){
			my $serviceType = $serviceQuery[0];
			$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies ((\$eventType=\"$serviceType\")";
			for(my $i=1;$i<@serviceQuery;$i+=1){
					$xquery .= " or (\$eventType=\"$serviceQuery[$i]\") \n";
			}
			$xquery .= ")";
			
		}elsif($mode eq "SpecifiedServices" && $keywordsearch ne ''){
			my $serviceType = $serviceQuery[0];
			$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies ( ((\$eventType=\"$serviceType\")\n";
			for(my $i=1;$i<@serviceQuery;$i+=1){
					$xquery .= " or (\$eventType=\"$serviceQuery[$i]\") \n";
			}
			$xquery .= ") and (\$data/nmwg:metadata/summary:parameters/nmwg:parameter[\@name=\"keyword\"]/\@value=\"project:$keywordsearch\"";
			$xquery .= " or \$data/nmwg:metadata/nmwg:parameters/nmwg:parameter[\@name=\"keyword\"]=\"project:$keywordsearch\")";
			$xquery .= ")";
			
		}elsif($mode eq "AllServices" && $keywordsearch eq ''){
			
		}elsif($mode eq "AllServices" && $keywordsearch ne ''){
			$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies (";
			$xquery .= "\$data/nmwg:metadata/summary:parameters/nmwg:parameter[\@name=\"keyword\"]/\@value=\"project:$keywordsearch\"";
			$xquery .= " or \$data/nmwg:metadata/nmwg:parameters/nmwg:parameter[\@name=\"keyword\"]=\"project:$keywordsearch\"";
			$xquery .= ")";
		}
	
		$xquery .= " return \$metadata";
	
	if($verbose ne ''){
		print $xquery,"\n";
	}

# Send query to Lookup Service
my $result = $client->queryRequestLS(
       {
           query => $xquery,
           format => 1 #want response to be formated as XML
       }
     ) ;

#or $np->nagios_die("Error contacting look up service")
#print $result->{response};

#Handle response
if ($verbose ne ''){
	print $result->{response};
}

if($result && $result->{response} && $result->{response} !~ /\</){
	if($verbose ne ''){
    	print "\n Did not find response";
    	next HLSLIST;
	}
} else {    
    my $parser = XML::LibXML->new();
    my $doc = "";
    my $urlList = ();
    eval{
        $doc = $parser->parse_string($result->{response});
    };
    if($@){
    	next HLSLIST;
        #$np->nagios_die( "Error parsing LS response" )
    }
    
    my $root = $doc->getDocumentElement;
       
    my @childnodes = $root->findnodes(".//*[local-name()='accessPoint']");
    my @tmpchildnodes = $root->findnodes(".//*[local-name()='address']");
    if(!defined @childnodes && !defined @tmpchildnodes){
        #$np->nagios_die( "Error extracting services from LS response" )
        next HLSLIST;
    }
    
    push(@childnodes, @tmpchildnodes);
 
 #set true in serviceCount hashmap if service is found  
 if($verbose ne ''){
 	 print "Service URL: " ;
 }

    foreach $child(@childnodes){
    	my $data = $child->textContent;
    	if($verbose ne ''){
    		print "$data\n";
    	}
    	if (!$serviceCount{$data}){
    		$serviceCount{$data} = "true";
    	}
    }
}
}

# count number of services found 
    foreach $key(keys %serviceCount){
    	if($serviceCount{$key} eq "true"){
    		$service_count += 1;
    	}
    }
}
my $serviceQueryCount = scalar @serviceQuery;
#add service count to output
$np->add_perfdata(
        'label' => 'count',
        'value' => $service_count
    );
# check thresholds
my $code = $np->check_threshold(
     check => $service_count,
     warning => $np->opts->{'w'},
     critical => $np->opts->{'c'},
   );
if($code eq OK){
    $msg = "Services found";
}elsif ($code eq WARNING || $code eq CRITICAL){
    $msg = "Services missing";
}else{
    $msg = "Error analyzing results";
}
$np->nagios_exit($code, $msg);



#GLS function that returns list of HLS
sub contactGLS(){
	my @service_desc;
	
	my($glsURL, $hintsURL, $keywordsearch, @serviceQuery) = @_;
	
	if($verbose ne ''){
			print "contactGLS: Input params:",$glsURL, $hintsURL, $keywordsearch, @serviceQuery,"\n";
		}
	my @glsList;
	if($glsURL eq ''){
		if($hintsurl eq ''){
 			$hintsurl = "http://www.perfsonar.net/gls.root.hints";
		}

	#retrieve gls URLs
		unless (defined($content = get $hintsurl)){
       	 	die "could not get $hintsurl \n";
		}

		@glsList = split("\n", $content);
	#for debugging
		if($verbose ne ''){
			print "contactGLS: GLS List:", @glsList;
		}

	}else{
			@glsList[0] = $glsURL;
	}
	
	#GLSLIST block begins
	GLSLIST: foreach $linkurl (@glsList){

		if($verbose ne ''){
			print "\ncontactGLS: GLS URL: ", $linkurl,"\n"; 
		}

		#Create client
		my $client = new perfSONAR_PS::Client::LS(
        	{
            	instance => $linkurl
        	}
    	);
    
		# Create XQuery
		my $xquery='';
		$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n";
		$xquery .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
		$xquery .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
		$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata \n";
		$xquery .= "let \$id := \$metadata/\@id \n";
		$xquery .= "let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef =\$id]\n";
		
		if($mode eq "SpecifiedServices" && $keywordsearch eq ''){
			my $serviceType = $serviceQuery[0];
			$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies ((\$eventType=\"$serviceType\")";
			for(my $i=1;$i<@serviceQuery;$i+=1){
					$xquery .= " or (\$eventType=\"$serviceQuery[$i]\") \n";
			}
			$xquery .= ")";
			
		}elsif($mode eq "SpecifiedServices" && $keywordsearch ne ''){
			my $serviceType = $serviceQuery[0];
			$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies ( ((\$eventType=\"$serviceType\")\n";
			for(my $i=1;$i<@serviceQuery;$i+=1){
					$xquery .= " or (\$eventType=\"$serviceQuery[$i]\") \n";
			}
			$xquery .= ") and (\$data/nmwg:metadata/summary:parameters/nmwg:parameter[\@name=\"keyword\"]/\@value=\"project:$keywordsearch\"";
			$xquery .= " or \$data/nmwg:metadata/nmwg:parameters/nmwg:parameter[\@name=\"keyword\"]=\"project:$keywordsearch\")";
			$xquery .= ")";
			
		}elsif($mode eq "AllServices" && $keywordsearch eq ''){
			
		}elsif($mode eq "AllServices" && $keywordsearch ne ''){
			$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies (";
			$xquery .= "\$data/nmwg:metadata/summary:parameters/nmwg:parameter[\@name=\"keyword\"]/\@value=\"project:$keywordsearch\"";
			$xquery .= " or \$data/nmwg:metadata/nmwg:parameters/nmwg:parameter[\@name=\"keyword\"]=\"project:$keywordsearch\"";
			$xquery .= ")";
		}
	
		$xquery .= " return \$metadata";
		
		#for debugging
		 if($verbose ne ''){
			print "\ncontactGLS: GLSmode XQuery: ", $xquery,"\n";
	 	}
	 
	 my $result = $client->queryRequestLS(
         {
            query => $xquery,
            format => 1 #want response to be formated as XML
        }
      ) ;
      
      #or $np->nagios_die( "Error contacting lookup service" )
      
      #Handle response
      if($verbose ne ''){
      	print "GLSMODE Response: $result->{response}";
      }
	if($result && $result->{response} && $result->{response} !~ /\</){
    	#$service_count = 0; 
    	push(@service_desc, "None");
    	next GLSLIST;
	} else {    
    	my $parser = XML::LibXML->new();
    	my $doc = "";
    	my $urlList = ();
    	eval{
        	$doc = $parser->parse_string($result->{response});
    	};
    	
    	if($@){
        	$np->nagios_die( "Error parsing LS response" )
   		}
    
    	my $root = $doc->getDocumentElement;
        
   	    my @childnodes = $root->findnodes("./*[local-name()='accessPoint']");
    	if(!defined @childnodes){
        	$np->nagios_die( "Error extracting services from LS response" )
    	}
    	
    	foreach $child(@childnodes){
    	my $data = $child->textContent;
    	push(@service_desc, $data);
    	}
    
    	
    	
    	last GLSLIST;
	}
      
	}#GLSLIST ends
	
	if($verbose ne ''){
    		print "\n contactGLS: List of URLS from response: \n";
    		print @service_desc, "\n";
    		print  scalar @service_desc, "\n";   			
    	}
	return @service_desc;
	
}
