package perfSONAR_PS::Services::MA::PingER;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::MA::PingER

=head1 DESCRIPTION

A module that implements MA service.  This module aims to offer simple methods
for dealing with requests for information, and the related tasks of intializing
the backend storage.  

=head1 API

=cut

use English qw( -no_match_vars);

use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;

use perfSONAR_PS::Client::LS::Remote;
use perfSONAR_PS::Services::MA::General;

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data';
use perfSONAR_PS::Datatypes::EventTypes;
use perfSONAR_PS::Datatypes::Message;

use perfSONAR_PS::Datatypes::PingER;
use perfSONAR_PS::DB::SQL::PingER;
use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::Topology::ID qw(idIsFQ);

use perfSONAR_PS::Services::Base;
use base 'perfSONAR_PS::Services::Base';
use Data::Dumper;

use fields qw( DATABASE LS_CLIENT eventTypes);
use warnings;
use Exporter;
use Params::Validate qw(:all);

use POSIX qw(strftime);

use constant CLASSPATH => 'perfSONAR_PS::Services::MA::PingER';

use Log::Log4perl qw(get_logger);
our $logger = get_logger( CLASSPATH );

# name of configuraiotn elements to pick up
our $basename = 'pingerma';

our $processName = 'perfSONAR-PS PingER MA';

=head2 new

create a new instance of the PingER MA

=cut

sub new {
    my $that  = shift;
    my $class = ref( $that ) || $that;
    my $self  = fields::new( $class );
    $self                = $self->SUPER::new( @_ );
    $self->{'DATABASE'}  = undef;
    $self->{'LS_CLIENT'} = undef;
    $self->{eventTypes}  = perfSONAR_PS::Datatypes::EventTypes->new();
    return $self;
}

=head2 init( $handler )

Initiate the MA; configure the configuration defaults, and message handlers.

=cut

sub init {
    my ( $self, $handler ) = @_;

    eval {

        # ls stuff
        $self->configureConf( 'enable_registration', undef, $self->getConf( 'enable_registration' ) );

        # info about service
        $self->configureConf( 'service_name', $processName, $self->getConf( 'service_name' ) );
        $self->configureConf( 'service_type', 'MA', $self->getConf( 'service_type' ) );

        my $default_description = $processName . ' Service';
        if ( $self->getConf( "site_name" ) ) {
            $default_description .= " at " . $self->getConf( "site_name" );
        }
        if ( $self->getConf( "site_location" ) ) {
            $default_description .= " in " . $self->getConf( "site_location" );
        }
        $self->configureConf( 'service_description', $default_description, $self->getConf( 'service_description' ) );
        
        if ( $self->getConf( "enable_registration" ) and not ( $self->getConf( "service_node" ) or $self->getConf( "node_id" ) ) ) {
            # XXX: For now we make this a hard fail since the rest of the GENI infrastructure will depend on it.
            $logger->logdie( "This service requires the service_node or node_id to be set, exiting." );
        }
        
        $self->configureConf( 'service_node', $self->getConf( 'node_id' ), $self->getConf( 'service_node' ) );
        
        if ( $self->getConf( "enable_registration" ) and not idIsFQ( $self->getConf( 'service_node' ), "node" ) ) {
            $logger->logdie( "service_node (or node_id) is not a fully-qualified UNIS node id, exiting." );
        }
        
        $self->configureConf( 'default_scheme', "http", $self->getConf( 'default_scheme' ) );
        
        my $default_accesspoint;
        if ( $self->getConf( "external_address" ) ) {
            $default_accesspoint = $self->getConf( 'default_scheme' ) . '://' . $self->getConf( "external_address" ) . ':' . $self->{PORT} . $self->{ENDPOINT};
        }
        
        $self->configureConf( 'service_accesspoint', $default_accesspoint, $self->getConf( 'service_accesspoint' ) );
        if ( $self->getConf( "enable_registration" ) and not $self->getConf( "service_accesspoint" ) ) {
            $logger->logdie( "Must have either a service_accesspoint or an external address specified if you enable registration" );
        }

        $self->configureConf( 'db_host', undef,              $self->getConf( 'db_host' ) );
        $self->configureConf( 'db_port', undef,              $self->getConf( 'db_port' ) );
        $self->configureConf( 'db_type', 'SQLite',           $self->getConf( 'db_type' ) );
        $self->configureConf( 'db_name', 'pingerMA.sqlite3', $self->getConf( 'db_name' ) );

        $self->configureConf( 'db_username', undef, $self->getConf( 'db_username' ) );
        $self->configureConf( 'db_password', undef, $self->getConf( 'db_password' ) );

        # other
        $self->configureConf( 'root_hints_url', 'http://www.perfsonar.net/gls.root.hints', $self->getConf( 'root_hints_url' ) );
        $self->configureConf( 'query_size_limit', undef, $self->getConf( 'query_size_limit' ) );

    };
    if ( $@ ) {
        $logger->error( "Configuration incorrect: $@" );
        return -1;
    }

    $logger->info( "Initialising PingER MA" );

    if ( $handler ) {
        $logger->debug( "Setting up message handlers" );
        $handler->registerEventHandler( "SetupDataRequest",   $self->{eventTypes}->tools->pinger, $self );
        $handler->registerEventHandler( "MetadataKeyRequest", $self->{eventTypes}->tools->pinger, $self );
        $handler->registerEventHandler( "SetupDataRequest",   $self->{eventTypes}->ops->select,   $self );
        $handler->registerEventHandler( "MetadataKeyRequest", $self->{eventTypes}->ops->select,   $self );

        my @eventTypes = ( $self->{eventTypes}->tools->pinger, $self->{eventTypes}->ops->select );
        $handler->registerMergeHandler( "MetadataKeyRequest", \@eventTypes, $self );
        $handler->registerMergeHandler( "SetupDataRequest",   \@eventTypes, $self );

    }

    # setup database
    $logger->debug( "initializing database " . $self->getConf( "db_type" ) );

    if ( $self->getConf( "db_type" ) eq "SQLite" || "mysql" ) {

        # setup DB  object
        eval {
            my $dbo = perfSONAR_PS::DB::SQL::PingER->new(
                {

                    driver   => $self->getConf( "db_type" ),
                    database => $self->getConf( "db_name" ),
                    host     => $self->getConf( "db_host" ),
                    port     => $self->getConf( "db_port" ),
                    username => $self->getConf( "db_username" ),
                    password => $self->getConf( "db_password" ),
                }
            );

            if ( $dbo->openDB() == 0 ) {
                $self->database( $dbo );
            }
            else {
                die " Failed to open DB" . $dbo->ERRORMSG;
            }
        };
        if ( $@ ) {
            $logger->logdie( "Could not open database '" . $self->getConf( 'db_type' ) . "' for '" . $self->getConf( 'db_name' ) . "' using '" . $self->getConf( 'db_username' ) . "'" . $@ );
        }

    }
    else {
        $logger->logdie( "Database type '" . $self->getConf( "db_type" ) . "' is not supported." );
        return -1;
    }

    # set name
    $0 = $processName;

    return 0;
}

=head2 database

accessor/mutator for database instance

=cut

sub database {
    my $self = shift;
    if ( @_ ) {
        $self->{DATABASE} = shift;
    }
    return $self->{DATABASE};
}

=head2 configureConf($self, $key, $default, $value)

TBD

=cut

sub configureConf {
    my $self    = shift;
    my $key     = shift;
    my $default = shift;
    my $value   = shift;

    my $fatal = shift;    # if set, then if there is no value, will return -1

    if ( defined $value ) {
        if ( $value =~ /^ARRAY/ ) {
            my $index = scalar @$value - 1;

            #$logger->info( "VALUE: $value,  SIZE: $index");

            $value = $value->[$index];
        }
        $self->{CONF}->{$basename}->{$key} = $value;
    }
    else {
        if ( !$fatal ) {
            if ( defined $default ) {
                $self->{CONF}->{$basename}->{$key} = $default;
                $logger->warn( "Setting '$key' to '$default'" );
            }
            else {
                $self->{CONF}->{$basename}->{$key} = undef;
                $logger->warn( "Setting '$key' to null" );
            }
        }
        else {
            $logger->logdie( "Value for '$key' is not set" );
        }
    }

    return 0;
}

=head2 getConf($self, $key)

TBD

=cut

sub getConf {
    my $self = shift;
    my $key  = shift;
    if ( defined $self->{'CONF'}->{$basename}->{$key} ) {
        $logger->debug( "Value for '$basename/$key' is set" );
        return $self->{'CONF'}->{$basename}->{$key};
    }
    else {
        return $self->{'CONF'}->{$key};
    }
}

=head2 ls

accessor/mutator for the lookup service

=cut

sub ls {
    my $self = shift;
    if ( @_ ) {
        $self->{'LS_CLIENT'} = shift;
    }
    return $self->{'LS_CLIENT'};
}

=head2 needLS

Should the instance of the PingER register with a LS?

=cut

sub needLS($) {
    my ( $self ) = @_;
    return $self->getConf( 'enable_registration' );
}

=head2 registerLS

register all the metadata that our ma contains to the LS

=cut

sub registerLS($) {
    my $self = shift;

    $0 = $processName . ' LS Registration';

    $logger->info( "Registering PingER MA with LS" );
    my @ls_array = ();
    my @array = split( /\s+/, $self->getConf( 'ls_instance' ) );
    foreach my $l ( @array ) {
        $l =~ s/(\s|\n)*//g;
        push @ls_array, $l if $l;
    }
    my @hints_array = ();
    @array = split( /\s+/, $self->getConf( "root_hints_url" ) );
    foreach my $h ( @array ) {
        $h =~ s/(\s|\n)*//g;
        push @hints_array, $h if $h;
    }

    # create new client if required
    if ( !defined $self->ls() ) {
        my $ls_conf = {
            'SERVICE_NODE'        => $self->getConf( 'service_node' ),
            'SERVICE_TYPE'        => $self->getConf( 'service_type' ),
            'SERVICE_NAME'        => $self->getConf( 'service_name' ),
            'SERVICE_DESCRIPTION' => $self->getConf( 'service_description' ),
            'SERVICE_ACCESSPOINT' => $self->getConf( 'service_accesspoint' ),
        };
        my $ls = new perfSONAR_PS::Client::LS::Remote( \@ls_array, $ls_conf, \@hints_array );
        $self->ls( $ls );
    }

    my @sendToLS = ();

    # open db
    my $metas = $self->database()->getMeta( [], 10000 );
    my $pingerMA = perfSONAR_PS::Datatypes::PingER->new();
    foreach my $metaid ( sort keys %{$metas} ) {
        my $md = $pingerMA->ressurectMd( { md_row => $metas->{$metaid} } );
        $md->set_eventType( $self->{eventTypes}->tools->pinger );
        push @sendToLS, $md->getDOM()->toString();

    }

    # foreach my $meta ( @sendToLS ) {
    #	    $logger->debug( "Found metadata for LS registration: '" . $meta . "'" );
    # }

    return $self->ls()->registerStatic( \@sendToLS );
}

=head2 handleMessageBegin( $self, $ret_message, $messageId, $messageType, $msgParams, $request, $retMessageType, $retMessageNamespaces )

TBD

=cut

sub handleMessageBegin($$$$$$$$) {
    my ( $self, $ret_message, $messageId, $messageType, $msgParams, $request, $retMessageType, $retMessageNamespaces );

    $0 = $processName . ' Query';

    return 1;
}

=head2 handleMessageEnd( $self, $ret_message, $messageId )

TBD

=cut

sub handleMessageEnd($$$) {
    my ( $self, $ret_message, $messageId );
    return 1;
}

=head2 handleEvent()

main access into MA from Daemon Architecture

=cut

sub handleEvent() {
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
        }
    );

    # shoudl do some validation on the eventType
    ${ $parameters->{"doOutputMetadata"} } = 0;

    my $response = $self->__handleEvent( $parameters->{"messageType"}, $parameters->{"rawRequest"}, \@{ $parameters->{"subject"} }, $parameters->{"data"}, $parameters->{"filterChain"}->[0], $parameters->{"messageParameters"} );

    ##### $response is
    foreach my $element ( @{ $response->get_metadata }, @{ $response->get_data } ) {
        $parameters->{"output"}->addExistingXMLElement( $element->getDOM() );
    }

    return;
}

=head2 __handleEvent( $request )

actually do something the incoming $request message.

=cut

sub __handleEvent {

    my ( $self, $messageType, $raw_request, $mds, $data, $filters, $message_parameters ) = @_;

#    $logger->debug( "\n\n\nRequest:\n" . Dumper $raw_request );

    $logger->debug( "  Type= $messageType md = " . $mds->[0]->toString . " Data=" . $data->toString );

    my $doc = $raw_request->getRequestDOM();

    my $arr_filters = [];
    if ( $filters && ref( $filters ) eq 'ARRAY' ) {
        foreach my $filter ( @{$filters} ) {
            $logger->debug( " Filter .... " . $filter->toString );
            push @{$arr_filters}, Metadata->new( $filter );
        }
    }
    $logger->debug( "Unmarshalling into PingER object" );
    my $pingerRequest = perfSONAR_PS::Datatypes::PingER->new(
        {
            metadata => [ Metadata->new( $mds->[0] ) ],
            data     => [ Data->new( $data ) ],
            filters  => $arr_filters
        }
    );
    my $error_msg = '';
    my $type      = $messageType;

    my $messageIdReturn = "message." . perfSONAR_PS::Common::genuid();
    ( my $responseType = $type ) =~ s/Request/Response/;

    $logger->debug( "Parsing request...Registering namespaces..." );
    $pingerRequest->registerNamespaces();
    ###$logger->debug("Done...");

    ### pass db handler down request object
    $logger->debug( "Creating PingER response" );
    my $pingerResponse = perfSONAR_PS::Datatypes::Message->new( { type => $responseType, id => $messageIdReturn } );    # response message
    $logger->debug( "Done..." );

    #	foreach my $field ($pingerResponse->show_fields('Public')) {
    #		$logger->debug("Pinger Response:  $field= " . $pingerResponse->{$field});
    #	}

    #### map namespaces on response
    $logger->debug( " Mapping namespaces on response" );
    $pingerResponse->set_nsmap( $pingerRequest->get_nsmap );
    $logger->debug( "Done..." );
    ###

    my $evt = $pingerRequest->eventTypes;
    ## setting up db object
    $pingerRequest->DBO( $self->database );
    my $errorMessage = $pingerRequest->handle( $type, $pingerResponse, $self->{'CONF'}->{'pingerma'} );

    $logger->debug( "PINGER RESPONSE: $errorMessage\n" . $pingerResponse->asString() );

    return $pingerResponse;
}

=head2 mergeMetadata

This function is called by the daemon if the module has registered a merge
handler and a md is found that needs to be merged with another md and has an
eventType that matches what's been registered with the daemon.

  messageType: The type of the message where the merging is occurring
  eventType: The event type in at least one of the md that caused this handler 
    to be chosen
  parentMd: The metadata that was metadataIdRef'd by the childMd
  childMd: The metadata that needs to be merged with its parent

=cut

sub mergeMetadata {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            messageType => 1,
            eventType   => 1,
            parentMd    => 1,
            childMd     => 1,
        }
    );

    my $parent_md = $parameters->{parentMd};
    my $child_md  = $parameters->{childMd};

    $logger->debug( "mergeMetadata called" );

    # Just use the default merge routine for now
    defaultMergeMetadata( $parent_md, $child_md );

    return;
}

1;

__END__

=head1 SYNOPSIS

    use perfSONAR_PS::Services::MA::PingER;
    
    
    my %conf = ();
    $conf{"METADATA_DB_TYPE"} = "xmldb";
    $conf{"METADATA_DB_NAME"} = "/home/netadmin/LHCOPN/perfSONAR-PS/MP/Ping/xmldb";
    $conf{"METADATA_DB_FILE"} = "pingerstore.dbxml";
    $conf{"SQL_DB_USER"} = "pinger";
    $conf{"SQL_DB_PASS"} = "pinger";
    $conf{"SQL_DB_DB"} = "pinger_pairs";
    
    my $pingerMA_conf = perfSONAR_PS::SimpleConfig->new( -FILE => 'pingerMA.conf', -PROMPTS => \%CONF_PROMPTS, -DIALOG => '1');
    my $config_data = $pingerMA_conf->parse(); 
    $pingerMA_conf->store;
    %conf = %{$pingerMA_conf->getNormalizedData()}; 
    my $ma = perfSONAR_PS::MA::PingER->new( \%con );

    # or
    # $self = perfSONAR_PS::MA::PingER->new;
    # $self->setConf(\%conf);
       
        
    $self->init;  
    while(1) {
      $self->receive;
      $self->respond;
    }  

=head1 SEE ALSO

L<perfSONAR_PS::MA::Base>, L<perfSONAR_PS::MA::General>, L<perfSONAR_PS::Common>, 
L<perfSONAR_PS::Messages>, L<perfSONAR_PS::DB::File>, L<perfSONAR_PS::DB::XMLDB>, 
L<perfSONAR_PS::DB::RRD>, L<perfSONAR_PS::Datatypes::Namespace>, L<perfSONAR_PS::SimpleConfig>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: PingER.pm 2821 2009-06-08 22:06:07Z maxim $

=head1 AUTHOR

Yee-Ting Li, ytl@slac.stanford.edu
Maxim Grigoriev, maxim@fnal.gov
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut
