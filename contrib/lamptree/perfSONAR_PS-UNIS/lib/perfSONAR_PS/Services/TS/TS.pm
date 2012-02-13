package perfSONAR_PS::Services::TS::TS;

use warnings;
use strict;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::TS::TS

=head1 DESCRIPTION

A module that provides methods for a Topology Service. The Topology Service can
be used to make Topology Data available to individuals via webservice interface.

This module, in conjunction with other parts of the perfSONAR-PS framework, handles
specific messages from interested actors in search of Topology data.

There are two major message types that this service can act upon:
    QueryRequest/SetupDataRequest   - Allows queries to the database
    TopologyChangeRequest           - Allows updates to the topology database

=head1 API

=cut

use base 'perfSONAR_PS::Services::Base';

use fields 'CLIENT', 'LS_CLIENT', 'LOGGER';

use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);

use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Topology::Common qw( normalizeTopology validateDomain validateNode validatePort validateLink getTopologyNamespaces );
use perfSONAR_PS::Topology::ID qw( idIsFQ idEncode idBaseLevel );
use perfSONAR_PS::DB::TopologyXMLDB;
use perfSONAR_PS::Client::LS::Remote;
use perfSONAR_PS::Utils::ParameterValidation;

use ProtoGENI::GeniCredential;

=head2 init 

Called at startup by the daemon when this particular module is loaded into the
perfSONAR-PS deployment. Checks the configuration file for the necessary items
and fills in others when needed. Initializes the backed metadata storage (Oracle
Sleepycat XML Database). Finally the message handler registers the appropriate
message types and eventTypes for this module. Any other 'pre-startup' tasks
should be placed in this function.

=cut

sub init {
    my ( $self, $handler ) = @_;

    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::TS" );

    if ( not exists $self->{CONF}->{"topology"}->{"db_type"} or $self->{CONF}->{"topology"}->{"db_type"} eq q{} ) {
        $self->{LOGGER}->error( "No database type specified" );
        return -1;
    }

    if ( lc( $self->{CONF}->{"topology"}->{"db_type"} ) eq "xml" ) {
        if ( not exists $self->{CONF}->{"topology"}->{"db_file"} or $self->{CONF}->{"topology"}->{"db_file"} eq q{} ) {
            $self->{LOGGER}->error( "You specified a Sleepycat XML DB Database, but then did not specify a database file (db_file)" );
            return -1;
        }

        if ( not exists $self->{CONF}->{"topology"}->{"db_environment"} or $self->{CONF}->{"topology"}->{"db_environment"} eq q{} ) {
            $self->{LOGGER}->error( "You specified a Sleepycat XML DB Database, but then did not specify a database name (db_environment)" );
            return -1;
        }

        my $environment = $self->{CONF}->{"topology"}->{"db_environment"};
        if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} ) {
            unless ( $environment =~ "^/" ) {
                $environment = $self->{DIRECTORY} . "/" . $environment;
            }
        }

        my $read_only = 0;

        if ( exists $self->{CONF}->{"topology"}->{"read_only"} and $self->{CONF}->{"topology"}->{"read_only"} == 1 ) {
            $read_only = 1;
        }

        my $file = $self->{CONF}->{"topology"}->{"db_file"};
        my %ns   = getTopologyNamespaces();

        $self->{CLIENT} = perfSONAR_PS::DB::TopologyXMLDB->new();
        $self->{CLIENT}->init( { directory => $environment, file => $file, namespaces => \%ns, read_only => $read_only } );
    }
    else {
        $self->{LOGGER}->error( "Invalid database type specified" );
        return -1;
    }

    if ( $self->{CONF}->{"topology"}->{"enable_registration"} ) {
        unless ( exists $self->{CONF}->{service_accesspoint} and $self->{CONF}->{service_accesspoint} ) {
            unless ( exists $self->{CONF}->{external_address} and $self->{CONF}->{external_address} ) {
                $self->{LOGGER}->error( "With LS registration enabled, you need to specify either the service accessPoint for the service or the external_address" );
                return -1;
            }

            $self->{LOGGER}->info( "Setting service access point to http://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT} );
            $self->{CONF}->{"topology"}->{"service_accesspoint"} = "http://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT};
        }

        unless ( exists $self->{CONF}->{"topology"}->{"ls_instance"} and $self->{CONF}->{"topology"}->{"ls_instance"} ) {
            $self->{CONF}->{"topology"}->{"ls_instance"} = $self->{CONF}->{"ls_instance"};
        }

        unless ( exists $self->{CONF}->{"topology"}->{"ls_instance"} and $self->{CONF}->{"topology"}->{"ls_instance"} ) {
            $self->{LOGGER}->warn( "No LS instance specified for Topology Service. Will select one to register with." );

            unless ( exists $self->{CONF}->{"root_hints_url"} and $self->{CONF}->{"root_hints_url"} ) {
                $self->{CONF}->{"root_hints_url"} = "http://www.perfsonar.net/gls.root.hints";
                $self->{LOGGER}->warn( "gLS Hints file not set, using default at \"http://www.perfsonar.net/gls.root.hints\"." );
            }
        }

        if ( not exists $self->{CONF}->{"topology"}->{"ls_registration_interval"} or $self->{CONF}->{"topology"}->{"ls_registration_interval"} eq q{} ) {
            if ( exists $self->{CONF}->{"ls_registration_interval"} and $self->{CONF}->{"ls_registration_interval"} ne q{} ) {
                $self->{CONF}->{"topology"}->{"ls_registration_interval"} = $self->{CONF}->{"ls_registration_interval"};
            }
            else {
                $self->{LOGGER}->warn( "Setting registration interval to 30 minutes" );
                $self->{CONF}->{"topology"}->{"ls_registration_interval"} = 1800;
            }
        }
        else {

            # turn the registration interval from minutes to seconds
            $self->{CONF}->{"topology"}->{"ls_registration_interval"} *= 60;
        }

        unless ( exists $self->{CONF}->{"topology"}->{"service_description"} and $self->{CONF}->{"topology"}->{"service_description"} ) {
            my $description = "perfSONAR_PS Topology Service";
            if ( exists $self->{CONF}->{site_name} and $self->{CONF}->{site_name} ) {
                $description .= " at " . $self->{CONF}->{site_name};
            }
            if ( exists $self->{CONF}->{site_location} and $self->{CONF}->{site_location} ) {
                $description .= " in " . $self->{CONF}->{site_location};
            }
            $self->{CONF}->{"topology"}->{"service_description"} = $description;
            $self->{LOGGER}->warn( "Setting 'service_description' to '$description'." );
        }

        if ( not exists $self->{CONF}->{"topology"}->{"service_name"}
            or $self->{CONF}->{"topology"}->{"service_name"} eq q{} )
        {
            $self->{CONF}->{"topology"}->{"service_name"} = "Topology Service";
            $self->{LOGGER}->warn( "Setting 'service_name' to 'Topology Service'." );
        }

        if ( not exists $self->{CONF}->{"topology"}->{"service_type"}
            or $self->{CONF}->{"topology"}->{"service_type"} eq q{} )
        {
            $self->{CONF}->{"topology"}->{"service_type"} = "TS";
            $self->{LOGGER}->warn( "Setting 'service_type' to 'TS'." );
        }
        
        unless ( exists $self->{CONF}->{"topology"}->{"service_node"} and $self->{CONF}->{"topology"}->{"service_node"} ) {
            unless ( exists $self->{CONF}->{"topology"} and $self->{CONF}->{"node_id"} ) {
                # XXX: For now we make this a hard fail since the rest of the GENI infrastructure will depend on it.
                $self->{LOGGER}->fatal( "This service requires the service_node or node_id to be set, exiting." );
                return -1;
            }
            $self->{CONF}->{"topology"}->{"service_node"} = $self->{CONF}->{"node_id"};
        }
        
        unless ( idIsFQ( $self->{CONF}->{"topology"}->{"service_node"}, "node" ) ) {
            $self->{LOGGER}->fatal( "service_node (or node_id) is not a fully-qualified UNIS node id, exiting." );
            return -1;
        }
    }

    $handler->registerEventHandler( "QueryRequest",     "http://ggf.org/ns/nmwg/topology/20070809", $self );
    $handler->registerEventHandler( "TSQueryRequest",   "http://ggf.org/ns/nmwg/topology/20070809", $self );
    $handler->registerEventHandler( "TSAddRequest",     "http://ggf.org/ns/nmwg/topology/20070809", $self );
    $handler->registerEventHandler( "TSUpdateRequest",  "http://ggf.org/ns/nmwg/topology/20070809", $self );
    $handler->registerEventHandler( "TSReplaceRequest", "http://ggf.org/ns/nmwg/topology/20070809", $self );

    # For compatibility with older versions of the software.
    $handler->registerEventHandler( "SetupDataRequest",      "http://ggf.org/ns/nmwg/topology/query/xquery/20070809",   $self );
    $handler->registerEventHandler( "SetupDataRequest",      "http://ggf.org/ns/nmwg/topology/query/all/20070809",      $self );
    $handler->registerEventHandler( "TopologyChangeRequest", "http://ggf.org/ns/nmwg/topology/change/add/20070809",     $self );
    $handler->registerEventHandler( "TopologyChangeRequest", "http://ggf.org/ns/nmwg/topology/change/update/20070809",  $self );
    $handler->registerEventHandler( "TopologyChangeRequest", "http://ggf.org/ns/nmwg/topology/change/replace/20070809", $self );
    
    return 0;
}

=head2 needLS

Returns whether or not this service will be registering with a Lookup Service.

=cut

sub needLS {
    my ( $self ) = @_;

    return ( $self->{CONF}->{"topology"}->{"enable_registration"} );
}

=head2 registerLS($self $sleep_time)

Given the service information (specified in configuration) and the contents of
our xmldb backend, we can contact the specified LS and register the top-level
identifiers (a summarized form of the elements in the database).

=cut

sub registerLS {
    my ( $self, $sleep_time ) = @_;
    my ( $status, $res1 );

    unless ( exists $self->{LS_CLIENT} and $self->{LS_CLIENT} ) {
        my %ls_conf = (
            SERVICE_NODE             => $self->{CONF}->{"topology"}->{"service_node"},
            SERVICE_TYPE             => $self->{CONF}->{"topology"}->{"service_type"},
            SERVICE_NAME             => $self->{CONF}->{"topology"}->{"service_name"},
            SERVICE_DESCRIPTION      => $self->{CONF}->{"topology"}->{"service_description"},
            SERVICE_ACCESSPOINT      => $self->{CONF}->{"topology"}->{"service_accesspoint"},
            LS_REGISTRATION_INTERVAL => $self->{CONF}->{"topology"}->{"registration_interval"},
        );

        my @hints_array = ();
        unless ( exists $self->{CONF}->{"topology"}->{"ls_instance"} and $self->{CONF}->{"topology"}->{"ls_instance"} ) {
            my @array = split( /\s+/, $self->{CONF}->{"root_hints_url"} );
            foreach my $h ( @array ) {
                $h =~ s/(\s|\n)*//g;
                push @hints_array, $h if $h;
            }
        }

        $self->{LS_CLIENT} = perfSONAR_PS::Client::LS::Remote->new( $self->{CONF}->{"topology"}->{"ls_instance"}, \%ls_conf, \@hints_array );
    }

    ( $status, $res1 ) = $self->{CLIENT}->open;
    if ( $status != 0 ) {
        my $msg = "Couldn't open from database: $res1";
        $self->{LOGGER}->error( $msg );
        return -1;
    }

    ( $status, $res1 ) = $self->buildSummary;
    if ( $status != 0 ) {
        my $msg = "Couldn't get topology summary from database: $res1";
        $self->{LOGGER}->error( $msg );
        return -1;
    }

    my @mds    = ();
    my @md_ids = ();
    
    # GFR: Why do we need one metadata per domain/network/path0?
    #   Changed to create a single one, and we're also registering when there's none.
    #foreach my $info ( @{} ) {
        my ( $md, $md_id ) = buildLSMetadata( $res1 );
        push @mds, $md;
    #}
    
    unless ( exists $self->{CONF}->{"topology"}->{"ls_instance"} and $self->{CONF}->{"topology"}->{"ls_instance"} ) {
        $self->{LOGGER}->warn( "No LS instance specified for Topology Service. Will select one to register with." );
    }
    
    my $n = $self->{LS_CLIENT}->registerDynamic( \@mds );
    
    if ( $sleep_time ) {
        ${$sleep_time} = $self->{CONF}->{"topology"}->{"ls_registration_interval"};
    }
    
    return $n;
}

=head2 buildLSMetadata ($id, $type, $prefix, $url)

This function is used to build the metadata that is registered with the LS.
This element contains the prefix and the local name of the element to be
register as well as the id for that element. 

=cut

sub buildLSMetadata {
    my ( $elements ) = @_;
    my $md    = q{};
    my $md_id = "meta" . genuid();

    $md .= "<nmwg:metadata id=\"$md_id\">\n";
    $md .= "<nmwg:subject id=\"sub0\">\n";
    for my $info ( @{ $elements } ) {
        my ( $id, $type, $prefix, $uri ) = ( $info->{id}, $info->{type}, $info->{prefix}, $info->{uri} );
        if ( not defined $prefix or $prefix eq q{} ) {
            $md .= " <$type xmlns=\"$uri\" id=\"$id\" />\n";
        }
        else {
            $md .= " <$prefix:$type xmlns:$prefix=\"$uri\" id=\"$id\" />\n";
        }
    }
    $md .= "</nmwg:subject>\n";
    $md .= "<nmwg:eventType>topology</nmwg:eventType>\n";
    $md .= "<nmwg:eventType>http://ggf.org/ns/nmwg/topology/20070809</nmwg:eventType>\n";
    $md .= "<nmwg:eventType>http://ggf.org/ns/nmwg/topology/query/all/20070809</nmwg:eventType>\n";
    $md .= "<nmwg:eventType>http://ggf.org/ns/nmwg/topology/query/xquery/20070809</nmwg:eventType>\n";
    $md .= "<nmwg:eventType>http://ggf.org/ns/nmwg/topology/change/add/20070809</nmwg:eventType>\n";
    $md .= "<nmwg:eventType>http://ggf.org/ns/nmwg/topology/change/update/20070809</nmwg:eventType>\n";
    $md .= "<nmwg:eventType>http://ggf.org/ns/nmwg/topology/change/replace/20070809</nmwg:eventType>\n";
    $md .= "<nmwg:eventType>http://perfsonar.net/ns/protogeni/auth/credential/1</nmwg:eventType>\n";
    $md .= "</nmwg:metadata>\n";

    return ( $md, $md_id );
}

=head2 buildSummary($self)

A function used by the service to pull out the set of identifiers used that get
registered with the Lookup Service. Longer term, it should produce a more
complex summary to register.

=cut

sub buildSummary {
    my ( $self ) = @_;
    my $error;
    my ( @domain_ids, @network_ids, @path_ids );

    my ( $status, $results ) = $self->{CLIENT}->getAll();
    if ( $status != 0 ) {
        return ( $status, $results );
    }

    my @ids = ();

    my $find_res;

    $find_res = find( $results, "./*[local-name()='domain']", 0 );
    if ( $find_res ) {
        foreach my $node ( $find_res->get_nodelist ) {
            my $id     = $node->getAttribute( "id" );
            my $uri    = $node->namespaceURI();
            my $prefix = $node->prefix;

            my %info = (
                type   => 'domain',
                id     => $id,
                prefix => $prefix,
                uri    => $uri,
            );

            push @ids, \%info;
        }
    }

    $find_res = find( $results, "./*[local-name()='network']", 0 );
    if ( $find_res ) {
        foreach my $node ( $find_res->get_nodelist ) {
            my $id     = $node->getAttribute( "id" );
            my $uri    = $node->namespaceURI();
            my $prefix = $node->prefix;

            my %info = (
                type   => 'network',
                id     => $id,
                prefix => $prefix,
                uri    => $uri,
            );

            push @ids, \%info;
        }
    }

    $find_res = find( $results, "./*[local-name()='path']", 0 );
    if ( $find_res ) {
        foreach my $node ( $find_res->get_nodelist ) {
            my $id     = $node->getAttribute( "id" );
            my $uri    = $node->namespaceURI();
            my $prefix = $node->prefix;

            my %info = (
                type   => 'path',
                id     => $id,
                prefix => $prefix,
                uri    => $uri,
            );

            push @ids, \%info;
        }
    }

    return ( 0, \@ids );
}

=head2 handleEvent

This is the function that is called by the daemon whenever a metadata/data pair
with one of our eventTypes is found in a message we've regeistered in.

=cut

sub handleEvent {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            output            => 1,
            messageId         => 1,
            messageType       => 1,
            messageParameters => 1,
            eventType         => 1,
            subject           => 1,
            filterChain       => 1,
            data              => 1,
            rawRequest        => 1,
            doOutputMetadata  => 1,
            credentials       => 1,
        }
    );

    my $output             = $parameters->{"output"};
    my $messageId          = $parameters->{"messageId"};
    my $messageType        = $parameters->{"messageType"};
    my $message_parameters = $parameters->{"messageParameters"};
    my $eventType          = $parameters->{"eventType"};
    my $d                  = $parameters->{"data"};
    my $raw_request        = $parameters->{"rawRequest"};
    my @subjects           = @{ $parameters->{"subject"} };
    my $md                 = $subjects[0];

    my @filters = @{ $parameters->{"filterChain"} };
    if ( $#filters > -1 ) {
        throw perfSONAR_PS::Error_compat( "error.ma.select", "Topology Service does not yet support filtering" );
    }
    
    my %slices = ();
    for my $credential ( @{ $parameters->{"credentials"} } ) {
        if ( $credential->IsSliceCredential() ) {
            my $slice_id = $credential->target_urn();
            # Remove URN prefix (urn:publicid:IDN+)
            $slice_id =~ s/^[^+]*\+//;
            $slice_id = idEncode( $slice_id );
            $slices{  $slice_id } = $credential;
        }
    }
    
    # LAMP service certificates get special permission for their slice
    # GFR: This is bound to change, it's here just for the demo
    if ( exists $ENV{'GENIURN'} and 
        $ENV{'GENIURN'} =~ /^urn:publicid:IDN\+(.+)\+service\+.+@(.+)$/ ) {
        my $slice_id = idEncode( $1 . '+slice+' . $2 );
        $slices{ $slice_id } = 1 unless exists $slices{  $slice_id };
    }

    if ( not %slices ) {
        throw perfSONAR_PS::Error_compat( "error.topology.policy", "You must supply at least one Slice Credential" );
    }
    
    my ( $status, $res ) = $self->{CLIENT}->open;
    if ( $status != 0 ) {
        my $msg = "Couldn't open database";
        $self->{LOGGER}->error( "Error changing topology: $res" );
        throw perfSONAR_PS::Error_compat( "error.topology.ma", $msg );
    }

    if ( $messageType eq "SetupDataRequest" ) {
        $self->handleSetupDataRequest( $output, $eventType, $md, $d, \%slices );
    }
    elsif ( $messageType eq "QueryRequest" or $messageType eq "TSQueryRequest" ) {
        $self->handleQueryRequest( $output, $eventType, $md, $d, \%slices );
    }
    elsif ( $messageType eq "TSAddRequest" ) {
        $self->handleChangeTopologyRequest( $output, "add", $md, $d, \%slices );
    }
    elsif ( $messageType eq "TSUpdateRequest" ) {
        $self->handleChangeTopologyRequest( $output, "update", $md, $d, \%slices );
    }
    elsif ( $messageType eq "TSReplaceRequest" ) {
        $self->handleChangeTopologyRequest( $output, "replace", $md, $d, \%slices );

        #    } elsif ($messageType eq "TSRemoveRequest") {
        #        $self->handleChangeTopologyRequest($output, "remove", $m, $d);
    }

    return;
}

=head2 handleQueryRequest ($self, $output, $eventType, $m, $d)

This function handles the (hopefully to be standardized) QueryRequest message.
The semantics of the message are as follows:

If no subject is included, the semantics are "give me the whole database", and
an XQuery for "/*" (i.e. everything) is submitted to the backend database.

If an xquery subject is included, the semantics are "use the included XQuery to
query the database". It simply passes the included XQuery to the backend
database.

If any other subject is included, an invalid subject error is thrown.

=cut

sub handleQueryRequest {
    my ( $self, $output, $eventType, $m, $d, $slices ) = @_;

    my $subjects = find( $m, "./*[local-name()='subject']", 0 );
    if ( $subjects->size() > 1 ) {
        throw perfSONAR_PS::Error_compat( "error.ma.subject", "Multiple subjects specified" );
    }

    my $xquery;

    if ( $subjects->size() == 0 ) {

        # no subject is the query all request
        $xquery = "/*";
    }
    else {
        my $subject = $subjects->get_node( 1 );
        if ( $subject->namespaceURI() eq "http://ggf.org/ns/nmwg/tools/org/perfsonar/xquery/1.0/" ) {
            $xquery = $subject->textContent;
        }
        else {
            throw perfSONAR_PS::Error_compat( "error.ma.subject", "Invalid subject type: " . $subject->namespaceURI() );
        }
    }
    
    #
    # GENI: We limit lookups to the domains for which credentials
    #   were provided. The xQuery is applied to the filtered dataset. 
    #
    # TODO: BUG: find() is not xQuery compatible, it only takes xPath 1.0 
    #
    my $db = $self->getRestrictedDBView( $slices );
    my $find_res = find( $db, $xquery );
    
    my $dataContent = "";
    if ( $find_res ) {
        foreach my $node ( $find_res->get_nodelist ) {
            $dataContent .= $node->toString() ;
        }
    }
    
    my %namespaces = getTopologyNamespaces();
    createData( $output, "data." . genuid(), $m->getAttribute( "id" ), $dataContent, { unis => $namespaces{unis} } );

    return;
}

=head2 handleSetupDataRequest ($self, $output, $eventType, $m, $d)

This function handles the older protocol's query mechanism. The semantics of the
message are as follows:

If an "http://ggf.org/ns/nmwg/topology/query/all/20070809" eventType is included
in the metadata, the entire backend database is returned.

If an "http://ggf.org/ns/nmwg/topology/query/xquery/20070809" eventType is
included in the metadata, an xquery subject must be included as well. The xquery
inside the xquery subject will be passed to the backend database.

=cut

sub handleSetupDataRequest {
    my ( $self, $output, $eventType, $m, $d, $slices ) = @_;
    my $dataContent = "";

    #
    # GENI: We limit lookups to the domains for which credentials
    #   were provided. The xQuery is applied to the filtered dataset. 
    #
    my $db = $self->getRestrictedDBView( $slices );
    
    if ( $eventType eq "http://ggf.org/ns/nmwg/topology/query/all/20070809" ) {
        $dataContent = $db->toString();
    }
    elsif ( $eventType eq "http://ggf.org/ns/nmwg/topology/query/xquery/20070809" ) {
        my $query = findvalue( $m, "./xquery:subject" );

        if ( not defined $query or $query eq q{} ) {
            my $msg = "No query given in request";
            $self->{LOGGER}->error( $msg );
            throw perfSONAR_PS::Error_compat( "error.topology.query.query_not_found", $msg );
        }
        
        my $find_res = find( $db, $query );
        if ( $find_res ) {
            foreach my $node ( $find_res->get_nodelist ) {
                $dataContent .= $node->toString() ;
            }
        }
    }
    
    my %namespaces = getTopologyNamespaces();
    createData( $output, "data." . genuid(), $m->getAttribute( "id" ), $dataContent, { unis => $namespaces{unis} } );

    return;
}

=head2 handleChangeTopologyRequest 

The hope is to standardize the information changing protocol between the LS and
the Topology Service. In the interim, this handler handle metadata/data pairs
corresponding to the current TS protocol.

The metadata contains an eventType specifying how the data should modify the
backend database and the data contains a topology wrapper containing the
topology elements to add or update.

If the eventType is "http://ggf.org/ns/nmwg/topology/change/add/20070809", the
elements in the data segment are added to the database. If any of the elements
(based on identifiers), already exist in the database, an error is returned. 

If the eventType is "http://ggf.org/ns/nmwg/topology/change/update/20070809",
the elements in the data segment are merged with the existing elements with the
same identifier in the database. If any element in the data segment does not
exist in the database, an error will be returned.

If the eventType is "http://ggf.org/ns/nmwg/topology/change/replace/20070809",
the elements in the data segment are added to the database. If any of the
elements already exist in the database, they will be replaced with the element
in the data segment.

GENI: The only top-level element (inside the topology wrapper) accepted is
domain. The domain id must be the GENI slice id as <authority>+slice+<id>.
A credential must be presented for each domain. 

=cut

sub handleChangeTopologyRequest {
    my ( $self, $output, $changeType, $m, $d, $slices ) = @_;
    my ( $status, $res );

    my $topology = find( $d, "./*[local-name()='topology']", 1 );

    unless ( defined $topology ) {
        my $msg = "No topology defined in change topology request for metadata: " . $m->getAttribute( "id" );
        $self->{LOGGER}->error( "Error changing topology: $msg" );
        throw perfSONAR_PS::Error_compat( "error.topology.query.topology_not_found", $msg );
    }

    ( $status, $res ) = normalizeTopology( $topology, $changeType );
    if ( $status != 0 ) {
        $self->{LOGGER}->error( "Couldn't normalize topology" );
        throw perfSONAR_PS::Error_compat( "error.topology.invalid_topology", $res );
    }
    
    #
    # GENI: Verify that we have the credentials for each domain
    #   we are trying to change. The domain id must match the slice id.
    #
    my $find_res = find( $topology, "./*[local-name()='domain']", 0 );
    if ( $find_res ) {
        foreach my $domain ( $find_res->get_nodelist ) {
            my $idvalue = idBaseLevel( $domain->getAttribute( "id" ) );
            
            if ( not exists $slices->{ $idvalue } ) {
                $self->{LOGGER}->error( "No credential given for domain $idvalue" );
                throw perfSONAR_PS::Error_compat( "error.topology.policy", "No credential given for domain $idvalue" );
            }
        }
    }
    
    ( $status, $res ) = $self->{CLIENT}->changeTopology( $changeType, $topology );
    if ( $status != 0 ) {
        $self->{LOGGER}->error( "Error handling topology request" );
        throw perfSONAR_PS::Error_compat( "error.topology.ma", $res );
    }

    my $changeDesc;
    my $mdID = "metadata." . genuid();

    if ( $changeType eq "add" ) {
        $changeDesc = "added";
    }
    elsif ( $changeType eq "replace" ) {
        $changeDesc = "replaced";
    }
    elsif ( $changeType eq "update" ) {
        $changeDesc = "updated";
    }

    getResultCodeMetadata( $output, $mdID, $m->getAttribute( "id" ), "success.ma." . $changeDesc );
    getResultCodeData( $output, "data." . genuid(), $mdID, "data element(s) successfully $changeDesc", 1 );

    return;
}

=head2 getRestrictedDBView 

GENI: We limit lookups to the domains for which credentials
were provided. This method returns a partil view of the database
based on the permissions of the user. 

=cut

sub getRestrictedDBView {
    my ( $self, $slices ) = @_;
    
    my $dbquery = '//*[local-name()=\'domain\' and @id[substring-after(.,\'urn:ogf:network:domain=\')=(';
    for my $slice ( keys %{ $slices } ) {
        $dbquery = $dbquery . "'$slice',";
    }
    chop $dbquery;
    $dbquery = $dbquery . ")]]";
    
    my ( $status, $res ) = $self->{CLIENT}->xQuery( $dbquery );
    if ( $status != 0 ) {
        my $msg = "Database query failed: $res";
        $self->{LOGGER}->error( $msg );
        throw perfSONAR_PS::Error_compat( "error.common.storage.query", $msg );
    }
    
    my $dbview = parseToDOM( $res );
    
    if ( $dbview eq -1 ) {
        my $msg = "Database parsing failed";
        throw perfSONAR_PS::Error_compat( "error.common.internal_error", $msg );
    }
    
    return $dbview;
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::Base>, L<perfSONAR_PS::Services::MA::General>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Messages>,
L<perfSONAR_PS::Client::LS::Remote>, L<perfSONAR_PS::Topology::Common>,
L<perfSONAR_PS::Client::Topology::XMLDB>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: TS.pm 2721 2009-04-03 16:55:55Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
