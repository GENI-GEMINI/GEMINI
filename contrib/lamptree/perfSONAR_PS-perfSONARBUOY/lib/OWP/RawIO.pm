package OWP::RawIO;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

RawIO.pm - Library to handle IO operations on measurement data.

=head1 DESCRIPTION

Library to handle IO operations on measurement data.

=cut

require 5.005;
require Exporter;
use vars qw(@ISA @EXPORT $VERSION);
use POSIX;
use FindBin;

#use Errno qw(EINTR EIO :POSIX);

@ISA    = qw(Exporter);
@EXPORT = qw(sys_readline sys_writeline);

$RawIO::REVISION = '$Id: RawIO.pm 2969 2009-07-15 14:40:14Z zurawski $';
$VERSION = $RawIO::VERSION = '1.0';

sub sys_readline {
    my ( %args ) = @_;
    my ( $fh, $tmout ) = ( \*STDIN, 0 );
    my ( $cb ) = sub { return undef };
    my $char;
    my $read;
    my $line = "";
    $tmout = $args{'TIMEOUT'}    if ( defined $args{'TIMEOUT'} );
    $fh    = $args{'FILEHANDLE'} if ( defined $args{'FILEHANDLE'} );
    $cb    = $args{'CALLBACK'}   if ( defined $args{'CALLBACK'} );

    while ( 1 ) {
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            local $SIG{PIPE} = sub { die "pipe\n" };
            alarm $tmout;
            $read = sysread( $fh, $char, 1 );
            alarm 0;
        };
        if ( !defined( $read ) ) {
            if ( ( $! == EINTR ) && ( $@ ne "alarm\n" ) && ( $@ ne "pipe\n" ) ) {
                next;
            }
            return &$cb( undef, $@ );
        }
        if ( $read < 1 ) {
            return &$cb( $read, undef );
        }
        if ( $char eq "\n" ) {

            #warn "RECV: $line\n";
            return $line;
        }
        $line .= $char;
    }
}

sub sys_writeline {
    my ( %args ) = @_;
    my ( $fh, $line, $md5, $tmout ) = ( \*STDOUT, '', undef, 0 );
    my ( $cb ) = sub { return undef };
    $line  = $args{'LINE'}       if ( defined $args{'LINE'} );
    $tmout = $args{'TIMEOUT'}    if ( defined $args{'TIMEOUT'} );
    $fh    = $args{'FILEHANDLE'} if ( defined $args{'FILEHANDLE'} );
    $cb    = $args{'CALLBACK'}   if ( defined $args{'CALLBACK'} );
    $md5   = $args{'MD5'}        if ( defined $args{'MD5'} );

    $md5->add( $line ) if ( ( defined $md5 ) && !( $line =~ /^$/ ) );

    $line .= "\n";
    my $len    = length( $line );
    my $offset = 0;

    while ( $len ) {
        my $written;
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            local $SIG{PIPE} = sub { die "pipe\n" };
            alarm $tmout;
            $written = syswrite $fh, $line, $len, $offset;
            alarm 0;
        };
        if ( !defined( $written ) ) {
            if ( ( $! == EINTR ) && ( $@ ne "alarm\n" ) && ( $@ ne "pipe\n" ) ) {
                next;
            }
            return &$cb( undef, $@ );
        }
        $len -= $written;
        $offset += $written;
    }

    #warn "TXMT: $line";
    return 1;
}

1;

__END__

=head1 SEE ALSO

L<Exporter>, L<POSIX>, L<FindBin>, L<Errno>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: RawIO.pm 2969 2009-07-15 14:40:14Z zurawski $

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
