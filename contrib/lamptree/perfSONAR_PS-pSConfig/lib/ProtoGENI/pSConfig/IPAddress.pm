package ProtoGENI::pSConfig::IPAddress;

use base 'perfSONAR_PS::Services::pSConfig::Handlers::Base';

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

TODO:

=head1 DESCRIPTION

TODO:

=cut

use Socket;
use Sys::Hostname;
use Log::Log4perl qw(get_logger);

use perfSONAR_PS::Common qw(extract find mergeHash);
use perfSONAR_PS::Utils::Host qw( get_ips get_ethernet_interfaces get_interface_addresses );

# XXX: Namespaces should be kept in a single module?
use constant UNIS_NS      => 'http://ogf.org/schema/network/topology/unis/20100528/';
use constant PSCONFIG_NS  => 'http://ogf.org/schema/network/topology/psconfig/20100716/';

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=head2 apply($self, $node)

TODO:

=cut

sub apply {
    my ( $self, $node, $last_config, $changed, $first_run, $failed_last ) = @_;
    
    my $force_run = ( $changed or $failed_last or $first_run );
    return 0 unless $force_run;
    
    # Any changes we make to the node must be pushed.
    my $must_push = 0;
    
    my @ips = get_ips;
    
    # First make sure hostnames are correct.
    my $slice_hostname = hostname;
    
    my $found = 0;
    foreach my $address ( $node->getChildrenByTagNameNS( UNIS_NS, "address" ) ) {
        my $type = $address->getAttribute( "type" );
        
        next unless $type and lc $type eq "dns" or lc $type eq "hostname";
        
        my $hostname = extract( $address, 1 );
        
        # Make sure that hostnames resolve to one of our IPs
        my $ip = 0;
        my $packed_ip = gethostbyname( $hostname );
        $ip = inet_ntoa($packed_ip) if (defined $packed_ip);
        
        unless ( grep { /^\Q$ip\E$/ } @ips ) {
            $node->removeChild( $address );
            $must_push = 1;
        }
        
        $found = 1 if ( $hostname eq $slice_hostname );  
    }
    
    unless ( $found ) {
        my $address = $node->addNewChild( UNIS_NS, "address" );
        $address->setAttribute( "type", "dns" );
        $address->appendText( $slice_hostname );
        $must_push = 1;
    }
    
    # Now we check the interfaces; ProtoGENI tends to get these wrong.
    
    # We use MAC addresses as keys and update everything else.
    my %interfaces = ();
    foreach my $iface ( get_ethernet_interfaces( { full_info => 1, } ) ) {
        # Clean MACs to 1a2b3c4d5e6f format.
        $iface->{"mac"} =~ s/://g;
        $iface->{"mac"} = lc $iface->{"mac"};
        
        $interfaces{ $iface->{"mac"} } = $iface;
    }
    
    foreach my $port ( $node->getChildrenByTagNameNS( UNIS_NS, "port" ) ) {
        my $mac = extract( find( $port, "./unis:address[\@type='mac']", 1 ), 1 );
        
        next unless $mac and exists $interfaces{$mac};
        
        my $name = find( $port, "./unis:name", 1 );
        unless ( extract( $name, 1 ) eq $interfaces{$mac}->{"name"} ) {
            $name->removeChildNodes();
            $name->appendText( $interfaces{$mac}->{"name"} );
            $must_push = 1;
        }
        
        my $address = find( $port, "./unis:address[\@type='ipv4']", 1 );
        unless ( extract( $address, 1 ) eq $interfaces{$mac}->{"ipv4"} ) {
            $address->removeChildNodes();
            $address->appendText( $interfaces{$mac}->{"ipv4"} );
            $must_push = 1;
        }
    }
    
    return $must_push;
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::pSConfig::Handlers::Base>

=cut
