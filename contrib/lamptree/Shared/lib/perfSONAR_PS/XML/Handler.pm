package perfSONAR_PS::XML::Handler;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

Handler

=head1 DESCRIPTION

A module that acts as an XML element handler for a SAX parser (Specifically from
the XML::SAX family).  The job of a handler is to listen for SAX events, and act
on the information that is passed from the parsing system above.  The particular 
handler relies on objects of type 'Element' for storage, and requires the use of
an external stack to manage intereactions of these objects.  

=cut

use Exporter;
use Data::Stack;
use perfSONAR_PS::XML::Element;
use Carp qw( croak );
our @ISA    = qw( Exporter );
our @EXPORT = ();

=head2 new($package, $stack)

The '\%conf' hash contains arguments supplied to the service by the user (such as log files). 
Creates a new handler object, a external stack (of type Data::Stack) MUST
be passed in.  This stack is the only way to access the finished element
tree after parsing has finished.  

=cut

sub new {
    my ( $package, $stack ) = @_;
    my %hash = ();
    $hash{"FUNCTION"} = "\"new\"";
    $hash{"FILENAME"} = "Handler";
    if ( defined $stack ) {
        $hash{"STACK"} = $stack;
    }
    else {
        croak( $self->{FILENAME} . ":\tStack argument required in " . $self->{FUNCTION} );
    }
    bless \%hash => $package;
    return;
}

=head2 start_document($self)

This event indicates the document has started parsing, it is not used in 
this handler.  

=cut

sub start_document {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"start_document\"";

    # unused for now
    return;
}

=head2 end_document($self)

This event indicates the document is done parsing, it is not used in this
handler.  

=cut

sub end_document {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"end_document\"";

    # unused for now
    return;
}

=head2 start_element($self, $element)

When an element is started, we allocate a new element object and populate
it with the necessary information:

  Local Name - Non-prefixed name of the element
  Prefix - Prefix that maps to a namespace URI.
  Namespace URI - URI that indicates an element's membership.
  Qualified Name - Prefix + Local Name of an element.
  Attributes - name/value pairs of information in the element.
  Children - Array of child elements that are 'within' this element.
  Parent - The element that the 'parent' (directly above) this element.
  
Additionally, we keep track of namespace nesting to ensure that namespaces
are only declared once per scope.  The element, once populated, is pushed on
to the stack, and the previous top of the stack is marked as the 'parent' of
this element.  

=cut

sub start_element {
    my ( $self, $element ) = @_;
    $self->{FUNCTION} = "\"start_element\"";
    if ( defined $element ) {
        my $newElement = new perfSONAR_PS::XML::Element();

        if ( defined $self->{NSDEPTH}{ $element->{Prefix} } ) {
            $self->{NSDEPTH}{ $element->{Prefix} }++;
        }
        else {
            $self->{NSDEPTH}{ $element->{Prefix} } = 1;
            $newElement->addAttribute( "xmlns:" . $element->{Prefix}, $element->{NamespaceURI} );
        }

        my %attrs = %{ $element->{Attributes} };
        foreach my $a ( keys %attrs ) {
            if ( $attrs{$a}{Prefix} ne "xmlns" and $attrs{$a}{NamespaceURI} ne "http://www.w3.org/2000/xmlns/" ) {
                $newElement->addAttribute( $attrs{$a}{Name}, $attrs{$a}{Value} );
            }
        }

        $newElement->setParent( $self->{STACK}->peek() );
        if ( $newElement->getAttributeByName( "id" ) eq q{} ) {
            $newElement->setID( genuid() );
        }
        else {
            $newElement->setID( $newElement->getAttributeByName( "id" ) );
        }
        $newElement->setPrefix( $element->{Prefix} );
        $newElement->setURI( $element->{NamespaceURI} );
        $newElement->setLocalName( $element->{LocalName} );
        $newElement->setQName( $element->{Name} );

        $self->{STACK}->peek()->addChild( $newElement );
        $self->{STACK}->push( $newElement );
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 end_element($self, $element)

When the end of an element is seen we must pop the stack (to indicate that
this element has ended) and expose the next 'parent' element.  We also update
the namespace counter.  

=cut

sub end_element {
    my ( $self, $element ) = @_;
    $self->{FUNCTION} = "\"end_element\"";
    if ( defined $element ) {
        if ( $self->{STACK}->empty() ) {
            croak( $self->{FILENAME} . ":\tPop on empty stack in " . $self->{FUNCTION} );
        }
        else {
            my $top = $self->{STACK}->pop();
        }

        $self->{NSDEPTH}{ $element->{Prefix} }--;
        if ( $self->{NSDEPTH}{ $element->{Prefix} } == 0 ) {
            undef $self->{NSDEPTH}{ $element->{Prefix} };
        }
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 characters($self, $characters)

If bare characters are discovered in an XML document, the 'characters' event 
is triggered.  Most times this event may indicate whitespace, and a simple 
regex can be used to exit if this is the case.  When the event is meaningful, 
we wish to pass the seen value back to the element that resides on the top of
the stack by populating it's 'Value' field.  

=cut

sub characters {
    my ( $self, $characters ) = @_;
    $self->{FUNCTION} = "\"characters\"";
    if ( defined $characters ) {
        my $text = $characters->{Data};
        $text =~ s/^\s*//;
        $text =~ s/\s*$//;
        return unless $text;
        $self->{STACK}->peek()->setValue( $text );
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 genuid()

Generates a random number.  This auxilary function is used to generate
an ID value for elements who are not assigned one.  

=cut

sub genuid {
    my ( $r ) = int( rand( 16777216 ) );
    return ( $r + 1048576 );
}

1;

__END__

=head1 SYNOPSIS
 
    use XML::SAX::ParserFactory;
    use Data::Stack;
    use Handler;
    use Element;

    my $file = "store.xml"

    # set up the stack
    my $stack = new Data::Stack();
    my $sentinal = new Element();
    $sentinal->setParent($sentinal);
    $stack->push($sentinal);

    # parse with a custom handler
    my $handler = Handler->new($stack);
    my $p = XML::SAX::ParserFactory->parser(Handler => $handler);
    $p->parse_uri($file);

    #get the object of the 'root' element
    my $element = $stack->peek()->getChildByIndex(0);

    #print the element
    $element->print();

=head1 SEE ALSO

L<Element>, L<XML::SAX>, L<Data::Stack>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Handler.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut
