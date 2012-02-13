package perfSONAR_PS::Services::pSConfig::Handlers::Services;

use base 'perfSONAR_PS::Services::pSConfig::Handlers::Base';

use fields 'SERVICES', 'ENABLED_SERVICES_FILE';

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

TODO:

=head1 DESCRIPTION

TODO:
TODO: Merge with perfSONAR_PS::NPToolkit::Config::Handlers::Services

=cut

use Readonly;
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use perfSONAR_PS::Common qw(extract find mergeHash);

use perfSONAR_PS::NPToolkit::Config::Services;

use constant PSCONFIG_NS => 'http://ogf.org/schema/network/topology/psconfig/20100716/';

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=head2 init($self)

TODO:

=cut

sub init {
    my ( $self ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::pSConfig::Handlers::Services" );
    
    $self->{CONF} = mergeHash( $self->{CONF}, $self->{CONF}->{"services"}, {} ) if exists $self->{CONF}->{"services"};
    
    if ( exists $self->{CONF}->{"enabled_services_file"} and $self->{CONF}->{"enabled_services_file"} ) {
        $self->{ENABLED_SERVICES_FILE} = $self->{CONF}->{"enabled_services_file"};
    }
    
    $self->{SERVICES} = {};
     
    return 0;
}

=head2 apply($self, $node, $changed)

TODO:

=cut

sub apply {
    my ( $self, $node, $last_config, $changed, $first_run, $failed_last ) = @_;
    
    my $force_run = ( $changed or $failed_last or $first_run );
    return 0 unless $force_run;
    
    my $services = find( $node, './/*[local-name()="service" and namespace-uri()="' . PSCONFIG_NS . '"]', 0 );
    
    unless ( $services->size() ) {
        $self->{LOGGER}->error( "Couldn't find any psconfig:service configuration entry, skipping." );
        return 0;
    }
    
    $self->load_encoded( { services => $services } );
    
    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $services_conf->init( { enabled_services_file => $self->{ENABLED_SERVICES_FILE} } );
    
    $services_conf->clear_state();
    
    foreach my $service_type ( keys %{ $self->{SERVICES} } ) {
        if ( $self->{SERVICES}->{$service_type}->{enabled} ) {
            $services_conf->enable_service( { name => $service_type } );
        }
        else {
            $services_conf->disable_service( { name => $service_type } );
        }
    }
    
    $services_conf->save( { restart_services => 0 } );
    
    # for now, we never change the node config
    return 0; 
}

# This is adapted from perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting
# The two handlers should probably be the same module, or have an 'utils' module.
sub load_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { services => 1, } );
    
    $self->{SERVICES} = {};
    
    my $services = $parameters->{services};
    
    foreach my $service ( $services->get_nodelist() ) {
        my $type = $service->getAttribute( "type" );
        
        if ( $service->hasAttribute( "enable" ) and lc( $service->getAttribute( "enable" ) ) eq "true" ) {
            $self->{SERVICES}->{$type}->{enabled} = 1;
        }
        else {
            $self->{SERVICES}->{$type}->{enabled} = 0;
        }
    }
    
    return 0;
}

1;
__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::pSConfig::Handlers::Base>

=cut
