package perfSONAR_PS::Client::NotificationBroker::Client;

use strict;
use warnings;

use threads;
use Thread::Queue;
use Log::Log4perl qw/get_logger/;
use HTTP::Daemon;
use XML::LibXML;

use perfSONAR_PS::Client::NotificationBroker::BasicClient;
use perfSONAR_PS::Utils::ParameterValidation;

use fields 'LOGGER', 'CLIENT', 'RESERVATIONS', 'MIN_PORT', 'MAX_PORT', 'CURR_PORT', 'USED_PORTS', 'NOTIFICATION_QUEUE', 'FAILURE_QUEUE', 'XPATH_CONTEXT';

my %namespaces = (
        wsnotify => "http://docs.oasis-open.org/wsn/b-2",
);

sub new {
        my ($class) = @_;

        my $self = fields::new($class);

        $self->{LOGGER} = get_logger($class);

        return $self;
}

sub init {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { oscars_client => 1, axis2_home => 1, port_range => 0 } );

    $self->{CLIENT} = perfSONAR_PS::Client::NotificationBroker::BasicClient->new();
    my $n = $self->{CLIENT}->init({ 
                oscars_client => $parameters->{oscars_client},
                axis2_home    => $parameters->{axis2_home},
            });
    if ($n != 0) {
        $self->{LOGGER}->error("Couldn't initialize the notification client");
        return -1;
    }

    if ($parameters->{port_range}) {
        if ($parameters->{port_range} =~ /(\d+)-(\d+)/) {
            $self->{MIN_PORT} = $1;
            $self->{CURR_PORT} = $1;
            $self->{MAX_PORT} = $2;
        }

        if (not $self->{MIN_PORT} or $self->{MIN_PORT} > $self->{MAX_PORT}) {
            $self->{LOGGER}->error("Specified port range must be of the form '[lower port]-[upper port]'");
            return -1;
        }
    }

    $self->{RESERVATIONS} = ();
    $self->{USED_PORTS} = ();
    $self->{NOTIFICATION_QUEUE} = Thread::Queue->new();
    $self->{FAILURE_QUEUE} = Thread::Queue->new();
    $self->{XPATH_CONTEXT} = XML::LibXML::XPathContext->new();

    # Create an XPath Context that will be used for XPath queries in this module.
    foreach my $prefix ( keys %namespaces ) {
        $self->{XPATH_CONTEXT}->registerNs( $prefix, $namespaces{$prefix} );
    }

    return 0;
}

sub createHTTPDaemon {
    my ($self) = @_;

    my $chosen_port;
    if ($self->{MIN_PORT}) {
        my $prev_curr = $self->{CURR_PORT};
        while(not $chosen_port) {
            if (not $self->{USED_PORTS}->{$self->{CURR_PORT}}) {
                $chosen_port = $self->{CURR_PORT};
                $self->{CURR_PORT}++;
                if ($self->{CURR_PORT} > $self->{MAX_PORT}) {
                    $self->{CURR_PORT} = $self->{MIN_PORT};
                }
                last;
            }

            $self->{CURR_PORT}++;
            if ($self->{CURR_PORT} > $self->{MAX_PORT}) {
                $self->{CURR_PORT} = $self->{MIN_PORT};
            }

            if ($self->{CURR_PORT} == $prev_curr) {
                return undef;
            }
        }
    }

    if ($chosen_port) {
        return HTTP::Daemon->new(Timeout => 5);
    } else {
        return HTTP::Daemon->new(Timeout => 5, LocalPort => $chosen_port);
    }
}

sub subscribe {
    my ($self, @args) = @_;
    my $parameters = validateParams( @args, { broker => 1, source => 1, topics => 0, filter => 0 } );

    # valid parameters: BROKER, NotificationSource, Topics, MessageFilter

    my $daemon = $self->createHTTPDaemon();
    if (not $daemon) {
        $self->{LOGGER}->error("Couldn't allocate listening HTTP daemon");
        return undef;
    }

    $self->{LOGGER}->debug("Listening on ".$daemon->url);

    my $reservation_id = $self->{CLIENT}->subscribe({
                source              => $parameters->{source}, 
                sink                => $daemon->url,
                broker              => $parameters->{broker}, 
                topics              => $parameters->{topics},
                filter              => $parameters->{filter},
            });

    if ($reservation_id) {
        my %resv_info = ();

        $resv_info{broker}              = $parameters->{broker};
        $resv_info{notification_source} = $parameters->{notification_source};
        $resv_info{topics}              = $parameters->{topics};
        $resv_info{filter}              = $parameters->{filter};

        $resv_info{daemon}              = $daemon;
        $resv_info{notification_queue}  = $self->{NOTIFICATION_QUEUE};
        $resv_info{reservation_id}      = $reservation_id;
        $resv_info{client}              = $self->{CLIENT};
        $resv_info{control_queue}       = Thread::Queue->new();

        my $thr = threads->create(\&notification_handler, \%resv_info);

        # create a notify 'handler', a child process, that accepts, reads in the data, and "puts it in the queue". 
        $self->{RESERVATIONS}->{$reservation_id} = \%resv_info;

        $resv_info{thread} = $thr;
        # we use the control queue to get the thread to close nicely
#        $thr->detach;
    }

    return $reservation_id;
}

sub unsubscribe {
    my ($self, @args) = @_;
    my $parameters = validateParams( @args, { reservation_id => 1 } );

    my $reservation_id = $parameters->{reservation_id};

    if (not $reservation_id) {
        $self->{LOGGER}->error("Must have a notification reservation id specified");
        return -1;
    }

    if (not $self->{RESERVATIONS}->{$reservation_id}) {
        $self->{LOGGER}->error("Invalid UID $reservation_id");
        return -1;
    }

    my $resv_info = $self->{RESERVATIONS}->{$reservation_id};

    delete($self->{RESERVATIONS}->{$reservation_id});

    $resv_info->{control_queue}->enqueue("close");    

    $resv_info->{thread}->join();

    return 0;
}

sub notification_handler {
    my ($resv_info) = @_;

    my $notify_client      = $resv_info->{client};
    my $daemon             = $resv_info->{daemon};
    my $notification_queue = $resv_info->{notification_queue};
    my $control_queue      = $resv_info->{control_queue};

    my $prev_renew_time = time;

    while(1) {
    	my $handle = $daemon->accept;
        if ($handle) {
            my $request = $handle->get_request;
            if ($request) {
                # validate request
                $notification_queue->enqueue($request->content);
                $handle->send_status_line(200)
            }
        }

        # Check if the client is telling us to unsubscribe
        my $msg = $control_queue->dequeue_nb;
        if ($msg and $msg eq "close") {
            $notify_client->unsubscribe({ broker => $resv_info->{broker}, reservation_id => $resv_info->{reservation_id} });
            return;
        }

        # check if we need to renew the subscription. Currently, fixed at once per 10 minutes.
        if ($prev_renew_time < time - 10*60) {
            $notify_client->renew({ broker => $resv_info->{broker}, reservation_id => $resv_info->{reservation_id} });
            $prev_renew_time = time;
        }
    }
}

sub wait_notification {
    my ($self, $timeout) = @_;

    my $end_time;
    
    $end_time = time + $timeout if ($timeout);

    my $ret_notification;
    do {
        my $notification;
        while (not ($notification = $self->{NOTIFICATION_QUEUE}->dequeue_nb())) {
            last if ($end_time and $end_time < time);

            sleep(1);
        }

        return unless ($notification);

        my $parser = XML::LibXML->new();
        my $dom;
        eval {
            $dom = $parser->parse_string($notification);
        };
        if ($@) {
            $self->{LOGGER}->error("Received unparseable notification: $@");
            next;
        }

        my $message = $self->xPathFind($dom, "//wsnotify:Message", 1);
        if ($message) {

            my %notification_details = ();
            $notification_details{message} = $message;

            $ret_notification = \%notification_details;
        }
    } while (not $ret_notification);

    return $ret_notification;
}

=head2 xPathFind ($self, $node, $query, $return_first)

Does the find for this module. It uses the XPath context containing all the
namespaces that this module knows about. This context is created when the module
is initialized. If the "$return_first" is set to true, it returns the first node
of the list.

=cut

sub xPathFind {
    my ( $self, $node, $query, $return_first ) = @_;
    my $res;

    eval { $res = $self->{XPATH_CONTEXT}->find( $query, $node ); };
    if ( $@ ) {
        $self->{LOGGER}->error( "Error finding value($query): $@" );
        return;
    }

    if ( defined $return_first and $return_first == 1 ) {
        return $res->get_node( 1 );
    }

    return $res;
}

=head2 xPathFindValue ($self, $node, $query)

This function is analogous to the xPathFind function above. Unlike the above,
this function returns the text content of the nodes found.

=cut

sub xPathFindValue {
    my ( $self, $node, $xpath ) = @_;

    my $found_node;

    $found_node = $self->xPathFind( $node, $xpath, 1 );

    return unless $found_node;
    return $found_node->textContent;
}

1;
