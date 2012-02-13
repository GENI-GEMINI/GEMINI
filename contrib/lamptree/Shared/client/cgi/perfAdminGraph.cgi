#!/usr/bin/perl -w

use strict;
use warnings;

use CGI;
use XML::LibXML;
use Date::Manip qw(ParseDate UnixDate);
use lib "/opt/perfSONAR-PS/lib";
use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Common;

my $cgi = new CGI;
if ( $cgi->param('key') and $cgi->param('url')) {

    my $ma = new perfSONAR_PS::Client::MA(
      { instance => $cgi->param('url') }
    );

    my @eventTypes = ();
    my ( $sec, $frac ) = Time::HiRes::gettimeofday;
    my $subject = "  <nmwg:key id=\"key-1\">\n";
    $subject .= "    <nmwg:parameters id=\"parameters-key-1\">\n";
    $subject .= "      <nmwg:parameter name=\"maKey\">".$cgi->param('key')."</nmwg:parameter>\n";
    $subject .= "    </nmwg:parameters>\n";
    $subject .= "  </nmwg:key>  \n";

    my $result2 = $ma->setupDataRequest( { 
      start => ($sec-86400), 
      end => $sec, 
      subject => $subject, 
      eventTypes => \@eventTypes } );  

    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string( $result2->{"data"}->[0] );
    my $datum = find( $doc->getDocumentElement, "./iperf:datum", 0 );
    if( $datum ) {
      open(SIMILE, ">/tmp/perfAdmin/".$cgi->param('key'));
      foreach my $dt ( $datum->get_nodelist ) {
        my $date = ParseDate($dt->getAttribute("timeValue"));
        my $datestr = UnixDate($date, "%Y-%m-%d %H:%M:%S");
        print SIMILE $datestr . ",";        
        print SIMILE $dt->getAttribute("throughput") . "\n";
      }
      close(SIMILE);
    }

  print "Content-type: text/html\n\n";
  
  my $JSCRIPT=<<END;
var timeplot;

function onLoad() {
  var eventSource = new Timeplot.DefaultEventSource();
  var plotInfo = [
    Timeplot.createPlotInfo({
      id: "plot1",
      dataSource: new Timeplot.ColumnSource(eventSource,1),
      valueGeometry: new Timeplot.DefaultValueGeometry({
        gridColor: "#000000",
        axisLabelsPlacement: "left"
      }),
      timeGeometry: new Timeplot.DefaultTimeGeometry({
        gridColor: "#000000",
        axisLabelsPlacement: "top"
      }),      
      lineColor: "#ff0000",
      fillColor: "#cc8080",
      showValues: true
    })
  ];
  
  timeplot = Timeplot.create(document.getElementById("my-timeplot"), plotInfo);
END
  $JSCRIPT .= "  timeplot.loadText(\"../perfAdmin/".$cgi->param('key')."\", \",\", eventSource);";
  $JSCRIPT .= <<END;
}

var resizeTimerID = null;
function onResize() {
    if (resizeTimerID == null) {
        resizeTimerID = window.setTimeout(function() {
            resizeTimerID = null;
            timeplot.repaint();
        }, 100);
    }
}
END

  my $html = $cgi->start_html(-title=>'perfSONAR-PS perfAdmin', -script => [
                                    { -type => 'text/javascript',
                                      -src  => 'http://static.simile.mit.edu/timeplot/api/1.0/timeplot-api.js'
                                    },
                                    $JSCRIPT
                                 ], 
                               -onload => 'onLoad();', 
                               -onresize => 'onResize();');

  $html .= $cgi->start_table({ border => "2", cellpadding => "1", 
                               align => "center", width => "75%" })."\n";

    $html .= $cgi->start_Tr;
      $html .= $cgi->start_td({ align => "center", colspan => "2" });
        $html .= "<div id=\"my-timeplot\" style=\"height: 200px;\"></div>\n";
      $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

  $html .= $cgi->end_table."\n";
  
  $html .= $cgi->end_html."\n";
  print $html;
}
else {
  print "Content-type: text/html\n\n";
  print "<html><head><title>perfSONAR-PS perfAdmin</title></head>";
  print "<body><h2 align=\"center\">Graph error; Close window and try again.</h2></body></html>";
}


