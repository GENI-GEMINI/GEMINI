#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.2;

=head1 NAME

makeStore.pl

=head1 DESCRIPTION

Create a temporary store file to ensure that the Skeleton MP service works
properly.

=head1 SYNOPSIS

makeStore.pl

=cut

use English qw( -no_match_vars );
use File::Temp qw(tempfile);
use Carp;

my $confdir = shift;
unless ( $confdir ) {
    croak "Configuration directory not provided, aborting.\n";
    exit( 1 );
}

my $load = shift;

my ( $fileHandle, $fileName ) = tempfile();
print $fileHandle "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
print $fileHandle "<nmwg:store  xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
print $fileHandle "     xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"\n";
print $fileHandle "     xmlns:unis=\"http://ogf.org/schema/network/topology/unis/20100528/\"\n";
print $fileHandle "     xmlns:nmtm=\"http://ggf.org/ns/nmwg/time/2.0/\">\n\n";

print $fileHandle "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"m-" . "1\">\n";

# JZ 12/14/2010
#
# Add in some statements that create the metadata content for the store file.

print $fileHandle "  </nmwg:metadata>\n\n";

print $fileHandle "  <nmwg:data xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"d-" . "1\" metadataIdRef=\"m-" . "1\">\n";
print $fileHandle "    <nmwg:key id=\"k-" . "1\">\n";
print $fileHandle "      <nmwg:parameters id=\"pk-" . "1\">\n";

# JZ 12/14/2010
#
# Add in some statements that create the data (key) content for the store file.  

print $fileHandle "      </nmwg:parameters>\n";
print $fileHandle "    </nmwg:key>\n";
print $fileHandle "  </nmwg:data>\n\n";

print $fileHandle "</nmwg:store>\n";
close( $fileHandle );

if ( $load ) {
    system( "mv " . $fileName . " " . $confdir . "/store.xml" );
}
else {
    print $fileName;
}

__END__

=head1 SEE ALSO

L<English>, L<File::Temp>, L<Carp>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: makeStore.pl 2754 2009-04-13 14:46:03Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Guilherme Fernandes, fernande@cis.udel.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2010, Internet2 and the University of Delaware

All rights reserved.

=cut
