package perfSONAR_PS::LSRegistrationDaemon::REDDnet;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::REDDnet - The REDDnet class provides checks for
REDDnet depots.

=head1 DESCRIPTION

This module provides the request functions to check a REDDnet depot, and the
information necessary for the Base module to construct an REDDnet service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 6714;

=head2 init($self, $conf)

This function doesn't yet read the REDDnet configuration file, so it simply
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

Returns the human readable description of the service "REDDnet Depot".

=cut

sub type {
    my ( $self ) = @_;

    return "REDDnet Depot";
}

=head2 service_type($self)

Returns the REDDnet service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "reddnet";
}

=head2 event_type($self)

Returns the REDDnet event type.

=cut

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/reddnet/1.0";
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

$Id: REDDnet.pm 3925 2010-02-25 18:38:56Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2010, Internet2

All rights reserved.

=cut
