package perfSONAR_PS::Utils::NTP;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Utils::NTP

=head1 DESCRIPTION

A module that provides utility methods for interacting with NTP servers.  This
module provides a set of methods for interacting with NTP servers. This module
IS NOT an object, and the methods can be invoked directly. The methods need to
be explicitly imported to use them.

=head1 API

=cut

use base 'Exporter';

use Socket;
use Time::HiRes qw(gettimeofday);
use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);

our @EXPORT_OK = qw( ping );

=head2 ping ($hostname => 1, port => 0, timeout => 0)

Resolve an ip address to a NTP name.

=cut

sub ping {
    my $parameters = validate( @_, { hostname => 1, port => 0, timeout => 0} );

    my $hostname = $parameters->{hostname};
    my $port = $parameters->{port};
    my $timeout = $parameters->{timeout};

    $port = 123 unless ($port);

    my $retval;

    eval {
		local $SIG{ALRM} = sub { die "Timeout" };
		if ($timeout) {
			alarm($timeout);
		}

        my ($status, $res);

	    #we use the system call to open a UDP socket
        $status = socket(SOCKET, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
        unless ($status) {
            die("Socket failed: $?" );
        }

	    #convert hostname to ipaddress if needed
        my $ipaddr   = inet_aton($hostname);
        my $portaddr = sockaddr_in($port, $ipaddr);

	    # build a message.  Our message is all zeros except for a one in the protocol version field
    	# $msg in binary is 00 001 000 00000000 ....  or in C msg[]={010,0,0,0,0,0,0,0,0,...}
    	#it should be a total of 48 bytes long
    	my $MSG="\010"."\0"x47;

		my   ($s_seconds, $s_microseconds) = gettimeofday();

		#send the data
		$res = send(SOCKET, $MSG, 0, $portaddr);
		unless ($res == length($MSG)) {
			die("cannot send to $hostname($port): $!");
		}

		$portaddr = recv(SOCKET, $MSG, 1024, 0)      or die "recv: $!";

		my   ($e_seconds, $e_microseconds) = gettimeofday();

		my $dur_seconds = ($e_seconds - $s_seconds);
		my $dur_micros = ($e_microseconds - $s_microseconds);
		if ($dur_micros < 0) {
			$dur_micros = -$dur_micros;
			$dur_seconds--;
		}
		$retval = sprintf("%d.%06d", $dur_seconds, $dur_micros);

        alarm 0;
	};
	if ($@) {
		my $msg = $@;
		return (-1, $msg);
	}

	return (0, $retval);
}

1;

__END__

=head1 SEE ALSO

L<Socket>, L<Time::HiRes>,
L<Params::Validate>,L<Log::Log4perl>,

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: NTP.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
