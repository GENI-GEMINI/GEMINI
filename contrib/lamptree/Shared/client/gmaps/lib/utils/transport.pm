#!/bin/env perl

#######################################################################
# handles all transport/communications with perfsonar services
#######################################################################

use perfSONAR_PS::Transport;
use perfSONAR_PS::Common;

use utils::xml;

package utils::transport;
use Log::Log4perl qw(get_logger);
our $logger = Log::Log4perl::get_logger( 'utils::transport');

use Error qw(:try);

use strict;



sub get
{
	my $host = shift;
	my $port = shift;
	my $endpoint = shift;
	
	my $request = shift; # xml file or string
	my $filter = shift;	# xpath

	my $unescapeResponse = shift;

	if ( $filter eq '' ) {
		$filter = '/';
	}

	# start a transport agent
	my $sender = perfSONAR_PS::Transport->new();
	$sender->setContactHost( $host );
	$sender->setContactPort( $port );
	$sender->setContactEndPoint( $endpoint );

	# get the xml
	my $xml = undef;
	if ( ! defined $request or $request eq '' ) {
		$logger->logdie( "File '$request' does not exist");
	}
 
	# read from file name or straigh from string
	if ( -e $request ) {
		$request = &perfSONAR_PS::Common::readXML( $request );
	} else {
		# set string directly
	} 
	
	# Make a SOAP envelope, use the XML file as the body.
	my $envelope = perfSONAR_PS::Common::makeEnvelope($request);
	
	$logger->debug( "Sending: $envelope...");
	
	# Send/receive to the server, store the response for later processing
	my $response = undef;

	# need to chance the parent modules into Error	
	eval {
		$response = $sender->sendReceive($envelope);
	};

	if ( ! defined $response or $response eq '' ) {
		
		$logger->logdie( "No response from remote service at '" . perfSONAR_PS::Transport::getHttpURI( $host, $port, $endpoint ) . "'\n" );

	};
	
	
	# escape
	if ( $unescapeResponse ) {
		$response =~ s/\&lt\;/\</g;
		$response =~ s/\&gt\;/\>/g;
		$response =~ s/\&quot\;/\"/g;
	}

	$logger->debug( "Recvd: $response...");

	# usie the xpath statement if necessary
   	my $root = utils::xml::fromString( \$response );

	# check for errors
	my $nodelist = ${utils::xml::xpc}->find( '//nmwg:metadata[child::nmwg:eventType]', $root );
	foreach my $node ( $nodelist->get_nodelist ) {
		my $id = $node->getAttribute( 'id' );
		foreach my $child ( $node->childNodes() ) {		
			#$logger->fatal( " $metadataIdRef -> " . $child->localname() );
			
			# found an error, report it
			if ( $child->localname() eq 'eventType' 
					&& $child->textContent =~ /^error/ ) {
				
				# get the text from the id
				my $err = ${utils::xml::xpc}->find( "//nmwg:data[\@metadataIdRef='$id']/nmwgr:datum" , $root );
				die( "Remote error encountered to '" . perfSONAR_PS::Transport::getHttpURI( $host, $port, $endpoint )  . "': type '" . $child->textContent . "' - $err\n" );			
			}
		}
	}
	
	$logger->debug( "Applying xpath '$filter' on $root:\n" . $root->toString() );
	if ( ! defined $filter ) {
		$filter = '/';	
	}
	my $nodelist = ${utils::xml::xpc}->find( $filter, $root );

	# no point if tehre is nothign there...
	$logger->debug( "Found (" . $nodelist->size() . "): ");
	if ( scalar $nodelist->size() == 0 ) {
		$logger->logdie( "No data found with filter '$filter' on xml:\n" . $root->toString() );
	}

	#foreach my $node ( $nodelist->get_nodelist  ) {
	#	$logger->debug( "-->" . $node->toString() );
	#}

		
	return ( $nodelist->get_nodelist() );
}


sub getArray
{
	my $host = shift;
	my $port = shift;
	my $endpoint = shift;
	
	my $request = shift; # xml file
	my $filter = shift;	# xpath
		
	my @nodes = &get( $host, $port, $endpoint, $request, $filter );
	
	# For now, print out the result message
	my @out = undef;
    foreach my $node (@nodes ) {
    	$logger->debug( "Looking at '$node'" );
        push @out, $node;
    }
    
    return \@out;
}

sub getString
{
	my $host = shift;
	my $port = shift;
	my $endpoint = shift;
	
	my $request = shift; # xml file
	my $filter = shift;	# xpath
		
	my $array = &getArray( $host, $port, $endpoint, $request, $filter );

	$logger->debug( "Found '@$array'");
	return "@$array";
}


1;
