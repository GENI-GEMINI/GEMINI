package perfSONAR_PS::Services::MA::Skeleton;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::MA::Skeleton

=head1 DESCRIPTION

A skeleton of a Measurement Archive module.  This module aims to be easily
modifiable to support new and different MAs.

=cut

use base 'perfSONAR_PS::Services::Base';

use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);

use fields 'LOGGER';

use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Utils::ParameterValidation;

=head2 init($self, $handler);

This routine is called on startup for each endpoint that uses this module. The
function should be used to verify the configuration and set any default values.
The function should return 0 if the configuration is valid, and -1 if an error
is found.

=cut

sub init {
    my ( $self, $handler ) = @_;

    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::MA::Skeleton" );

    # Check the configuration and set some default values

    # If they haven't specified whether or not to perform LS registration, set it to false
    if ( not exists $self->{CONF}->{"skeleton"}->{"enable_registration"}
        or $self->{CONF}->{"skeleton"}->{"enable_registration"} eq q{} )
    {
        $self->{LOGGER}->warn( "Disabling registration since its use is unspecified" );
        $self->{CONF}->{"skeleton"}->{"enable_registration"} = 0;
    }

    if ( $self->{CONF}->{"skeleton"}->{"enable_registration"} ) {
        if ( not exists $self->{CONF}->{"skeleton"}->{"service_accesspoint"} or $self->{CONF}->{"skeleton"}->{"service_accesspoint"} eq q{} ) {
            $self->{LOGGER}->error( "No access point specified for SNMP service" );
            return -1;
        }

        # Verify an LS instance exists. If no ls is set specifically
        # for the skeleton MA, check if a global ls_instance exists. If
        # so, set it to be the skeleton MA's ls_instance.
        if ( not exists $self->{CONF}->{"skeleton"}->{"ls_instance"} or $self->{CONF}->{"skeleton"}->{"ls_instance"} eq q{} ) {
            if ( exists $self->{CONF}->{"ls_instance"} and $self->{CONF}->{"ls_instance"} ) {
                $self->{CONF}->{"skeleton"}->{"ls_instance"} = $self->{CONF}->{"ls_instance"};
            }
            else {
                $self->{LOGGER}->error( "No LS instance specified for SNMP service" );
                return -1;
            }
        }

        # Verify an LS registration interval exists. If no interval
        # exists, check to see if one was globally set. If not, set it
        # to a default of 30 minutes. If one does exist, change the
        # registration interval from minutes to seconds.
        if ( not exists $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} or $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} eq q{} ) {
            if ( exists $self->{CONF}->{"ls_registration_interval"} and $self->{CONF}->{"ls_registration_interval"} ) {
                $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} = $self->{CONF}->{"ls_registration_interval"};
            }
            else {
                $self->{LOGGER}->warn( "Setting registration interval to 30 minutes" );
                $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} = 1800;
            }
        }
        else {

            # turn the registration interval from minutes to seconds
            $self->{CONF}->{"skeleton"}->{"ls_registration_interval"} *= 60;
        }

        # set a default service description
        if ( not exists $self->{CONF}->{"skeleton"}->{"service_description"}
            or $self->{CONF}->{"skeleton"}->{"service_description"} eq q{} )
        {
            $self->{CONF}->{"skeleton"}->{"service_description"} = "perfSONAR_PS Skeleton MA";
            $self->{LOGGER}->warn( "Setting 'service_description' to 'perfSONAR_PS Skeleton MA'." );
        }

        # set a default service name
        if ( not exists $self->{CONF}->{"skeleton"}->{"service_name"}
            or $self->{CONF}->{"skeleton"}->{"service_name"} eq q{} )
        {
            $self->{CONF}->{"skeleton"}->{"service_name"} = "Skeleton MA";
            $self->{LOGGER}->warn( "Setting 'service_name' to 'Skeleton MA'." );
        }

        # set a default service type
        if ( not exists $self->{CONF}->{"skeleton"}->{"service_type"}
            or $self->{CONF}->{"skeleton"}->{"service_type"} eq q{} )
        {
            $self->{CONF}->{"skeleton"}->{"service_type"} = "MA";
            $self->{LOGGER}->warn( "Setting 'service_type' to 'MA'." );
        }

        # Create the LS client. This client will be reused each time
        # the registerLS function is called.
        my %ls_conf = (
            SERVICE_TYPE        => $self->{CONF}->{"skeleton"}->{"service_type"},
            SERVICE_NAME        => $self->{CONF}->{"skeleton"}->{"service_name"},
            SERVICE_DESCRIPTION => $self->{CONF}->{"skeleton"}->{"service_description"},
            SERVICE_ACCESSPOINT => $self->{CONF}->{"skeleton"}->{"service_accesspoint"},
        );

        $self->{LS_CLIENT} = new perfSONAR_PS::Client::LS::Remote( $self->{CONF}->{"skeleton"}->{"ls_instance"}, \%ls_conf, $self->{NAMESPACES} );
    }

    # Add a handler for events types "SkeletonRequest" in messages of type "SkeletonMessage"
    $handler->registerEventHandler( "SkeletonMessage", "SkeletonRequest", $self );

    # Add a handler for all events in messages of type "SkeletonMessage2"
    $handler->registerMessageHandler( "SkeletonMessage2", $self );

    # Add a complete handler for messages of type "SkeletonMessage"
    $handler->registerFullMessageHandler( "SkeletonMessage3", $self );

    my @eventTypes = ( 'SkeletonRequest' );
    $handler->registerMergeHandler( "SkeletonMessage",  \@eventTypes, $self );
    $handler->registerMergeHandler( "SkeletonMessage2", \@eventTypes, $self );
    $handler->registerMergeHandler( "SkeletonMessage3", \@eventTypes, $self );
    return 0;
}

=head2 needLS();

This function returns whether or not this MA will need a registration process.
It returns 0 if none is needed and non-zero if one is needed. If non-zero is
returned, the function registerLS must be defined.

=cut

sub needLS {
    my ( $self ) = @_;

    return $self->{CONF}->{"skeleton"}->{"enable_registration"};
}

=head2 registerLS($self, $sleep_time)

This function is called in a separate process from the message handling. It is
used to register the MA's metadata with an LS.  Generally, this is done using
the LS client software. The $sleep_time variable is a reference that can be used
to return how long the process should sleep for before calling the registerLS
function again.

=cut

sub registerLS {
    my ( $self, $sleep_time ) = validateParamsPos( @_, 1, { type => SCALARREF }, );

    # Obtain the metadata as an array of strings containing the metadata
    my @metadata = $self->getMetadataToRegister();

    $self->{LS_CLIENT}->registerStatic( \@metadata );

    # Set the next sleep_time. This could be used to dynamically change the
    # registration interval if desired.
    if ( defined $sleep_time ) {
        $$sleep_time = $self->{CONF}->{"status"}->{"ls_registration_interval"};
    }

    return;
}

=head2 handleMessage 

If a full message handler is registered, this function will be called when a new
message of the specified type is received.

    Valid Parameters:
     output: The perfSONAR_PS::XML::Document being used to construct the response message
     messageId: The id for the message received
     messageType: The type of the message received
     message: The full message received
     rawRequest: The raw request received

=cut

sub handleMessage {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            output      => 1,
            messageId   => 1,
            messageType => 1,
            message     => 1,
            rawRequest  => 1,
        }
    );

    my $messageId = $args->{"messageId"};
    my $output    = $args->{"output"};

    my $mdID = "metadata." . genuid();
    my $msg  = "The skeleton can handle full message.";

    startMessage( $output, genuid(), $messageId, "SkeletonResponse", q{}, undef );
    getResultCodeMetadata( $output, $mdID, q{}, "success.fullmessage.skeleton" );
    getResultCodeData( $output, "data." . genuid(), $mdID, $msg, 1 );
    endMessage( $output );

    return;
}

=head2 handleMessageBegin ($self, $ret_message, $messageId, $messageType, $msgParams, $request, $retMessageType, $retMessageNamespaces);

When a message handler is added, this function will be called when a message of
the registered message type is received. The function can be used to initialize
any per request fields. This could include things like opening database
connections once instead of opening them each time a metadata/data pair is
found.  

    Valid Parameters:
     output: The perfSONAR_PS::XML::Document being used to construct the response message
     messageId: The id for the message received
     messageType: The type of the message received
     messageParameters: The parameters for the message received as a hash
     message: The full message received
     rawRequest: The raw request received
     doOutputMessageHeader: A ref that can be set to specify whether the daemon should output the message header
     doOutputMetadata: A ref that can be set to have the daemon output all of the metadata from the request message when it outputs the message header
     outputMessageId: A ref that can be set to specify the message id of the response message
     outputMessageType: A ref that can be set to specify the message type of the response message
     outputNamespaces: A ref that can be set to a hash to specify additional namespaces to be added to the return message header

=cut

sub handleMessageBegin {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            output                => 1,
            messageId             => 1,
            messageType           => 1,
            messageParameters     => 1,
            message               => 1,
            rawRequest            => 1,
            doOutputMessageHeader => 1,
            doOutputMetadata      => 1,
            outputMessageType     => 1,
            outputNamespaces      => 1,
            outputMessageId       => 1,
        }
    );

    return;
}

=head2 handleMessageEnd ($self, $ret_message, $messageId);

When a message handler is added, this function is called when the message is
finished. This function can be used to cleanup any per request fields (like open
database connections).

    Valid Parameters:
     output: The perfSONAR_PS::XML::Document being used to construct the response message
     messageId: The id for the message finished being handled
     messageType: The type of the message finished being handled
     message: The full message handled
     doOutputMessageFooter: A ref that can be set to specify whether the daemon should output the message footer

=cut

sub handleMessageEnd {
    my ( $self, @args ) = @_;
    my $args = validateParams(
        @args,
        {
            output                => 1,
            messageId             => 1,
            messageType           => 1,
            message               => 1,
            doOutputMessageFooter => 1,
        }
    );

    # The daemon will, by default, put on the footer to the message
    # "</nmwg:message>". However by setting the doOutputMessageFooter ref to
    # '0', the module can tell the daemon to not end the message. This can be
    # used if the module wishes to end the message on its own.

    # ${ $parameters->{"doOutputMessageFooter"} } = 0;

    return;
}

=head2 handleEvent ($self, $output, $messageId, $messageType, $message_parameters, $eventType, $md, $d, $raw_request);

The handleEvent function is called when a metadata/data pair is found in a
received message. 

    Valid Parameters:
     output: The perfSONAR_PS::XML::Document being used to construct the response message
     messageId: The id for the message the md/d pair was in
     messageType: The type of the message rthe md/d pair was in
     messageParameters: The parameters for the message received as a hash
     eventType: The event type that triggered calling this handler with these parameters
     subject: An array containing the subject md(s). This should only be one md, but maybe change to include the full chain in the future.
     filterChain: An array containing the filter md(s). The ordering is array[0] = md closest to the subject md, array[arraylen] = the bottom of the chain
     data: The data element from the md/d pair
     rawRequest: The raw request received
     doOutputMetadata: A ref that can be set to have the daemon output the metadata from the request message when it outputs the message header

=cut

sub handleEvent {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            output            => 1,
            messageId         => 1,
            messageType       => 1,
            messageParameters => 1,
            eventType         => 1,
            subject           => 1,
            filterChain       => 1,
            data              => 1,
            rawRequest        => 1,
            doOutputMetadata  => 1,
        }
    );

    my $output             = $parameters->{"output"};
    my $messageId          = $parameters->{"messageId"};
    my $messageType        = $parameters->{"messageType"};
    my $message_parameters = $parameters->{"messageParameters"};
    my $eventType          = $parameters->{"eventType"};
    my $d                  = $parameters->{"data"};
    my $raw_request        = $parameters->{"rawRequest"};
    my @subjects           = @{ $parameters->{"subject"} };
    my @filters            = @{ $parameters->{"filterChain"} };

    my $mdID = "metadata." . genuid();
    my $msg  = "The skeleton exists.";

    # if the module is going to output both the metadata and data for this
    # request, it needs to tell the daemon to not output the metadata. It does
    # this by setting the value of the doOutputMetadata ref to '0'. If
    # doOutputMetadata is not set, the daemon will output all the filter and
    # subject metadata.

    ${ $parameters->{"doOutputMetadata"} } = 0;

    getResultCodeMetadata( $output, $mdID, $subjects[0]->getAttribute( "id" ), "success.skeleton" );
    getResultCodeData( $output, "data." . genuid(), $mdID, $msg, 1 );

    return;
}

=head2 mergeMetadata

This function is called by the daemon if the module has registered a merge
handler and a md is found that needs to be merged with another md and has an
eventType that matches what's been registered with the daemon.

     messageType: The type of the message where the merging is occurring
     eventType: The event type in at least one of the md that caused this handler to be chosen
     parentMd: The metadata that was metadataIdRef'd by the childMd
     childMd: The metadata that needs to be merged with its parent

=cut

sub mergeMetadata {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            messageType => 1,
            eventType   => 1,
            parentMd    => 1,
            childMd     => 1,
        }
    );

    my $parent_md = $parameters->{parentMd};
    my $child_md  = $parameters->{childMd};

    $self->{LOGGER}->info( "mergeMetadata called" );

    # Just use the default merge routine for now
    defaultMergeMetadata( $parent_md, $child_md );

    return;
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::MA::Base>, L<perfSONAR_PS::MA::General>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Messages>, L<perfSONAR_PS::LS::Register>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Skeleton.pm 2640 2009-03-20 01:21:21Z zurawski $

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
