#!/usr/bin/perl -w -I../lib


=head1  NAME  

            create_landmarks.pl   - create landmarks.xml file for pinger MP
 

=head1 DESCRIPTION

    this is a script for pinger MP. It parses simple CSV file and creates
    landmarks.xml file. It can also update existing XML landmarks file by adding new nodes from the CSV file.
    The CSV filename is supplied through the --file=<filename> mandatory option.
     The format of CSV file is:
    <domain>,<node>,<hostname>,<ip>,<description>,<packetsize>,<count>,<packetInterval>,<ttl>,<measurementPeriod>,<measuermentOffset>,<project>
    First 4 parameters are required but if one of hostname or ip is missing then it will atempt to resolve the rest.
    Other parameters are optional and will be set to default values:
    <description=''>,<packetsize=1000>,<count=10>,<packetInterval=1>,<ttl=255>,<measurementPeriod=60>,<measurementOffset=0>,<project=LHCOPN>
     
     The default values could be set to different ones by using command line optional options:
      --description=''
      --packetsize=''
      --count=''
      --packetInterval=''
      --ttl=''
      --measurementPeriod=''
      --measurementOffset=''
      --project=''
      
     Other optional parameters are:
      --out=<filename> - sets the resulting filename, if skipped then default filename will 
               be created by substituting .csv extention with .xml and keeping the same base filename.
      --update=<filename>  -  use this XML landmarks file to update, if --out option is set then new file will be created if not then
               this file will be overwritten
      
      Note: if you updating an existing file then for any matching domain:node id all parameters will be overwritten from the CSV file 
            or reset to defaults if missing 
	     
	     
=head1 SYNOPSIS
     
     # create a new one
     ./create_landmarks.pl  --file=landmarks.csv --project=MYPROJECT --out=landmarks.xml
     # or update  an old one
     ./create_landmarks.pl  --file=landmarks.csv --project=MYPROJECT --update=landmarks.xml
	     
=head1 AUTHORS

     Maxim Grigoriev, maxim_at_fnal_gov    2008	     

=head1   Functions

=cut

use strict;
###use warnings;
use English qw(-no_match_vars);

use FindBin qw($Bin);
use lib "$Bin/../lib";
use Data::Dumper;
use IO::File;
use File::Copy; 
use Pod::Usage;
use Log::Log4perl qw(:easy);
use Getopt::Long;
use Text::CSV_XS;
use perfSONAR_PS::Utils::DNS qw/reverse_dns resolve_address/;

use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Name';

use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::HostName';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Description';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters::Parameter';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtl3::Topology::Domain::Node::Port';
use constant URNBASE => 'urn:ogf:network'; 

my  %options;
my %string_option_keys = (file => '',  update => '', out => '', description => '',  project => 'LHCOPN');
my %int_option_keys = (packetsize => '1000', count => '10',  packetInterval => '1', ttl => '255',
                       measurementPeriod => '60', measurementOffset => '0');

### parameter position in the row 
my %lookup_row = (description => 4, packetsize => 5, count =>  6,  packetInterval => 7, ttl => 8,
                       measurementPeriod => 9, measurementOffset => 10, project => 11);
GetOptions(
    \%options,
    map("$_=i", keys %int_option_keys), map("$_=s", keys %string_option_keys),
    qw/verbose help/,

);
if($options{verbose}) {
    Log::Log4perl->easy_init($DEBUG);
} else {
    Log::Log4perl->easy_init($INFO);
}  

my $logger = get_logger("create_landmarks");

$logger->logdie(pod2usage(-verbose => 2)) if $options{help} || !($options{file} && -e $options{file});

my $landmark_obj;
if($options{update} && -e $options{update}) {
    $options{out} = $options{update} unless  $options{out};
    eval {
        local ( $/, *fd_in );
        my $fd_in  = new IO::File($options{update}) or die " Failed to open landmarks $options{update} ";
        my $text = <$fd_in>;
        $landmark_obj  = Topology->new( { xml => $text } );      
        $fd_in->close;
    };
    if ($EVAL_ERROR) {
        $logger->logdie( " Failed to load landmarks $options{update}  $EVAL_ERROR" );
    }    
} else {
    $landmark_obj = Topology->new();
}
unless($options{out}) {
    $options{out} = $options{file};
    $options{out} =~ s/\.\w+$/\.xml/;
}
my %all_options = (%string_option_keys, %int_option_keys);
foreach my $opt (keys %all_options) {
    $options{$opt} =  $all_options{$opt} unless  $options{$opt};
}  
###    0       1           2         3         4           5          6          7            8          9                    10             11
###<domain>,<node_name>,<hostname>,<ip>,<description>,<packetsize>,<count>,<packetInterval>,<ttl>,<measurementPeriod>,<measuermentOffset>,<project>
my %dns_cache = ();   
my %reverse_dns_cache = ();  
my $num=0;
my $io_file = IO::File->new($options{file});
my $csv_obj = Text::CSV_XS->new ();
while(my $row = $csv_obj->getline($io_file)) {
    unless($row->[0] && $row->[1] && ($row->[2] || $row->[3])) {
       $logger->error(" Skipping Malformed row: domain=$row->[0]  node=$row->[1] hostname=$row->[2] ip=$row->[3]");
       next;
    } 
    check_row($row, \%options, \%dns_cache, \%reverse_dns_cache , \%lookup_row ); 
    my $domain_id = URNBASE . ":domain=$row->[0]";
    my $domain_obj = $landmark_obj->getDomainById($domain_id);
    unless($domain_obj) {
    	$domain_obj = Domain->new({id => $domain_id});
	$landmark_obj->addDomain($domain_obj);		      
    }   
    my $node_id =  "$domain_id:node=$row->[1]";
    my $node_obj =  $domain_obj->getNodeById($node_id);
    $domain_obj->removeNodeById($node_id)  if($node_obj);
    eval {
     	 $node_obj = Node->new({
    			     id =>  $node_id,
			     name =>  Name->new(  { type => 'string', text =>  $row->[1]} ),
			     hostName =>  HostName->new( { text => $row->[2] } ),   
			     description => Description->new( { text => $row->[4] }),
    			     port =>  Port->new(
    					 { xml =>  qq{
<nmtl3:port xmlns:nmtl3="http://ogf.org/schema/network/topology/l3/20070707/" id="$node_id:port=$row->[3]">
    <nmtl3:ipAddress type="IPv4">$row->[3]</nmtl3:ipAddress>
</nmtl3:port>
}
    					 }
    				   ),
    			    parameters =>  Parameters->new(
    					{  xml => qq{
<nmwg:parameters xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/" id="paramid$num">
     <nmwg:parameter name="packetSize">$row->[5]</nmwg:parameter>
     <nmwg:parameter name="count">$row->[6]</nmwg:parameter>
     <nmwg:parameter name="packetInterval">$row->[7]</nmwg:parameter>
     <nmwg:parameter name="ttl">$row->[8]</nmwg:parameter> 
     <nmwg:parameter name="measurementPeriod">$row->[9]</nmwg:parameter>  
     <nmwg:parameter name="measurementOffset">$row->[10]</nmwg:parameter>
     <nmwg:parameter name="project">$row->[11]</nmwg:parameter> 
 </nmwg:parameters>
}
    				       }
    			   )
    			 });
    	  $domain_obj->addNode($node_obj);
	  $num++;
    };
    if($EVAL_ERROR) {
    	$logger->logdie(" Node create failed $EVAL_ERROR");
    }
    
}
$io_file->close();
 
my $tmp_file = "/tmp/temp_LANDMARKS." . $$;
my $fd  = new IO::File(">$tmp_file")  or $logger->logdie( "Failed to open file $tmp_file" . $! );
eval {
    print $fd $landmark_obj->asString;
    $fd->close;
    move($tmp_file, $options{out});
};
if($EVAL_ERROR) {
    $logger->logdie( "Failed to store new xml landmarks file $EVAL_ERROR "  );
}
 
=head2 check_row 

     set missing values from defaults, resolve DNS name or IP address

=cut

sub check_row {
    my( $row, $options_h, $dns_cache_h, $reverse_dns_cache_h, $lookup_row_h) = @_;
    unless($row->[2]) {
        unless($reverse_dns_cache_h->{$row->[3]}) {
            $row->[2] = reverse_dns($row->[3]);
	     $reverse_dns_cache_h->{$row->[3]} =  $row->[2];
        } else {
	    $row->[2] = $reverse_dns_cache_h->{$row->[3]}; 
	}
    }
    unless($row->[3]) {
        unless($dns_cache_h->{$row->[2]}) {
            ($row->[3]) =  resolve_address($row->[2]);
            $dns_cache_h->{$row->[2]} =  $row->[3];
        } else {
	    $row->[3] = $dns_cache_h->{$row->[2]};
	}
    }
    foreach my $key (keys %{$lookup_row_h}) {
        $row->[$lookup_row_h->{$key}] = $options_h->{$key}  unless $row->[$lookup_row_h->{$key}];
    }
}

1;

__END__



=head1 SEE ALSO

 
To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: create_landmarks.pl 2735 2009-04-08 18:11:43Z maxim $

=head1 AUTHOR

Maxim Grigoriev, maxim_at_fnal_dot_gov

=head1 LICENSE

You should have received a copy of  the Fermitools license
along with this software. If not, see
<http://fermitools.fnal.gov/about/terms.html>

=head1 COPYRIGHT

Copyright (c)  2009,   Fermi Research Alliance (FRA)

All rights reserved.

=cut
