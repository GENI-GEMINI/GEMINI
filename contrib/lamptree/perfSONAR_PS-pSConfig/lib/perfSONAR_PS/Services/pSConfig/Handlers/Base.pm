package perfSONAR_PS::Services::pSConfig::Handlers::Base;

use fields 'LOGGER', 'CONF', 'UNIS_CLIENT', 'NODE_ID', 'PUSH';

use strict;
use warnings;

use Carp;

our $VERSION = 3.1;

=head1 NAME

TODO:

=head1 DESCRIPTION

TODO:

=cut

=head1 API

The offered API is not meant for external use as many of the functions are
relied upon by internal aspects of the perfSONAR-PS framework.

=cut

=head2 new($class)

This call instantiates new objects.

=cut

sub new {
    my ( $class, $conf, $client, $node_id, $push ) = @_;

    my $self = fields::new( $class );

    if ( defined $conf and $conf ) {
        $self->{CONF} = \%{$conf};
    }

    if ( defined $client and $client ) {
        $self->{UNIS_CLIENT} = $client;
    }

    if ( defined $node_id and $node_id ) {
        $self->{NODE_ID} = $node_id;
    }

    if ( defined $push and $push ) {
        $self->{PUSH} = $push;
    }

    return $self;
}

=head2 init($self)

This function should be implemented by subclasses that need further
configuration.

=cut

sub init {
    my ( $self ) = @_;
    return 0;
}

=head2 apply($self, $node, $last_config, $changed, $failed_last)

TODO:

=cut

sub apply {
    croak "apply is not implemented in perfSONAR_PS::Services::pSConfig::Handlers::Base";
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>

=cut
