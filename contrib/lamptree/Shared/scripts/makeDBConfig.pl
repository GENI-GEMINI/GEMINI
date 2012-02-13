#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

makeDBConfig.pl

=head1 DESCRIPTION

The DB_CONFIG file is used by the XMLDB to control environmental
items like number of locks and the size of the cache.  This file is
very valuable to dynamic services such as the LS.

=head1 SYNOPSIS

./makeDBConfig.pl

=cut

use File::Temp qw(tempfile);

my ( $fileHandle, $fileName ) = tempfile();

print $fileHandle "set_lock_timeout 5000\n";
print $fileHandle "set_txn_timeout 5000\n";
print $fileHandle "set_lk_max_lockers 500000\n";
print $fileHandle "set_lk_max_locks 500000\n";
print $fileHandle "set_lk_max_objects 500000\n";
print $fileHandle "set_lk_detect DB_LOCK_MINLOCKS\n";
print $fileHandle "set_cachesize 0 33554432 0\n";
print $fileHandle "set_flags DB_LOG_AUTOREMOVE\n";
print $fileHandle "set_lg_regionmax 2097152\n";

close( $fileHandle );

print $fileName;

__END__

=head1 SEE ALSO

L<File::Temp>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: makeDBConfig.pl 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2

All rights reserved.

=cut
