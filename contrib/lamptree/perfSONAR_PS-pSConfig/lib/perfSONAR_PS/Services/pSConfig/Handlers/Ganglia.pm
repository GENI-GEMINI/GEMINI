package perfSONAR_PS::Services::pSConfig::Handlers::Ganglia;

use base 'perfSONAR_PS::Services::pSConfig::Handlers::Base';

use fields 'GMOND_CONF_TEMPLATE_FILE', 'GMOND_CONF_FILE', 'GMETAD_CONF_TEMPLATE_FILE', 
        'GMETAD_CONF_FILE', 'DOMAIN', 'GMETAD_HOST', 'INTERFACES';

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

TODO:

=head1 DESCRIPTION

TODO:
TODO: Merge with perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting

=cut

use Readonly;
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use Sys::Hostname;

use perfSONAR_PS::Common qw(extract find mergeHash);
use perfSONAR_PS::Topology::ID qw(idBaseLevel idSplit);

use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );

# XXX: Namespaces should be kept in a single module?
use constant UNIS_NS      => 'http://ogf.org/schema/network/topology/unis/20100528/';
use constant PSCONFIG_NS  => 'http://ogf.org/schema/network/topology/psconfig/20100716/';

# These are the defaults for LAMP
my %defaults = (
    gmond_conf_template_file  => "/usr/local/etc/gmond_conf.tmpl",
    gmond_conf_file           => "/opt/ganglia/etc/gmond.conf",
    gmetad_conf_template_file => "/usr/local/etc/gmetad_conf.tmpl",
    gmetad_conf_file          => "/opt/ganglia/etc/gmetad.conf",
);

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=head2 init($self)

TODO:

=cut

sub init {
    my ( $self ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::pSConfig::Handlers::Ganglia" );
    
    $self->{CONF} = mergeHash( $self->{CONF}, $self->{CONF}->{"ganglia"}, {} ) if exists $self->{CONF}->{"ganglia"};
    
    if ( exists $self->{CONF}->{"gmond_conf_template_file"} and $self->{CONF}->{"gmond_conf_template_file"} ) {
        $self->{GMOND_CONF_TEMPLATE_FILE} = $self->{CONF}->{"gmond_conf_template_file"};
    } 
    else {
        $self->{GMOND_CONF_TEMPLATE_FILE} = $defaults{gmond_conf_template_file};
    }
    
    if ( exists $self->{CONF}->{"gmond_conf_file"} and $self->{CONF}->{"gmond_conf_file"} ) {
        $self->{GMOND_CONF_FILE} = $self->{CONF}->{"gmond_conf_file"};
    } 
    else {
        $self->{GMOND_CONF_FILE} = $defaults{gmond_conf_file};
    }
    
    if ( exists $self->{CONF}->{"gmetad_conf_template_file"} and $self->{CONF}->{"gmetad_conf_template_file"} ) {
        $self->{GMETAD_CONF_TEMPLATE_FILE} = $self->{CONF}->{"gmetad_conf_template_file"};
    } 
    else {
        $self->{GMETAD_CONF_TEMPLATE_FILE} = $defaults{gmetad_conf_template_file};
    }
    
    if ( exists $self->{CONF}->{"gmetad_conf_file"} and $self->{CONF}->{"gmetad_conf_file"} ) {
        $self->{GMETAD_CONF_FILE} = $self->{CONF}->{"gmetad_conf_file"};
    } 
    else {
        $self->{GMETAD_CONF_FILE} = $defaults{gmetad_conf_file};
    }
    
    return 0;
}

=head2 apply($self, $node, $changed)

TODO:

=cut

sub apply {
    my ( $self, $node, $last_config, $changed, $first_run, $failed_last ) = @_;
    
    my $force_run = ( $changed or $failed_last or $first_run );
    return 0 unless $force_run;
    
    my $gmetad     = find( $node, './/*[local-name()="service" and @type="ganglia_gmetad"]', 1 );
    my $gmond      = find( $node, './/*[local-name()="service" and @type="ganglia_gmond"]', 1 );
    my $ganglia_ma = find( $node, './/*[local-name()="service" and @type="ganglia_ma"]', 1 );
    
    unless ( $gmetad or $gmond or $ganglia_ma ) {
        $self->{LOGGER}->error( "Couldn't find ganglia related configuration entries, skipping." );
        return 0;
    }
    
    my $status = 0;
    
    # 
    # XXX: configure_gmetad also configures gmond. 
    #    
    if ( $gmetad ) {
        #
        # Something completely unrelated on the node config could have changed,
        # so we try to check if our particular service's config did or not.
        # TODO: this way of checking will treat any textual change as significant).
        #
        my $old_gmetad = find( $last_config, './/*[local-name()="service" and @type="ganglia_gmetad"]', 1 );
        
        next if not $force_run and $old_gmetad and $old_gmetad->toString eq $gmetad->toString;
        
        $status = ( $self->configure_gmetad( { node => $node, service => $gmetad } ) or $status );
    }
    elsif ( $gmond ) {
        my $old_gmond = find( $last_config, './/*[local-name()="service" and @type="ganglia_gmond"]', 1 );
        
        next if not $force_run and $old_gmond and $old_gmond->toString eq $gmond->toString;
        
        $status = ( $self->configure_gmond( { node => $node, service => $gmond } ) or $status );
    }
    
    if ( $ganglia_ma ) {
        my $old_ganglia_ma = find( $last_config, './/*[local-name()="service" and @type="ganglia_ma"]', 1 );
        
        next if not $force_run and $old_ganglia_ma and $old_ganglia_ma->toString eq $ganglia_ma->toString;
        
        $status = ( $self->configure_ganglia_ma( { node => $node, service => $ganglia_ma } ) or $status );
    }
    
    # for now, we never change the node config on UNIS
    return 0; 
}

use constant GMETAD_NODE_XPATH => "
//*[local-name()='node' and namespace-uri()='" . UNIS_NS . "' and 
    ./*[local-name()='nodePropertiesBag' and namespace-uri()='" . UNIS_NS . "'
       ]/*[local-name()='nodeProperties' and namespace-uri()='" . PSCONFIG_NS . "'
          ]/*[local-name()='service' and namespace-uri()='" . PSCONFIG_NS . "' 
              and \@type='ganglia_gmetad' and \@enable='true']]
";

use constant INTERFACE_NAME_XPATH => "
//*[local-name()='port' and namespace-uri()='" . UNIS_NS . "'
   ]/*[local-name()='name' and namespace-uri()='" . UNIS_NS . "']
";

sub configure_gmond {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node => 1, service => 0, gmetad => 0 } );
    
    #
    # For now we don't have a proper configuration for gmond (e.g. which metrics to
    # enable, where to send announcements, etc). We try to find the gmetad instance
    # through the configuration on the topology (if not given). 
    #
    # TODO: We should eventually also check for a gmetad instance registered as a daemon on UNIS.
    #
    my $gmetad_host = $parameters->{gmetad};
    
    unless ( $gmetad_host ) {
        my ( $status, $res ) = $self->{UNIS_CLIENT}->xQuery( GMETAD_NODE_XPATH );
       
        if ( $status != 0 ) {
            my $msg = "Couldn't query UNIS: $res";
            $self->{LOGGER}->error( $msg );
            return -1;
        }
        
        my @gmetad_nodes = $res->getElementsByTagNameNS( UNIS_NS, "node" );
        
        return -1 unless scalar @gmetad_nodes;
        
        # 
        # XXX: We assume the node is from our slice, and that our hostname was set
        #   properly by the control framework (i.e. it resolves to our control interface's
        #   IP). So we just substitute the gmetad node's name in our hostname.
        #   We are also relying on the fact that our manifest->unis conversion will
        #   set node ids properly.
        #
        # TODO: Eventually we can trust that the right hostname has been pushed to UNIS
        #   and use that. Initially on the manifest we only have the 'real' hostname.
        #
        my $gmetad_node_name = idBaseLevel( $gmetad_nodes[0]->getAttribute( "id" ) );
        
        my $host = hostname;
        $host =~ s/^[^\.]+/$gmetad_node_name/;
        
        $gmetad_host = $host;
    }
    
    $self->{GMETAD_HOST} = $gmetad_host;
    
    foreach my $interface ( $parameters->{node}->findnodes( INTERFACE_NAME_XPATH ) ) {
        my $name = extract( $interface, 1 );
        
        $self->{INTERFACES}->{$name} = 1;
    }
    
    # Get the domain off the node id to use as our cluster (and grid).
    my @id_fields = idSplit( $self->{NODE_ID}, 0, 1 );
    $self->{DOMAIN} = $id_fields[3];
    
    my $gmond_conf_output = $self->generate_gmond_conf();
    
    return -1 unless $gmond_conf_output;
    
    my $res = save_file( { file => $self->{GMOND_CONF_FILE}, content => $gmond_conf_output } );
    if ( $res == -1 ) {
        $self->{LOGGER}->error( "File save failed: " . $self->{GMOND_CONF_FILE} );
        return -1;
    }
    
    my $status = restart_service( { name => "ganglia_gmond" } );
    if ( $status != 0 ) {
        $self->{LOGGER}->error( "Couldn't restart gmond" );
        return -1;
    }
    
    return 0;
}

sub configure_gmetad {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node => 1, service => 0, } );
    
    my $hostname = hostname;
    
    my $status = $self->configure_gmond( { node => $parameters->{node}, service => $parameters->{service}, gmetad => $hostname } );
    
    return $status if $status != 0;
    
    # configure_gmond() already filled in everything we need
    
    my $gmetad_conf_output = $self->generate_gmetad_conf();
    
    return -1 unless $gmetad_conf_output;
    
    $status = save_file( { file => $self->{GMETAD_CONF_FILE}, content => $gmetad_conf_output } );
    if ( $status == -1 ) {
        $self->{LOGGER}->error( "File save failed: " . $self->{GMETAD_CONF_FILE} );
        return -1;
    }
    
    $status = restart_service( { name => "ganglia_gmetad" } );
    if ( $status != 0 ) {
        $self->{LOGGER}->error( "Couldn't restart gmetad" );
        return -1;
    }
    
    return 0;
}

sub configure_ganglia_ma {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node => 1, service => 0, } );
    
    # No need to configure, maybe just a restart.
    return 0;
}

=head2 generate_gmond_conf ({})
    Converts the internal configuration into the expected template toolkit
    variables, and passes them to template toolkit along with the configured
    template.
=cut

sub generate_gmond_conf {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    my %vars            = ();
    my @vars_interfaces = keys %{ $self->{INTERFACES} };
    
    $vars{domain}      = $self->{DOMAIN};
    $vars{gmetad_host} = $self->{GMETAD_HOST};
    $vars{interfaces}  = \@vars_interfaces;
    
    # Deaf if we're not the collector
    $vars{deaf}        = ( $self->{GMETAD_HOST} ne hostname );
    
    my $config;

    my $tt = Template->new( ABSOLUTE => 1 );
    unless ( $tt ) {
        $self->{LOGGER}->error( "Couldn't initialize template toolkit" );
        return;
    }

    unless ( $tt->process( $self->{GMOND_CONF_TEMPLATE_FILE}, \%vars, \$config ) ) {
        $self->{LOGGER}->error( "Error creating $self->{GMOND_CONF_FILE}: " . $tt->error() );
        return;
    }

    return $config;
}

sub generate_gmetad_conf {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    my %vars       = ();
    $vars{domain}  = $self->{DOMAIN};
    
    my $config;

    my $tt = Template->new( ABSOLUTE => 1 );
    unless ( $tt ) {
        $self->{LOGGER}->error( "Couldn't initialize template toolkit" );
        return;
    }

    unless ( $tt->process( $self->{GMETAD_CONF_TEMPLATE_FILE}, \%vars, \$config ) ) {
        $self->{LOGGER}->error( "Error creating $self->{GMETAD_CONF_TEMPLATE_FILE}: " . $tt->error() );
        return;
    }

    return $config;
}

1;
__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::pSConfig::Handlers::Base>

=cut
