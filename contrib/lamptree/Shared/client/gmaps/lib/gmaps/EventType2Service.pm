
=head1 NAME

gmaps::EventType2Service - An static class to map between event types and implemented services.  

=head1 DESCRIPTION

This module provides a simple mapping between a given event type and the required Service class to interact with it.

=head1 SYNOPSIS

    use gmaps::EventType2Service;
    
    # create a new service
    my $serviceName = gmaps::EventType2Service::getServiceFromEventType( '' );
  
=head1 DETAILS

This API is a work in progress, and still does not reflect the general access needed in an MA.
Additional logic is needed to address issues such as different backend storage facilities.  

=head1 API

The offered API is simple, but offers the key functions we need in a measurement archive. 

=cut


package gmaps::EventType2Service;

our $logger = Log::Log4perl::get_logger( 'gmaps::EventType2Service');


our %eventType2service = (
    'http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0' => 'BWCTL',
    'http://ggf.org/ns/nmwg/tools/owamp/2.0' => 'OWAMP',
    'http://ggf.org/ns/nmwg/tools/pinger/2.0/' => 'PingER',
    'http://ggf.org/ns/nmwg/characteristic/utilization/2.0' => 'Utilisation',
    'http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0' => 'Lookup',
);

our %service2eventType = reverse %eventType2service;

sub getServiceFromEventType
{
    my $eventType = shift;
    
    if ( defined $eventType2service{$eventType} ) {
        return $eventType2service{$eventType};
    }
    
    return undef;
}


sub getEventTypeFromService
{
    my $service = shift;
    
    if ( defined $service2eventType{$service} ) {
        return $service2eventType{$service};
    }
    
    return undef;
}



=head2 autoDetermineService( $uri )

tries to determine the service type for hte uri provided

=cut
sub autoDetermineService
{
	my $uri = shift;
	
	my @services = ();
	
	if ( $uri =~ /rrd/i or $uri =~ /snmp/ ) {
		push @services, 'Utilisation';
	} elsif ( $uri =~ /topology/i ) {
		push @services, 'topology';
	} elsif ( $uri =~ /pinger/i ) {
		push @services, 'PingER';
	} elsif ( $uri =~ /LS/i ) {
		push @services, 'Lookup';
    } elsif ( $uri =~ /perfSONARBOUY/ ) {
        push @services, 'OWAMP';
        push @services, 'BWCTL';
	} else {
		$logger->logdie( "Cannot determine service type form uri '$uri'");
	}

	$logger->logdie( "Could not auto determine the service from uri '$uri'\n")
	    if scalar @services < 1;

	return \@services;
}

=head2 autoDetermineEventType( $uri )

tries to dteermine the appropriate eventtype to use for the service

=cut
sub autoDetermineEventType
{
    my $uri = shift;
    
    my $services = gmaps::EventType2Service::autoDetermineService( $uri );
    my @eventTypes = ();
    foreach my $service ( @$services ) {
        push @eventTypes, gmaps::EventType2Service::getEventTypeFromService( $service );
    }
    return \@eventTypes;
}


1;
