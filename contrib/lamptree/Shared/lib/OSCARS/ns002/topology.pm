
#PASTOR: Code generated by XML::Pastor/1.0.3 at 'Wed Jul  1 15:32:04 2009'

use utf8;
use strict;
use warnings;
no warnings qw(uninitialized);

use XML::Pastor;



#================================================================

package OSCARS::ns002::topology;

use OSCARS::ns002::Type::CtrlPlaneTopologyContent;

our @ISA=qw(OSCARS::ns002::Type::CtrlPlaneTopologyContent XML::Pastor::Element);

OSCARS::ns002::topology->XmlSchemaElement( bless( {
                 'baseClasses' => [
                                    'OSCARS::ns002::Type::CtrlPlaneTopologyContent',
                                    'XML::Pastor::Element'
                                  ],
                 'class' => 'OSCARS::ns002::topology',
                 'isRedefinable' => 1,
                 'metaClass' => 'OSCARS::Pastor::Meta',
                 'name' => 'topology',
                 'scope' => 'global',
                 'targetNamespace' => 'http://ogf.org/schema/network/topology/ctrlPlane/20080828/',
                 'type' => 'CtrlPlaneTopologyContent|http://ogf.org/schema/network/topology/ctrlPlane/20080828/'
               }, 'XML::Pastor::Schema::Element' ) );

1;


__END__



=head1 NAME

B<OSCARS::ns002::topology>  -  A class generated by L<XML::Pastor> . 


=head1 ISA

This class descends from L<OSCARS::ns002::Type::CtrlPlaneTopologyContent>, L<XML::Pastor::Element>.


=head1 CODE GENERATION

This module was automatically generated by L<XML::Pastor> version 1.0.3 at 'Wed Jul  1 15:32:04 2009'


=head1 SEE ALSO

L<OSCARS::ns002::Type::CtrlPlaneTopologyContent>, L<XML::Pastor::Element>, L<XML::Pastor>, L<XML::Pastor::Type>, L<XML::Pastor::ComplexType>, L<XML::Pastor::SimpleType>


=cut
