package perfSONAR_PS::Client::Parallel::Simple;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'LOGGER', 'REQUESTS';

=head1 NAME

perfSONAR_PS::Client::Parallel::Simple

=head1 DESCRIPTION

Very basic "perfsonar" client. Allows adding multiple requests and then running
them in parallel.

=cut

use Log::Log4perl qw(get_logger :nowarn);
use English qw( -no_match_vars );
use Data::Dumper;

# Used to allow asynchronous HTTP requests
use AnyEvent;
use AnyEvent::HTTP;

use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Utils::ParameterValidation;

=head2 =head2 new($package, $contactHost, $contactPort, $contactEndPoint)

The 'contactHost', 'contactPort', and 'contactEndPoint' set the values that are
used to send information to a remote host.  All values can be left blank and
set via the various set functions.

=cut

sub new {
    my ( $package ) = @_;

    my $self = fields::new( $package );

    $self->{REQUESTS} = ();
    $self->{LOGGER}   = get_logger( $package );

    return $self;
}

sub init {
    my ( $self ) = @_;

    return 0;
}

=head2 add_request ({ request => 1, url => 1, timeout => 0 })

Adds the specified request to the queue. The request is a string consisting of
a perfSONAR message. The url is a string containing the URL. If the 'timeout'
parameter is specified, that request will only be waited for that amount of
time before timing out. The function returns a string value that can be
compared against the results to see which request a given response corresponds
to.

=cut

sub add_request {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            request => 1,
            url     => 1,
            timeout => 0,
        }
    );

    my $cookie = genuid();

    my $string = "<SOAP-ENV:Envelope xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\"\n";
    $string .= "                   xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"\n";
    $string .= "                   xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n";
    $string .= "                   xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\">\n";
    $string .= "  <SOAP-ENV:Header/>\n";
    $string .= "  <SOAP-ENV:Body>\n";
    $string .= $args->{request};
    $string .= "  </SOAP-ENV:Body>\n";
    $string .= "</SOAP-ENV:Envelope>\n";

    $self->{LOGGER}->debug( "QUERY TIMEOUT: " . $args->{timeout} ) if ( $args->{timeout} );

    $self->{REQUESTS}->{$cookie} = { request => $string, url => $args->{url}, cookie => $cookie, timeout => $args->{timeout} };

    return $cookie;
}

=head2 wait_all ({ parallelism => 0, timeout => 0 })

Sends all the requests and waits for the responses. If the timeout parameter is
set, the function should take no longer than the specified time. THe
parallelism parameter can be used to specify how many requests can be
outstanding at a given moment. The response consists of a hash keyed on the
identifier returned by add_request. The value is a hash containing a "status"
field with "success" or "error" and either a "content" field containing the
response or an "error_msg" field containing the error message.

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

    my $wait_all_start = time;

    my $parallelism = 7;
    if ( defined $args->{parallelism} ) {
        $parallelism = $args->{parallelism};
    }

    my %results              = ();
    my @outstanding_requests = [];

    my @requests = ();
    foreach my $key ( keys %{ $self->{REQUESTS} } ) {
        push @requests, $self->{REQUESTS}->{$key};
    }

    if ( $parallelism <= 0 or $parallelism > scalar( @requests ) ) {
        $parallelism = scalar( @requests );
    }

    my $start_time = time;

    my $outstanding = 0;
    my $curr_cv     = AnyEvent->condvar;
    my $curr_slot   = 0;
    my @slots       = ();

    for my $i ( 0 .. $parallelism ) {
        push @slots, $i;
    }

    if ( $args->{timeout} ) {

        # Set the timeout timer
        AnyEvent->timer( after => $args->{timeout}, cb => sub { print "TIMEOUT"; $curr_cv->send } );
    }

    my %running = ();

    while ( scalar( @requests ) > 0 ) {
        if ( $outstanding < $parallelism ) {

            my $request = pop( @requests );

            my $timeout;
            my $curr_time = time;
            if ( $request->{timeout} ) {
                $timeout = $request->{timeout};
                $self->{LOGGER}->debug( "Setting timeout to $timeout" );
            }
            if ( $args->{timeout} ) {
                if ( not $timeout or $curr_time + $timeout > $start_time + $args->{timeout} ) {
                    $timeout = $start_time + $args->{timeout} - $curr_time;
                    $self->{LOGGER}->debug( "Setting timeout to $timeout" );
                }
            }

            my $method_uri = "http://ggf.org/ns/nmwg/base/2.0/message/";

            $self->{LOGGER}->debug( "Spawning new request: " . $request->{url} );

            my $request_start_time = time;
            
            my $tls_ctx = { cache => 1, sslv2 => 1 };
            if ( $request->{url} =~ /^https/ ) {
                # Create the tls_ctx that will be used by AnyEvent::Handle
                if ( exists $ENV{ "HTTPS_CERT_FILE" } and $ENV{ "HTTPS_CERT_FILE" } ) {
                    $tls_ctx->{'cert_file'} = $ENV{ "HTTPS_CERT_FILE" };
                }
                if ( exists $ENV{ "HTTPS_KEY_FILE" } and $ENV{ "HTTPS_KEY_FILE" } ) {
                    $tls_ctx->{'key_file'} = $ENV{ "HTTPS_KEY_FILE" };
                }
                if ( exists $ENV{ "HTTPS_CERT_PASSWORD" } and $ENV{ "HTTPS_CERT_PASSWORD" } ) {
                    $tls_ctx->{'cert_password'} = $ENV{ "HTTPS_CERT_PASSWORD" };
                }
            }
            
            my $req = http_request
                POST    => $request->{url},
                body    => $request->{request},
                timeout => $timeout,
                tls_ctx => $tls_ctx,
                headers => { "SOAPAction" => $method_uri, "Content-Type" => "text/xml" },
                sub {
                my ( $body, $header ) = @_;

                my %result = ();
                $result{cookie} = $request->{cookie};
                $result{url}    = $request->{url};

                $body = "" unless ( $body );

                # Save the results
                if ( $header->{Status} =~ /^2/ ) {
                    $result{status}  = "success";
                    $result{content} = $body;
                }
                else {
                    $result{status}    = "error";
                    $result{error_msg} = $header->{Status} . ": " . $header->{Reason};
                }

                $result{total_duration}   = time - $wait_all_start;
                $result{request_duration} = time - $request_start_time;
                $result{queue_duration}   = $request_start_time - $wait_all_start;

                $results{ $request->{cookie} } = \%result;

                if ( $result{status} eq "success" ) {
                    $self->{LOGGER}->debug( "Finished " . $request->{url} . "( " . $result{request_duration} . "/" . $result{queue_duration} . "/" . $result{total_duration} . ")" );
                }
                else {
                    $self->{LOGGER}->debug( "Finished (http error) " . $request->{url} . "( " . $result{request_duration} . "/" . $result{queue_duration} . "/" . $result{total_duration} . "): " . $result{error_msg} );
                }

                #$self->{LOGGER}->debug("Result ".$request->{url}.": ".$body);

                delete( $running{ $request->{cookie} } );

                $outstanding--;

                $curr_cv->send;
                return;
                };

            my %running_info = ();
            $running_info{start}           = time;
            $running_info{url}             = $request->{url};
            $running_info{timeout}         = $timeout;
            $running_info{request}         = $req;
            $running{ $request->{cookie} } = \%running_info;

            $outstanding++;
        }

        if ( scalar( @requests ) == 0 ) {

            # wait for the outstanding requests to finish
            while ( $outstanding > 0 ) {
                $self->{LOGGER}->debug( "Waiting for outstanding: $outstanding" );
                $self->{LOGGER}->debug( "Running:" );
                foreach my $key ( keys %running ) {

                    #$self->{LOGGER}->debug("   -Seconds: ".(time-$running{$key}->{start})."/".$running{$key}->{timeout}." URL: ".$running{$key}->{url});
                    $self->{LOGGER}->debug( "   -Seconds: " . ( time - $running{$key}->{start} ) . "/0 URL: " . $running{$key}->{url} );
                }

                $curr_cv->recv;
                $self->{LOGGER}->debug( "Exited recv" );

                $self->{LOGGER}->debug( "Before condvar" );
                $curr_cv = AnyEvent->condvar;    # reset the condition variable
                $self->{LOGGER}->debug( "After condvar" );

                # when we're done, wait
                my $end_time = time;

                if ( $args->{timeout} ) {
                    goto OUT if ( $end_time - $start_time >= $args->{timeout} );
                }
            }
            $self->{LOGGER}->debug( "Outside outstanding loop" );
        }
        else {

            # wait for a request slot to become available.
            while ( $outstanding == $parallelism ) {
                $self->{LOGGER}->debug( "Waiting for a slot to open" );
                $self->{LOGGER}->debug( "Running:" );
                foreach my $key ( keys %running ) {

                    #$self->{LOGGER}->debug("   -Seconds: ".(time-$running{$key}->{start})."/".$running{$key}->{timeout}." URL: ".$running{$key}->{url});
                    $self->{LOGGER}->debug( "   -Seconds: " . ( time - $running{$key}->{start} ) . "/0 URL: " . $running{$key}->{url} );
                }

                $curr_cv->recv;
                $curr_cv = AnyEvent->condvar;    # reset the condition variable

                my $end_time = time;

                if ( $args->{timeout} ) {
                    goto OUT if ( $end_time - $start_time >= $args->{timeout} );
                }
            }
        }
    }

    # Get rid of any outstanding requests
    $self->{LOGGER}->debug( "Getting rid of any remaining running processes" );
    foreach my $key ( keys %running ) {
        $running{$key}->{request} = undef;
    }
    $self->{LOGGER}->debug( "Done getting rid of any remaining running processes" );

OUT:

    # Parse the results
    foreach my $key ( keys %results ) {
        if ( $results{$key}->{status} eq "success" ) {
            my $doc;
            eval {
                $self->{LOGGER}->debug( "Parsing: " . $results{$key}->{url} );
                my $parser        = XML::LibXML->new();
                my $xpath_context = XML::LibXML::XPathContext->new();

                $xpath_context->registerNs( "nmwg", "http://ggf.org/ns/nmwg/base/2.0/" );

                $doc = $parser->parse_string( $results{$key}->{content} );
                my $nodeset = $xpath_context->find( "//nmwg:message", $doc->getDocumentElement );
                if ( $nodeset->size <= 0 ) {
                    die( "Message element not found in response" );
                }
                elsif ( $nodeset->size > 1 ) {
                    die( "Too many message elements found in response" );
                }
                else {
                    my $nmwg_msg = $nodeset->get_node( 1 );
                    $results{$key}->{content} = $nmwg_msg;
                }
            };
            if ( $EVAL_ERROR ) {
                $results{$key}->{status}    = "error";
                $results{$key}->{error_msg} = "Error parsing response: $EVAL_ERROR";
            }
        }
    }

    $self->{LOGGER}->debug( "Returning base" );

    return \%results;
}

1;

__END__

=head1 SEE ALSO

L<Log::Log4perl>, L<English>, L<Data::Dumper>, L<AnyEvent>, L<AnyEvent::HTTP>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Messages>,
L<perfSONAR_PS::Utils::ParameterValidation>

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

