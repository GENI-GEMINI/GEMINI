package perfSONAR_PS::LSRegistrationDaemon::Base;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Base - The Base class from which all LS
Registration Agents inherit.

=head1 DESCRIPTION

This module provides the Base for all the LS Registration Agents. It includes
most of the common components, like service checking, LS message construction
and LS registration. The Agents implement the functions specific to them, like
service status checking or event type.

=cut

use strict;
use warnings;

our $VERSION = 3.1;

use Log::Log4perl qw/get_logger/;

use perfSONAR_PS::Utils::DNS qw(reverse_dns);
use perfSONAR_PS::Client::LS;

use fields 'CONF', 'STATUS', 'LOGGER', 'KEY', 'NEXT_REFRESH', 'LS_CLIENT';

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=cut

=head2 new()

This call instantiates new objects. The object's "init" function must be called
before any interaction can occur.

=cut

sub new {
    my $class = shift;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );

    return $self;
}

=head2 init($self, $conf)

This function initializes the object according to the configuration options set
in the $conf hash. It allocates an LS client, and sets its status to
"UNREGISTERED".

=cut

sub init {
    my ( $self, $conf ) = @_;

    $self->{CONF}   = $conf;
    $self->{STATUS} = "UNREGISTERED";
    $self->{LS_CLIENT} = perfSONAR_PS::Client::LS->new( { instance => $conf->{ls_instance} } );

    if ($self->{CONF}->{require_site_name} and not $self->{CONF}->{site_name}) {
    	$self->{LOGGER}->error("site_name is a required configuration option");
    	return -1;
    }

    if ($self->{CONF}->{require_site_location} and not $self->{CONF}->{site_location}) {
    	$self->{LOGGER}->error("site_location is a required configuration option");
    	return -1;
    }

    return 0;
}

=head2 service_name ($self)

This internal function generates the name to register this service as. It calls
the object-specific function "type" when creating the function.

=cut

sub service_name {
    my ( $self ) = @_;

    if ( $self->{CONF}->{service_name} ) {
        return $self->{CONF}->{service_name};
    }

    my $retval = q{};
    if ( $self->{CONF}->{site_name} ) {
        $retval .= $self->{CONF}->{site_name} . " ";
    }
    $retval .= $self->type();

    return $retval;
}

=head2 service_node ($self)

For now returns the configured node id or undef if not configured.

=cut

sub service_node {
    my ( $self ) = @_;

    if ( exists $self->{CONF}->{node_id} and $self->{CONF}->{node_id} ) {
        return $self->{CONF}->{node_id};
    }

    return undef;
}

=head2 service_name ($self)

This internal function generates the human-readable description of the service
to register. It calls the object-specific function "type" when creating the
function.

=cut

sub service_desc {
    my ( $self ) = @_;

    if ( $self->{CONF}->{service_description} ) {
        return $self->{CONF}->{service_description};
    }

    my $retval = $self->type();
    if ( $self->{CONF}->{site_name} ) {
        $retval .= " at " . $self->{CONF}->{site_name};
    }

    if ( $self->{CONF}->{site_location} ) {
        $retval .= " in " . $self->{CONF}->{site_location};
    }

    return $retval;
}

=head2 refresh ($self)

This function is called by the daemon. It checks if the service is up, and if
so, checks if it should regster the service or send a keepalive to the Lookup
Service. If not, it unregisters the service from the Lookup Service.

=cut

sub refresh {
    my ( $self ) = @_;

    if ( $self->{STATUS} eq "BROKEN" ) {
        $self->{LOGGER}->error( "Refreshing misconfigured service: ".$self->service_desc );
        return;
    }

    $self->{LOGGER}->debug( "Refreshing: " . $self->service_desc );

    if ( $self->is_up ) {
        $self->{LOGGER}->debug( "Service is up" );
        if ( $self->{STATUS} ne "REGISTERED" ) {
            $self->{LOGGER}->info( "Service '".$self->service_desc."' is up, registering" );
            $self->register();
        }
        elsif ( time >= $self->{NEXT_REFRESH} ) {
            $self->{LOGGER}->info( "Service '".$self->service_desc."' is up, refreshing registration" );
            $self->keepalive();
        }
        else {
            $self->{LOGGER}->debug( "No need to refresh" );
        }
    }
    elsif ( $self->{STATUS} eq "REGISTERED" ) {
        $self->{LOGGER}->info( "Service '".$self->service_desc."' is down, unregistering" );
        $self->unregister();
    }
    else {
        $self->{LOGGER}->info( "Service '".$self->service_desc."' is down" );
    }

    return;
}

=head2 register ($self)

This function is called by the refresh function. It creates an XML description
of the service. It then registers that service and saves the KEY for when a
keepalive needs to be done.

=cut

sub register {
    my ( $self ) = @_;

    my $addresses = $self->get_service_addresses();

    my @metadata = ();
    my %service  = ();
    $service{nonPerfSONARService} = 1;
    $service{name}                = $self->service_name();
    $service{description}         = $self->service_desc();
    $service{type}                = $self->service_type();
    $service{node}                = $self->service_node();
    $service{addresses}           = $addresses;

    my $ev       = $self->event_type();
    my $projects = $self->{CONF}->{site_project};

    my $node_addresses = $self->get_node_addresses();

    my $md = q{};
    $md .= "<nmwg:metadata id=\"" . int( rand( 9000000 ) ) . "\">\n";
    $md .= "  <nmwg:subject>\n";
    $md .= $self->create_node( $node_addresses );
    $md .= "  </nmwg:subject>\n";
    $md .= "  <nmwg:eventType>$ev</nmwg:eventType>\n";
    if ( $projects ) {
        $md .= "  <nmwg:parameters>\n";
        if ( ref( $projects ) eq "ARRAY" ) {
            foreach my $project ( @$projects ) {
                $md .= "    <nmwg:parameter name=\"keyword\">project:" . $project . "</nmwg:parameter>\n";
            }
        }
        else {
            $md .= "    <nmwg:parameter name=\"keyword\">project:" . $projects . "</nmwg:parameter>\n";
        }
        $md .= "  </nmwg:parameters>\n";
    }
    $md .= "</nmwg:metadata>\n";

    push @metadata, $md;

    my $res = $self->{LS_CLIENT}->registerRequestLS( service => \%service, data => \@metadata );
    if ( $res and $res->{"key"} ) {
        $self->{LOGGER}->debug( "Registration succeeded with key: " . $res->{"key"} );
        $self->{STATUS}       = "REGISTERED";
        $self->{KEY}          = $res->{"key"};
        $self->{NEXT_REFRESH} = time + $self->{CONF}->{"ls_interval"};
    }
    else {
        my $error;
        if ( $res and $res->{error} ) {
            $self->{LOGGER}->error( "Problem registering service. Will retry full registration next time: " . $res->{error} );
        }
        else {
            $self->{LOGGER}->error( "Problem registering service. Will retry full registration next time." );
        }
    }

    return;
}

=head2 keepalive ($self)

This function is called by the refresh function. It uses the saved KEY from the
Lookup Service registration, and sends a refresh to the Lookup Service.

=cut

sub keepalive {
    my ( $self ) = @_;

    my $res = $self->{LS_CLIENT}->keepaliveRequestLS( key => $self->{KEY} );
    if ( $res->{eventType} and $res->{eventType} ne "success.ls.keepalive" ) {
        $self->{NEXT_REFRESH} = time + $self->{CONF}->{"ls_interval"};
    }
    else {
        $self->{STATUS} = "UNREGISTERED";
        $self->{LOGGER}->error( "Couldn't send Keepalive. Will send full registration next time." );
    }

    return;
}

=head2 unregister ($self)

This function is called by the refresh function. It uses the saved KEY from the
Lookup Service registration, and sends an unregister request to the Lookup
Service.

=cut

sub unregister {
    my ( $self ) = @_;

    $self->{LS_CLIENT}->deregisterRequestLS( key => $self->{KEY} );
    $self->{STATUS} = "UNREGISTERED";

    return;
}

=head2 create_node ($self, $addresses)

This internal function is called by the register function. It uses the passed
in set of addresses to construct the node that is registered along with the
lookup service registration.

=cut

sub create_node {
    my ( $self, $addresses ) = @_;
    my $node = q{};

    my $nmtb  = "http://ogf.org/schema/network/topology/base/20070828/";
    my $nmtl3 = "http://ogf.org/schema/network/topology/l3/20070828/";

    $node .= "<nmtb:node xmlns:nmtb=\"$nmtb\" xmlns:nmtl3=\"$nmtl3\">\n";
    foreach my $addr ( @$addresses ) {
        my $name = reverse_dns( $addr->{value} );
        if ( $name ) {
            $node .= " <nmtb:name type=\"dns\">$name</nmtb:name>\n";
        }
    }

    foreach my $addr ( @$addresses ) {
        $node .= " <nmtl3:port>\n";
        $node .= "   <nmtl3:address type=\"" . $addr->{type} . "\">" . $addr->{value} . "</nmtl3:address>\n";
        $node .= " </nmtl3:port>\n";
    }
    $node .= "</nmtb:node>\n";

    return $node;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<perfSONAR_PS::Utils::DNS>,
L<perfSONAR_PS::Client::LS>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Base.pm 4015 2010-04-07 16:04:22Z aaron $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
