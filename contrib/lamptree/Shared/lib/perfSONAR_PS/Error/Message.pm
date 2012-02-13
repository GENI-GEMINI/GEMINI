use perfSONAR_PS::Error;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Error::Message

=head1 DESCRIPTION

A module that provides the message exceptions framework for perfSONAR PS.  This
module provides the message exception objects.

=cut

=head2 perfSONAR_PS::Error::Message

Base exception class from which all following exception objects derive.

=cut

package perfSONAR_PS::Error::Message;
use base "perfSONAR_PS::Error";

=head2 perfSONAR_PS::Error::Message::InvalidXML

The XML is invalid, either it is not well formed, or has other issues.

=cut

package perfSONAR_PS::Error::Message::InvalidXML;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message

Chaining errors, such as invalid chaining defined, or chaining could not be resolved.

=cut

package perfSONAR_PS::Error::Message::Chaining;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message::NoMessageType

No message type was provided.

=cut

package perfSONAR_PS::Error::Message::NoMessageType;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message::InvalidMessageType

The message type provided is invalid, it is not supported.

=cut

package perfSONAR_PS::Error::Message::InvalidMessageType;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message::NoEventType

No Event Type was provided.

=cut

package perfSONAR_PS::Error::Message::NoEventType;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message::InvalidEventType

The event type is not supported or is invalid.

=cut

package perfSONAR_PS::Error::Message::InvalidEventType;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message::InvalidKey

The provide key is invalid or cannot be resolved.

=cut

package perfSONAR_PS::Error::Message::InvalidKey;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message::InvalidSubject

The provided subject was invalid.

=cut

package perfSONAR_PS::Error::Message::InvalidSubject;
use base "perfSONAR_PS::Error::Message";

=head2 perfSONAR_PS::Error::Message::NoMetaDataPair

The metadata does not resolve to a data element.

=cut

package perfSONAR_PS::Error::Message::NoMetadataDataPair;
use base "perfSONAR_PS::Error::Message";

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

$Id: Message.pm 2640 2009-03-20 01:21:21Z zurawski $

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
