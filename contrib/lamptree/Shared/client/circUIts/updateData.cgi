#!/usr/bin/perl -w -I /usr/local/perfSONAR-PS/lib -I/Users/boote/dev/perfSONAR-PS/trunk/lib -I/home/boote/dev/perfSONAR-PS/trunk/lib

use strict;
use FindBin;

use Getopt::Std;
use CGI qw/:standard -any/;
use CGI::Carp qw(fatalsToBrowser);
use XML::LibXML;
use XML::XPath;
use Time::HiRes qw( gettimeofday );

#use perfSONAR_PS::Transport;
use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Common;

# Eventually get these from config (or even app)
my $service = "http://packrat.internet2.edu:2008/perfSONAR_PS/services/snmpMA";

my $filter = '//nmwg:message//nmwg:datum';

my $cgi = new CGI;

# Test mode stuff
# TODO: Modify default to false...
my $fakeServiceMode = $cgi->param('fakeServiceMode');

my $int = $cgi->param('resolution') || 10;
my $maxValue = $cgi->param('maxValue') || 10000;
my $host = $cgi->param('hostName') || "192.65.196.254";
my $ifname = $cgi->param('ifName') || "TenGigabitEthernet-1/2";
my $direction = $cgi->param('direction') || "out";
my $npoints = $cgi->param('npoints') || 5;
my $refTime = $cgi->param('refTime') || "now";



# Create JSON from datum
print $cgi->header(-type => "text/javascript",
    -expires=>'now',
    -pragma=>'no-cache');

my $sec;
if(!$fakeServiceMode){
#    warn "real data";
    $sec = getReferenceTime($refTime,1);
    print fetchPerfsonarData($host, $ifname, $sec, $int, $direction, $npoints);
}
else{
#    warn "fake data: $fakeServiceMode";
    $sec = getReferenceTime($refTime,0);
    print fetchFakeData($host, $ifname, $sec, $int, $direction, $npoints);
}

exit 0;

sub getReferenceTime{
    my($sec,$do_res_hack) = @_;
    my($frac);

    if($sec eq "now"){
        ($sec, $frac) = Time::HiRes::gettimeofday;  
        $sec -= 2;
    }

    $sec;
}

sub fetchFakeData{
    my($host, $name, $time, $int, $direction, $npoints) = @_;

    # Randomize from 0 to maxValue
    my $data =  "\{\"servdata\"\: \{\n    \"data\"\: \[\n";
    my $v = rand($maxValue);
    $data .= '        ['.$time."," . $v. '],'. "\n";
    $data .= "\n      \]\n    \}\n\}";

    return $data;
}

sub fetchPerfsonarData{
    my($host, $name, $time, $int, $direction, $npoints) = @_;
    my $stime = $time-($int*$npoints);
    my $etime = $time;

    warn "Pre sender";
    my $ma = new perfSONAR_PS::Client::MA(
        { instance => $service});
    warn "Post sender";

    my $subject = <<"EOF";
<netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"s1\">
  <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">
    <nmwgt:ifName>$name</nmwgt:ifName>
    <nmwgt:direction>$direction</nmwgt:direction>
  </nmwgt:interface>
</netutil:subject>
EOF
    my @eventTypes = ("http://ggf.org/ns/nmwg/characteristic/utilization/2.0");

    my $result = $ma->setupDataRequest(
        {
            subject => $subject,
            eventTypes => \@eventTypes,

            consolidationFunction => "AVERAGE",
            resolution => $int,
            start => $stime,
            end => $etime,
        });
    warn $result->{"data"}->[0];
#    warn "Post send data";

    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_string( $result->{"data"}->[0] );
    my $nodeset = find( $doc->getDocumentElement, "./*[local-name()='datum']", 0);
    if($nodeset->size() <= 0) {
        die "Nothing found for xpath statement $filter.\n";
    }

    my $data =  "\{\"servdata\"\: \{\n    \"data\"\: \[\n";
    foreach my $d ($nodeset->get_nodelist) {
        my $tt = $d->getAttribute("timeType");
        my $du = $d->getAttribute("valueUnits");

        if($tt ne "unix"){
            die "Unsupported timeType in result: $tt";
        }
        if($du ne "Bps"){
            die "Unsupported valueUnits in result: $du";
        }
        my $t = int($d->getAttribute("timeValue"));
        # convert to mbps
        my $v = int($d->getAttribute("value")) * 8 / 1000000;
        next if($v eq 'nan');
        $data .= '        ['. $t. "," . $v. '],'. "\n";
    }
    $data .= "\n      \]\n    \}\n\}";

    return $data;
}
