package perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::Element;
use strict;
use warnings;
use version;our $VERSION = qw("v2.0");
use base 'Exporter';

=head1 NAME

perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::Element -  static class for basic element manipulations

=head1 DESCRIPTION

it exports only single call - getElement which allows to create XML DOM out of perl object
This module was automatically build by L<XML::RelaxNG::Compact::PXB>.

=cut

our @EXPORT_OK   = qw(&getElement);

use Readonly;
use Scalar::Util qw(blessed);
use XML::LibXML;
use Log::Log4perl qw(get_logger);
use Data::Dumper;
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::Element';
Readonly::Hash   our %NSREGISTRY => ( 'pingertopo' => 'http://ogf.org/ns/nmwg/tools/pinger/landmarks/1.0/',
 'topo' => 'http://ggf.org/ns/nmwg/topology/2.0/',
 'nmtl2' => 'http://ogf.org/schema/network/topology/l2/20070707/',
 'nmwg' => 'http://ggf.org/ns/nmwg/base/2.0/',
 'nmtl3' => 'http://ogf.org/schema/network/topology/l3/20070707',
 'nmwgr' => 'http://ggf.org/ns/nmwg/result/2.0/',
 'xsd' => 'http://www.w3.org/2001/XMLSchema',
 'nmtl4' => 'http://ogf.org/schema/network/topology/l4/20070707',
 'xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
 'SOAP-ENV' => 'http://schemas.xmlsoap.org/soap/envelope/',
 'nmtb' => 'http://ogf.org/schema/network/topology/base/20070707/',
 'pinger' => 'http://ggf.org/ns/nmwg/tools/pinger/2.0/',
 'select' => 'http://ggf.org/ns/nmwg/ops/select/2.0/',
 'nmtm' => 'http://ggf.org/ns/nmwg/time/2.0/',
 'nmtopo' => 'http://ogf.org/schema/network/topology/base/20070707/',
 'nmwgt' => 'http://ggf.org/ns/nmwg/topology/2.0/',
);

our $LOGGER = get_logger($CLASSPATH);

=head1 METHODS

=head2    getElement ()

 create   element from some data struct and return it as DOM
 accepts 1 parameter - hashref to hash of keyd parameters

 where:
 
  'name' =>  name of the element
 
  'ns' => [ namespace id1, namespace id2 ...] array ref
 
  'parent' => parent DOM if provided ( element will be created in context of the parent),
 
  'attributes' =>  arrayref to the array of attributes pairs,
                   where to get i-th attribute one has to  $attr->[i]->[0] for  name  and  $attr->[i]->[1]  for value
 
  'text' => <CDATA>

 creates  new   element, returns this element

=back

=cut

sub  getElement {
    my $param = shift;
    my $data;
    unless($param && ref($param) eq 'HASH' &&  $param->{name}) {
       $LOGGER->logdie(" Need single hashref parameter as { name => '',  parent => DOM_obj, attributes => [], text => ''} with at least name key defined");
    }
    my $name =   $param->{name};
    my $attrs =  $param->{attributes};
    my $text =   $param->{text};
    my $nss =    $param->{ns}; ## reference to array ref with ns prefixes for this element
   
    if($param->{parent} && blessed($param->{parent}) && $param->{parent}->isa('XML::LibXML::Document')) {
        $data =  $param->{parent}->createElement($name);
    } else {
        $data =  XML::LibXML::Element->new($name);
    }
    ## validation of the namespace prefixes  registered
    if($nss)  {
        foreach my $ns (@{$nss}) {
            next unless $ns;
            unless($NSREGISTRY{$ns}) {
     	 	$LOGGER->error("Attempted to create element with un-supported namespace prefix"); 
     	    }
            $data->setNamespace($NSREGISTRY{$ns}, $ns, 1);
        }
    } else {
        $LOGGER->error("Attempted to create element without namespace");
    }
    if(($attrs && ref($attrs) eq 'ARRAY') || $text) {
        if($attrs && ref($attrs) eq 'ARRAY') {
            foreach my $attr (@{$attrs}) {
        	if($attr->[0] && $attr->[1]) {
        	    unless(ref($attr->[1]))   {
        		$data->setAttribute($attr->[0], $attr->[1]);
        	    } else {
        		$LOGGER->warn("Attempted to create ".$attr->[0]." with this: ".$attr->[1]." dump:" . sub { Dumper($attr->[1])});
        	    }
        	}
            }
        }
        if($text)  {
            unless(ref($text)) {
        	my $text_el = XML::LibXML::Text->new($text);
        	$data->appendChild($text_el);
            }  else {
        	$LOGGER->warn(" Attempted to create text with non scalar: $text dump:" . sub {Dumper($text)});
            }
        }
    } else {
        $LOGGER->warn(" Attempted to create empty element with name $name, failed to do so, will return undef ");
    }
    return $data;
}



1;

__END__


=head1  SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

   https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

   http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

   http://code.google.com/p/perfsonar-ps/issues/list
   

=head1 AUTHOR

Maxim Grigoriev

=head1 COPYRIGHT

Copyright (c) 2008, Fermi Research Alliance (FRA)

=head1 LICENSE

You should have received a copy of the Fermitool license along with this software.

=cut


