package perfSONAR_PS::Client::LS::Remote;

use strict;
use warnings;

our $VERSION = 3.2;

use fields 'LS_ORDER', 'LS_CONF', 'HINTS', 'LS', 'CONF', 'CHUNK', 'ALIVE', 'FIRST', 'LS_KEY', 'LOGGER', 'LIMIT';

=head1 NAME

perfSONAR_PS::Client::LS::Remote

=head1 DESCRIPTION

Provides functionality to services that wish to register with an hLS instance.
Capability exists to auto-discovery an hLS or supply a known instance.  This
module aims to offer simple methods for dealing with requests for information,
and the related tasks of interacting with backend storage.

=cut

use Log::Log4perl qw(get_logger);
use English qw( -no_match_vars );
use LWP::Simple;
use Net::Ping;
use XML::LibXML;
use perfSONAR_PS::Common;
use perfSONAR_PS::Transport;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Client::Echo;
use perfSONAR_PS::Client::gLS;

=head2 new ($package, ( $uri | \@uri ), \%conf, ( $hints | \@hints ) ) 

The parameters are the URI of the Lookup Service (scalar or arrayref), a conf
hashref describing the service for registration purposes, and a hints URL of 
gLS instances (scalar or arrayref) that can be used to auto-discover any LS.

The %conf can have 4 keys:

SERVICE_NAME - The name of the service registering data
SERVICE_ACCESSPOINT - The URL for the service registering data
SERVICE_TYPE - The type (MA, LS, etc) of the service registering data
SERVICE_DESCRIPTION - A description of the service registering data

=cut

sub new {
    my ( $package, $uri, $conf, $hints ) = @_;

    my $self = fields::new( $package );
    $self->{LS_ORDER} = ();
    $self->{LS_CONF}  = ();
    $self->{HINTS}    = ();
    $self->{CHUNK}    = 50;
    $self->{ALIVE}    = 0;
    $self->{FIRST}    = 1;

    # XXX JZ 3/23 - Set the hLS LIMIT to 3 for now
    $self->{LIMIT} = 3;

    undef $self->{LS};
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Client::LS::Remote" );

    if ( defined $uri and $uri ) {
        if ( ref( $uri ) eq "ARRAY" ) {
            foreach my $u ( @{$uri} ) {
                if ( $u =~ m/^http:\/\// ) {
                    $u =~ s/\s+//g;
                    push @{ $self->{LS_CONF} }, $u;
                }
                else {
                    $self->{LOGGER}->error( "URI \"" . $u . "\" must be of the form http://ADDRESS." );
                }
            }
        }
        else {
            if ( $uri =~ m/^http:\/\// ) {
                $uri =~ s/\s+//g;
                push @{ $self->{LS_CONF} }, $uri;
            }
            else {
                $self->{LOGGER}->error( "URI \"" . $uri . "\" must be of the form http://ADDRESS." );
            }
        }
    }

    if ( defined $hints and $hints ) {
        if ( ref( $hints ) eq "ARRAY" ) {
            foreach my $h ( @{$hints} ) {
                if ( $h =~ m/^http:\/\// ) {
                    $h =~ s/\s+//g;
                    push @{ $self->{HINTS} }, $h;
                }
                else {
                    $self->{LOGGER}->error( "HINTS \"" . $h . "\" must be of the form http://ADDRESS." );
                }
            }
        }
        else {
            if ( $hints =~ m/^http:\/\// ) {
                $hints =~ s/\s+//g;
                push @{ $self->{HINTS} }, $hints;
            }
            else {
                $self->{LOGGER}->error( "HINTS \"" . $hints . "\" must be of the form http://ADDRESS." );
            }
        }
    }

    $self->init();

    if ( defined $conf and $conf ) {
        $self->{CONF} = \%{$conf};
    }

    return $self;
}

=head2 setURI ($self, ( $uri | \@uri ) )

(Re-)Sets the value for the LS URI, this can be a scalar or arrayref

=cut

sub setURI {
    my ( $self, $uri ) = @_;

    if ( defined $uri and $uri ) {
        if ( ref( $uri ) eq "ARRAY" ) {
            foreach my $u ( @{$uri} ) {
                if ( $u =~ m/^http:\/\// ) {
                    $u =~ s/\s+//g;
                    push @{ $self->{LS_CONF} }, $u;
                }
                else {
                    $self->{LOGGER}->error( "URI \"" . $u . "\" must be of the form http://ADDRESS." );
                }
            }
        }
        else {
            if ( $uri =~ m/^http:\/\// ) {
                $uri =~ s/\s+//g;
                push @{ $self->{LS_CONF} }, $uri;
            }
            else {
                $self->{LOGGER}->error( "URI \"" . $uri . "\" must be of the form http://ADDRESS." );
            }
        }
        $self->init();
    }
    else {
        $self->{LOGGER}->error( "Missing argument." );
    }
    return;
}

=head2 setHints ($self, ( $hints | \@hints ) )

(Re-)Sets the value for the hints file, this can be a scalar or an arrayref

=cut

sub setHints {
    my ( $self, $hints ) = @_;

    if ( defined $hints and $hints ) {
        if ( ref( $hints ) eq "ARRAY" ) {
            foreach my $h ( @{$hints} ) {
                if ( $h =~ m/^http:\/\// ) {
                    $h =~ s/\s+//g;
                    push @{ $self->{HINTS} }, $h;
                }
                else {
                    $self->{LOGGER}->error( "Hints \"" . $h . "\" must be of the form http://ADDRESS." );
                }
            }
        }
        else {
            if ( $hints =~ m/^http:\/\// ) {
                $hints =~ s/\s+//g;
                push @{ $self->{HINTS} }, $hints;
            }
            else {
                $self->{LOGGER}->error( "Hints \"" . $hints . "\" must be of the form http://ADDRESS." );
            }
        }
        $self->init();
    }
    else {
        $self->{LOGGER}->error( "Missing argument." );
    }
    return;
}

=head2 setConf ($self, \%conf)

(Re-)Sets the value for the 'conf' hash.

=cut

sub setConf {
    my ( $self, $conf ) = @_;

    if ( defined $conf and $conf ) {
        $self->{CONF} = \%{$conf};
    }
    else {
        $self->{LOGGER}->error( "Missing argument." );
    }
    return;
}

=head2 clearURIs( $self, {} )

Clear the URI list.

=cut

sub clearURIs {
    my ( $self ) = @_;
    $self->{LS_CONF} = ();
    return;
}

=head2 clearHints( $self, {} )

Clear the Hints list.

=cut

sub clearHints {
    my ( $self ) = @_;
    $self->{HINTS} = ();
    return;
}

=head2 init( $self, { } )

Used to extract gLS instances from some hints file, order the resulting hLS
instances (and specified hLSs) by connectivity.

=cut

sub init {
    my ( $self ) = @_;

    $self->{LS_ORDER} = ();
    my %temp      = ();
    my $lsCounter = 0;
    foreach my $ls ( @{ $self->{LS_CONF} } ) {
        my $echo_service = perfSONAR_PS::Client::Echo->new( $ls );
        my ( $status, $res ) = $echo_service->ping();
        if ( $status > -1 ) {
            $self->{LOGGER}->info( "Adding LS \"" . $ls . "\" to the contact list." );
            push @{ $self->{LS_ORDER} }, $ls unless $temp{$ls};
            $temp{$ls}++;
            $lsCounter++;
        }
        else {
            $self->{LOGGER}->warn( "LS \"" . $ls . "\" was not reacheable..." );
            next;
        }
        last if $lsCounter >= $self->{LIMIT};
    }

    if ( $#{ $self->{LS_ORDER} } < $self->{LIMIT} ) {

        # ask a gLS for help - do a single query to someone close, get an hLS
        #   list and then add the results to the list are maintaining

        if ( $#{ $self->{HINTS} } > -1 ) {
            my $gls    = perfSONAR_PS::Client::gLS->new( { url    => $self->{HINTS} } );
            my $result = $gls->getLSDiscoverRaw(         { xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:metadata/*[local-name()=\"subject\"]/*[local-name()=\"service\"]/*[local-name()=\"accessPoint\"]" } );
            if ( $result and $result->{eventType} =~ m/^success/ ) {
                my $parser = XML::LibXML->new();
                my %temp2  = ();
                my $ping   = Net::Ping->new();
                $ping->hires();
                if ( exists $result->{eventType} and $result->{eventType} ne "error.ls.query.empty_results" ) {
                    next unless exists $result->{response} and $result->{response};
                    my $doc = $parser->parse_string( $result->{response} );
                    my $ap = find( $doc->getDocumentElement, ".//*[local-name()=\"accessPoint\"]", 0 );
                    foreach my $a ( $ap->get_nodelist ) {
                        my $value = extract( $a, 0 );
                        if ( $value ) {
                            my $value2 = $value;
                            $value2 =~ s/^http:\/\///;
                            my ( $unt_host ) = $value2 =~ /^(.+):/;
                            my ( $ret, $duration, $ip ) = $ping->ping( $unt_host );
                            $temp2{$duration} = $value if ( ( $ret or $duration ) and ( not $temp{$value} ) );
                        }
                    }
                }
                $ping->close();

                foreach my $time ( sort keys %temp2 ) {
                    my $echo_service = perfSONAR_PS::Client::Echo->new( $temp2{$time} );
                    my ( $status, $res ) = $echo_service->ping();
                    next unless $status > -1;

                    push @{ $self->{LS_ORDER} }, $temp2{$time};
                    $lsCounter++;
                    last if $lsCounter >= $self->{LIMIT};
                }
            }
        }
    }

    if ( $self->{LS_ORDER}->[0] ) {
        $self->{LS}    = $self->{LS_ORDER}->[0];
        $self->{ALIVE} = 1;
    }
    else {
        undef $self->{LS};
        $self->{ALIVE} = 0;
        $self->{LOGGER}->warn( "Could not find an active LS, add one or use the gLS for discovery." );
    }

    return 0;
}

=head2 getLS( $self, { } )

Extract the first usable hLS.

=cut

sub getLS {
    my ( $self ) = @_;

    if ( $#{ $self->{LS_ORDER} } > -1 ) {
        foreach my $ls ( @{ $self->{LS_ORDER} } ) {
            my $echo_service = perfSONAR_PS::Client::Echo->new( $ls );
            my ( $status, $res ) = $echo_service->ping();
            if ( $status != -1 ) {
                $self->{LS}    = $ls;
                $self->{ALIVE} = 1;
                return;
            }
            else {
                $self->{LOGGER}->warn( "LS \"" . $ls . "\" was not reacheable..." );
            }
        }

        $self->{LOGGER}->error( "Could not contact LS in supplied list." );
        undef $self->{LS};
        $self->{ALIVE} = 0;
    }
    else {
        $self->{LOGGER}->error( "LS List is emtpty, cannot contact active LS for registration." );
        undef $self->{LS};
        $self->{ALIVE} = 0;
    }
    return;
}

=head2 getKey ($self)

Returns the key, or failing that asks for the key from the LS.  

=cut

sub getKey {
    my ( $self ) = @_;
    return $self->{LS_KEY} if $self->{LS_KEY};
    $self->sendKey();
    if ( exists $self->{LS_KEY} and $self->{LS_KEY} ) {
        return $self->{LS_KEY};
    }
    else {
        $self->{LOGGER}->error( "Key not found." );
        return;
    }
}

=head2 createKey ($self, $key)

Creates a 'key' structure that is used to access the LS.

=cut

sub createKey {
    my ( $self, $lsKey ) = @_;
    my $key = "    <nmwg:key id=\"key." . genuid() . "\">\n";
    $key = $key . "      <nmwg:parameters id=\"parameters." . genuid() . "\">\n";
    if ( defined $lsKey and $lsKey ) {
        $key = $key . "        <nmwg:parameter name=\"lsKey\">" . $lsKey . "</nmwg:parameter>\n";
    }
    else {
        if ( $self->getKey ) {
            $key = $key . "        <nmwg:parameter name=\"lsKey\">" . $self->getKey . "</nmwg:parameter>\n";
        }
        else {
            $self->{LOGGER}->error( "Cannot return key structure: value for key not found." );
            return;
        }
    }
    $key = $key . "      </nmwg:parameters>\n";
    $key = $key . "    </nmwg:key>\n";
    return $key;
}

=head2 createService ($self)

Creates the 'service' strcture (description of the service) for LS registration.

=cut

sub createService {
    my ( $self ) = @_;
    my $logger   = get_logger( "perfSONAR_PS::Client::LS::Remote" );
    my $service  = "    <perfsonar:subject xmlns:perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\" id=\"subject." . genuid() . "\">\n";
    $service = $service . "      <psservice:service xmlns:psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\">\n";
    $service = $service . "        <psservice:serviceName>" . $self->{CONF}->{"SERVICE_NAME"} . "</psservice:serviceName>\n" if exists $self->{CONF}->{"SERVICE_NAME"} and $self->{CONF}->{"SERVICE_NAME"};
    $service = $service . "        <psservice:accessPoint>" . $self->{CONF}->{"SERVICE_ACCESSPOINT"} . "</psservice:accessPoint>\n" if exists $self->{CONF}->{"SERVICE_ACCESSPOINT"} and $self->{CONF}->{"SERVICE_ACCESSPOINT"};
    $service = $service . "        <psservice:serviceType>" . $self->{CONF}->{"SERVICE_TYPE"} . "</psservice:serviceType>\n" if exists $self->{CONF}->{"SERVICE_TYPE"} and $self->{CONF}->{"SERVICE_TYPE"};
    $service = $service . "        <psservice:serviceDescription>" . $self->{CONF}->{"SERVICE_DESCRIPTION"} . "</psservice:serviceDescription>\n" if exists $self->{CONF}->{"SERVICE_DESCRIPTION"} and $self->{CONF}->{"SERVICE_DESCRIPTION"};
    $service = $service . "      </psservice:service>\n";
    $service = $service . "    </perfsonar:subject>\n";
    return $service;
}

=head2 callLS ($self, $sender, $message)

Given a message and a sender, contact an LS and parse the results.

=cut

sub callLS {
    my ( $self, $sender, $message ) = @_;

    my $error = q{};
    my $responseContent = $sender->sendReceive( makeEnvelope( $message ), q{}, \$error );
    if ( $error ) {
        $self->{LOGGER}->error( "sendReceive failed: $error" );
        return -1;
    }

    my $parser = XML::LibXML->new();
    if ( $responseContent and ( not $responseContent =~ m/^\d+/mx ) ) {
        my $doc = q{};
        eval { $doc = $parser->parse_string( $responseContent ); };
        if ( $EVAL_ERROR ) {
            $self->{LOGGER}->error( "Parser failed: " . $EVAL_ERROR );
            return -1;
        }
        else {
            my $msg = $doc->getDocumentElement->getElementsByTagNameNS( "http://ggf.org/ns/nmwg/base/2.0/", "message" )->get_node( 1 );
            if ( $msg ) {
                my $eventType = findvalue( $msg, "./nmwg:metadata/nmwg:eventType" );
                if ( $eventType and $eventType =~ m/success/mx ) {
                    my $temp = extract( find( $msg, "./nmwg:metadata/nmwg:key/nmwg:parameters/nmwg:parameter[\@name=\"lsKey\"]", 1 ), 0 );
                    $self->{LS_KEY} = $temp if $temp;
                    return 0;
                }
            }
        }
    }
    return -1;
}

=head2 registerStatic ($self, \@data_ref)

Performs registration of 'static' data with an LS.  Static in this sense
indicates that the data in the underlying storage DOES NOT change.  This
function uses special messages that intend to simply keep the data alive, not
worrying at all if something comes in that is new or goes away that is old.

=cut

sub registerStatic {
    my ( $self, $data_ref ) = @_;

    unless ( $self->{LS} and $self->{ALIVE} ) {
        $self->getLS();
        unless ( $self->{LS} and $self->{ALIVE} ) {
            $self->{LOGGER}->error( "LS cannot be reached, supply alternate or consult gLS." );
            return -1;
        }
    }

    if ( exists $self->{FIRST} and $self->{FIRST} ) {
        if ( $self->sendDeregister( $self->getKey() ) == 0 ) {
            $self->{LOGGER}->debug( "Nothing registered." );
        }
        else {
            $self->{LOGGER}->debug( "Removed old registration." );
        }

        my @resultsString = @{$data_ref};
        if ( $#resultsString != -1 ) {
            my ( $status, $res ) = $self->__register( createService( $self ), $data_ref );
            if ( $status == -1 ) {
                $self->{LOGGER}->error( "Unable to register data with LS." );
                $self->{ALIVE} = 0;
            }
        }
    }
    else {
        if ( $self->sendKeepalive( $self->getKey() ) == -1 ) {
            my @resultsString = @{$data_ref};
            if ( $#resultsString != -1 ) {
                my ( $status, $res ) = $self->__register( createService( $self ), $data_ref );
                if ( $status == -1 ) {
                    $self->{LOGGER}->error( "Unable to register data with LS." );
                    $self->{ALIVE} = 0;
                    return -1;
                }
            }
        }
    }

    $self->{FIRST} = 0 if $self->{FIRST};
    return 0;
}

=head2 registerDynamic ($self, \@data_ref)

Performs registration of 'dynamic' data with an LS.  Dynamic in this sense
indicates that the data in the underlying storage DOES change.  This function
uses special messages that will remove all old data and insert everything brand
new with each registration. 

=cut

sub registerDynamic {
    my ( $self, $data_ref ) = @_;

    unless ( $self->{LS} and $self->{ALIVE} ) {
        $self->getLS();
        unless ( $self->{LS} and $self->{ALIVE} ) {
            $self->{LOGGER}->error( "LS cannot be reached, supply alternate or consult gLS." );
            return -1;
        }
    }

    if ( exists $self->{FIRST} and $self->{FIRST} ) {
        if ( $self->sendDeregister( $self->getKey() ) == 0 ) {
            $self->{LOGGER}->debug( "Nothing registered." );
        }
        else {
            $self->{LOGGER}->debug( "Removed old registration." );
        }

        my @resultsString = @{$data_ref};
        if ( $#resultsString != -1 ) {
            if ( $self->__register( createService( $self ), $data_ref ) == -1 ) {
                $self->{LOGGER}->error( "Unable to register data with LS." );
                $self->{ALIVE} = 0;
            }
        }
    }
    else {
        my @resultsString = @{$data_ref};
        my $subject       = q{};
        if ( $self->sendKeepalive( $self->getKey() ) == -1 ) {
            $subject = createService( $self );
        }
        else {
            $subject = createKey( $self ) . "\n" . createService( $self );
        }

        if ( $#resultsString != -1 ) {
            if ( $self->__register( $subject, $data_ref ) == -1 ) {
                $self->{LOGGER}->error( "Unable to register data with LS." );
                $self->{ALIVE} = 0;
                return -1;
            }
        }
    }

    $self->{FIRST} = 0 if ( $self->{FIRST} );
    return 0;
}

=head2 __register ($self, $subject, $data_ref)

Performs the actual data registration. Unlike the above registration functions,
this function does not try to perform any of the keepalive/deregister
registration tricks. It simply registers the specified data. As part of the
registration, it splits the data into chunks and registers each independently.

=cut

sub __register {
    my ( $self, $subject, $data_ref ) = @_;

    my %lsHash = map { $_, 1 } @{ $self->{LS_CONF} };

    unless ( $self->{LS} and $self->{ALIVE} ) {
        $self->getLS();
        unless ( $self->{LS} and $self->{ALIVE} ) {
            $self->{LOGGER}->error( "LS cannot be reached, supply alternate or consult gLS." );
            return -1;
        }
    }

    my @data       = @{$data_ref};
    my $iterations = int( ( ( $#data + 1 ) / $self->{CHUNK} ) );
    my $x          = 0;
    my $len        = $iterations + 1;
    for my $y ( 1 .. $len ) {
        my $doc = perfSONAR_PS::XML::Document->new();
        startMessage( $doc, "message." . genuid(), q{}, "LSRegisterRequest", q{}, { perfsonar => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/", psservice => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/" } );
        my $mdID = "metadata." . genuid();
        if ( $subject ) {
            createMetadata( $doc, $mdID, q{}, $subject, undef );
        }
        else {
            createMetadata( $doc, $mdID, q{}, createService( $self ), undef );
        }
        for ( ; $x < ( $y * $self->{CHUNK} ) and $x <= $#data; $x++ ) {
            createData( $doc, "data." . genuid(), $mdID, $data[$x], undef );
        }
        endMessage( $doc );

        foreach my $ls ( @{ $self->{LS_ORDER} } ) {
            next unless exists $lsHash{$ls} and $lsHash{$ls};
            my ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $ls );
            unless ( $host and $port and $endpoint ) {
                $self->{LOGGER}->error( "URI conversion error for LS \"" . $ls . "\"." );
                next;
            }

            my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );

            unless ( $self->callLS( $sender, $doc->getValue() ) == 0 ) {
                $self->{LOGGER}->error( "Unable to register data with LS \"" . $ls . "\"." );
                next;
            }
        }
    }
    return 0;
}

=head2 sendDeregister ($self, $key)

Deregisters the data with the specified key

=cut

sub sendDeregister {
    my ( $self, $key ) = @_;
    $self->{LOGGER}->error( "Key value not supplied." ) and return -1 unless $key;

    my %lsHash = map { $_, 1 } @{ $self->{LS_CONF} };

    unless ( $self->{LS} and $self->{ALIVE} ) {
        $self->getLS();
        unless ( $self->{LS} and $self->{ALIVE} ) {
            $self->{LOGGER}->error( "LS cannot be reached, supply alternate or consult gLS." );
            return -1;
        }
    }

    my $doc = perfSONAR_PS::XML::Document->new();
    startMessage( $doc, "message." . genuid(), q{}, "LSDeregisterRequest", q{}, { perfsonar => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/", psservice => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/" } );

    my $mdID = "metadata." . genuid();
    createMetadata( $doc, $mdID, q{}, createKey( $self, $key ), undef );
    createData( $doc, "data." . genuid(), $mdID, q{}, undef );
    endMessage( $doc );

    foreach my $ls ( @{ $self->{LS_ORDER} } ) {
        next unless exists $lsHash{$ls} and $lsHash{$ls};
        my ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $ls );
        unless ( $host and $port and $endpoint ) {
            $self->{LOGGER}->error( "URI conversion error for LS \"" . $ls . "\"." );
            next;
        }

        my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );

        unless ( $self->callLS( $sender, $doc->getValue() ) == 0 ) {
            $self->{LOGGER}->error( "Unable to de-register data with LS \"" . $ls . "\"." );
            next;
        }
    }
    return;
}

=head2 sendKeepalive ($self, $key)

Sends a keepalive message for the data with the specified key

=cut

sub sendKeepalive {
    my ( $self, $key ) = @_;
    $self->{LOGGER}->error( "Key value not supplied." ) and return -1 unless $key;

    my %lsHash = map { $_, 1 } @{ $self->{LS_CONF} };

    unless ( $self->{LS} and $self->{ALIVE} ) {
        $self->getLS();
        unless ( $self->{LS} and $self->{ALIVE} ) {
            $self->{LOGGER}->error( "LS cannot be reached, supply alternate or consult gLS." );
            return -1;
        }
    }

    my $doc = perfSONAR_PS::XML::Document->new();
    startMessage( $doc, "message." . genuid(), q{}, "LSKeepaliveRequest", q{}, { perfsonar => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/", psservice => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/" } );

    my $mdID = "metadata." . genuid();
    createMetadata( $doc, $mdID, q{}, createKey( $self, $key ), undef );
    createData( $doc, "data." . genuid(), $mdID, q{}, undef );
    endMessage( $doc );

    my $success = 0;
    foreach my $ls ( @{ $self->{LS_ORDER} } ) {
        next unless exists $lsHash{$ls} and $lsHash{$ls};
        my ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $ls );
        unless ( $host and $port and $endpoint ) {
            $self->{LOGGER}->error( "URI conversion error for LS \"" . $ls . "\"." );
            next;
        }

        my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );

        unless ( $self->callLS( $sender, $doc->getValue() ) == 0 ) {
            $self->{LOGGER}->error( "Unable to keepalive data with LS \"" . $ls . "\"." );
            next;
        }

        $success = 1;
    }

    unless ( $success ) {
        $self->{LOGGER}->error( "Unable to keepalive data with any LS" );
        return -1;
    }

    return 0;
}

=head2 sendKey ($self)

Sends a key request message.

=cut

sub sendKey {
    my ( $self ) = @_;

    unless ( $self->{LS} and $self->{ALIVE} ) {
        $self->getLS();
        unless ( $self->{LS} and $self->{ALIVE} ) {
            $self->{LOGGER}->error( "LS cannot be reached, supply alternate or consult gLS." );
            return -1;
        }
    }

    my ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $self->{LS} );
    unless ( $host and $port and $endpoint ) {
        $self->{LOGGER}->error( "URI conversion error." );
        return -1;
    }

    my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );
    my $doc = perfSONAR_PS::XML::Document->new();
    startMessage( $doc, "message." . genuid(), q{}, "LSKeyRequest", q{}, { perfsonar => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/", psservice => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/" } );

    my $mdID = "metadata." . genuid();
    createMetadata( $doc, $mdID, q{}, createService( $self ), undef );
    createData( $doc, "data." . genuid(), $mdID, q{}, undef );
    endMessage( $doc );

    return callLS( $self, $sender, $doc->getValue() );
}

=head2 query ($self, \%queries)

This function sends the specified queries to the LS and returns the results.
The queries are given as a hash table with each key/value pair being an
identifier/a query. Each query gets executed and the returned value is a hash
containing the same identifiers as keys, but instead of pointing to queries,
they point to an array containing a status and a result. The status is either
0 or -1. If it's 0, the result is a pointer to the data element. If it's -1,
the result is the error message.

=cut

sub query {
    my ( $self, $queries ) = @_;
    $self->{LOGGER}->error( "Query value not supplied." ) and return -1 unless $queries;

    unless ( $self->{LS} and $self->{ALIVE} ) {
        $self->getLS();
        unless ( $self->{LS} and $self->{ALIVE} ) {
            $self->{LOGGER}->error( "LS cannot be reached, supply alternate or consult gLS." );
            return -1;
        }
    }

    my ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $self->{LS} );
    unless ( $host and $port and $endpoint ) {
        $self->{LOGGER}->error( "URI conversion error." );
        return -1;
    }

    my $request = "<nmwg:message type=\"LSQueryRequest\" id=\"msg1\"\n";
    $request .= "     xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
    $request .= "     xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/\">\n";
    foreach my $query_id ( keys %{$queries} ) {
        $request .= "  <nmwg:metadata id=\"perfsonar_ps.meta.$query_id\">\n";
        $request .= "    <xquery:subject id=\"sub1\">\n";
        $request .= $queries->{$query_id};
        $request .= "    </xquery:subject>\n";
        $request .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0</nmwg:eventType>\n";
        $request .= "  <xquery:parameters id=\"params.1\">\n";
        $request .= "    <nmwg:parameter name=\"lsOutput\">native</nmwg:parameter>\n";
        $request .= "  </xquery:parameters>\n";
        $request .= "  </nmwg:metadata>\n";
        $request .= "  <nmwg:data metadataIdRef=\"perfsonar_ps.meta.$query_id\" id=\"data.$query_id\"/>\n";
    }
    $request .= "</nmwg:message>\n";

    my ( $status, $res ) = consultArchive( $host, $port, $endpoint, $request );
    if ( $status != 0 ) {
        my $msg = "Error consulting LS: $res";
        $self->{LOGGER}->error( $msg );
        return -1;
    }

    $self->{LOGGER}->debug( "Response: " . $res->toString );

    my %ret_structure = ();

    foreach my $d ( $res->getChildrenByTagName( "nmwg:data" ) ) {
        foreach my $m ( $res->getChildrenByTagName( "nmwg:metadata" ) ) {
            my $md_id    = $m->getAttribute( "id" );
            my $md_idref = $m->getAttribute( "metadataIdRef" );
            my $d_idref  = $d->getAttribute( "metadataIdRef" );

            if ( $md_id eq $d_idref ) {
                my $query_id;
                my $eventType = findvalue( $m, "nmwg:eventType" );

                if ( defined $md_idref and $md_idref =~ /perfsonar_ps\.meta\.(.*)/mx ) {
                    $query_id = $1;
                }
                elsif ( $md_id =~ /perfsonar_ps\.meta\.(.*)/mx ) {
                    $query_id = $1;
                }
                else {
                    my $msg = "Received unknown response: $md_id/$md_idref";
                    $self->{LOGGER}->error( $msg );
                    next;
                }

                my @retval;
                if ( defined $eventType and $eventType =~ /^error\./mx ) {
                    my $error_msg = findvalue( $d, "./nmwgr:datum" );
                    $error_msg = "Unknown error" unless $error_msg;
                    @retval = ( -1, $error_msg );
                }
                else {
                    @retval = ( 0, $d );
                }

                $ret_structure{$query_id} = \@retval;
            }
        }
    }
    return ( 0, \%ret_structure );
}

1;

__END__

=head1 SYNOPSIS

    use perfSONAR_PS::Client::LS::Remote;

    my %conf = ();
    $conf{"SERVICE_ACCESSPOINT"} = "http://localhost:1234/perfSONAR_PS/services/TEST";
    $conf{"SERVICE_NAME"} = "TEST MA";
    $conf{"SERVICE_TYPE"} = "MA";
    $conf{"SERVICE_DESCRIPTION"} = "TEST MA";

    my @rdata = ();
    $rdata[0] .= "    <nmwg:metadata id=\"meta\">\n";
    $rdata[0] .= "      <netutil:subject id=\"subj\" xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\">\n";
    $rdata[0] .= "        <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
    $rdata[0] .= "          <nmwgt:hostName>localhost</nmwgt:hostName>\n";
    $rdata[0] .= "          <nmwgt:ifName>eth0</nmwgt:ifName>\n";
    $rdata[0] .= "          <nmwgt:ifAddress type=\"ipv4\">127.0.0.1</nmwgt:ifAddress>\n";
    $rdata[0] .= "          <nmwgt:direction>in</nmwgt:direction>\n";
    $rdata[0] .= "        </nmwgt:interface>\n";
    $rdata[0] .= "      </netutil:subject>\n";
    $rdata[0] .= "      <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
    $rdata[0] .= "    </nmwg:metadata>\n";

    my $ls1 = "http://localhost:9999/perfSONAR_PS/services/gLS";
    my $ls2 = "http://localhost:3432/perfSONAR_PS/services/gLS";
    my @ls = ( $ls1, $ls2 );
    my $hints1 = "http://l1ocalhost/gls.root.hints";
    my $hints2 = "http://localhost/gls.root.hints";
    my @hints = ( $hints1, $hints2 );

    # common case:
    my $ls_client = perfSONAR_PS::Client::LS::Remote->new( $ls1, \%conf );
    
    # starting with an array of LS instances:
    # $ls_client = perfSONAR_PS::Client::LS::Remote->new( \@ls, \%conf );
    # 
    # or starting with a hints file:
    # $ls_client = perfSONAR_PS::Client::LS::Remote->new( $ls1, \%conf, $hints1 );
    # 
    # the hints file can be an array as well:
    # $ls_client = perfSONAR_PS::Client::LS::Remote->new( $ls1, \%conf, \@hints );
    
    # Set the conf info
    # $ls_client->setConf( \%conf );
    
    # Adding an LS (single)
    # $ls_client->setURI( $ls2 );
    #
    # Adding an LS (array)
    # $ls_client->setURI( \@ls );
    #
    # Adding a hints file (single)
    # $ls_client->setHints( $hints2 );
    #
    # Adding a hints file (array)
    # $ls_client->setHints( \@hints );
    
    # cleaing the LS list
    # $ls_client->clearURIs;
    #
    # clearng the hints files
    # $ls_client->clearHints;


    # Use this for services where the metadata set *does not* change (uses keepalives)    
    $ls_client->registerStatic(\@rdata);
    
    # Use this for services where the metadata set *may* change (does not use keepalives)
    # $ls_client->registerStatic(\@rdata);

    # Show the key for the service
    print $ls_client->getKey() , "\n";

    # keepalive some key
    $ls_client->sendKeepalive($ls_client->getKey());

    # deregister some key
    $ls_client->sendDeregister($ls_client->getKey());
    
    # Send an aribitrary query
    my %queries = ();
    $queryies{"1"} = "/nmwg:store/nmwg:metadata";
    $ls_client->sendDeregister( \%queries );    

=head1 SEE ALSO

L<Log::Log4perl>, L<English>, L<LWP::Simple>, L<Net::Ping>, L<XML::LibXML>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Transport>, L<perfSONAR_PS::Messages>,
L<perfSONAR_PS::Client::Echo>, L<perfSONAR_PS::Client::gLS>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Remote.pm 4477 2010-09-29 14:02:45Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Aaron Brown, aaron@internet2.edu
Guilherme Fernandes, fernande@cis.udel.edu

=head1 LICENSE
 
You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT
 
Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut
