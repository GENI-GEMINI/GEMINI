#!/usr/bin/perl -w

use strict;
use warnings;

use Tk;
use Tk::widgets qw/PNG Dialog/;
use Time::HiRes qw(gettimeofday);
use XML::LibXML;
use Data::Dumper;

use lib "/home/jason/ami/perfSONARBUOY/trunk/lib";

use perfSONAR_PS::Client::MA;
use perfSONAR_PS::Client::DCN;
use perfSONAR_PS::Common qw( extract find );

# Define Arrow Colors
my $white = "#ffffff";
my $black = "#000000";
my $c1 = "#00ebeb";
my $c2 = "#00a3f7";
my $c3 = "#0000f7";
my $c4 = "#00ff00";
my $c5 = "#00c700";
my $c6 = "#008f00";
my $c7 = "#969600";
my $c8 = "#ffff00";
my $c9 = "#ff8f00";
my $c10 = "#ff0000";
my $c11 = "#d70000";
my $c12 = "#bf0000";
my $c13 = "#ff00ff";
my $c14 = "#9b57cb";
my $c15 = "#d4b7d8";
my $c16 = "#7f7f7f";

my $VERBOSE = 1;
my $VERSION = 0.09;

my $parser = XML::LibXML->new();
my $Main = MainWindow->new(-title => "perfSONAR-PS Fusion", -background => "white" );

# Create the menubar

my $menubar = $Main->Menu;
$Main->configure(-menu => $menubar);
my $file = $menubar->cascade(-label => 'File', -tearoff => 0);
$file->command(-label => "Quit", -command => \&finish);

my $help = $menubar->cascade(-label => 'Help', -tearoff => 0);
$help->command(-label => 'Version', -command=>\&version);
$help->separator;
$help->command(-label => 'About', -command=>\&about);

my $image = $Main->Photo(-file => "US_new.png");

# update speed (in seconds)
my $updateSpeed = 5;

# ------------------------------------------------------------------------------

sub finish {
    exit;
}

sub about {
  my $popup = $Main->DialogBox(
    -title => "About",
    -buttons => ["OK"]
  );
  $popup->add("Label", 
    -text => "perfSONAR-PS Fusion works to unite the Internet2 Dynamic Circuit Nerwork (DCN) with the perfSONAR measurement infrastructure."
  )->pack;
  $popup->Show;
}

sub version {
  my $popup = $Main->DialogBox(
    -title => "Version", 
    -buttons => ["OK"]
  );
  $popup->add("Label", 
    -text => "perfSONAR-PS Fusion v $VERSION"
  )->pack;
  $popup->Show;
} 

sub drawMap {
	my $target = shift or return undef;
	my $f1 = $target->Frame()->pack( -side => "left",-fill => "both", -expand => 1 );
  my $cns = $f1->Canvas( -background=>"white", -width => 450, -height => 450 );
  $cns->createImage( 225,225, -image => $image );

	drawArrows( $cns, ( $updateSpeed * 1000 ) );

	return $cns->pack(
		-side           => "bottom",
		-expand         => 1,
		-fill           => 'both',
	);
}

sub drawArrows {
  my($target, $ms) = @_;

  my $result = collectData();
  print Dumper($result) , "\n" if $VERBOSE;

  # NB: Draw from the source to the cloud

  $target->createImage(225,225, -image => $image); 

  my $write = 0;
  foreach my $host ( %{ $result } ) {
      if ( $host eq "phoebus.salt.dcn.internet2.edu" ) {
          makeArrow($target, 109, 194, 189, 228, 3, 
            getColor($result->{$host}->{"in"}), 
            getColor($result->{$host}->{"out"}));    
          $write++;
      }
      elsif( $host eq "phoebus.losa.dcn.internet2.edu" ) {
          makeArrow($target, 46, 256, 174, 238, 3, 
            getColor($result->{$host}->{"in"}), 
            getColor($result->{$host}->{"out"})); 
          $write++;
      }
      elsif( $host eq "phoebus.chic.dcn.internet2.edu" ) {
          makeArrow($target, 268, 204, 259, 224, 3, 
            getColor($result->{$host}->{"in"}), 
            getColor($result->{$host}->{"out"})); 
          $write++;
      }
      elsif( $host eq "phoebus.hous.dcn.internet2.edu" ) {
          makeArrow($target, 191, 276, 198, 255, 3, 
            getColor($result->{$host}->{"in"}), 
            getColor($result->{$host}->{"out"})); 
          $write++;
      }
      elsif( $host eq "nysernet.newy.dcn.internet2.edu" ) {
          makeArrow($target, 350, 189, 278, 230, 3, 
            getColor($result->{$host}->{"in"}), 
            getColor($result->{$host}->{"out"})); 
          $write++;
      }
  }
  
  unless ( $write ) {
    $target->createImage(225,225, -image => $image);    
  }
  
  
  $target->after($ms, [ \&drawArrows => $target, $ms ] );
}

sub makeArrow {
  my($target, $x1, $y1, $x2, $y2, $width, $inColor, $outColor) = @_;  
    my $theta = atan2($y1-$y2,$x1-$x2);

   # in arrow

    my $arrow1 = $target->createPolygon(
      $x2,$y2,
      $x2+$width*sin($theta),
      $y2-$width*cos($theta),
      $x1+$width*sin($theta)-($width*2)*cos($theta),
      $y1-($width*2)*sin($theta)-$width*cos($theta),
      $x1+($width*2)*(sin($theta)-cos($theta)),
      $y1+($width*2)*(-sin($theta)-cos($theta)),
      $x1,$y1,
      -outline => "black",
      -fill => $inColor 
    ); 
    
    # out arrow
    
    $theta = atan2($y2-$y1,$x2-$x1);
    my $arrow2 = $target->createPolygon(
      $x1,$y1,
      $x1+$width*sin($theta),
      $y1-$width*cos($theta),
      $x2+$width*sin($theta)-($width*2)*cos($theta),
      $y2-($width*2)*sin($theta)-$width*cos($theta),
      $x2+($width*2)*(sin($theta)-cos($theta)),
      $y2+($width*2)*(-sin($theta)-cos($theta)),
      $x2,$y2,
      -outline => "black",
      -fill => $outColor 
    );
}

drawMap($Main);

MainLoop;

exit(99);


# ------------------------------------------------------------------------------


sub getColor {
    my($value) = @_;
    if($value == -1) {
        return $black;
    }
    elsif($value < 0) {
        return $white;  
    }
    elsif($value >= 0 && $value < 5242880) {
        return $c1;  
    }
    elsif($value >= 5242880 && $value < 10485760) {
        return $c2;  
    }
    elsif($value >= 10485760 && $value < 52428800) {
        return $c3;  
    }
    elsif($value >= 52428800 && $value < 104857600) {
        return $c4;  
    }
    elsif($value >= 104857600 && $value < 524288000) {
        return $c5;  
    }
    elsif($value >= 524288000 && $value < 1073741824) {
        return $c6;  
    }
    elsif($value >= 1073741824 && $value < 2147483648) {
        return $c7;  
    }
    elsif($value >= 2147483648 && $value < 3221225472) {
        return $c8;  
    }
    elsif($value >= 3221225472 && $value < 4294967296) {
        return $c9;  
    }
    elsif($value >= 4294967296 && $value < 5368709120) {
        return $c10;  
    }
    elsif($value >= 5368709120 && $value < 6442450944) {
        return $c11;  
    }
    elsif($value >= 6442450944 && $value < 7516192768) {
        return $c12;  
    }
    elsif($value >= 7516192768 && $value < 8589934592) {
        return $c13;  
    }
    elsif($value >= 8589934592 && $value < 9663676416) {
        return $c14;  
    }
    elsif($value >= 9663676416 && $value < 10737418240) {
        return $c15;  
    }
    elsif($value >= 10737418240) {
      return $c16;  
    }
    else {
        return $black;
    }
}



sub collectData {
    my %final = ();

    my $oscars_ma = new perfSONAR_PS::Client::MA(
      { instance => "http://packrat.internet2.edu:8083/perfSONAR_PS/services/oscars"}
    );
    my $dcn_ls = new perfSONAR_PS::Client::DCN(
      { instance => "http://packrat.internet2.edu:8009/perfSONAR_PS/services/LS"}
    );

    my $snmp_ma = new perfSONAR_PS::Client::MA(
      { instance => "http://packrat.internet2.edu:8082/perfSONAR_PS/services/snmpMA"}
    );

    # Query the OSCARS MA  
    my @oscarsET = ("http://ggf.org/ns/nmwg/topology/query/all/20070809");
    my $result = $oscars_ma->setupDataRequest( { eventTypes => \@oscarsET } );

    # We don't really care about the Metadata, just the data.  There 'may' be
    #   many, so iterate over all of them
    foreach my $d ( @{ $result->{"data"} } ) {
        my $data = $parser->parse_string( $d );

        if ($VERBOSE) {
            my $topo = extract( find( $data->getDocumentElement, "./nmtb:topology", 1 ), 0 ); 
            unless ( $topo ) {
                print "Topology not found.\n";
            }
        }
    
        # We are looking for topology elements inside of the data.  There 'may'
        #   be many, so iterate over all of them
        foreach my $t ( $data->getDocumentElement->getChildrenByTagNameNS( "http://ogf.org/schema/network/topology/base/20070828/", "topology" ) ) {

            if ($VERBOSE) {
                my $path = extract( find( $t, "./nmtb:path", 1 ), 0 );  
                unless ( $path ) {
                    print "Path not found.\n";
                }
            }
            
            # We are looking for path elements inside of the topology.  There
            #   'may' be many, so iterate over all of them
            foreach my $p ( $t->getChildrenByTagNameNS( "http://ogf.org/schema/network/topology/base/20070828/", "path" ) ) {
      
                # Because there is a lot of junk, lets make a array containing
                #   the end to end path
                
                my @list = ();
                foreach my $c ( $p->childNodes->get_nodelist ) {
                    my $node = $c->toString;
                    $node =~ s/^(\s+|\n+)//g;
                    $node =~ s/(\s+|\n+)$//g;
                    if ( $node ) {
                        my $urn = extract( find( $c, "./nmtb:linkIdRef", 1 ), 0 );
                        push @list, $urn if $urn;
                    }
                }

                # Only the first and the last count (for now), store these into
                #   a hash for return.

                my $names = $dcn_ls->idToName( { id => $list[0] } );
                my $names2 = $dcn_ls->idToName( { id => $list[$#list] } );
                if($names->[0]) {
                    my %temp = ();
                    $temp{"in"} = callSNMP_MA($snmp_ma, $names->[0], "in");        
                    $temp{"out"} = callSNMP_MA($snmp_ma, $names->[0], "out");
                    $final{$names->[0]} = \%temp;
                }
                if($names2->[0]) {
                    my %temp2 = ();
                    $temp2{"in"} = callSNMP_MA($snmp_ma, $names2->[0], "in");
                    $temp2{"out"} = callSNMP_MA($snmp_ma, $names2->[0], "out");    
                    $final{$names2->[0]} = \%temp2;
                } 
            }
        }    
    }  
    
    return \%final;
}



sub callSNMP_MA {
    my($ma, $host, $direction) = @_;
    my %datum = ();
    my ( $sec, $frac ) = Time::HiRes::gettimeofday;
            
    # Standard SNMP MA/RRD MA subject.  Only search on host/direction
            
    my $subject = "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"s-in-16\">\n";
    $subject .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
    $subject .= "        <nmwgt:hostName>".$host."</nmwgt:hostName>\n";
    $subject .= "        <nmwgt:direction>".$direction."</nmwgt:direction>\n";
    $subject .= "      </nmwgt:interface>\n";
    $subject .= "    </netutil:subject>\n";
    
    # Standard eventType, we could add more
    my @eventTypes = ("http://ggf.org/ns/nmwg/characteristic/utilization/2.0");

    # Not worrying about 'supportedEventType' parameters (will break RRD MA)

    # Call up the MA, we just want a little bit of data (1 minute is more than
    #    enough).  Note I am requesting a VERY low resolution, this should give
    #    us the smallest in the RRD file.
    my $ma_result = $ma->setupDataRequest(
        { 
            consolidationFunction => "AVERAGE", 
            resolution => 1,
            start => ($sec-60), 
            end => $sec, 
            subject => $subject, 
            eventTypes => \@eventTypes
        } 
    );

    # There should be only one data, but iterate anyway.
    foreach my $d ( @{ $ma_result->{"data"} } ) {
        my $data = $parser->parse_string( $d );    
        
        # Extract the datum elements. 
        foreach my $dt ( $data->getDocumentElement->getChildrenByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "datum" ) ) {
            # Make sure the time and data are legit.
            if($dt->getAttribute("timeValue") =~ m/^\d{10}$/) {           
                if($dt->getAttribute("value") and $dt->getAttribute("value") ne "nan") {
                    $datum{$dt->getAttribute("timeValue")} = $dt->getAttribute("value") * 8;
                }
                else {
                    # these are usually 'NaN' values
                    $datum{$dt->getAttribute("timeValue")} = $dt->getAttribute("value");
                }
            }
        }
    }
 
    # Sort, than pick the last in line that is NOT a 'nan'
    my $last = 0;
    foreach my $value ( sort keys %datum ) {   
        unless ( lc($datum{$value}) eq "nan" ) {
            $last = $datum{$value};
        }
    }
    return $last;
}
