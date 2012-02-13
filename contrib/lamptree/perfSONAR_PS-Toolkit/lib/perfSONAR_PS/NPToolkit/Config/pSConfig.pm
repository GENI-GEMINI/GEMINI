package perfSONAR_PS::NPToolkit::Config::pSConfig;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::pSConfig

=head1 DESCRIPTION

Module for configuring the set of services for the slice.

=cut

use Data::Dumper;

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'UNIS_INSTANCE', 'ROOT', 'NODES', 'CONFIG_NODES', 'LAST_PULL_FILE', 'CURRENT_STATE_FILE', 'MODIFIED', 'LAST_PULL_DATE', 'LAST_MODIFIED_DATE';

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger :nowarn);
use Storable qw(store retrieve freeze thaw dclone);
use Date::Parse;
use POSIX qw(strftime);
use Time::Local;

use perfSONAR_PS::Common qw(extract parseToDOM);
use perfSONAR_PS::Client::Topology;
use perfSONAR_PS::Topology::ID qw(idBaseLevel);

# Easier to load all handlers here (instead of ondemand) because of freeze/thaw.
use perfSONAR_PS::NPToolkit::Config::Handlers::Base;
use perfSONAR_PS::NPToolkit::Config::Handlers::NTP;
use perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting;

# XXX: Namespaces should be kept in a single module?
use constant UNIS_NS     => 'http://ogf.org/schema/network/topology/unis/20100528/';
use constant PSCONFIG_NS => 'http://ogf.org/schema/network/topology/psconfig/20100716/';

my %defaults = (
    last_pull_file     => "/var/lib/perfsonar/web_admin/last_pull",
    current_state_file => "/var/lib/perfsonar/web_admin/current_state",
);

my %known_services = (
    "unis" => {
        nodisplay   => 1,
        type        => "unis",
        short_name  => "UNIS",
        name        => "Unified Network Information Service (UNIS)",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "hls"  => {
        nodisplay   => 1,
        type        => "hls",
        short_name  => "hLS",
        name        => "Lookup Service",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "ls_registration_daemon" => {
        nodisplay   => 1,
        type        => "ls_registration_daemon",
        short_name  => "LS Registration Daemon",
        name        => "LS Registration Daemon",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        description => "Registers enabled daemons on this host with UNIS.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "snmp_ma" => {
        nodisplay   => 1,
        type        => "snmp_ma",
        short_name  => "SNMP MA",
        name        => "SNMP Measurement Archive",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        description => "Makes available SNMP statistics collected by an external program (e.g. Cacti).",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "ndt" => {
        nodisplay   => 1,
        type        => "ndt",
        short_name  => "NDT",
        name        => "Network Diagnostic Tester (NDT)",
        url         => "http://www.internet2.edu/performance/ndt/",
        description => "Allows clients at other sites to run NDT tests to this host.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "npad" => {
        nodisplay   => 1,
        type        => "npad",
        short_name  => "NPAD",
        name        => "Network Path and Application Diagnosis (NPAD)",
        url         => "http://www.psc.edu/networking/projects/pathdiag/",
        description => "Allows clients at other sites to run NPAD tests to this host.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },
    
    "regular_testing" => {
        nodisplay   => 1,
        type        => "regular_testing",
        short_name  => "Regular Testing",
        name        => "Regular Testing",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        description => "Defines regular tests for PingER and pSB. Transparent to the user.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting",
    },
    
    "pinger" => {
        type        => "pinger",
        short_name  => "PingER",
        name        => "PingER Measurement Archive and Regular Tester",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        description => "Enables hosts to perform scheduled ping tests." .
                       "These tests will periodically ping configured hosts giving " .
                       "administrators a view of the latency from their site over time.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "owamp" => {
        type        => "owamp",
        short_name  => "OWAMP",
        name        => "One-Way Ping Service (OWAMP)",
        url         => "http://www.internet2.edu/performance/owamp/index.html",
        description => "Allows clients at other sites to run One-Way Latency tests to this host",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "bwctl" => {
        type        => "bwctl",
        short_name  => "BWCTL",
        name        => "Bandwidth Test Controller (BWCTL)",
        url         => "http://www.internet2.edu/performance/bwctl/index.html",
        description => "Allows clients at other sites to run Throughput tests to this host",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "ssh" => {
        nodisplay   => 1,
        type        => "ssh",
        short_name  => "SSH",
        name        => "SSH Server",
        description => "Allows administrators to remotely connect to this host using SSH",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "perfsonarbuoy_ma" => {
        type        => "perfsonarbuoy_ma",
        short_name  => "perfSONAR-BUOY MA",
        name        => "perfSONAR-BUOY Measurement Archive",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        description => "Makes available the data collected by the perfSONAR-BUOY Latency and Throughput tests.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "perfsonarbuoy_owamp" => {
        type        => "perfsonarbuoy_owamp",
        short_name  => "perfSONAR-BUOY Latency Testing",
        name        => "perfSONAR-BUOY Regular Testing (One-Way Latency)",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        description => "Enables hosts to perform scheduled one-way latency tests. " .
                       "These tests will run periodically giving administrators a view " .
                       "of the latency from their site over time.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "perfsonarbuoy_bwctl" => {
        type        => "perfsonarbuoy_bwctl",
        short_name  => "perfSONAR-BUOY Throughput Testing",
        name        => "perfSONAR-BUOY Regular Testing (Throughput)",
        url         => "http://www.internet2.edu/performance/pS-PS/index.html",
        description => "Enables hosts to perform scheduled throughput tests. " .
                       "These tests will run periodically giving administrators a view " .
                       " of the throughput to and from their site over time.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },
    
    "ntp" => {
        type        => "ntp",
        short_name  => "NTP",
        name        => "NTP Server",
        url         => "http://www.ntp.org/",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::NTP",
    },

    "ganglia_gmond" => {
        type        => "ganglia_gmond",
        short_name  => "Host Monitoring Daemon (Ganglia)",
        name        => "Host Monitoring Daemon (Ganglia Monitoring Daemon)",
        url         => "http://ganglia.info/",
        description => "Monitors and announces a wide variety of host statistics. " .
                       "Statistics are kept in-memory and are not persistently stored (see Host Monitoring Collector).",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "ganglia_gmetad" => {
        type        => "ganglia_gmetad",
        short_name  => "Host Monitoring Collector (Ganglia)",
        name        => "Host Monitoring Collector (Ganglia Meta Daemon)",
        url         => "http://ganglia.info/",
        description => "Receives the announcements of all Host Monitoring Daemons and stores " .
                       "the statistics in local round-robin databases. " .
                       "Currently, only one collector is supported per slice.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "ganglia_ma" => {
        type        => "ganglia_ma",
        short_name  => "Ganglia MA",
        name        => "Ganglia Measurement Archive",
        url         => "http://ganglia.info/",
        description => "Exports the metrics collected by the Host Monitoring Collector using " .
                       "the SNMP MA interface and NMWG schema.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "periscope" => {
        type        => "periscope",
        short_name  => "Periscope",
        name        => "Periscope Visualization Tool",
        description => "GUI for visualizing topology and related I&M data.",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },

    "lamp_portal" => {
        type        => "lamp_portal",
        short_name  => "LAMP Portal",
        name        => "LAMP I&M System Portal",
        description => "Main portal for the LAMP I&M System (you're looking at it :).",
        module      => "perfSONAR_PS::NPToolkit::Config::Handlers::Base",
    },
);

=head2 init({ unis_instance => 1, config_file => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
unis_instance parameter must be passed to set which UNIS the module
should use for pulling/pushing the configuration.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { unis_instance => 1, last_pull_file => 0 } );

    # Initialize the defaults
    $self->{LAST_PULL_FILE}     = $defaults{last_pull_file};
    $self->{CURRENT_STATE_FILE} = $defaults{current_state_file};

    # Override any
    $self->{LAST_PULL_FILE}     = $parameters->{last_pull_file} if ( $parameters->{last_pull_file} );
    $self->{CURRENT_STATE_FILE} = $parameters->{current_state_file} if ( $parameters->{current_state_file} );
    
    # XXX: This could be determined through the hints file, especially 
    #   as there might be the need for querying multiple UNIS instances 
    $self->{UNIS_INSTANCE} = $parameters->{unis_instance};
    
    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 save({ })
    Saves the configuration to disk.
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { set_modified => 0, } );
    
    $self->{MODIFIED} = 1 if $parameters->{set_modified};
    
    my $res = $self->save_state();
    if ( $res == -1 ) {
        return (-1, "Problem saving state to disk.");
    }

    return 0;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
    Pulls the current configuration from UNIS if there's no local copy.
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my $must_pull = 1;
    # The frozen representation should always exist, unless there was
    # a problem with the parsing. In which case we should pull from UNIS anyways.
    if ( -e $self->{LAST_PULL_FILE} and -e $self->{CURRENT_STATE_FILE} ) {
        $must_pull = 0;
        eval {
            my $fd = new IO::File( $self->{LAST_PULL_FILE} ) or die " Failed to open config file.";
            
            # First line should be the last pull date.
            # We make sure it's a valid date, but keep it in string format.
            my $last_pull = <$fd>;
            chomp($last_pull);
            timelocal( strptime( $last_pull, "%Y-%m-%d %H:%M:%S" ) ) or die " Failed to parse last pull date.";
            
            # Restore the frozen state (maybe with modifications)
            if ( $self->restore_state() != 0 ) {
                die "Failed to load last state.";
            }
            
            ( $last_pull eq $self->{LAST_PULL_DATE} ) or die "Frozen state is unsynced with last pull data.";
            
            # Rest of file should be the topology data of all psconfig-enabled nodes.
            # We leave it alone for now (we use it for catching "race" conditions on the topology data).
            $fd->close();            
        } or do {
            my $msg = " Failed to load the configuration file: $@";
            $self->{LOGGER}->error( $msg );
            $must_pull = 1;
        };
    }
    
    # We pull the current configuratoin from UNIS if there was a problem
    # reading the configuration file or if there was none (i.e. first run).
    return $self->pull_configuration() if ( $must_pull == 1 );
    
    return 0;
}

=head2 pull_configuration ({ })
    TODO:
=cut

# GFR: There's a bug on the current UNIS implementation for the TS side
#   that xQuery's won't work, only xPath 1.0 queries.
use constant CONFIG_NODE_XPATH => "
//*[local-name()='node' and 
    namespace-uri()='" . UNIS_NS . "' and 
    ./*[local-name()='nodePropertiesBag' and 
        namespace-uri()='" . UNIS_NS . "']/*[local-name()='nodeProperties' and 
                                             namespace-uri()='" . PSCONFIG_NS . "']]
";

use constant NODE_XPATH => "//*[local-name()='node' and namespace-uri()='" . UNIS_NS . "']";

sub pull_configuration {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    # Query all nodes so we can also use the non-configurable nodes as test members.
    # XXX: Note that we rely on UNIS for filtering to our domain based on policy. 
    # XXX: We might not need to get everything from all nodes though.
    my $unis = perfSONAR_PS::Client::Topology->new( $self->{UNIS_INSTANCE} );
    my ( $status, $nodes ) = $unis->xQuery( NODE_XPATH );
   
    if ( $status != 0 ) {
        my $msg = "Couldn't query UNIS: $nodes";
        $self->{LOGGER}->error( $msg );
        return -1;
    }
    
    $self->{LAST_PULL_DATE} = strftime( "%Y-%m-%d %H:%M:%S", localtime );
    
    $status = $self->parse_configuration( { node_list_root => $nodes } );
    if ( $status != 0 ) {
         $self->{LOGGER}->error( "Couldn't parse pulled configuration." );
         return -1;
    }
   
    # Save what we just pulled to disk for book keeping
    eval {
        my $fd = new IO::File( "> ". $self->{LAST_PULL_FILE} ) or die " Failed to open config file.";
        
        # First line should be the last pull date (i.e. now).
        print $fd $self->{LAST_PULL_DATE} . "\n";
        
        # Rest of file should be the topology data of all 
        # psconfig-enabled nodes (i.e. what we just pulled).
        # TODO: Filter out only the config nodes according to CONFIG_NODE_XPATH.
        print $fd $nodes->toString();
        
        $fd->close();            
    } or do {
        my $msg = " Failed to save to the configuration file: $@";
        $self->{LOGGER}->error( $msg );
        # XXX: Maybe we don't have to fail here.
        return -1;
    };
    
    return 0;
}

sub push_configuration {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return (-1, "There have been no modifications") unless $self->{LAST_MODIFIED_DATE};
    
    my $unis = perfSONAR_PS::Client::Topology->new( $self->{UNIS_INSTANCE} );
    my ( $status, $res ) = $unis->xQuery( NODE_XPATH );
   
    if ( $status != 0 ) {
        my $msg = "Couldn't query UNIS: $res";
        $self->{LOGGER}->error( $msg );
        return (-1, "Couldn't query UNIS.");
    }
    
    my $new_topo = $res;
    
    # Make sure that the topology information (of config nodes) didn't change since
    # our last pull. This is our current way to avoid getting new information (probably
    # from other sources) overwritten because we modified a stale cache. (The user
    # *will* lose his changes though.)
    my $old_topo = '';
    eval {
        my $fd = new IO::File( $self->{LAST_PULL_FILE} ) or die " Failed to open config file.";
        
        my $last_pull = <$fd>;
        
        # Rest of the file should be the topology data we were operating on.
        # Slurp it.
        local( $/ );
        $old_topo = <$fd>;
        
        $fd->close(); 
    } or do {
        my $msg = " Failed to load the configuration file: $@";
        $self->{LOGGER}->error( $msg );
        return (-1, "Failed to load the configuration file.");
    };
    
    # TODO: String comparison is ugly here, since any difference
    #   (even in whitespaces) between the XMLs will be considered.
    #   Should check if XML::LibXML::Node::isSameNode works. 
    unless ( $old_topo eq $new_topo->toString() ) {
        # TODO: error msg
        my $msg = " The topology data in UNIS changed... : $@";
        $self->{LOGGER}->error( $msg );
        
        $self->{LAST_PULL_DATE} = strftime( "%Y-%m-%d %H:%M:%S", localtime );
        $self->parse_configuration( { node_list_root => $new_topo } );
        
        return (-1, "Race condition detected, local changes lost.");
    }
    
    # We change the encoded XML in place with the new configuration so that
    # we don't mess with other node related data (because UNIS only supports
    # replacing whole base topology elements for now). 
    foreach my $node (  $new_topo->getChildrenByTagNameNS( UNIS_NS, "node" )->get_nodelist ) {
        my $node_id = $node->getAttribute( "id" );
        
        my @node_properties = $node->getElementsByTagNameNS( PSCONFIG_NS, "nodeProperties" );
        next unless scalar @node_properties > 0;
        
        my $psconfig_properties = $node_properties[0];
        
        # TODO: Policy
        
        my %services_configured = ();
        foreach my $service ( $psconfig_properties->getChildrenByTagNameNS( PSCONFIG_NS, "service" )->get_nodelist ) {
            my $type = $service->getAttribute( "type" );
            
            # Ignore this service if don't know about it.
            next unless exists $known_services{ $type };
            
            # No service of this type on our current state means that the service
            # had no configuration and was disabled (so we just remove it).
            unless ( exists $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type } ) {
                $psconfig_properties->removeChild( $service );
                next;
            }
            
            # Delegate actual configuration updates to the service-specific module.
            $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type }->{CONFIGURATION}->update_encoded( { service => $service } );
            
            $services_configured{ $type } = 1;
        }
        
        # Now we add the services that didn't exist on the node before.
        foreach my $service_type ( keys %{ $self->{CONFIG_NODES}->{ $node_id }->{SERVICES} } ) {
            next if exists $services_configured{ $service_type };
            
            $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $service_type }->{CONFIGURATION}->add_encoded( { node_properties => $psconfig_properties } );
        }
    }
    
    # UNIS expects the nodes to be inside a <topology> element, 
    # so we just change the <nmwg:data> wrapper from the xQuery.
    $new_topo->setNamespace( UNIS_NS, "unis", 1 );
    
    # This is not DOM compliant, but works. Otherwise we would have
    # to create a separate topology element and add the children.
    $new_topo->setNodeName( "unis:topology" );
    
    ( $status, $res ) = $unis->changeTopology( "replace", $new_topo );
    
    if ( $status != 0 ) {
        my $msg = "Couldn't replace topology data on UNIS: $res";
        $self->{LOGGER}->error( $msg );
        return (-1, "Couldn't replace topology data on UNIS.");
    }
    
    # We pull the configuration back because UNIS normalizes the topology
    # and moves things around. We need the exact textual representation.
    $status = $self->pull_configuration();
    
    if ( $status != 0 ) {
        # Now this is tricky. Theoretically we already pushed the new changes.
        # We haven't updated the current state, and the last pull is stale.
        # Likely the best thing to do at this point is to just erase all local data.
        $self->clear_state();
        
        # TODO: not sure how're gonna disable the interface until we get the data.
    }
    
    return ( 0, "" );
}

=head2 parse_configuration ({ node_list_root => 1 })
    TODO:
=cut

sub parse_configuration {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node_list_root => 1 } );
    
    my $node_list_root = $parameters->{node_list_root};
    
    return -1 unless ( ref $node_list_root eq "XML::LibXML::Element" );
    
    $self->{NODES} = {};
    $self->{CONFIG_NODES} = {};
    foreach my $node (  $node_list_root->getChildrenByTagNameNS( UNIS_NS, "node" )->get_nodelist ) {
        my $node_id = $node->getAttribute( "id" );
        
        # For the name of the node we either use one of the node's <unis:name>
        # elements if any, otherwise we use the node value of the id.
        my @node_names = $node->getChildrenByTagNameNS( UNIS_NS, "name" );
        if ( scalar @node_names > 0 ) {
            foreach my $name ( @node_names ) {
                my $name_val = extract( $name, 0 );
                # Trim it
                $name_val =~ s/^\s*//;
                $name_val =~ s/\s*$//;
                
                # Make sure it's not empty
                if ( $name_val ) {
                    $self->{NODES}->{ $node_id }->{name} = $name_val;
                    last;
                }
            }
        }
        
        unless ( exists $self->{NODES}->{ $node_id }->{name} ) {
            $self->{NODES}->{ $node_id }->{name} = idBaseLevel( $node_id );
        }
        
        my @node_properties = $node->getElementsByTagNameNS( PSCONFIG_NS, "nodeProperties" );
        
        if ( scalar @node_properties > 0 ) {
            unless ( scalar @node_properties == 1 ) { 
                $self->{LOGGER}->error( " Invalid number of psconfig:nodeProperties for $node_id." );
                next;
            }
            
            $self->{CONFIG_NODES}->{ $node_id }->{name} = $self->{NODES}->{ $node_id }->{name};
               
            for my $service ( $node_properties[0]->getElementsByTagNameNS( PSCONFIG_NS, "service" ) ) {
                my $service_type = $service->getAttribute( "type" );
                
                # For now we only care about services we know about.
                next unless exists $known_services{ $service_type };
                
                my $service_ref = $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $service_type } = {};
                $self->init_service( { type => $service_type, service => $service_ref } );
                
                $service_ref->{CONFIGURATION}->load_encoded( { service => $service } );
            }
        }
    }
    
    # Everytime we parse we're essentially resetting the state.
    # MODIFIED says whether we modified the *frozen state*, and LAST_MODIFIED_DATE
    # is the last time we saved a modified configuration (too confusing?).
    $self->{MODIFIED} = 1;
    $self->{LAST_MODIFIED_DATE} = 0;
    $self->save_state( { keep_modified_date => 1 } );
    
    return 0;
}

=head2 get_nodes ({})
    Returns the list of nodes as a hash indexed by UNIS id. 
    The hash values are hashes containing the node's properties.
=cut

sub get_nodes {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{NODES};
}

=head2 get_config_nodes ({})
    Returns the list of nodes that can be configured (tagged by having the 
    psconfig:nodeProperties element) as a hash indexed by UNIS id. The hash
    values are hashes containing the node's properties (including a SERVICES hash).
=cut

sub get_config_nodes {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{CONFIG_NODES};
}

=head2 get_services ({ node_id => 1 })
    Returns the list of services as a hash indexed by name. The hash values are
    hashes containing the service's properties.
=cut

sub get_services {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node_id => 1, } );

    return $self->{CONFIG_NODES}->{ $parameters->{node_id} }->{SERVICES};
}

=head2 get_known_services ({ })
    Returns the list of known services as a hash indexed by name. 
    The hash values are hashes containing the service's properties.
=cut

sub get_known_services {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return \%known_services;
}

=head2 lookup_service ({ node_id => 1, type => 1 })
    Returns the properties of the specified service as a hash. Returns
    undefined if the service request does not exist.
=cut

sub lookup_service {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node_id => 1, type => 1, } );

    my $node_id = $parameters->{node_id};
    my $type    = $parameters->{type};
    
    return undef unless exists $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type };
    
    return $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type };
}

# TODO: The service ref should be directly an instance of the handler for this service.
sub init_service {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { type => 1, service => 1, } );
    
    my $service_type = $parameters->{type};
    my $service      = $parameters->{service};
            
    # Append all we know about this service.
    @$service{ keys %{ $known_services{ $service_type } } }  = values %{ $known_services{ $service_type } };
            
    # For further processing by the service-specific config module.
    $service->{CONFIGURATION} = $service->{module}->new();
    $service->{CONFIGURATION}->init( { service => $service } );
    
    return 0;
}

=head2 enable_service ({ node_id => 1, type => 1})
    Enables the specified service. Returns 0 if successful and -1 if the
    service does not exist.
=cut

sub enable_service {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node_id => 1, type => 1, } );

    my $node_id = $parameters->{node_id};
    my $type = $parameters->{type};
    
    unless ( exists $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type } ) {
        # New service enabled. There's currently some redundancy between
        # this module and the handler regarding enabling/disabling.
        my $service_ref = $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type } = {};
        $self->init_service( { type => $type, service => $service_ref } );
        
        $service_ref->{enabled} = 1;
        
        $self->{MODIFIED} = 1;
        
        return 0;
    }
    
    return 0 unless $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type }->{enabled};
    
    $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type }->{CONFIGURATION}->enable();
    $self->{MODIFIED} = 1;
    
    return 0;
}

=head2 disable_service ({ node_id => 1, name => 1})
    Disables the specified service. Returns 0 if successful and -1 if the
    service does not exist.
=cut

sub disable_service {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node_id => 1, type => 1, } );

    my $node_id = $parameters->{node_id};
    my $type = $parameters->{type};
    
    return 0 unless exists $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type };
    return 0 unless $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type }->{enabled};
    
    $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type }->{CONFIGURATION}->disable();
    
    # We simply remove the service if there's no configuration associated.
    if ( $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type }->{CONFIGURATION}->is_empty() ) {
        delete $self->{CONFIG_NODES}->{ $node_id }->{SERVICES}->{ $type };
    }
    
    $self->{MODIFIED} = 1;
    
    return 0;
}

=head2 last_pull()
    Returns when the site information was last pulled from UNIS.
=cut

sub last_pull {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{LAST_PULL_DATE};
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{LAST_MODIFIED_DATE};
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { keep_modified_date => 0 } );

    return 0 unless $self->{MODIFIED};
    
    unless ( exists $parameters->{keep_modified_date} and $parameters->{keep_modified_date} ) {
        $self->{LAST_MODIFIED_DATE} = strftime( "%Y-%m-%d %H:%M:%S", localtime );
    }
    
    my %state = (
        NODES               => $self->{NODES},
        CONFIG_NODES        => $self->{CONFIG_NODES},
        LAST_PULL_DATE      => $self->{LAST_PULL_DATE},
        LAST_MODIFIED_DATE  => $self->{LAST_MODIFIED_DATE},
    );

    return -1 unless store( \%state, $self->{CURRENT_STATE_FILE} );

    return 0;
}

=head2 restore_state({ })
    Restores the modules state based on a string provided by the "save_state"
    function above.
=cut

sub restore_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return -1 unless -f $self->{CURRENT_STATE_FILE};
    
    my $state = retrieve( $self->{CURRENT_STATE_FILE} );
    
    return -1 unless $state;
    
    $self->{NODES}              = $state->{NODES};
    $self->{CONFIG_NODES}       = $state->{CONFIG_NODES};
    $self->{LAST_PULL_DATE}     = $state->{LAST_PULL_DATE};
    $self->{LAST_MODIFIED_DATE} = $state->{LAST_MODIFIED_DATE};
    
    # MODIFIED says whether we modified the *frozen state*.
    $self->{MODIFIED} = 0;
    
    return 0;
}

=head2 clear_state({ })
    Removes all local state.
=cut

sub clear_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    unlink ( $self->{LAST_PULL_FILE} );
    unlink ( $self->{CURRENT_STATE_FILE} );
    
    $self->{NODES}              = undef;
    $self->{CONFIG_NODES}       = undef;
    $self->{LAST_PULL_DATE}     = undef;
    $self->{LAST_MODIFIED_DATE} = undef;
    $self->{MODIFIED}           = undef;
    
    return 0;
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
