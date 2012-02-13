use perfSONAR_PS::Error;
use perfSONAR_PS::Error::Common;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Error::MA

=head1 DESCRIPTION

A module that provides the measurement archive exceptions framework for
perfSONAR PS.  This module provides the measurement archive exception objects.

=cut

package perfSONAR_PS::Error::MA;
use base "perfSONAR_PS::Error";

package perfSONAR_PS::Error::MA::Configuration;
use base "perfSONAR_PS::Error::Common::Configuration";

# not sure about these as they are provided under Common

package perfSONAR_PS::Error::MA::Query;
use base "perfSONAR_PS::Error::Common::Storage::Query";

package perfSONAR_PS::Error::MA::Query::IncompleteData;
use base "perfSONAR_PS::Error::MA::Query";

package perfSONAR_PS::Error::MA::Query::IncompleteMetaData;
use base "perfSONAR_PS::Error::MA::Query";

package perfSONAR_PS::Error::MA::Query::InvalidKnowledgeLevel;
use base "perfSONAR_PS::Error::MA::Query";

package perfSONAR_PS::Error::MA::Query::InvalidTimestampType;
use base "perfSONAR_PS::Error::MA::Query";

package perfSONAR_PS::Error::MA::Query::InvalidUpdateParamter;
use base "perfSONAR_PS::Error::MA::Query";

package perfSONAR_PS::Error::MA::Select;
use base "perfSONAR_PS::Error::MA";

package perfSONAR_PS::Error::MA::Status;
use base "perfSONAR_PS::Error::MA";

package perfSONAR_PS::Error::MA::Status::NoLinkId;
use base "perfSONAR_PS::Error::MA::Status";

package perfSONAR_PS::Error::MA::Storage;
use base "perfSONAR_PS::Error::MA";

package perfSONAR_PS::Error::MA::StorageResult;
use base "perfSONAR_PS::Error::MA";

package perfSONAR_PS::Error::MA::Storage::Result;
use base "perfSONAR_PS::Error::MA::Storage";

package perfSONAR_PS::Error::MA::Structure;
use base "perfSONAR_PS::Error::MA";

package perfSONAR_PS::Error::MA::Transport;
use base "perfSONAR_PS::Error::MA";

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

$Id: MA.pm 2640 2009-03-20 01:21:21Z zurawski $

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
