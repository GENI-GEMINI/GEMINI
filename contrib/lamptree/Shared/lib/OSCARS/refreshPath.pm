
#PASTOR: Code generated by XML::Pastor/1.0.3 at 'Wed Jul  1 15:32:04 2009'

use utf8;
use strict;
use warnings;
no warnings qw(uninitialized);

use XML::Pastor;



#================================================================

package OSCARS::refreshPath;

use OSCARS::Type::refreshPathContent;

our @ISA=qw(OSCARS::Type::refreshPathContent XML::Pastor::Element);

OSCARS::refreshPath->XmlSchemaElement( bless( {
                 'baseClasses' => [
                                    'OSCARS::Type::refreshPathContent',
                                    'XML::Pastor::Element'
                                  ],
                 'class' => 'OSCARS::refreshPath',
                 'isRedefinable' => 1,
                 'metaClass' => 'OSCARS::Pastor::Meta',
                 'name' => 'refreshPath',
                 'scope' => 'global',
                 'targetNamespace' => 'http://oscars.es.net/OSCARS',
                 'type' => 'refreshPathContent|http://oscars.es.net/OSCARS'
               }, 'XML::Pastor::Schema::Element' ) );

1;


__END__



=head1 NAME

B<OSCARS::refreshPath>  -  A class generated by L<XML::Pastor> . 


=head1 ISA

This class descends from L<OSCARS::Type::refreshPathContent>, L<XML::Pastor::Element>.


=head1 CODE GENERATION

This module was automatically generated by L<XML::Pastor> version 1.0.3 at 'Wed Jul  1 15:32:04 2009'


=head1 SEE ALSO

L<OSCARS::Type::refreshPathContent>, L<XML::Pastor::Element>, L<XML::Pastor>, L<XML::Pastor::Type>, L<XML::Pastor::ComplexType>, L<XML::Pastor::SimpleType>


=cut
