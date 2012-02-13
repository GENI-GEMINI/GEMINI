package perfSONAR_PS::Services::pSConfig::Handlers::PingER;

use base 'perfSONAR_PS::Services::pSConfig::Handlers::Base';

use fields 'LOGGER', 'RC_FILE', 'LANDMARKS_FILE';

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

TODO:

=head1 DESCRIPTION

TODO:

=cut

use Readonly;
use Log::Log4perl qw(get_logger);
use perfSONAR_PS::Common qw(extract find mergeHash);

use constant PSCONFIG_PINGER_NS     => 'http://ogf.org/schema/network/topology/psconfig/pinger/20100813';
# XXX: The following constants should really be on a PingER module
use constant DEFAULT_LANDMARKS_FILE => '/opt/perfsonar_ps/PingER/etc/pinger-landmarks.xml';

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=head2 init($self)

TODO:

=cut

sub init {
    my ( $self ) = @_;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::pSConfig::Handlers::PingER" );
    
    $self->{CONF} = mergeHash( $self->{CONF}, $self->{CONF}->{"pinger"}, {} ) if exists $self->{CONF}->{"pinger"};
    
    if ( exists $self->{CONF}->{"landmarks_file"} and $self->{CONF}->{"landmarks_file"} ) {
        $self->{LANDMARKS_FILE} = $self->{CONF}->{"landmarks_file"};
    }
    else {
        $self->{LANDMARKS_FILE} = DEFAULT_LANDMARKS_FILE;
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
    
    my $service = find( $node, './/*[local-name()="service" and @type="pinger"]', 1 );
    
    unless ( $service ) {
        $self->{LOGGER}->error( "Couldn't find pinger configuration entry, skipping." );
        return 0;
    }
    
    # Something completely unrelated on the node config could have changed,
    # so we try to check if our pinger config did or not (note that this
    # way of checking will treat any textual change as significant).
    my $old_service = find( $last_config, './/*[local-name()="service" and @type="pinger"]', 1 );
     
    return 0 if not $force_run and $old_service and $old_service->toString eq $service->toString;
    
    # value defines if field value should be cleaned (see extract)
    my %landmark_fields = (
        domain              => 0,
        node                => 0,
        hostname            => 1,
        ip                  => 1,
        description         => 0,
        packetSize          => 1,
        count               => 1,
        packetInterval      => 1,
        ttl                 => 1,
        measurementPeriod   => 1,
        measurementOffset   => 1,
        project             => 0
    );
    
    my @landmarks = ();
    my $landmarks_xml = find( $service, './/*[local-name()="landmark" and namespace-uri()="' . PSCONFIG_PINGER_NS . '"]', 0 );
    for my $mark_node ( $landmarks_xml->get_nodelist ) {
        my %mark = ();
        
        for my $field ( keys %landmark_fields ) {
            my $value = extract( find( $mark_node, ".//*[local-name()='$field']", 1 ), $landmark_fields{ $field } );
            
            if ( not $landmark_fields{ $field } and $value ) {
                # trim the value
                $value =~ s/^\s*//;
                $value =~ s/\s*$//;
            }
            
            $mark{ $field } = $value;
        }
        push @landmarks, \%mark;
    }
    
    # TODO: update() should check if any of the configuration changed,
    #   so that we don't keep restarting the service every time we think
    #   the xml from UNIS changed.
    $self->update( \@landmarks );
    
    # restart service
    $self->manageService( "false" );
    $self->manageService( "true" );
    
    # for now, we never change the node config
    return 0; 
}

#
# The following is adapted from PingER's create_landmarks.pl by Maxim Grigoriev.
# TODO: should be moved somewhere else (e.g. perfSONAR_PS::Services::MP::Config::PingER)
#
use Socket;
use IO::File;
use perfSONAR_PS::Utils::DNS qw/reverse_dns resolve_address/;

use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Name';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::HostName';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Description';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters::Parameter';
use aliased 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtl3::Topology::Domain::Node::Port';

use constant URNBASE => 'urn:ogf:network';

Readonly::Hash our %DEFAULT_VALUES => (
    description       => '',
    packetSize        => '1000',
    count             => '10',
    packetInterval    => '1',
    ttl               => '255',
    measurementPeriod => '60',
    measurementOffset => '0'
);

sub update {
    my ( $self, $marks ) = @_;
    my $landmark_obj;
    
    # Right now we just trump the landmarks file with the new config
    if ( 0 ) {
        if (-e $self->{LANDMARKS_FILE} ) {
            eval {
                local ( $/ );
                my $fd_in = new IO::File( $self->{LANDMARKS_FILE} ) or die " Failed to open landmarks $self->{LANDMARKS_FILE} ";
                my $text = <$fd_in>;
                $landmark_obj = Topology->new( { xml => $text } );
                $fd_in->close;
            };
            if ( $@ ) {
                $self->{LOGGER}->error( " Failed to load landmarks $self->{LANDMARKS_FILE} $@" );
                return -1;
            }
        }
        else {
            $landmark_obj = Topology->new();
        }
    } else {
        $landmark_obj = Topology->new();
    }
    
    my %dns_cache         = ();
    my %reverse_dns_cache = ();
    my $num               = 0;
    foreach my $mark ( @{ $marks } ) {
        unless ( $mark->{domain} && $mark->{node} && ( $mark->{hostname} || $mark->{ip} ) ) {
            $self->{LOGGER}->error( " Skipping Malformed row: domain=$mark->{domain}  node=$mark->{node} hostname=$mark->{hostname} ip=$mark->{ip}" );
            next;
        }
        check_row( $mark, \%dns_cache, \%reverse_dns_cache );
        my $domain_id  = URNBASE . ":domain=$mark->{domain}";
        my $domain_obj = $landmark_obj->getDomainById( $domain_id );
        unless ( $domain_obj ) {
            $domain_obj = Domain->new( { id => $domain_id } );
            $landmark_obj->addDomain( $domain_obj );
        }
        my $node_id  = "$domain_id:node=$mark->{node}";
        my $node_obj = $domain_obj->getNodeById( $node_id );
        $domain_obj->removeNodeById( $node_id ) if ( $node_obj );
        eval {
            my $project_param;
            
            if ( $mark->{project} ) {
                $project_param = '     <nmwg:parameter name="project">$mark->{project}</nmwg:parameter> ';
            }
            else {
                $project_param = '';
            }
            
            $node_obj = Node->new(
                {
                    id   => $node_id,
                    name => Name->new( { type => 'string', text => $mark->{node} } ),
                    hostName    => HostName->new(    { text => $mark->{hostname} } ),
                    description => Description->new( { text => $mark->{description} } ),
                    port        => Port->new(
                        {
                            #
                            # GFR: We don't know the port id; to assume that it
                            #   is uses the IP address can be wrong, so use *.
                            #
                            xml => qq{
<nmtl3:port xmlns:nmtl3="http://ogf.org/schema/network/topology/l3/20070707/" id="$node_id:port=*">
    <nmtl3:ipAddress type="IPv4">$mark->{ip}</nmtl3:ipAddress>
</nmtl3:port>
}
                        }
                    ),
                    parameters => Parameters->new(
                        {
                            xml => qq{
<nmwg:parameters xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/" id="paramid$num">
     <nmwg:parameter name="packetSize">$mark->{packetSize}</nmwg:parameter>
     <nmwg:parameter name="count">$mark->{count}</nmwg:parameter>
     <nmwg:parameter name="packetInterval">$mark->{packetInterval}</nmwg:parameter>
     <nmwg:parameter name="ttl">$mark->{ttl}</nmwg:parameter> 
     <nmwg:parameter name="measurementPeriod">$mark->{measurementPeriod}</nmwg:parameter>  
     <nmwg:parameter name="measurementOffset">$mark->{measurementOffset}</nmwg:parameter>
$project_param
 </nmwg:parameters>
}
                        }
                    )
                }
            );
            $domain_obj->addNode( $node_obj );
            $num++;
        };
        if ( $@ ) {
            $self->{LOGGER}->error( " Node create failed $@" );
            return -1;
        }
    }
    
    eval {
        my $fd = new IO::File( ">$self->{LANDMARKS_FILE}" ) or die( "Failed to open file $self->{LANDMARKS_FILE}: " . $! );
        print $fd $landmark_obj->asString;
        $fd->close;
    };
    if ( $@ ) {
        $self->{LOGGER}->error( "Failed to store new xml landmarks file $@ " );
        return -1;
    }
    
    return 0;
}

=head2 check_row 

     set missing values from defaults, resolve DNS name or IP address

=cut

sub check_row {
    my ( $mark, $dns_cache_h, $reverse_dns_cache_h ) = @_;
    unless ( $mark->{hostname} ) {
        unless ( $reverse_dns_cache_h->{ $mark->{ip} } ) {
            $mark->{hostname} = reverse_dns( $mark->{ip} );
            $reverse_dns_cache_h->{ $mark->{ip} } = $mark->{hostname};
        }
        else {
            $mark->{hostname} = $reverse_dns_cache_h->{ $mark->{ip} };
        }
    }
    unless ( $mark->{ip} ) {
        unless ( $dns_cache_h->{ $mark->{hostname} } ) {
            #
            # GFR: Net::DNS::Resolver does not use /etc/hosts. This is a big
            #   problem in GENI (was there a reason for not using gethostbyname?).
            #
            #( $mark->{ip} ) = resolve_address( $mark->{hostname} );
            
            my $packed_ip = gethostbyname( $mark->{hostname} );
            if (defined $packed_ip) {
                $mark->{ip} = inet_ntoa($packed_ip);
                $dns_cache_h->{ $mark->{hostname} } = $mark->{ip};
            }
        }
        else {
            $mark->{ip} = $dns_cache_h->{ $mark->{hostname} };
        }
    }
    foreach my $key ( keys %DEFAULT_VALUES ) {
        $mark->{ $key } = $DEFAULT_VALUES{ $key } unless $mark->{ $key };
    }
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::pSConfig::Handlers::Base>

=cut
