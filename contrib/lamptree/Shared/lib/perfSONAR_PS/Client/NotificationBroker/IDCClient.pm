package perfSONAR_PS::Client::NotificationBroker::IDCClient;

use strict;
use warnings;

use threads;
use Thread::Queue;
use Log::Log4perl qw/get_logger/;
use HTTP::Daemon;
use XML::LibXML::XPathContext;

use OSCARS::event;

use perfSONAR_PS::Utils::ParameterValidation;

use base 'perfSONAR_PS::Client::NotificationBroker::Client';

use fields 'XPATH_CONTEXT';

my %namespaces = (
        oscars => "http://oscars.es.net/OSCARS",
);

sub init {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { oscars_client => 1, axis2_home => 1, port_range => 0 } );

    my $status;

    $status = $self->SUPER::init({ oscars_client => $parameters->{oscars_client}, axis2_home => $parameters->{axis2_home}, port_range => $parameters->{port_range} });
    if ($status != 0) {
        $self->{LOGGER}->error("Couldn't initialize the notification client");
        return -1;
    }

    # Create an XPath Context that will be used for XPath queries in this module.
    foreach my $prefix ( keys %namespaces ) {
        $self->{XPATH_CONTEXT}->registerNs( $prefix, $namespaces{$prefix} );
    }

    return 0;
}

sub wait_notification {
    my ($self, $timeout) = @_;

    my $notification = $self->SUPER::wait_notification($timeout);
    return unless ($notification);

    my $message = $notification->{message};
    return unless ($message);

    my $event = $self->xPathFind($message, "//oscars:event", 1);
    return unless ($event);

    $event = OSCARS::event->from_xml_string($event);

    return $event;
}

1;
