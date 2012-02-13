#!/usr/local/bin/perl -w
# -*- perl -*-
#-------------------------------------------------------------------------
#         former dump-targets script converted to create perfSONAR 
#             XML configuration files
#                  Maxim Grigoriev, maxim@fnal.gov,  09.2006
#
# See embedded POD below for further information
#
#-------------------------------------------------------------------------
# Cricket: a configuration, polling and data display wrapper for RRD files
#
#    Copyright (C) 1998 Jeff R. Allen and WebTV Networks, Inc.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.



  
### ddefault value of cricket  base - location of cricket-conf.pl
BEGIN {
        my $programdir = (($0 =~ m:^(.*/):)[0] || "./") . "..";
        eval "require '$programdir/cricket-conf.pl'";
        eval "require '/usr/local/etc/cricket-conf.pl'"
                                        unless $Common::global::gInstallRoot;
        $Common::global::gInstallRoot ||= $programdir;
}
use lib "$Common::global::gInstallRoot/lib";

use strict; 
use Getopt::Long;
 
my $fname = '';
my $help = '';
my $dss = 'ifInOctets,ifOutOctets';
my $nets = '';
my $domain = "Fermilab";
my $ctree = '/';
my $vvv = '';

GetOptions (   
             "ctree=s" => \$ctree, 
             "help|?|h" => \$help, 
             "fname=s" => \$fname, 
	     "verbose" => \$vvv, 
	     "domain=s" => \$domain,
	     "dss=s" => \$dss, 
	     "nets=s" => \$nets) or pod2usage(2) ; 
	
 
use Net::Netmask; 
use Pod::Usage;
use Common::Log;
use Common::global;
use ConfigTree::Cache;
  		 
$Common::global::gCT = new ConfigTree::Cache;
my $gCT = $Common::global::gCT;
$gCT->Base($Common::global::gConfigRoot);
$gCT->Warn(\&Warn);

 
pod2usage(1) if $help;
pod2usage(2)  unless $fname;
###### create hash with CIDRs as keys and Net objects  
my $subnets = {};

if($nets) {
    my @netblocks = split ",", $nets;
    foreach my $net ( @netblocks) {
      my $net_table = new  Net::Netmask($net); 
      $net_table->storeNetblock([$subnets]);
    }
}

if (! $gCT->init()) {
    Die("Failed to open compiled config tree from " .
		"$Common::global::gConfigRoot/config.db: $!");
}


my $header =  qq(<?xml version="1.0" encoding="UTF-8"?>


<!-- ===================================================================
<description>
   MA RRD configuration file

   \$Id: cricket2SONAR.pl 2640 2009-03-20 01:21:21Z zurawski $fname,v 1.10 2005/10/25 05:39:08 zurawski Exp \$
   project: perfSONAR

Notes:
   This is the configuration file which contains the information 
   about RRD files from  $domain

</description>
==================================================================== -->

<nmwg:store xmlns="http://ggf.org/ns/nmwg/base/2.0/" 
                 xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/" 
                 xmlns:netutil="http://ggf.org/ns/nmwg/characteristic/utilization/2.0/" 
                 xmlns:nmwgt="http://ggf.org/ns/nmwg/topology/2.0/"> 
		 
		 <!--  metadata section  -->
);
 
my $targetCnt = 1;
my %dss_check = map {$_, 1} split ",", $dss; ## converting string into hash for later check
    
my @ctrees =   split ",", $ctree; 
my %dss_h = ();
foreach my $subtree (@ctrees) {
    if ($gCT->nodeExists( $subtree )) {
        $gCT->visitLeafs($subtree, \&makePerfSONAR );
    } else {
        Warn("Unknown subtree: $subtree.");
    }
}
printPerfSONAR($header, $fname );
exit;

####################################
#
#     print XML into file or STDOUT
#
#
sub printPerfSONAR {
   my($header, $fname) = @_;
   if($fname) {
       open OUT, ">$fname" or die " Could not open the file: $fname $! "; 
   } else {
    *OUT = *STDOUT;
   }
   print OUT  $header;
   my $cnt = 1;
   foreach my $rrd_file ( keys %dss_h ) {
    foreach my  $rrd_ds_name (keys %{$dss_h{$rrd_file}}) {
     
       my   $host = $dss_h{$rrd_file}{$rrd_ds_name}{host};
       my   $ipaddr =  $dss_h{$rrd_file}{$rrd_ds_name}{ipv4} ;
       
        unless($ipaddr and $host) {Warn("Unknown IP=$ipaddr or Hostname=$host");next;}
 
        next if( $nets && !(findNetblock($ipaddr, [$subnets])));
       
       my   $direction  = lc($rrd_ds_name) ;
            $direction =~ s/^if(in|out).+/$1/;
       my   $descr = $dss_h{$rrd_file}{$rrd_ds_name}{descr};
            $descr = "N/A" unless $descr;
       my   $interface = $dss_h{$rrd_file}{$rrd_ds_name}{interface};
       my   $rrd_ds= $dss_h{$rrd_file}{$rrd_ds_name}{rrd_ds};
       my   $rrd_max = $dss_h{$rrd_file}{$rrd_ds_name}{rrd_max};    
       print OUT qq(
       <nmwg:metadata  xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/" id="meta$cnt">
	 <netutil:subject  xmlns:netutil="http://ggf.org/ns/nmwg/characteristic/utilization/2.0/" id="subj$cnt">
               <nmwgt:interface xmlns:nmwgt="http://ggf.org/ns/nmwg/topology/2.0/"> 
	          <nmwgt:hostName>$host</nmwgt:hostName>
                   <nmwgt:ifAddress type="ipv4">$ipaddr</nmwgt:ifAddress>
                   <nmwgt:ifName>$interface</nmwgt:ifName>
                   <nmwgt:ifDescription>$descr</nmwgt:ifDescription>
		   <nmwgt:direction>$direction</nmwgt:direction>\n);
	   $rrd_max?print OUT "                   <nmwgt:capacity>$rrd_max</nmwgt:capacity>\n":
           $interface =~ /tengigabit/i?print OUT "                   <nmwgt:capacity>10000000000</nmwgt:capacity>\n":
	      $interface =~ /gigabit/i?print OUT "                   <nmwgt:capacity>1000000000</nmwgt:capacity>\n":print;              
       print OUT qq(                   <nmwgt:authRealm>$domain</nmwgt:authRealm>
               </nmwgt:interface>
             </netutil:subject>  
	     <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType> 
            <nmwg:parameters>
                   <nmwg:parameter name="supportedEventType">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>
          </nmwg:parameters>
	</nmwg:metadata>
	  <nmwg:data xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/" id="data$cnt" metadataIdRef="meta$cnt">
           <nmwg:key>
               <nmwg:parameters> 
	           <nmwg:parameter name="supportedEventType">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>
	           <nmwg:parameter name="type">rrd</nmwg:parameter>
                   <nmwg:parameter name="valueUnits">Bps</nmwg:parameter>
                   <nmwg:parameter name="file">$rrd_file</nmwg:parameter>
                   <nmwg:parameter name="dataSource">$rrd_ds</nmwg:parameter>
		   <nmwg:parameter name="unit">bps</nmwg:parameter> 
               </nmwg:parameters>
           </nmwg:key>
	</nmwg:data>

	);
    $cnt++;     
   } 
    
   }
   print OUT "</nmwg:store>\n";
   close OUT;
}
#########
#
#  callback for every config tree
#
sub makePerfSONAR {
    my($name) = @_;

    my($tpath, $tname) = ($name =~ /^(.*)\/(.*)$/);
    
    print  " -----------------------------------------------\n" if $vvv;
    my($target) = $gCT->configHash($name, 'target', undef , 1);
     
    foreach my $type (qw/targettype/) {
	my($tmp_dict) = $gCT->configHash(  join('/',
	                                         $target->{'auto-target-path'},  
	                                         $target->{'auto-target-name'}),
	                                   'targettype',
                                           lc($target->{'target-type'}),
					   $target );
	print  " $type dictionary for $tname\n" if $vvv;
        my($Counter) = 0;
        my(%dsMap) = map { $_ => $Counter++ } split(/\s*,\s*/,$tmp_dict ->{'ds'});
            
     #    foreach my $k (sort (keys(%{$tmp_dict}))) {
     #	  my $v = $tmp_dict->{$k};
     #	  print "\t$k = $v\n" if $vvv;
     #    } 
         (my $rrd_fl = $target->{'rrd-datafile'}) =~ s/\/([^\/]+\/\.\.\/|\/)/\//g;
	 my %router_names = ();
	foreach my $k (sort  (keys(%dsMap))) {
		 my $v = $dsMap{$k};
		 if($dss_check{$k}) {
		  $dss_h{$rrd_fl}{$k}{host} =  $target->{'router'};
		  $dss_h{$rrd_fl}{$k}{ipv4} =  $target->{'ip'};  
		  unless($target->{'ip'}) {
		     if($router_names{$target->{'router'}}) {
		         $dss_h{$rrd_fl}{$k}{ipv4} = $router_names{$target->{'router'}};
		     } else {
		         $dss_h{$rrd_fl}{$k}{ipv4} = get_nameip($target->{'router'});
		         $router_names{$target->{'router'}} = $dss_h{$rrd_fl}{$k}{ipv4};
		    }
	          } 
		  $dss_h{$rrd_fl}{$k}{rrd_ds} =   "ds$v";
		  $dss_h{$rrd_fl}{$k}{interface} =  $tname;
		  $dss_h{$rrd_fl}{$k}{rrd_max} =  $target->{'rrd-max'};
		   
		  
		  $dss_h{$rrd_fl}{$k}{descr} = $target->{'short-desc'};
		  }
		   
		print "\t$k = $v\n" if $vvv;
        }
	 
    }
	
	print "\n" if $vvv;

}

sub get_nameip {
 my $ipname = shift;
  my $s2_ip = qx($Common::global::gInstallRoot/util/rname.sh  $ipname);
  chomp $s2_ip;
  return  undef if($s2_ip eq "NODNS");
  return $s2_ip;
 
}

__END__



=head1 NAME

B<cricket2SONAR.pl> - parse Cricket configuration files and convert datasources  of interest into perfSONAR XML config file

=head1 SYNOPSIS

B<cricket2SONAR.pl> S<[B<--help>]>
                    S<[B<--ctree>=F<CSV LIST>]>
		    S<[B<--fname>=F<FILENAME>]>
		    S<[B<--dss>=F<CSV LIST>]>
		    S<[B<--nets>=F<CSV LIST>]>	
		    S<[B<--domain>=F<NAME>]>	   
                    S<[B<--verbose>]> 



=head1 DESCRIPTION

Parses the Cricket configuration tree and prints out  perfSONAR XML configuration file
 based on supplied list of datasources and network block for devices of interest ( in CIDR format with block prefix )  



=head1 OPTIONS

Nearly all options have a built in default, that can be overwritten using
command line arguments.  


=over


=item B<--help>

Prints a help/usage message and exits.

 
 
 =item B<--ctree>=F<CVS LIST>

 Comma separated list of   Cricket config trees ( example: '/switches,/routers' )
 DEFAULT: /  
 
=item B<--fname>=F<FILENAME>

 Full filename of the resulting perfSONAR config file.
 DEFAULT: all will be printed to STDOUT
 
=item <--dss>=F<CSV LIST>

 Comma separated list of datasources to look for in the Cricket targets.Example: 'ifInOctets,ifOutOctets'
 DEFAULT: Accept all supported datasources ( 'ifInOctets,ifOutOctets' only for now)
 
=item B<--nets>=F<CSV LIST>

 Comma separated list of netblocks to match.Example: '131.225.0.1/16,137.221.223.1/22'> 
 DEFAULT: Accept all netblocks 

=item B<--domain>=F<NAME>

 Name of authorative domain/realm 
 DEFAULT: Fermilab

=item B<--verbose>

Print additional information.
E.g. bunch of info while parsing  Cricket config tree

Configuration file: C<$vvv>
Default: disabled
 

=back
 
=head1 TODO

