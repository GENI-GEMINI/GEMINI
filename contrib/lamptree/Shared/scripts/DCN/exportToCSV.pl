#!/usr/bin/perl -w

use strict;
use warnings;

use XML::LibXML;

use lib "../../lib";

use perfSONAR_PS::Client::LS;
use perfSONAR_PS::Common qw( extract find );

my $LS = shift;
die "no LS instance provided\n" unless $LS;

my $LEGACY = shift;
die "legacy mode nod specified, use (0|1)\n" unless defined $LEGACY;

my $ls = new perfSONAR_PS::Client::LS( { instance => $LS } ); 

my $query = q{};
if ( $LEGACY ) {
    $query = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $query .= "/nmwg:store[\@type=\"LSStore\"]/*[local-name()='data']\n";
}
else {
    $query = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $query .= "declare namespace dcn=\"http://ggf.org/ns/nmwg/tools/dcn/2.0/\";\n";
    $query .= "/nmwg:store[\@type=\"LSStore\"]/*[local-name()='data']/*[local-name()='metadata']/dcn:subject\n";
}

my $result = $ls->queryRequestLS( { query => $query, format => 1 } );
if ( $result->{eventType} =~ m/^error/mx ) {
    die "Something went wrong ... eventType:\t" . $result->{eventType} . "\tResponse:\t" . $result->{response} , "\n";
} 
else {
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string( $result->{response} );
    my $nodes = find( $doc->getDocumentElement, ".//*[local-name()='node']", 0 );
    foreach my $n ( $nodes->get_nodelist ) {
        my $host = extract( find ( $n, "./*[local-name()='address']", 1 ), 0 ); 
        my $link = extract( find ( $n, "./*[local-name()='relation']/*[local-name()='linkIdRef']", 1 ), 0 ); 
        print $host , "," , $link , "\n" if $host and $link;
    }
}
