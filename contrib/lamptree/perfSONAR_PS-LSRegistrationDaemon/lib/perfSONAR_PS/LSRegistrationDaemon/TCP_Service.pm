package perfSONAR_PS::LSRegistrationDaemon::TCP_Service;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::TCP_Service - The TCP_Service class
provides a simple sub-class for checking if generic TCP services are running.

=head1 DESCRIPTION

This module is meant to be inherited by other classes that define the TCP
services. It defines the function get_service_addresses, get_node_addresses and
a simple is_up routine that checks it can connect to the service with a simple
TCP connect.

=cut

use strict;
use warnings;

use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);
use perfSONAR_PS::Utils::Host qw(get_ips);

our $VERSION = 3.1;

use base 'perfSONAR_PS::LSRegistrationDaemon::Base';

use fields 'ADDRESSES', 'PORT';

use IO::Socket;
use IO::Socket::INET6;
use IO::Socket::INET;

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
            $addr_map{$addr} = 1;

            #            my @addrs = resolve_address($addr);
            #            foreach my $addr (@addrs) {
            #                $addr_map{$addr} = 1;
            #            }
        }

        @addresses = keys %addr_map;
    }
    else {
        @addresses = get_ips();
    }

    $self->{ADDRESSES} = \@addresses;

    if ( $conf->{port} ) {
        $self->{PORT} = $conf->{port};
    }

    return $self->SUPER::init( $conf );
}

=head2 is_up ($self)

This function uses IO::Socket::INET or IO::Socket::INET6 to make a TCP
connection to the addresses and ports. If it can connect to any of them, it
returns that the service is up. If not, it returns that the service is down.

=cut

sub is_up {
    my ( $self ) = @_;

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $sock;

        $self->{LOGGER}->debug( "Connecting to: " . $addr . ":" . $self->{PORT} );

        if ( $addr =~ /:/ ) {
            $sock = IO::Socket::INET6->new( PeerAddr => $addr, PeerPort => $self->{PORT}, Proto => 'tcp', Timeout => 5 );
        }
        else {
            $sock = IO::Socket::INET->new( PeerAddr => $addr, PeerPort => $self->{PORT}, Proto => 'tcp', Timeout => 5 );
        }

        if ( $sock ) {
            $sock->close;

            return 1;
        }
    }

    return 0;
}

=head2 get_service_addresses ($self)

This function returns the list of addresses for the service is running on.

=cut

sub get_service_addresses {
    my ( $self ) = @_;

    my @addresses = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $uri;

        my $dns = reverse_dns( $addr );

        $uri = "tcp://";
		if ( $dns ) {
			$uri .= "$dns";
        }
        elsif ( $addr =~ /:/ ) {
            $uri .= "[$addr]";
        }
        else {
            $uri .= "$addr";
        }

        $uri .= ":" . $self->{PORT};

        my %addr = ();
        $addr{"value"} = $uri;
        $addr{"type"}  = "uri";

        push @addresses, \%addr;
    }

    return \@addresses;
}

=head2 get_service_addresses ($self)

This function returns the list of addresses for the service is running on.

=cut

sub get_node_addresses {
    my ( $self ) = @_;

    my @addrs = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        unless ( $addr =~ /:/ or $addr =~ /\d+\.\d+\.\d+\.\d+/ ) {

            # it's probably a hostname, try looking it up.
        }

        if ( $addr =~ /:/ ) {
            my %addr = ();
            $addr{"value"} = $addr;
            $addr{"type"}  = "ipv6";
            push @addrs, \%addr;
        }
        elsif ( $addr =~ /\d+\.\d+\.\d+\.\d+/ ) {
            my %addr = ();
            $addr{"value"} = $addr;
            $addr{"type"}  = "ipv4";
            push @addrs, \%addr;
        }
    }

    return \@addrs;
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Utils::DNS>,L<perfSONAR_PS::Utils::Host>,
L<perfSONAR_PS::LSRegistrationDaemon::Base>,L<IO::Socket>,
L<IO::Socket::INET>,L<IO::Socket::INET6>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: TCP_Service.pm 2708 2009-04-03 13:39:02Z zurawski $

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
