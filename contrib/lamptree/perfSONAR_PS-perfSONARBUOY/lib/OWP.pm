package OWP;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

OWP.pm - perfSONAR-BUOY utility functions

=head1 DESCRIPTION

Functions for the operation of the perfSONAR-BUOY collection and measurement
software. 

=cut

require 5.005;
require Exporter;
use FindBin;
use POSIX;
use Fcntl qw(:flock);
use FileHandle;
use vars qw(@ISA @EXPORT $VERSION);
use OWP::Helper;
use OWP::Conf;
use OWP::Utils;

@ISA    = qw(Exporter);
@EXPORT = qw(daemonize setids);

$OWP::REVISION = '$Id: OWP.pm 4166 2010-06-02 21:09:41Z boote $';
$VERSION       = '1.0';

sub setids {
    my ( %args ) = @_;
    my ( $uid,  $gid );
    my ( $unam, $gnam );

    $uid = $args{'USER'}  if ( defined $args{'USER'} );
    $gid = $args{'GROUP'} if ( defined $args{'GROUP'} );

    # Don't do anything if we are not running as root.
    return if ( $> != 0 );

    die "Must set User option! (Running as root is folly!)"
        if ( !$uid );

    # set GID first to ensure we still have permissions to.
    if ( defined( $gid ) ) {
        if ( $gid =~ /\D/ ) {

            # If there are any non-digits, it is a groupname.
            $gid = getgrnam( $gnam = $gid )
                or die "Can't getgrnam($gnam): $!";
        }
        elsif ( $gid < 0 ) {
            $gid = -$gid;
        }
        die( "Invalid GID: $gid" ) if ( !getgrgid( $gid ) );
        $) = $( = $gid;
    }

    # Now set UID
    if ( $uid =~ /\D/ ) {

        # If there are any non-digits, it is a username.
        $uid = getpwnam( $unam = $uid )
            or die "Can't getpwnam($unam): $!";
    }
    elsif ( $uid < 0 ) {
        $uid = -$uid;
    }
    die( "Invalid UID: $uid" ) if ( !getpwuid( $uid ) );
    $> = $< = $uid;

    return;
}

sub daemonize {
    my ( %args ) = @_;
    my ( $dnull, $umask ) = ( '/dev/null', 022 );
    my $fh;

    $dnull = $args{'DEVNULL'} if ( defined $args{'DEVNULL'} );
    $umask = $args{'UMASK'}   if ( defined $args{'UMASK'} );

    if ( defined $args{'PIDFILE'} ) {
        $fh = new FileHandle $args{'PIDFILE'}, O_CREAT | O_RDWR;
        unless ( $fh && flock( $fh, LOCK_EX | LOCK_NB ) ) {
            die "Unable to lock pid file $args{'PIDFILE'}: $!";
        }
        $_ = <$fh>;
        if ( defined $_ ) {
            my ( $pid ) = /(\d+)/;
            die "PID from $args{'PIDFILE'} invalid: $!" unless $pid;
            chomp $pid;
            die "$FindBin::Script:$pid still running..."
                if ( kill( 0, $pid ) );
        }
    }

    open STDIN,  "$dnull"   or die "Can't read $dnull: $!";
    open STDOUT, ">>$dnull" or die "Can't write $dnull: $!";
    if ( !$args{'KEEPSTDERR'} ) {
        open STDERR, ">>$dnull" or die "Can't write $dnull: $!";
    }

    defined( my $pid = fork ) or die "Can't fork: $!";

    # parent
    exit if $pid;

    # child
    truncate( $fh, 0 );
    $fh->seek( 0, 0 );
    $fh->print( $$ );
    undef $fh;
    setsid or die "Can't start new session: $!";
    umask $umask;

    return 1;
}

#
# Hacks to fix incomplete CGI.pm
#
package CGI;

sub script_filename {
    return $ENV{'SCRIPT_FILENAME'};
}

1;

__END__

=head1 SEE ALSO

L<FindBin>, L<POSIX>, L<Fcntl>, L<FileHandle>, L<OWP::Helper>, L<OWP::Conf>,
L<OWP::Utils>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: OWP.pm 4166 2010-06-02 21:09:41Z boote $

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
