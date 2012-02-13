package perfSONAR_PS::Utils::ParameterValidation;

use strict;
use warnings;

our $VERSION = 3.1;

use base 'Exporter';

=head1 NAME

perfSONAR_PS::Utils::ParameterValidation

=head1 DESCRIPTION

Only use Params::Validate when the logger is set to debug mode.  Performance
testing has revealed that Params::Validate can be costly, especially when called
repeatable functions.  This module wraps the commonly used Params::Validate
functions and only uses them when the logging level is set to DEBUG. 

=cut

our @EXPORT = qw( validateParams validateParamsPos );

our $logger = get_logger( "perfSONAR_PS::Utils::ParameterValidation" );

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger :nowarn);

=head2 validateParams($params, $options)

Wrapper for the 'validate' function in Params::Validate.

=cut

sub validateParams(\@$) {
    my ( $params, $options ) = @_;

    if ( $logger->is_debug() ) {
        my @a;
        if ( not defined $options ) {
            $options = $params;
        }
        else {
            @a = @{$params};
        }
        return validate( @a, $options );
    }
    else {
        if ( ref $params->[0] ) {
            $params = $params->[0];
        }
        elsif ( scalar( @{$params} ) % 2 == 0 ) {
            $params = { @{$params} };

        }
        else {
            $params = undef;
        }

        return wantarray ? %{$params} : $params;
    }
}

=head2 validateParamsPos($params, @options)

Wrapper for the 'validate_pos' function in Params::Validate.

=cut

sub validateParamsPos(\@@) {
    my ( $params, @options ) = @_;

    if ( $logger->is_debug() ) {
        my @a = @{$params};
        return validate_pos( @a, @options );
    }
    else {
        return wantarray ? @{$params} : $params;
    }
}

1;

__END__

=head1 SEE ALSO

L<Params::Validate>, L<Log::Log4perl>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: ParameterValidation.pm 2640 2009-03-20 01:21:21Z zurawski $

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

# vim: expandtab shiftwidth=4 tabstop=4
