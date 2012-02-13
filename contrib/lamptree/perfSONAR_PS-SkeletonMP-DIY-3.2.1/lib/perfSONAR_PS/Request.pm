package perfSONAR_PS::Request;

use strict;
use warnings;

our $VERSION = 3.2;

use fields 'REQUEST', 'REQUESTDOM', 'RESPONSE', 'RESPONSEMESSAGE', 'START_TIME', 'CALL', 'NAMESPACES';

=head1 NAME

perfSONAR_PS::Request

=head1 DESCRIPTION

A module that provides an object to interact with for each client request. This
module is to be treated as an object representing a request from a user. The
object can be used to get the users request in DOM format as well as set and
send the response.

=cut

use Log::Log4perl qw(get_logger);
use XML::LibXML;
use English qw( -no_match_vars );
use Socket;

use perfSONAR_PS::Common;

=head2 new ($package, $call, $http_request)

The 'call' argument is the resonse from HTTP::Daemon->accept(). The request is
the actual http request from the user. In general, it can be obtained from the call
variable specified above using the '->get_request' function. If it is
unspecified, new will try to obtain the request from $call directly.

=cut

sub new {
    my ( $package, $call, $http_request ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );

    my $self = fields::new( $package );

    $self->{"CALL"} = $call;
    if ( defined $http_request and $http_request ) {
        $self->{"REQUEST"} = $http_request;
    }
    else {
        $self->{"REQUEST"} = $call->get_request;
    }
    my %empty = ();
    $self->{"NAMESPACES"} = \%empty;

    $self->{"RESPONSE"} = HTTP::Response->new();
    $self->{"RESPONSE"}->header( 'Content-Type' => 'text/xml' );
    $self->{"RESPONSE"}->header( 'user-agent'   => 'perfSONAR-PS/3.2' );
    $self->{"RESPONSE"}->code( "200" );

    $self->{"START_TIME"} = [Time::HiRes::gettimeofday];

    return $self;
}

=head2 setRequest($self, $request)

(Re-)Sets the request from the client.

=cut

sub setRequest {
    my ( $self, $request ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    if ( defined $request and $request ) {
        $self->{REQUEST} = $request;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 getEndpoint($self)

Return the contacted endPoint.

=cut

sub getEndpoint {
    my ( $self ) = @_;
    my $endpoint = $self->{REQUEST}->uri;

    $endpoint =~ s/\/\//\//;
    return $endpoint;
}

=head2 parse($self, $ns, $error)

Parses the request and remaps the elements in the request according to the
specified namespaces. It returns -1 on error and 0 if everything parsed.

=cut

sub parse {
    my ( $self, $namespace_map, $error ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );

    unless ( exists $self->{REQUEST} ) {
        my $msg = "No request to parse";
        $logger->error( $msg );
        $$error = $msg;
        return -1;
    }

    $logger->debug( "Parsing request: " . $self->{REQUEST}->content );

    my $parser = XML::LibXML->new();
    my $dom    = q{};
    eval { $dom = $parser->parse_string( $self->{REQUEST}->content ); };
    if ( $EVAL_ERROR ) {
        my $msg = escapeString( "Parse failed: " . $EVAL_ERROR );
        $logger->error( $msg );
        $$error = $msg if $error;
        return -1;
    }

    &perfSONAR_PS::Common::mapNamespaces( $dom->getDocumentElement, $self->{NAMESPACES} );

    &perfSONAR_PS::Common::reMap( $self->{NAMESPACES}, $namespace_map, $dom->getDocumentElement, 0 );

    my $nmwg_prefix = $self->{NAMESPACES}->{"http://ggf.org/ns/nmwg/base/2.0/"};
    unless ( exists $self->{NAMESPACES}->{"http://ggf.org/ns/nmwg/base/2.0/"} and $self->{NAMESPACES}->{"http://ggf.org/ns/nmwg/base/2.0/"} ) {
        my $msg = "Received message with incorrect message URI";
        $logger->error( $msg );
        $$error = $msg if $error;
        return -1;
    }

    my $messages = find( $dom->getDocumentElement, ".//nmwg:message", 0 );

    unless ( $messages or $messages->size() <= 0 ) {
        my $msg = "Couldn't find message element in request";
        $logger->error( $msg );
        $$error = $msg if $error;
        return -1;
    }

    if ( $messages->size() > 1 ) {
        my $msg = "Too many message elements found within request";
        $logger->error( $msg );
        $$error = $msg if $error;
        return -1;
    }

    my $new_dom = q{};
    $new_dom = $parser->parse_string( $messages->get_node( 1 )->toString );

    $logger->debug( "Parsed incoming request: " . $new_dom->toString );

    $self->{REQUESTDOM} = $new_dom;
    $$error = q{};
    return 0;
}

=head2 remapRequest($self, $ns)

Remaps the given request according to the prefix/uri pairs specified in the $ns
hash.

=cut

sub remapRequest {
    my ( $self, $ns ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );

    unless ( exists $self->{REQUESTDOM} and $self->{REQUESTDOM} ) {
        $logger->error( "Tried to remap an unparsed request" );
        return;
    }

    $self->{NAMESPACES} = &perfSONAR_PS::Common::reMap( $self->{NAMESPACES}, $ns, $self->{REQUESTDOM} );
    return;
}

=head2 getURI($self)

Returns the URI for the specified request.

=cut

sub getURI {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    unless ( exists $self->{REQUEST} ) {
        $logger->error( "Tried to get URI with no request" );
        return;
    }
    return $self->{REQUEST}->uri;
}

=head2 getRawRequest($self)

Returns the request as it was given to the object (object form).

=cut

sub getRawRequest {
    my ( $self ) = @_;
    return $self->{REQUEST};
}

=head2 getRawRequestAsString($self)

Returns the request as it was given to the object (string form).

=cut

sub getRawRequestAsString {
    my ( $self ) = @_;
    return $self->{REQUEST}->content;
}

=head2 setResponse($self, $content)

Sets the response to the content.

=cut

sub setResponse {
    my ( $self, $content ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    if ( defined $content and $content ) {
        $self->{RESPONSE}->message( "success" );
        $self->{RESPONSE}->content( makeEnvelope( $content ) );
        $self->{RESPONSEMESSAGE} = $content;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 getRequestDOM($self)

Gets and returns the contents of the request as a DOM object.

=cut

sub getRequestDOM {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    if ( exists $self->{REQUESTDOM} and $self->{REQUESTDOM} ) {
        return $self->{REQUESTDOM};
    }
    else {
        $logger->error( "Request DOM not found." );
        return;
    }
}

=head2 getResponse($self)

Gets and returns the response as a string.

=cut

sub getResponse {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    if ( exists $self->{RESPONSEMESSAGE} and $self->{RESPONSEMESSAGE} ) {
        return $self->{RESPONSEMESSAGE};
    }
    else {
        $logger->error( "Response not found." );
        return;
    }
}

=head2 setNamespaces($self,\%ns)

(Re-)Sets the the namespaces in the request.

=cut

sub setNamespaces {
    my ( $self, $ns ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    if ( defined $ns and $ns ) {
        $self->{NAMESPACES} = $ns;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 getNamespaces($self)

Gets and returns the hash containing the namespaces for the given request.

=cut

sub getNamespaces {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    if ( exists $self->{NAMESPACES} and $self->{NAMESPACES} ) {
        return $self->{NAMESPACES};
    }
    else {
        $logger->error( "Request namespace object not found." );
        return ();
    }
}

=head2 setRequestDOM($self, $dom)

Sets the request dom to the supplied value.

=cut

sub setRequestDOM {
    my ( $self, $dom ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );
    if ( defined $dom and $dom ) {
        $self->{REQUESTDOM} = $dom;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 finish($self)

Sends the response to the client and closes the connection

=cut

sub finish {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Request" );

    if ( exists $self->{CALL} and $self->{CALL} ) {
        my $end_time = [Time::HiRes::gettimeofday];
        my $diff = Time::HiRes::tv_interval $self->{START_TIME}, $end_time;
        $logger->info( "Total service time for request from " . $self->{CALL}->peerhost() . ": " . $diff . " seconds" );
        $self->{CALL}->send_response( $self->{RESPONSE} );
        $self->{CALL}->close;
        delete $self->{CALL};
        $logger->debug( "Closing call." );
    }
    return;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<XML::LibXML>, L<English>, L<perfSONAR_PS::Common>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Request.pm 4475 2010-09-29 13:18:06Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
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
