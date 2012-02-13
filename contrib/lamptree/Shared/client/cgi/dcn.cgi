#!/usr/bin/perl -w

use strict;
use warnings;
use CGI;
use CGI::Ajax;

use lib "/usr/local/DCN_LS/merge/lib";
use perfSONAR_PS::Client::DCN;
use perfSONAR_PS::Common qw( escapeString );

my $INSTANCE = "http://dc211.internet2.edu:8090/perfSONAR_PS/services/LS";
#my $INSTANCE = "http://packrat.internet2.edu:8009/perfSONAR_PS/services/LS";

my $cgi = new CGI;
my $pjx = new CGI::Ajax( 
  'exported_func' => \&delete, 
  'exported_func2' => \&topo
);

print $pjx->build_html( $cgi, \&display);



# Call/Display the DCN mappings

sub delete {
  my($load, $hostname, $linkid, $add) = @_; 

  my $dcn = new perfSONAR_PS::Client::DCN(
    { instance => $INSTANCE }
  );

  my $html = q{};
  unless(defined $load and $load) {
    return $html;
  }

  $html = "<br>\n";

  if($hostname and $linkid) {
    $html .= "<table width=\"100%\" align=\"center\" border=\"2\">\n";  
    $html .= "<tr><th align=\"center\" colspan=\"2\" >Operation Status</th></tr>\n";
    $html .= "<tr>\n";
    if($add) {
      my $code = $dcn->insert({ 
        name => $hostname, 
        id => $linkid 
      });
      if($code == 0) {
        $html .= "<td align=\"center\" ><b><font color=\"green\"/>Insert</font></b></td>\n";
        $html .= "<td align=\"center\" ><i>Insert of \"".$hostname."\" and \"".$linkid."\" worked.</i></td>\n</tr>\n";
      }
      else {
        $html .= "<td align=\"center\" ><b><font color=\"red\"/>Insert</font></b></td>\n";
        $html .= "<td align=\"center\" ><i>Insert of \"".$hostname."\" and \"".$linkid."\" failed.</i></td>\n</tr>\n";
      }
    }
    else { 
      my $code = $dcn->remove({ 
        name => $hostname, 
        id => $linkid 
      });
      if($code == 0) {
        $html .= "<td align=\"center\" ><b><font color=\"green\"/>Delete</font></b></td>\n";
        $html .= "<td align=\"center\" ><i>Delete of \"".$hostname."\" and \"".$linkid."\" worked.</i></td>\n</tr>\n";
      }
      else {
        $html .= "<td align=\"center\" ><b><font color=\"red\"/>Delete</font></b></td>\n";
        $html .= "<td align=\"center\" ><i>Delete of \"".$hostname."\" and \"".$linkid."\" failed.</i></td>\n</tr>\n";
      }
    }
    $html .= "</tr>\n";
    $html .= "</table>\n";
    $html .= "<br>\n";
  }

  $html .= "<table border=\"0\" align=\"center\" width=\"60%\" >\n";
    $html .= "<tr>\n";
      $html .= "<td colspan=\"2\" align=\"center\">\n";
        $html .= "<input type=\"submit\" name=\"insert\" ";
        $html .= "value=\"Insert\" onclick=\"exported_func( ";
        $html .= "['loadQuery', 'hostname', 'linkid', 'add'], ['resultdiv'] );\">\n";
        $html .= "<input type=\"hidden\" name=\"add\" value=\"1\" id=\"add\" >\n";
      $html .= "</td>\n";
    $html .= "</tr>\n";
    $html .= "<tr>\n";
      $html .= "<td align=\"center\">\n";
        $html .= "Hostname: <input type=\"text\" name=\"hostname\" id=\"hostname\" />\n";
      $html .= "</td>\n";
      $html .= "<td align=\"center\">\n";
        $html .= "LinkID: <input type=\"text\" name=\"linkid\" id=\"linkid\" />\n";
      $html .= "</td>\n";
    $html .= "</tr>\n";
  $html .= "</table><br>\n";

  my $map = $dcn->getMappings;
  $html .= "<table width=\"100%\" align=\"center\" border=\"0\">\n";

  if($#$map == -1) {
    $html .= "<tr>";
    $html .= "<td align=\"center\">";
    $html .= "<i>No data to display.</i>";
    $html .= "</td>";  
    $html .= "</tr>\n";  
  } 
  else {
    my $counter = 0;
    foreach my $m (@$map) {
      $html .= "<tr>\n";
      my $col = 0;
      foreach my $value (@$m) {
        $html .= "<td>";
        if(($col % 2) == 0) {
          $html .= "<input type=\"text\" name=\"hostname.".$counter."\" value=\"".$value."\" size=\"25\" id=\"hostname.".$counter."\" />\n";
        }
        else {
          $html .= "<input type=\"text\" name=\"linkid.".$counter."\" value=\"".$value."\" size=\"75\" id=\"linkid.".$counter."\" />\n";
        }
        $html .= "</td>\n";
        $col++;
      }

        $html .= "<td>\n";
          $html .= "<input type=\"submit\" name=\"submit.".$counter."\" ";
          $html .= "value=\"Delete\" onclick=\"exported_func( ";
          $html .= "['loadQuery', 'hostname.".$counter."', 'linkid.".$counter."'], ";
          $html .= "['resultdiv'] );\">\n";
        $html .= "</td>\n";
      $html .= "</tr>\n";
      $counter++;
    }
  }
  $html .= "</table>\n";
  $html .= "<br>\n";
  
  return $html;
}



# Display/Call the topology service

sub topo {
  my($load) = @_;
  my $dcn = new perfSONAR_PS::Client::DCN(
    { instance => $INSTANCE }
  );

  my $html = q{};
  if(defined $load and $load) {

    my $services = $dcn->getTopologyServices;

    if($services) {
      $html .= "<br><table width=\"100%\" align=\"center\" border=\"1\">\n";
      $html .= "<tr>\n";
      $html .= "<th align=\"center\">Domain</th>\n";
      $html .= "<th align=\"center\">Access Point</th>\n";
      $html .= "<th align=\"center\">Name</th>\n";
      $html .= "<th align=\"center\">Type</th>\n";
      $html .= "<th align=\"center\">Description</th>\n";
      $html .= "<th align=\"center\">Show Topo</th>\n";
      $html .= "<th align=\"center\">Graph Topo</th>\n";
      $html .= "</tr>\n";

      my $tsCounter = 0;
      foreach my $s (keys %{$services}) {

        my $domains = $dcn->getDomainService(
          { 
            accessPoint => $s 
          }
        );

        my $dString = q{};
        my $dCount = 0;
        foreach my $d (@$domains) {
          if($dCount) {
            $dString .= ",&nbsp;";
          }
          $dString .= $d;
          $dCount++;
        }

        $html .= "<tr>\n";
        $html .= "<td align=\"center\">".$dString."</td>\n";
        $html .= "<td align=\"center\">".$s."</td>\n";
        $html .= "<td align=\"center\">".$services->{$s}->{"serviceName"}."</td>\n";
        $html .= "<td align=\"center\">".$services->{$s}->{"serviceType"}."</td>\n";
        $html .= "<td align=\"center\">".$services->{$s}->{"serviceDescription"}."</td>\n";
        $html .= "<td align=\"center\">\n";
        $html .= "<input type=\"button\" value=\"Query\" name=\"ts_query\" id=\"ts_query\" ";
        $html .= "onClick=\"window.open('display.cgi?dcn=".$INSTANCE."&ts=".$s."'";
        $html .= ",'mywindow','width=600,height=400,status=yes,scrollbars=yes,resizable=yes')\">\n";
        $html .= "</td>\n";
        $html .= "<td align=\"center\">\n";
        $html .= "<input type=\"button\" value=\"Graph\" name=\"ts_graph\" id=\"ts_graph\" ";
        $html .= "onClick=\"window.open('graph.cgi?dcn=".$INSTANCE."&ts=".$s."'";
        $html .= ",'mywindow2','width=800,height=600,status=yes,scrollbars=yes,resizable=yes')\">\n";
        $html .= "</td>\n";
        $html .= "</tr>\n";

        $tsCounter++;
      }
      $html .= "</table><br>\n";
    }
    else {
      $html .= "<i>No data to display.</i>";
    }
  }
  return $html;
}




# Main Page Display

sub display {

#  my $html = $cgi->start_html(-title=>'DCN Administrative Tool',
#			      -style=>{'src'=>'../html/dcn.css'});

  my $html = $cgi->start_html(-title=>'DCN Administrative Tool');

  $html .= $cgi->h2({ align => "center" }, "DCN Administrative Tool")."\n";
  $html .= $cgi->hr({size => "4", width => "95%"})."\n";

  $html .= $cgi->br;
  $html .= $cgi->br;

  $html .= $cgi->start_table({ border => "2", cellpadding => "1", align => "center", width => "95%" })."\n";

    $html .= $cgi->start_Tr;
      $html .= $cgi->start_th({ align => "center" });
        $html .= $cgi->h3( { align => "center" }, "Connection Mappings");
      $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
      $html .= $cgi->start_td({ align => "center" });
        $html .= "<input type=\"submit\" name=\"query\" ";
        $html .= "value=\"Query LS\" onclick=\"exported_func( ";
        $html .= "['loadQuery'], ['resultdiv'] );\">\n";

        $html .= "<input type=\"reset\" name=\"query_reset\" ";
        $html .= "value=\"Reset\" onclick=\"exported_func( ";
        $html .= "[], ['resultdiv'] );\">\n";

        $html .= "<input type=\"hidden\" name=\"loadQuery\" ";
        $html .= "id=\"loadQuery\" value=\"1\" />\n";

        $html .= "<div id=\"resultdiv\"></div>\n";
      $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

  $html .= $cgi->end_table."\n";

  $html .= $cgi->br;
  $html .= $cgi->br;

  $html .= $cgi->start_table({ border => "2", cellpadding => "1", align => "center", width => "95%" })."\n";

    $html .= $cgi->start_Tr;
      $html .= $cgi->start_th({ align => "center" });
        $html .= $cgi->h3( { align => "center" }, "Topology Service View");
      $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;
    $html .= $cgi->start_Tr;
      $html .= $cgi->start_td({ align => "center" });
        $html .= "<input type=\"submit\" name=\"topo_query\" ";
        $html .= "value=\"Query Topo\" onclick=\"exported_func2( ";
        $html .= "['loadTopo'], ['resultdiv2'] );\">\n";

        $html .= "<input type=\"reset\" name=\"topo_reset\" ";
        $html .= "value=\"Reset\" onclick=\"exported_func2( ";
        $html .= "[], ['resultdiv2'] );\">\n";

        $html .= "<input type=\"hidden\" name=\"loadTopo\" ";
        $html .= "id=\"loadTopo\" value=\"1\" />\n";

        $html .= "<div id=\"resultdiv2\"></div>\n";
      $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

  $html .= $cgi->end_table."\n";

  $html .= $cgi->br;
  $html .= $cgi->br;

  $html .= $cgi->hr({size => "4", width => "95%"})."\n";

  $html .= $cgi->end_html."\n";
  return $html;
}

