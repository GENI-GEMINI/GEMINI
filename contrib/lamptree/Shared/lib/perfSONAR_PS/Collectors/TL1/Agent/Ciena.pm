package perfSONAR_PS::Collectors::TL1::Agent::Ciena;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Collectors::TL1::Agent::Ciena

=head1 DESCRIPTION

TBD

=cut

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use perfSONAR_PS::Utils::ParameterValidation;

use base 'perfSONAR_PS::Collectors::TL1::Agent::Base';

=head2 new($class)

TBD

=cut

sub new {
    my ( $class ) = @_;

    my $self = fields::new( $class );
    return;
}

=head2 init($self, $conf)

TBD

=cut

sub init {
    my ( $self, $conf ) = @_;

    unless ( $conf->{PORT} ) {
        $conf->{PORT} = 10201;
    }
    $self->SUPER::init( $conf );
    return $self;
}

=head2 run($self)

TBD

=cut

sub run {
    my ( $self ) = @_;
    return;
}

1;

__END__

=head1 SEE ALSO

L<Params::Validate>, L<Log::Log4perl>,
L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Ciena.pm 2640 2009-03-20 01:21:21Z zurawski $

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
