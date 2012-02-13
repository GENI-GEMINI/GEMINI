package perfSONAR_PS::Transport;

use strict;
use warnings;

our $VERSION = 3.2;

use fields 'CONTACT_HOST', 'CONTACT_PORT', 'CONTACT_ENDPOINT';

=head1 NAME

perfSONAR_PS::Transport

=head1 DESCRIPTION

A module that provides methods for listening and contacting SOAP endpoints as
well as performing other 'transportation' needs for communication in the
perfSONAR-PS framework.  This module is to be treated a single object, capable
of interacting with a given service (specified by information at creation time). 

=cut

use Exporter;
use base 'Exporter';
our @EXPORT = ();

use LWP::UserAgent;
use Log::Log4perl qw(get_logger :nowarn);
use English qw( -no_match_vars );
use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;

=head2 =head2 new($package, $contactHost, $contactPort, $contactEndPoint)

The 'contactHost', 'contactPort', and 'contactEndPoint' set the values that are
used to send information to a remote host.  All values can be left blank and
set via the various set functions.

=cut

sub new {
    my ( $package, $contactHost, $contactPort, $contactEndPoint ) = @_;

    my $self = fields::new( $package );

    if ( defined $contactHost and $contactHost ) {
        $self->{"CONTACT_HOST"} = $contactHost;
    }
    if ( defined $contactPort and $contactPort ) {
        $self->{"CONTACT_PORT"} = $contactPort;
    }
    if ( defined $contactEndPoint and $contactEndPoint ) {
        $self->{"CONTACT_ENDPOINT"} = $contactEndPoint;
    }

    return $self;
}

=head2 setContactHost($self, $contactHost)  

(Re-)Sets the value for the 'contactHost' variable.  The contact host is the
hostname of a remote host that is supplying a service.

=cut

sub setContactHost {
    my ( $self, $contactHost ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Transport" );
    if ( defined $contactHost and $contactHost ) {
        $self->{CONTACT_HOST} = $contactHost;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 setContactPort($self, $contactPort)  

(Re-)Sets the value for the 'contactPort' variable.  The contact port is the
port on a remote host that is supplying a service.

=cut

sub setContactPort {
    my ( $self, $contactPort ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Transport" );
    if ( defined $contactPort and $contactPort ) {
        $self->{CONTACT_PORT} = $contactPort;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 splitURI($uri)

Splits the contents of a URI into host, port, and endpoint.

=cut

sub splitURI {
    my ( $uri )  = @_;
    my $logger   = get_logger( "perfSONAR_PS::Transport" );
    my $host     = undef;
    my $port     = undef;
    my $endpoint = undef;
    my $secure   = 0;

    # lop off the protocol, then split everthing up by :'s
    $secure++ if $uri =~ m/^https:\/\//;
    $uri =~ s/^https?:\/\///;
    my @chunk = split( /:/, $uri );
    my $len = $#chunk;

    # assume the very last thing in line is the port/endPoint (this
    #  isn't true w/ ipv6 of course)
    $port = $chunk[$len];

    # subtract the endPoint from the port, XOR to get the endPoint
    $port =~ s/\/.*$//;
    $endpoint = substr $chunk[$len], length $port, length $chunk[$len];

    if ( $port =~ m/^\d+$/ ) {

        # the fun part ... If its all numbers, it COULD be the port
        $chunk[$len] = q{};
        unless ( $chunk[ $len - 1 ] =~ m/\]$/ ) {

            # the last chunk is really what we thought was the port.
            $chunk[$len] = $port if $port and $len > 1;
        }
    }
    else {

        # this is the case where we clearly have hex digits, or it ends
        #  in ].  The last item in the array is not a port, but part of the
        #  address, so set the port to nil.
        $chunk[$len] =~ s/\/.*$//;
        $port = q{};
    }

    # not ipv6
    if ( $len == 0 ) {
        $host = $port;
        $port = q{};
    }

    # combine the chunks back together
    for my $x ( 0 .. $len ) {
        $host .= ":" unless $x == 0;
        $host .= $chunk[$x];
    }

    # clean up
    $host =~ s/:$//;
    $host =~ s/^\[//;
    $host =~ s/\]$//;

    # default port is 80 for http, and 443 for https
    unless ( defined $port or $port ) {
        if ( $secure ) {
            $port = 443;
        }
        else {
            $port = 80;
        }
    }

    $logger->debug( "Found host: " . $host . " port: " . $port . " endpoint: " . $endpoint );
    return ( $host, $port, $endpoint );
}

=head2 getHttpURI($host, $port, $endpoint)

Creates a URI from a host, port, and endpoint

=cut

sub getHttpURI {
    my ( $host, $port, $endpoint ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Transport" );
    $endpoint = "/" . $endpoint if ( $endpoint =~ /^[^\/]/ );
    if ( $host =~ /:/ ) {
        $host = "[" . $host . "]";
    }
    my $uri = 'http://' . $host . ':' . $port . $endpoint;
    $logger->debug( "Created URI: $uri" );
    return $uri;
}

=head2 setContactEndPoint($self, $contactEndPoint)  

(Re-)Sets the value for the 'contactEndPoint' variable.  The contactEndPoint
is the endPoint on a remote host that is supplying a service.

=cut

sub setContactEndPoint {
    my ( $self, $contactEndPoint ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Transport" );
    if ( defined $contactEndPoint and $contactEndPoint ) {
        $self->{CONTACT_ENDPOINT} = $contactEndPoint;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 sendReceive($self, $envelope, $timeout, $error)

Sends and receives a SOAP envelope. $error is a pointer to a variable as well
as a given timout value. If an error message is generated, it is filled with
that message. If not, it is filled with "".

=cut

sub sendReceive {
    my ( $self, $envelope, $timeout, $error ) = @_;

    # XXX 3/17 - JZ
    #    Should be configurable.
    $timeout = 30 unless $timeout;
    my $logger = get_logger( "perfSONAR_PS::Transport" );
    my $method_uri   = "http://ggf.org/ns/nmwg/base/2.0/message/";
    my $httpEndpoint = &getHttpURI( $self->{CONTACT_HOST}, $self->{CONTACT_PORT}, $self->{CONTACT_ENDPOINT} );
    my $userAgent    = LWP::UserAgent->new( 'timeout' => ( $timeout * 1000 ) );

    $logger->debug( "Sending information to \"" . $httpEndpoint . "\": $envelope" );

    my $sendSoap = HTTP::Request->new( 'POST', $httpEndpoint, new HTTP::Headers, $envelope );
    $sendSoap->header( 'SOAPAction' => $method_uri );
    $sendSoap->content_type( 'text/xml' );
    $sendSoap->content_length( length( $envelope ) );

    my $httpResponse;
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        $httpResponse = $userAgent->request( $sendSoap );
        alarm 0;
    };
    if ( $EVAL_ERROR ) {
        $logger->error( "Connection to \"" . $httpEndpoint . "\" terminiated due to alarm after \"" . $timeout . "\" seconds." ) unless $EVAL_ERROR eq "alarm\n";
        $$error = "Connection to \"" . $httpEndpoint . "\" terminiated due to alarm after \"" . $timeout . "\" seconds.";
        return;
    }
    else {
        unless ( $httpResponse->is_success ) {
            $logger->debug( "Send to \"" . $httpEndpoint . "\" failed: " . $httpResponse->status_line );
            $$error = $httpResponse->status_line if defined $error;
            return;
        }
        my $responseCode    = $httpResponse->code();
        my $responseContent = $httpResponse->content();
        $logger->debug( "Response returned: " . $responseContent );
        $$error = q{} if defined $error;
        return $responseContent;
    }
}

1;

__END__

=head1 SEE ALSO

L<LWP::UserAgent>, L<Log::Log4perl>, L<English>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Messages>

To join the 'perfSONAR Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Transport.pm 4475 2010-09-29 13:18:06Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Guilherme Fernandes, fernande@cis.udel.edu

=head1 LICENSE
 
You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT
 
Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut

