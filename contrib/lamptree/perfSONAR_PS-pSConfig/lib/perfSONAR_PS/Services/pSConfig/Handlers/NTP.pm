package perfSONAR_PS::Services::pSConfig::Handlers::NTP;

use base 'perfSONAR_PS::Services::pSConfig::Handlers::Base';

use fields 'NTP_SERVERS', 'NTP_CONF_FILE', 'NTP_CONF_TEMPLATE_FILE', 'KNOWN_SERVERS_FILE';

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

TODO:

=head1 DESCRIPTION

TODO:
TODO: Merge with perfSONAR_PS::NPToolkit::Config::Handlers::NTP

=cut

use Readonly;
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use perfSONAR_PS::Common qw(extract find mergeHash);

use perfSONAR_PS::NPToolkit::Config::NTP;

use constant PSCONFIG_NS      => 'http://ogf.org/schema/network/topology/psconfig/20100716/';
use constant NTP_PSCONFIG_NS  => 'http://ogf.org/schema/network/topology/psconfig/ntp/20100914/';

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=head2 init($self)

TODO:

=cut

sub init {
    my ( $self ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::pSConfig::Handlers::NTP" );
    
    $self->{CONF} = mergeHash( $self->{CONF}, $self->{CONF}->{"ntp"}, {} ) if exists $self->{CONF}->{"ntp"};
    
    if ( exists $self->{CONF}->{"ntp_conf_template_file"} and $self->{CONF}->{"ntp_conf_template_file"} ) {
        $self->{NTP_CONF_TEMPLATE_FILE} = $self->{CONF}->{"ntp_conf_template"};
    }
    
    if ( exists $self->{CONF}->{"ntp_conf_file"} and $self->{CONF}->{"ntp_conf_file"} ) {
        $self->{NTP_CONF_FILE} = $self->{CONF}->{"ntp_conf_file"};
    }
    
    if ( exists $self->{CONF}->{"known_servers_file"} and $self->{CONF}->{"known_servers_file"} ) {
        $self->{KNOWN_SERVERS_FILE} = $self->{CONF}->{"known_servers_file"};
    }
    
    return 0;
}

=head2 apply($self, $node, $last_config, $changed, $first_run, $failed_last)

TODO:

=cut

sub apply {
    my ( $self, $node, $last_config, $changed, $first_run, $failed_last ) = @_;
    
    my $force_run = ( $changed or $failed_last or $first_run );
    return 0 unless $force_run;
    
    my $service = find( $node, './/*[local-name()="service" and namespace-uri()="' . PSCONFIG_NS . '" and @type="ntp"]', 1 );
    
    unless ( $service ) {
        $self->{LOGGER}->warn( "Couldn't find ntp configuration entry, skipping." );
        return 0;
    }
    
    # Something completely unrelated on the node config could have changed,
    # so we try to check if our regular_testing config did or not.
    # TODO: this way of checking will treat any textual change as significant).
    my $old_service = find( $last_config, './/*[local-name()="service" and namespace-uri()="' . PSCONFIG_NS . '" and @type="ntp"]', 1 );
     
    return 0 if not $force_run and $old_service and $old_service->toString eq $service->toString;
    
    $self->load_encoded( { service => $service } );
    
    return 0 unless keys %{ $self->{NTP_SERVERS} };
     
    my $ntp_conf = perfSONAR_PS::NPToolkit::Config::NTP->new();
    $ntp_conf->init( {
            ntp_conf_template => $self->{NTP_CONF_TEMPLATE_FILE},
            known_servers     => $self->{KNOWN_SERVERS_FILE},
            ntp_conf          => $self->{NTP_CONF_FILE},
            ntp_servers       => $self->{NTP_SERVERS},
        } );
    
    my ($status, $res) = $ntp_conf->save( { save_ntp_conf => 1, restart_services => 1 });
    if ( $status != 0 ) {
        $self->{LOGGER}->error( "Error processing NTP service entry: $res" );
        return -1;
    }
    
    # for now, we never change the node config
    return 0; 
}

# This is adapted from perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting
# The two handlers should probably be the same module, or have an 'utils' module.
sub load_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    my $service = $parameters->{service};
    
    foreach my $server ( $parameters->{service}->getChildrenByTagNameNS( NTP_PSCONFIG_NS, "server" ) ) {
        my $address = extract( $server,  1 );
        $self->{NTP_SERVERS}->{ $address } = {
            selected    => 1,
            address     => $address,
            description => "",
        };
    }
    
    return 0;    
}

1;
__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::pSConfig::Handlers::Base>

=cut
