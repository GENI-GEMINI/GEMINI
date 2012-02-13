package perfSONAR_PS::Client::Echo;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'URI', 'EVENT_TYPE';

=head1 NAME

perfSONAR_PS::Client::Echo

=head1 DESCRIPTION

A module that provides methods for interacting with perfSONAR Echo services.
This module allows one to test whether or not a perfSONAR service is running by
testing by pinging it using the standardized pS ping request.

The module is to be treated as an object, where each instance of the object
represents a connection to an endpoint. Each method may then be invoked on the
object for the specific endpoint.  

=cut

use Log::Log4perl qw(get_logger :nowarn);
use perfSONAR_PS::Common;
use perfSONAR_PS::Transport;
use perfSONAR_PS::Messages;
use perfSONAR_PS::XML::Document;

=head2 new($package, $uri_string, $eventType)

The new function takes a URI connection string as its first argument. This
specifies which service to interact with. The function can take an optional
eventType argument which can be used if a service only supports a specific echo
request event type.

=cut

sub new {
    my ( $package, $uri_string, $eventType ) = @_;

    my $self = fields::new( $package );

    if ( defined $uri_string and $uri_string ) {
        $self->{"URI"} = $uri_string;
    }
    if ( not defined $eventType or $eventType eq q{} ) {
        $eventType = "http://schemas.perfsonar.net/tools/admin/echo/2.0";
    }

    $self->{"EVENT_TYPE"} = $eventType;
    return $self;
}

=head2 setEventType($self, $eventType)

The setEventType function changes the eventType that the instance uses.

=cut

sub setEventType {
    my ( $self, $eventType ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Client::Echo" );

    if ( not defined $eventType or $eventType eq q{} ) {
        $eventType = "http://schemas.perfsonar.net/tools/admin/echo/2.0";
    }
    $self->{EVENT_TYPE} = $eventType;
    return;
}

=head2 setURIString($self, $uri_string)

The setURIString function changes the MA that the instance uses.

=cut

sub setURIString {
    my ( $self, $uri_string ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Client::Echo" );

    $self->{URI} = $uri_string if defined $uri_string and $uri_string;
    return;
}

=head2 createEchoRequest($self, $output)

Create the EchoRequest message.

=cut

sub createEchoRequest {
    my ( $self, $output ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Client::Echo" );

    my $messageID = "message." . genuid();
    my $mdID      = "metadata." . genuid();
    my $dID       = "data." . genuid();

    startMessage( $output, $messageID, undef, "EchoRequest", q{}, undef );
    getResultCodeMetadata( $output, $mdID, q{}, $self->{EVENT_TYPE} );
    createData( $output, $dID, $mdID, q{}, undef );
    endMessage( $output );

    $logger->debug( "Finished creating echo request" );
    return 0;
}

=head2 ping($self)

The ping function is used to test if the service is up. It returns an array
containing two values. The first value is a number which specifies whether the
ping succeeded. If it's 0, that means the ping succeeded and the second value
is undefined. If it is -1, that means the ping failed and the second value
contains an error message.

=cut

sub ping {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Client::Echo" );

    unless ( exists $self->{URI} ) {
        return ( -1, "Invalid URI specified \"\"" );
    }

    my ( $host, $port, $endpoint, $scheme ) = &perfSONAR_PS::Transport::splitURI( $self->{URI} );
    if ( not defined $host and not defined $port and not defined $endpoint ) {
        return ( -1, "Invalid URI specified \"" . $self->{URI} . "\"" );
    }

    my $doc = perfSONAR_PS::XML::Document->new();
    $self->createEchoRequest( $doc );

    my $timeout = 15;
    my ( $status, $res ) = consultArchive( $host, $port, $endpoint, $scheme, $doc->getValue(), $timeout );
    if ( $status != 0 ) {
        my $msg = "Error contacting service \"" . $self->{URI} . "\" : $res";
        $logger->error( $msg );
        return ( -1, $msg );
    }

    $logger->debug( "Response from \"" . $self->{URI} . "\": " . $res->toString );

    foreach my $d ( $res->getChildrenByTagName( "nmwg:data" ) ) {
        foreach my $m ( $res->getChildrenByTagName( "nmwg:metadata" ) ) {
            my $md_id    = $m->getAttribute( "id" );
            my $md_idref = $m->getAttribute( "metadataIdRef" );
            my $d_idref  = $d->getAttribute( "metadataIdRef" );

            if ( $md_id eq $d_idref ) {
                my $eventType = findvalue( $m, "nmwg:eventType" );

                $eventType =~ s/\s*//g;

                if ( $eventType =~ /^success\./ ) {
                    return ( 0, q{} );
                }
            }
        }
    }
    return ( -1, "No successful return for \"" . $self->{URI} . "\"." );
}

1;

__END__

=head1 SYNOPSIS

	use perfSONAR_PS::Client::Echo;

	my $echo_client = new perfSONAR_PS::Client::Echo("http://localhost:4801/axis/services/status");
	if (not defined $echo_client) {
		print "Problem creating echo client for service\n";
		exit(-1);
	}

	my ($status, $res) = $echo_client->ping;
	if ($status != 0) {
		print "Problem pinging service: $res\n";
		exit(-1);
	}

=head1 SEE ALSO

L<Log::Log4perl>, L<perfSONAR_PS::Common>, L<perfSONAR_PS::Transport>,
L<perfSONAR_PS::Messages>, L<perfSONAR_PS::XML::Document>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Echo.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE
 
You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT
 
Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
