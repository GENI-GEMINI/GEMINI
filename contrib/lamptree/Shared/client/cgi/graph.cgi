#!/usr/bin/perl -w

use strict;
use warnings;
use CGI;
use XML::LibXML;
use HTML::Entities;
use URI::Escape;
use File::Temp qw(tempfile);

use lib "/usr/local/DCN_LS/merge/lib";
use perfSONAR_PS::Client::DCN;

my $cgi = new CGI;
if ( $cgi->param('dcn') and $cgi->param('ts') ) {
  my $dcn = new perfSONAR_PS::Client::DCN(
    { instance => $cgi->param('dcn') }
  );
  my $result = $dcn->queryTS( { topology => $cgi->param('ts') } );

  my($fileHandle_dot, $fileName_dot) = tempfile();
  my($fileHandle_png, $fileName_png) = tempfile();
  close($fileHandle_png);

  my $parser = XML::LibXML->new();
  my $dom = $parser->parse_string($result->{response});

  my %nodes = ();
  my %domains = ();
  my @colors = ("mediumslateblue", "crimson", "chartreuse", "yellow", "darkorchid", "orange", "greenyellow");
  my $colorCounter = 0;

  print "Content-type: image/png\n\n";

  print $fileHandle_dot "graph g {\n";
  print $fileHandle_dot "  nodesep=1.5;\n";
  print $fileHandle_dot "  ranksep=1.5;\n";

  foreach my $l ($dom->getElementsByLocalName("link")) {
    my $id = $l->find("./\@id");  
    my %id_hash = ();

    $id =~ s/^urn:ogf:network://;
    $id = uri_unescape($id);
    my @array = split(/:/, $id);
    foreach my $a (@array) {
      my @array2 = split(/=/,$a);
      $id_hash{$array2[0]} = $array2[1];
    }
  
    unless ( exists $domains{ $id_hash{ "domain" } } ) {
      $domains{ $id_hash{ "domain" } } = $colorCounter;
      $colorCounter++;
    }
    unless ( exists $nodes{ $id_hash{ "node" } } ) {
      $nodes{ $id_hash{ "node" } } = $domains{ $id_hash{ "domain" } };
    }

    if ( $id ) {
      if ( $l->find("./*[local-name()=\"remoteLinkId\"]") ) {
        my $rid = $l->find("./*[local-name()=\"remoteLinkId\"]/text()")->get_node(1)->toString;
        my %rid_hash = ();
        $rid =~ s/^urn:ogf:network://;
        $rid = uri_unescape($rid);
        my @array3 = split(/:/, $rid);
        foreach my $a (@array3) {
          my @array4 = split(/=/,$a);
          $rid_hash{$array4[0]} = $array4[1];
        }

        unless ( exists $domains{ $id_hash{ "domain" } } ) {
          $domains{ $id_hash{ "domain" } } = $colorCounter;
          $colorCounter++;
        }
        unless ( exists $nodes{ $id_hash{ "node" } } ) {
          $nodes{ $id_hash{ "node" } } = $domains{ $id_hash{ "domain" } };
        }
      
        unless ($id_hash{"node"} eq "*" or $rid_hash{"node"} eq "*") {
          print $fileHandle_dot "  \"" , $id_hash{"node"} , "\" -- \"" , $rid_hash{"node"} , "\" [ labeldistance=2, labelfontsize=8, arrowhead=none, arrowtail=none, headlabel=\"".$id_hash{"port"}."\", taillabel=\"".$rid_hash{"port"}."\" ];\n";
        }
      }
    }
  }
  foreach my $n (keys %nodes) {
    print $fileHandle_dot "  \"".$n."\" [ color=".$colors[$nodes{$n}].", style=filled ];\n"
  }
  print $fileHandle_dot "}\n";
  close($fileHandle_dot); 
 
  system("fdp ".$fileName_dot." -Tpng ".$fileName_png);
}
else {
  print "Content-type: text/html\n\n";
  print "<html><head><title>DCN Topology Display</title></head>";
  print "<body><h2 align=\"center\">Error in topology display.</h2></body></html>";
}

