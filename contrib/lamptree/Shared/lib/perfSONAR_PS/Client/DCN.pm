package perfSONAR_PS::Client::DCN;

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::Client::LS';
use fields 'SERVICE', 'LS_KEY';

=head1 NAME

perfSONAR_PS::Client::DCN

=head1 DESCRIPTION

API that implements select perfSONAR calls that DCN tools will require.

=cut

use Log::Log4perl qw( get_logger );
use Params::Validate qw( :all );
use Digest::MD5 qw( md5_hex );
use English qw( -no_match_vars );
use XML::LibXML;

use perfSONAR_PS::Common qw( genuid makeEnvelope find extract );
use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::Client::LS;

=head2 new($package { instance })

Constructor for object.  Four optional arguments are possible:

 instance - LS instance to communicate with
 
The next three items compose the 'service' defintion of something using this
API.  For example if we are a registration web page, we may have a service block
that looks like this:

  <nmwg:metadata xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/">
    <perfsonar:subject xmlns:perfsonar="http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/">
      <nmtb:service xmlns:nmtb="http://ogf.org/schema/network/base/20070828/">
        <nmtb:name>DCN Registration CGI</nmtb:name>
        <nmtb:type>dcnmap</nmtb:type>
        <nmtb:address type="url">https://dcn-ls.internet2.edu</nmtb:address>
      </nmtb:service>
    </perfsonar:subject>
  </nmwg:metadata> 
 
The correspoinding variables to input to this function are: 
 
 myAddress - address of 'service' that is using this API.  For example if you
             are an IDC your 'contact address' goes here.  If you are a web page
             (e.g. the registration web page) your url goes here.
 myName - name of 'service' that is using this API.
 myType - type of 'service' that is using this API.

Each value may also be set in the other 'set' functions.  

=cut

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams( @args, { instance => 0, myAddress => 0, myName => 0, myType => 0 } );

    my $self = fields::new( $package );

    $self->{ALIVE}                          = 0;
    $self->{SERVICE}                        = ();
    $self->{SERVICE}->{nonPerfSONARService} = 1;
    $self->{SERVICE}->{addresses}           = ();
    $self->{LOGGER}                         = get_logger( "perfSONAR_PS::Client::DCN" );

    if ( exists $parameters->{"instance"} and $parameters->{"instance"} ) {
        if ( $parameters->{"instance"} =~ m/^http(s?):\/\// ) {
            $self->{INSTANCE} = $parameters->{"instance"};
        }
        else {
            $self->{LOGGER}->error( "'instance' must be of the form http://ADDRESS or https://ADDRESS" );
        }
    }

    if ( exists $parameters->{"myAddress"} and $parameters->{"myAddress"} ) {
        if ( $parameters->{"instance"} =~ m/^http(s?):\/\// ) {
            my $temp;
            $temp->{value} = $parameters->{"myAddress"};
            $temp->{type}  = "url";
            push @{ $self->{SERVICE}->{addresses} }, $temp;
        }
        else {
            $self->{LOGGER}->error( "'myAddress' must be of the form http://ADDRESS or https://ADDRESS" );
        }
    }

    $self->{SERVICE}->{name} = $parameters->{"myName"} if exists $parameters->{"myName"} and $parameters->{"myName"};
    $self->{SERVICE}->{type} = $parameters->{"myType"} if exists $parameters->{"myType"} and $parameters->{"myType"};
    $self->{LS_KEY} = $self->getLSKey if $self->{INSTANCE} and $self->{SERVICE}->{addresses} and $self->{SERVICE}->{name} and $self->{SERVICE}->{type};
    return $self;
}

=head2 setInstance($self { instance })

Required argument 'instance' is the LS instance to be contacted for queries.
See 'new' for more information.   

=cut

sub setInstance {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { instance => 1 } );

    $self->{ALIVE} = 0;
    if ( $parameters->{"instance"} =~ m/^http(s?):\/\// ) {
        $self->{INSTANCE} = $parameters->{"instance"};
        $self->{LS_KEY} = $self->getLSKey if $self->{INSTANCE} and $self->{SERVICE}->{addresses} and $self->{SERVICE}->{name} and $self->{SERVICE}->{type};
    }
    else {
        $self->{LOGGER}->error( "'instance' must be of the form http://ADDRESS or https://ADDRESS" );
    }
    return;
}

=head2 setMyAddress($self { myAddress })

Sets the address of the 'service' that is using this API.  For example if you
are an IDC your 'contact address' goes here.  If you are a web page (e.g. the
registration web page) your url goes here.  See 'new' for more information.

=cut

sub setMyAddress {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { myAddress => 1 } );

    if ( $parameters->{"myAddress"} =~ m/^http(s?):\/\// ) {
        $self->{SERVICE}->{addresses} = ();
        my $temp = ();
        $temp->{value} = $parameters->{"myAddress"};
        $temp->{type}  = "url";
        push @{ $self->{SERVICE}->{addresses} }, $temp;
        $self->{LS_KEY} = $self->getLSKey if $self->{INSTANCE} and $self->{SERVICE}->{addresses} and $self->{SERVICE}->{name} and $self->{SERVICE}->{type};
    }
    else {
        $self->{LOGGER}->error( "'myAddress' must be of the form http://ADDRESS or https://ADDRESS" );
    }
    return;
}

=head2 setMyName($self { myName })

Sets the name of the 'service' that is using this API.  For example if you
are an IDC your 'serviceName' goes here.  If you are a web page (e.g. the
registration web page) enter your title here.  See 'new' for more information.

=cut

sub setMyName {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { myName => 1 } );

    $self->{SERVICE}->{name} = $parameters->{"myName"};
    $self->{LS_KEY} = $self->getLSKey if $self->{INSTANCE} and $self->{SERVICE}->{addresses} and $self->{SERVICE}->{name} and $self->{SERVICE}->{type};
    return;
}

=head2 setMyType($self { myType })

Sets the type of the 'service' that is using this API.  For example if you
are an IDC your type shlould be 'IDC' or similar.  If you are a web page (e.g.
the registration web page) your should note that here.  See 'new' for more
information.

=cut

sub setMyType {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { myType => 1 } );

    $self->{SERVICE}->{type} = $parameters->{"myType"};
    $self->{LS_KEY} = $self->getLSKey if $self->{INSTANCE} and $self->{SERVICE}->{addresses} and $self->{SERVICE}->{name} and $self->{SERVICE}->{type};
    return;
}

=head2 getLSKey($self { })

Send an LSKeyRequest to the service to retrive the actual key value for the
registration of the 'DCN' service.

=cut

sub getLSKey {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    my $result = $self->keyRequestLS( { service => \%{ $self->{SERVICE} } } );
    if ( $result and exists $result->{key} and $result->{key} ) {
        return $result->{key};
    }
    else {
        if ( $result ) {
            $self->{LOGGER}->error( "Error \"" . $result->{eventType} . "\" in LSKeyRequest: \"" . $result->{response} . "\"" );
        }
        else {
            $self->{LOGGER}->error( "Error in LSKeyRequest" );
        }
    }
    return;
}

=head2 getServiceKey($self { })

Return the value of the LS_KEY field.  

=cut

sub getServiceKey {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );
    unless ( $self->{LS_KEY} ) {
        $self->{LS_KEY} = $self->getLSKey;
    }
    return $self->{LS_KEY};
}

=head2 nameToId

Given a name (i.e. DNS 'hostname') return any matching link ids.

=cut

sub nameToId {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { name => 1 } );
    my @ids        = ();
    my $metadata   = q{};
    my %ns         = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );

    my $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $q        .= "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n";
    $q        .= "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/*[local-name()='subject']/nmtb:node[nmtb:address/text()=\"" . $parameters->{name} . "\"]\n";
    $metadata .= $self->queryWrapper( { query => $q } );

    my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType and $eventType =~ m/^success/mx ) {
        my $links = find( $msg->getChildrenByLocalName( "data" )->get_node( 1 )->getChildrenByLocalName( "datum" )->get_node( 1 ), ".//nmtb:node/nmtb:relation[\@type=\"connectionLink\"]/nmtb:linkIdRef", 0 );
        if ( $links ) {
            foreach my $l ( $links->get_nodelist ) {
                my $value = extract( $l, 0 );
                push @ids, $value if $value;
            }
        }
        else {
            $self->{LOGGER}->error( "No link elements found in message: " . $msg->toString );
        }
    }
    else {
        $self->{LOGGER}->error( "EventType not found in message: " . $msg->toString );
    }
    return \@ids;
}

=head2 idToName

Given a link id return any matching names (i.e. DNS 'hostname').

=cut

sub idToName {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { id => 1 } );
    my @names      = ();
    my $metadata   = q{};
    my %ns         = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );

    my $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $q        .= "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n";
    $q        .= "/nmwg:store[\@type=\"LSStore\"]/nmwg:data/nmwg:metadata/*[local-name()='subject']/nmtb:node[nmtb:relation[\@type=\"connectionLink\"]/nmtb:linkIdRef[text()=\"" . $parameters->{id} . "\"]]\n";
    $metadata .= $self->queryWrapper( { query => $q } );

    my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType and $eventType =~ m/^success/mx ) {
        my $hostnames = find( $msg->getChildrenByLocalName( "data" )->get_node( 1 )->getChildrenByLocalName( "datum" )->get_node( 1 ), ".//nmtb:node/nmtb:address[\@type=\"hostname\"]", 0 );
        if ( $hostnames ) {
            foreach my $hn ( $hostnames->get_nodelist ) {
                my $value = extract( $hn, 0 );
                push @names, $value if $value;
            }
        }
        else {
            $self->{LOGGER}->error( "No link elements found in message: " . $msg->toString );
        }
    }
    else {
        $self->{LOGGER}->error( "EventType not found in message: " . $msg->toString );
    }
    return \@names;
}

=head2 controlKey($self { id name })

Returns the key of the service that 'controls' a given Id/Name combination.

=cut

sub controlKey {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { id => 1, name => 1 } );
    my @ids        = ();
    my $metadata   = q{};
    my %ns         = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );

    my $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $q        .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
    $q        .= "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n";
    $q        .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
    $q        .= "/nmwg:store[\@type=\"LSStore\"]/nmwg:data[nmwg:metadata/*[local-name()='subject']/nmtb:node[nmtb:address/text()=\"" . $parameters->{name} . "\" and nmtb:relation[\@type=\"connectionLink\"]/nmtb:linkIdRef[text()=\"" . $parameters->{id} . "\"]]]\n";
    $metadata .= $self->queryWrapper( { query => $q } );

    my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType and $eventType =~ m/^success/mx ) {
        my $datablock = find( $msg->getChildrenByLocalName( "data" )->get_node( 1 )->getChildrenByLocalName( "datum" )->get_node( 1 ), ".//nmwg:data", 1 );
        return $datablock->getAttribute( "metadataIdRef" );
    }
    else {
        $self->{LOGGER}->error( "EventType not found in message: " . $msg->toString );
    }
    return;
}

=head2 insert($self { id name })

Given an id AND a name, register this infomration to the LS instance.  Optional
elements include:

 institution - Textual location name, e.g. someschool.edu is really "The University of Someschool"
 latitude - Latitude coordinate reading for this node
 longitude - Longitude coordinate reading for this node
 keywords - Array of 'keyword' values, e.g. project:ScienceExperiement or project:BackboneNetwork

=cut

sub insert {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { id => 1, name => 1, institution => 0, latitude => 0, longitude => 0, keywords => 0 } );

    unless ( $self->{LS_KEY} ) {
        $self->{LS_KEY} = $self->getLSKey;
    }

    my %ns = (
        perfsonar => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/",
        psservice => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/",
        dcn       => "http://ggf.org/ns/nmwg/tools/dcn/2.0/",
        nmtb      => "http://ogf.org/schema/network/topology/base/20070828/"
    );

    my $metadata = q{};
    if ( exists $self->{LS_KEY} and $self->{LS_KEY} ) {
        $metadata = $self->createKey( { key => $self->{LS_KEY} } );
    }
    else {
        $metadata = $self->createService( { service => \%{ $self->{SERVICE} } } );
    }

    my @data = ();
    $data[0] = $self->createNode( { id => $parameters->{id}, name => $parameters->{name}, institution => $parameters->{institution}, latitude => $parameters->{latitude}, longitude => $parameters->{longitude}, keywords => $parameters->{keywords} } );
    my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSRegisterRequest", ns => \%ns, metadata => $metadata, data => \@data } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return -1;
    }

    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType and $eventType =~ m/^success/mx ) {
        my $datum = extract( find( $msg, "./nmwg:data/*[local-name()=\"datum\"]", 1 ), 0 );
        if ( $datum and $datum =~ m/^\s*\[\d+\] Data elements/m ) {
            my $num = $datum;
            $num =~ s/^\[//xm;
            $num =~ s/\].*//xm;
            if ( $num >= 0 ) {
                $self->{LOGGER}->warn( "Information already registered." ) if $num == 0;
                return 0;
            }
        }
        $self->{LOGGER}->error( "Datum not found or in unexpected format: " . $msg->toString );
    }
    else {
        $self->{LOGGER}->error( "EventType not found or unexpected in message: " . $msg->toString );
    }
    return -1;
}

=head2 remove($self { id name key })

Given an id or a name, delete this specific info from the LS instance.  The
optional key argument can be used to insert some other LS key instead of the
key that travels with the service information in this object. 

=cut

sub remove {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { id => 0, name => 0, key => 0 } );

    unless ( $parameters->{id} or $parameters->{name} ) {
        $self->{LOGGER}->error( "Must supply either a name or id." );
        return -1;
    }

    my $searchKey = q{};
    if ( exists $parameters->{key} and $parameters->{key} ) {
        $searchKey = $parameters->{key};
    }
    else {
        unless ( $self->{LS_KEY} ) {
            $self->{LS_KEY} = $self->getLSKey;
        }
        $searchKey = $self->{LS_KEY};
    }

    if ( $searchKey ) {
        my %ns = (
            perfsonar => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/",
            psservice => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/",
            dcn       => "http://ggf.org/ns/nmwg/tools/dcn/2.0/",
            nmtb      => "http://ogf.org/schema/network/topology/base/20070828/"
        );
        my @data = ();
        $data[0] = $self->createNode( { id => $parameters->{id}, name => $parameters->{name} } );
        my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSDeregisterRequest", metadata => $self->createKey( { key => $searchKey } ), data => \@data } ) } );
        unless ( $msg ) {
            $self->{LOGGER}->error( "Message element not found in return." );
            return -1;
        }

        my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
        if ( $eventType and $eventType =~ m/^success/mx ) {
            my $datum = extract( find( $msg, "./nmwg:data/*[local-name()=\"datum\"]", 1 ), 0 );
            if ( $datum and $datum =~ m/^Removed/xm ) {
                my $num = $datum;
                $num =~ s/^Removed\s{1}\[//xm;
                $num =~ s/\].*//xm;
                if ( $num >= 0 ) {
                    $self->{LOGGER}->warn( "Response successful, but nothing removed." ) if $num == 0;
                    return 0;
                }
            }
            $self->{LOGGER}->error( "Datum not found or in unexpected format: " . $msg->toString );
        }
        else {
            $self->{LOGGER}->error( "EventType not found or unexpected in message: " . $msg->toString );
        }
    }
    else {
        $self->{LOGGER}->error( "Key not found, cannot de-register." );
    }
    return -1;
}

=head2 getMappings($self, { })

Return all link id to hostname mappings in the LS.

=cut

sub getMappings {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );
    my @lookup = ();

    $self->{LS_KEY} = $self->getLSKey unless $self->{LS_KEY};
    $self->{LS_KEY} = q{} unless $self->{LS_KEY};
    my %ns = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );

    for my $times ( 0 .. 1 ) {
        my $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
        $q .= "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n";
        $q .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
        $q .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
        $q .= "declare namespace dcn=\"http://ggf.org/ns/nmwg/tools/dcn/2.0/\";\n";
        $q .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata\n";
        $q .= "let \$metadata_id := \$metadata/\@id\n";
        $q .= "let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef=\$metadata_id]\n";
        if ( $times == 0 ) {
            $q .= "where \$metadata_id=\"" . $self->{LS_KEY} . "\"\n";
        }
        else {
            $q .= "where \$metadata_id!=\"" . $self->{LS_KEY} . "\"\n";
        }
        $q .= "return \$data/nmwg:metadata[*[local-name()='subject']/nmtb:node]\n";

        my $metadata = $self->queryWrapper( { query => $q } );
        my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );
        unless ( $msg ) {
            $self->{LOGGER}->error( "Message element not found in return." );
            return;
        }

        my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
        if ( $eventType and $eventType =~ m/^success/mx ) {
            my $datum = find( $msg, ".//*[local-name()='datum']", 0 )->get_node( 1 );
            unless ( $datum ) {
                $self->{LOGGER}->error( "No datum elements found in return:" . $msg->toString );
                return;
            }

            foreach my $md ( $datum->getChildrenByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "metadata" ) ) {
                my $keywords = find( $md, ".//nmwg:parameters/nmwg:parameter", 0 );

                my $address = extract( find( $md, "./*[local-name()=\"subject\"]/nmtb:node/nmtb:address", 1 ), 0 );
                my $link = extract( find( $md, "./*[local-name()=\"subject\"]/nmtb:node/nmtb:relation[\@type=\"connectionLink\"]/nmtb:linkIdRef", 1 ), 0 );

                my %misc = ();
                my $temp;
                if ( $times == 0 ) {
                    $misc{authoratative} = 1;
                }
                else {
                    $misc{authoratative} = 0;
                }
                $temp = extract( find( $md, "./*[local-name()=\"subject\"]/nmtb:node/nmtb:location/nmtb:institution", 1 ), 0 );
                $misc{institution} = $temp if $temp;
                $temp = extract( find( $md, "./*[local-name()=\"subject\"]/nmtb:node/nmtb:location/nmtb:latitude", 1 ), 0 );
                $misc{latitude} = $temp if $temp;
                $temp = extract( find( $md, "./*[local-name()=\"subject\"]/nmtb:node/nmtb:location/nmtb:longitude", 1 ), 0 );
                $misc{longitude} = $temp if $temp;

                if ( $keywords ) {
                    foreach my $kw ( $keywords->get_nodelist ) {
                        my $name = $kw->getAttribute( "name" );
                        next unless $name eq "keyword";
                        my $value = extract( $kw, 0 );
                        $value =~ s/(\n|\r)//g;
                        push @{ $misc{keywords} }, $value if $value;
                    }
                }
                push @lookup, [ $address, $link, \%misc ];
            }
        }
        else {
            $self->{LOGGER}->error( "EventType not found or unexpected in message: " . $msg->toString );
        }
    }    
    return \@lookup;
}

=head2 createNode($self { id name })

Construct a node given an id and a name.  Optional elements include:

 institution - Textual location name, e.g. someschool.edu is really "The University of Someschool"
 latitude - Latitude coordinate reading for this node
 longitude - Longitude coordinate reading for this node
 keywords - Array of 'keyword' values, e.g. project:ScienceExperiement or project:BackboneNetwork

=cut

sub createNode {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { id => 0, name => 0, institution => 0, latitude => 0, longitude => 0, keywords => 0 } );

    unless ( $parameters->{id} or $parameters->{name} ) {
        $self->{LOGGER}->error( "Must supply either a name or id." );
        return -1;
    }

    my $id   = md5_hex( $parameters->{name} . $parameters->{id} );
    my $node = "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata." . $id . "\">\n";
    $node .= "      <dcn:subject xmlns:dcn=\"http://ggf.org/ns/nmwg/tools/dcn/2.0/\" id=\"subject." . $id . "\">\n";
    $node .= "        <nmtb:node xmlns:nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\" id=\"node." . $id . "\">\n";
    $node .= "          <nmtb:address type=\"hostname\">" . $parameters->{name} . "</nmtb:address>\n" if exists $parameters->{name} and $parameters->{name};
    if ( exists $parameters->{id} and $parameters->{id} ) {
        $node .= "          <nmtb:relation type=\"connectionLink\">\n";
        $node .= "            <nmtb:linkIdRef>" . $parameters->{id} . "</nmtb:linkIdRef>\n";
        $node .= "          </nmtb:relation>\n";
    }
    if ( ( exists $parameters->{institution} and $parameters->{institution} ) or ( exists $parameters->{latitude} and $parameters->{latitude} ) or ( exists $parameters->{longitude} and $parameters->{longitude} ) ) {
        $node .= "          <nmtb:location>\n";
        $node .= "            <nmtb:institution>" . $parameters->{institution} . "</nmtb:institution>\n" if $parameters->{institution} and $parameters->{institution};
        $node .= "            <nmtb:latitude>" . $parameters->{latitude} . "</nmtb:latitude>\n" if exists $parameters->{latitude} and $parameters->{latitude};
        $node .= "            <nmtb:longitude>" . $parameters->{longitude} . "</nmtb:longitude>\n" if exists $parameters->{longitude} and $parameters->{longitude};
        $node .= "          </nmtb:location>\n";
    }
    $node .= "        </nmtb:node>\n";
    $node .= "      </dcn:subject>\n";
    $node .= "      <nmwg:eventType>http://oscars.es.net/OSCARS</nmwg:eventType>\n";
    if ( exists $parameters->{keywords} and $parameters->{keywords} ) {
        $node .= "      <nmwg:parameters id=\"" . $id . "\">\n";
        foreach my $kw ( @{ $parameters->{keywords} } ) {
            $node .= "        <nmwg:parameter name=\"keyword\">" . $kw . "</nmwg:parameter>\n";
        }
        $node .= "      </nmwg:parameters>\n";
    }
    $node .= "    </nmwg:metadata>\n";
    return $node;
}

=head2 getTopologyKey($self { accessPoint serviceName serviceType serviceDescription })

Send an LSKeyRequest to the LS with some service information reguarding a
topology service.  The goal is to get a key, nothing will be returned on
failure.

=cut

sub getTopologyKey {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { accessPoint => 1, serviceName => 0, serviceType => 0, serviceDescription => 0 } );

    my %service = ();
    $service{accessPoint}        = $parameters->{accessPoint}        if $parameters->{accessPoint};
    $service{serviceName}        = $parameters->{serviceName}        if $parameters->{serviceName};
    $service{serviceType}        = $parameters->{serviceType}        if $parameters->{serviceType};
    $service{serviceDescription} = $parameters->{serviceDescription} if $parameters->{serviceDescription};

    my $result = $self->keyRequestLS( { service => \%service } );
    if ( $result and exists $result->{key} and $result->{key} ) {
        return $result->{key};
    }
    $self->{LOGGER}->error( "Key not found." );
    return;
}

=head2 getDomainKey($self { key })

Get the domain for a topology service given a key.

=cut

sub getDomainKey {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { key => 1 } );
    my @domains = ();

    my %ns = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );
    my $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $q .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
    $q .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
    $q .= "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n";
    $q .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata\n";
    $q .= "  let \$metadata_id := \$metadata/\@id\n";
    $q .= "  let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef=\$metadata_id]\n";
    $q .= "  where \$metadata_id=\"" . $parameters->{key} . "\"\n";
    $q .= "  return \$data/nmwg:metadata/*[local-name()='subject']/*[local-name()='domain']\n\n";
    my $metadata = $self->queryWrapper( { query => $q } );

    my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType and $eventType =~ m/^success/mx ) {

        my $ds = find( $msg, "./nmwg:data/*[local-name()='datum']/*[local-name()='domain']", 0 );
        if ( $ds ) {
            foreach my $d ( $ds->get_nodelist ) {
                my $value = $d->getAttribute( "id" );
                $value =~ s/urn:ogf:network:domain=//xm;
                push @domains, $value if $value;
            }
        }
        else {
            $self->{LOGGER}->error( "No domain elements found in return." );
            return;
        }
    }
    else {
        $self->{LOGGER}->error( "EventType not found or unexpected in message: " . $msg->toString );
    }
    return \@domains;
}

=head2 getDomainService($self { accessPoint, serviceName, serviceType })

Get the domain of a topology service given service information

=cut

sub getDomainService {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { accessPoint => 1, serviceName => 0, serviceType => 0 } );
    my @domains = ();

    my %ns = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );
    my $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $q .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
    $q .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
    $q .= "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n\n";
    $q .= "for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata\n";
    $q .= "  let \$metadata_id := \$metadata/\@id\n";
    $q .= "  let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef=\$metadata_id]\n";
    $q .= "  where \$metadata/*[local-name()='subject']/*[local-name()='service']/*[local-name()='accessPoint' and text()=\"" . $parameters->{accessPoint} . "\"]\n";
    if ( exists $parameters->{serviceType} and $parameters->{serviceType} ) {
        $q .= "        and \$metadata/*[local-name()='subject']/*[local-name()='service']/*[local-name()='serviceType' and text()=\"" . $parameters->{serviceType} . "\"]\n";
    }
    if ( exists $parameters->{serviceName} and $parameters->{serviceName} ) {
        $q .= "        and \$metadata/*[local-name()='subject']/*[local-name()='service']/*[local-name()='serviceName' and text()=\"" . $parameters->{serviceName} . "\"]\n";
    }
    $q .= "  return \$data/nmwg:metadata/*[local-name()='subject']/*[local-name()='domain']\n\n";
    my $metadata = $self->queryWrapper( { query => $q } );

    my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType and $eventType =~ m/^success/mx ) {
        my $ds = find( $msg, "./nmwg:data/psservice:datum/*[local-name()='domain']", 0 );
        if ( $ds ) {
            foreach my $d ( $ds->get_nodelist ) {
                my $value = $d->getAttribute( "id" );
                $value =~ s/urn:ogf:network:domain=//xm;
                push @domains, $value if $value;
            }
        }
        else {
            $self->{LOGGER}->error( "No domain elements found in return." );
            return;
        }
    }
    else {
        $self->{LOGGER}->error( "EventType not found or unexpected in message: " . $msg->toString );
    }
    return \@domains;
}

=head2 getTopologyServices($self { domain })

Get the topology service instances that are registered with an LS.  The 
optional 'domain' parameter will return only TS instances that match a
particular domain string.

=cut

sub getTopologyServices {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { domain => 0 } );
    my %services = ();

    my %ns = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );
    my $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $q .= "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n";
    $q .= "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n";
    $q .= "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n";
    if ( exists $parameters->{domain} and $parameters->{domain} ) {
        $q .= "for \$data in /nmwg:store[\@type=\"LSStore\"]/nmwg:data[./nmwg:metadata/*[local-name()='subject']/*[local-name()='domain' and \@id=\"urn:ogf:network:domain=" . $parameters->{domain} . "\"]]\n";
    }
    else {
        $q .= "for \$data in /nmwg:store[\@type=\"LSStore\"]/nmwg:data[./nmwg:metadata/*[local-name()='subject']/*[local-name()='domain']]\n";
    }
    $q .= " let \$metadataidref := \$data/\@metadataIdRef\n";
    $q .= " let \$metadata := /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata[\@id=\$metadataidref]\n";
    $q .= " return \$metadata/*[local-name()='subject']/*[local-name()='service']\n\n";
    my $metadata = $self->queryWrapper( { query => $q } );

    my $msg = $self->callLS( { message => $self->createLSMessage( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType and $eventType =~ m/^success/mx ) {
        my $ss = find( $msg, "./nmwg:data/psservice:datum/*[local-name()='service']", 0 );
        if ( $ss ) {
            foreach my $s ( $ss->get_nodelist ) {
                my $t1 = extract( find( $s, "./*[local-name()='accessPoint']", 1 ), 0 );
                if ( $t1 ) {
                    my %temp = ();
                    my $t2   = extract( find( $s, "./*[local-name()='serviceType']", 1 ), 0 );
                    my $t3   = extract( find( $s, "./*[local-name()='serviceName']", 1 ), 0 );
                    my $t4   = extract( find( $s, "./*[local-name()='serviceDescription']", 1 ), 0 );
                    $temp{"serviceType"}        = $t2 if $t2;
                    $temp{"serviceName"}        = $t3 if $t3;
                    $temp{"serviceDescription"} = $t4 if $t4;
                    $services{$t1} = \%temp;
                }
            }
        }
        else {
            $self->{LOGGER}->error( "No domain elements found in return." );
            return;
        }
    }
    else {
        $self->{LOGGER}->error( "EventType not found or unexpected in message: " . $msg->toString );
    }
    return \%services;
}

=head2 queryTS($self, { topology })

Given the name of a topology service, this performs a simple query to dump it's
contents.  The contents are XML, but returned in string form.  Check the
returned hash to see if an error occured.

=cut

sub queryTS {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { topology => 1, domain => 0 } );
    my %ns = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );

    my $echo_service = perfSONAR_PS::Client::Echo->new( $parameters->{topology} );
    my ( $status, $res ) = $echo_service->ping();
    if ( $status == -1 ) {
        $self->{LOGGER}->error( "Ping to " . $parameters->{topology} . " failed: $res" );
        return;
    }

    my ( $host, $port, $endpoint, $scheme ) = perfSONAR_PS::Transport::splitURI( $parameters->{topology} );
    unless ( $host and $port and $endpoint ) {
        $self->{LOGGER}->error( "Topology URI: \"" . $parameters->{topology} . "\" is malformed." );
        return;
    }
    my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint, $scheme );
    unless ( $sender ) {
        $self->{LOGGER}->error( "TS could not be contaced." );
        return;
    }

    my $error = q{};
    my $responseContent = q{};
    if ( exists $parameters->{domain} and $parameters->{domain} ) {
        $responseContent = $sender->sendReceive( makeEnvelope( $self->createLSMessage( { ns => \%ns, type => "QueryRequest", metadata => "<xquery:subject id=\"sub1\" xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/xquery/1.0/\">//*[\@id=\"" . $parameters->{domain} . "\"]</xquery:subject><nmwg:eventType>http://ggf.org/ns/nmwg/topology/20070809</nmwg:eventType>\n" } ) ), q{}, \$error );
    }
    else {
        $responseContent = $sender->sendReceive( makeEnvelope( $self->createLSMessage( { type => "SetupDataRequest", metadata => "<nmwg:eventType>http://ggf.org/ns/nmwg/topology/query/all/20070809</nmwg:eventType>\n" } ) ), q{}, \$error );
    }

    if ( $error ) {
        $self->{LOGGER}->error( "sendReceive failed: $error" );
        return;
    }

    my $msg    = q{};
    my $parser = XML::LibXML->new();
    if ( $responseContent and ( not $responseContent =~ m/^\d+/xm ) ) {
        my $doc = q{};
        eval { $doc = $parser->parse_string( $responseContent ); };
        if ( $EVAL_ERROR ) {
            $self->{LOGGER}->error( "Parser failed: " . $EVAL_ERROR );
        }
        else {
            $msg = $doc->getDocumentElement->getElementsByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "message" )->get_node( 1 );
        }
    }

    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my %result = ();
    my $eventType = extract( find( $msg, "./nmwg:metadata/nmwg:eventType", 1 ), 0 );
    if ( $eventType ) {
        $result{"eventType"} = $eventType;
        if ( $eventType and ( $eventType eq "http://ggf.org/ns/nmwg/topology/query/all/20070809" or $eventType eq "http://ggf.org/ns/nmwg/topology/20070809" ) ) {
            $result{"response"} = $msg->getChildrenByLocalName( "data" )->get_node( 1 )->getChildrenByLocalName( "topology" )->get_node( 1 )->toString;
        }
        else {
            $result{"response"} = extract( find( $msg, "./nmwg:data/nmwgr:datum", 1 ), 0 );
            unless ( $result{"response"} ) {
                $result{"response"} = extract( find( $msg, "./nmwg:data/nmwg:datum", 1 ), 0 );
            }
        }
    }
    else {
        $self->{LOGGER}->error( "EventType not found or unexpected in message: " . $msg->toString );
    }
    return \%result;
}

=head2 queryWrapper($self { query, eventType })

Given some XQuery/Xpath expression, insert this into a 'canned'
subject/parameter/eventType for an LSQueryRequest.  

=cut

sub queryWrapper {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { query => 0, eventType => 0 } );

    my $query = "    <xquery:subject id=\"subject." . genuid() . "\" xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/\">\n";
    $query .= $parameters->{query};
    $query .= "    </xquery:subject>\n";
    if ( exists $parameters->{query} and $parameters->{eventType} ) {
        $query .= "    <nmwg:eventType>" . $parameters->{eventType} . "</nmwg:eventType>\n";
    }
    else {
        $query .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0</nmwg:eventType>\n";
    }
    $query .= "  <xquery:parameters id=\"parameters." . genuid() . "\" xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/\">\n";
    $query .= "    <nmwg:parameter name=\"lsOutput\">native</nmwg:parameter>\n";
    $query .= "  </xquery:parameters>\n";
    return $query;
}

1;

__END__

=head1 SYNOPSIS

    #!/usr/bin/perl -w

    use perfSONAR_PS::Client::DCN;

    my $dcn = new perfSONAR_PS::Client::DCN( { instance => "http://some.host.edu/perfSONAR_PS/services/LS", myAddress => "https://dcn-ls.internet2.edu/", myName => "DCN Registration CGI", myType => "dcnmap" } );
    
    # 
    # or 
    # 
    # my $dcn = new perfSONAR_PS::Client::DCN;
    # $dcn->setInstance( { instance => "http://some.host.edu/perfSONAR_PS/services/LS" } );
    # $dcn->setMyAddress( { myAddress => "https://dcn-ls.internet2.edu/" } );
    # $dcn->setMyName( { myName => "DCN Registration CGI" } );
    # $dcn->setMyType( { myType => "dcnmap" } );

    my $name = "some.hostname.edu";
    my $id = "urn:ogf:network:domain=some.info.about.this.link";

    # Get link id values given a host name
    # 
    my $ids = $dcn->nameToId({ name => $name });
    foreach my $i (@$ids) {
      print $name , "\t=\t" , $i , "\n";
    }
    
    # Get host names given link id values
    #
    my $names = $dcn->idToName( { id => $id } );
    foreach my $n (@$names) {
      print $id , "\t=\t" , $n , "\n";
    }

    # Insert a new entry into the LS given a host name and link id
    # 
    $code = $dcn->insert({ name => "test", id => "test" });
    print "Insert of \"test\" and \"test\" failed.\n" if($code == -1); 

    # Remove an entry from the LS given the host name and link id
    # 
    my $code = $dcn->remove({ name => "test", id => "test" });
    print "Removal of \"test\" and \"test\" failed.\n" if($code == -1);
       
    # Dump all of the nodes from the LS, returns a matrix in host name/link id
    # format.
    # 
    my $map = $dcn->getMappings;
    foreach my $m (@$map) {
      foreach my $value (@$m) {
        print $value , "\t";
      }
      print "\n";
    }    

    # The DCN module has associated 'registration' info to make it act like
    # a service.  This info will be registered with an LS, and will have a key
    # associated with it.  This call will get that key from the LS.
    # 
    my $key = $dcn->getLSKey;
    print "The DCN registration key is \"" , $key , "\".\n" if($key);

    # Like the previous call, get us the key for some other service.
    # 
    $key = $dcn->getTopologyKey({ accessPoint => "http://some.topology.service.edu:8080/perfSONAR_PS/services/topology" });
    print "Found key \"" , $key , "\" for topology service.\n" if($key);
    
    # Get the domain a particular topology service is responsible for given
    # the LS key that corresponds to the service
    # 
    my $domains = $dcn->getDomainKey({ key => "$key" });
    foreach my $d (@$domains) {
      print "Domain:\t" , $d , "\n";
    }

    # Get the domain a particular topology service is responsible for given
    # the service information of the service
    # 
    $domains = $dcn->getDomainService({ accessPoint => "http://some.topology.service.edu:8080/perfSONAR_PS/services/topology", serviceType => "MA" });
    foreach my $d (@$domains) {
      print "Domain:\t" , $d , "\n";
    }

    # Get the services that are responsible for a particular domain.  Returns
    # a hash reference to the structure.  Omit the 'domain' argument to simply
    # get ALL of the topology services in this LS.
    # 
    my $service = $dcn->getTopologyServices({ domain => "I2" });

    my $services = $dcn->getTopologyServices;
    foreach my $s (sort keys %$services) {
      print $s , "\n";
      foreach my $s2 (sort keys %{$services->{$s}}) {
        print "\t" , $s2 , " - " , $services->{$s}->{$s2} , "\n";

        # Dump the topology file
        # 

        my $topo = $dcn->queryTS( { topology => $s } );
        print "\t\t" , $topo->{eventType} , "\n" , $topo->{response} , "\n\n";
      }
      print "\n";
    }

    exit(1);
    
=head1 SEE ALSO

L<Log::Log4perl>, L<Params::Validate>, L<Digest::MD5>, L<English>,
L<XML::LibXML>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Utils::ParameterValidation>, L<perfSONAR_PS::Client::LS>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: DCN.pm 3661 2009-08-28 14:39:32Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

