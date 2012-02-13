package perfSONAR_PS::Client::Parallel::LS;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Client::Parallel::LS

=head1 DESCRIPTION

Simple LS client that lets queries run in parallel.

=cut

use fields 'LOGGER', 'CLIENT', 'NEEDS_FORMAT';

use Data::Dumper;
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

    $self->{NEEDS_FORMAT} = ();

    $self->{CLIENT} = perfSONAR_PS::Client::Parallel::Simple->new();

    my $res = $self->{CLIENT}->init();
    if ( $res ) {
        return $res;
    }

    return 0;
}

=head2 add_query ({ url => 1, xquery => 0, subject => 0, format => 0, event_type => 0, timeout => 0 })

Adds the specified query to the queue. The query can either be an xquery or a
discovery-like subject query. The format parameter can be used to specify
whether the responses should be encoded. The event_type can be used to specify
which event type to send.  The url is a string containing the URL. If the
'timeout' parameter is specified, that request will only be waited for that
amount of time before timing out. The function returns a string value that can
be compared against the results to see which request a given response
corresponds to.

=cut

sub add_query {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            url        => 1,
            xquery     => 0,
            subject    => 0,
            format     => 0,
            event_type => 0,
            timeout    => 0,
        }
    );

    $self->{LOGGER}->debug( "Adding query to " . $args->{url} );

    if ( $args->{xquery} and $args->{subject} ) {
        $self->{LOGGER}->error( "Choose either 'xquery' XOR 'subject' parameter." );
        return;
    }

    unless ( $args->{xquery} or $args->{subject} ) {
        $self->{LOGGER}->error( "Need either 'xquery' or 'subject' parameter." );
        return;
    }

    my $metadata = q{};
    my %ns       = ();

    if ( $args->{subject} ) {
        %ns = (
            xquery  => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/",
            summary => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/",
            nmtb    => "http://ogf.org/schema/network/topology/base/20070828/",
            nmtl3   => "http://ogf.org/schema/network/topology/l3/20070828/"
        );

        $metadata .= $args->{subject};
        if ( exists $args->{event_type} and $args->{event_type} ) {
            $metadata .= "    <nmwg:eventType>" . $args->{event_type} . "</nmwg:eventType>\n";
        }
        else {
            $metadata .= "    <nmwg:eventType>http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0</nmwg:eventType>\n";
        }
    }
    else {
        %ns = ( xquery => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/" );

        $metadata .= "    <xquery:subject id=\"subject." . genuid() . "\" xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/\">\n";
        $metadata .= $args->{xquery};
        $metadata .= "    </xquery:subject>\n";

        if ( exists $args->{event_type} and $args->{event_type} ) {
            $metadata .= "    <nmwg:eventType>" . $args->{event_type} . "</nmwg:eventType>\n";
        }
        else {
            $metadata .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0</nmwg:eventType>\n";
        }

        if ( exists $args->{format} and $args->{format} ) {
            $metadata .= "  <xquery:parameters id=\"parameters." . genuid() . "\" xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/\">\n";
            $metadata .= "    <nmwg:parameter name=\"lsOutput\">native</nmwg:parameter>\n";
            $metadata .= "  </xquery:parameters>\n";
        }
    }

    $self->{LOGGER}->debug( "Request: " . $self->createLSRequest( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) );

    my $cookie = $self->{CLIENT}->add_request( { url => $args->{url}, timeout => $args->{timeout}, request => $self->createLSRequest( { type => "LSQueryRequest", ns => \%ns, metadata => $metadata } ) } );

    if ( $args->{format} ) {
        $self->{NEEDS_FORMAT}->{$cookie} = 1;
    }

    return $cookie;
}

=head2 wait_all ({ parallelism => 0, timeout => 0 })

Sends all the queries and waits for the responses. If the timeout parameter is
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

    my $results = $self->{CLIENT}->wait_all( { timeout => $args->{timeout}, parallelism => $args->{parallelism} } );

    $self->{LOGGER}->debug( "Based returned something" );

    foreach my $key ( keys %$results ) {
        my $response_info = $results->{$key};
        my $cookie        = $response_info->{cookie};

        $self->{LOGGER}->debug( "Now in " . $response_info->{url} );

        if ( $response_info->{error_msg} ) {
            $self->{LOGGER}->debug( "Skipping " . $response_info->{url} . ": " . $response_info->{error_msg} );
            next;
        }

        $self->{LOGGER}->debug( "Scanning " . $response_info->{url} );

        foreach my $d ( $response_info->{content}->getChildrenByTagName( "nmwg:data" ) ) {
            foreach my $m ( $response_info->{content}->getChildrenByTagName( "nmwg:metadata" ) ) {
                my $md_id    = $m->getAttribute( "id" );
                my $md_idref = $m->getAttribute( "metadataIdRef" );
                my $d_idref  = $d->getAttribute( "metadataIdRef" );

                if ( $md_id eq $d_idref ) {
                    $self->{LOGGER}->debug( "Found pair" );
                    my $eventType = extract( find( $m, "./nmwg:eventType", 1 ), 0 );
                    $self->{LOGGER}->debug( "Done extracting event type" );
                    if ( $eventType ) {
                        $response_info->{"event_type"} = $eventType;
                        if ( $eventType =~ m/^success/mx ) {
                            $self->{LOGGER}->debug( "Finding datum" );
                            my $datum = find( $d, './*[local-name()="datum"]', 1 );
                            $self->{LOGGER}->debug( "Unescaping string" );
                            $datum = unescapeString( $datum ) if ( $self->{NEEDS_FORMAT}->{$cookie} );
                            $self->{LOGGER}->debug( "Saving" );
                            my $stime = time;
                            $response_info->{"content"} = $datum;
                            my $etime = time;
                            $self->{LOGGER}->debug( "Done Saving (" . ( $etime - $stime ) . ")" );
                        }
                        elsif ( $eventType eq "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0" ) {
                            my $content = "<nmwgr:datum xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" xmlns:nmwgr=\"http://ggf.org/ns/nmwg/result/2.0/\">";
                            foreach my $data ( $response_info->{content}->getChildrenByTagName( "nmwg:data" ) ) {
                                $self->{LOGGER}->debug( "Unescaping data" );
                                $data = unescapeString( $data ) if ( $self->{NEEDS_FORMAT}->{$cookie} );
                                $self->{LOGGER}->debug( "Saving" );
                                $content .= $data->toString;
                                $self->{LOGGER}->debug( "Done Saving" );
                            }
                            $content .= "</nmwgr:datum>";

                            my $parser = XML::LibXML->new();
                            my $doc    = $parser->parse_string( $content );

                            $response_info->{"content"} = $doc->getDocumentElement;
                        }
                        else {
                            $self->{LOGGER}->debug( "Finding nmwgr" );
                            $response_info->{"content"} = extract( find( $d, "./nmwgr:datum", 1 ), 0 );
                            unless ( $response_info->{"content"} ) {
                                $response_info->{"content"} = extract( find( $d, "./nmwg:datum", 1 ), 0 );
                            }
                        }
                    }
                    else {
                        my $datum = find( $d, './*[local-name()="datum"]', 1 );
                        $response_info->{"content"} = $datum->toString;
                    }
                }

                goto RESPONSE_FINISHED;
            }
        }

        $response_info->{error_msg} = 'No metadata/data pairs in response';
        $response_info->{content}   = undef;

    RESPONSE_FINISHED:
    }

    $self->{LOGGER}->debug( "Returning LS" );

    return $results;
}

=head2 createLSRequest($self, { type, metadata, ns, data })

Creates the basic message structure for communication with the LS.  The type
argument is used to insert a message type (LSRegisterRequest,
LSDeregisterRequest, LSKeepaliveRequest, LSKeyRequest, LSQueryRequest).  The
metadata argument must contain metadata (a service block, a key, or an xquery).
The optional ns hash reference can contain namespace to prefix mappings and
the data block can optionally contain data (in the case of register and
deregister messages).  The fully formed message is returned from this function.

=cut

sub createLSRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { type => 1, metadata => 1, ns => 0, data => 0 } );

    my $request = q{};
    my $mdId    = "metadata." . genuid();
    $request .= "<nmwg:message type=\"" . $parameters->{type} . "\" id=\"message." . genuid() . "\"";
    $request .= " xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"";
    if ( exists $parameters->{ns} and $parameters->{ns} ) {
        foreach my $n ( keys %{ $parameters->{ns} } ) {
            $request .= " xmlns:" . $n . "=\"" . $parameters->{ns}->{$n} . "\"";
        }
    }
    $request .= ">\n";
    $request .= "  <nmwg:metadata id=\"metadata." . $mdId . "\">\n";
    $request .= $parameters->{metadata};
    $request .= "  </nmwg:metadata>\n";
    if ( exists $parameters->{data} and $parameters->{data} and $#{ $parameters->{data} } > -1 ) {
        $request .= "  <nmwg:data metadataIdRef=\"metadata." . $mdId . "\" id=\"data." . genuid() . "\">\n";
        foreach my $data ( @{ $parameters->{data} } ) {
            $request .= $data;
        }
        $request .= "  </nmwg:data>\n";
    }
    else {
        $request .= "  <nmwg:data metadataIdRef=\"metadata." . $mdId . "\" id=\"data." . genuid() . "\" />\n";
    }
    $request .= "</nmwg:message>\n";

    return $request;
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

