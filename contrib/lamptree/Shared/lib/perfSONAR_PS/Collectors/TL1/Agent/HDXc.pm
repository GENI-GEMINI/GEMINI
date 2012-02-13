package perfSONAR_PS::Collectors::TL1::Agent::HDXc;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'AGENT', 'LOGGER', 'AID_TYPE', 'AID', 'COUNTER';

=head1 NAME

perfSONAR_PS::Collectors::TL1::Agent::HDXc

=head1 DESCRIPTION

TBD

=cut

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::Utils::TL1::HDXc;

=head2 new($class, @params)

TBD

=cut

sub new {
    my ( $class, @params ) = @_;

    my $parameters = validateParams(
        @params,
        {
            address  => 0,
            port     => 0,
            username => 0,
            password => 0,
            agent    => 0,
            aid      => 1,
            counter  => 1,
            aid_type => 1,
        }
    );

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( "perfSONAR_PS::Collectors::TL1::Agent::HDXc" );

    # we need to be able to generate a new tl1 agent or reuse an existing one. Not neither.
    if (
        not $parameters->{agent}
        and (  not $parameters->{address}
            or not $parameters->{port}
            or not $parameters->{username}
            or not $parameters->{password} )
        )
    {
        return;
    }

    unless ( exists $parameters->{agent} ) {
        $parameters->{agent} = perfSONAR_PS::Utils::TL1::HDXc->new();
        $parameters->{agent}->initialize(
            username   => $parameters->{username},
            password   => $parameters->{password},
            address    => $parameters->{address},
            port       => $parameters->{port},
            cache_time => 300
        );
    }

    $self->counter( $parameters->{counter} );
    $self->agent( $parameters->{agent} );
    $self->aid( $parameters->{aid} );
    $self->aid_type( $parameters->{aid_type} );

    return $self;
}

=head2 run($self)

TBD

=cut

sub run {
    my ( $self ) = @_;

    if ( exists $self->{AID_TYPE} and $self->{AID_TYPE} eq "line" ) {
        return $self->{AGENT}->getLine_PM( $self->{AID}, $self->{COUNTER} );
    }
    elsif ( exists $self->{AID_TYPE} and $self->{AID_TYPE} eq "sect" ) {
        return $self->{AGENT}->getSect_PM( $self->{AID}, $self->{COUNTER} );
    }
}

=head2 agent($self, $agent)

TBD

=cut

sub agent {
    my ( $self, $agent ) = @_;

    if ( defined $agent and $agent ) {
        $self->{AGENT} = $agent;
    }
    return $self->{AGENT};
}

=head2 counter($self, $counter)

TBD

=cut

sub counter {
    my ( $self, $counter ) = @_;

    if ( defined $counter and $counter ) {
        $self->{COUNTER} = $counter;
    }
    return $self->{COUNTER};
}

=head2 aid($self, $aid)

TBD

=cut

sub aid {
    my ( $self, $aid ) = @_;

    if ( defined $aid and $aid ) {
        $self->{AID} = $aid;
    }
    return $self->{AID};
}

=head2 aid_type($self, $aid_type)

TBD

=cut

sub aid_type {
    my ( $self, $aid_type ) = @_;

    if ( $aid_type and ( $aid_type eq "sect" or $aid_type eq "line" ) ) {
        $self->{AID_TYPE} = $aid_type;
    }
    return $self->{AID_TYPE};
}

1;

__END__

=head1 SEE ALSO

L<Params::Validate>, L<Log::Log4perl>,
L<perfSONAR_PS::Utils::ParameterValidation>, L<perfSONAR_PS::Utils::TL1::HDXc>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: HDXc.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
