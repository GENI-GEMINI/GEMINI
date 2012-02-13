package perfSONAR_PS::Services::MP::Skeleton;

use base 'perfSONAR_PS::Services::Base';

use fields 'LS_CLIENT', 'NAMESPACES', 'METADATADB', 'LOGGER', 'STORE_FILE_MTIME', 'BAD_MTIME';

use strict;
use warnings;

our $VERSION = 3.2;

=head1 NAME

perfSONAR_PS::Services::MP::Skeleton

=head1 DESCRIPTION

TBD

=cut

use Storable qw( nfreeze freeze thaw );
use File::Temp qw(tempfile);
use Log::Log4perl qw(get_logger);
use Module::Load;
use Digest::MD5 qw(md5_hex);
use English qw( -no_match_vars );
use Params::Validate qw(:all);
use Date::Manip;
use File::Copy;

use perfSONAR_PS::Services::MA::General;
use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Client::LS::Remote;
use perfSONAR_PS::Error_compat qw/:try/;
use perfSONAR_PS::DB::File;
use perfSONAR_PS::Utils::ParameterValidation;

# JZ 12/14/2010
#
# Unused stub functions, leave these alone! 

sub handleMessageBegin {
    return;
}

sub handleMessageEnd {
    return;
}

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=head2 init($self, $handler)

Called at startup by the daemon when this particular module is loaded into
the perfSONAR-PS deployment.  Checks the configuration file for the necessary
items and fills in others when needed. Initializes the backed metadata storage.
Finally the message handler loads the appropriate message types and eventTypes
for this module.  Any other 'pre-startup' tasks should be placed in this
function.

=cut

sub init {
    my ( $self, $handler ) = @_;

    # JZ 12/14/2010
    #
    # The init function should check the values that are in the configuration
    # file and set some of the global variables.  

    $self->{LOGGER}    = get_logger( "perfSONAR_PS::Services::MP::Skeleton" );

    unless ( exists $self->{CONF}->{"root_hints_url"} ) {
        $self->{CONF}->{"root_hints_url"} = q{};
        $self->{LOGGER}->info( "gLS Hints file was not set, automatic discovery of hLS instance disabled." );
    }

    if ( exists $self->{CONF}->{"root_hints_file"} and $self->{CONF}->{"root_hints_file"} ) {
        unless ( $self->{CONF}->{"root_hints_file"} =~ "^/" ) {
            $self->{CONF}->{"root_hints_file"} = $self->{DIRECTORY} . "/" . $self->{CONF}->{"root_hints_file"};
            $self->{LOGGER}->debug( "Setting full path to 'root_hints_file': \"" . $self->{CONF}->{"root_hints_file"} . "\"" );
        }
    }
    else {
        $self->{CONF}->{"root_hints_file"} = $self->{DIRECTORY} . "/gls.root.hints";
        $self->{LOGGER}->info( "Setting 'root_hints_file': \"" . $self->{CONF}->{"root_hints_file"} . "\"" );
    }

    if ( exists $self->{CONF}->{"skeleton"}->{"data_file"} and $self->{CONF}->{"skeleton"}->{"data_file"} ) {
        if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} and -d $self->{DIRECTORY} ) {
            unless ( $self->{CONF}->{"skeleton"}->{"data_file"} =~ "^/" ) {
                $self->{CONF}->{"skeleton"}->{"data_file"} = $self->{DIRECTORY} . "/" . $self->{CONF}->{"skeleton"}->{"data_file"};
                $self->{LOGGER}->info( "Setting \"data_file\" to \"" . $self->{DIRECTORY} . "/" . $self->{CONF}->{"skeleton"}->{"data_file"} . "\"" );
            }
        }
    }
    else {
        $self->{LOGGER}->fatal( "Value for 'data_file' is not set." );
        return -1;
    }

    unless ( exists $self->{CONF}->{"skeleton"}->{"metadata_db_type"}
        and $self->{CONF}->{"skeleton"}->{"metadata_db_type"} )
    {
        $self->{LOGGER}->fatal( "Value for 'metadata_db_type' is not set." );
        return -1;
    }

    if ( $self->{CONF}->{"skeleton"}->{"metadata_db_type"} eq "file" ) {
        if ( exists $self->{CONF}->{"skeleton"}->{"metadata_db_file"} and $self->{CONF}->{"skeleton"}->{"metadata_db_file"} ) {
            if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} and -d $self->{DIRECTORY} ) {
                unless ( $self->{CONF}->{"skeleton"}->{"metadata_db_file"} =~ "^/" ) {
                    $self->{CONF}->{"skeleton"}->{"metadata_db_file"} = $self->{DIRECTORY} . "/" . $self->{CONF}->{"skeleton"}->{"metadata_db_file"};
                    $self->{LOGGER}->info( "Setting \"metadata_db_file\" to \"" . $self->{DIRECTORY} . "/" . $self->{CONF}->{"skeleton"}->{"metadata_db_file"} . "\"" );
                }
            }
        }
        else {
            $self->{LOGGER}->fatal( "Value for 'metadata_db_file' is not set." );
            return -1;
        }
    }
    else {
        $self->{LOGGER}->fatal( "Wrong value for 'metadata_db_type' set." );
        return -1;
    }

    unless ( exists $self->{CONF}->{"skeleton"}->{"enable_registration"} ) {
        if ( exists $self->{CONF}->{"enable_registration"} and $self->{CONF}->{"enable_registration"} ) {
            $self->{CONF}->{"skeleton"}->{"enable_registration"} = $self->{CONF}->{"enable_registration"};
        }
        else {
            $self->{CONF}->{"enable_registration"} = 0;
            $self->{CONF}->{"skeleton"}->{"enable_registration"} = 0;
        }
        $self->{LOGGER}->warn( "Setting 'enable_registration' to \"" . $self->{CONF}->{"skeleton"}->{enable_registration} . "\"." );
    }

    if ( $self->{CONF}->{"skeleton"}->{"enable_registration"} ) {
        unless ( exists $self->{CONF}->{"skeleton"}->{"ls_instance"}
            and $self->{CONF}->{"skeleton"}->{"ls_instance"} )
        {
            if ( defined $self->{CONF}->{"ls_instance"}
                and $self->{CONF}->{"ls_instance"} )
            {
                $self->{LOGGER}->warn( "Setting \"ls_instance\" to \"" . $self->{CONF}->{"ls_instance"} . "\"" );
                $self->{CONF}->{"skeleton"}->{"ls_instance"} = $self->{CONF}->{"ls_instance"};
            }
            else {
                $self->{LOGGER}->warn( "No LS instance specified for SNMP service" );
            }
        }

        unless ( exists $self->{CONF}->{"skeleton"}->{"ls_registration_number"}
            and $self->{CONF}->{"skeleton"}->{"ls_registration_number"} )
        {
            $self->{LOGGER}->warn( "Setting registration number to 2 hosts (e.g. will not register to anymore than 2 LS instances) " );
            $self->{CONF}->{"skeleton"}->{"ls_registration_number"} = 2;
        }

        unless ( exists $self->{CONF}->{"skeleton"}->{"ls_registration_interval"}
            and $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} )
        {
            if ( defined $self->{CONF}->{"ls_registration_interval"}
                and $self->{CONF}->{"ls_registration_interval"} )
            {
                $self->{LOGGER}->warn( "Setting \"ls_registration_interval\" to \"" . $self->{CONF}->{"ls_registration_interval"} . "\"" );
                $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} = $self->{CONF}->{"ls_registration_interval"};
            }
            else {
                $self->{LOGGER}->warn( "Setting registration interval to 4 hours" );
                $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} = 14400;
            }
        }

        if ( not $self->{CONF}->{"skeleton"}->{"service_accesspoint"} ) {
            unless ( $self->{CONF}->{external_address} ) {
                $self->{LOGGER}->fatal( "With LS registration enabled, you need to specify either the service accessPoint for the service or the external_address" );
                return -1;
            }
            $self->{LOGGER}->info( "Setting service access point to http://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT} );
            $self->{CONF}->{"skeleton"}->{"service_accesspoint"} = "http://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT};
        }

        unless ( exists $self->{CONF}->{"skeleton"}->{"service_description"}
            and $self->{CONF}->{"skeleton"}->{"service_description"} )
        {
            my $description = "perfSONAR_PS SNMP MA";
            if ( $self->{CONF}->{site_name} ) {
                $description .= " at " . $self->{CONF}->{site_name};
            }
            if ( $self->{CONF}->{site_location} ) {
                $description .= " in " . $self->{CONF}->{site_location};
            }
            $self->{CONF}->{"skeleton"}->{"service_description"} = $description;
            $self->{LOGGER}->warn( "Setting 'service_description' to '$description'." );
        }

        unless ( exists $self->{CONF}->{"skeleton"}->{"service_name"}
            and $self->{CONF}->{"skeleton"}->{"service_name"} )
        {
            $self->{CONF}->{"skeleton"}->{"service_name"} = "SNMP MA";
            $self->{LOGGER}->warn( "Setting 'service_name' to 'SNMP MA'." );
        }

        unless ( exists $self->{CONF}->{"skeleton"}->{"service_type"}
            and $self->{CONF}->{"skeleton"}->{"service_type"} )
        {
            $self->{CONF}->{"skeleton"}->{"service_type"} = "MA";
            $self->{LOGGER}->warn( "Setting 'service_type' to 'MA'." );
        }
    }

    unless ( exists $self->{CONF}->{"skeleton"}->{"collection_interval"} ) {
        $self->{LOGGER}->debug( "Configuration value 'collection_interval' not present.  Searching for other values..." );

        unless ( exists $self->{CONF}->{"skeleton"}->{"collection_interval"} ) {
            $self->{CONF}->{"skeleton"}->{"collection_interval"} = 30;
        }
    }
    $self->{LOGGER}->debug( "Setting 'collection_interval' to \"" . $self->{CONF}->{"skeleton"}->{"collection_interval"} . "\" seconds." );

    unless ( exists $self->{CONF}->{"skeleton"}->{"maintenance_interval"} ) {
        $self->{LOGGER}->debug( "Configuration value 'maintenance_interval' not present.  Searching for other values..." );

        unless ( exists $self->{CONF}->{"skeleton"}->{"maintenance_interval"} ) {
            $self->{CONF}->{"skeleton"}->{"maintenance_interval"} = 30;
        }
    }
    $self->{LOGGER}->debug( "Setting 'maintenance_interval' to \"" . $self->{CONF}->{"skeleton"}->{"maintenance_interval"} . "\" seconds." );

    $self->{CONF}->{"skeleton"}->{"ls_chunk"} = 50;
    # JZ 12/14/2010
    #
    # Messages that this service will respond to.  
    my $error = q{};
    $handler->registerMessageHandler( "MeasurementRequest", $self );

    if ( $self->{CONF}->{"skeleton"}->{"metadata_db_type"} eq "file" ) {
        my $status = $self->refresh_store_file( { error => \$error } );
        unless ( $status == 0 ) {
            $self->{LOGGER}->fatal( "Couldn't initialize store file: $error" );
            return -1;
        }
    }
    else {
        $self->{LOGGER}->fatal( "Wrong value for 'metadata_db_type' set." );
        return -1;
    }

    return 0;
}

=head2 maintenance( $self )

Returns the 'maintenance_interval' variable, if this is set to a positive value
this indicates that the process is required.  

=cut

sub maintenance {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    return $self->{CONF}->{"skeleton"}->{"maintenance_interval"};
}

=head2 inline_maintenance( $self )

Stub function to call the process that will re-generate the store file.  If
there are other regular activities needed here (e.g. cleaning a database, moving
temporary files, etc.), add them.  

=cut

sub inline_maintenance {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    $self->refresh_store_file();
}

=head2 refresh_store_file( $self  {error } )

Regenerate the store file, covers the case of someone editing the file and not
needing to restart/hup the service.  

=cut

sub refresh_store_file {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { error => 0 } );

    my $store_file = $self->{CONF}->{"skeleton"}->{"metadata_db_file"};

    if ( -f $store_file ) {
        my ( $mtime ) = ( stat( $store_file ) )[9];
        if ( $self->{BAD_MTIME} and $mtime == $self->{BAD_MTIME} ) {
            my $msg = "Previously seen bad store file";
            $self->{LOGGER}->error( $msg );
            ${ $parameters->{error} } = $msg if ( $parameters->{error} );
            return -1;
        }

        $self->{LOGGER}->debug( "New: $mtime Old: " . $self->{STORE_FILE_MTIME} ) if ( $mtime and $self->{STORE_FILE_MTIME} );

        unless ( $self->{STORE_FILE_MTIME} and $self->{STORE_FILE_MTIME} == $mtime ) {
            my $error;
            my $new_metadatadb = perfSONAR_PS::DB::File->new( { file => $store_file } );
            $new_metadatadb->openDB( { error => \$error } );
            unless ( $new_metadatadb ) {
                my $msg = "Couldn't initialize store file: $error";
                $self->{LOGGER}->error( $msg );
                ${ $parameters->{error} } = $msg if ( $parameters->{error} );
                $self->{BAD_MTIME} = $mtime;
                return -1;
            }

            $self->{METADATADB}       = $new_metadatadb;
            $self->{STORE_FILE_MTIME} = $mtime;
            $self->{LOGGER}->debug( "Setting mtime to $mtime" );
        }
    }

    ${ $parameters->{error} } = "" if ( $parameters->{error} );
    return 0;
}

=head2 collection( $self )

Returns the 'collection_interval' variable, if this is set to a positive value
this indicates that the process is required.  

=cut

sub collection {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    return $self->{CONF}->{"skeleton"}->{"collection_interval"};
}

=head2 makeMeasurement $self ( {error } )

Function to perform a measurement.  This is run on the interval set by the
'collection_interval' variable.  Just about anything can be put in this
function.  For example the following flow chart is possible:

 - Read Store file to get list of measurements to perform
 - Perform measurements in a loop
 - Collect results into a data structure
 - Write data structure to a file (e.g. using 'Storable qw (freeze)') or shared
   memory.  

=cut

sub makeMeasurement {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { error => 0 } );

    $self->{LOGGER}->debug( "Starting measurement..." );

    # JZ 12/14/2010
    #
    # Add code!

    $self->{LOGGER}->debug( "Ending measurement..." );

    ${ $parameters->{error} } = "" if ( $parameters->{error} );
    return 0;
}

=head2 needLS($self {})

All the service to register with a lookup service.  This function simply returns
the value set in the configuration file (either yes or no, depending on user
preference) to let other parts of the framework know if LS registration is
required.

=cut

sub needLS {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    return $self->{CONF}->{"skeleton"}->{enable_registration};
}

=head2 registerLS($self $sleep_time)

Given the service information (specified in configuration) and the contents of
our metadata database (store.xml file), we can contact the specified LS and
register ourselves. We then sleep for some amount of time and do it again.

=cut

sub registerLS {
    my ( $self, $sleep_time ) = validateParamsPos( @_, 1, { type => SCALARREF }, );

    if ( $self->{CONF}->{"skeleton"}->{"metadata_db_type"} eq "file" ) {
        unless ( -f $self->{CONF}->{"skeleton"}->{"metadata_db_file"} ) {
            $self->{LOGGER}->fatal( "Store file not defined, disallowing registration." );
            return -1;
        }
    }
    else {
        $self->{LOGGER}->fatal( "Metadata database is not configured, disallowing registration." );
        return -1;
    }

    my ( $status, $res );
    my $ls = q{};

    my @ls_array = ();
    my @array = split( /\s+/, $self->{CONF}->{"skeleton"}->{"ls_instance"} );
    foreach my $l ( @array ) {
        $l =~ s/(\s|\n)*//g;
        push @ls_array, $l if $l;
    }
    @array = split( /\s+/, $self->{CONF}->{"ls_instance"} );
    foreach my $l ( @array ) {
        $l =~ s/(\s|\n)*//g;
        push @ls_array, $l if $l;
    }

    my @hints_array = ();
    @array = split( /\s+/, $self->{CONF}->{"root_hints_url"} );
    foreach my $h ( @array ) {
        $h =~ s/(\s|\n)*//g;
        push @hints_array, $h if $h;
    }

    unless ( exists $self->{LS_CLIENT} and $self->{LS_CLIENT} ) {
        my %ls_conf = (
            SERVICE_TYPE        => $self->{CONF}->{"skeleton"}->{"service_type"},
            SERVICE_NAME        => $self->{CONF}->{"skeleton"}->{"service_name"},
            SERVICE_DESCRIPTION => $self->{CONF}->{"skeleton"}->{"service_description"},
            SERVICE_ACCESSPOINT => $self->{CONF}->{"skeleton"}->{"service_accesspoint"},
        );
        $self->{LS_CLIENT} = new perfSONAR_PS::Client::LS::Remote( \@ls_array, \%ls_conf, \@hints_array );
    }

    $ls = $self->{LS_CLIENT};

    my $error         = q{};
    my @resultsString = ();
    if ( $self->{CONF}->{"skeleton"}->{"metadata_db_type"} eq "file" ) {
        @resultsString = $self->{METADATADB}->query( { query => "/nmwg:store/nmwg:metadata", error => \$error } );
    }
    else {
        $self->{LOGGER}->fatal( "Wrong value for 'metadata_db_type' set." );
        return -1;
    }

    if ( $#resultsString == -1 ) {
        $self->{LOGGER}->warn( "No data to register with LS" );
        return -1;
    }
    $ls->registerStatic( \@resultsString );
    return 0;
}

=head2 handleEvent($self, { output, messageId, messageType, messageParameters, eventType, subject, filterChain, data, rawRequest, doOutputMetadata })

All messages that enter will be routed based on the message type.  The
appropriate solution to this problem is to route on eventType and message type
and will be implemented in future releases.

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
        }
    );
    my @subjects = @{ $parameters->{subject} };
    my $md       = $subjects[0];
    ${ $parameters->{doOutputMetadata} } = 0;

    # JZ 12/14/2010
    #
    # Add in different types of message here, then define handlers that take 
    # the correct action.  
    
    if ( $parameters->{messageType} eq "MeasurementRequest" ) {
        $self->{LOGGER}->info( "MeasurementRequest initiated." );
        $self->measurementRequestRetrieveMetadataData(
            {
                metadatadb         => $self->{METADATADB},
                metadata           => $md,
                message_parameters => $parameters->{messageParameters},
                output             => $parameters->{output}
            }
        );
    }
    else {
        throw perfSONAR_PS::Error_compat( "error.ma.message_type", "Invalid Message Type" );
    }
    return;
}

=head2 measurementRequestRetrieveMetadataData($self, $metadatadb, $metadata, 
                                              $id, $message_parameters, $output)

The input will be partially or fully specified metadata.  If this matches
something in the database we will return a data matching the description.  After
we are able to tell if this service has data that matches a request, pass along
to the data handling function.

=cut

sub measurementRequestRetrieveMetadataData {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            metadatadb         => 1,
            metadata           => 1,
            message_parameters => 1,
            output             => 1
        }
    );

    my $mdId = q{};
    my $dId  = q{};

    my $queryString = q{};
    if ( $self->{CONF}->{"skeleton"}->{"metadata_db_type"} eq "file" ) {
        $queryString = "/nmwg:store/nmwg:metadata[" . getMetadataXQuery( { node => $parameters->{metadata} } ) . "]";
    }

    $self->{LOGGER}->debug( "Running query \"" . $queryString . "\"" );

    my $results = $parameters->{metadatadb}->querySet( { query => $queryString } );

    my %et                  = ();
    my $eventTypes          = find( $parameters->{metadata}, "./nmwg:eventType", 0 );
    my $supportedEventTypes = find( $parameters->{metadata}, ".//nmwg:parameter[\@name=\"supportedEventType\" or \@name=\"eventType\"]", 0 );
    foreach my $e ( $eventTypes->get_nodelist ) {
        my $value = extract( $e, 0 );
        if ( $value ) {
            $et{$value} = 1;
        }
    }
    foreach my $se ( $supportedEventTypes->get_nodelist ) {
        my $value = extract( $se, 0 );
        if ( $value ) {
            $et{$value} = 1;
        }
    }

    if ( $self->{CONF}->{"skeleton"}->{"metadata_db_type"} eq "file" ) {
        $queryString = "/nmwg:store/nmwg:data";
    }

    if ( $eventTypes->size() or $supportedEventTypes->size() ) {
        $queryString = $queryString . "[./nmwg:key/nmwg:parameters/nmwg:parameter[(\@name=\"supportedEventType\" or \@name=\"eventType\")";
        foreach my $e ( sort keys %et ) {
            $queryString = $queryString . " or (\@value=\"" . $e . "\" or text()=\"" . $e . "\")";
        }
        $queryString = $queryString . "]]";
    }

    $self->{LOGGER}->debug( "Running query \"" . $queryString . "\"" );

    my $dataResults = $parameters->{metadatadb}->querySet( { query => $queryString } );
    my %used = ();
    for my $x ( 0 .. $dataResults->size() ) {
        $used{$x} = 0;
    }

    my $base_id = $parameters->{metadata}->getAttribute( "id" );

    if ( $results->size() > 0 and $dataResults->size() > 0 ) {
        my %mds = ();
        foreach my $md ( $results->get_nodelist ) {
            next if not $md->getAttribute( "id" );

            my %l_et                  = ();
            my $l_eventTypes          = find( $md, "./nmwg:eventType", 0 );
            my $l_supportedEventTypes = find( $md, ".//nmwg:parameter[\@name=\"supportedEventType\" or \@name=\"eventType\"]", 0 );
            foreach my $e ( $l_eventTypes->get_nodelist ) {
                my $value = extract( $e, 0 );
                if ( $value ) {
                    $l_et{$value} = 1;
                }
            }
            foreach my $se ( $l_supportedEventTypes->get_nodelist ) {
                my $value = extract( $se, 0 );
                if ( $value ) {
                    $l_et{$value} = 1;
                }
            }

            my %hash = ();
            $hash{"md"}                       = $md;
            $hash{"et"}                       = \%l_et;
            $mds{ $md->getAttribute( "id" ) } = \%hash;
        }

        foreach my $d ( $dataResults->get_nodelist ) {
            my $idRef = $d->getAttribute( "metadataIdRef" );

            next if ( not defined $idRef or not defined $mds{$idRef} );

            my $md_temp = $mds{$idRef}->{"md"}->cloneNode( 1 );
            my $d_temp  = $d->cloneNode( 1 );
            $mdId = "metadata." . genuid();
            $md_temp->setAttribute( "metadataIdRef", $base_id );
            $md_temp->setAttribute( "id",            $mdId );
            $parameters->{output}->addExistingXMLElement( $md_temp );
            $self->handleData(
                {
                    id                 => $mdId,
                    data               => $d_temp,
                    metadata           => $mds{$idRef}->{"md"},
                    output             => $parameters->{output},
                    et                 => $mds{$idRef}->{"et"},
                    message_parameters => $parameters->{message_parameters}
                }
            );
        }
    }
    else {
        my $msg = "Database \"" . $self->{CONF}->{"skeleton"}->{"metadata_db_file"} . "\" returned 0 results for search";
        $self->{LOGGER}->error( $msg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage", $msg );
    }
    return;
}

=head2 handleData($self, $id, $data, $output, $et, $message_parameters)

Function to retrieve data from storage and prepare a message for return to the
user.  

=cut

sub handleData {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            id                 => 1,
            data               => 1,
            metadata           => 1,
            output             => 1,
            et                 => 1,
            message_parameters => 1
        }
    );

    # JZ 12/14/2010
    #
    # Just for an example, we will get the current time and start to load up
    # a hash value that will be used to output data.  
    
    my ( $sec, $frac ) = Time::HiRes::gettimeofday;
    my $timeType = q{};

    my %attrs = ();
    $attrs{"timeType"}  = "unix";
    $attrs{"timeValue"} = $sec;




    # JZ 12/14/2010
    #
    # Add code!  This is the function that handles the data, so interact with
    # a database or temporary storage (the items you used in 'makeMeasurement').
    # Use a loop to iterate, and create XML elements.  Recall that we have the
    # original metadata and data XML elements at our disposal
    # ($parameters->{metadata} and $parameters->{data}), use the XML::LibXML
    # library to access if required.  




    # JZ 12/14/2010
    #
    # The next sequence is important.  We begin to form the 'data' XML element.
    # We first use the 'output' parameter (this already contains the response
    # message), then give it the data and metadata Ids.  

    my $data_id     = "data." . genuid();
    my $prefix = "nmwg";
    my $uri    = "http://ggf.org/ns/nmwg/base/2.0/";

    startData( $parameters->{output}, $data_id, $parameters->{id}, undef );

    # JZ 12/14/2010
    #
    # This creates a single datum element.  We use the 'attrs' hash to assign
    # attributes.  For example in the above there are two attributes (timeType
    # and timeValue), this would create a datum element as such:
    #
    # <nmwg:datum timeType="unix" timeValue="1291144702"/>
    #
    $parameters->{output}->createElement(
        prefix     => $prefix,
        namespace  => $uri,
        tag        => "datum",
        attributes => \%attrs
    );

    endData( $parameters->{output} );
    return;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<Module::Load>, L<Digest::MD5>, L<English>, 
L<Params::Validate>, L<Date::Manip>, L<perfSONAR_PS::Services::MA::General>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Messages>,
L<perfSONAR_PS::Client::LS::Remote>, L<perfSONAR_PS::Error_compat>,
L<perfSONAR_PS::DB::File>, L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: SNMP.pm 4542 2010-11-11 23:04:11Z jdugan $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Aaron Brown, aaron@internet2.edu
Guilherme Fernandes, fernande@cis.udel.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut
