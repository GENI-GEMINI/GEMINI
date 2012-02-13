package perfSONAR_PS::LSRegistrationDaemon::BWCTL;

=head1 NAME

perfSONAR_PS::LSRegistrationDaemon::BWCTL - The BWCTL class provides checks for
BWCTL services.

=head1 DESCRIPTION

This module provides the request functions to check a service, and the
information necessary for the Base module to construct a bwctl service
instance.

=cut

use strict;
use warnings;

our $VERSION = 3.1;

use base 'perfSONAR_PS::LSRegistrationDaemon::TCP_Service';

use constant DEFAULT_PORT => 4823;

=head2 init($self, $conf)

This function reads the bwctl configuration file (if appropriate), and then
passes the appropriate address and port to the TCP service init routines.

=cut

sub init {
    my ( $self, $conf ) = @_;

    my $res;
    if ( $conf->{config_file} ) {
        my $bwctl_config = $conf->{config_file};

        $res = read_bwctl_config( $bwctl_config );
        if ( $res->{error} ) {
            $self->{LOGGER}->error( "Problem reading bwctl configuation: " . $res->{error} );
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

    if ( $res->{addr} ) {
        my @tmp_addrs = ();
        push @tmp_addrs, $res->{addr};

        $conf->{address} = \@tmp_addrs;
    }

    return $self->SUPER::init( $conf );
}

=head2 read_bwctl_config($file)

This function reads the bwctl configuration file and returns the address and
port that the service listens on if set.

=cut

sub read_bwctl_config {
    my ( $file ) = @_;

    my %conf = ();

    my $FH;
    open( $FH, "<", $file ) or return \%conf;
    while ( my $line = <$FH> ) {
        $line =~ s/#.*//;     # get rid of any comment on the line
        $line =~ s/^\S+//;    # get rid of any leading whitespace
        $line =~ s/\S+$//;    # get rid of any trailing whitespace

        my ( $key, $value ) = split( /\S+/, $line );
        if ( not $key ) {
            next;
        }

        if ( $value ) {
            $conf{$key} = $value;
        }
        else {
            $conf{$key} = 1;
        }
    }
    close( $FH );

    my $addr_to_parse;

    if ( $conf{"srcnode"} ) {
        $addr_to_parse = $conf{"srcnode"};
    }
    elsif ( $conf{"src_node"} ) {
        $addr_to_parse = $conf{"src_node"};
    }

    my ( $addr, $port );

    if ( $addr_to_parse and $addr_to_parse =~ /(.*):(.*)/ ) {
        $addr = $1;
        $port = $2;
    }

    my %res = ();
    if ( $addr ) {
        $res{addr} = $addr;
    }
    $res{port} = $port;

    return \%res;
}

=head2 type($self)

Returns the human readable description of the service "BWCTL Server".

=cut

sub type {
    my ( $self ) = @_;

    return "BWCTL Server";
}

=head2 type($self)

Returns the bwctl service type.

=cut

sub service_type {
    my ( $self ) = @_;

    return "bwctl";
}

=head2 type($self)

Returns the bwctl event type.

=cut

sub event_type {
    my ( $self ) = @_;

    return "http://ggf.org/ns/nmwg/tools/bwctl/1.0";
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

$Id: BWCTL.pm 2708 2009-04-03 13:39:02Z zurawski $

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
