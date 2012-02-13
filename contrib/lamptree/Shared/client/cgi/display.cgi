#!/usr/bin/perl -w

use strict;
use warnings;
use CGI;

use lib "/usr/local/DCN_LS/merge/lib";
use perfSONAR_PS::Client::DCN;

my $cgi = new CGI;
if ( $cgi->param('dcn') and $cgi->param('ts') ) {
  my $dcn = new perfSONAR_PS::Client::DCN(
    { instance => $cgi->param('dcn') }
  );
  my $result = $dcn->queryTS( { topology => $cgi->param('ts') } );
  print "Content-type: text/xml\n\n";
  print $result->{response};
}
else {
  print "Content-type: text/html\n\n";
  print "<html><head><title>DCN Topology Display</title></head>";
  print "<body><h2 align=\"center\">Error in topology display.</h2></body></html>";
}
