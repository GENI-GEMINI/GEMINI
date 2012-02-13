#!/usr/bin/perl -w

use strict;
use warnings;

use CGI;
use CGI::Ajax;
use XML::LibXML;    
use Socket;
use lib "/opt/perfSONAR-PS/lib";
use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Common;

my $service = "http://ndb0-aami.internet2.edu:8099/perfSONAR_PS/services/pSB";
my $ma = new perfSONAR_PS::Client::MA(
  { instance => $service }
);

my $subject = "    <iperf:subject xmlns:iperf=\"http://ggf.org/ns/nmwg/tools/iperf/2.0/\" />\n";
my @eventTypes = ("http://ggf.org/ns/nmwg/tools/iperf/2.0");

my $result = $ma->metadataKeyRequest( { 
  subject => $subject, 
  eventTypes => \@eventTypes } 
);

my $md;
if ( $#{ $result->{"data"} } and  $#{ $result->{"metadata"} }) {
  foreach my $d ( @{ $result->{"data"} } ) {
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string( $d );
    $md->{$doc->getDocumentElement->getAttribute("metadataIdRef")}->{"key"} = extract( find( $doc->getDocumentElement, "./nmwg:key/nmwg:parameters/nmwg:parameter", 1 ), 0 );
  }
  foreach my $m ( @{ $result->{"metadata"} } ) {
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string( $m );
    
    my $id = $doc->getDocumentElement->getAttribute("id");

    my $source = find( $doc->getDocumentElement, "./iperf:subject/nmwgt:endPointPair/nmwgt:src", 1 );
    ($md->{$id}->{"src"}->{"address"}, $md->{$id}->{"src"}->{"host"}) = lookupValues($source);
    my $dest = find( $doc->getDocumentElement, "./iperf:subject/nmwgt:endPointPair/nmwgt:dst", 1 );
    ($md->{$id}->{"dst"}->{"address"}, $md->{$id}->{"dst"}->{"host"}) = lookupValues($dest);

    my $eventTypes = find( $doc->getDocumentElement, "./nmwg:eventType", 0 );
    my $supportedEventTypes = find( $doc->getDocumentElement, "./nmwg:parameters/nmwg:parameter[\@name=\"supportedEventType\" or \@name=\"eventType\"]", 0 );
    foreach my $e ( $eventTypes->get_nodelist ) {
        my $value = extract( $e, 0 );
        push @{ $md->{$id}->{"content"}->{"eventType"} }, $value if $value;
    }
    foreach my $se ( $supportedEventTypes->get_nodelist ) {
        my $value = extract( $se, 0 );
        push @{ $md->{$id}->{"content"}->{"eventType"} }, $value if $value;
    }      
    
    my $parameters = find( $doc->getDocumentElement, "./nmwg:parameters/nmwg:parameter", 0 );
    foreach my $p ( $parameters->get_nodelist ) {
        my $value = extract( $p, 0 );
        my $name = $p->getAttribute("name");
        unless ( ( $name eq "eventType") or 
                 ( $name eq "supportedEventType") ){
            push @{ $md->{$id}->{"content"}->{$name} }, $value if $value;
        }
    }    
  }
}

sub lookupValues {
    my($node) = @_;
    my $ipAddress;
    my $host;
    if ( lc($node->getAttribute("type")) eq "ipv4" ) {
        $ipAddress = extract($node , 0 );
        my $iaddr = inet_aton($ipAddress);  
        my $adddress = gethostbyaddr($iaddr, AF_INET);
        if(defined $adddress) {      
            $host = $adddress;
        }
        else {
            $host = $ipAddress;
        }
    }
    elsif ( lc($node->getAttribute("type")) eq "host" or 
            lc($node->getAttribute("type")) eq "hostname" or 
            lc($node->getAttribute("type")) eq "dns") {
        $host = extract($node , 0 );
        my $packed_ip = gethostbyname($host);
        if (defined $packed_ip) {
            $ipAddress = inet_ntoa($packed_ip);
        }
        else {
            $ipAddress = $host;
        }
    }
    else {
        $ipAddress = extract($node , 0 );
        $host = $ipAddress;
    }
    return ($ipAddress, $host);
}

my $cgi = new CGI;
my $pjx = new CGI::Ajax( 
  'exported_func' => \&graph
);

print $pjx->build_html( $cgi, \&display);

sub graph {
  my($key) = @_;

  my $html = q{};
  if(defined $key and $key) {
      $html .= "<table width=\"100%\" align=\"center\" border=\"0\">\n";
      $html .= "<tr>\n";
      $html .= "<td width=\"80%\">\n";
      $html .= "<table width=\"100%\" align=\"center\" border=\"1\">\n";
      foreach my $id ( keys %{ $md } ) {
        if( $md->{$id}->{"key"} eq $key ) {
        
          $html .= "<tr>\n";
          $html .= "<th align=\"left\">Source</th>\n";
          $html .= "<td align=\"left\">".$md->{$id}->{"src"}->{"host"}."<br>".$md->{$id}->{"src"}->{"address"}."</td>\n";
          $html .= "</tr>\n";            
          $html .= "<tr>\n";
          $html .= "<th align=\"left\">Destination</th>\n";
          $html .= "<td align=\"left\">".$md->{$id}->{"dst"}->{"host"}."<br>".$md->{$id}->{"dst"}->{"address"}."</td>\n";
          $html .= "</tr>\n";  
                  
          foreach my $item ( keys %{ $md->{$id}->{"content"} } ) {
            foreach my $item2 ( @{ $md->{$id}->{"content"}->{$item} } ) {
              $html .= "<tr>\n";
              $html .= "<th align=\"left\">".$item."</th>\n";
              $html .= "<td align=\"left\">".$item2."</td>\n";
              $html .= "</tr>\n";           
            }
          }
          last;
        }
      }
      $html .= "</table>\n"; 
      $html .= "</td>\n";
      $html .= "<td valign=\"center\" halign=\"center\" align=\"center\" width=\"80%\">\n";
      $html .= "<input type=\"submit\" value=\"Graph\" name=\"graph\" id=\"graph\" ";
      $html .= "onClick=\"window.open('perfAdminGraph.cgi?url=".$service."&key=".$key."'";
      $html .= ",'graphwindow','width=800,height=300,status=yes,scrollbars=yes,resizable=yes')\">\n";
      $html .= "</td>\n";
      $html .= "</tr>\n";
      $html .= "</table>\n";  
  }
  return $html;
}

sub display {

  my $html = $cgi->start_html(-title=>'perfSONAR-PS perfAdmin',
                               -onload => 'onLoad();', 
                               -onresize => 'onResize();');
  $html .= $cgi->br;
  $html .= $cgi->start_table({ border => "2", cellpadding => "1", 
                               align => "center", width => "65%" })."\n";
    $html .= $cgi->start_Tr;
      $html .= $cgi->start_td({ align => "center" });
        $html .= "<input type=\"submit\" id=\"graph\" name=\"graph\" ";
        $html .= "value=\"Query MA\" onclick=\"exported_func( ";
        $html .= "['pair'], ['resultdiv'] );\">\n";  
        $html .= "<input type=\"reset\" name=\"query_reset\" ";
        $html .= "value=\"Reset\" onclick=\"exported_func( ";
        $html .= "[], ['resultdiv'] );\">\n";   
      $html .= $cgi->end_td;
      $html .= $cgi->start_td({ align => "center" });
        $html .= "<select id=\"pair\" name=\"pair\" onchange=\"exported_func( ";
        $html .= "['pair'], ['resultdiv'] );\">\n"; 
        foreach my $pair (sort keys %{ $md } ) {
          $html .= "  <option value=\"".$md->{$pair}->{"key"}."\">".$md->{$pair}->{"src"}->{"host"}." - ".$md->{$pair}->{"dst"}->{"host"}."</option>\n";        
        }        
        $html .= "</select>\n"; 
      $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
      $html .= $cgi->start_td({ align => "center", colspan => "2" });
        $html .= "<div id=\"resultdiv\"></div>\n";
      $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

  $html .= $cgi->end_table."\n";

  $html .= $cgi->end_html."\n";
  return $html;
}

