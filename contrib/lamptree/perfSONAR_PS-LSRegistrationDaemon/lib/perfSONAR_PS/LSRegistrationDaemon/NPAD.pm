package perfSONAR_PS::LSRegistrationDaemon::NPAD;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::NPAD - The NPAD class provides checks for
NPAD services.

=head1 DESCRIPTION

This module provides the request functions to check an NPAD service, and the
information necessary for the Base module to construct an NPAD service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 8200;

=head2 init($self, $conf)

This function reads the NPAD configuration file (if appropriate), and then
passes the appropriate address and port to the TCP service init routines.

=cut

sub init {
    my ( $self, $conf ) = @_;

    my $res;
    if ( $conf->{config_file} ) {
        my $res = read_npad_config( $conf->{config_file} );
        if ( $res->{error} ) {
            $self->{LOGGER}->error( "Problem reading npad configuation: " . $res->{error} );
            $self->{STATUS} = "BROKEN";
            return -1;
        }
    }
    else {
        my %tmp = ();
        $res = \%tmp;
    }

    if ( not $conf->{port} and not $res->{port} ) {
        $conf->{port} = DEFAULT_PORT;
    }
    elsif ( not $conf->{port} ) {
        $conf->{port} = $res->{port};
    }

    return $self->SUPER::init( $conf );
}

=head2 read_npad_config($file)

This function reads the NPAD configuration file and returns the address and
port that the service listens on if set.

=cut

sub read_npad_config {
    my ( $file ) = @_;

    my %conf;

    my $port;

    my $FH;
    open( $FH, "<", $file ) or return \%conf;
    while ( <$FH> ) {
        if ( /key="webPort".*value="\([^"]\)"/ ) {
            $port = $1;
        }
    }
    close( $FH );

    $conf{port} = $port;

    return \%conf;
}

=head2 get_service_addresses ($self)

This function returns the list of addresses for this service. This overrides
the TCP_Service get_service_addresses function so that NPAD URLs are returned as
URLs.

=cut

sub get_service_addresses {
    my ( $self ) = @_;

    # we override the TCP_Service addresses function so that we can generate
    # URLs.

    my @addresses = ();

    foreach my $addr ( @{ $self->{ADDRESSES} } ) {
        my $uri;

        $uri = "http://";
        if ( $addr =~ /:/ ) {
            $uri .= "[$addr]";
        }
        else {
            $uri .= "$addr";
        }

        $uri .= ":" . $self->{PORT};

        my %addr = ();
        $addr{"value"} = $uri;
        $addr{"type"}  = "url";

        push @addresses, \%addr;
    }

    return \@addresses;
}

=head2 type($self)

Returns the human readable description of the service "NPAD Server".

=cut

sub type {
    my ( $self ) = @_;

    return "NPAD Server";
}

=head2 service_type($self)

Returns the NPAD service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "npad";
}

=head2 event_type($self)

Returns the NPAD event type.

=cut

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/npad/1.0";
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

$Id: NPAD.pm 2708 2009-04-03 13:39:02Z zurawski $

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
