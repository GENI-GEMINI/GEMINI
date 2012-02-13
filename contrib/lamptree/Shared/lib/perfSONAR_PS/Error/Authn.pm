use perfSONAR_PS::Error;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Error::Authn

=head1 DESCRIPTION

A module that provides the exceptions for the authenicationframework for
perfSONAR PS.  This module provides the authenication exception objects.

=cut

package perfSONAR_PS::Error::Authn;
use base "perfSONAR_PS::Error";

package perfSONAR_PS::Error::Authn::WrongParams;
use base "perfSONAR_PS::Error::Authn";

package perfSONAR_PS::Error::Authn::AssertionNotIncluded;
use base "perfSONAR_PS::Error::Authn";

package perfSONAR_PS::Error::Authn::AssertionNotValid;
use base "perfSONAR_PS::Error::Authn";

package perfSONAR_PS::Error::Authn::x509NotIncluded;
use base "perfSONAR_PS::Error::Authn";

package perfSONAR_PS::Error::Authn::x509NotValid;
use base "perfSONAR_PS::Error::Authn";

package perfSONAR_PS::Error::Authn::NotSecToken;
use base "perfSONAR_PS::Error::Authn";

1;

__END__

=head1 SEE ALSO

L<Data::Dumper>, L<Statistics::Descriptive>, L<Log::Log4perl>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Authn.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li <ytl@slac.stanford.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2 and SLAC National Accelerator Laboratory

All rights reserved.

=cut
