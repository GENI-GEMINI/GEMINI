#!/bin/env perl

#######################################################################
# handles all transport/communications with perfsonar services
#######################################################################

#use XML::XPath;
use XML::LibXML;
use XML::LibXML::XPathContext;


package utils::xml;
use Log::Log4perl qw(get_logger);
our $logger = Log::Log4perl::get_logger( 'utils::xml');

our $parser = XML::LibXML->new();
our $xpc = XML::LibXML::XPathContext->new();

use URI::Escape;
use strict;


# return something that we can search
sub getRoot {
	my $tree = shift;
	# declare some ns
	
	$xpc->registerNs( 'nmwg', "http://ggf.org/ns/nmwg/base/2.0/" );
	$xpc->registerNs( 'nmwgr', "http://ggf.org/ns/nmwg/result/2.0/" );

	$xpc->registerNs( 'nmwgt', 'http://ggf.org/ns/nmwg/topology/2.0/' );
	$xpc->registerNs( 'nmtl4', "http://ogf.org/schema/network/topology/l4/20070828/" );
	$xpc->registerNs( 'nmtl3', "http://ogf.org/schema/network/topology/l3/20070828/" );
	$xpc->registerNs( 'nmtopo', "http://ogf.org/schema/network/topology/base/20070828/" );
	$xpc->registerNs( 'netutil', 'http://ggf.org/ns/nmwg/characteristic/utilization/2.0/' );
	$xpc->registerNs( 'psservice', "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/" );
	$xpc->registerNs( 'xquery', '"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/' );
	
	# index documents for faster xpath processing
	$tree->indexElements();
	return $tree->getDocumentElement();
}

sub fromString
{
	my $stringRef = shift;
	return &getRoot( $parser->parse_string( $$stringRef ) );
}


sub fromFile
{
	my $file = shift;
	if ( -e $file ) {
		return &getRoot( $parser->parse_file( $file ) );
	} else {
		$logger->fatal( "File '$file' does not exist");
		return undef;
	}
}

sub fromXMLChunk
{
	my $chunk = shift;
	return &getRoot( $parser->parse_xml_chunk( $chunk ) );
}





###
# unescapes text
###
sub unescape
{
	my $text = shift;
	return uri_unescape( $text );
}

sub escape
{
	my $text = shift;
	return uri_escape( $text );
}

1;