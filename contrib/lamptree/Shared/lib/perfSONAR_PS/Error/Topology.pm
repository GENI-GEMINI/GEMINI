use perfSONAR_PS::Error;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Error::MA

=head1 DESCRIPTION

A module that provides the exceptions framework for perfSONAR PS.  This module
provides the message exception types that will be presented.

=cut

=head2 perfSONAR_PS::Error::Topology

Base error for topology from which all topology exceptions derive.

=cut

package perfSONAR_PS::Error::Topology;
use base "perfSONAR_PS::Error";

=head2 perfSONAR_PS::Error::Topology::InvalidParameter

invalid parameter error

=cut

package perfSONAR_PS::Error::Topology::InvalidParameter;
use base "perfSONAR_PS::Error::Topology";

=head2 perfSONAR_PS::Error::Topology

dependency error

=cut

package perfSONAR_PS::Error::Topology::Dependency;
use base "perfSONAR_PS::Error::Topology";

=head2 perfSONAR_PS::Error::Topology

invalid topology error

=cut

package perfSONAR_PS::Error::Topology::InvalidTopology;
use base "perfSONAR_PS::Error::Topology";

# YTL: i think these should return the common::storage errors
#package perfSONAR_PS::Error::Topology::MA;
#use base "perfSONAR_PS::Error::Topology";

# YTL: i reckon these should return teh common:query errors
#package perfSONAR_PS::Error::Topology::Query;
#use base "perfSONAR_PS::Error::Topology";

#package perfSONAR_PS::Error::Topology::Query::QueryNotFound;
#use base "perfSONAR_PS::Error::Topology::Query";

#package perfSONAR_PS::Error::Topology::Query::TopologyNotFound;
#use base "perfSONAR_PS::Error::Topology::Query";

#package perfSONAR_PS::Error::Topology::Query::InvalidKnowledgeLevel;
#use base "perfSONAR_PS::Error::Topology::Query";

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

$Id: Topology.pm 2640 2009-03-20 01:21:21Z zurawski $

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
