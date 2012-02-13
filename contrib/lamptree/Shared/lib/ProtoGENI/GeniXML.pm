#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2010 University of Utah and the Flux Group.
# All rights reserved.
#
package ProtoGENI::GeniXML;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = "Exporter";
@EXPORT = qw(Parse ParseFile FindNodes FindNodesNS FindFirst FindElement FindAttr IsLanNode IsLocalNode GetNodeId GetVirtualId GetManagerId SetText GetText CreateDocument AddElement PolicyExists);

use English;
use XML::LibXML;
use XML::LibXML::XPathContext;
use XML::LibXML::NodeList;
use ProtoGENI::GeniHRN;
use ProtoGENI::GeniUtil;
use Carp qw(cluck carp);

# Configure variables
# Configure variables

# Returns the document element by parsing a given string. If the
# string fails to parse, returns undefined.
sub Parse($)
{
    my ($xml) = @_;
    my $parser = XML::LibXML->new;
    my $doc;
    eval {
        $doc = $parser->parse_string($xml);
    };
    if ($@) {
	carp("Failed to parse xml string: $@\nXML: $xml\n\n");
	return undef;
    } else {
	return $doc->documentElement();
    }
}

sub ParseFile($)
{
    my ($file) = @_;
    my $parser = XML::LibXML->new;
    my $doc;
    eval {
        $doc = $parser->parse_file($file);
    };
    if ($@) {
	carp("Failed to parse xml string: $@");
	return undef;
    } else {
	return $doc->documentElement();
    }
}

# Returns a NodeList for a given XPath using a given node as
# context. 'n' is defined to be the prefix for the namespace of the
# node.
sub FindNodes($$)
{
    my ($path, $node) = @_;
    my $result = undef;
    my $ns = undef;
    eval {
	my $xc = XML::LibXML::XPathContext->new();
	$ns = $node->namespaceURI();
	if (defined($ns)) {
	    $xc->registerNs('n', $ns);
	} else {
	    $path =~ s/\bn://g;
	}
	$result = $xc->findnodes($path, $node);
    };
    if ($@) {
	if (! defined($ns)) {
	    $ns = "undefined";
	}
        cluck "Failed to find nodes using XPath path='$path', ns='$ns': $@\n";
	return XML::LibXML::NodeList->new();
    } else {
	return $result;
    }
}

# Returns a NodeList for a given XPath using a given namespace as
# context. 'n' is defined to be the prefix for the given namespace.
sub FindNodesNS($$$)
{
    my ($path, $node, $nsURI) = @_;
    my $result = undef;
    return XML::LibXML::NodeList->new()
        if (!defined($node));
    eval { 
  my $xc = XML::LibXML::XPathContext->new();
  if (defined($nsURI)) {
      $xc->registerNs('n', $nsURI);
  } else {
      $path =~ s/\bn://g;
  }
  $result = $xc->findnodes($path, $node);
    };
    if ($@) {
  if (! defined($nsURI)) {
      $nsURI = "undefined";
  }
        cluck "Failed to find nodes using XPath path='$path', nsURI='$nsURI': $@\n";        
  return XML::LibXML::NodeList->new();
    } else { 
  return $result;
    } 
}


# Returns the first Node which matches a given XPath against a given
# node. If that node is not of the specified type, returns
# undefined. Works like FindNodes.
sub FindNodeType($$$)
{
    my ($path, $node, $type) = @_;
    my $result = FindNodes($path, $node)->pop();
    if (defined($result) && $result->nodeType() != $type) {
	$result = undef;
    }
    return $result;
}

# Returns the first Node which matches a given XPath.
sub FindFirst($$)
{
    my ($path, $node) = @_;
    return FindNodes($path, $node)->pop();
}

# Returns the first Element which matches a given XPath.
sub FindElement($$)
{
    my ($path, $node) = @_;
    return FindNodeType($path, $node, XML_ELEMENT_NODE);
}

# Returns the first Attribute which matches a given XPath.
sub FindAttr($$)
{
    my ($path, $node) = @_;
    return FindNodeType($path, $node, XML_ATTRIBUTE_NODE);
}

# Returns true if a given XML Node is an RSpec node and is of type lan
sub IsLanNode($)
{
    my ($node) = @_;
    my $result = 0;
    if (defined($node) && $node->localname() eq "node") {
	foreach my $lan (FindNodes("n:node_type", $node)->get_nodelist()) {
	    my $typeName = GetText("type_name", $lan);
	    if (defined($typeName) && $typeName eq "lan") {
		$result = 1;
		last;
	    }
	}
    }
    return $result;
}

# Returns true if a given XML Node is an RSpec node and either has
# the current CM as a 'component_manager_urn' or
# 'component_manager_uuid or no component_manager defined.
sub IsLocalNode($)
{
    my ($node) = @_;
    my $result = 0;
    if (defined($node) && $node->localname() eq "node") {
	my $manager_uuid  = GetManagerId($node);
	if (! defined($manager_uuid) ||
	    ProtoGENI::GeniHRN::Equal($manager_uuid, $ENV{'MYURN'}) ||
	    $manager_uuid eq $ENV{'MYUUID'}) {

	    $result = 1;
	}
    }
    return $result;
}

# Returns the uuid or urn of an RSpec node or undef if it is not a node.
sub GetNodeId($)
{
    my ($node) = @_;
    return GetText("component_uuid", $node) ||
	GetText("component_urn", $node) ||
	GetText("uuid", $node);
}

sub GetVirtualId($)
{
    my ($node) = @_;
    return GetText("virtual_id", $node) ||
	GetText("nickname", $node);
}

sub GetSliverId($)
{
    my ($node) = @_;
    return GetText("sliver_urn", $node);
}

sub GetManagerId($)
{
    my ($node) = @_;
    return GetText("component_manager_uuid", $node) ||
	GetText("component_manager_urn", $node);
}

# Takes an attribute/element name, *NOT AN XPATH* and a node and sets
# the text of that node to a particular value. If the node is an
# attribute, the value is set. If it is an element with just a text
# node child, that node is replaced.
# Returns 1 on success and 0 on failure.
sub SetText($$$)
{
    my ($name, $node, $text) = @_;
    my $result = 0;
    my $child = FindFirst('@n:'.$name, $node);
    if (! defined($child)) {
	$child = FindFirst('@'.$name, $node);
    }
    if (defined($child)) {
	if ($child->nodeType() == XML_ATTRIBUTE_NODE) {
	    $child->setValue($text);
	    $result = 1;
	}
    } else {
	$child = FindFirst('n:'.$name, $node);
	if (defined($child)) {
	    my @grand = $child->childNodes();
	    if (scalar(@grand) == 1
		&& $grand[0]->nodeType() == XML_TEXT_NODE) {
		$grand[0]->setData($text);
		$result = 1;
	    } elsif (scalar(@grand) == 0
		     && $child->nodeType() == XML_ELEMENT_NODE) {
		$child->appendText($text);
		$result = 1;
	    }
	} elsif ($node->nodeType() == XML_ELEMENT_NODE) {
	    my $ns = $node->namespaceURI();
	    if (defined($ns)) {
# TODO: Submit bug report for the library. This call is bugged.
#		$node->setAttributeNS($ns, "rs:$name", $text);
		$node->setAttribute($name, $text);
	    } else {
		$node->setAttribute($name, $text);
	    }
	    $result = 1;
	}
    }
    return $result;
}

# Get the text contents of a child of a node with a particular
# name. This can be either an attribute or an element.
sub GetText($$)
{
    my ($name, $node) = @_;
    my $result = undef;
    my $child = FindFirst('@n:'.$name, $node);
    if (! defined($child)) {
	$child = FindFirst('@'.$name, $node);
    }
    if (! defined($child)) {
	$child = FindFirst('n:'.$name, $node);
    }
    if (defined($child)) {
	$result = $child->textContent();
    }
    return $result;
}

# Converts the XML representation of a node to a UTF-8 string and
# outputs it as a complete XML document.
sub Serialize($)
{
    my ($node) = @_;
    my $newnode = $node->cloneNode(1);
    return $newnode->toString();
}

# Create a new XML document with a given namespace URI and document
# element name.
sub CreateDocument($$)
{
    my ($ns, $name) = @_;
    my $doc = XML::LibXML::Document->createDocument("1.0", "UTF-8");
    my $root = $doc->createElementNS($ns, "rs:$name");
    $doc->setDocumentElement($root);
    return $doc;
}

# Add a new element to a node. The new element will have the given
# name and be otherwise empty.
sub AddElement($$)
{
    my ($name, $node) = @_;
    my $ns = $node->namespaceURI();
    my $child = $node->addNewChild($ns, "rs:$name");
    return $child;
}

# Remove a node with a given name from a node. It will be removed
# whether it is an attribute or an element. The name is not an xpath.
sub RemoveChild($$)
{
    my ($name, $node) = @_;
    my $child = FindFirst('@n:'.$name, $node);
    if (! defined($child)) {
	$child = FindFirst('n:'.$name, $node);
    }
    if (defined($child)) {
	$node->removeChild($child);
    }
}

# checks for the existense of policy in extensions of the given
# credential.
sub PolicyExists($$)
{
    my ($policy, $credential) = @_;
    my $exists = 0;

    return 0
        if (!ref($credential) or !defined($policy));
    my $extensions_elem = $credential->extensions();
    return 0
        if (!defined($extensions_elem));
    my $policies = ProtoGENI::GeniXML::FindNodesNS("//n:policy_exceptions/*",
          $extensions_elem, $ProtoGENI::GeniUtil::EXTENSIONS_NS);
    foreach my $epolicy ($policies->get_nodelist) {
        if ($policy eq $epolicy->string_value) {
            $exists = 1;
            last;
        }      
    }       
  
    return $exists;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
