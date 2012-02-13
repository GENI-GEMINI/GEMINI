package perfSONAR_PS::LSRegistrationDaemon::Ping;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Ping - The Ping class provides checks for
Ping responders.

=head1 DESCRIPTION

This module provides the request functions to check a service, and the
information necessary for the Base module to construct a ping service
instance. It is just a slim wrapper over the ICMP_Service module.

=cut

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::LSRegistrationDaemon::ICMP_Service';

=head2 type($self)

Returns the human readable description of the service "Ping Responder".

=cut

sub type {
    my ( $self ) = @_;

    return "Ping Responder";
}

=head2 service_type($self)

Returns the ping service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "ping";
}

=head2 event_type($self)

Returns the ping event type.

=cut

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/ping/1.0";
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::LSRegistrationDaemon::ICMP_Service>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Ping.pm 2708 2009-04-03 13:39:02Z zurawski $

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
