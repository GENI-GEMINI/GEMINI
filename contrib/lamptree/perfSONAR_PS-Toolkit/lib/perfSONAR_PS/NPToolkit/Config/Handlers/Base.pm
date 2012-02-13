package perfSONAR_PS::NPToolkit::Config::Handlers::Base;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::Base;

=head1 DESCRIPTION

This module provides the base for all of the NPToolkit::Config modules. The
provided functions are common to all the NPToolkit::Config modules, and must be
over-ridden by them. The semantics of the functions must be the same across all
modules.

=cut

use Log::Log4perl qw(get_logger :nowarn);
use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);

use fields 'SERVICE', 'MODIFIED', 'EMPTY';

use constant PSCONFIG_NS => 'http://ogf.org/schema/network/topology/psconfig/20100716/';

sub new {
    my ( $package, @params ) = @_;
    my $parameters = validate( @params, { saved_state => 0, } );

    my $self = fields::new( $package );

    return $self;
}

=head2 init({ service => 1 })
    Initializes the module.
=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    $self->{SERVICE}  = $parameters->{service};
    $self->{EMPTY}    = 1;
    $self->{MODIFIED} = 1;
    
    return 0;
}

sub load_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    my $service = $parameters->{service};
    
    if ( $service->hasAttribute( "enable" ) and lc( $service->getAttribute( "enable" ) ) eq "true" ) {
        $self->{SERVICE}->{enabled} = 1;
    }
    else {
        $self->{SERVICE}->{enabled} = 0;
    }
    
    $self->{EMPTY}    = 0 if $service->nonBlankChildNodes()->size();
    $self->{MODIFIED} = 0;
    
    return 0;
}

sub update_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    return 0 unless $self->{MODIFIED};
    
    my $service = $parameters->{service};
    
    # Base just updates enabled/disabled.
    if ( $self->{SERVICE}->{enabled} ) {
        $service->setAttribute( "enable", "true" );
    }
    else {
        $service->removeAttribute( "enable" ) if $service->hasAttribute( "enable" );
    }
    
    return 0;
}

sub add_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node_properties => 1, } );
    
    my $node_properties = $parameters->{node_properties};
    
    my $dom = $node_properties->ownerDocument();
    
    my $service = $dom->createElementNS( PSCONFIG_NS, "psconfig:service" );
    $service->setAttribute( "type", $self->{SERVICE}->{type} );
    
    $node_properties->addChild( $service );
    
    $self->update_encoded( { service => $service } );
    
    return $service;
}

sub is_empty {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    return $self->{EMPTY};
}

sub disable {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    return 0 unless $self->{SERVICE}->{enabled};
    
    $self->{SERVICE}->{enabled} = 0;
    $self->{MODIFIED} = 1;
}

sub enable {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    return 0 if $self->{SERVICE}->{enabled};
    
    $self->{SERVICE}->{enabled} = 1;
    $self->{MODIFIED} = 1;
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
