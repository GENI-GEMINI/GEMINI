#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;
use XML::LibXML;
use Net::CIDR;

use lib "../lib";
use perfSONAR_PS::Client::gLS;
use perfSONAR_PS::Common;

my $parser = XML::LibXML->new();
my $url = "http://192.168.69.131/gls.root.hints";

my $gls = perfSONAR_PS::Client::gLS->new( { url => $url} );
foreach my $root ( @{ $gls->{ROOTS} } ) {
    print "Root:\t" , $root , "\n";
}

unless ( $#{ $gls->{ROOTS} } > -1 ) {
    print "Root not found, exiting...\n";
    exit(1);
}

my $doc = q{};
my $eT = q{};
my $domain = q{};
my $address = q{};

# ------------------------------------------------------------------------------
# level 0 tests - getLSDiscoverRaw/getLSQueryRaw to find services
# ------------------------------------------------------------------------------

my @hls = ();

print "\nFinding all available hLS instances...\n";
my $result = $gls->getLSDiscoverRaw( { xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:metadata[./perfsonar:subject/psservice:service/psservice:serviceType[text()=\"LS\" or text()=\"hLS\" or text()=\"gLS\"]]" } );
if ( $result and $result->{eventType} =~ m/^success/ ) {
    if ( exists $result->{eventType} and $result->{eventType} ne "error.ls.query.empty_results" ) {
        $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
        my $ap = find( $doc->getDocumentElement, ".//psservice:accessPoint", 0 );
        foreach my $a ( $ap->get_nodelist ) {
            my $value = extract( $a, 0 );
            print "\thLS:\ " , $value , "\n" if $value;
            push @hls, $value if $value;
        }
    }
    else {
        print "Query error.\n";
    }
}
else {
   print "\tNothing Found.\n";
}

if ( $#hls > -1 ) {
    print "\nFinding all registered services at each hLS...\n";
    foreach my $h ( @hls ) {
        print "\thLS:\ " , $h , "\n";
        my $result = $gls->getLSQueryRaw( { ls => $h, xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:metadata[./perfsonar:subject/psservice:service]" } );
        if ( exists $result->{eventType} and $result->{eventType} ne "error.ls.query.empty_results" ) {
            $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
            my $ap = find( $doc->getDocumentElement, ".//psservice:accessPoint", 0 );
            foreach my $a ( $ap->get_nodelist ) {
                my $value = extract( $a, 0 );
                print "\t\tservice:\ " , $value , "\n" if $value;
            }
        }
        else {
            print "Query error at \"".$h."\".\n";
        }
    }
}

# ------------------------------------------------------------------------------
# level 0 tests - getLSDiscoverRaw
# ------------------------------------------------------------------------------

print "\nLevel 0: getLSDiscoverRaw for \"eventType\" @ the root...\n";
$result = $gls->getLSDiscoverRaw( { xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/nmwg:eventType" } );
if ( $result and $result->{eventType} =~ m/^success/ ) {
    $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
    $eT = find( $doc->getDocumentElement, ".//nmwg:eventType", 0 );
    foreach my $e ( $eT->get_nodelist ) {
        my $value = extract( $e, 0 );
        print "\teventType:\ " , $value , "\n" if $value;
    }
}
else {
   print "\tNothing Found.\n";
}

if ( $#hls > -1 ) {
    foreach my $h ( @hls ) {
        print "\nLevel 0: getLSDiscoverRaw for \"eventType\" @ the hLS \"".$h."\"...\n";
        $result = $gls->getLSDiscoverRaw( { ls => $h, xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/nmwg:eventType" } );
        $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
        $eT = find( $doc->getDocumentElement, ".//nmwg:eventType", 0 );
        foreach my $e ( $eT->get_nodelist ) {
            my $value = extract( $e, 0 );
            print "\teventType:\ " , $value , "\n" if $value;
        }
    }
}

# --------------------------------

print "\nLevel 0: getLSDiscoverRaw for \"domain\" @ the gLS...\n";
my $ds;
$result = $gls->getLSDiscoverRaw( { xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/summary:subject/nmtb:domain" } );
if ( $result and $result->{eventType} =~ m/^success/ ) {
    $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
    $domain = find( $doc->getDocumentElement, ".//nmtb:domain/nmtb:name[\@type=\"dns\"]", 0 );
    foreach my $d ( $domain->get_nodelist ) {
        my $value = extract( $d, 0 );
        $ds->{$value} = 1 if $value;
    }
    foreach my $d ( keys %{ $ds } ) {
        print "\tdomain:\ " , $d , "\n";
    }
}
else {
   print "\tNothing Found.\n";
}

if ( $#hls > -1 ) {
    foreach my $h ( @hls ) {
        print "\nLevel 0: getLSDiscoverRaw for \"domain\" @ the hLS \"".$h."\"...\n";
        undef $ds;
        $result = $gls->getLSDiscoverRaw( { ls => $h, xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/summary:subject/nmtb:domain" } );
        $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
        $domain = find( $doc->getDocumentElement, ".//nmtb:domain/nmtb:name[\@type=\"dns\"]", 0 );
        foreach my $d ( $domain->get_nodelist ) {
            my $value = extract( $d, 0 );
            $ds->{$value} = 1 if $value;
        }
        foreach my $d ( keys %{ $ds } ) {
            print "\tdomain:\ " , $d , "\n";       
        }
    }
}
    

# --------------------------------

print "\nLevel 0: getLSDiscoverRaw for \"addresses\" @ the gLS...\n";
my $as;
$result = $gls->getLSDiscoverRaw( { xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/summary:subject/*[local-name()=\"network\"]" } );
if ( $result and $result->{eventType} =~ m/^success/ ) {
    $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
    $address = find( $doc->getDocumentElement, ".//nmtl3:network/nmtl3:subnet", 0 );
    foreach my $a ( $address->get_nodelist ) {
        my $value1 = extract( find($a, "./nmtl3:address", 1) , 0 );
        my $value2 = extract( find($a, "./nmtl3:netmask", 1) , 0 );
        $as->{$value1."/".$value2} = 1 if $value1 and $value2;
    }
    foreach my $a ( keys %{ $as } ) {
        my @a2 = Net::CIDR::cidr2range($a);
        foreach my $o (@a2) {
          print "\trange: " , $o , "\n";
        }
    }
}
else {
   print "\tNothing Found.\n";
}

if ( $#hls > -1 ) {
    foreach my $h ( @hls ) {
        print "\nLevel 0: getLSDiscoverRaw for \"addresses\" @ the hLS \"".$h."\"...\n";
        undef $as;
        $result = $gls->getLSDiscoverRaw( { ls => $h, xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/summary:subject/nmtl3:network" } );
        if ( $result and $result->{eventType} =~ m/^success/ ) {     
            $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};        
            $address = find( $doc->getDocumentElement, ".//nmtl3:network/nmtl3:subnet", 0 );
            foreach my $a ( $address->get_nodelist ) {
                my $value1 = extract( find($a, "./nmtl3:address", 1) , 0 );
                my $value2 = extract( find($a, "./nmtl3:netmask", 1) , 0 );
                $as->{$value1."/".$value2} = 1 if $value1 and $value2;
            }
            foreach my $a ( keys %{ $as } ) {
                my @a2 = Net::CIDR::cidr2range($a);
                foreach my $o (@a2) {
                    print "\trange: " , $o , "\n";
                }
            }
        }
        else {
            print "\tNothing Found.\n";
        }
    }
}



# ------------------------------------------------------------------------------
# level 1 tests - getLSDiscovery
# ------------------------------------------------------------------------------


# baselines:
my @ipaddresses = ();
my @eventTypes = ();
my @domains = ();
my @keywords = ();
my %service = ();

@domains = ("edu");
print "\nLevel 1: getLSDiscovery for \"domain = edu\" @ the root...\n";
$result = $gls->getLSDiscovery( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
foreach my $ls ( @{ $result } ) {
    print "\thLS to Try:\ " , $ls , "\n";
}
unless ( $#{ $result } > -1 ) {
    print "\tNothing found for search.\n";
}

@eventTypes = ("http://ggf.org/ns/nmwg/characteristic/utilization/2.0");
print "\nLevel 1: getLSDiscovery for \"domain = edu, eventType = utilization\" @ the root...\n";
$result = $gls->getLSDiscovery( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
foreach my $ls ( @{ $result } ) {
    print "\thLS to Try:\ " , $ls , "\n";
}
unless ( $#{ $result } > -1 ) {
    print "\tNothing found for search.\n";
}

@keywords = ("LHC");
print "\nLevel 1: getLSDiscovery for \"domain = edu, eventType = utilization\" keywords = \"LHC\"@ the root...\n";
undef $result;
$result = $gls->getLSDiscovery( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
foreach my $ls ( @{ $result } ) {
    print "\thLS to Try:\ " , $ls , "\n";
}
unless ( $#{ $result } > -1 ) {
    print "\tNothing found for search.\n";
}
@keywords = ("blah");
print "\nLevel 1: getLSDiscovery for \"domain = edu, eventType = utilization\" keywords = \"blah\"@ the root...\n";
undef $result;
$result = $gls->getLSDiscovery( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
foreach my $ls ( @{ $result } ) {
    print "\thLS to Try:\ " , $ls , "\n";
}
unless ( $#{ $result } > -1 ) {
    print "\tNothing found for search.\n";
}
@keywords = ();

%service = ( serviceType => "LS" );
print "\nLevel 1: getLSDiscovery for \"domain = edu, eventType = utilization, serviceType = LS\" @ the root...\n";
$result = $gls->getLSDiscovery( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
foreach my $ls ( @{ $result } ) {
    print "\thLS to Try:\ " , $ls , "\n";
}
unless ( $#{ $result } > -1 ) {
    print "\tNothing found for search.\n";
}

@ipaddresses = (["118.71.52.126", "ipv4"]);
print "\nLevel 1: getLSDiscovery for \"domain = edu, eventType = utilization, serviceType = LS, ipaddress = 118.71.52.126\" @ the root...\n";
$result = $gls->getLSDiscovery( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
foreach my $ls ( @{ $result } ) {
    print "\thLS to Try:\ " , $ls , "\n";
}
unless ( $#{ $result } > -1 ) {
    print "\tNothing found for search.\n";
}

# ------------------------------------------------------------------------------
# level 1 tests - getLSQueryLocation
# ------------------------------------------------------------------------------

@ipaddresses = ();
@domains = ("edu");
@eventTypes = ();
%service = ();
@keywords = ();
if ( $#hls > -1 ) {
    foreach my $h ( @hls ) {
        print "\nLevel 1: getLSQueryLocation for \"domain = edu @ the hLS \"".$h."\"...\n";
        $result = $gls->getLSQueryLocation( { ls => $h, addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
        foreach my $s ( @{ $result } ) {
            $doc = $parser->parse_string( $s ); 
            print $doc->toString , "\n";
        }
        unless ( $#{ $result } > -1 ) {
            print "\tNothing found for search.\n";
        }
    }
}

@eventTypes = ("http://ggf.org/ns/nmwg/characteristic/utilization/2.0");
if ( $#hls > -1 ) {
    foreach my $h ( @hls ) {
        print "\nLevel 1: getLSQueryLocation for \"domain = edu, eventType = utilization\" @ the hLS \"".$h."\"...\n";
        $result = $gls->getLSQueryLocation( { ls => $h, addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
        foreach my $s ( @{ $result } ) {
            $doc = $parser->parse_string( $s ); 
            print $doc->toString , "\n";
        }
        unless ( $#{ $result } > -1 ) {
            print "\tNothing found for search.\n";
        }
    }
}

@eventTypes = ("http://ggf.org/ns/nmwg/tools/owamp/2.0");
if ( $#hls > -1 ) {
    foreach my $h ( @hls ) {
        print "\nLevel 1: getLSQueryLocation for \"domain = edu, eventType = owamp\" @ the hLS \"".$h."\"...\n";
        $result = $gls->getLSQueryLocation( { ls => $h, addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
        foreach my $s ( @{ $result } ) {
            $doc = $parser->parse_string( $s ); 
            print $doc->toString , "\n";
        }
        unless ( $#{ $result } > -1 ) {
            print "\tNothing found for search.\n";
        }
    }
}


# ------------------------------------------------------------------------------
# level 2 tests - getLSLocation
# ------------------------------------------------------------------------------


@ipaddresses = ();
@domains = ("edu");
@eventTypes = ();
%service = ();
@keywords = ();
print "\nLevel 2: getLSLocation for \"domain = edu @ the root...\n";
$result = $gls->getLSLocation( { domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
foreach my $s ( @{ $result } ) {
    $doc = $parser->parse_string( $s ); 
    print $doc->toString , "\n";
}
unless ( $#{ $result } > -1 ) {
    print "\tNothing found for search.\n";
}
