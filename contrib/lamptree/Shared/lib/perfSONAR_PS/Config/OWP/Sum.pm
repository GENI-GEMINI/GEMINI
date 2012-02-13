package perfSONAR_PS::Config::OWP::Sum;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

Sum.pm - Module to read summarized data.

=head1 DESCRIPTION

Module to read summarized data.

=cut

require 5.005;
require Exporter;
use vars qw(@ISA @EXPORT $VERSION);

@ISA    = qw(Exporter);
@EXPORT = qw(parsesum);

$Sum::REVISION = '$Id: Sum.pm 2969 2009-07-15 14:40:14Z zurawski $';
$VERSION = $Sum::VERSION = '1.0';

sub parsesum {
    my ( $sfref, $rref ) = @_;

    while ( <$sfref> ) {
        my ( $key, $val );
        next if ( /^\s*#/ );    # comments
        next if ( /^\s*$/ );    # blank lines

        if ( ( ( $key, $val ) = /^(\w+)\s+(.*?)\s*$/o ) ) {
            $key =~ tr/a-z/A-Z/;
            $$rref{$key} = $val;
            next;
        }

        if ( /^<BUCKETS>\s*/ ) {
            my @buckets;
            my ( $bi, $bn );
        BUCKETS:
            while ( <$sfref> ) {
                last BUCKETS if ( /^<\/BUCKETS>\s*/ );
                if ( ( ( $bi, $bn ) = /^\s*(-{0,1}\d+)\s+(\d+)\s*$/o ) ) {
                    push @buckets, $bi, $bn;
                }
                else {
                    warn "SUM Syntax Error[line:$.]: $_";
                    return undef;
                }
            }
            if ( @buckets > 0 ) {
                $$rref{'BUCKETS'} = join '_', @buckets;
            }
            next;
        }

        if ( /^<TTLBUCKETS>\s*/ ) {
            my @buckets;
            my ( $bi, $bn );
        TTLBUCKETS:
            while ( <$sfref> ) {
                last TTLBUCKETS if ( /^<\/TTLBUCKETS>\s*/ );
                if ( ( ( $bi, $bn ) = /^\s*(-{0,1}\d+)\s+(\d+)\s*$/o ) ) {
                    push @buckets, $bi, $bn;
                }
                else {
                    warn "SUM Syntax Error[line:$.]: $_";
                    return undef;
                }
            }
            if ( @buckets > 0 ) {
                $$rref{'TTLBUCKETS'} = join '_', @buckets;
            }
            next;
        }

        if ( /^MINTTL\s*/ or /^MAXTTL\s*/ ) {

            # do nothing for now
        }

        if ( /^<NREORDERING>\s*/ ) {

            # do nothing for now

        NREORDERING:
            while ( <$sfref> ) {
                last NREORDERING if ( /^<\/NREORDERING>\s*/ );
            }
            next;
        }

        warn "SUM Syntax Error[line:$.]: $_";
        return undef;
    }

    if ( !defined( $$rref{'SUMMARY'} ) ) {
        warn "perfSONAR_PS::Config::OWP::Sum::parsesum(): Invalid Summary";
        return undef;
    }

    return 1;
}

1;

__END__

=head1 SEE ALSO

L<Exporter>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Sum.pm 2969 2009-07-15 14:40:14Z zurawski $

=head1 AUTHOR

Jeff Boote, boote@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
