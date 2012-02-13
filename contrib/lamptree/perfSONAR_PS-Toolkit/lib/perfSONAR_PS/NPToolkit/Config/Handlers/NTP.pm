package perfSONAR_PS::NPToolkit::Config::Handlers::NTP;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::Handlers::NTP;

=head1 DESCRIPTION

TODO:

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Handlers::Base';

use Log::Log4perl qw(get_logger :nowarn);
use Params::Validate qw(:all);

use perfSONAR_PS::Common qw(extract);

use fields 'SERVERS';

use constant NTP_PSCONFIG_NS => 'http://ogf.org/schema/network/topology/psconfig/ntp/20100914/';

=head2 init({ service => 1 })
    Initializes the module.
=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    $self->SUPER::init( @params );
    
    $self->{SERVERS} = {};
    
    return 0;
}

sub load_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    $self->SUPER::load_encoded( @params );
    
    $self->{SERVERS} = ();
    
    foreach my $server ( $parameters->{service}->getChildrenByTagNameNS( NTP_PSCONFIG_NS, "server" ) ) {
        my $address = extract( $server,  1 );
        $self->{SERVERS}->{ $address } = 1;
        $self->{EMPTY} = 0;
    }
    
    return 0;    
}

sub update_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    return 0 unless $self->{MODIFIED};
    
    $self->SUPER::update_encoded( @params );
    
    my $service = $parameters->{service};
    
    # XXX: We replace the whole content. (Not extensible.)
    $service->removeChildNodes();
    my $dom = $service->ownerDocument();
    foreach my $address ( keys %{ $self->{SERVERS} } ) {
        my $server = $dom->createElementNS( NTP_PSCONFIG_NS, "ntp:server" );
        $server->appendTextNode( $address );
        $service->addChild( $server );
    }
    
    return 0;
}

sub set_servers {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { servers => 1, } );
    
    my $modified = 0;
    
    my %servers = map { $_ => 1 } @{ $parameters->{servers} };
    
    foreach my $address ( keys %{ $self->{SERVERS} }) {
        unless ( exists $servers{ $address } ) {
            $modified = 1;
            delete $self->{SERVERS}->{ $address };
        }
    }
    
    foreach my $address ( keys %servers ) {
        unless ( exists $self->{SERVERS}->{ $address } ) {
            $self->{SERVERS}->{$address} = 1;
            $modified = 1;
        }
    }
    
    $self->{MODIFIED} = 1 if $modified;
    
    return $modified;
}

=head2 get_servers({ })
    Returns the list of servers as a hash indexed by address.
=cut

sub get_servers {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{SERVERS};
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
