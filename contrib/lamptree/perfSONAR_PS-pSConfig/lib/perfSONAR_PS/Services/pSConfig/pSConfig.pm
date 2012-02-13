package perfSONAR_PS::Services::pSConfig::pSConfig;

use base 'perfSONAR_PS::Services::Base';

use fields 'LOGGER', 'UNIS_CLIENT', 'NODE_ID', 'PUSH', 'QUERY', 'HANDLERS', 'FAILED_LAST', 'FIRST_RUN', 'LAST_CONFIG_FILE';

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

TODO:

=head1 DESCRIPTION

TODO:

=cut

use IO::File;
use Module::Load;
use Log::Log4perl qw(get_logger);

use perfSONAR_PS::Common qw(duplicateHash parseToDOM);
use perfSONAR_PS::Client::Topology;
use perfSONAR_PS::Topology::ID qw(idConstruct idIsFQ);

use constant UNIS_NS      => 'http://ogf.org/schema/network/topology/unis/20100528/';
use constant PSCONFIG_NS        => 'http://ogf.org/schema/network/topology/psconfig/20100716/';
use constant UNIS_NODE_XQUERY   => "//*[local-name()='node' and \@id='__NODEID__' and namespace-uri()='http://ogf.org/schema/network/topology/unis/20100528/']";

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=cut

=head2 init($self)

TODO: 

Called at startup by the daemon when this particular module is loaded into
the perfSONAR-PS deployment. 

=cut

sub init {
    my ( $self ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::pSConfig::pSConfig" );
    
    unless ( exists $self->{CONF}->{"unis_instance"} and $self->{CONF}->{"unis_instance"}) {
        $self->{LOGGER}->error("unis_instance is a required configuration option");
        return -1;
    }
    
    $self->{UNIS_CLIENT} = perfSONAR_PS::Client::Topology->new( $self->{CONF}->{"unis_instance"} );
    
    unless ( exists $self->{CONF}->{"psconfig"} and $self->{CONF}->{"psconfig"} ) {
        $self->{LOGGER}->error("No pSConfig configuration provided.");
        return -1;
    }
    
    if ( exists $self->{CONF}->{"psconfig"}->{"connectivity_type"} and $self->{CONF}->{"psconfig"}->{"connectivity_type"} ) {
        # Eventually this could configure remote nodes or network equipment
        unless ( $self->{CONF}->{"psconfig"}->{"connectivity_type"} eq "local" ) {
            $self->{LOGGER}->error("Only connectivity type currently supported is 'local'.");
            return -1;
        }
    }
    
    if ( exists $self->{CONF}->{"psconfig"}->{"node_id"} and $self->{CONF}->{"psconfig"}->{"node_id"} ) {
        unless( idIsFQ( $self->{CONF}->{"psconfig"}->{"node_id"}, "node" ) ) {
            $self->{LOGGER}->error("node_id must be fully qualified.");
            return -1;
        }
        $self->{NODE_ID} = $self->{CONF}->{"psconfig"}->{"node_id"};
    }
    elsif ( exists $self->{CONF}->{"psconfig"}->{"domain"} and $self->{CONF}->{"psconfig"}->{"domain"} and
                exists $self->{CONF}->{"psconfig"}->{"node"} and $self->{CONF}->{"psconfig"}->{"node"} ) {
        $self->{NODE_ID} = idConstruct( "domain", $self->{CONF}->{"psconfig"}->{"domain"}, "node", $self->{CONF}->{"psconfig"}->{"node"}, q{} );
    }
    elsif ( exists $self->{CONF}->{"node_id"} and $self->{CONF}->{"node_id"} ) {
        unless( idIsFQ( $self->{CONF}->{"node_id"}, "node"  ) ) {
            $self->{LOGGER}->error("node_id must be fully qualified.");
            return -1;
        }
        $self->{NODE_ID} = $self->{CONF}->{"node_id"};
    }
    else {
        $self->{LOGGER}->error("Couldn't determine node id.");
        return -1;
    }
    
    $self->{QUERY} = UNIS_NODE_XQUERY;
    $self->{QUERY} =~ s/__NODEID__/$self->{NODE_ID}/;
    
    if ( exists $self->{CONF}->{"psconfig"}->{"enable_push"} and $self->{CONF}->{"psconfig"}->{"enable_push"} ) {
        $self->{PUSH} = $self->{CONF}->{"psconfig"}->{"enable_push"};
    }
    else {
        $self->{PUSH} = 0;
    }
    
    unless ( exists $self->{CONF}->{"psconfig"}->{"handler"} and $self->{CONF}->{"psconfig"}->{"handler"} ) {
        $self->{LOGGER}->error("You must specify at least one handler.");
        return -1;
    }
    
    my @loaded_handlers = ();
    
    my @handlers= ();
    if ( ref $self->{CONF}->{"psconfig"}->{"handler"} eq "ARRAY" ) {
        @handlers = @{ $self->{CONF}->{"psconfig"}->{"handler"} };
    }
    else {
        push @handlers, ref $self->{CONF}->{"psconfig"}->{"handler"};
    }
    
    foreach my $handler ( @handlers ) {
        
        unless ( exists $handler->{"module"} and $handler->{"module"} ) {
            $self->{LOGGER}->error("No module defined for handler.");
            return -1;
        } 
        
        my $handler_conf = duplicateHash( $handler, { module => 1 } );
        
        load $handler->{"module"};
        my $loaded_handler = $handler->{"module"}->new( $handler_conf, $self->{UNIS_CLIENT}, $self->{NODE_ID}, $self->{PUSH} );
        
        unless ( $loaded_handler->isa( "perfSONAR_PS::Services::pSConfig::Handlers::Base" ) ) {
            $self->{LOGGER}->error("Handler " . $handler->{"module"} . " doesn't extend perfSONAR_PS::Services::pSConfig::Handlers::Base.");
            return -1;
        }
        
        if ( $loaded_handler->init() != 0 ) {
            $self->{LOGGER}->error( "Failed to initialize handler " . $handler->{"module"} );
            return -1;
        }
        
        push @loaded_handlers, $loaded_handler;
        
        $self->{FAILED_LAST}->{$loaded_handler} = 0;
    }
    
    $self->{HANDLERS} = \@loaded_handlers;
    
    if ( exists $self->{CONF}->{"psconfig"}->{"last_config_file"} and $self->{CONF}->{"psconfig"}->{"last_config_file"} ) {
        $self->{LAST_CONFIG_FILE} = $self->{CONF}->{"psconfig"}->{"last_config_file"};
    }
    else {
        $self->{LAST_CONFIG_FILE} = $self->{DIRECTORY} + '/last';
    }
    
    unless ( -e $self->{LAST_CONFIG_FILE} ) {
        my $fd;
        unless ( open( $fd, "> $self->{LAST_CONFIG_FILE}" ) ) {
            $self->{LOGGER}->error( "Unable to open last config file ($self->{LAST_CONFIG_FILE}): $!" );
            return -1;
        }
        print $fd '<init/>';
        close $fd;
    }
    
    $self->{FIRST_RUN} = 1;
    
    return 0;
}

sub run {
    my ( $self ) = @_;
    my ( $status, $res );
    my $changed = 0;
    
    ( $status, $res ) = $self->{UNIS_CLIENT}->xQuery( $self->{QUERY} );
   
    if ( $status != 0 ) {
        my $msg = "Couldn't query UNIS: $res";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }
    
    my $node = $res->nonBlankChildNodes()->[0];
    $node->setNamespace( UNIS_NS, "unis", 0 );
    
    my $last_config;
    eval {
        local ( $/ );
        my $fd = new IO::File( $self->{LAST_CONFIG_FILE} ) or die " Failed to open last config file ";
        $last_config = <$fd>;
        $changed = not $last_config eq $node->toString;
        $fd->close;
        
        $fd = new IO::File( "> $self->{LAST_CONFIG_FILE}" ) or die " Failed to open last config file ";
        print $fd $node->toString;
        $fd->close;
    } or do {
        my $msg = " Failed to open last config file: $@";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    };
    
    $last_config = parseToDOM( $last_config );
    
    if ( $last_config == -1 ) {
        my $msg = " Failed to parse last config file: $@";
        $self->{LOGGER}->error( $msg );
        return ( -1, $msg );
    }
    
    $last_config = $last_config->documentElement();
    
    my $node_clone = $node->cloneNode( 1 ); 
    
    my $push = 0;
    foreach my $handler ( @{ $self->{HANDLERS} } ) {
        $res = $handler->apply( $node_clone, $last_config, $changed, $self->{FIRST_RUN}, $self->{FAILED_LAST}->{$handler} );
        
        if ( $res < 0 ) {
            $self->{FAILED_LAST}->{$handler} = 1
        } 
        else {
            $changed = ( $changed or $push );
            $push = ( $res or $push );
        }
    }

    if ( $self->{CONF}->{"psconfig"}->{"enable_push"} and $push and not $node_clone->toString eq $node->toString ) {
        # TODO: double check that the node information on UNIS hasn't
        #   changed while we were processing it (duplicate and compare).
        #   Maybe we also need to make sure the modules didn't do something
        #   like change the id of the node.
        ( $status, $res ) = $self->{UNIS_CLIENT}->changeTopology( "replace", $node_clone );
        
        if ( $status != 0 ) {
            my $msg = "Couldn't replace node: $res";
            $self->{LOGGER}->error( $msg );
            return ( -1, $msg );
        }
    }
    
    $self->{FIRST_RUN} = 0;
    
    return (0, q{});
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<perfSONAR_PS::Client::LS>

=cut
