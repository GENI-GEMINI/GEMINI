package perfSONAR_PS::Services::pSConfig::Handlers::RegularTesting;

use base 'perfSONAR_PS::Services::pSConfig::Handlers::Base';

use fields 'TESTS', 'LOCAL_PORT_RANGES', 'PERFSONARBUOY_CONF_TEMPLATE', 'PERFSONARBUOY_CONF_FILE', 'PINGER_LANDMARKS_CONF_FILE';

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
use perfSONAR_PS::Common qw(extract extract_first find mergeHash);

use perfSONAR_PS::NPToolkit::Config::RegularTesting;

use constant PSCONFIG_NS       => 'http://ogf.org/schema/network/topology/psconfig/20100716/';
use constant RTEST_PSCONFIG_NS => 'http://ogf.org/schema/network/topology/psconfig/regtesting/20100914/';

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=head2 init($self)

TODO:

=cut

sub init {
    my ( $self ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::pSConfig::Handlers::RegularTesting" );
    
    $self->{CONF} = mergeHash( $self->{CONF}, $self->{CONF}->{"regular_testing"}, {} ) if exists $self->{CONF}->{"regular_testing"};
    
    if ( exists $self->{CONF}->{"perfsonarbuoy_conf_template"} and $self->{CONF}->{"perfsonarbuoy_conf_template"} ) {
        $self->{PERFSONARBUOY_CONF_TEMPLATE} = $self->{CONF}->{"perfsonarbuoy_conf_template"};
    }
    
    if ( exists $self->{CONF}->{"perfsonarbuoy_conf_file"} and $self->{CONF}->{"perfsonarbuoy_conf_file"} ) {
        $self->{PERFSONARBUOY_CONF_FILE} = $self->{CONF}->{"perfsonarbuoy_conf_file"};
    }
    
    if ( exists $self->{CONF}->{"pinger_landmarks_file"} and $self->{CONF}->{"pinger_landmarks_file"} ) {
        $self->{PINGER_LANDMARKS_CONF_FILE} = $self->{CONF}->{"pinger_landmarks_file"};
    }
        
    return 0;
}

=head2 apply($self, $node, $changed)

TODO:

=cut

sub apply {
    my ( $self, $node, $last_config, $changed, $first_run, $failed_last ) = @_;
    
    my $force_run = ( $failed_last or $first_run );
    return 0 unless $changed or $force_run;
    
    my $service = find( $node, './/*[local-name()="service" and namespace-uri()="' . PSCONFIG_NS . '" and @type="regular_testing"]', 1 );
    
    unless ( $service ) {
        $self->{LOGGER}->warn( "Couldn't find regular_testing configuration entry, skipping." );
        return 0;
    }
    
    # Something completely unrelated on the node config could have changed,
    # so we try to check if our regular_testing config did or not.
    # TODO: this way of checking will treat any textual change as significant).
    my $old_service = find( $last_config, './/*[local-name()="service" and @type="regular_testing"]', 1 );
     
    return 0 if not $force_run and $old_service and $old_service->toString eq $service->toString;
    
    $self->load_encoded( { service => $service } );
    
    my $regtest_conf = perfSONAR_PS::NPToolkit::Config::RegularTesting->new();
    $regtest_conf->init( { 
            perfsonarbuoy_conf_template => $self->{PERFSONARBUOY_CONF_TEMPLATE},
            perfsonarbuoy_conf_file     => $self->{PERFSONARBUOY_CONF_FILE},
            pinger_landmarks_file       => $self->{PINGER_LANDMARKS_CONF_FILE},
            local_port_ranges           => $self->{LOCAL_PORT_RANGES},
            tests                       => $self->{TESTS},
        } );
    
    $regtest_conf->save( { restart_services => 1 });
    
    # for now, we never change the node config
    return 0; 
}

# This is adapted from perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting
# The two handlers should probably be the same module, or have an 'utils' module.
sub load_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    $self->{TESTS} = {};
    $self->{LOCAL_PORT_RANGES} = {};
    
    my $service = $parameters->{service};
    
    foreach my $port_range ( $service->getChildrenByTagNameNS( RTEST_PSCONFIG_NS, "localPortRange" ) ) {
        my $test_type = $port_range->getAttribute( "testType" );
        my $min_port  = $port_range->getAttribute( "minPort" );
        my $max_port  = $port_range->getAttribute( "maxPort" );
        
        $self->{LOCAL_PORT_RANGES}->{$test_type}->{min_port} = $min_port;
        $self->{LOCAL_PORT_RANGES}->{$test_type}->{max_port} = $max_port;
    }
    
    foreach my $test ( $service->getChildrenByTagNameNS( RTEST_PSCONFIG_NS, "test" ) ) {
        my $id          = $test->getAttribute( "id" );
        my $type        = $test->getAttribute( "type" );
        my $mesh_type   = extract_first( $test, "meshType", RTEST_PSCONFIG_NS, 1 );
        my $name        = extract_first( $test, "name", RTEST_PSCONFIG_NS, 0, 1 );
        my $description = extract_first( $test, "description", RTEST_PSCONFIG_NS, 0, 1 );
        
        my %parameters = ();
        foreach my $param ( $test->getElementsByTagNameNS( RTEST_PSCONFIG_NS, "parameter" ) ) {
            $parameters{ $param->getAttribute( "name" ) } = extract( $param, 0, 1 );
        }
        
        my %members = ();
        foreach my $member (  $test->getElementsByTagNameNS( RTEST_PSCONFIG_NS, "member" ) ) {
            $members{ $member->getAttribute( "id" ) } = {
                address     => extract_first( $member, "address", RTEST_PSCONFIG_NS, 1 ),
                name        => extract_first( $member, "name", RTEST_PSCONFIG_NS, 0, 1 ),
                port        => extract_first( $member, "port", RTEST_PSCONFIG_NS, 1 ),
                description => extract_first( $member, "description", RTEST_PSCONFIG_NS, 0, 1 ),
                sender      => extract_first( $member, "sender", RTEST_PSCONFIG_NS, 1 ),
                receiver    => extract_first( $member, "receiver", RTEST_PSCONFIG_NS, 1 ),
            };
        }
        
        $self->{TESTS}->{ $id } = {
            id          => $id,
            type        => $type,
            name        => $name,
            mesh_type   => $mesh_type,
            description => $description,
            parameters  => \%parameters,
            members     => \%members,
        };
    }
    
    return 0;    
}

1;
__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::pSConfig::Handlers::Base>

=cut
