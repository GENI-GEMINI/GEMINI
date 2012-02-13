package perfSONAR_PS::Config::OWP::Helper;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

Helper.pm - Library used to verify tests.

=head1 DESCRIPTION

Library used to verify tests.

=cut

require Exporter;
use vars qw(@ISA @EXPORT $VERSION);

@ISA    = qw(Exporter);
@EXPORT = qw(owpverify_args print_hash split_addr);

$perfSONAR_PS::Config::OWP::REVISION = '$Id: Helper.pm 2969 2009-07-15 14:40:14Z zurawski $';
$VERSION       = '1.0';

sub owpverify_args {
    my ( $allowed, $must, %args ) = @_;
    my %allowed;

    foreach ( @$allowed ) {
        next if !defined $_;
        tr/a-z/A-Z/;
        $allowed{$_} = 1;
    }
    foreach ( @$must ) {
        next if !defined $_;
        tr/a-z/A-Z/;
        $allowed{$_} = 1;
    }

    foreach ( keys %args ) {
        my $name = $_;
        $name =~ tr/a-z/A-Z/;

        if ( !defined( $allowed{$name} ) ) {
            my ( $pack, $fname, $line, $sub ) = caller( 1 );
            warn "$fname\:$line -- $pack\:\:$sub\: Invalid arg $name\n";
            return undef;
        }

        if ( $name ne $_ ) {
            $args{$name} = $args{$_};
            delete $args{$_};
        }
    }

    foreach ( @$must ) {
        next if exists $args{$_};

        my ( $pack, $fname, $line, $sub ) = caller( 1 );
        warn "$fname\:$line -- $pack\:\:$sub\: Missing required arg $_\n";
        return undef;
    }

    my @args = %args;
    return @args;
}

sub print_hash {
    my ( $name, %hash ) = @_;
    my $key;

    foreach $key ( sort keys( %hash ) ) {
        warn "\$$name\{$key\}:\t$hash{$key}\n";
    }
}

#
# XXX: unit test eventually...
# Test cases:
#   [2001:468:1:12::16:98]:8725
#   2001:468:1:12::16:98
#   [2001:468:1:12::16:98]
#   192.168.1.1
#   192.168.1.1:1234
#   [192.168.1.1]:1234
#   nonsense.org
#   nonsense.org:87632
#   nonsense.org:8763292837492847
sub split_addr {
    my ( $fulladdr ) = @_;

    my ( $cnt, $addr, $port );

    $_ = $fulladdr;

    # any spaces is an error
    if ( ( $cnt = tr/ \t\n\r\f// ) > 0 ) {
        warn "split_addr(): Address \"$fulladdr\" contains $cnt whitespace chars";
        return ( undef, undef );
    }

    # full brackets
    if ( ( $addr, $port ) = /^\[([^\]]*)\]\:(\d*)$/ ) {
        ;
    }

    # brackets - no port
    elsif ( ( $addr ) = /^\[([^\]]*)\]$/ ) {
        ;
    }

    # no brackets, more than one ':' indicates bare v6 - no port
    elsif ( ( tr/:/:/ ) > 1 ) {
        $addr = $fulladdr;
    }

    # hostname with
    elsif ( ( $addr, $port ) = /^([^:]*)\:(\d*)$/ ) {
        ;
    }
    else {
        $addr = $fulladdr;
    }

    if ( defined( $port ) ) {
        if ( ( length( $port ) < 1 ) || ( $port == 0 ) ) {
            undef $port;
        }
        elsif ( $port > 65535 ) {
            warn "split_addr(): Address \"$fulladdr\" specifies an invalid port value \"$port\"";
            return ( undef, undef );
        }
    }

    return ( $addr, $port );
}

__END__

=head1 SEE ALSO

L<>, 

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Helper.pm 2969 2009-07-15 14:40:14Z zurawski $

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
