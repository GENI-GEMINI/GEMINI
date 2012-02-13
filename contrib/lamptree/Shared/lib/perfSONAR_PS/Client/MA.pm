package perfSONAR_PS::Client::MA;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'INSTANCE', 'LOGGER', 'ALIVE';

=head1 NAME

perfSONAR_PS::Client::MA

=head1 DESCRIPTION

API for calling an MA from a client or another service. Module with a very basic
API to some common MA functions.

=cut

use Log::Log4perl qw( get_logger );
use Params::Validate qw( :all );
use English qw( -no_match_vars );

use perfSONAR_PS::Common qw( genuid makeEnvelope find extract );
use perfSONAR_PS::Transport;
use perfSONAR_PS::Client::Echo;
use perfSONAR_PS::Utils::ParameterValidation;

=head2 new($package { instance })

Constructor for object.  Optional argument of 'instance' is the LS instance
to be contacted for interaction.  This can also be set via 'setInstance'.

=cut

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams( @args, { instance => 0 } );

    my $self = fields::new( $package );
    $self->{ALIVE}  = 0;
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Client::MA" );
    if ( exists $parameters->{"instance"} and $parameters->{"instance"} ) {
        $self->{INSTANCE} = $parameters->{"instance"};
    }
    return $self;
}

=head2 setInstance($self { instance })

Required argument 'instance' is the LS instance to be contacted for queries.  

=cut

sub setInstance {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { instance => 1 } );

    $self->{ALIVE}    = 0;
    $self->{INSTANCE} = $parameters->{"instance"};
    return;
}

=head2 callMA($self { message })

Calls the MA instance with the sent message and returns the response (if any). 

=cut

sub callMA {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { message => 1, timeout => 0 } );

    unless ( $self->{INSTANCE} ) {
        $self->{LOGGER}->error( "Instance not defined." );
        return;
    }

    unless ( $self->{ALIVE} ) {
        my $echo_service = perfSONAR_PS::Client::Echo->new( $self->{INSTANCE} );
        my ( $status, $res ) = $echo_service->ping();
        if ( $status == -1 ) {
            $self->{LOGGER}->error( "Ping to " . $self->{INSTANCE} . " failed: $res" );
            return;
        }
        $self->{ALIVE} = 1;
    }

    my ( $host, $port, $endpoint, $scheme ) = perfSONAR_PS::Transport::splitURI( $self->{INSTANCE} );
    unless ( defined $host and defined $port and defined $endpoint ) {
        return;
    }

    my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint, $scheme );
    unless ( $sender ) {
        $self->{LOGGER}->error( "LS could not be contaced." );
        return;
    }

    my $error = q{};
    my $responseContent = $sender->sendReceive( makeEnvelope( $parameters->{message} ), $parameters->{timeout}, \$error );
    if ( $error ) {
        $self->{ALIVE} = 0;
        $self->{LOGGER}->error( "sendReceive failed: $error" );
        return;
    }

    my $msg    = q{};
    my $parser = XML::LibXML->new();
    if ( defined $responseContent and $responseContent and ( not $responseContent =~ m/^\d+/xm ) ) {
        my $doc = q{};
        eval { $doc = $parser->parse_string( $responseContent ); };
        if ( $EVAL_ERROR ) {
            $self->{LOGGER}->error( "Parser failed: " . $EVAL_ERROR );
        }
        else {
            $msg = $doc->getDocumentElement->getElementsByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "message" )->get_node( 1 );
        }
    }
    else {
        $self->{ALIVE} = 0;
    }
    return $msg;
}

=head2 metadataKeyRequest($self, { subject, eventTypes, parameters, start, end, resolution, consolidationFunction })

Perform a MetadataKeyRequest, the results are returned as a data/metadata pair.

=cut

sub metadataKeyRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { subject => 1, eventTypes => 1, parameters => 0, start => 0, end => 0, resolution => 0, consolidationFunction => 0 } );

    my $mdId    = "metadata." . genuid();
    my $dId     = "data." . genuid();
    my $content = "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"" . $mdId . "\">\n";

    if ( exists $parameters->{"subject"} and $parameters->{"subject"} ) {
        $content .= $parameters->{"subject"};
    }

    foreach my $et ( @{ $parameters->{"eventTypes"} } ) {
        $content .= "    <nmwg:eventType>" . $et . "</nmwg:eventType>\n";
    }
    if ( exists $parameters->{"parameters"} and $parameters->{"parameters"} ) {
        $content .= "    <nmwg:parameters id=\"parameters." . genuid() . "\">\n";
        foreach my $p ( keys %{ $parameters->{"parameters"} } ) {
            $content .= "      <nmwg:parameter name=\"" . $p . "\">" . $parameters->{"parameters"}->{$p} . "</nmwg:parameter>\n";
        }
        $content .= "    </nmwg:parameters>\n";
    }
    $content .= "  </nmwg:metadata>\n";

    if (   ( exists $parameters->{"start"} and $parameters->{"start"} )
        or ( exists $parameters->{"end"}                   and $parameters->{"end"} )
        or ( exists $parameters->{"resolution"}            and $parameters->{"resolution"} )
        or ( exists $parameters->{"consolidationFunction"} and $parameters->{"consolidationFunction"} ) )
    {
        $content .= "  <nmwg:metadata id=\"" . $mdId . ".chain\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
        $content .= "    <select:subject id=\"subject." . genuid() . "\" metadataIdRef=\"" . $mdId . "\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\"/>\n";
        $content .= "    <select:parameters id=\"parameters." . genuid() . "\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\">\n";
        if ( exists $parameters->{"start"} and $parameters->{"start"} ) {
            $content .= "      <nmwg:parameter name=\"startTime\">" . $parameters->{"start"} . "</nmwg:parameter>\n";
        }
        if ( exists $parameters->{"end"} and $parameters->{"end"} ) {
            $content .= "      <nmwg:parameter name=\"endTime\">" . $parameters->{"end"} . "</nmwg:parameter>\n";
        }
        if ( exists $parameters->{"resolution"} and $parameters->{"resolution"} ) {
            $content .= "      <nmwg:parameter name=\"resolution\">" . $parameters->{"resolution"} . "</nmwg:parameter>\n";
        }
        if ( exists $parameters->{"consolidationFunction"} and $parameters->{"consolidationFunction"} ) {
            $content .= "      <nmwg:parameter name=\"consolidationFunction\">" . $parameters->{"consolidationFunction"} . "</nmwg:parameter>\n";
        }
        $content .= "    </select:parameters>\n";
        $content .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/ops/select/2.0</nmwg:eventType> \n";
        $content .= "  </nmwg:metadata>\n";
        $content .= "  <nmwg:data id=\"" . $dId . "\" metadataIdRef=\"" . $mdId . ".chain\"/>\n";
    }
    else {
        $content .= "  <nmwg:data id=\"" . $dId . "\" metadataIdRef=\"" . $mdId . "\"/>\n";
    }

    my $msg = $self->callMA( { timeout => 30, message => $self->createMAMessage( { type => "MetadataKeyRequest", content => $content } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my %result = ();
    my $list   = find( $msg, "./nmwg:metadata", 0 );
    my @mdList = ();
    foreach my $md ( $list->get_nodelist ) {
        $md->setNamespace( "http://ggf.org/ns/nmwg/base/2.0/", "nmwg", 0 );
        push @mdList, $md->toString;
    }

    $list = find( $msg, "./nmwg:data", 0 );
    my @dList = ();
    foreach my $d ( $list->get_nodelist ) {
        $d->setNamespace( "http://ggf.org/ns/nmwg/base/2.0/", "nmwg", 0 );
        push @dList, $d->toString;
    }

    $result{"metadata"} = \@mdList;
    $result{"data"}     = \@dList;

    return \%result;
}

=head2 dataInfoRequest($self, { subject, eventTypes, parameters })

Perform a DataInfoRequest, the results are returned as a data/metadata pair.

=cut

sub dataInfoRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { subject => 1, eventTypes => 1, parameters => 0 } );

    my $mdId    = "metadata." . genuid();
    my $dId     = "data." . genuid();
    my $content = "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"" . $mdId . "\">\n";

    if ( exists $parameters->{"subject"} and $parameters->{"subject"} ) {
        $content .= $parameters->{"subject"};
    }

    foreach my $et ( @{ $parameters->{"eventTypes"} } ) {
        $content .= "    <nmwg:eventType>" . $et . "</nmwg:eventType>\n";
    }
    if ( exists $parameters->{"parameters"} and $parameters->{"parameters"} ) {
        $content .= "    <nmwg:parameters id=\"parameters." . genuid() . "\">\n";
        foreach my $p ( keys %{ $parameters->{"parameters"} } ) {
            $content .= "      <nmwg:parameter name=\"" . $p . "\">" . $parameters->{"parameters"}->{$p} . "</nmwg:parameter>\n";
        }
        $content .= "    </nmwg:parameters>\n";
    }
    $content .= "  </nmwg:metadata>\n";

    $content .= "  <nmwg:data id=\"" . $dId . "\" metadataIdRef=\"" . $mdId . "\"/>\n";

    my $msg = $self->callMA( { timeout => 30, message => $self->createMAMessage( { type => "DataInfoRequest", content => $content } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my %result = ();
    my $list   = find( $msg, "./nmwg:metadata", 0 );
    my @mdList = ();
    foreach my $md ( $list->get_nodelist ) {
        $md->setNamespace( "http://ggf.org/ns/nmwg/base/2.0/", "nmwg", 0 );
        push @mdList, $md->toString;
    }

    $list = find( $msg, "./nmwg:data", 0 );
    my @dList = ();
    foreach my $d ( $list->get_nodelist ) {
        $d->setNamespace( "http://ggf.org/ns/nmwg/base/2.0/", "nmwg", 0 );
        push @dList, $d->toString;
    }

    $result{"metadata"} = \@mdList;
    $result{"data"}     = \@dList;

    return \%result;
}

=head2 setupDataRequest($self, { subject, eventTypes, parameters, start, end, resolution, consolidationFunction })

Perform a SetupDataRequest, the results are returned as a data/metadata pair.

=cut

sub setupDataRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { subject => 0, eventTypes => 1, parameterblock => 0, parameters => 0, start => 0, end => 0, resolution => 0, consolidationFunction => 0 } );

    my $mdId    = "metadata." . genuid();
    my $dId     = "data." . genuid();
    my $content = "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"" . $mdId . "\">\n";

    if ( exists $parameters->{"subject"} and $parameters->{"subject"} ) {
        $content .= $parameters->{"subject"};
    }

    foreach my $et ( @{ $parameters->{"eventTypes"} } ) {
        $content .= "    <nmwg:eventType>" . $et . "</nmwg:eventType>\n";
    }

    if ( exists $parameters->{"parameterblock"} and $parameters->{"parameterblock"} ) {
        $content .= $parameters->{"parameterblock"};
    }
    elsif ( exists $parameters->{"parameters"} and $parameters->{"parameters"} ) {
        $content .= "    <nmwg:parameters id=\"parameters." . genuid() . "\">\n";
        foreach my $p ( keys %{ $parameters->{"parameters"} } ) {
            $content .= "      <nmwg:parameter name=\"" . $p . "\">" . $parameters->{"parameters"}->{$p} . "</nmwg:parameter>\n";
        }
        $content .= "    </nmwg:parameters>\n";
    }

    $content .= "  </nmwg:metadata>\n";

    if (   ( exists $parameters->{"start"} and $parameters->{"start"} )
        or ( exists $parameters->{"end"}                   and $parameters->{"end"} )
        or ( exists $parameters->{"resolution"}            and $parameters->{"resolution"} )
        or ( exists $parameters->{"consolidationFunction"} and $parameters->{"consolidationFunction"} ) )
    {
        $content .= "  <nmwg:metadata id=\"" . $mdId . ".chain\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
        $content .= "    <select:subject id=\"subject." . genuid() . "\" metadataIdRef=\"" . $mdId . "\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\"/>\n";
        $content .= "    <select:parameters id=\"parameters." . genuid() . "\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\">\n";
        if ( exists $parameters->{"start"} and $parameters->{"start"} ) {
            $content .= "      <nmwg:parameter name=\"startTime\">" . $parameters->{"start"} . "</nmwg:parameter>\n";
        }
        if ( exists $parameters->{"end"} and $parameters->{"end"} ) {
            $content .= "      <nmwg:parameter name=\"endTime\">" . $parameters->{"end"} . "</nmwg:parameter>\n";
        }
        if ( exists $parameters->{"resolution"} and $parameters->{"resolution"} ) {
            $content .= "      <nmwg:parameter name=\"resolution\">" . $parameters->{"resolution"} . "</nmwg:parameter>\n";
        }
        if ( exists $parameters->{"consolidationFunction"} and $parameters->{"consolidationFunction"} ) {
            $content .= "      <nmwg:parameter name=\"consolidationFunction\">" . $parameters->{"consolidationFunction"} . "</nmwg:parameter>\n";
        }
        $content .= "    </select:parameters>\n";
        $content .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/ops/select/2.0</nmwg:eventType> \n";
        $content .= "  </nmwg:metadata>\n";
        $content .= "  <nmwg:data id=\"" . $dId . "\" metadataIdRef=\"" . $mdId . ".chain\"/>\n";
    }
    else {
        $content .= "  <nmwg:data id=\"" . $dId . "\" metadataIdRef=\"" . $mdId . "\"/>\n";
    }

    my $msg = $self->callMA( { timeout => 30, message => $self->createMAMessage( { type => "SetupDataRequest", content => $content } ) } );
    unless ( $msg ) {
        $self->{LOGGER}->error( "Message element not found in return." );
        return;
    }

    my %result = ();
    my $list   = find( $msg, "./nmwg:metadata", 0 );
    my @mdList = ();
    foreach my $md ( $list->get_nodelist ) {
        $md->setNamespace( "http://ggf.org/ns/nmwg/base/2.0/", "nmwg", 0 );
        push @mdList, $md->toString;
    }

    $list = find( $msg, "./nmwg:data", 0 );
    my @dList = ();
    foreach my $d ( $list->get_nodelist ) {
        $d->setNamespace( "http://ggf.org/ns/nmwg/base/2.0/", "nmwg", 0 );
        push @dList, $d->toString;
    }

    $result{"metadata"} = \@mdList;
    $result{"data"}     = \@dList;

    return \%result;
}

=head2 createMAMessage($self, { type, metadata, ns, data })

Create a message to send to an MA instance.

=cut

sub createMAMessage {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { type => 1, content => 1 } );

    my $request = q{};
    $request .= "<nmwg:message type=\"" . $parameters->{type} . "\" id=\"message." . genuid() . "\"";
    $request .= " xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
    $request .= $parameters->{content};
    $request .= "</nmwg:message>\n";

    return $request;
}

1;

__END__

=head1 SYNOPSIS

    #!/usr/bin/perl -w

    use strict;
    use warnings;
    use perfSONAR_PS::Client::MA;

    my $metadata .= "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"m1\">\n";
    $metadata .= "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"s-in-16\">\n";
    $metadata .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
    $metadata .= "        <nmwgt:hostName>nms-rexp.salt.net.internet2.edu</nmwgt:hostName>\n";
    $metadata .= "        <nmwgt:ifName>eth0</nmwgt:ifName>\n";
    $metadata .= "        <nmwgt:direction>in</nmwgt:direction>\n";
    $metadata .= "      </nmwgt:interface>\n";
    $metadata .= "    </netutil:subject>\n";
    $metadata .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
    $metadata .= "  </nmwg:metadata>\n";
    $metadata .= "  <nmwg:data id=\"d1\" metadataIdRef=\"m1\"/>\n";

    my $ma = new perfSONAR_PS::Client::MA(
      { instance => "http://packrat.internet2.edu:8082/perfSONAR_PS/services/snmpMA"}
    );

    my $subject = "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"s-in-16\">\n";
    $subject .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
    $subject .= "        <nmwgt:hostName>nms-rexp.salt.net.internet2.edu</nmwgt:hostName>\n";
    $subject .= "        <nmwgt:ifName>eth0</nmwgt:ifName>\n";
    $subject .= "        <nmwgt:direction>in</nmwgt:direction>\n";
    $subject .= "      </nmwgt:interface>\n";
    $subject .= "    </netutil:subject>\n";

    my @eventTypes = ("http://ggf.org/ns/nmwg/characteristic/utilization/2.0");
    my %parameters = ();
    $parameters{"supportedEventType"} = "http://ggf.org/ns/nmwg/characteristic/utilization/2.0";

    my ( $sec, $frac ) = Time::HiRes::gettimeofday;

    my $result = $ma->metadataKeyRequest( { 
      consolidationFunction => "AVERAGE", 
      resolution => 30,
      start => ($sec-300), 
      end => $sec, 
      subject => $subject, 
      eventTypes => \@eventTypes, 
      parameters => \%parameters } );

    $result = $ma->setupDataRequest( { 
      consolidationFunction => "AVERAGE", 
      resolution => 30,
      start => ($sec-300), 
      end => $sec, 
      subject => $subject, 
      eventTypes => \@eventTypes, 
      parameters => \%parameters } );

=head1 SEE ALSO

L<Log::Log4perl>, L<Params::Validate>, L<English>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Transport>, L<perfSONAR_PS::Client::Echo>,
L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: MA.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut
