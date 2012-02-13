use perfSONAR_PS::Error;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Error::MP

=head1 DESCRIPTION

A module that provides the measurement point exceptions framework for
perfSONAR PS.  This module provides the measurement point exception objects

=cut

=head2 perfSONAR_PS::Error::MP

General exceptions for MP's; all following objects derive from this.

=cut

package perfSONAR_PS::Error::MP;
use base "perfSONAR_PS::Error";

=head2 perfSONAR_PS::Error::MP::Configuration

Configuration errors for the MP, such as invalid configuration, unparseable 
configuration etc.

=cut

package perfSONAR_PS::Error::MP::Configuration;
use base "perfSONAR_PS::Error::Common::Configuration";

=head2

Scheduling errors for the MP, such as the inability to schedule a test, test
schedule is not valid etc.

=cut

package perfSONAR_PS::Error::MP::Scheduler;
use base "perfSONAR_PS::Error::MP";

=head2 perfSONAR_PS::Error::MP::Agent

Errors from the agents performing the test, typically low level system problems
such as command not found, or unparseable output etc.

=cut

package perfSONAR_PS::Error::MP::Agent;
use base "perfSONAR_PS::Error::MP";

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

$Id: MP.pm 2640 2009-03-20 01:21:21Z zurawski $

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
