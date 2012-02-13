package perfSONAR_PS::Services::MA::perfSONARBUOY;

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::Services::Base';

use fields 'LS_CLIENT', 'NAMESPACES', 'METADATADB', 'LOGGER', 'RES', 'HASH_TO_ID', 'ID_TO_HASH', 'STORE_FILE_MTIME', 'BAD_MTIME', 'NETLOGGER';

=head1 NAME

perfSONAR_PS::Services::MA::perfSONARBUOY - perfSONAR-BUOY Measurement Archive

=head1 DESCRIPTION

A module that provides methods for the perfSONARBUOY MA.  perfSONARBUOY exposes
data formerly collected by the former AMI framework, including BWCTL and
OWAMP data.  This data is stored in a database backend (commonly MySQL).  The
webservices interface provided by this MA currently exposes iperf data collected
via BWCTL and OWAMP data.

This module, in conjunction with other parts of the perfSONAR-PS framework,
handles specific messages from interested actors in search of BWCTL/OWAMP data.
There are three major message types that this service can act upon:

 - MetadataKeyRequest     - Given some metadata about a specific measurement, 
                            request a re-playable 'key' to faster access
                            underlying data.
 - SetupDataRequest       - Given either metadata or a key regarding a specific
                            measurement, retrieve data values.
 - MetadataStorageRequest - Store data into the archive (unsupported)
 
The module is capable of dealing with several characteristic and tool based
eventTypes related to the underlying data as well as the aforementioned message
types.  

=cut

use Log::Log4perl qw(get_logger);
use Module::Load;
use Digest::MD5 qw(md5_hex);
use English qw( -no_match_vars );
use Params::Validate qw(:all);
use Sys::Hostname;
use Fcntl ':flock';
use Date::Manip;
use Math::Int64;
use Data::Validate::IP qw(is_ipv4);
use Net::IPv6Addr;
use File::Basename;

use perfSONAR_PS::Config::OWP;
use perfSONAR_PS::Config::OWP::Utils;
use perfSONAR_PS::Services::MA::General;
use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Client::LS::Remote;
use perfSONAR_PS::Error_compat qw/:try/;
use perfSONAR_PS::DB::File;
use perfSONAR_PS::DB::SQL;
use perfSONAR_PS::Utils::NetLogger;
use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::Topology::ID qw(idIsFQ);

my %ma_namespaces = (
    nmwg       => "http://ggf.org/ns/nmwg/base/2.0/",
    nmtm       => "http://ggf.org/ns/nmwg/time/2.0/",
    ifevt      => "http://ggf.org/ns/nmwg/event/status/base/2.0/",
    iperf      => "http://ggf.org/ns/nmwg/tools/iperf/2.0/",
    bwctl      => "http://ggf.org/ns/nmwg/tools/bwctl/2.0/",
    owd        => "http://ggf.org/ns/nmwg/characteristic/delay/one-way/20070914/",
    summary    => "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921/",
    achievable => "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0",
    owamp      => "http://ggf.org/ns/nmwg/tools/owamp/2.0/",
    select     => "http://ggf.org/ns/nmwg/ops/select/2.0/",
    average    => "http://ggf.org/ns/nmwg/ops/average/2.0/",
    perfsonar  => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/",
    psservice  => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/",
    nmwgt      => "http://ggf.org/ns/nmwg/topology/2.0/",
    nmwgtopo3  => "http://ggf.org/ns/nmwg/topology/base/3.0/",
    nmtb       => "http://ogf.org/schema/network/topology/base/20070828/",
    nmtl2      => "http://ogf.org/schema/network/topology/l2/20070828/",
    nmtl3      => "http://ogf.org/schema/network/topology/l3/20070828/",
    nmtl4      => "http://ogf.org/schema/network/topology/l4/20070828/",
    nmtopo     => "http://ogf.org/schema/network/topology/base/20070828/",
    nmtb       => "http://ogf.org/schema/network/topology/base/20070828/",
    nmwgr      => "http://ggf.org/ns/nmwg/result/2.0/"
);

=head2 init($self, $handler)

Called at startup by the daemon when this particular module is loaded into
the perfSONAR-PS deployment.  Checks the configuration file for the necessary
items and fills in others when needed. Initializes the backed metadata storage
(DBXML or a simple XML file) and builds the internal 'key hash' for the 
MetadataKey exchanges.  Finally the message handler loads the appropriate 
message types and eventTypes for this module.  Any other 'pre-startup' tasks
should be placed in this function.

Due to performance issues, the database access must be handled in two different
ways:

 - File Database - it is expensive to continuously open the file and store it as
                   a DOM for each access.  Therefore it is opened once by the
                   daemon and used by each connection.  A $self object can
                   be used for this.
 - XMLDB - File handles are opened and closed for each connection.

=cut

sub init {
    my ( $self, $handler ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::MA::perfSONARBUOY" );
    $self->{NETLOGGER} = get_logger( "NetLogger" );
    
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

    if ( exists $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} and $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} ) {
        unless ( -d $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} ) {           
            my($filename, $dirname) = fileparse( $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} );
            if ( $filename and lc( $filename ) eq "owmesh.conf" ) {
                $self->{LOGGER}->info( "The 'owmesh' value was set to '" . $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} . "', which is not a directory; converting to '" . $dirname . "'." );
                $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} = $dirname;
            }
            else {
                $self->{LOGGER}->fatal( "Value for 'owmesh' is '" . $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} . "', please set to the *directory* that contains the owmesh.conf file" );
                return -1;
            }
        }
        if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} and -d $self->{DIRECTORY} ) {
            unless ( $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} =~ "^/" ) {
                $self->{LOGGER}->warn( "Setting value for 'owmesn' to \"" . $self->{DIRECTORY} . "/" . $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} . "\"" );
                $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"} = $self->{DIRECTORY} . "/" . $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"};
            }
        }        
    }
    else {
        $self->{LOGGER}->fatal( "Value for 'owmesh' is not set." );
        return -1;
    }

    unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"maintenance_interval"} ) {
        $self->{LOGGER}->debug( "Configuration value 'maintenance_interval' not present.  Searching for other values..." );
        if ( exists $self->{CONF}->{"gls"}->{"summarization_interval"} ) {
            $self->{CONF}->{"perfsonarbuoy"}->{"maintenance_interval"} = $self->{CONF}->{"gls"}->{"summarization_interval"};
        }

        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"maintenance_interval"} ) {
            $self->{CONF}->{"perfsonarbuoy"}->{"maintenance_interval"} = 30;
        }
    }
    $self->{LOGGER}->debug( "Setting 'maintenance_interval' to \"" . $self->{CONF}->{"perfsonarbuoy"}->{"maintenance_interval"} . "\" minutes." );
    $self->{CONF}->{"perfsonarbuoy"}->{"maintenance_interval"} *= 60;

    unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"}
        and $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} )
    {
        $self->{LOGGER}->fatal( "Value for 'metadata_db_type' is not set." );
        return -1;
    }

    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} )
        {
            $self->{LOGGER}->fatal( "Value for 'metadata_db_file' is not set." );
            return -1;
        }
        else {
            if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} and -d $self->{DIRECTORY} ) {
                unless ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} =~ "^/" ) {
                    $self->{LOGGER}->warn( "Setting value for \"metadata_db_file\" to \"" . $self->{DIRECTORY} . "/" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} . "\"" );
                    $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} = $self->{DIRECTORY} . "/" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"};
                }
            }
            else {
                $self->{LOGGER}->fatal( "Cannot set value for \"metadata_db_type\"." );
                return -1;
            }
        }
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        eval { load perfSONAR_PS::DB::XMLDB; };
        if ( $EVAL_ERROR ) {
            $self->{LOGGER}->fatal( "Couldn't load perfSONAR_PS::DB::XMLDB: $EVAL_ERROR" );
            return -1;
        }

        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} )
        {
            $self->{LOGGER}->warn( "Value for 'metadata_db_file' is not set, setting to 'psbstore.dbxml'." );
            $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} = "psbstore.dbxml";
        }

        if ( exists $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} )
        {
            if ( exists $self->{DIRECTORY} and $self->{DIRECTORY} and -d $self->{DIRECTORY} ) {
                unless ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} =~ "^/" ) {
                    $self->{LOGGER}->warn( "Setting the value of \"\" to \"" . $self->{DIRECTORY} . "/" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} . "\"" );
                    $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} = $self->{DIRECTORY} . "/" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"};
                }
            }
            unless ( -d $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} ) {
                $self->{LOGGER}->warn( "Creating \"" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} . "\" for the \"metadata_db_name\"" );
                system( "mkdir " . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} );
            }
        }
        else {
            $self->{LOGGER}->fatal( "Value for 'metadata_db_name' is not set." );
            return -1;
        }
    }
    else {
        $self->{LOGGER}->fatal( "Wrong value for 'metadata_db_type' set." );
        return -1;
    }

    unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{enable_registration} ) {
        if ( exists $self->{CONF}->{enable_registration} and $self->{CONF}->{enable_registration} ) {
            $self->{CONF}->{"perfsonarbuoy"}->{enable_registration} = $self->{CONF}->{enable_registration};
        }
        else {
            $self->{CONF}->{enable_registration} = 0;
            $self->{CONF}->{"perfsonarbuoy"}->{enable_registration} = 0;
        }
        $self->{LOGGER}->warn( "Setting 'enable_registration' to \"" . $self->{CONF}->{"perfsonarbuoy"}->{enable_registration} . "\"." );
    }

    if ( $self->{CONF}->{"perfsonarbuoy"}->{"enable_registration"} ) {
        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"ls_instance"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"ls_instance"} )
        {
            if ( defined $self->{CONF}->{"ls_instance"}
                and $self->{CONF}->{"ls_instance"} )
            {
                $self->{LOGGER}->warn( "Setting \"ls_instance\" to \"" . $self->{CONF}->{"ls_instance"} . "\"" );
                $self->{CONF}->{"perfsonarbuoy"}->{"ls_instance"} = $self->{CONF}->{"ls_instance"};
            }
            else {
                $self->{LOGGER}->warn( "No LS instance specified for pSB service" );
            }
        }

        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"ls_registration_interval"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"ls_registration_interval"} )
        {
            if ( defined $self->{CONF}->{"ls_registration_interval"}
                and $self->{CONF}->{"ls_registration_interval"} )
            {
                $self->{LOGGER}->warn( "Setting \"ls_registration_interval\" to \"" . $self->{CONF}->{"ls_registration_interval"} . "\"" );
                $self->{CONF}->{"perfsonarbuoy"}->{"ls_registration_interval"} = $self->{CONF}->{"ls_registration_interval"};
            }
            else {
                $self->{LOGGER}->warn( "Setting registration interval to 4 hours" );
                $self->{CONF}->{"perfsonarbuoy"}->{"ls_registration_interval"} = 14400;
            }
        }

        if ( not $self->{CONF}->{"perfsonarbuoy"}->{"service_accesspoint"} ) {
            unless ( exists $self->{CONF}->{external_address} and $self->{CONF}->{external_address} ) {
                $self->{LOGGER}->fatal( "This service requires a service_accesspoint or external_address to be set, exiting." );
                return -1;
            }
            $self->{CONF}->{default_scheme} = "http" unless exists $self->{CONF}->{default_scheme} and $self->{CONF}->{default_scheme};
            
            $self->{LOGGER}->debug( "Setting service access point to " . $self->{CONF}->{default_scheme} . "://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT} );
            $self->{CONF}->{"perfsonarbuoy"}->{"service_accesspoint"} = $self->{CONF}->{default_scheme} . "://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT};
        }

        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"service_description"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"service_description"} )
        {
            my $description = "perfSONAR_PS perfSONAR-BUOY MA";
            if ( $self->{CONF}->{site_name} ) {
                $description .= " at " . $self->{CONF}->{site_name};
            }
            if ( $self->{CONF}->{site_location} ) {
                $description .= " in " . $self->{CONF}->{site_location};
            }
            $self->{CONF}->{"perfsonarbuoy"}->{"service_description"} = $description;
            $self->{LOGGER}->warn( "Setting 'service_description' to '$description'." );
        }

        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"service_name"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"service_name"} )
        {
            $self->{CONF}->{"perfsonarbuoy"}->{"service_name"} = "perfSONAR-BUOY MA";
            $self->{LOGGER}->warn( "Setting 'service_name' to 'perfSONAR-BUOY MA'." );
        }

        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"service_type"}
            and $self->{CONF}->{"perfsonarbuoy"}->{"service_type"} )
        {
            $self->{CONF}->{"perfsonarbuoy"}->{"service_type"} = "MA";
            $self->{LOGGER}->warn( "Setting 'service_type' to 'MA'." );
        }
        
        unless ( exists $self->{CONF}->{"perfsonarbuoy"}->{"service_node"} and $self->{CONF}->{"perfsonarbuoy"}->{"service_node"} ) {
            unless ( exists $self->{CONF}->{"node_id"} and $self->{CONF}->{"node_id"} ) {
                # XXX: For now we make this a hard fail since the rest of the GENI infrastructure will depend on it.
                $self->{LOGGER}->fatal( "This service requires the service_node or node_id to be set, exiting." );
                return -1;
            }
            $self->{CONF}->{"perfsonarbuoy"}->{"service_node"} = $self->{CONF}->{"node_id"};
        }
        
        unless ( idIsFQ( $self->{CONF}->{"perfsonarbuoy"}->{"service_node"}, "node" ) ) {
            $self->{LOGGER}->fatal( "service_node (or node_id) is not a fully-qualified UNIS node id, exiting." );
            return -1;
        }
    }

    $handler->registerMessageHandler( "SetupDataRequest",   $self );
    $handler->registerMessageHandler( "MetadataKeyRequest", $self );

    my $error = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        unless ( $self->createStorage( { error => \$error } ) == 0 ) {
            $self->{LOGGER}->fatal( "Couldn't load the store file - service cannot start" );
            return -1;
        }

        my $status = $self->refresh_store_file( { error => \$error } );
        unless ( $status == 0 ) {
            $self->{LOGGER}->fatal( "Couldn't initialize store file: $error" );
            return -1;
        }
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        my $error      = q{};
        my $metadatadb = $self->prepareDatabases;
        unless ( $metadatadb ) {
            $self->{LOGGER}->fatal( "There was an error opening \"" . $self->{CONF}->{"ls"}->{"metadata_db_name"} . "/" . $self->{CONF}->{"ls"}->{"metadata_db_file"} . "\": " . $error );
            return -1;
        }

        unless ( $self->createStorage( { metadatadb => $metadatadb, error => \$error } ) == 0 ) {
            $self->{LOGGER}->fatal( "Couldn't load the XMLDB - service cannot start" );
            return -1;
        }

        $metadatadb->closeDB( { error => \$error } );
        $self->{METADATADB} = q{};

        my ( $status, $res ) = $self->buildHashedKeys( { metadatadb => $metadatadb, metadatadb_type => "xmldb" } );
        unless ( $status == 0 ) {
            $self->{LOGGER}->fatal( "Error building key database: $res" );
            return -1;
        }

        $self->{HASH_TO_ID} = $res->{hash_to_id};
        $self->{ID_TO_HASH} = $res->{id_to_hash};
    }
    else {
        $self->{LOGGER}->fatal( "Wrong value for 'metadata_db_type' set." );
        return -1;
    }

    return 0;
}

=head2 needLS($self {})

This particular service (perfSONARBUOY MA) should register with a lookup
service.  This function simply returns the value set in the configuration file
(either yes or no, depending on user preference) to let other parts of the
framework know if LS registration is required.

=cut

sub needLS {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    return ( $self->{CONF}->{"perfsonarbuoy"}->{enable_registration} or $self->{CONF}->{enable_registration} );
}

=head2 maintenance( $self )

Stub function indicating that we have 'maintenance' functions in this particular service.

=cut

sub maintenance {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    return $self->{CONF}->{"perfsonarbuoy"}->{"maintenance_interval"};
}

=head2 inline_maintenance($self {})

Stub function to run a function at the daemon level - results of these functions will be available to subsequent children.

=cut

sub inline_maintenance {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    $self->refresh_store_file();
    return;
}

=head2 refresh_store_file($self {})

Check to see if a store file has been changed (via the MTIME).  

=cut

sub refresh_store_file {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { error => 0 } );
    return 0 unless $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file";

    my $store_file = $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"};
    if ( -f $store_file ) {
        my ( $mtime ) = ( stat( $store_file ) )[9];
        if ( $self->{BAD_MTIME} and $mtime == $self->{BAD_MTIME} ) {
            my $msg = "Previously seen bad store file";
            $self->{LOGGER}->error( $msg );
            ${ $parameters->{error} } = $msg if ( $parameters->{error} );
            return -1;
        }

        $self->{LOGGER}->debug( "New: $mtime Old: " . $self->{STORE_FILE_MTIME} ) if exists $self->{STORE_FILE_MTIME};

        unless ( $self->{STORE_FILE_MTIME} and $self->{STORE_FILE_MTIME} == $mtime ) {
            my $error = q{};
            my $new_metadatadb = perfSONAR_PS::DB::File->new( { file => $store_file } );
            $new_metadatadb->openDB( { error => \$error } );
            unless ( $new_metadatadb ) {
                my $msg = "Couldn't initialize store file: $error";
                $self->{LOGGER}->error( $msg );
                ${ $parameters->{error} } = $msg if ( $parameters->{error} );
                $self->{BAD_MTIME} = $mtime;
                return -1;
            }

            my ( $status, $res ) = $self->buildHashedKeys( { metadatadb => $new_metadatadb, metadatadb_type => "file" } );
            unless ( $status == 0 ) {
                my $msg = "Error building key database: $res";
                $self->{LOGGER}->fatal( $msg );
                ${ $parameters->{error} } = $msg if ( $parameters->{error} );
                $self->{BAD_MTIME} = $mtime;
                return -1;
            }

            $self->{METADATADB}       = $new_metadatadb;
            $self->{HASH_TO_ID}       = $res->{hash_to_id};
            $self->{ID_TO_HASH}       = $res->{id_to_hash};
            $self->{STORE_FILE_MTIME} = $mtime;
            $self->{LOGGER}->debug( "Setting mtime to $mtime" );
        }
    }

    ${ $parameters->{error} } = "" if ( $parameters->{error} );
    return 0;
}

=head2 buildHashedKeys($self {})

With the backend storage known we can search through looking for key
structures.  Once we have these in hand each will be examined and Digest::MD5
will be utilized to create MD5 hex based fingerprints of each key.  We then 
map these to the key ids in the metadata database for easy lookup.

=cut

sub buildHashedKeys {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { metadatadb => 1, metadatadb_type => 1 } );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.buildHashedKeys.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my %hash_to_id = ();
    my %id_to_hash = ();

    my $metadatadb      = $parameters->{metadatadb};
    my $metadatadb_type = $parameters->{metadatadb_type};

    if ( $metadatadb_type eq "file" ) {
        my $results = $metadatadb->querySet( { query => "/nmwg:store/nmwg:data" } );
        if ( $results->size() > 0 ) {
            foreach my $data ( $results->get_nodelist ) {
                if ( $data->getAttribute( "id" ) ) {
                    my $hash = md5_hex( $data->toString );
                    $hash_to_id{$hash} = $data->getAttribute( "id" );
                    $id_to_hash{ $data->getAttribute( "id" ) } = $hash;
                    $self->{LOGGER}->debug( "Key id $hash maps to data element " . $data->getAttribute( "id" ) );
                }
            }
        }
    }
    elsif ( $metadatadb_type eq "xmldb" ) {
        my $metadatadb = $self->prepareDatabases( { doc => $parameters->{output} } );
        my $error = q{};
        unless ( $metadatadb ) {
            my $msg = "Database could not be opened.";
            $self->{LOGGER}->fatal( $msg );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.buildHashedKeys.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return ( -1, $msg );
        }

        my $parser = XML::LibXML->new();
        my @results = $metadatadb->query( { query => "/nmwg:store[\@type=\"MAStore\"]/nmwg:data", txn => q{}, error => \$error } );

        my $len = $#results;
        if ( $len == -1 ) {
            my $msg = "Nothing returned for database search.";
            $self->{LOGGER}->error( $msg );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.buildHashedKeys.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return ( -1, $msg );
        }

        for my $x ( 0 .. $len ) {
            my $hash = md5_hex( $results[$x] );
            my $data = $parser->parse_string( $results[$x] );
            $id_to_hash{$hash} = $data->getDocumentElement->getAttribute( "id" );
            $hash_to_id{ $data->getDocumentElement->getAttribute( "id" ) } = $hash;
            $self->{LOGGER}->debug( "Key id $hash maps to data element " . $data->getDocumentElement->getAttribute( "id" ) );
        }
    }
    else {
        my $msg = "Wrong value for 'metadata_db_type' set.";
        $self->{LOGGER}->fatal( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.buildHashedKeys.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return ( -1, $msg );
    }

    my %retval = (
        id_to_hash => \%id_to_hash,
        hash_to_id => \%hash_to_id,
    );
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.buildHashedKeys.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return ( 0, \%retval );
}

=head2 createStorage($self { metadatadb, error } )

Given the information in the AMI databases, construct appropriate metadata
structures into either a file or the XMLDB.  This allows us to maintain the 
query mechanisms as defined by the other services.  Also performs the steps
necessary for building the 'key' cache that will speed up access to the data
by providing a fast handle that points directly to a key.

=cut

sub createStorage {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { metadatadb => 0, error => 1 } );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my %defaults = (
        DBHOST  => "localhost",
        CONFDIR => $self->{CONF}->{"perfsonarbuoy"}->{"owmesh"}
    );
    my $conf = new perfSONAR_PS::Config::OWP::Conf( %defaults );

    my $errorFlag = 0;
    my $dbTr      = q{};

    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        unless ( exists $parameters->{metadatadb} and $parameters->{metadatadb} ) {
            $parameters->{metadatadb} = $self->prepareDatabases;
            unless ( exists $parameters->{metadatadb} and $parameters->{metadatadb} ) {
                $self->{LOGGER}->fatal( "There was an error opening \"" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} . "/" . $self->{CONF}->{"ls"}->{"metadata_db_file"} . "\": " . $parameters->{"error"} );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
        }

        $dbTr = $parameters->{metadatadb}->getTransaction( { error => \$parameters->{"error"} } );
        unless ( $dbTr ) {
            $parameters->{metadatadb}->abortTransaction( { txn => $dbTr, error => \$parameters->{"error"} } ) if $dbTr;
            undef $dbTr;
            $self->{LOGGER}->fatal( "Database error: \"" . $parameters->{"error"} . "\", aborting." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        my $fh = new IO::File "> " . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"};
        if ( defined $fh ) {
            print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
            print $fh "<nmwg:store xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
            print $fh "            xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"\n";
            print $fh "            xmlns:owamp=\"http://ggf.org/ns/nmwg/tools/owamp/2.0/\"\n";
            print $fh "            xmlns:owd=\"http://ggf.org/ns/nmwg/characteristic/delay/one-way/20070914/\"\n";
            print $fh "            xmlns:summary=\"http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921/\"\n";
            print $fh "            xmlns:bwctl=\"http://ggf.org/ns/nmwg/tools/bwctl/2.0/\"\n";
            print $fh "            xmlns:iperf= \"http://ggf.org/ns/nmwg/tools/iperf/2.0/\">\n\n";
            $fh->close;
        }
        else {
            $self->{LOGGER}->fatal( "File cannot be written." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
    }
    else {
        $self->{LOGGER}->fatal( "Wrong value for 'metadata_db_type' set." );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return -1;
    }

    my @dateList = ();
    my $query    = q{};
    my $id       = 0;
    my %tspec    = ();
    my %node     = ();

    my $dbtypeBW = $self->confHierarchy( { conf => $conf, type => "BW", variable => "DBTYPE" } );
    my $dbnameBW = $self->confHierarchy( { conf => $conf, type => "BW", variable => "DBNAME" } );
    my $dbhostBW = $self->confHierarchy( { conf => $conf, type => "BW", variable => "DBHOST" } );

    if ( $dbtypeBW and $dbnameBW and $dbhostBW ) {

        my $dbsourceBW = $dbtypeBW . ":" . $dbnameBW . ":" . $dbhostBW;
        my $dbuserBW   = $self->confHierarchy( { conf => $conf, type => "BW", variable => "DBUSER" } );
        my $dbpassBW   = $self->confHierarchy( { conf => $conf, type => "BW", variable => "DBPASS" } );

        my @dateSchema = ( "year", "month" );
        my $datedb = new perfSONAR_PS::DB::SQL( { name => $dbsourceBW, schema => \@dateSchema, user => $dbuserBW, pass => $dbpassBW } );
        my $dbReturn = $datedb->openDB;
        if ( $dbReturn == -1 ) {
            $self->{LOGGER}->fatal( "Database error, aborting." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }

        my $result = $datedb->query( { query => "select * from DATES order by year, month;" } );
        $datedb->closeDB;

        my $len = $#{$result};
        unless ( $len == -1 ) {
            for my $a ( 0 .. $len ) {
                push @dateList, sprintf "%04d%02d", $result->[$a][0], $result->[$a][1];
            }

            $query = q{};
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "select duration,len_buffer,window_size,tos,parallel_streams,udp,udp_bandwidth from " . $date . "_TESTSPEC";
            }
            $query .= ";";

            my @tspecSchema = ( "tspec_id", "description", "duration", "len_buffer", "window_size", "tos", "parallel_streams", "udp", "udp_bandwidth" );
            my $tspecdb = new perfSONAR_PS::DB::SQL( { name => $dbsourceBW, schema => \@tspecSchema, user => $dbuserBW, pass => $dbpassBW } );
            $dbReturn = $tspecdb->openDB;
            if ( $dbReturn == -1 ) {
                $self->{LOGGER}->fatal( "Database error, aborting." );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
            $result = $tspecdb->query( { query => $query } );
            $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

            undef $len;
            $len = $#{$result};
            for my $a ( 0 .. $len ) {
                $query = q{};
                my %content = ();
                foreach my $date ( @dateList ) {
                    $query .= " union " if $query;
                    $query .= "select tspec_id from " . $date . "_TESTSPEC where ";
                    my $query2 = q{};
                    for my $b ( 0 .. 6 ) {
                        if ( defined $result->[$a][$b] ) {
                            if ( $tspecSchema[ $b + 2 ] eq "duration" ) {
                                $content{"timeDuration"}{"value"} = $result->[$a][$b];
                                $content{"timeDuration"}{"units"} = "seconds";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "len_buffer" ) {
                                $content{"bufferLength"}{"value"} = $result->[$a][$b];
                                $content{"bufferLength"}{"units"} = "bytes";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "window_size" ) {
                                $content{"windowSize"}{"value"} = $result->[$a][$b];
                                $content{"windowSize"}{"units"} = "bytes";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "report_interval" ) {
                                $content{"interval"}{"value"} = $result->[$a][$b];
                                $content{"interval"}{"units"} = "seconds";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "udp_bandwidth" ) {
                                $content{"bandwidthLimit"}{"value"} = $result->[$a][$b];
                                $content{"bandwidthLimit"}{"units"} = "bps";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "udp" ) {
                                $content{"protocol"}{"units"} = q{};
                                if ( $result->[$a][$b] ) {
                                    $content{"protocol"}{"value"} = "UDP";
                                }
                                else {
                                    $content{"protocol"}{"value"} = "TCP";
                                }
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }

                            # XXX
                            # JZ - 7/14/09 - To be added when this is supported
                            #
                            #elsif ( $tspecSchema[ $b + 2 ] eq "test_interval" ) {
                            #    $content{"interval"}{"value"} = $result->[$a][$b];
                            #    $content{"interval"}{"units"} = "seconds";
                            #}
                        }
                        else {
                            $query2 .= $tspecSchema[ $b + 2 ] . " is NULL";
                            $query2 .= " and " unless $b == 6;
                        }
                    }
                    $query .= $query2;
                }
                $query .= ";";

                my $parameter = $self->generateParameters( { content => \%content } );
                my $result2 = $tspecdb->query( { query => $query } );
                $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result2 ) == -1;

                my $len2 = $#{$result2};
                $tspec{$a}{"xml"} = $parameter;
                for my $b ( 0 .. $len2 ) {
                    $tspec{$a}{"id"}{ $result2->[$b][0] } = 1;
                }
            }
            $tspecdb->closeDB;

            # ------------------------------------------------------------------
            # XXX
            # JZ 7/19/09
            # Changes based on node resolution bug
            # ------------------------------------------------------------------

            $query = q{};
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "select longname, addr from " . $date . "_NODES";
            }
            $query .= ";";

            my @nodeSchema = ( "node_id", "node_name", "longname", "addr", "first", "last" );
            my $nodedb = new perfSONAR_PS::DB::SQL( { name => $dbsourceBW, schema => \@nodeSchema, user => $dbuserBW, pass => $dbpassBW } );
            $dbReturn = $nodedb->openDB;
            if ( $dbReturn == -1 ) {
                $self->{LOGGER}->fatal( "Database error, aborting." );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
            $result = $nodedb->query( { query => $query } );
            $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

            my %tnode = ();
            undef $len;
            $len = $#{$result};
            for my $a ( 0 .. $len ) {
                $query = q{};
                foreach my $date ( @dateList ) {
                    $query .= " union " if $query;
                    $query .= "select node_id from " . $date . "_NODES where ";
                    my $query2 = q{};
                    for my $b ( 0 .. 1 ) {
                        if ( defined $result->[$a][$b] ) {
                            $query2 .= $nodeSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                            $query2 .= " and " unless $b == 1;
                        }
                        else {
                            $query2 .= $nodeSchema[ $b + 2 ] . " is NULL";
                            $query2 .= " and " unless $b == 1;
                        }
                    }
                    $query .= $query2;
                }
                $query .= ";";

                my $result2 = $nodedb->query( { query => $query } );
                $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result2 ) == -1;

                my $len2 = $#{$result2};
                for my $b ( 0 .. $len2 ) {
                    for my $b2 ( 0 .. $len2 ) {
                        if ( $len2 == 0 ) {
                            $tnode{ $result2->[$b][0] }{ $result2->[$b2][0] } = 1;
                        }
                        else {
                            next if $result2->[$b][0] eq $result2->[$b2][0];
                            $tnode{ $result2->[$b][0] }{ $result2->[$b2][0] } = 1;
                        }
                    }
                }
            }
            $nodedb->closeDB;

            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # XXX
            # JZ 7/19/09
            # duplicate node code...
            # ------------------------------------------------------------------

            my %node = ();
            $query = q{};
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "select node_id, addr from " . $date . "_NODES";
            }
            $query .= ";";

            @nodeSchema = ( "node_id", "node_name", "longname", "addr", "first", "last" );
            $nodedb = new perfSONAR_PS::DB::SQL( { name => $dbsourceBW, schema => \@nodeSchema, user => $dbuserBW, pass => $dbpassBW } );
            $dbReturn = $nodedb->openDB;
            if ( $dbReturn == -1 ) {
                $self->{LOGGER}->fatal( "Database error, aborting." );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
            $result = $nodedb->query( { query => $query } );
            $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

            $len = $#{$result};
            for my $a ( 0 .. $len ) {
                my $addr     = $result->[$a][1];
                my @cols     = split( /:/, $addr );
                my @nodePart = ();
                if ( $#cols > 1 ) {
                    @nodePart = split( /\]/, $addr );
                    $nodePart[0] =~ s/^\[//;
                    $nodePart[1] =~ s/^:// if $nodePart[1];
                }
                else {
                    @nodePart = split( /:/, $addr );
                }
                $node{ $result->[$a][0] }{"name"} = $nodePart[0];
                $node{ $result->[$a][0] }{"port"} = $nodePart[1];
                $node{ $result->[$a][0] }{"type"} = $self->addressType( { address => $nodePart[0] } );
            }

            # ------------------------------------------------------------------

            $query = q{};
            my $case = 0;
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "(select distinct send_id, recv_id, tspec_id, case";
                foreach my $id ( keys %tspec ) {
                    foreach my $id2 ( keys %{ $tspec{$id}{"id"} } ) {
                        $query .= " when tspec_id=" . $id2 . " then '" . $id . "' ";
                        $case++;
                    }
                }
                $query .= "end as tid from " . $date . "_DATA)";
            }
            $query .= " order by send_id, recv_id, tspec_id;";

            if ( $case ) {
                my @dataSchema = ( "send_id", "recv_id", "tspec_id", "ti", "timestamp", "throughput", "jitter", "lost", "sent" );
                my $datadb = new perfSONAR_PS::DB::SQL( { name => $dbsourceBW, schema => \@dataSchema, user => $dbuserBW, pass => $dbpassBW } );
                $dbReturn = $datadb->openDB;
                if ( $dbReturn == -1 ) {
                    $self->{LOGGER}->fatal( "Database error, aborting." );
                    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                    $self->{NETLOGGER}->debug( $nlmsg );
                    return -1;
                }
                $result = $datadb->query( { query => $query } );
                $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

                my %resSet = ();
                $len = $#{$result};
                for my $a ( 0 .. $len ) {
		    next unless (defined $result->[$a][3]);

                    my $src_id = $result->[$a][0];
                    my $dst_id = $result->[$a][1];

                    my $src_str = "";
		    $src_str .= $node{$src_id}{"name"} if (defined $node{$src_id}{"name"});
		    $src_str .= ",";
		    $src_str .= $node{$src_id}{"port"} if (defined $node{$src_id}{"port"});
		    $src_str .= ",";
		    $src_str .= $node{$src_id}{"type"} if (defined $node{$src_id}{"type"});

                    my $dst_str = "";
		    $dst_str .= $node{$dst_id}{"name"} if (defined $node{$dst_id}{"name"});
		    $dst_str .= ",";
		    $dst_str .= $node{$dst_id}{"port"} if (defined $node{$dst_id}{"port"});
		    $dst_str .= ",";
		    $dst_str .= $node{$dst_id}{"type"} if (defined $node{$dst_id}{"type"});

                    push @{ $resSet{ $src_str }{ $dst_str }{ $result->[$a][3] } }, $result->[$a][2];
                }

                my %mark = ();
                foreach my $src ( keys %resSet ) {
                    foreach my $dst ( keys %{ $resSet{$src} } ) {
                        foreach my $fakeid ( keys %{ $resSet{$src}{$dst} } ) {

                            # ------------------------------------------------------
                            # XXX
                            # JZ 7/19/09
                            # Changes based on node resolution bug
                            # ------------------------------------------------------

                            next if $mark{$src}{$dst}{$fakeid};
                            $mark{$src}{$dst}{$fakeid} = 1;
                            foreach my $otherS ( keys %{ $tnode{$src} } ) {
                                foreach my $otherD ( keys %{ $tnode{$dst} } ) {
                                    $mark{$otherS}{$otherD}{$fakeid} = 1;
                                }
                            }

                            # ------------------------------------------------------

			    my ($src_name, $src_port, $src_type) = split(",", $src);
			    my ($dst_name, $dst_port, $dst_type) = split(",", $dst);

                            my $metadata = q{};
                            my $data     = q{};

                            $metadata .= "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata-" . $id . "\">\n";
                            $metadata .= "    <iperf:subject xmlns:iperf=\"http://ggf.org/ns/nmwg/tools/iperf/2.0/\" id=\"subject-" . $id . "\">\n";
                            $metadata .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
                            $metadata .= "        <nmwgt:src";
                            $metadata .= " value=\"" . $src_name . "\"" if $src_name;
                            $metadata .= " port=\"" . $src_port . "\"" if $src_port;
                            $metadata .= " type=\"" . $src_type . "\"" if $src_type;
                            $metadata .= " />\n";
                            $metadata .= "        <nmwgt:dst";
                            $metadata .= " value=\"" . $dst_name . "\"" if $dst_name;
                            $metadata .= " port=\"" . $dst_port . "\"" if $dst_port;
                            $metadata .= " type=\"" . $dst_type . "\"" if $dst_type;
                            $metadata .= " />\n";
                            $metadata .= "      </nmwgt:endPointPair>\n";
                            $metadata .= "    </iperf:subject>\n";
                            $metadata .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/iperf/2.0</nmwg:eventType>\n";
                            $metadata .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0</nmwg:eventType>\n";
                            $metadata .= "    <nmwg:parameters id=\"parameters-" . $id . "\">\n";
                            $metadata .= $tspec{$fakeid}{"xml"};
                            $metadata .= "  </nmwg:metadata>\n";

                            # ------------------------------------------------------
                            # XXX
                            # JZ 7/19/09
                            # Changes based on node resolution bug
                            # ------------------------------------------------------
                            my %tList = ();
                            foreach my $ts ( @{ $resSet{$src}{$dst}{$fakeid} } ) {
                                $tList{$ts} = 1;
                            }
                            foreach my $otherS ( keys %{ $tnode{$src} } ) {
                                foreach my $otherD ( keys %{ $tnode{$dst} } ) {
                                    foreach my $ts ( @{ $resSet{$otherS}{$otherD}{$fakeid} } ) {
                                        $tList{$ts} = 1;
                                    }
                                }
                            }
                            my @temp = keys %tList;

                            my @eT = ( "http://ggf.org/ns/nmwg/tools/iperf/2.0", "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0" );
                            $data .= $self->generateData( { id => $id, testspec => \@temp, eT => \@eT, db => $dbsourceBW, user => $dbuserBW, pass => $dbpassBW } );

                            if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
                                my $dHash  = md5_hex( $data );
                                my $mdHash = md5_hex( $metadata );
                                $parameters->{metadatadb}->insertIntoContainer( { content => $parameters->{metadatadb}->wrapStore( { content => $metadata, type => "MAStore" } ), name => $mdHash, txn => $dbTr, error => \$parameters->{"error"} } );
                                $errorFlag++ if $parameters->{"error"};
                                $parameters->{metadatadb}->insertIntoContainer( { content => $parameters->{metadatadb}->wrapStore( { content => $data, type => "MAStore" } ), name => $dHash, txn => $dbTr, error => \$parameters->{"error"} } );
                                $errorFlag++ if $parameters->{"error"};
                            }
                            elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
                                my $fh = new IO::File ">> " . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"};
                                if ( defined $fh ) {
                                    print $fh $metadata . "\n" . $data . "\n";
                                    $fh->close;
                                }
                                else {
                                    $self->{LOGGER}->fatal( "File handle cannot be written, aborting." );
                                    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                                    $self->{NETLOGGER}->debug( $nlmsg );
                                    return -1;
                                }
                            }
                            $id++;
                        }
                    }
                }
            }
            else {
                $self->{LOGGER}->info( "BWCTL Data not found in database - not adding to metadata storage." );
            }
        }
    }

    # bwctl
    # --------------------------------------------------------------------------
    # owamp

    my $dbtypeOWP = $self->confHierarchy( { conf => $conf, type => "OWP", variable => "DBTYPE" } );
    my $dbnameOWP = $self->confHierarchy( { conf => $conf, type => "OWP", variable => "DBNAME" } );
    my $dbhostOWP = $self->confHierarchy( { conf => $conf, type => "OWP", variable => "DBHOST" } );

    if ( $dbtypeOWP and $dbnameOWP and $dbhostOWP ) {
        my $dbsourceOWP = $dbtypeOWP . ":" . $dbnameOWP . ":" . $dbhostOWP;
        my $dbuserOWP   = $self->confHierarchy( { conf => $conf, type => "OWP", variable => "DBUSER" } );
        my $dbpassOWP   = $self->confHierarchy( { conf => $conf, type => "OWP", variable => "DBPASS" } );

        my @dateSchema = ( "year", "month", "day" );
        my $datedb = new perfSONAR_PS::DB::SQL( { name => $dbsourceOWP, schema => \@dateSchema, user => $dbuserOWP, pass => $dbpassOWP } );
        my $dbReturn = $datedb->openDB;
        if ( $dbReturn == -1 ) {
            $self->{LOGGER}->fatal( "Database error, aborting." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
        my $result = $datedb->query( { query => "select * from DATES order by year, month, day;" } );
        $datedb->closeDB;

        my $len = $#{$result};
        unless ( $len == -1 ) {
            @dateList = ();
            for my $a ( 0 .. $len ) {
                push @dateList, sprintf "%04d%02d%02d", $result->[$a][0], $result->[$a][1], $result->[$a][2];
            }

            $query = q{};
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "select num_session_packets,num_sample_packets,wait_interval,dscp,loss_timeout,packet_padding,bucket_width from " . $date . "_TESTSPEC";
            }
            $query .= ";";

            my @tspecSchema = ( "tspec_id", "description", "num_session_packets", "num_sample_packets", "wait_interval", "dscp", "loss_timeout", "packet_padding", "bucket_width" );
            my $tspecdb = new perfSONAR_PS::DB::SQL( { name => $dbsourceOWP, schema => \@tspecSchema, user => $dbuserOWP, pass => $dbpassOWP } );
            $dbReturn = $tspecdb->openDB;
            if ( $dbReturn == -1 ) {
                $self->{LOGGER}->fatal( "Database error, aborting." );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
            $result = $tspecdb->query( { query => $query } );
            $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

            %tspec = ();
            undef $len;
            $len = $#{$result};
            for my $a ( 0 .. $len ) {
                $query = q{};
                my %content = ();
                foreach my $date ( @dateList ) {
                    $query .= " union " if $query;
                    $query .= "select tspec_id from " . $date . "_TESTSPEC where ";
                    my $query2 = q{};
                    for my $b ( 0 .. 6 ) {
                        if ( defined $result->[$a][$b] ) {
                            if ( $tspecSchema[ $b + 2 ] eq "bucket_width" ) {
                                $content{"bucket_width"}{"value"} = $result->[$a][$b];
                                $content{"bucket_width"}{"units"} = "seconds";
                                $query2 .= "concat(" . $tspecSchema[ $b + 2 ] . ")=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "num_sample_packets" ) {
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "num_session_packets" ) {
                                $content{"count"}{"value"} = $result->[$a][$b];
                                $content{"count"}{"units"} = "packets";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "wait_interval" ) {
                                $content{"schedule"}{"value"} = "\n        <interval type=\"exp\">" . $result->[$a][$b] . "</interval>\n      ";
                                $content{"schedule"}{"units"} = "seconds";
                                $query2 .= "concat(" . $tspecSchema[ $b + 2 ] . ")=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "dscp" ) {
                                $content{"DSCP"}{"value"} = $result->[$a][$b];
                                $content{"DSCP"}{"units"} = "";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "loss_timeout" ) {
                                $content{"timeout"}{"value"} = $result->[$a][$b];
                                $content{"timeout"}{"units"} = "seconds";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                            elsif ( $tspecSchema[ $b + 2 ] eq "packet_padding" ) {
                                $content{"packet_padding"}{"value"} = $result->[$a][$b];
                                $content{"packet_padding"}{"units"} = "bytes";
                                $query2 .= $tspecSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                                $query2 .= " and " unless $b == 6;
                            }
                        }
                        else {
                            $query2 .= $tspecSchema[ $b + 2 ] . " is NULL";
                            $query2 .= " and " unless $b == 6;
                        }

                    }
                    $query .= $query2;
                }
                $query .= ";";

                my $parameter = $self->generateParameters( { content => \%content } );
                my $result2 = $tspecdb->query( { query => $query } );
                $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result2 ) == -1;

                my $len2 = $#{$result2};
                $tspec{$a}{"xml"} = $parameter;
                for my $b ( 0 .. $len2 ) {
                    $tspec{$a}{"id"}{ $result2->[$b][0] } = 1;
                }
            }
            $tspecdb->closeDB;

            # ------------------------------------------------------------------
            # XXX
            # JZ 7/19/09
            # Changes based on node resolution bug
            # ------------------------------------------------------------------

            $query = q{};
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "select longname, host, addr from " . $date . "_NODES";
            }
            $query .= ";";

            my @nodeSchema = ( "node_id", "node_name", "longname", "host", "addr", "first", "last" );
            my $nodedb = new perfSONAR_PS::DB::SQL( { name => $dbsourceOWP, schema => \@nodeSchema, user => $dbuserOWP, pass => $dbpassOWP } );
            $dbReturn = $nodedb->openDB;
            if ( $dbReturn == -1 ) {
                $self->{LOGGER}->fatal( "Database error, aborting." );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
            $result = $nodedb->query( { query => $query } );
            $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

            my %tnode = ();
            undef $len;
            $len = $#{$result};
            for my $a ( 0 .. $len ) {
                $query = q{};
                foreach my $date ( @dateList ) {
                    $query .= " union " if $query;
                    $query .= "select node_id from " . $date . "_NODES where ";
                    my $query2 = q{};
                    for my $b ( 0 .. 2 ) {
                        if ( defined $result->[$a][$b] ) {
                            $query2 .= $nodeSchema[ $b + 2 ] . "=\"" . $result->[$a][$b] . "\"";
                            $query2 .= " and " unless $b == 2;
                        }
                        else {
                            $query2 .= $nodeSchema[ $b + 2 ] . " is NULL";
                            $query2 .= " and " unless $b == 2;
                        }
                    }
                    $query .= $query2;
                }
                $query .= ";";

                my $result2 = $nodedb->query( { query => $query } );
                $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result2 ) == -1;

                my $len2 = $#{$result2};
                for my $b ( 0 .. $len2 ) {
                    for my $b2 ( 0 .. $len2 ) {
                        if ( $len2 == 0 ) {
                            $tnode{ $result2->[$b][0] }{ $result2->[$b2][0] } = 1;
                        }
                        else {
                            next if $result2->[$b][0] eq $result2->[$b2][0];
                            $tnode{ $result2->[$b][0] }{ $result2->[$b2][0] } = 1;
                        }
                    }
                }
            }
            $nodedb->closeDB;

            # ------------------------------------------------------------------

            # ------------------------------------------------------------------
            # XXX
            # JZ 7/19/09
            # duplicate node code...
            # ------------------------------------------------------------------
            %node  = ();
            $query = q{};
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "select node_id, addr from " . $date . "_NODES";
            }
            $query .= ";";

            @nodeSchema = ( "node_id", "node_name", "longname", "host", "addr", "first", "last" );
            $nodedb = new perfSONAR_PS::DB::SQL( { name => $dbsourceOWP, schema => \@nodeSchema, user => $dbuserOWP, pass => $dbpassOWP } );
            $dbReturn = $nodedb->openDB;
            if ( $dbReturn == -1 ) {
                $self->{LOGGER}->fatal( "Database error, aborting." );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
            $result = $nodedb->query( { query => $query } );
            $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

            $len = $#{$result};
            for my $a ( 0 .. $len ) {
                my $addr     = $result->[$a][1];
                my @cols     = split( /:/, $addr );
                my @nodePart = ();
                if ( $#cols > 1 ) {
                    @nodePart = split( /\]/, $addr );
                    $nodePart[0] =~ s/^\[//;
                    $nodePart[1] =~ s/^:// if $nodePart[1];
                }
                else {
                    @nodePart = split( /:/, $addr );
                }
                $node{ $result->[$a][0] }{"name"} = $nodePart[0];
                $node{ $result->[$a][0] }{"port"} = $nodePart[1];
                $node{ $result->[$a][0] }{"type"} = $self->addressType( { address => $nodePart[0] } );
            }

            # ------------------------------------------------------------------

            $query = q{};
            my $case = 0;
            foreach my $date ( @dateList ) {
                $query .= " union " if $query;
                $query .= "(select distinct send_id, recv_id, tspec_id, case";
                foreach my $id ( keys %tspec ) {
                    foreach my $id2 ( keys %{ $tspec{$id}{"id"} } ) {
                        $query .= " when tspec_id=" . $id2 . " then '" . $id . "' ";
                        $case++;
                    }
                }
                $query .= "end as tid from " . $date . "_DATA)";
            }
            $query .= " order by send_id, recv_id, tspec_id;";

            if ( $case ) {
                my @dataSchema = ( "send_id", "recv_id", "tspec_id", "si", "ei", "stimestamp", "etimestamp", "start_time", "end_time", "min", "max", "minttl", "maxttl", "sent", "lost", "dups", "maxerr", "finished" );
                my $datadb = new perfSONAR_PS::DB::SQL( { name => $dbsourceOWP, schema => \@dataSchema, user => $dbuserOWP, pass => $dbpassOWP } );
                $dbReturn = $datadb->openDB;
                if ( $dbReturn == -1 ) {
                    $self->{LOGGER}->fatal( "Database error, aborting." );
                    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                    $self->{NETLOGGER}->debug( $nlmsg );
                    return -1;
                }
                $result = $datadb->query( { query => $query } );
                $self->{LOGGER}->fatal( "Query error, aborting." ) and return -1 if scalar( $result ) == -1;

                my %resSet = ();
                $len = $#{$result};
                for my $a ( 0 .. $len ) {
		    next unless (defined $result->[$a][3]);

                    my $src_id = $result->[$a][0];
                    my $dst_id = $result->[$a][1];

                    my $src_str = "";
		    $src_str .= $node{$src_id}{"name"} if defined $node{$src_id}{"name"};
		    $src_str .= ",";
		    $src_str .= $node{$src_id}{"port"} if defined $node{$src_id}{"port"};
		    $src_str .= ",";
		    $src_str .= $node{$src_id}{"type"} if defined $node{$src_id}{"type"};

                    my $dst_str = "";
		    $dst_str .= $node{$dst_id}{"name"} if defined $node{$dst_id}{"name"};
		    $dst_str .= ",";
		    $dst_str .= $node{$dst_id}{"port"} if defined $node{$dst_id}{"port"};
		    $dst_str .= ",";
		    $dst_str .= $node{$dst_id}{"type"} if defined $node{$dst_id}{"type"};

                    push @{ $resSet{ $src_str }{ $dst_str }{ $result->[$a][3] } }, $result->[$a][2];
                }

                my %mark = ();
                foreach my $src ( keys %resSet ) {
                    foreach my $dst ( keys %{ $resSet{$src} } ) {
                        foreach my $fakeid ( keys %{ $resSet{$src}{$dst} } ) {

                            # ------------------------------------------------------
                            # XXX
                            # JZ 7/19/09
                            # Changes based on node resolution bug
                            # ------------------------------------------------------

                            next if $mark{$src}{$dst}{$fakeid};
                            $mark{$src}{$dst}{$fakeid} = 1;
                            foreach my $otherS ( keys %{ $tnode{$src} } ) {
                                foreach my $otherD ( keys %{ $tnode{$dst} } ) {
                                    $mark{$otherS}{$otherD}{$fakeid} = 1;
                                }
                            }

                            # ------------------------------------------------------

			    my ($src_name, $src_port, $src_type) = split(",", $src);
			    my ($dst_name, $dst_port, $dst_type) = split(",", $dst);

                            my $metadata = q{};
                            my $data     = q{};

                            $metadata .= "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata-" . $id . "\">\n";
                            $metadata .= "    <owamp:subject xmlns:owamp=\"http://ggf.org/ns/nmwg/tools/owamp/2.0/\" id=\"subject-" . $id . "\">\n";
                            $metadata .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
                            $metadata .= "        <nmwgt:src";
                            $metadata .= " value=\"" . $src_name . "\"" if $src_name;
                            $metadata .= " port=\"" . $src_port . "\"" if $src_port;
                            $metadata .= " type=\"" . $src_type . "\"" if $src_type;
                            $metadata .= " />\n";
                            $metadata .= "        <nmwgt:dst";
                            $metadata .= " value=\"" . $dst_name . "\"" if $dst_name;
                            $metadata .= " port=\"" . $dst_port . "\"" if $dst_port;
                            $metadata .= " type=\"" . $dst_type . "\"" if $dst_type;
                            $metadata .= " />\n";
                            $metadata .= "      </nmwgt:endPointPair>\n";
                            $metadata .= "    </owamp:subject>\n";
                            $metadata .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/owamp/2.0</nmwg:eventType>\n";
                            $metadata .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921</nmwg:eventType>\n";
                            $metadata .= "    <nmwg:parameters id=\"parameters-" . $id . "\">\n";
                            $metadata .= $tspec{$fakeid}{"xml"};
                            $metadata .= "  </nmwg:metadata>\n";

                            # ------------------------------------------------------
                            # XXX
                            # JZ 7/19/09
                            # Changes based on node resolution bug
                            # ------------------------------------------------------
                            my %tList = ();
                            foreach my $ts ( @{ $resSet{$src}{$dst}{$fakeid} } ) {
                                $tList{$ts} = 1;
                            }
                            foreach my $otherS ( keys %{ $tnode{$src} } ) {
                                foreach my $otherD ( keys %{ $tnode{$dst} } ) {
                                    foreach my $ts ( @{ $resSet{$otherS}{$otherD}{$fakeid} } ) {
                                        $tList{$ts} = 1;
                                    }
                                }
                            }
                            my @temp = keys %tList;

                            # ------------------------------------------------------

                            my @eT = ( "http://ggf.org/ns/nmwg/tools/owamp/2.0", "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921" );
                            $data .= $self->generateData( { id => $id, testspec => \@temp, eT => \@eT, db => $dbsourceOWP, user => $dbuserOWP, pass => $dbpassOWP } );

                            if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
                                my $dHash  = md5_hex( $data );
                                my $mdHash = md5_hex( $metadata );
                                $parameters->{metadatadb}->insertIntoContainer( { content => $parameters->{metadatadb}->wrapStore( { content => $metadata, type => "MAStore" } ), name => $mdHash, txn => $dbTr, error => \$parameters->{"error"} } );
                                $errorFlag++ if $parameters->{"error"};
                                $parameters->{metadatadb}->insertIntoContainer( { content => $parameters->{metadatadb}->wrapStore( { content => $data, type => "MAStore" } ), name => $dHash, txn => $dbTr, error => \$parameters->{"error"} } );
                                $errorFlag++ if $parameters->{"error"};
                            }
                            elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
                                my $fh = new IO::File ">> " . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"};
                                if ( defined $fh ) {
                                    print $fh $metadata . "\n" . $data . "\n";
                                    $fh->close;
                                }
                                else {
                                    $self->{LOGGER}->fatal( "File handle cannot be written, aborting." );
                                    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                                    $self->{NETLOGGER}->debug( $nlmsg );
                                    return -1;
                                }
                            }
                            $id++;
                        }
                    }
                }
            }
            else {
                $self->{LOGGER}->info( "OWAMP Data not found in database - not adding to metadata storage." );
            }
        }
    }

    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        if ( $errorFlag ) {
            $parameters->{metadatadb}->abortTransaction( { txn => $dbTr, error => \$parameters->{"error"} } ) if $dbTr;
            undef $dbTr;
            $self->{LOGGER}->fatal( "Database error: \"" . $parameters->{"error"} . "\", aborting." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
        else {
            my $status = $parameters->{metadatadb}->commitTransaction( { txn => $dbTr, error => \$parameters->{"error"} } );
            if ( $status == 0 ) {
                undef $dbTr;
            }
            else {
                $parameters->{metadatadb}->abortTransaction( { txn => $dbTr, error => \$parameters->{"error"} } ) if $dbTr;
                undef $dbTr;
                $self->{LOGGER}->fatal( "Database error: \"" . $parameters->{"error"} . "\", aborting." );
                $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
                $self->{NETLOGGER}->debug( $nlmsg );
                return -1;
            }
        }
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        my $fh = new IO::File ">> " . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"};
        if ( defined $fh ) {
            print $fh "</nmwg:store>\n";
            $fh->close;
        }
        else {
            $self->{LOGGER}->fatal( "File handle cannot be written, aborting." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
    }
    else {
        $self->{LOGGER}->fatal( "Wrong value for 'metadata_db_type' set." );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return -1;
    }
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.createStorage.end", {status => -1});
    $self->{NETLOGGER}->debug( $nlmsg );
    return 0;
}

=head2 generateParameters( $self, { content => 1 } )

Given some parameters, generate a block.

=cut

sub generateParameters {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { content => 1 } );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.generateParameters.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $p = q{};
    if ( keys %{ $parameters->{content} } > 0 ) {
        foreach my $c ( keys %{ $parameters->{content} } ) {
            if ( exists $parameters->{content}->{$c}->{"value"} and $parameters->{content}->{$c}->{"value"} ) {
                $p .= "      <nmwg:parameter name=\"" . $c . "\">" . $parameters->{content}->{$c}->{"value"} . "</nmwg:parameter>\n";

                # XXX
                # JZ - 7/14/09 - do we want to cat the units on to this?
                #
                #$p .= "      <nmwg:parameter name=\"" . $c . "\">" . $parameters->{content}->{$c}->{"value"} . " " . $parameters->{content}->{$c}->{"units"} . "</nmwg:parameter>\n";
            }
        }
        $p .= "    </nmwg:parameters>\n";
    }
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.generateParameters.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return $p;
}

=head2 generateData( $self, { id => 1, db => 1, user => 0, pass => 0 } )

Given some parameters for the key element, generate a data block.

=cut

sub generateData {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { id => 1, testspec => 1, eT => 1, db => 1, user => 0, pass => 0 } );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.generateData.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $data = q{};
    $data .= "  <nmwg:data xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"data-" . $parameters->{id} . "\" metadataIdRef=\"metadata-" . $parameters->{id} . "\">\n";
    $data .= "    <nmwg:key id=\"key-" . $parameters->{id} . "\">\n";
    $data .= "      <nmwg:parameters id=\"parameters-key-" . $parameters->{id} . "\">\n";
    foreach my $e ( @{ $parameters->{eT} } ) {
        $data .= "        <nmwg:parameter name=\"eventType\">" . $e . "</nmwg:parameter>\n";
    }
    foreach my $t ( @{ $parameters->{testspec} } ) {
        $data .= "        <nmwg:parameter name=\"testspec\">" . $t . "</nmwg:parameter>\n";
    }
    $data .= "        <nmwg:parameter name=\"db\">" . $parameters->{db} . "</nmwg:parameter>\n";
    $data .= "        <nmwg:parameter name=\"user\">" . $parameters->{user} . "</nmwg:parameter>\n" if exists $parameters->{user} and $parameters->{user};
    $data .= "        <nmwg:parameter name=\"pass\">" . $parameters->{pass} . "</nmwg:parameter>\n" if exists $parameters->{pass} and $parameters->{pass};
    $data .= "        <nmwg:parameter name=\"type\">mysql</nmwg:parameter>\n";
    $data .= "      </nmwg:parameters>\n";
    $data .= "    </nmwg:key>\n";
    $data .= "  </nmwg:data>\n";
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.generateData.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return $data;
}

=head2 addressType($self, {  address } )

Return the proper type of address (ipv4, ipv6, hostname)

=cut

sub addressType {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { address => 1 } );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.addressType.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    if ( is_ipv4( $parameters->{address} ) ) {
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.addressType.end", {ipType => 'ipv4'});
        $self->{NETLOGGER}->debug( $nlmsg );
        return "ipv4";
    }
    elsif ( &Net::IPv6Addr::is_ipv6( $parameters->{address} ) ) {
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.addressType.end", {ipType => 'ipv6'});
        $self->{NETLOGGER}->debug( $nlmsg );
        return "ipv6";
    }
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.addressType.end", {ipType => 'hostname'});
    $self->{NETLOGGER}->debug( $nlmsg );
    return "hostname";
}

=head2 confHierarchy($self, {  conf, type, variable } )

Return the propel member from the conf Hierarchy.

=cut

sub confHierarchy {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { conf => 1, type => 1, variable => 1 } );

    if ( exists $parameters->{conf}->{ $parameters->{variable} } and $parameters->{conf}->{ $parameters->{variable} } ) {
        return $parameters->{conf}->{ $parameters->{variable} };
    }
    elsif ( exists $parameters->{conf}->{ $parameters->{type} . $parameters->{variable} } and $parameters->{conf}->{ $parameters->{type} . $parameters->{variable} } ) {
        return $parameters->{conf}->{ $parameters->{type} . $parameters->{variable} };
    }
    elsif ( exists $parameters->{conf}->{ "CENTRAL" . $parameters->{variable} } and $parameters->{conf}->{ "CENTRAL" . $parameters->{variable} } ) {
        return $parameters->{conf}->{ "CENTRAL" . $parameters->{variable} };
    }
    elsif ( exists $parameters->{conf}->{ $parameters->{type} . "CENTRAL" . $parameters->{variable} } and $parameters->{conf}->{ $parameters->{type} . "CENTRAL" . $parameters->{variable} } ) {
        return $parameters->{conf}->{ $parameters->{type} . "CENTRAL" . $parameters->{variable} };
    }
    return;
}

=head2 prepareDatabases($self, { doc })

Opens the XMLDB and returns the handle if there was not an error.  The optional
argument can be used to pass an error message to the given message and 
return this in response to a request.

=cut

sub prepareDatabases {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { doc => 0 } );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.prepareDatabases.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $error = q{};
    my $metadatadb = new perfSONAR_PS::DB::XMLDB( { env => $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"}, cont => $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"}, ns => \%ma_namespaces, } );
    unless ( $metadatadb->openDB( { txn => q{}, error => \$error } ) == 0 ) {
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.prepareDatabases.end", {'status' => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.perfSONAR-BUOY.xmldb", "There was an error opening \"" . $self->{CONF}->{"ls"}->{"metadata_db_name"} . "/" . $self->{CONF}->{"ls"}->{"metadata_db_file"} . "\": " . $error );
        return;
    }
    $self->{LOGGER}->info( "Returning \"" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} . "/" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} . "\"" );
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.prepareDatabases.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return $metadatadb;
}

=head2 registerLS($self $sleep_time)

Given the service information (specified in configuration) and the contents of
our metadata database, we can contact the specified LS and register ourselves.
We then sleep for some amount of time and do it again.

=cut

sub registerLS {
    my ( $self, $sleep_time ) = validateParamsPos( @_, 1, { type => SCALARREF }, );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        unless ( -d $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_name"} ) {
            $self->{LOGGER}->fatal( "XMLDB is not defined, disallowing registration." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.end", {'status' => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        unless ( -f $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} ) {
            $self->{LOGGER}->fatal( "Store file not defined, disallowing registration." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.end", {'status' => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
    }
    else {
        $self->{LOGGER}->fatal( "Metadata database is not configured, disallowing registration." );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.end", {'status' => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return -1;
    }

    my ( $status, $res );
    my $ls = q{};

    my @ls_array = ();
    my @array = split( /\s+/, $self->{CONF}->{"perfsonarbuoy"}->{"ls_instance"} );
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

    if ( !defined $self->{LS_CLIENT} ) {
        my %ls_conf = (
            SERVICE_NODE        => $self->{CONF}->{"perfsonarbuoy"}->{"service_node"},
            SERVICE_TYPE        => $self->{CONF}->{"perfsonarbuoy"}->{"service_type"},
            SERVICE_NAME        => $self->{CONF}->{"perfsonarbuoy"}->{"service_name"},
            SERVICE_DESCRIPTION => $self->{CONF}->{"perfsonarbuoy"}->{"service_description"},
            SERVICE_ACCESSPOINT => $self->{CONF}->{"perfsonarbuoy"}->{"service_accesspoint"},
        );
        $self->{LS_CLIENT} = new perfSONAR_PS::Client::LS::Remote( \@ls_array, \%ls_conf, \@hints_array );
    }

    $ls = $self->{LS_CLIENT};

    my $error         = q{};
    my @resultsString = ();
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        @resultsString = $self->{METADATADB}->query( { query => "/nmwg:store/nmwg:metadata", error => \$error } );
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        my $metadatadb = $self->prepareDatabases;
        unless ( $metadatadb ) {
            $self->{LOGGER}->error( "Database could not be opened." );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.end", {'status' => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return -1;
        }
        @resultsString = $metadatadb->query( { query => "/nmwg:store[\@type=\"MAStore\"]/nmwg:metadata", txn => q{}, error => \$error } );
        $metadatadb->closeDB( { error => \$error } );
    }
    else {
        $self->{LOGGER}->error( "Wrong value for 'metadata_db_type' set." );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.end", {'status' => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return -1;
    }

    if ( $#resultsString == -1 ) {
        $self->{LOGGER}->error( "No data to register with LS" );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.end", {'status' => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return -1;
    }
    $ls->registerStatic( \@resultsString );
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.registerLS.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return 0;
}

=head2 handleMessageBegin($self, { ret_message, messageId, messageType, msgParams, request, retMessageType, retMessageNamespaces })

Stub function that is currently unused.  Will be used to interact with the 
daemons message handler.

=cut

sub handleMessageBegin {
    my ( $self, $ret_message, $messageId, $messageType, $msgParams, $request, $retMessageType, $retMessageNamespaces ) = @_;

    #   my ($self, @args) = @_;
    #      my $parameters = validateParams(@args,
    #            {
    #                ret_message => 1,
    #                messageId => 1,
    #                messageType => 1,
    #                msgParams => 1,
    #                request => 1,
    #                retMessageType => 1,
    #                retMessageNamespaces => 1
    #            });

    return 0;
}

=head2 handleMessageEnd($self, { ret_message, messageId })

Stub function that is currently unused.  Will be used to interact with the 
daemons message handler.

=cut

sub handleMessageEnd {
    my ( $self, $ret_message, $messageId ) = @_;

    #   my ($self, @args) = @_;
    #      my $parameters = validateParams(@args,
    #            {
    #                ret_message => 1,
    #                messageId => 1
    #            });

    return 0;
}

=head2 handleEvent($self, { output, messageId, messageType, messageParameters, eventType, subject, filterChain, data, rawRequest, doOutputMetadata })

Current workaround to the daemons message handler.  All messages that enter
will be routed based on the message type.  The appropriate solution to this
problem is to route on eventType and message type and will be implemented in
future releases.

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
            credentials       => 0,
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleEvent.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my @subjects = @{ $parameters->{subject} };
    my @filters  = @{ $parameters->{filterChain} };
    my $md       = $subjects[0];

    # this module outputs its own metadata so it needs to turn off the daemon's
    # metadata output routines.
    ${ $parameters->{doOutputMetadata} } = 0;

    my %timeSettings = ();

    # go through the main subject and select filters looking for parameters.
    my $new_timeSettings = getFilterParameters( { m => $md, namespaces => $parameters->{rawRequest}->getNamespaces(), default_resolution => $self->{CONF}->{"perfsonarbuoy"}->{"default_resolution"} } );

    $timeSettings{"CF"}                   = $new_timeSettings->{"CF"}                   if ( defined $new_timeSettings->{"CF"} );
    $timeSettings{"RESOLUTION"}           = $new_timeSettings->{"RESOLUTION"}           if ( defined $new_timeSettings->{"RESOLUTION"} and $timeSettings{"RESOLUTION_SPECIFIED"} );
    $timeSettings{"RESOLUTION_SPECIFIED"} = $new_timeSettings->{"RESOLUTION_SPECIFIED"} if ( $new_timeSettings->{"RESOLUTION_SPECIFIED"} );

    if ( exists $new_timeSettings->{"START"}->{"value"} ) {
        if ( exists $new_timeSettings->{"START"}->{"type"} and lc( $new_timeSettings->{"START"}->{"type"} ) eq "unix" ) {
            $new_timeSettings->{"START"}->{"internal"} = time2owptime( $new_timeSettings->{"START"}->{"value"} );
        }
        elsif ( exists $new_timeSettings->{"START"}->{"type"} and lc( $new_timeSettings->{"START"}->{"type"} ) eq "iso" ) {
            $new_timeSettings->{"START"}->{"internal"} = time2owptime( UnixDate( $new_timeSettings->{"START"}->{"value"}, "%s" ) );
        }
        else {
            $new_timeSettings->{"START"}->{"internal"} = time2owptime( $new_timeSettings->{"START"}->{"value"} );
        }
    }
    $timeSettings{"START"} = $new_timeSettings->{"START"};

    if ( exists $new_timeSettings->{"END"}->{"value"} ) {
        if ( exists $new_timeSettings->{"END"}->{"type"} and lc( $new_timeSettings->{"END"}->{"type"} ) eq "unix" ) {
            $new_timeSettings->{"END"}->{"internal"} = time2owptime( $new_timeSettings->{"END"}->{"value"} );
        }
        elsif ( exists $new_timeSettings->{"START"}->{"type"} and lc( $new_timeSettings->{"END"}->{"type"} ) eq "iso" ) {
            $new_timeSettings->{"END"}->{"internal"} = time2owptime( UnixDate( $new_timeSettings->{"END"}->{"value"}, "%s" ) );
        }
        else {
            $new_timeSettings->{"END"}->{"internal"} = time2owptime( $new_timeSettings->{"END"}->{"value"} );
        }
    }
    $timeSettings{"END"} = $new_timeSettings->{"END"};

    if ( $#filters > -1 ) {
        foreach my $filter_arr ( @filters ) {
            my @filters = @{$filter_arr};
            my $filter  = $filters[-1];

            $new_timeSettings = getFilterParameters( { m => $filter, namespaces => $parameters->{rawRequest}->getNamespaces(), default_resolution => $self->{CONF}->{"perfsonarbuoy"}->{"default_resolution"} } );

            $timeSettings{"CF"}                   = $new_timeSettings->{"CF"}                   if ( defined $new_timeSettings->{"CF"} );
            $timeSettings{"RESOLUTION"}           = $new_timeSettings->{"RESOLUTION"}           if ( defined $new_timeSettings->{"RESOLUTION"} and $new_timeSettings->{"RESOLUTION_SPECIFIED"} );
            $timeSettings{"RESOLUTION_SPECIFIED"} = $new_timeSettings->{"RESOLUTION_SPECIFIED"} if ( $new_timeSettings->{"RESOLUTION_SPECIFIED"} );

            if ( exists $new_timeSettings->{"START"}->{"value"} ) {
                if ( exists $new_timeSettings->{"START"}->{"type"} and lc( $new_timeSettings->{"START"}->{"type"} ) eq "unix" ) {
                    $new_timeSettings->{"START"}->{"internal"} = time2owptime( $new_timeSettings->{"START"}->{"value"} );
                }
                elsif ( exists $new_timeSettings->{"START"}->{"type"} and lc( $new_timeSettings->{"START"}->{"type"} ) eq "iso" ) {
                    $new_timeSettings->{"START"}->{"internal"} = time2owptime( UnixDate( $new_timeSettings->{"START"}->{"value"}, "%s" ) );
                }
                else {
                    $new_timeSettings->{"START"}->{"internal"} = time2owptime( $new_timeSettings->{"START"}->{"value"} );
                }
            }
            else {
                $new_timeSettings->{"START"}->{"internal"} = q{};
            }

            if ( exists $new_timeSettings->{"END"}->{"value"} ) {
                if ( exists $new_timeSettings->{"END"}->{"type"} and lc( $new_timeSettings->{"END"}->{"type"} ) eq "unix" ) {
                    $new_timeSettings->{"END"}->{"internal"} = time2owptime( $new_timeSettings->{"END"}->{"value"} );
                }
                elsif ( exists $new_timeSettings->{"END"}->{"type"} and lc( $new_timeSettings->{"END"}->{"type"} ) eq "iso" ) {
                    $new_timeSettings->{"END"}->{"internal"} = time2owptime( UnixDate( $new_timeSettings->{"END"}->{"value"}, "%s" ) );
                }
                else {
                    $new_timeSettings->{"END"}->{"internal"} = time2owptime( $new_timeSettings->{"END"}->{"value"} );
                }
            }
            else {
                $new_timeSettings->{"END"}->{"internal"} = q{};
            }

            # we conditionally replace the START/END settings since under the
            # theory of filter, if a later element specifies an earlier start
            # time, the later start time that appears higher in the filter chain
            # would have filtered out all times earlier than itself leaving
            # nothing to exist between the earlier start time and the later
            # start time. XXX I'm not sure how the resolution and the
            # consolidation function should work in this context.

            if ( exists $new_timeSettings->{"START"}->{"internal"} and ( ( not exists $timeSettings{"START"}->{"internal"} ) or $new_timeSettings->{"START"}->{"internal"} > $timeSettings{"START"}->{"internal"} ) ) {
                $timeSettings{"START"} = $new_timeSettings->{"START"};
            }

            if ( exists $new_timeSettings->{"END"}->{"internal"} and ( ( not exists $timeSettings{"END"}->{"internal"} ) or $new_timeSettings->{"END"}->{"internal"} < $timeSettings{"END"}->{"internal"} ) ) {
                $timeSettings{"END"} = $new_timeSettings->{"END"};
            }
        }
    }

    # If no resolution was listed in the filters, go with the default
    if ( not defined $timeSettings{"RESOLUTION"} ) {
        $timeSettings{"RESOLUTION"}           = $self->{CONF}->{"perfsonarbuoy"}->{"default_resolution"};
        $timeSettings{"RESOLUTION_SPECIFIED"} = 0;
    }

    my $cf         = q{};
    my $resolution = q{};
    my $start      = q{};
    my $end        = q{};

    $cf         = $timeSettings{"CF"}                  if ( $timeSettings{"CF"} );
    $resolution = $timeSettings{"RESOLUTION"}          if ( $timeSettings{"RESOLUTION"} );
    $start      = $timeSettings{"START"}->{"internal"} if ( $timeSettings{"START"}->{"internal"} );
    $end        = $timeSettings{"END"}->{"internal"}   if ( $timeSettings{"END"}->{"internal"} );

    $self->{LOGGER}->debug( "Request filter parameters: cf: $cf resolution: $resolution start: $start end: $end" );

    if ( $parameters->{messageType} eq "MetadataKeyRequest" ) {
        $self->{LOGGER}->info( "MetadataKeyRequest initiated." );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleEvent.end", { type => $parameters->{messageType} });
        $self->{NETLOGGER}->debug( $nlmsg );
        return $self->maMetadataKeyRequest(
            {
                output             => $parameters->{output},
                metadata           => $md,
                filters            => \@filters,
                time_settings      => \%timeSettings,
                request            => $parameters->{rawRequest},
                message_parameters => $parameters->{messageParameters}
            }
        );
    }
    elsif ( $parameters->{messageType} eq "SetupDataRequest" ) {
        $self->{LOGGER}->info( "SetupDataRequest initiated." );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleEvent.end", { type => $parameters->{messageType} });
        $self->{NETLOGGER}->debug( $nlmsg );
        return $self->maSetupDataRequest(
            {
                output             => $parameters->{output},
                metadata           => $md,
                filters            => \@filters,
                time_settings      => \%timeSettings,
                request            => $parameters->{rawRequest},
                message_parameters => $parameters->{messageParameters}
            }
        );
    }
    else {
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleEvent.end", { type => $parameters->{messageType}, status => -1 });
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.message_type", "Invalid Message Type" );
        return;
    }
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleEvent.end", { type => $parameters->{messageType}});
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 maMetadataKeyRequest($self, { output, metadata, time_settings, filters, request, message_parameters })

Main handler of MetadataKeyRequest messages.  Based on contents (i.e. was a
key sent in the request, or not) this will route to one of two functions:

 - metadataKeyRetrieveKey          - Handles all requests that enter with a 
                                     key present.  
 - metadataKeyRetrieveMetadataData - Handles all other requests
 
The goal of this message type is to return a pointer (i.e. a 'key') to the data
so that the more expensive operation of XPath searching the database is avoided
with a simple hashed key lookup.  The key currently can be replayed repeatedly
currently because it is not time sensitive.  

=cut

sub maMetadataKeyRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            output             => 1,
            metadata           => 1,
            time_settings      => 1,
            filters            => 1,
            request            => 1,
            message_parameters => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maMetadataKeyRequest.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $mdId  = q{};
    my $dId   = q{};
    my $error = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $self->{METADATADB} = $self->prepareDatabases( { doc => $parameters->{output} } );
        unless ( $self->{METADATADB} ) {
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maMetadataKeyRequest.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            throw perfSONAR_PS::Error_compat( "Database could not be opened." );
            return;
        }
    }
    unless ( ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" )
        or ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) )
    {
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maMetadataKeyRequest.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "Wrong value for 'metadata_db_type' set." );
        return;
    }

    my $nmwg_key = find( $parameters->{metadata}, "./nmwg:key", 1 );
    if ( $nmwg_key ) {
        $self->{LOGGER}->info( "Key found - running MetadataKeyRequest with existing key." );
        $self->metadataKeyRetrieveKey(
            {
                metadatadb         => $self->{METADATADB},
                key                => $nmwg_key,
                metadata           => $parameters->{metadata},
                filters            => $parameters->{filters},
                request_namespaces => $parameters->{request}->getNamespaces(),
                output             => $parameters->{output}
            }
        );
    }
    else {
        $self->{LOGGER}->info( "Key not found - running MetadataKeyRequest without a key." );
        $self->metadataKeyRetrieveMetadataData(
            {
                metadatadb         => $self->{METADATADB},
                time_settings      => $parameters->{time_settings},
                metadata           => $parameters->{metadata},
                filters            => $parameters->{filters},
                request_namespaces => $parameters->{request}->getNamespaces(),
                output             => $parameters->{output}
            }
        );

    }
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $self->{LOGGER}->debug( "Closing database." );
        $self->{METADATADB}->closeDB( { error => \$error } );
    }
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maMetadataKeyRequest.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 metadataKeyRetrieveKey($self, { metadatadb, key, metadata, filters, request_namespaces, output })

Because the request entered with a key, we must handle it in this particular
function.  We first attempt to extract the 'maKey' hash and check for validity.
An invalid or missing key will trigger an error instantly.  If the key is found
we see if any chaining needs to be done (and appropriately 'cook' the key), then
return the response.

=cut

sub metadataKeyRetrieveKey {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            metadatadb         => 1,
            key                => 1,
            metadata           => 1,
            filters            => 1,
            request_namespaces => 1,
            output             => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.metadataKeyRetrieveKey.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $mdId    = "metadata." . genuid();
    my $dId     = "data." . genuid();
    my $hashKey = extract( find( $parameters->{key}, ".//nmwg:parameter[\@name=\"maKey\"]", 1 ), 0 );
    unless ( $hashKey ) {
        my $msg = "Key error in metadata storage: cannot find 'maKey' in request message.";
        $self->{LOGGER}->error( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.metadataKeyRetrieveKey.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage_result", $msg );
        return;
    }

    my $hashId = $self->{HASH_TO_ID}->{$hashKey};
    unless ( $hashId ) {
        my $msg = "Key error in metadata storage: 'maKey' cannot be found.";
        $self->{LOGGER}->error( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.metadataKeyRetrieveKey.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage_result", $msg );
        return;
    }

    my $query = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        $query = "/nmwg:store/nmwg:data[\@id=\"" . $hashId . "\"]";
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $query = "/nmwg:store[\@type=\"MAStore\"]/nmwg:data[\@id=\"" . $hashId . "\"]";
    }

    $self->{LOGGER}->debug( "Running query \"" . $query . "\"" );

    if ( $parameters->{metadatadb}->count( { query => $query } ) != 1 ) {
        my $msg = "Key error in metadata storage: 'maKey' should exist, but matching data not found in database.";
        $self->{LOGGER}->error( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.metadataKeyRetrieveKey.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage_result", $msg );
        return;
    }

    my $mdIdRef;
    my @filters = @{ $parameters->{filters} };
    if ( $#filters > -1 ) {
        $mdIdRef = $filters[-1][0]->getAttribute( "id" );
    }
    else {
        $mdIdRef = $parameters->{metadata}->getAttribute( "id" );
    }

    createMetadata( $parameters->{output}, $mdId, $mdIdRef, $parameters->{key}->toString, undef );
    my $key2 = $parameters->{key}->cloneNode( 1 );
    my $params = find( $key2, ".//nmwg:parameters", 1 );
    $self->addSelectParameters( { parameter_block => $params, filters => $parameters->{filters} } );
    createData( $parameters->{output}, $dId, $mdId, $key2->toString, undef );
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.metadataKeyRetrieveKey.end", {status => -1});
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 metadataKeyRetrieveMetadataData($self, $metadatadb, $metadata, $chain,
                                       $id, $request_namespaces, $output)

Similar to 'metadataKeyRetrieveKey' we are looking to return a valid key.  The
input will be partially or fully specified metadata.  If this matches something
in the database we will return a key matching the description (in the form of
an MD5 fingerprint).  If this metadata was a part of a chain the chaining will
be resolved and used to augment (i.e. 'cook') the key.

=cut

sub metadataKeyRetrieveMetadataData {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            metadatadb         => 1,
            time_settings      => 1,
            metadata           => 1,
            filters            => 1,
            request_namespaces => 1,
            output             => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.metadataKeyRetrieveMetadataData.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $mdId        = q{};
    my $dId         = q{};
    my $queryString = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        $queryString = "/nmwg:store/nmwg:metadata[" . getMetadataXQuery( { node => $parameters->{metadata} } ) . "]";
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $queryString = "/nmwg:store[\@type=\"MAStore\"]/nmwg:metadata[" . getMetadataXQuery( { node => $parameters->{metadata} } ) . "]";
    }

    $self->{LOGGER}->debug( "Running query \"" . $queryString . "\"" );

    my $results             = $parameters->{metadatadb}->querySet( { query => $queryString } );
    my %et                  = ();
    my $eventTypes          = find( $parameters->{metadata}, "./nmwg:eventType", 0 );
    my $supportedEventTypes = find( $parameters->{metadata}, ".//nmwg:parameter[\@name=\"supportedEventType\" or \@name=\"eventType\"]", 0 );
    foreach my $e ( $eventTypes->get_nodelist ) {
        my $value = extract( $e, 0 );
        $et{$value} = 1 if $value;
    }
    foreach my $se ( $supportedEventTypes->get_nodelist ) {
        my $value = extract( $se, 0 );
        $et{$value} = 1 if $value;
    }

    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        $queryString = "/nmwg:store/nmwg:data";
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $queryString = "/nmwg:store[\@type=\"MAStore\"]/nmwg:data";
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
    if ( $results->size() > 0 and $dataResults->size() > 0 ) {
        my %mds = ();
        foreach my $md ( $results->get_nodelist ) {
            my $curr_md_id = $md->getAttribute( "id" );
            next if not $curr_md_id;
            $mds{$curr_md_id} = $md;
        }

        foreach my $d ( $dataResults->get_nodelist ) {
            my $curr_d_mdIdRef = $d->getAttribute( "metadataIdRef" );
            next if ( not $curr_d_mdIdRef or not exists $mds{$curr_d_mdIdRef} );

            my $curr_md = $mds{$curr_d_mdIdRef};

            my $dId  = "data." . genuid();
            my $mdId = "metadata." . genuid();

            my $md_temp = $curr_md->cloneNode( 1 );
            $md_temp->setAttribute( "metadataIdRef", $curr_d_mdIdRef );
            $md_temp->setAttribute( "id",            $mdId );

            $parameters->{output}->addExistingXMLElement( $md_temp );

            my $hashId  = $d->getAttribute( "id" );
            my $hashKey = $self->{ID_TO_HASH}->{$hashId};
            unless ( $hashKey ) {
                my $msg = "Key error in metadata storage: 'maKey' cannot be found.";
                $self->{LOGGER}->error( $msg );
                throw perfSONAR_PS::Error_compat( "error.ma.storage", $msg );
            }

            startData( $parameters->{output}, $dId, $mdId, undef );
            $parameters->{output}->startElement( { prefix => "nmwg", tag => "key", namespace => "http://ggf.org/ns/nmwg/base/2.0/" } );
            startParameters( $parameters->{output}, "params.0" );
            addParameter( $parameters->{output}, "maKey", $hashKey );

            my %attrs = ();
            $attrs{"type"} = $parameters->{time_settings}->{"START"}->{"type"} if $parameters->{time_settings}->{"START"}->{"type"};
            addParameter( $parameters->{output}, "startTime", $parameters->{time_settings}->{"START"}->{"value"}, \%attrs ) if ( defined $parameters->{time_settings}->{"START"}->{"value"} );

            %attrs = ();
            $attrs{"type"} = $parameters->{time_settings}->{"END"}->{"type"} if $parameters->{time_settings}->{"END"}->{"type"};
            addParameter( $parameters->{output}, "endTime", $parameters->{time_settings}->{"END"}->{"value"}, \%attrs ) if ( defined $parameters->{time_settings}->{"END"}->{"value"} );

            if ( defined $parameters->{time_settings}->{"RESOLUTION"} and $parameters->{time_settings}->{"RESOLUTION_SPECIFIED"} ) {
                addParameter( $parameters->{output}, "resolution", $parameters->{time_settings}->{"RESOLUTION"} );
            }
            addParameter( $parameters->{output}, "consolidationFunction", $parameters->{time_settings}->{"CF"} ) if ( defined $parameters->{time_settings}->{"CF"} );
            endParameters( $parameters->{output} );
            $parameters->{output}->endElement( "key" );
            endData( $parameters->{output} );
        }
    }
    else {
        my $msg = "Database \"" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} . "\" returned 0 results for search";
        $self->{LOGGER}->error( $msg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage", $msg );
    }
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.metadataKeyRetrieveMetadataData.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 maSetupDataRequest($self, $output, $md, $request, $message_parameters)

Main handler of SetupDataRequest messages.  Based on contents (i.e. was a
key sent in the request, or not) this will route to one of two functions:

 - setupDataRetrieveKey          - Handles all requests that enter with a 
                                   key present.  
 - setupDataRetrieveMetadataData - Handles all other requests
 
Chaining operations are handled internally, although chaining will eventually
be moved to the overall message handler as it is an important operation that
all services will need.

The goal of this message type is to return actual data, so after the metadata
section is resolved the appropriate data handler will be called to interact
with the database of choice (i.e. mysql, sqlite, others?).  

=cut

sub maSetupDataRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            output             => 1,
            metadata           => 1,
            filters            => 1,
            time_settings      => 1,
            request            => 1,
            message_parameters => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maSetupDataRequest.start");
    $self->{NETLOGGER}->debug( $nlmsg );

    my $mdId  = q{};
    my $dId   = q{};
    my $error = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $self->{METADATADB} = $self->prepareDatabases( { doc => $parameters->{output} } );
        unless ( $self->{METADATADB} ) {
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maSetupDataRequest.end", { status => -1 });
            $self->{NETLOGGER}->debug( $nlmsg );
            throw perfSONAR_PS::Error_compat( "Database could not be opened." );
            return;
        }
    }
    unless ( ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" )
        or ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) )
    {
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maSetupDataRequest.end", { status => -1 });
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "Wrong value for 'metadata_db_type' set." );
        return;
    }

    my $nmwg_key = find( $parameters->{metadata}, "./nmwg:key", 1 );
    if ( $nmwg_key ) {
        $self->{LOGGER}->info( "Key found - running SetupDataRequest with existing key." );
        $self->setupDataRetrieveKey(
            {
                metadatadb         => $self->{METADATADB},
                metadata           => $nmwg_key,
                filters            => $parameters->{filters},
                message_parameters => $parameters->{message_parameters},
                time_settings      => $parameters->{time_settings},
                request_namespaces => $parameters->{request}->getNamespaces(),
                output             => $parameters->{output}
            }
        );
    }
    else {
        $self->{LOGGER}->info( "Key not found - running SetupDataRequest without key." );
        $self->setupDataRetrieveMetadataData(
            {
                metadatadb         => $self->{METADATADB},
                metadata           => $parameters->{metadata},
                filters            => $parameters->{filters},
                time_settings      => $parameters->{time_settings},
                message_parameters => $parameters->{message_parameters},
                output             => $parameters->{output}
            }
        );
    }
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $self->{LOGGER}->debug( "Closing database." );
        $self->{METADATADB}->closeDB( { error => \$error } );
    }
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.maSetupDataRequest.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 setupDataRetrieveKey($self, $metadatadb, $metadata, $chain, $id,
                            $message_parameters, $request_namespaces, $output)

Because the request entered with a key, we must handle it in this particular
function.  We first attempt to extract the 'maKey' hash and check for validity.
An invalid or missing key will trigger an error instantly.  If the key is found
we see if any chaining needs to be done.  We finally call the handle data
function, passing along the useful pieces of information from the metadata
database to locate and interact with the backend storage (i.e. rrdtool, mysql, 
sqlite).  

=cut

sub setupDataRetrieveKey {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            metadatadb         => 1,
            metadata           => 1,
            filters            => 1,
            time_settings      => 1,
            message_parameters => 1,
            request_namespaces => 1,
            output             => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveKey.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $mdId    = q{};
    my $dId     = q{};
    my $results = q{};

    my $hashKey = extract( find( $parameters->{metadata}, ".//nmwg:parameter[\@name=\"maKey\"]", 1 ), 0 );
    unless ( $hashKey ) {
        my $msg = "Key error in metadata storage: cannot find 'maKey' in request message.";
        $self->{LOGGER}->error( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveKey.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage_result", $msg );
        return;
    }

    my $hashId = $self->{HASH_TO_ID}->{$hashKey};
    $self->{LOGGER}->debug( "Received hash key $hashKey which maps to $hashId" );
    unless ( $hashId ) {
        my $msg = "Key error in metadata storage: 'maKey' cannot be found.";
        $self->{LOGGER}->error( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveKey.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage_result", $msg );
        return;
    }

    my $query = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        $query = "/nmwg:store/nmwg:data[\@id=\"" . $hashId . "\"]";
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $query = "/nmwg:store[\@type=\"MAStore\"]/nmwg:data[\@id=\"" . $hashId . "\"]";
    }

    $self->{LOGGER}->debug( "Running query \"" . $query . "\"" );

    $results = $parameters->{metadatadb}->querySet( { query => $query } );
    if ( $results->size() != 1 ) {
        my $msg = "Key error in metadata storage: 'maKey' should exist, but matching data not found in database.";
        $self->{LOGGER}->error( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveKey.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage_result", $msg );
        return;
    }

    # XXX Jul 22, 2008
    #
    # BEGIN Hack
    #
    # I shouldn't have to do this, we need to store this in the key somewhere

    my $md_id_val = $results->get_node( 1 )->getAttribute( "metadataIdRef" );
    my $query2    = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        $query2 = "/nmwg:store/nmwg:metadata[\@id=\"" . $md_id_val . "\"]";
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $query2 = "/nmwg:store[\@type=\"MAStore\"]/nmwg:metadata[\@id=\"" . $md_id_val . "\"]";
    }

    $self->{LOGGER}->debug( "Running query \"" . $query . "\"" );

    my $results2 = $parameters->{metadatadb}->querySet( { query => $query2 } );
    if ( $results2->size() != 1 ) {
        my $msg = "Key error in metadata storage: 'metadataIdRef' " . $md_id_val . " should exist, but matching data not found in database.";
        $self->{LOGGER}->error( $msg );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveKey.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage_result", $msg );
        return;
    }

    my $src_b = find( $results2->get_node( 1 ), "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']", 1 );
    my $src_p = $src_b->getAttribute( "port" );
    my $src   = extract( $src_b, 0 );
    $src .= ":" . $src_p if $src_p;

    my $dst_b = find( $results2->get_node( 1 ), "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']", 1 );
    my $dst_p = $dst_b->getAttribute( "port" );
    my $dst   = extract( $dst_b, 0 );
    $dst .= ":" . $dst_p if $dst_p;

    # END Hack

    my $sentKey      = $parameters->{metadata}->cloneNode( 1 );
    my $results_temp = $results->get_node( 1 )->cloneNode( 1 );
    my $storedKey    = find( $results_temp, "./nmwg:key", 1 );

    my %l_et = ();
    my $l_supportedEventTypes = find( $storedKey, ".//nmwg:parameter[\@name=\"supportedEventType\" or \@name=\"eventType\"]", 0 );
    foreach my $se ( $l_supportedEventTypes->get_nodelist ) {
        my $value = extract( $se, 0 );
        $l_et{$value} = 1 if $value;
    }

    $mdId = "metadata." . genuid();
    $dId  = "data." . genuid();

    my $mdIdRef = $parameters->{metadata}->getAttribute( "id" );
    my @filters = @{ $parameters->{filters} };
    if ( $#filters > -1 ) {
        $self->addSelectParameters( { parameter_block => find( $sentKey, ".//nmwg:parameters", 1 ), filters => \@filters } );
        $mdIdRef = $filters[-1][0]->getAttribute( "id" );
    }

    createMetadata( $parameters->{output}, $mdId, $mdIdRef, $sentKey->toString, undef );
    $self->handleData(
        {
            id                 => $mdId,
            data               => $results_temp,
            output             => $parameters->{output},
            time_settings      => $parameters->{time_settings},
            et                 => \%l_et,
            src                => $src,
            dst                => $dst,
            message_parameters => $parameters->{message_parameters}
        }
    );
    
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveKey.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 setupDataRetrieveMetadataData($self, $metadatadb, $metadata, $id, 
                                     $message_parameters, $output)

Similar to 'setupDataRetrieveKey' we are looking to return data.  The input
will be partially or fully specified metadata.  If this matches something in
the database we will return a data matching the description.  If this metadata
was a part of a chain the chaining will be resolved passed along to the data
handling function.

=cut

sub setupDataRetrieveMetadataData {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            metadatadb         => 1,
            metadata           => 1,
            filters            => 1,
            time_settings      => 1,
            message_parameters => 1,
            output             => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveMetadataData.start");
    $self->{NETLOGGER}->debug( $nlmsg );

    my $mdId = q{};
    my $dId  = q{};

    my $queryString = q{};
    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        $queryString = "/nmwg:store/nmwg:metadata[" . getMetadataXQuery( { node => $parameters->{metadata} } ) . "]";
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $queryString = "/nmwg:store[\@type=\"MAStore\"]/nmwg:metadata[" . getMetadataXQuery( { node => $parameters->{metadata} } ) . "]";
    }

    $self->{LOGGER}->debug( "Running query \"" . $queryString . "\"" );

    my $results = $parameters->{metadatadb}->querySet( { query => $queryString } );

    my %et                  = ();
    my $eventTypes          = find( $parameters->{metadata}, "./nmwg:eventType", 0 );
    my $supportedEventTypes = find( $parameters->{metadata}, ".//nmwg:parameter[\@name=\"supportedEventType\" or \@name=\"eventType\"]", 0 );
    foreach my $e ( $eventTypes->get_nodelist ) {
        my $value = extract( $e, 0 );
        $et{$value} = 1 if $value;
    }
    foreach my $se ( $supportedEventTypes->get_nodelist ) {
        my $value = extract( $se, 0 );
        $et{$value} = 1 if $value;
    }

    if ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "file" ) {
        $queryString = "/nmwg:store/nmwg:data";
    }
    elsif ( $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_type"} eq "xmldb" ) {
        $queryString = "/nmwg:store[\@type=\"MAStore\"]/nmwg:data";
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
    my @filters = @{ $parameters->{filters} };
    if ( $#filters > -1 ) {
        my @filter_arr = @{ $filters[-1] };
        $base_id = $filter_arr[0]->getAttribute( "id" );
    }

    if ( $results->size() > 0 and $dataResults->size() > 0 ) {
        my %mds = ();
        foreach my $md ( $results->get_nodelist ) {
            next if not $md->getAttribute( "id" );

            # XXX Jul 22, 2008
            #
            # BEGIN Hack
            #
            # I shouldn't have to do this, we need to store this in the key somewhere

            my $src_b = find( $md, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='src']", 1 );
            my $src_p = $src_b->getAttribute( "port" );
            my $src   = extract( $src_b, 0 );
            $src .= ":" . $src_p if $src_p;

            my $dst_b = find( $md, "./*[local-name()='subject']/*[local-name()='endPointPair']/*[local-name()='dst']", 1 );
            my $dst_p = $dst_b->getAttribute( "port" );
            my $dst   = extract( $dst_b, 0 );
            $dst .= ":" . $dst_p if $dst_p;

            # END Hack

            my %l_et                  = ();
            my $l_eventTypes          = find( $md, "./nmwg:eventType", 0 );
            my $l_supportedEventTypes = find( $md, ".//nmwg:parameter[\@name=\"supportedEventType\" or \@name=\"eventType\"]", 0 );
            foreach my $e ( $l_eventTypes->get_nodelist ) {
                my $value = extract( $e, 0 );
                $l_et{$value} = 1 if $value;
            }
            foreach my $se ( $l_supportedEventTypes->get_nodelist ) {
                my $value = extract( $se, 0 );
                $l_et{$value} = 1 if $value;
            }

            my %hash = ();
            $hash{"md"}                       = $md;
            $hash{"et"}                       = \%l_et;
            $hash{"src"}                      = $src;
            $hash{"dst"}                      = $dst;
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
                    output             => $parameters->{output},
                    time_settings      => $parameters->{time_settings},
                    et                 => $mds{$idRef}->{"et"},
                    src                => $mds{$idRef}->{"src"},
                    dst                => $mds{$idRef}->{"dst"},
                    message_parameters => $parameters->{message_parameters}
                }
            );
        }
    }
    else {
        my $msg = "Database \"" . $self->{CONF}->{"perfsonarbuoy"}->{"metadata_db_file"} . "\" returned 0 results for search";
        $self->{LOGGER}->error( $msg );
        throw perfSONAR_PS::Error_compat( "error.ma.storage", $msg );
    }
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.setupDataRetrieveMetadataData.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 handleData($self, $id, $data, $output, $et, $message_parameters)

Directs the data retrieval operations based on a value found in the metadata
databases representation of the key (i.e. storage 'type').  Current offerings
only interact with rrd files and sql databases.

=cut

sub handleData {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            id                 => 1,
            data               => 1,
            output             => 1,
            et                 => 1,
            time_settings      => 1,
            message_parameters => 1,
            src                => 1,
            dst                => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleData.start");
    $self->{NETLOGGER}->debug( $nlmsg );
    
    my $type = extract( find( $parameters->{data}, "./nmwg:key/nmwg:parameters/nmwg:parameter[\@name=\"type\"]", 1 ), 0 );
    if ( lc( $type ) eq "mysql" or lc( $type ) eq "sql" ) {
        $self->retrieveSQL(

            {
                d                  => $parameters->{data},
                mid                => $parameters->{id},
                output             => $parameters->{output},
                time_settings      => $parameters->{time_settings},
                et                 => $parameters->{et},
                src                => $parameters->{src},
                dst                => $parameters->{dst},
                message_parameters => $parameters->{message_parameters}
            }
        );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleData.end");
    }
    else {
        my $msg = "Database \"" . $type . "\" is not yet supported";
        $self->{LOGGER}->error( $msg );
        getResultCodeData( $parameters->{output}, "data." . genuid(), $parameters->{id}, $msg, 1 );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleData.end", { status => -1 });
    }
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.handleData.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 retrieveSQL($self, $d, $mid, $output, $et, $message_parameters)

Given some 'startup' knowledge such as the name of the database and any
credentials to connect with it, we start a connection and query the database
for given values.  These values are prepared into XML response content and
return in the response message.

=cut

sub retrieveSQL {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            d                  => 1,
            mid                => 1,
            time_settings      => 1,
            output             => 1,
            et                 => 1,
            message_parameters => 1,
            src                => 1,
            dst                => 1
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.start");
    $self->{NETLOGGER}->debug( $nlmsg );

    my $timeType = "iso";
    if ( defined $parameters->{message_parameters}->{"timeType"} ) {
        if ( lc( $parameters->{message_parameters}->{"timeType"} ) eq "unix" ) {
            $timeType = "unix";
        }
        elsif ( lc( $parameters->{message_parameters}->{"timeType"} ) eq "iso" ) {
            $timeType = "iso";
        }
    }

    unless ( $parameters->{d} ) {
        $self->{LOGGER}->error( "No data element." );
        throw perfSONAR_PS::Error_compat( "error.ma.storage", "No data element found." );
    }

    my $testspecList = find( $parameters->{d}, "./nmwg:key//nmwg:parameter[\@name=\"testspec\"]", 0 );
    my @tspec = ();
    foreach my $t ( $testspecList->get_nodelist ) {
        my $value = extract( $t, 0 );
        push @tspec, $value if $value;
    }

    my $testspec = q{};
    foreach my $t ( @tspec ) {
        $testspec .= " or " if $testspec;
        $testspec .= " ( " unless $testspec;
        $testspec .= " tspec_id=\"" . $t . "\"";
    }
    $testspec .= " ) ";

    my $dbconnect = extract( find( $parameters->{d}, "./nmwg:key//nmwg:parameter[\@name=\"db\"]",    1 ), 1 );
    my $dbuser    = extract( find( $parameters->{d}, "./nmwg:key//nmwg:parameter[\@name=\"user\"]",  1 ), 1 );
    my $dbpass    = extract( find( $parameters->{d}, "./nmwg:key//nmwg:parameter[\@name=\"pass\"]",  1 ), 1 );
    my $dbtable   = extract( find( $parameters->{d}, "./nmwg:key//nmwg:parameter[\@name=\"table\"]", 1 ), 1 );

    unless ( $dbconnect ) {
        $self->{LOGGER}->error( "Data element " . $parameters->{d}->getAttribute( "id" ) . " is missing some SQL elements" );
        throw perfSONAR_PS::Error_compat( "error.ma.storage", "Unable to open associated database" );
    }

    my $dataType = "";
    foreach my $eventType ( keys %{ $parameters->{et} } ) {
        if ( $eventType eq "http://ggf.org/ns/nmwg/tools/owamp/2.0" ) {
            $dataType = "OWAMP";
            last;
        }
        elsif ($eventType eq "http://ggf.org/ns/nmwg/tools/bwctl/2.0"
            or $eventType eq "http://ggf.org/ns/nmwg/tools/iperf/2.0" )
        {
            $dataType = "BWCTL";
            last;
        }
    }

    my $id       = "data." . genuid();
    my @dbSchema = ();
    my $res;
    my $query    = q{};
    my $dbReturn = q{};

    # XXX JZ - 7/15/2009
    #
    # If we were to limt the data, here is the place to do so (see the owamp section for more notes)

    if ( $dataType eq "BWCTL" ) {
        my @dateSchema = ( "year", "month" );
        my $datedb = new perfSONAR_PS::DB::SQL( { name => $dbconnect, schema => \@dateSchema, user => $dbuser, pass => $dbpass } );
        $dbReturn = $datedb->openDB;
        if ( $dbReturn == -1 ) {
            my $msg = "Database error, could not complete request.";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }

        my $result = $datedb->query( { query => "select * from DATES;" } );
        $datedb->closeDB;
        my $len = $#{$result};
        unless ( $len > -1 ) {
            my $msg = "No data in database";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }
        my @dateList = ();
        for my $a ( 0 .. $len ) {
            push @dateList, sprintf "%04d%02d", $result->[$a][0], $result->[$a][1];
        }

        my @nodeSchema = ( "node_id", "node_name", "longname", "addr", "first", "last" );
        my $nodedb = new perfSONAR_PS::DB::SQL( { name => $dbconnect, schema => \@nodeSchema, user => $dbuser, pass => $dbpass } );

        my $query1 = q{};
        my $query2 = q{};
        foreach my $date ( @dateList ) {
            $query1 .= " union " if $query1;
            $query1 .= "select distinct node_id from " . $date . "_NODES where addr like \"" . $parameters->{src} . "%\"";
            $query2 .= " union " if $query2;
            $query2 .= "select distinct node_id from " . $date . "_NODES where addr like \"" . $parameters->{dst} . "%\"";
        }
        $query1 .= ";";
        $query2 .= ";";

        $dbReturn = $nodedb->openDB;
        if ( $dbReturn == -1 ) {
            my $msg = "Database error, could not complete request.";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }

        my $result1 = $nodedb->query( { query => $query1 } );
        my $result2 = $nodedb->query( { query => $query2 } );
        $nodedb->closeDB;

        if ( $#{$result1} < 0 and $#{$result2} < 0 ) {
            my $msg = "Id error, found \"" . join( " - ", @{$result1} ) . "\" for SRC and \"" . join( " - ", @{$result2} ) . "\" for DST addresses.";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }

        my $sendSQL = q{};
        if ( $#{$result1} >= 0 ) {
            foreach my $s ( @{$result1} ) {
                $sendSQL .= " or " if $sendSQL;
                $sendSQL .= " ( " unless $sendSQL;
                $sendSQL .= " send_id=\"" . $s->[0] . "\"";
            }
            $sendSQL .= " ) ";
        }
                
        my $recvSQL = q{};
        if ( $#{$result2} >= 0 ) {
            foreach my $r ( @{$result2} ) {
                $recvSQL .= " or " if $recvSQL;
                $recvSQL .= " ( " unless $recvSQL;
                $recvSQL .= " recv_id=\"" . $r->[0] . "\"";
            }
            $recvSQL .= " ) ";
        }


        # XXX JZ - 7/15/2009
        #
        # If we were to limt the data, here is the place to do so.  We can set
        #   a 'lower bound' to be some amount of time < now().

#        my $lowerBound = q{};
#        my $upperBound = q{};
#        if ( $parameters->{time_settings}->{"START"}->{"internal"} ) {
#            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = owpgmtime( $parameters->{time_settings}->{"START"}->{"internal"} );
#            $lowerBound = sprintf "%4d%02d", ( $year + 1900 ), ( $mon + 1 );            
#        }
#        if ( $parameters->{time_settings}->{"END"}->{"internal"} ) {
#            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = owpgmtime( $parameters->{time_settings}->{"END"}->{"internal"} );
#            $upperBound = sprintf "%4d%02d", ( $year + 1900 ), ( $mon + 1 );          
#        }

        @dbSchema = ( "send_id", "recv_id", "tspec_id", "ti", "timestamp", "throughput", "jitter", "lost", "sent" );
        foreach my $date ( @dateList ) {

            if ( $parameters->{time_settings}->{"START"}->{"internal"} or $parameters->{time_settings}->{"END"}->{"internal"} ) {
#                next if $lowerBound and $date < $lowerBound;
#                next if $upperBound and $date > $upperBound;
                if ( $query ) {
                    $query = $query . " union select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec . " and";
                }
                else {
                    $query = "select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec . " and";
                }

                my $queryCount = 0;
                if ( $parameters->{time_settings}->{"START"}->{"internal"} ) {
                    $query = $query . " timestamp > " . $parameters->{time_settings}->{"START"}->{"internal"};
                    $queryCount++;
                }
                if ( $parameters->{time_settings}->{"END"}->{"internal"} ) {
                    if ( $queryCount ) {
                        $query = $query . " and timestamp < " . $parameters->{time_settings}->{"END"}->{"internal"};
                    }
                    else {
                        $query = $query . " timestamp < " . $parameters->{time_settings}->{"END"}->{"internal"};
                    }
                }
            }
            else {
                if ( $query ) {
                    $query = $query . " union select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec;
                }
                else {
                    $query = "select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec;
                }
            }
        }
        $query = $query . ";" if $query;
    }
    elsif ( $dataType eq "OWAMP" ) {

        my @dateSchema = ( "year", "month" . "day" );
        my $datedb = new perfSONAR_PS::DB::SQL( { name => $dbconnect, schema => \@dateSchema, user => $dbuser, pass => $dbpass } );
        $dbReturn = $datedb->openDB;
        if ( $dbReturn == -1 ) {
            my $msg = "Database error, could not complete request.";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }

        my $result = $datedb->query( { query => "select * from DATES;" } );
        $datedb->closeDB;
        my $len = $#{$result};
        unless ( $len > -1 ) {
            my $msg = "No data in database";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }
        my @dateList = ();
        for my $a ( 0 .. $len ) {
            push @dateList, sprintf "%04d%02d%02d", $result->[$a][0], $result->[$a][1], $result->[$a][2];
        }

        my @nodeSchema = ( "node_id", "node_name", "longname", "host", "addr", "first", "last" );
        my $nodedb = new perfSONAR_PS::DB::SQL( { name => $dbconnect, schema => \@nodeSchema, user => $dbuser, pass => $dbpass } );

        my $query1 = q{};
        my $query2 = q{};
        foreach my $date ( @dateList ) {
            $query1 .= " union " if $query1;
            $query1 .= "select distinct node_id from " . $date . "_NODES where addr like \"" . $parameters->{src} . "%\"";
            $query2 .= " union " if $query2;
            $query2 .= "select distinct node_id from " . $date . "_NODES where addr like \"" . $parameters->{dst} . "%\"";
        }
        $query1 .= ";";
        $query2 .= ";";

        $dbReturn = $nodedb->openDB;
        if ( $dbReturn == -1 ) {
            my $msg = "Database error, could not complete request.";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }

        my $result1 = $nodedb->query( { query => $query1 } );
        my $result2 = $nodedb->query( { query => $query2 } );
        $nodedb->closeDB;

        if ( $#{$result1} < 0 and $#{$result2} < 0 ) {
            my $msg = "Id error, found \"" . join( " - ", @{$result1} ) . "\" for SRC and \"" . join( " - ", @{$result2} ) . "\" for DST addresses.";
            $self->{LOGGER}->error( $msg );
            getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
            $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
            $self->{NETLOGGER}->debug( $nlmsg );
            return;
        }

        my $sendSQL = q{};
        if ( $#{$result1} >= 0 ) {
            foreach my $s ( @{$result1} ) {
                $sendSQL .= " or " if $sendSQL;
                $sendSQL .= " ( " unless $sendSQL;
                $sendSQL .= " send_id=\"" . $s->[0] . "\"";
            }
            $sendSQL .= " ) ";
        }
                
        my $recvSQL = q{};
        if ( $#{$result2} >= 0 ) {
            foreach my $r ( @{$result2} ) {
                $recvSQL .= " or " if $recvSQL;
                $recvSQL .= " ( " unless $recvSQL;
                $recvSQL .= " recv_id=\"" . $r->[0] . "\"";
            }
            $recvSQL .= " ) ";
        }

        # XXX JZ - 7/15/2009
        #
        # If we were to limt the data, here is the place to do so.  We can set
        #   a 'lower bound' to be some amount of time < now().

#        my $lowerBound = q{};
#        my $upperBound = q{};
#        if ( $parameters->{time_settings}->{"START"}->{"internal"} ) {
#            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = gmtime( time );
#            $lowerBound = sprintf "%4d%02d%02d", ( $year + 1900 ), ( $mon + 1 ), ( $mday );
#        }
#        if ( $parameters->{time_settings}->{"END"}->{"internal"} ) {
#            my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = gmtime( time );
#            $upperBound = sprintf "%4d%02d%02d", ( $year + 1900 ), ( $mon + 1 ), ( $mday );
#        }

        @dbSchema = ( "send_id", "recv_id", "tspec_id", "si", "ei", "stimestamp", "etimestamp", "start_time", "end_time", "min", "max", "minttl", "maxttl", "sent", "lost", "dups", "maxerr", "finished" );
        foreach my $date ( @dateList ) {
            if ( $parameters->{time_settings}->{"START"}->{"internal"} or $parameters->{time_settings}->{"END"}->{"internal"} ) {
#                next if $lowerBound and $date < $lowerBound;
#                next if $upperBound and $date > $upperBound;
                if ( $query ) {
                    $query = $query . " union select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec . " and";
                }
                else {
                    $query = "select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec . " and";
                }

                my $queryCount = 0;
                if ( $parameters->{time_settings}->{"START"}->{"internal"} ) {
                    $query = $query . " etimestamp > " . $parameters->{time_settings}->{"START"}->{"internal"};
                    $queryCount++;
                }
                if ( $parameters->{time_settings}->{"END"}->{"internal"} ) {
                    if ( $queryCount ) {
                        $query = $query . " and stimestamp < " . $parameters->{time_settings}->{"END"}->{"internal"};
                    }
                    else {
                        $query = $query . " stimestamp < " . $parameters->{time_settings}->{"END"}->{"internal"};
                    }
                }
            }
            else {
                if ( $query ) {
                    $query = $query . " union select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec;
                }
                else {
                    $query = "select * from " . $date . "_DATA where " . $sendSQL . " and " . $recvSQL . " and " . $testspec;
                }
            }
        }
        $query = $query . ";" if $query;
    }
    else {
        my $msg = "Improper eventType found.";
        $self->{LOGGER}->error( $msg );
        getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return;
    }

    $self->{LOGGER}->info( "Query \"" . $query . "\" formed." );

    unless ( $query ) {
        my $msg = "Query returned 0 results";
        $self->{LOGGER}->error( $msg );
        getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return;
    }    
            
    my $datadb = new perfSONAR_PS::DB::SQL( { name => $dbconnect, schema => \@dbSchema, user => $dbuser, pass => $dbpass } );

    $dbReturn = $datadb->openDB;
    if ( $dbReturn == -1 ) {
        my $msg = "Database error, could not complete request.";
        $self->{LOGGER}->error( $msg );
        getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return;
    }

    my $result = $datadb->query( { query => $query } );
    $datadb->closeDB;

    if ( $#{$result} == -1 ) {
        my $msg = "Query returned 0 results";
        $self->{LOGGER}->error( $msg );
        getResultCodeData( $parameters->{output}, $id, $parameters->{mid}, $msg, 1 );
        $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
        $self->{NETLOGGER}->debug( $nlmsg );
        return;
    }
    else {
        if ( $dataType eq "BWCTL" ) {
            my $prefix = "iperf";
            my $uri    = "http://ggf.org/ns/nmwg/tools/iperf/2.0/";

            startData( $parameters->{output}, $id, $parameters->{mid}, undef );
            my $len = $#{$result};
            for my $a ( 0 .. $len ) {
                my %attrs = ();

                if ( $timeType eq "unix" ) {
                    $attrs{"timeType"} = "unix";

                    #                        $attrs{ $dbSchema[4] . "Value" } = owptime2exacttime( $result->[$a][4] );
                    $attrs{"timeValue"} = owptime2exacttime( $result->[$a][4] );
                }
                else {
                    $attrs{"timeType"} = "iso";

                    #                        $attrs{ $dbSchema[4] . "Value" } = owpexactgmstring( $result->[$a][4] );
                    $attrs{"timeValue"} = owpexactgmstring( $result->[$a][4] );
                }

                $attrs{ $dbSchema[5] } = $result->[$a][5] if $result->[$a][5];
                $attrs{ $dbSchema[6] } = $result->[$a][6] if $result->[$a][6];
                $attrs{ $dbSchema[7] } = $result->[$a][7] if $result->[$a][7];
                $attrs{ $dbSchema[8] } = $result->[$a][8] if $result->[$a][8];

                $parameters->{output}->createElement(
                    prefix     => $prefix,
                    namespace  => $uri,
                    tag        => "datum",
                    attributes => \%attrs
                );

            }
            endData( $parameters->{output} );
        }
        elsif ( $dataType eq "OWAMP" ) {
            my $prefix = "summary";
            my $uri    = "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921/";

            startData( $parameters->{output}, $id, $parameters->{mid}, undef );
            my $len = $#{$result};
            for my $a ( 0 .. $len ) {
                my %attrs = ();
                if ( $timeType eq "unix" ) {
                    $attrs{"timeType"}  = "unix";
                    $attrs{"startTime"} = owptime2exacttime( $result->[$a][5] );
                    $attrs{"endTime"}   = owptime2exacttime( $result->[$a][6] );
                }
                else {
                    $attrs{"timeType"}  = "iso";
                    $attrs{"startTime"} = owpexactgmstring( $result->[$a][5] );
                    $attrs{"endTime"}   = owpexactgmstring( $result->[$a][6] );
                }

                #min
                $attrs{"min_delay"} = $result->[$a][9] if defined $result->[$a][9];

                # max
                $attrs{"max_delay"} = $result->[$a][10] if defined $result->[$a][10];

                # minTTL
                $attrs{"minTTL"} = $result->[$a][11] if defined $result->[$a][11];

                # maxTTL
                $attrs{"maxTTL"} = $result->[$a][12] if defined $result->[$a][12];

                #sent
                $attrs{"sent"} = $result->[$a][13] if defined $result->[$a][13];

                #lost
                $attrs{"loss"} = $result->[$a][14] if defined $result->[$a][14];

                #dups
                $attrs{"duplicates"} = $result->[$a][15] if defined $result->[$a][15];

                #err
                $attrs{"maxError"} = $result->[$a][16] if defined $result->[$a][16];

                $parameters->{output}->createElement(
                    prefix     => $prefix,
                    namespace  => $uri,
                    tag        => "datum",
                    attributes => \%attrs
                );
            }
            endData( $parameters->{output} );
        }
    }
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.retrieveSQL.end", {status => -1});
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

=head2 addSelectParameters($self, { parameter_block, filters })

Re-construct the parameters block.

=cut

sub addSelectParameters {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            parameter_block => 1,
            filters         => 1,
        }
    );
    my $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.addSelectParameters.start");
    $self->{NETLOGGER}->debug( $nlmsg );

    my $params       = $parameters->{parameter_block};
    my @filters      = @{ $parameters->{filters} };
    my %paramsByName = ();

    foreach my $p ( $params->childNodes ) {
        if ( $p->localname and $p->localname eq "parameter" and $p->getAttribute( "name" ) ) {
            $paramsByName{ $p->getAttribute( "name" ) } = $p;
        }
    }

    foreach my $filter_arr ( @filters ) {
        my @filters = @{$filter_arr};
        my $filter  = $filters[-1];

        $self->{LOGGER}->debug( "Filter: " . $filter->toString );

        my $select_params = find( $filter, "./select:parameters", 1 );
        if ( $select_params ) {
            foreach my $p ( $select_params->childNodes ) {
                if ( $p->localname and $p->localname eq "parameter" and $p->getAttribute( "name" ) ) {
                    my $newChild = $p->cloneNode( 1 );
                    if ( $paramsByName{ $p->getAttribute( "name" ) } ) {
                        $params->replaceChild( $newChild, $paramsByName{ $p->getAttribute( "name" ) } );
                    }
                    else {
                        $params->addChild( $newChild );
                    }
                    $paramsByName{ $p->getAttribute( "name" ) } = $newChild;
                }
            }
        }
    }
    $nlmsg = perfSONAR_PS::Utils::NetLogger::format("org.perfSONAR.Services.MA.pSB.addSelectParameters.end");
    $self->{NETLOGGER}->debug( $nlmsg );
    return;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<Module::Load>, L<Digest::MD5>, L<English>,
L<Params::Validate>, L<Sys::Hostname>, L<Fcntl>, L<Date::Manip>,
L<Math::Int64>, L<Data::Validate::IP>, L<Net::IPv6Addr>, L<File::Basename>,
L<perfSONAR_PS::Config::OWP>,L<perfSONAR_PS::Config::OWP::Utils>,
L<perfSONAR_PS::Services::MA::General>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Messages>, L<perfSONAR_PS::Client::LS::Remote>,
L<perfSONAR_PS::Error_compat>, L<perfSONAR_PS::DB::File>,
L<perfSONAR_PS::DB::SQL>, L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: perfSONARBUOY.pm 4325 2010-08-06 12:08:28Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Jeff Boote, boote@internet2.edu
Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
