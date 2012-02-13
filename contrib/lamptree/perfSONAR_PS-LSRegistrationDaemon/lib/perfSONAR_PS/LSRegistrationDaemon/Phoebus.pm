package perfSONAR_PS::LSRegistrationDaemon::Phoebus;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::Phoebus - The Phoebus class provides checks for
Phoebus services.

=head1 DESCRIPTION

This module provides the request functions to check an Phoebus service, and the
information necessary for the Base module to construct an Phoebus service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 5006;

=head2 init($self, $conf)

This function doesn't yet read the Phoebus configuration file, so it simply
sets the default port values unless it has been set in the config file.

=cut

sub init {
    my ( $self, $conf ) = @_;

    my $port = $conf->{port};
    if ( not $port ) {
        $conf->{port} = DEFAULT_PORT;
    }

    return $self->SUPER::init( $conf );
}

=head2 type($self)

Returns the human readable description of the service "Phoebus Gateway".

=cut

sub type {
    my ( $self ) = @_;

    return "Phoebus Gateway";
}

=head2 service_type($self)

Returns the Phoebus service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "phoebus";
}

=head2 event_type($self)

Returns the Phoebus event type.

=cut

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/phoebus/1.0";
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::LSRegistrationDaemon::TCP_Service>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Phoebus.pm 2708 2009-04-03 13:39:02Z zurawski $

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
