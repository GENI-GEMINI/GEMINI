package perfSONAR_PS::LSRegistrationDaemon::ICMP_Service;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::ICMP_Service - The ICMP_Service class
provides a simple sub-class for checking if ICMP services are running.

=head1 DESCRIPTION

This module is meant to be inherited by other classes that define the ICMP
services. It defines the function get_service_addresses, get_node_addresses and
a simple is_up routine that checks if a service is responding to pings.
=cut

use strict;
use warnings;

our $VERSION = 3.1;

use Net::Ping;

use perfSONAR_PS::Utils::DNS qw(reverse_dns resolve_address);
use perfSONAR_PS::Utils::Host qw(get_ips);

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';

use fields 'ADDRESSES';

=head2 init($self, $conf)

This function checks if an address has been configured, if not, it reads the
local addresses, and uses those to perform the later checks.

=cut

sub init {
    my ( $self, $conf ) = @_;

    unless ( $conf->{address} ) {
        $self->{LOGGER}->warn( "No address specified, assuming local service" );
    }

    my @addresses;

    if ( $conf->{address} ) {
        @addresses = ();

        my @tmp = ();
        if ( ref( $conf->{address} ) eq "ARRAY" ) {
            @tmp = @{ $conf->{address} };
        }
        else {
            push @tmp, $conf->{address};
        }

        my %addr_map = ();
        foreach my $addr ( @tmp ) {
            my @addrs = resolve_address( $addr );
            foreach my $addr ( @addrs ) {
                $addr_map{$addr} = 1;
            }
        }

        @addresses = keys %addr_map;
    }
    else {
        @addresses = get_ips();
    }

    $self->{ADDRESSES} = \@addresses;

    return $self->SUPER::init( $conf );
}

=head2 get_service_addresses ($self)

This function returns the list of addresses for this service.

=cut

sub get_service_addresses {
    my ( $self ) = @_;

    my @addrs = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my %addr = ();
        $addr{"value"} = $addr;

        # XXX: this should check if it's a hostname as well

        if ( $addr =~ /:/ ) {
            $addr{"type"} = "ipv6";
        }
        else {
            $addr{"type"} = "ipv4";
        }

        push @addrs, \%addr;
    }

    return \@addrs;
}

=head2 get_node_addresses ($self)

This function returns the list of addresses for the node the service is running on.

=cut

sub get_node_addresses {
    my ( $self ) = @_;

    return $self->get_service_addresses();
}

=head2 is_up ($self)

This function uses Net::Ping::External to ping the service. If any of the
addresses match, it returns true, if not, it returns false.

=cut

sub is_up {
    my ( $self ) = @_;

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        if ( $addr =~ /:/ ) {
            next;
        }
        else {
            $self->{LOGGER}->debug( "Pinging: " . $addr );
            my $ping = Net::Ping->new( "external" );
            if ( $ping->ping( $addr, 1 ) ) {
                return 1;
            }
        }
    }

    return 0;
}

1;

__END__

=head1 SEE ALSO

L<Net::Ping>, L<Net::Ping::External>, L<perfSONAR_PS::Utils::DNS>,
L<perfSONAR_PS::Utils::Host>, L<perfSONAR_PS::LSRegistrationDaemon::Base>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: ICMP_Service.pm 2708 2009-04-03 13:39:02Z zurawski $

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
