#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2009-2010 University of Utah and the Flux Group.
# All rights reserved.
#
package GeniHRN;

use strict;
use Exporter;
use Carp;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# References:
#
#   GMOC Proposal: "Use URN as GENI identifiers" version 0.2, Viecco, 2009
#   RFC 2141, "URN Syntax", Moats, 1997
#   RFC 3151, "A URN Namespace for Public Identifiers", Walsh, 2001
#   RFC 3986, "URI Generic Syntax", Berners-Lee, 2005
#   RFC 3987, "Internationalised Resource Identifiers", Duerst, 2005
#   RFC 4343, "DNS Case Insensitivity Clarification", Eastlake, 2006

sub Unescape($)
{
    my ($uri) = @_;

    my $norm = "";
    while( $uri =~ /^([^%]*)%([0-9A-Fa-f]{2})(.*)$/ ) {
	$norm .= $1;
	my $val = hex( $2 );
	# Transform %-encoded sequences back to unreserved characters
	# where possible (see RFC 3986, section 2.3).
	if( $val == 0x2D || $val == 0x2E ||
	    ( $val >= 0x30 && $val <= 0x39 ) ||
	    ( $val >= 0x41 && $val <= 0x5A ) ||
	    $val == 0x5F ||
	    ( $val >= 0x61 && $val <= 0x7A ) ||
	    $val == 0x7E ) {
	    $norm .= chr( $val );
	} else {
	    $norm .= "%" . $2;
	}
	$uri = $3;
    }
    $norm .= $uri;

    return $norm;
}

sub IsValid($)
{
    my ($hrn) = @_;

    if (!defined($hrn)) {
	carp("GeniHRN::IsValid: hrn is undefined");
	return 0;
    }

    # Reject %00 sequences (see RFC 3986, section 7.3).
    return undef if $hrn =~ /%00/;

    # We accept ANY other %-encoded octet (following RFC 3987, section 5.3.2.3
    # in favour of RFC 2141, section 5, which specifies the opposite).
    $hrn = Unescape( $hrn );

    # The "urn" prefix is case-insensitive (see RFC 2141, section 2).
    # The "publicid" NID is case-insensitive (see RFC 2141, section 3).
    # The "IDN" specified by Viecco is believed to be case-sensitive (no
    #   authoritative reference known).
    # We regard Viecco's optional resource-type specifier as being
    #   mandatory: partly to avoid ambiguity between resource type
    #   namespaces, and partly to avoid ambiguity between a resource-type
    #   and a resource-name containing (escaped) whitespace.
    return $hrn =~ m'^[uU][rR][nN]:[pP][uU][bB][lL][iI][cC][iI][dD]:IDN\+[A-Za-z0-9.-]+(?::[A-Za-z0-9.-]+)*\+\w+\+(?:[-!$()*,./0-9:=@A-Z_a-z]|(?:%[0-9A-Fa-f][0-9A-Fa-f]))+$';
}

# Perform RFC 3151 transcription (from a string of legal public identifier
# characters to a URN (sub)string).
sub Transcribe($)
{
    my ($str) = @_;

    # Perform whitespace normalisation (see RFC 3151, section 1.1).
    $str =~ s/^[ \t\r\n]*//;
    $str =~ s/[ \t\r\n]*$//;
    # The replacement with a space is arbitrary and temporary; the space
    # will later be replaced with a '+' below (we can't directly use a '+'
    # yet, because we want to treat literal '+'s in the input differently).
    $str =~ s/[ \t\r\n]+/ /g;

    # The order here is critical: the intent is that from now on, at most
    # one transformation will apply to any character.
    $str =~ s/%/%25/g;
    # '% characters have been escaped; it is now unambiguous to translate
    # sequences that will contain '%'s.
    $str =~ s/#/%23/g;
    $str =~ s/'/%27/g;
    $str =~ s/\+/%2B/g;
    $str =~ s/;/%3B/g;
    $str =~ s/\?/%3F/g;
    # '+' characters have been escaped; it is now safe to translate ' ' to '+'.
    $str =~ s/ /+/g;
    # ';' characters have been escaped; it is now safe to translate '::' to
    # ';'.
    $str =~ s/::/;/g;
    # '::' sequences have been translated; any remaining ':' character must
    # have been a singleton, and can now be escaped.
    $str =~ s/:/%3A/g;
    # All ':' characters have been escaped; we can now translate '//' to ':'.
    $str =~ s|//|:|g;
    # '//' sequences have been translated; any remaining '/' character must
    # have been a singleton, and can now be escaped.
    $str =~ s|/|%2F|g;

    return $str;
}

# Perform RFC 3151 inverse transcription (from a URN (sub)string to a
# (partial) public identifier).
sub Untranscribe($)
{
    my ($str) = @_;

    # Do this in exactly the opposite order to Transcribe, for exactly
    # the same reason.
    $str =~ s|%2F|/|gi;
    $str =~ s|:|//|g;
    $str =~ s/%3A/:/gi;
    $str =~ s/;/::/g;
    $str =~ s/\+/ /g;
    $str =~ s/%3F/?/gi;
    $str =~ s/%3B/;/gi;
    $str =~ s/%2B/+/gi;
    $str =~ s/%27/'/gi;
    $str =~ s/%23/#/gi;
    $str =~ s/%25/%/gi;

    # Note that whitespace normalisation is inherently lossy, so we couldn't
    # undo it even if we wanted to: all leading and trailing whitespace is
    # irretrievably gone, and all internal whitespace sequences have collapsed
    # to single space characters.
    return $str;
}

# Break a URN into (sub-)authority, type, and ID components.  There
# might be further structure in the authority part, but we'll ignore
# that for now.
sub Parse($)
{
    my ($hrn) = @_;

    if (!defined($hrn)) {
	carp("GeniHRN::Parse: hrn is undefined");
	return 0;
    }
    return undef if !IsValid( $hrn );

    $hrn = Unescape( $hrn );

    $hrn =~ /^[^+]*\+([^+]+)\+([^+]+)\+(.+)$/;

    return ($1, $2, Untranscribe( $3 ));
}

# Generate a ProtoGENI URN.  Note that this is a little bit more
# restrictive than the general GENI naming scheme requires: we don't
# currently apply transcription to the authority or type fields,
# though it would be easy enough to add if anybody were perverse
# enough to want it.
sub Generate($$$)
{
    my ($authority, $type, $id) = @_;

    # Assume that any sub-authorities are already encoded (see
    # RFC 3151, section 2).  We don't currently handle sub-authorities,
    # so this is irrelevant for now.

    # Apply case normalisation to the authority; see RFC 3987, section
    # 5.3.2.1.  According to section 5.3.3, we are supposed to go
    # further and perform RFC 3490 ToASCII UseSTD3ASCIIRules and
    # AllowUnassigned and RFC 3491 Nameprep validation to interpret IRIs,
    # but quite frankly I think I've done more than enough RFC chasing already.
    $authority =~ tr/A-Z/a-z/;
    return undef if $authority !~ /^[-.0-9A-Za-z:]+$/;
    return undef if $type !~ /^[-.0-9A-Z_a-z~]+$/;
    return undef if $id !~ m{^[-\t\n\r !#$%'()*+,./0-9:;=?\@A-Z_a-z]+$};

    return "urn:publicid:IDN+" . $authority . "+" . $type . "+" .
        Transcribe( $id );
}

# Apply scheme-based (and other) normalisations to a URN (see RFC 3987,
# section 5.3).  This is conformant to RFC 2141, section 5 (we recognise
# all of those lexical equivalences, and introduce additional ones as
# is permitted).  We do not perform deep interpretation of the URN, so
# this procedure can and should be applied to foreign (non-ProtoGENI) URNs.
sub Normalise($)
{
    my ($hrn) = @_;

    return undef if !IsValid( $hrn );

    my ($authority, $type, $id) = Parse( $hrn );
    return Generate( $authority, $type, $id );
}

sub Equal($$)
{
    my ($hrn0, $hrn1) = @_;

    return undef if !IsValid( $hrn0 ) || !IsValid( $hrn1 );

    my $norm0 = Normalise( $hrn0 );
    my $norm1 = Normalise( $hrn1 );

    return $norm0 eq $norm1;
}

sub Authoritative($$)
{
    my ($hrn, $authority) = @_;

    $authority =~ tr/A-Z/a-z/;
    my @hrn = Parse( $hrn );
    $hrn[ 0 ] =~ tr/A-Z/a-z/;

    return $hrn[ 0 ] eq $authority;
}

# Helper functions to make special cases slightly less messy:

# Generate an interface URN given a node and an interface ID on that node.
# This will probably fail horribly if the node ends and/or the interface
# begins with a '/' character, but anybody who does that probably deserves
# what they get.
sub GenerateInterface($$$)
{
    my ($authority,$node,$interface) = @_;

    return Generate( $authority, "interface", $node . "//" . $interface );
}

# Undo the GenerateInterface into a authority/name/interface triplet.
sub ParseInterface($)
{
    my ($urn) = @_;

    if (!defined($urn)) {
	carp("GeniHRN::ParseInterface: urn is undefined");
	return 0;
    }
    my ($authority,$type,$id) = Parse( $urn );

    return undef if $type ne "interface";

    return undef unless $id =~ m{(.*)//(.*)};

    return ( $authority, $1, $2 );
}

# _Always_ make sure that this 1 is at the end of the file...
1;
