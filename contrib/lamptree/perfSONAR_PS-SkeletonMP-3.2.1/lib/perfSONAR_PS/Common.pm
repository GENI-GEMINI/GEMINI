package perfSONAR_PS::Common;

use strict;
use warnings;

our $VERSION = 3.2;

=head1 NAME

perfSONAR_PS::Common

=head1 DESCRIPTION

A module that provides common methods for performing simple, necessary actions
within the perfSONAR-PS framework.  This module is a catch all for common
methods (for now) in the perfSONAR-PS framework.  As such there is no
'common thread' that each method shares.  This module IS NOT an object, and the
methods can be invoked directly (and sparingly).

=cut

use Exporter;
use IO::File;
use Time::HiRes qw( gettimeofday );
use Log::Log4perl qw(get_logger :nowarn);
use XML::LibXML;
use English qw( -no_match_vars );

use base 'Exporter';
our @EXPORT = qw( readXML defaultMergeMetadata countRefs genuid extract reMap consultArchive find findvalue escapeString unescapeString makeEnvelope mapNamespaces mergeConfig mergeHash mergeNodes_general );

=head2 find($node, $query, $return_first)

This function replicates the libxml "find" function. However, it formats the
query to work around some oddities in the find implementation. It converts the
XPath query to get rid of direct references like /nmwg:element and replaces them
with /*[name()='nmwg:element"] which avoids spurious 'undefined namespace'
errors. It also wraps the find in an eval and returns 'undef' if ->find throws
an error. If the $return_first is set to one, the function returns only the
first node from the nodes found.

=cut

sub find {
    my ( $node, $query, $return_first ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );
    my $res;

    $logger->debug( "Query(pre-process): $query" );
    $query =~ s/\/([a-zA-Z_][a-zA-Z0-9\.\-\_]+:[a-zA-Z_][a-zA-Z0-9\.\-\_]+)\[/\/*[name()='$1' and /g;
    $query =~ s/\/([a-zA-Z_][a-zA-Z0-9\.\-\_]+:[a-zA-Z_][a-zA-Z0-9\.\-\_]+)/\/*[name()='$1']/g;
    $query =~ s/^([a-zA-Z_][a-zA-Z0-9\.\-\_]+:[a-zA-Z_][a-zA-Z0-9\.\-\_]+)\[/*[name()='$1' and /g;
    $query =~ s/^([a-zA-Z_][a-zA-Z0-9\.\-\_]+:[a-zA-Z_][a-zA-Z0-9\.\-\_]+)/*[name()='$1']/g;
    $logger->debug( "Query(post-process): $query" );

    eval { $res = $node->find( $query ); };
    if ( $EVAL_ERROR ) {
        $logger->error( "Error finding value($query): $@" );
        return;
    }

    return $res->get_node( 1 ) if $return_first and $return_first == 1;
    return $res;
}

=head2 findvalue($node, $query)

This function is analogous to the libxml "findvalue" function. However, it makes
use of the 'find' function documented above. Unlike the libxml findvalue
function, this function will only return the text contents of the first node
found.

=cut

sub findvalue {
    my ( $node, $xpath ) = @_;

    my $found_node;

    $found_node = find( $node, $xpath, 1 );

    return unless $found_node;
    return $found_node->textContent;
}

=head2 makeEnvelope($content)

Wraps the specified content in a soap envelope and returns it as a string.

=cut

sub makeEnvelope {
    my ( $content ) = @_;
    my $logger      = get_logger( "perfSONAR_PS::Common" );
    my $string      = "<SOAP-ENV:Envelope xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\"\n";
    $string .= "                   xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n";
    $string .= "                   xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n";
    $string .= "                   xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\">\n";
    $string .= "  <SOAP-ENV:Header/>\n";
    $string .= "  <SOAP-ENV:Body>\n";
    $string .= $content if $content;
    $string .= "  </SOAP-ENV:Body>\n";
    $string .= "</SOAP-ENV:Envelope>\n";
    return $string;
}

=head2 readXML($file)

Reads the file specified in '$file' and returns the XML contents in string form.
The <xml> tag will be extracted from the final returned string.  Function will
warn on error, and return an empty string.

=cut

sub readXML {
    my ( $file ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    if ( defined $file and $file ) {
        my $XML = new IO::File( "<" . $file );
        if ( $XML ) {
            my $xmlstring = q{};
            while ( <$XML> ) {
                unless ( $_ =~ m/^<\?xml.*/ ) {
                    $xmlstring .= $_;
                }
            }
            $XML->close();
            return $xmlstring;
        }
        else {
            $logger->error( "Cannot open file \"" . $file . "\"." );
        }
    }
    else {
        $logger->error( "Missing argument." );
    }

    return;
}

=head2 chainMetadata($dom)
Given a dom of objects, this function will continuously loop through performing
a 'chaining' operation to share values between metadata objects.  An example
would be:

  <nmwg:metadata id="1" xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/">
    <netutil:subject xmlns:netutil="http://ggf.org/ns/nmwg/characteristic/utilization/2.0/" id="1">
      <nmwgt:interface xmlns:nmwgt="http://ggf.org/ns/nmwg/topology/2.0/">
        <nmwgt:ifAddress type="ipv4">128.4.133.167</nmwgt:ifAddress>
        <nmwgt:hostName>stout</nmwgt:hostName>
      </nmwgt:interface>
    </netutil:subject>
    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>
  </nmwg:metadata>

  <nmwg:metadata id="2" xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/" metadataIdRef="1">
    <netutil:subject xmlns:netutil="http://ggf.org/ns/nmwg/characteristic/utilization/2.0/" id="2">
      <nmwgt:interface xmlns:nmwgt="http://ggf.org/ns/nmwg/topology/2.0/">
        <nmwgt:ifName>eth1</nmwgt:ifName>
        <nmwgt:ifIndex>3</nmwgt:ifIndex>
        <nmwgt:direction>in</nmwgt:direction>
      </nmwgt:interface>
    </netutil:subject>
    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>
  </nmwg:metadata>

    Which would then become:

  <nmwg:metadata id="2">
    <netutil:subject xmlns:netutil="http://ggf.org/ns/nmwg/characteristic/utilization/2.0/" id="1">
      <nmwgt:interface xmlns:nmwgt="http://ggf.org/ns/nmwg/topology/2.0/">
        <nmwgt:ifAddress type="ipv4">128.4.133.167</nmwgt:ifAddress>
        <nmwgt:hostName>stout</nmwgt:hostName>
        <nmwgt:ifName>eth1</nmwgt:ifName>
        <nmwgt:ifIndex>3</nmwgt:ifIndex>
        <nmwgt:direction>in</nmwgt:direction>
      </nmwgt:interface>
    </netutil:subject>
    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0/</nmwg:eventType>
  </nmwg:metadata>

This chaining is useful for 'factoring out' large chunks of XML.

=cut

sub chainMetadata {
    my ( $dom ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    if ( defined $dom and $dom ) {
        my %mdChains = ();

        my $changes = 1;
        while ( $changes ) {
            $changes = 0;
            foreach my $md ( $dom->getElementsByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "metadata" ) ) {
                if ( $md->getAttribute( "metadataIdRef" ) ) {
                    unless ( $mdChains{ $md->getAttribute( "metadataIdRef" ) } ) {
                        $mdChains{ $md->getAttribute( "metadataIdRef" ) } = 0;
                    }
                    if ( $mdChains{ $md->getAttribute( "id" ) } != $mdChains{ $md->getAttribute( "metadataIdRef" ) } + 1 ) {
                        $mdChains{ $md->getAttribute( "id" ) } = $mdChains{ $md->getAttribute( "metadataIdRef" ) } + 1;
                        $changes = 1;
                    }
                }
            }
        }

        my @sorted = sort { $mdChains{$a} <=> $mdChains{$b} } keys %mdChains;
        for my $x ( 0 .. $#sorted ) {
            $mdChains{ $sorted[$x] } = 0;
            foreach my $md ( $dom->getElementsByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "metadata" ) ) {
                if ( $md->getAttribute( "id" ) eq $sorted[$x] ) {
                    foreach my $md2 ( $dom->getElementsByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "metadata" ) ) {
                        if (    $md->getAttribute( "metadataIdRef" )
                            and $md2->getAttribute( "id" ) eq $md->getAttribute( "metadataIdRef" ) )
                        {
                            defaultMergeMetadata( $md2, $md );
                            $md->removeAttribute( "metadataIdRef" );
                            last;
                        }
                    }
                    last;
                }
            }
        }
    }
    else {
        $logger->error( "Missing argument." );
    }

    return $dom;
}

=head2 defaultMergeMetadata ($parent, $child)

This function will try to merge the specified parent metadata into the child
metadata. It will do this by first merging their subjects, then copying all the
eventTypes from the parent into the child and then merging all the parameters
blocks from the parent into the child.

=cut

sub defaultMergeMetadata {
    my ( $parent, $child, $eventTypeEquivalenceHandler ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Topology::Common" );

    $logger->debug( "Merging " . $parent->getAttribute( "id" ) . " with " . $child->getAttribute( "id" ) );

    # verify that it's not a 'key' value
    if ( defined find( $parent, "./*[local-name()='key' and namespace-uri()='http://ggf.org/ns/nmwg/base/2.0/']", 1 ) ) {
        throw perfSONAR_PS::Error_compat( "error.common.merge", "Merging with a key metadata is invalid" );
    }

    if ( defined find( $child, "./*[local-name()='key' and namespace-uri()='http://ggf.org/ns/nmwg/base/2.0/']", 1 ) ) {
        throw perfSONAR_PS::Error_compat( "error.common.merge", "Merging with a key metadata is invalid" );
    }

    # verify that the subject elements are the same namespace
    my $parent_subjects = find( $parent, "./*[local-name()='subject']", 0 );
    if ( $parent_subjects->size() > 1 ) {
        throw perfSONAR_PS::Error_compat( "error.common.merge", "Metadata " . $parent->getAttribute( "id" ) . " has multiple subjects" );
    }
    my $parent_subject = find( $parent, "./*[local-name()='subject']", 1 );

    my $child_subjects = find( $child, "./*[local-name()='subject']", 0 );
    if ( $child_subjects->size() > 1 ) {
        throw perfSONAR_PS::Error_compat( "error.common.merge", "Metadata " . $child->getAttribute( "id" ) . " has multiple subjects" );
    }
    my $child_subject = find( $child, "./*[local-name()='subject']", 1 );

    if ( not defined $child_subject and not defined $parent_subject ) {
        $logger->debug( "No subject in parent or child: " . $child->toString );
    }

    if ( defined $child_subject and defined $parent_subject ) {
        if ( $child_subject->namespaceURI ne $parent_subject->namespaceURI ) {
            throw perfSONAR_PS::Error_compat( "error.common.merge", "Metadata " . $child->getAttribute( "id" ) . " and " . $parent->getAttribute( "id" ) . " have subjects with different namespaces." );
        }

        # Merge the subjects
        defaultMergeSubject( $parent_subject, $child_subject );
    }
    elsif ( $parent_subject ) {

        # if the parent has a subject, but not the child, simply copy the subject from the parent
        $child->addChild( $parent_subject->cloneNode( 1 ) );
    }

    # Copy over the event types
    my %parent_eventTypes = ();
    my %child_eventTypes  = ();

    foreach my $ev ( $parent->getChildrenByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "eventType" ) ) {
        my $eventType = $ev->textContent;
        $eventType =~ s/^\s+//;
        $eventType =~ s/\s+$//;
        $parent_eventTypes{$eventType} = $ev;
        $logger->debug( "Found eventType $eventType in child" );
    }

    foreach my $ev ( $child->getChildrenByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "eventType" ) ) {
        my $eventType = $ev->textContent;
        $eventType =~ s/^\s+//;
        $eventType =~ s/\s+$//;
        $child_eventTypes{$eventType} = $ev;
        $logger->debug( "Found eventType $eventType in child" );
    }

    if ( $eventTypeEquivalenceHandler ) {
        my @parent_evs = keys %parent_eventTypes;
        my @child_evs  = keys %child_eventTypes;

        my $common_evs = $eventTypeEquivalenceHandler->matchEventTypes( \@parent_evs, \@child_evs );

        foreach my $ev ( keys %child_eventTypes ) {
            my $old_ev = $child->removeChild( $child_eventTypes{$ev} );
            $child_eventTypes{$ev} = $old_ev;
        }

        foreach my $ev ( @{$common_evs} ) {
            if ( not exists $child_eventTypes{$ev} ) {
                $child->addChild( $parent_eventTypes{$ev}->cloneNode( 1 ) );
            }
            else {
                $child->addChild( $child_eventTypes{$ev} );
            }
        }
    }
    else {
        if ( scalar( keys %parent_eventTypes ) > 0 or scalar( keys %child_eventTypes ) > 0 ) {

            # if we have a child metadata with nothing in it and a parent with
            # something in it, copy all the parent's over.
            if ( scalar( keys %child_eventTypes ) == 0 ) {
                foreach my $ev ( keys %parent_eventTypes ) {
                    $child->addChild( $parent_eventTypes{$ev}->cloneNode( 1 ) );
                }
            }

            # both the child and the parent have eventTypes so only save the ones in common
            elsif ( scalar( keys %parent_eventTypes ) > 0 ) {
                my $in_common = 0;

                foreach my $ev ( keys %child_eventTypes ) {
                    if ( not exists $parent_eventTypes{$ev} ) {
                        $child->removeChild( $child_eventTypes{$ev} );
                    }
                    else {
                        $in_common = 1;
                    }
                }

                unless ( $in_common ) {
                    throw perfSONAR_PS::Error_compat( "error.common.merge", "Metadata " . $child->getAttribute( "id" ) . " and " . $parent->getAttribute( "id" ) . " have no eventTypes in common" );
                }
            }
        }
    }

    # Copy over any parameter blocks
    my %params = ();
    foreach my $params_elm ( $child->getChildrenByTagNameNS( "*", "parameters" ) ) {
        $params{ $params_elm->namespaceURI } = $params_elm;
    }

    foreach my $params_elm ( $parent->getChildrenByTagNameNS( "*", "parameters" ) ) {
        if ( exists $params{ $params_elm->namespaceURI } and $params{ $params_elm->namespaceURI } ) {
            defaultMergeParameters( $params_elm, $params{ $params_elm->namespaceURI } );
        }
        else {
            $child->addChild( $params_elm->cloneNode( 1 ) );
        }
    }

    return;
}

=head2 defaultMergeParameters($parent, $child)

This function simply does a simple merge of the parent and child subject
element. If an element exists in the parent and not the child, it will be added.
If an element exists in both, an attempt will be made to merge them.  The only
special case elements are parameter elements where the 'name' attribute is
checked to verify the equivalence. In all other case, the elements name and
namespace will be compared and if they're the same, the function assumes that
the child's should supercede the parent's.

=cut

sub defaultMergeSubject {
    my ( $subject_parent, $subject_child ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Topology::Common" );

    my %comparison_attrs = ( parameter => ( name => q{} ), );

    my $new_subj = mergeNodes_general( $subject_parent, $subject_child );

    $subject_child->replaceNode( $new_subj );

    return;
}

=head2 defaultMergeParameters($parent, $child)

This function takes parent and child parameter blocks and adds each parameter
element from the parent into the child. If a parameter by the same name and
namespace already exists in the child, the function will merge the two
parameters. In the case of a parameter with only a 'value' attribute and no
body, the child's will simply replace the parent. In the case that elements
exist as children below the parameter, the parameters will be merged.

=cut

sub defaultMergeParameters {
    my ( $params_parent, $params_child ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Topology::Common" );

    my %params = ();

    # look up all the parameters in the parent block
    foreach my $param ( $params_parent->getChildrenByTagNameNS( "*", "parameter" ) ) {
        my $name = $param->getAttribute( "name" );
        my $ns   = $param->namespaceURI;

        $logger->debug( "Found parameter $name in namespace $ns in parent" );

        unless ( $name ) {
            throw perfSONAR_PS::Error_compat( "error.common.merge", "Attempting to merge a parameter with a missing 'name' attribute" );
        }

        $params{$ns} = () unless exists $params{$ns};
        $params{$ns}->{$name} = $param;
    }

    # go through the set of parameters in the child block, merging parameter
    # elements if they exist in both the child and the parent
    foreach my $param ( $params_child->getChildrenByTagNameNS( "*", "parameter" ) ) {
        my $name = $param->getAttribute( "name" );
        my $ns   = $param->namespaceURI;

        $logger->debug( "Found parameter $name in namespace $ns in child" );

        unless ( $name ) {
            throw perfSONAR_PS::Error_compat( "error.common.merge", "Attempting to merge a parameter with a missing 'name' attribute" );
        }

        if ( exists $params{$ns}->{$name} and $params{$ns}->{$name} ) {
            $logger->debug( "Merging parameter $name in namespace $ns with parameter in parent" );

            $params{$ns} = () unless exists $params{$ns};
            my $new_param = mergeNodes_general( $params{$ns}{$name}, $param );
            $param->replaceNode( $new_param );
            delete $params{$ns}->{$name};
        }
    }

    # add any parameters that exist in the parent and not in the child
    foreach my $ns ( keys %params ) {
        foreach my $name ( keys %{ $params{$ns} } ) {
            $params_child->addChild( $params{$ns}->{$name}->cloneNode( 1 ) );
        }
    }

    return;
}

=head2 mergeNodes_general($old_node, $new_node, $attrs)

Takes two LibXML nodes containing structures and merges them together. The
$attrs variable is a pointer to a hash describing which attributes on an element
node should be compared to define equality. If an element's name is not defined
in the hash, the element is simply replaced if one of the same name and
namespace is found.

To have links compared based on their 'id' attribute, you would specify $attrs as such:

my %attrs = (
    link => ( id => '' );
);

=cut

sub mergeNodes_general {
    my ( $old_node, $new_node, $comparison_attrs ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Topology::Common" );

    if ( $old_node->getType != $new_node->getType ) {
        $logger->warn( "Inconsistent node types, old " . $old_node->getType . " vs new " . $new_node->getType . ", simply replacing old with new" );
        return $new_node->cloneNode( 1 );
    }

    if ( $new_node->getType == 3 ) {    # text node
        return $new_node->cloneNode( 1 );
    }

    if ( $new_node->getType != 1 ) {
        $logger->warn( "Received unknown node type: " . $new_node->getType . ", returning new node" );
        return $new_node->cloneNode( 1 );
    }

    if ( $new_node->localname ne $old_node->localname ) {
        $logger->warn( "Received inconsistent node names: " . $old_node->localname . " and " . $new_node->getType . ", returning new node" );
        return $new_node;
    }

    my $ret_node = $old_node->cloneNode( 1 );

    my @new_attributes = $new_node->getAttributes();

    foreach my $attribute ( @new_attributes ) {
        if ( $attribute->getType == 2 ) {
            $ret_node->setAttribute( $attribute->getName, $attribute->getValue );
        }
        else {
            $logger->warn( "Unknown attribute type, " . $attribute->getType . ", skipping" );
        }
    }

    my %elements = ();

    foreach my $elem ( $ret_node->getChildNodes ) {
        next unless defined $elem->localname;
        $elements{ $elem->localname } = () unless defined $elements{ $elem->localname };
        push @{ $elements{ $elem->localname } }, $elem;
    }

    foreach my $elem ( $new_node->getChildNodes ) {
        my $is_equal;

        if ( $elem->getType == 3 ) {

            # Since we don't know which text node it is, we have to
            # remove all of them... sigh...
            foreach my $tn ( $ret_node->getChildNodes ) {
                if ( $tn->getType == 3 ) {
                    $ret_node->removeChild( $tn );
                }
            }

            $ret_node->addChild( $elem->cloneNode( 1 ) );
        }

        next unless defined $elem->localname;

        my $old_elem;
        if ( ( exists $comparison_attrs->{ $elem->localname } and $comparison_attrs->{ $elem->localname } ) and ( exists $elements{ $elem->localname } and $elements{ $elem->localname } ) ) {
            my $i = 0;

            foreach my $tmp_elem ( @{ $elements{ $elem->localname } } ) {

                # skip elements from different namespaces
                next if ( $elem->namespaceURI ne $tmp_elem->namespaceURI );

                $is_equal = 1;

                $logger->debug( "Comparison attributes: " . Dumper( $comparison_attrs->{ $elem->localname } ) );

                unless ( exists $comparison_attrs->{ $elem->localname }->{'*'} ) {
                    foreach my $attr ( keys %{ $comparison_attrs->{ $elem->localname } } ) {
                        my $old_attr = $tmp_elem->getAttributes( $attr );
                        my $new_attr = $elem->getAttributes( $attr );

                        if ( defined $old_attr and defined $new_attr ) {

                            # if the attribute exists in both the old node and the new node, compare them
                            if ( $old_attr->getValue ne $new_attr->getValue ) {
                                $is_equal = 0;
                            }
                        }
                        elsif ( defined $old_attr or defined $new_attr ) {

                            # if the attribute exists in one or the other, obviously they cannot be equal
                            $is_equal = 0;
                        }
                    }
                }

                if ( $is_equal ) {
                    $old_elem = $tmp_elem;
                    splice( @{ $elements{ $elem->localname } }, $i, 1 );
                    last;
                }

                $i++;
            }
        }
        elsif ( exists $elements{ $elem->localname } and $elements{ $elem->localname } ) {
            $old_elem = pop( @{ $elements{ $elem->localname } } );
        }

        my $new_child;

        if ( $old_elem ) {
            $new_child = mergeNodes_general( $old_elem, $elem, $comparison_attrs );
            $ret_node->removeChild( $old_elem );
        }
        else {
            $new_child = $elem->cloneNode( 1 );
        }

        $ret_node->appendChild( $new_child );
    }

    $logger->debug( "Merged Node: " . $ret_node->toString );

    return $ret_node;
}

=head2 countRefs($id, $dom, $uri, $element, $attr)

Given a ID, and a series of 'struct' objects and a key 'value' to search on,
this function will return a 'count' of the number of times the id was seen as a
reference to the objects.  This is useful for eliminating 'dead' blocks that may
not contain a trigger. The function will return -1 on error.

=cut

sub countRefs {
    my ( $id, $dom, $uri, $element, $attr ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    if (    ( defined $id and $id )
        and ( defined $dom     and $dom )
        and ( defined $uri     and $uri )
        and ( defined $element and $element )
        and ( defined $attr    and $attr ) )
    {
        my $flag = 0;
        foreach my $d ( $dom->getElementsByTagNameNS( $uri, $element ) ) {
            $flag++ if $id eq $d->getAttribute( $attr );
        }
        return $flag;
    }
    else {
        $logger->error( "Missing argument(s)." );
    }
    $logger->debug( "0 Refernces Found" );
    return -1;
}

=head2 genuid()

Generates a random number.

=cut

sub genuid {
    my $r = int( rand( 16777216 ) ) + 1048576;
    return $r;
}

=head2 extract($node)

Returns a 'value' from a xml element, either the value attribute or the text
field.

=cut

sub extract {
    my ( $node, $clean ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );
    if ( defined $node and $node ) {
        if ( $node->getAttribute( "value" ) ) {
            return $node->getAttribute( "value" );
        }
        else {
            my $value = $node->textContent;
            if ( $clean ) {
                $value =~ s/\s*//g;
            }
            if ( $value ) {
                return $value;
            }
        }
    }
    return;
}

=head2 mapNamespaces($node, \%namespaces)

Fills in a uri -> prefix mapping of the namespaces.

=cut

sub mapNamespaces {
    my ( $node, $namespaces ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    my @nsList = $node->getNamespaces;
    if ( $#nsList > -1 ) {
        foreach my $ns ( @nsList ) {
            $namespaces->{ $ns->getValue() } = $ns->getLocalName();
        }
    }

    my $uri    = $node->namespaceURI();
    my $prefix = $node->prefix();
    if ( $prefix and $uri ) {
        unless ( exists $namespaces->{$uri} ) {
            $namespaces->{$uri} = $prefix;
            $node->ownerDocument->getDocumentElement->setNamespace( $uri, $prefix, 0 );
        }
    }
    elsif ( ( not defined $prefix or $prefix eq q{} ) and defined $uri ) {
        if ( exists $namespaces->{$uri} and $namespaces->{$uri} ) {
            $node->setNamespace( $uri, $namespaces->{$uri}, 1 );
        }
    }
    if ( $node->hasChildNodes() ) {
        foreach my $c ( $node->childNodes ) {
            mapNamespaces( $c, $namespaces ) if $node->nodeType != 3;
        }
    }

    return;
}

=head2 reMap(\%{$rns}, \%{$ns}, $dom_node)

Re-map the nodes namespace prefixes to known prefixes (to not screw with the
XPath statements that will occur later).

=cut

sub reMap {
    my ( $requestNamespaces, $namespaces, $node, $set_owner_prefix ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    if ( $node->prefix and $node->namespaceURI() ) {
        unless ( $requestNamespaces->{ $node->namespaceURI() } ) {
            $requestNamespaces->{ $node->namespaceURI() } = $node->prefix;
            if ( $set_owner_prefix ) {
                $node->ownerDocument->getDocumentElement->setNamespace( $node->namespaceURI(), $node->prefix, 0 );
            }
            $logger->debug( "Setting namespace \"" . $node->namespaceURI() . "\" with prefix \"" . $node->prefix . "\"." );
        }
        unless ( $namespaces->{ $node->prefix } ) {
            foreach my $ns ( keys %{$namespaces} ) {
                if ( $namespaces->{$ns} eq $node->namespaceURI() ) {
                    $node->setNamespace( $namespaces->{$ns}, $ns, 1 );
                    if ( $set_owner_prefix ) {
                        $node->ownerDocument->getDocumentElement->setNamespace( $namespaces->{$ns}, $ns, 0 );
                    }
                    $logger->debug( "Re-mapping namespace \"" . $namespaces->{$ns} . "\" to prefix \"" . $ns . "\"." );
                    last;
                }
            }
        }
    }
    elsif ( $node->namespaceURI() ) {
        if ( exists $requestNamespaces->{ $node->namespaceURI() } and $requestNamespaces->{ $node->namespaceURI() } ) {
            $logger->debug( "Setting namespace \"" . $node->namespaceURI() . "\" with prefix \"" . $requestNamespaces->{ $node->namespaceURI() } . "\"." );
            $node->setNamespace( $node->namespaceURI(), $requestNamespaces->{ $node->namespaceURI() }, 1 );
        }
        else {
            my $new_prefix;
            foreach my $ns ( keys %{$namespaces} ) {
                if ( $namespaces->{$ns} eq $node->namespaceURI() ) {
                    $new_prefix = $ns;
                    last;
                }
            }

            if ( not $new_prefix ) {
                $logger->debug( "No prefix for namespace " . $node->namespaceURI() . ": generating one" );
                do {
                    $new_prefix = "pref" . ( genuid() % 1000 );
                } while ( exists $namespaces->{$new_prefix} );
            }

            $node->setNamespace( $node->namespaceURI(), $new_prefix, 1 );
            $node->ownerDocument->getDocumentElement->setNamespace( $node->namespaceURI(), $new_prefix, 0 ) if $set_owner_prefix;

            $logger->debug( "Re-mapping namespace \"" . $node->namespaceURI() . "\" to prefix \"" . $new_prefix . "\"." );
            $requestNamespaces->{ $node->namespaceURI() } = $new_prefix;
        }
    }
    if ( $node->hasChildNodes() ) {
        foreach my $c ( $node->childNodes ) {
            $requestNamespaces = reMap( $requestNamespaces, $namespaces, $c, $set_owner_prefix ) if $node->nodeType != 3;
        }
    }
    return $requestNamespaces;
}

=head2 consultArchive($host, $port, $endpoint, $request)

This function can be used to easily consult a measurement archive. It's a thin
wrapper around the sendReceive function in the perfSONAR_PS::Transport module.
You specify the host, port and endpoint for the MA you wish to consult and the
request you wish to send. The function sends the request to the MA, parses the
response and returns to you the LibXML element corresponding to the nmwg:message
portion of the response. The return value an array of the form ($status, $res)
where status is 0 means the function was able to send the request and get a
properly formed response and -1 on failure. $res contains the LibXML element on
success and an error message on failure.

=cut

sub consultArchive {
    my ( $host, $port, $endpoint, $request, $timeout ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    # start a transport agent
    my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );

    my $envelope = makeEnvelope( $request );
    my $error;
    my $start_time = time;
    $timeout = 30 unless $timeout;    # 30 secondtimeout
    my $response = $sender->sendReceive( $envelope, $timeout, \$error );
    my $end_time = time;

    $logger->debug( "Time to make request: " . ( $end_time - $start_time ) );

    if ( $error ) {
        my $msg = "Error while sending request to server: $error";
        $logger->error( $msg );
        return ( -1, $msg );
    }

    if ( not defined $response or $response eq q{} ) {
        my $msg = "No response received from status service";
        $logger->error( $msg );
        return ( -1, $msg );
    }

    my $doc;
    eval {
        my $parser = XML::LibXML->new();
        $doc = $parser->parse_string( $response );
    };
    if ( $EVAL_ERROR ) {
        my $msg = "Couldn't parse response: $EVAL_ERROR";
        $logger->error( $msg );
        return ( -1, $msg );
    }

    my $nodeset = find( $doc, "//nmwg:message", 0 );
    if ( $nodeset->size <= 0 ) {
        my $msg = "Message element not found in response";
        $logger->error( $msg );
        return ( -1, $msg );
    }
    elsif ( $nodeset->size > 1 ) {
        my $msg = "Too many message elements found in response";
        $logger->error( $msg );
        return ( -1, $msg );
    }

    my $nmwg_msg = $nodeset->get_node( 1 );

    return ( 0, $nmwg_msg );
}

=head2 escapeString($string)

This function does some basic XML character escaping. Replacing < with &lt;, &
with &amp;, etc.

=cut

sub escapeString {
    my ( $input ) = @_;

    $input =~ s/&/&amp;/g;
    $input =~ s/</&lt;/g;
    $input =~ s/>/&gt;/g;
    $input =~ s/'/&apos;/g;
    $input =~ s/"/&quot;/g;

    return $input;
}

=head2 unescapeString($string)

This function does some basic XML character escaping. Replacing &lt; with <,
&amp; with &, etc.

=cut

sub unescapeString {
    my ( $input ) = @_;

    $input =~ s/&lt;/</g;
    $input =~ s/&gt;/>/g;
    $input =~ s/&apos;/'/g;
    $input =~ s/&quot;/"/g;
    $input =~ s/&amp;/&/g;

    return $input;
}

=head2 mergeConfig($base, $specific)

Merges the configurations in $base and $specific.

=cut

sub mergeConfig {
    my ( $base, $specific ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    my %elements = (
        port     => 1,
        endpoint => 1
    );

    my $ret_config = mergeHash( $base, $specific, \%elements );

    return $ret_config;
}

=head2 mergeHash($base, $specific, $skip_elements)

Internal function that merges $base and $specific into a unified hash. The
elements from the $specific hash will be used whenever a collision occurs.
$skip_elements is a hash containing the set of keys whose values should be
ignored.

=cut

sub mergeHash {
    my ( $base, $specific, $skip_elements ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    my $new = duplicateHash( $base, $skip_elements );

    foreach my $key ( keys %{$specific} ) {
        next if exists $skip_elements->{$key} and $skip_elements->{$key};

        if ( ref $specific->{$key} eq "HASH" ) {
            if ( not exists $new->{$key} ) {
                $new->{$key} = duplicateHash( $specific->{$key}, $skip_elements );
            }
            else {
                $new->{$key} = mergeHash( $new->{$key}, $specific->{$key}, $skip_elements );
            }
        }
        else {
            $new->{$key} = $specific->{$key};
        }
    }

    return $new;
}

=head2 duplicateArray($array, $skip_elements)

Internal function that duplicates the specified hash. It ignores hash elements
with the keys specified in the $skip_elements.

=cut

sub duplicateHash {
    my ( $hash, $skip_elements ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );

    my %new = ();

    foreach my $key ( keys %{$hash} ) {
        next if exists $skip_elements->{$key} and $skip_elements->{$key};

        if ( ref $hash->{$key} eq "HASH" ) {
            $new{$key} = duplicateHash( $hash->{$key}, $skip_elements );
        }
        elsif ( ref $hash->{$key} eq "ARRAY" ) {
            $new{$key} = duplicateArray( $hash->{$key}, $skip_elements );
        }
        else {
            $new{$key} = $hash->{$key};
        }
    }

    return \%new;
}

=head2 duplicateArray($array, $skip_elements)

Internal function that duplicates the specified array. When duplicating hash
elements in the array, the elements specified in skip_elements will be skipped.

=cut

sub duplicateArray {
    my ( $array, $skip_elements ) = @_;

    my @old_array = @{$array};
    my @new       = ();
    for my $i ( 0 .. $#old_array ) {
        if ( ref $old_array[$i] eq "ARRAY" ) {
            $new[$i] = duplicateArray( $old_array[$i], $skip_elements );
        }
        elsif ( ref $old_array[$i] eq "HASH" ) {
            $new[$i] = duplicateHash( $old_array[$i], $skip_elements );
        }
        else {
            $new[$i] = $old_array[$i];
        }
    }

    return \@new;
}

=head2 convertISO($iso)

Given the time in ISO format, conver to 'unix' epoch seconds.

=cut

sub convertISO {
    my ( $iso ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Common" );
    if ( defined $iso and $iso ) {
        my ( $date_portion, $time_portion ) = split( /T/, $iso );
        my ( $year, $mon, $day ) = split( /-/, $date_portion );
        my ( $hour, $min, $sec ) = split( /:/, $time_portion );
        my $frac = q{};
        ( $sec, $frac ) = split( /\./, $sec );
        my $zone = $frac;
        $frac =~ s/\D+//g;
        $zone =~ s/\d+//g;

        if ( $zone eq "Z" ) {
            return timegm( $sec, $min, $hour, $day, $mon - 1, $year - 1900 );
        }
        else {
            return timelocal( $sec, $min, $hour, $day, $mon - 1, $year - 1900 );
        }
    }
    else {
        $logger->error( "Missing argument." );
        return "N/A";
    }
}

1;

__END__

=head1 SEE ALSO

L<Exporter>, L<IO::File>, L<Time::HiRes>, L<Log::Log4perl>, L<XML::LibXML>,
L<English>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Common.pm 4475 2010-09-29 13:18:06Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
Jason Zurawski, zurawski@internet2.edu
Guilherme Fernandes, fernande@cis.udel.edu

=head1 LICENSE
 
You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT
 
Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut
