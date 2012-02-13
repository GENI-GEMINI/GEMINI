package perfSONAR_PS::Client::Parallel::Echo;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Client::Parallel::Echo

=head1 DESCRIPTION

Echo client that lets echos run in parallel.

=cut

use fields 'LOGGER', 'CLIENT';

use Log::Log4perl qw(get_logger :nowarn);

use perfSONAR_PS::Common;
use perfSONAR_PS::XML::Document;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Utils::ParameterValidation;

use perfSONAR_PS::Client::Parallel::Simple;

=head2 new({})
Create a new object
=cut

sub new {
    my ( $package ) = @_;

    my $self = fields::new( $package );

    $self->{LOGGER} = get_logger( $package );

    return $self;
}

=head2 init({})
Initializes the client. Returns 0 on success and -1 on failure.
=cut

sub init {
    my ( $self ) = @_;

    $self->{CLIENT} = perfSONAR_PS::Client::Parallel::Simple->new();

    my $res = $self->{CLIENT}->init();
    if ( $res ) {
        return $res;
    }

    return 0;
}

=head2 add_ping ({ url => 1, event_type => 0 })

Adds the specified ping request to the queue. The url is a string containing
the service URL.  The function returns a string value that can be compared
against the results to see which request a given response corresponds to.

=cut

sub add_ping {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            url        => 1,
            event_type => 0,
        }
    );

    my $event_type = "http://schemas.perfsonar.net/tools/admin/echo/2.0";
    if ( $args->{event_type} ) {
        $event_type = $args->{event_type};
    }

    my $doc = perfSONAR_PS::XML::Document->new();
    $self->createEchoRequest( { output => $doc, event_type => $event_type } );

    return $self->{CLIENT}->add_request( { url => $args->{url}, request => $doc->getValue() } );
}

=head2 wait_all ({ parallelism => 0, timeout => 0 })

Sends all the echo requests and waits for the responses. If the timeout parameter is
set, the function should take no longer than the specified time. THe
parallelism parameter can be used to specify how many requests can be
outstanding at a given moment. The response consists of a hash keyed on the
identifier returned by add_request. The value is a hash containing a "status"
field with "success" or "error" and either a "content" field containing an "up"
or "down" response or an "error_msg" field containing the error message.

=cut

sub wait_all {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            timeout     => 0,
            parallelism => 0,
        }
    );

    my $results = $self->{CLIENT}->wait_all( { timeout => $args->{timeout}, parallelism => $args->{parallelism} } );

    # Filter the results into 'up' and 'down' messages

    foreach my $key ( keys %$results ) {
        my $response_info = $results->{$key};

        next if ( $response_info->{error_msg} );

        foreach my $d ( $response_info->{content}->getChildrenByTagName( "nmwg:data" ) ) {
            foreach my $m ( $response_info->{content}->getChildrenByTagName( "nmwg:metadata" ) ) {
                my $md_id    = $m->getAttribute( "id" );
                my $md_idref = $m->getAttribute( "metadataIdRef" );
                my $d_idref  = $d->getAttribute( "metadataIdRef" );

                if ( $md_id eq $d_idref ) {
                    my $eventType = findvalue( $m, "nmwg:eventType" );

                    $eventType =~ s/\s*//g;

                    if ( $eventType =~ /^success\./ ) {
                        $response_info->{content} = 'up';
                        goto RESPONSE_FINISHED;
                    }
                }
            }
        }

        $response_info->{content} = 'down';

    RESPONSE_FINISHED:
    }

    return $results;
}

=head2 createEchoRequest($self, $output)

Create the EchoRequest message.

=cut

sub createEchoRequest {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            output     => 1,
            event_type => 1,
        }
    );

    my $output     = $args->{output};
    my $event_type = $args->{event_type};

    my $messageID = "message." . genuid();
    my $mdID      = "metadata." . genuid();
    my $dID       = "data." . genuid();

    startMessage( $output, $messageID, undef, "EchoRequest", q{}, undef );
    getResultCodeMetadata( $output, $mdID, q{}, $event_type );
    createData( $output, $dID, $mdID, q{}, undef );
    endMessage( $output );

    $self->{LOGGER}->debug( "Finished creating echo request" );
    return 0;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<perfSONAR_PS::Common>, L<perfSONAR_PS::XML::Document>,
L<perfSONAR_PS::Messages>, L<perfSONAR_PS::Utils::ParameterValidation>,
L<perfSONAR_PS::Client::Parallel::Simple>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

