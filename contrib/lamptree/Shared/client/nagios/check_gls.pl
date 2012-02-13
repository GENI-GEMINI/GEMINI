#!/usr/bin/perl

use FindBin qw($RealBin);
use lib "$RealBin/../../lib/";
use Nagios::Plugin;
use perfSONAR_PS::Common qw( find findvalue );
use perfSONAR_PS::Client::LS;
use XML::LibXML;
use LWP::Simple;


my $np = Nagios::Plugin->new( shortname => 'check_gls',
                              usage => "Usage: %s -v|--verbose -h|--hintsURL <gls-hints-URL> -u|--url <serviceglsURL> -f|--hlsurlfile <hls url file> -k|--keyword <keyword search> -t|--type <type of service> -w|--warning <warning-threshold> -c|--critical <critical-threshold> -i|--initialConfig <config-file path>" );

#get arguments
$np->add_arg(spec=> "h|hintsURL=s",
             help => "URL of the gls hints file",
             required => 0);
             
$np->add_arg(spec=> "u|url=s",
             help => "URL of the gLS to contact",
             required => 0);
             
$np->add_arg(spec=> "k|keyword=s",
             help => "keyword to search in gLS",
             required => 0); 
             
$np->add_arg(spec=> "f|hlsurlfile=s",
             help => "hls urls to search in gls",
             required => 0); 
         
$np->add_arg(spec=> "t|typeofservice=s",
             help => "type of service to search in gLS",
             required => 0);   
                         
$np->add_arg(spec=> "w|warning=s",
             help => "threshold to show warning state",
             required => 1);
            
$np->add_arg(spec=> "c|critical=s",
             help => "threshold to show critical state",
             required => 1); 

$np->add_arg(spec=> "i|initialConfig=s",
             help => "initial config file path",
             required => 0);  
             
$np->add_arg(spec=> "v|verbose",
             help => "allow verbose mode for debugging",
             required => 0); 

$np->getopts;

my $configPath = $np->opts->{'i'};                                                        
my $hintsurl = $np->opts->{'h'};
my $keywordsearch = $np->opts->{'k'};
my $serviceglsURL = $np->opts->{'u'};
my $hlsurlfile = $np->opts->{'f'};
my $wThresh = $np->opts->{'w'};
my $cThresh = $np->opts->{'c'};
my $serviceType =$np->opts->{'t'};
my $verbose = $np->opts->{'v'};

my %serviceMap =();
#read contents of service config file and store mapping

if(open(FILEHANDLE, $configPath)){
	my @lines = <FILEHANDLE>;
	#print @lines;
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



my $mode;
#determine the mode - URL, keyword or type search
if($hlsurlfile eq '' && $keywordsearch eq '' && $serviceType eq ''){
	$mode = "searchEntireGLS";
}elsif($hlsurlfile ne ''){ #if hlsurl file is specified the other two search types are ignored
	$mode = "checkHLSReg";
}elsif($keywordsearch ne '' && $serviceType ne ''){
	$mode = "keywordTypeSearch";
}elsif($keywordsearch ne ''){
	$mode = "keywordSearch";
}elsif($serviceType ne ''){
	$mode  ="typeSearch";	
}else{
	$mode = "Invalid";
}

#get the service type mapping
if ($mode eq "typeSearch" || $mode eq "keywordTypeSearch"){
	if ($serviceType =~ m/^http:\/\//){
		if($verbose ne ''){
		print "found service URI"; #for debugging
		}
	}else {
		if($configPath eq ''){
			$np->nagios_die("Specify config file for service name mappings. Else use full URLs");
		}
		my $tmpType = $serviceMap{$serviceType};
		if($tmpType ne ''){
			$serviceType = $tmpType;
		}else{
			#for debugging
			if($verbose ne ''){
			print "WARNING!!!!service Mapping not found! Results may not be found!!Enter entire URI or include service in config file and rerun \n"
			}		
			}
	}
	
}


#get the glsList of URLs to contact. If specified then only 1 URL else retrieved from hints file
my @glsList;
if($serviceglsURL eq ''){
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
		print @glsList;
	}

}else{
		@glsList[0] = $serviceglsURL;
}



my $service_count;
my $service_desc;

#retrieve hls URLs to search in gls, if hlsURLfile is specified
my @hlsList;
if($hlsurlfile ne ''){
	open(FILEHANDLE, $hlsurlfile) || die("Could not open file!");
	while(<FILEHANDLE>){
		chomp;
		$test =$_;
		$test =~ s/^\s+//;
		push(@hlsList, $test);
	}
	#@hlsList = <FILEHANDLE>;
 	close (FILEHANDLE);
 	
}


#GLSLIST block begins
GLSLIST: foreach $linkurl (@glsList){

if($verbose ne ''){
print "\n GLS URL: ", $linkurl,"\n"; 
}

	#Create client
	my $client = new perfSONAR_PS::Client::LS(
        {
            instance => $linkurl
        }
    );
    
	# Create XQuery
	my $xquery='';
	#only serviceURL is given
	if($verbose ne ''){
	print "\n mode: $mode\n"; #for debugging
	}
	if ($mode eq "searchEntireGLS"){
    	$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
		$xquery .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
		$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata\n";
		$xquery .= "    return \$metadata/perfsonar:subject/psservice:service/psservice:accessPoint";
	
	
	}elsif($mode eq "checkHLSReg"){	
		my $serviceURL = @hlsList[0];	
		
		$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
		$xquery .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
		$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata\n";
		$xquery .="     where \$metadata/perfsonar:subject/psservice:service/psservice:accessPoint=\"$serviceURL\"\n";
		
		for (my $i=1; $i<@hlsList;$i+=1){
			$serviceURL = @hlsList[$i];
			$xquery .="		or \$metadata/perfsonar:subject/psservice:service/psservice:accessPoint=\"$serviceURL\"\n";
		}
		$xquery .= "    return \$metadata/perfsonar:subject/psservice:service/psservice:accessPoint";
	
	
	}elsif($mode eq "keywordSearch"){	
		$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
		$xquery .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
		$xquery .= "declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n";
		$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata \n";
		$xquery .= "let \$id := \$metadata/\@id \n";
		$xquery .= "let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef =\$id]\"\n";
		$xquery .= "where \$data/nmwg:metadata/summary:parameters/nmwg:parameter[\@name=\"keyword\"]/\@value=\"project:$keywordsearch\"\n";
		$xquery .= " or \$data/nmwg:metadata/nmwg:parameters/nmwg:parameter[\@name=\"keyword\"]=\"project:$keywordsearch\"";
		$xquery .= "    return \$metadata/perfsonar:subject/psservice:service/psservice:accessPoint";	
	
	
	}elsif($mode eq "typeSearch"){
		$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata \n";
		$xquery .= "let \$id := \$metadata/\@id \n";
		$xquery .= "let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef =\$id]\n";
		$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies (\$eventType=\"$serviceType\")\n";
		$xquery .= "   return \$metadata/perfsonar:subject/psservice:service/psservice:accessPoint";
	
	
	 }elsif($mode eq "keywordTypeSearch"){
		$xquery = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
		$xquery .= "declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n";
		$xquery .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
		$xquery .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
		$xquery .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata \n";
		$xquery .= "let \$id := \$metadata/\@id \n";
		$xquery .= "let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef =\$id]\n";
		$xquery .= "where some \$eventType in \$data/nmwg:metadata/nmwg:eventType satisfies (\$eventType=\"$serviceType\"\n";
		$xquery .= "and (\$data/nmwg:metadata/summary:parameters/nmwg:parameter[\@name=\"keyword\"]/\@value=\"project:$keywordsearch\" \n";
		$xquery .= " or \$data/nmwg:metadata/nmwg:parameters/nmwg:parameter[\@name=\"keyword\"]=\"project:$keywordsearch\"))";
		$xquery .= "    return \$metadata/perfsonar:subject/psservice:service/psservice:accessPoint";
       
     
        	 
	 }
	 
	 #for debugging
	 if($verbose ne ''){
		print $xquery,"\n";
	 }
	
	
	my $result = $client->queryRequestLS(
         {
            query => $xquery,
            format => 1 #want response to be formated as XML
        }
      ) or $np->nagios_die( "Error contacting lookup service" );
      
       
	#Handle response
	if($result && $result->{response} && $result->{response} !~ /\</){
    	$service_count = 0; 
    	$service_desc = "None";
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
    
    	my $urlList = find($doc->getDocumentElement, "./*[local-name()='accessPoint']", 0);
    	if(!defined $urlList){
    	    $np->nagios_die( "Error extracting services from LS response" )
    	}
    
    	$service_count = $urlList->size;
    	$service_desc = $urlList;
    	
    	if($verbose ne ''){
    		print "\n List of URLS: \n";
    		print $urlList, "\n";   			
    	}
    	last GLSLIST;
	}
} #GLSLIST ends

#add service count to output
$np->add_perfdata(
        'label' => 'HLS_COUNT',
        'value' => $service_count
    );
    

# check thresholds and set return values
my $code = $np->check_threshold(
     check => $service_count,
     warning => $wThresh,
     critical => $cThresh,
   );
if($code eq OK){
    $msg = "HLS found";
}elsif ($code eq WARNING || $code eq CRITICAL){
    $msg = "HLS missing";
}else{
    $msg = "Error analyzing results";
}

#exit the module with appropriate return values
$np->nagios_exit($code, $msg);
