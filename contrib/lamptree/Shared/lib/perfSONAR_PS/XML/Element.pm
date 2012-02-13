package perfSONAR_PS::XML::Element;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

Element - A module that captures the values of a typical XML element, including 
references to parents, children, attributes, namespaces, and all enclosing 
information.

=head1 DESCRIPTION

The purpose of this module is to mimic the behavior of the GGF's NM-WG parsing
elements found in the java implementation of perfSONAR.  Although the java
version consists of a single specialized element for each known XML element,
this class presents a generic 'element' structure that can be configured in any
possible way.

=cut

use Carp qw( croak );
@ISA    = ( 'Exporter' );
@EXPORT = ();

#use overload '""' => 'print';

=head2 new($package)

Creates a new object, does not support the passing of any initial values.  

=cut

sub new {
    my ( $package ) = @_;
    my %hash = ();
    $hash{"FUNCTION"} = "\"new\"";
    $hash{"FILENAME"} = "Element";
    bless \%hash => $package;
    return;
}

=head2 setParent($self, $parent)

The parent is the element that directly encloses a particular element.  This
method allows a reference to be set so the parent can be easily tracked.

=cut

sub setParent {
    my ( $self, $parent ) = @_;
    $self->{FUNCTION} = "\"setParent\"";
    if ( defined $parent ) {
        $self->{Parent} = $parent;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getParent($self)

Returns the value of the parent element.

=cut

sub getParent {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"getParent\"";
    if ( defined $self->{Parent} ) {
        return $self->{Parent};
    }
    else {
        return;
    }
}

=head2 setID($self, $id)

If an element contains an attribute for 'id', it is set here.  Otherwise a
randomly genereated number will be used.

=cut

sub setID {
    my ( $self, $id ) = @_;
    $self->{FUNCTION} = "\"setID\"";
    if ( defined $id ) {
        $self->{ID} = $id;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getID($self)

Returns the id value of an element.

=cut

sub getID {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"getID\"";
    if ( defined $self->{ID} ) {
        return $self->{ID};
    }
    else {
        return;
    }
}

=head2 setPrefix($self, $prefix)

Sets the 'prefix', a shortcut that maps a string to the namespace URI for an element.

=cut

sub setPrefix {
    my ( $self, $prefix ) = @_;
    $self->{FUNCTION} = "\"setPrefix\"";
    if ( defined $prefix ) {
        $self->{Prefix} = $prefix;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getPrefix($self)

Returns the prefix of an element.

=cut

sub getPrefix {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"getPrefix\"";
    if ( defined $self->{Prefix} ) {
        return $self->{Prefix};
    }
    else {
        return;
    }
}

=head2 setURI($self, $uri)

Sets the URI of the namespace for an element.  

=cut

sub setURI {
    my ( $self, $uri ) = @_;
    $self->{FUNCTION} = "\"setURI\"";
    if ( defined $uri ) {
        $self->{URI} = $uri;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getURI($self)

Returns the namespace URI of an element.

=cut

sub getURI {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"getURI\"";
    if ( defined $self->{URI} ) {
        return $self->{URI};
    }
    else {
        return;
    }
}

=head2 setLocalName($self, $localname)

Sets the local (non namespace tied) name of an element. 

=cut

sub setLocalName {
    my ( $self, $localname ) = @_;
    $self->{FUNCTION} = "\"setLocalName\"";
    if ( defined $localname ) {
        $self->{LocalName} = $localname;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getLocalName($self)

Returns the local (non-prefixed) name of an element.

=cut

sub getLocalName {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"getLocalName\"";
    if ( defined $self->{LocalName} ) {
        return $self->{LocalName};
    }
    else {
        return;
    }
}

=head2 setQName($self, $qname)

Sets the qualified (prefixed to a namespace) name of an element.

=cut

sub setQName {
    my ( $self, $qname ) = @_;
    $self->{FUNCTION} = "\"setQName\"";
    if ( defined $qname ) {
        $self->{QName} = $qname;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getQName($self)

Returns the qualified (prefixed) name of an element.

=cut

sub getQName {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"getQName\"";
    if ( defined $self->{QName} ) {
        return $self->{QName};
    }
    else {
        return;
    }
}

=head2 setValue($self, $value)

Sets the text value of an element.

=cut

sub setValue {
    my ( $self, $value ) = @_;
    $self->{FUNCTION} = "\"setValue\"";
    if ( defined $value ) {
        $self->{Value} = $value;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getValue($self)

Returns the text value of an element.

=cut

sub getValue {
    my ( $self ) = @_;
    $self->{FUNCTION} = "\"getValue\"";
    if ( defined $self->{Value} ) {
        return $self->{Value};
    }
    else {
        return;
    }
}

=head2 addChild($self, $child)

Adds the element 'child' to the child array of an element.

=cut

sub addChild {
    my ( $self, $child ) = @_;
    $self->{FUNCTION} = "\"addChild\"";
    if ( defined $child ) {
        my @array;
        if ( $self->{Children} ) {
            @array = @{ $self->{Children} };
        }
        else {
            @array = ();
        }
        push @array, $child;
        $self->{Children} = \@array;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getChildByName($self, $childname)

Returns the 'first' child element that matches the supplied name.

=cut

sub getChildByName {
    my ( $self, $childname ) = @_;
    $self->{FUNCTION} = "\"getChildByName\"";
    if ( defined $childname ) {
        foreach my $c ( @{ $self->{Children} } ) {
            if ( $c->getLocalName() eq $childname ) {
                return $c;
            }
        }
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getChildByID($self, $childid)

Returns the child element that matches the supplied id.

=cut

sub getChildByID {
    my ( $self, $childid ) = @_;
    $self->{FUNCTION} = "\"getChildByID\"";
    if ( defined $childid ) {
        foreach my $c ( @{ $self->{Children} } ) {
            if ( $c->getID() eq $childid ) {
                return $c;
            }
        }
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getChildByIndex($self, $index)

Returns the child element for a particular 'index' value in the child element 
array.

=cut

sub getChildByIndex {
    my ( $self, $index ) = @_;
    $self->{FUNCTION} = "\"getChildByIndex\"";
    if ( defined $index ) {
        return $self->{Children}[$index];
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 addAttribute($self, $name, $value)

Adds an attribute/value pair to an element.

=cut

sub addAttribute {
    my ( $self, $name, $value ) = @_;
    $self->{FUNCTION} = "\"addAttribute\"";
    if ( defined $name and defined $value ) {
        $self->{Atributes}{$name} = $value;
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 getAttributeByName($self, $name)

Returns the value of an attribute that matches the supplied name.

=cut

sub getAttributeByName {
    my ( $self, $name ) = @_;
    $self->{FUNCTION} = "\"getAttributeByName\"";
    if ( defined $name ) {
        if ( defined $self->{Atributes}{$name} ) {
            return $self->{Atributes}{$name};
        }
        else {
            return;
        }
    }
    else {
        croak( $self->{FILENAME} . ":\tMissing argument to " . $self->{FUNCTION} );
    }
    return;
}

=head2 print($self, $indent)

Prints the XML output for a element and all of it's children. This module is overloaded
to support the standard perl print. 

=cut

sub print {
    my ( $self, $indent ) = @_;
    $self->{FUNCTION} = "\"print\"";

    if ( defined $indent ) {
        indent( $indent );
    }
    else {
        $indent = 0;
    }

    print "<", $self->{Prefix}, ":", $self->{LocalName};
    foreach my $a ( keys %{ $self->{Atributes} } ) {
        print " ", $a, "=\"", $self->{Atributes}{$a}, "\"";
    }
    if ( defined $self->{Children} ) {
        print ">\n";
        foreach my $c ( @{ $self->{Children} } ) {
            $c->print( $indent + 2 );
        }
        if ( defined $indent ) {
            indent( $indent );
        }
        print "</", $self->{Prefix}, ":", $self->{LocalName}, ">\n";
    }
    elsif ( defined $self->{Value} ) {
        print ">";
        print $self->{Value};
        print "</", $self->{Prefix}, ":", $self->{LocalName}, ">\n";
    }
    else {
        print "/>\n";
    }
    return;
}

=head2 asString($self, $index);
  
TBD

=cut

sub asString {
    my $self   = shift;
    my $index  = shift;
    my $indent = shift;

    $self->{FUNCTION} = "\"asString\"";

    my $string = q{};

    if ( defined $indent ) {
        $string .= ' ' x $indent;
    }
    else {
        $indent = 0;
    }

    $string .= "<" . $self->{Prefix} . ":" . $self->{LocalName};
    foreach my $a ( keys %{ $self->{Atributes} } ) {
        $string .= " " . $a . "=\"" . $self->{Atributes}{$a} . "\"";
    }
    if ( defined $self->{Children} ) {
        $string .= ">\n";
        foreach my $c ( @{ $self->{Children} } ) {
            $string .= $c->asString( $indent + 2 );
        }
        if ( defined $indent ) {
            $string .= ' ' x $indent;
        }
        $string .= "</" . $self->{Prefix} . ":" . $self->{LocalName} . ">\n";
    }
    elsif ( defined $self->{Value} ) {
        $string .= ">";
        $string .= $self->{Value};
        $string .= "</" . $self->{Prefix} . ":" . $self->{LocalName} . ">\n";
    }
    else {
        $string .= "/>\n";
    }
    return $string;
}

=head2 indent($indent)

Given a numeric value, prints spaces equal to this value to 'pretty print' the 
XML output.

=cut

sub indent {
    my ( $indent, $string ) = @_;
    for ( my $x = 0; $x < $indent; $x++ ) {
        if ( defined $string ) {
            return " ";
        }
        else {
            print " ";
        }
    }
    return;
}

1;

__END__

=head1 SYNOPSIS
 
    use Element;

    # consder that we wish to make this XML:
    #
    #   <nmwg:store xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/">
    #     <nmwg:metadata id="m1">
    #       <netutil:subject xmlns:netutil="http://ggf.org/ns/nmwg/characteristic/utilization/2.0/" id="s1">
    #       <nmwg:eventType>snmp.1.3.6.1.2.1.2.2.1.10</nmwg:eventType>
    #     </nmwg:metadata>
    #     <nmwg:data id="d1" metadataIdRef="m1" />
    #   </nmwg:store>

    my $store = new Element();
    $store->setLocalName("store");
    $store->setPrefix("nmwg");
    $store->setURI("http://ggf.org/ns/nmwg/base/2.0/");
    $store->setQName($store->getPrefix().":".$store->getLocalName());
    $store->addAttribute("xmlns:nmwg","http://ggf.org/ns/nmwg/base/2.0/");

    my $md = new Element();
    $md->setLocalName("metadata");
    $md->setPrefix("nmwg");
    $md->setURI("http://ggf.org/ns/nmwg/base/2.0/");
    $md->setQName($md->getPrefix().":".$md->getLocalName());
    $md->setID("m1");
    $md->addAttribute("id","m1");

    my $subject = new Element();
    $subject->setLocalName("subject");
    $subject->setPrefix("netutil");
    $subject->setURI("http://ggf.org/ns/nmwg/characteristic/utilization/2.0/");
    $subject->setQName($subject->getPrefix().":".$subject->getLocalName());
    $subject->addAttribute("xmlns:netutil","http://ggf.org/ns/nmwg/characteristic/utilization/2.0/");
    $subject->setID("s1");
    $subject->addAttribute("id","s1");

    my $event = new Element();
    $event->setLocalName("eventType");
    $event->setPrefix("nmwg");
    $event->setURI("http://ggf.org/ns/nmwg/base/2.0/");
    $event->setQName($event->getPrefix().":".$event->getLocalName());
    $event->setValue("snmp.1.3.6.1.2.1.2.2.1.10");

    my $d = new Element();
    $d->setLocalName("data");
    $d->setPrefix("nmwg");
    $d->setURI("http://ggf.org/ns/nmwg/base/2.0/");
    $d->setQName($d->getPrefix().":".$d->getLocalName());
    $d->setID("d1");
    $d->addAttribute("id","d1");
    $d->addAttribute("metadataIdRef","m1");

    $md->addChild($subject);
    $md->addChild($event);

    $store->addChild($md);
    $store->addChild($d);

    $store->print();

=head1 SEE ALSO

L<Handler>, L<XML::SAX>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Element.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
