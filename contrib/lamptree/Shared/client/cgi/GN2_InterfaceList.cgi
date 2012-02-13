#!/usr/bin/perl -w

use strict;
use warnings;
use XML::LibXML;
use CGI;

use lib "../../";

use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Common qw( extract find );

my $cgi = new CGI;

my $ma = new perfSONAR_PS::Client::MA(
  { instance => "http://stats.geant2.net/perfsonar/RRDMA-access/MeasurementArchiveService"}
);

my $subject = "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"s\">\n";
$subject .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
$subject .= "        <nmwgt:direction>in</nmwgt:direction>\n";
$subject .= "      </nmwgt:interface>\n";
$subject .= "    </netutil:subject>\n";

my @eventTypes = ("http://ggf.org/ns/nmwg/characteristic/utilization/2.0");

print "Content-type: text/html\r\n\r\n";
print $cgi->start_html(-title=>'GN2 perfSONAR MA Output');

my $parser = XML::LibXML->new();            
my $result = $ma->metadataKeyRequest( { 
  subject => $subject, 
  eventTypes => \@eventTypes } );

print $cgi->start_table({ border => "2", cellpadding => "1", align => "center", width => "95%" });

print $cgi->start_Tr;
print $cgi->start_th({ align => "center" });
print "hostName\n";
print $cgi->end_th;
print $cgi->start_th({ align => "center" });
print "ifName\n";
print $cgi->end_th;
print $cgi->start_th({ align => "center" });
print "ifDescription\n";
print $cgi->end_th;
print $cgi->start_th({ align => "center" });
print "ifAddress\n";
print $cgi->end_th;
print $cgi->start_th({ align => "center" });
print "capacity\n";
print $cgi->end_th;
print $cgi->end_Tr;

foreach my $md ( @{ $result->{"metadata"} } ) {
  my $metadata = $parser->parse_string( $md );

  print $cgi->start_Tr;

  print $cgi->start_td({ align => "center" });
  print extract( find( $metadata->getDocumentElement, 
    "./netutil:subject/nmwgt:interface/nmwgt:hostName", 1 ), 0 ) , "\n";
  print $cgi->end_td;
  print $cgi->start_td({ align => "center" });
  print extract( find( $metadata->getDocumentElement, 
    "./netutil:subject/nmwgt:interface/nmwgt:ifName", 1 ), 0 ) , "\n";
  print $cgi->end_td;
  print $cgi->start_td({ align => "center" });
  print extract( find( $metadata->getDocumentElement, 
    "./netutil:subject/nmwgt:interface/nmwgt:ifDescription", 1 ), 0 ) , "\n";
  print $cgi->end_td;
  print $cgi->start_td({ align => "center" });
  print extract( find( $metadata->getDocumentElement, 
    "./netutil:subject/nmwgt:interface/nmwgt:ifAddress", 1 ), 0 ) , "\n";
  print $cgi->end_td;
  print $cgi->start_td({ align => "center" });
  print extract( find( $metadata->getDocumentElement, 
    "./netutil:subject/nmwgt:interface/nmwgt:capacity", 1 ), 0 ) , "\n";
  print $cgi->end_td;
 
  print $cgi->end_Tr;
}

print $cgi->end_html;
