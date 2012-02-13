use gmaps::paths;
use utils::xml;

use gmaps::Services::Lookup;
use gmaps::Services::Topology;
use gmaps::Services::Utilisation;
use gmaps::Services::PingER;
use gmaps::Services::BWCTL;
use gmaps::Services::OWAMP;

use gmaps::Graph::RRD;
use gmaps::Graph::RRD::Utilisation;
use gmaps::Graph::RRD::PingER;
use gmaps::Graph::RRD::Throughput;
use gmaps::Graph::RRD::Latency;

use gmaps::EventType2Service;

use URI::Escape;

use utils::urn;

#use perfSONAR_PS::ParameterValidation;
use Params::Validate qw(:all);
use Template;
use Data::Dumper;

use LWP::UserAgent;

use gmaps::InterfaceCache;
use Storable qw/ freeze thaw /;


=head1 NAME

gmaps::Interface - An interface to interact with a remote service.  

=head1 DESCRIPTION

This module provides functions to query a remote perfsonar measurement point
or measurement archive. Inherited classes should overload the appropiate
methods to provide customised access to the service in question.

=head1 SYNOPSIS

    use gmaps::Service;
    
    # create a new service
    my $service = gmaps::Service->new( 'http://localhost:8080/endpoint' );
  
	# check to see that the service is alive
	if ( $service->isAlive() ) {
		
		# get a list of the available urn's on the service
		my $list = $service->getUrns();
		
		
		
	} else {
		
		print "Error: Service is not alive.";
		
	}

=head1 DETAILS

This API is a work in progress, and still does not reflect the general access needed in an MA.
Additional logic is needed to address issues such as different backend storage facilities.  

=head1 API

The offered API is simple, but offers the key functions we need in a measurement archive. 

=cut

package gmaps::Interface;

use fields qw( TEMPLATE );

our $logger = Log::Log4perl::get_logger( 'gmaps::Interface');

use strict;


#######################################################################
# generic interfaces to gmaps data
#######################################################################

=head2 new
create a new interface instance to query perfsonar servers
=cut
sub new
{
	my gmaps::Interface $self = shift;
	unless ( ref $self ) {
		$self = fields::new( $self );
	}
	return $self;
}

#######################################################################
# tools and utility functions
#######################################################################



#######################################################################
# Discovery
#######################################################################

=head2 discover( $uri, $using )
returns a list of the urn's representing the metadata contained within the
service at uri
=cut
sub list
{
	my $self = shift;
	
	my $uri =shift;
	my $eventType = shift;
	
	my $data = $self->discover( $uri, $eventType );
	
	# return just list of urns
	my @urns = ();
    foreach my $item ( @$data ) {
        
        $logger->debug( Data::Dumper::Dumper( $item ) );
        if ( exists $item->{urns} ) {
            # for ma stuff
            foreach my $urn ( @{$item->{urns}} ) {
                $logger->debug( "  adding urn: " . $urn->{urn} );
	            push @urns, $urn->{urn};
            }
	    } else {
            $logger->debug( "  adding access: " . $item->{accessPoint} );
            push @urns, $item->{eventType} . ' @ ' . $item->{accessPoint};
		}
		
	}

	return \@urns;
}

=head2 topology( $uri, $using )

returns an array of hashes containing information on the metadata contained at service

=cut
sub discover
{
	my $self = shift;
	
	my $accessPoint = shift;
	my $eventType = shift;

    my $gotResponse = 0;
    
    my $useDB = 1;
	$useDB = 0
		if ( ! defined ${gmaps::paths::discoverCache} 
			or ${gmaps::paths::discoverCache} eq '' );

    my $key = $accessPoint . '|' . $eventType;

    # cache data
    my $db = undef;       
    my $data = undef;

    my $response = undef;
	# cache so that we don't have to worry about dynamic loksup
    if ( $useDB ) {
	    $db = gmaps::InterfaceCache->new( ${gmaps::paths::discoverCache} );
        $response = $db->getResponse( $key );
    }	

	# try the cache first
    if ( $response eq undef ) {

    	$logger->debug( "Attempting live discovery of service at '$accessPoint' with eventType '$eventType'");	
    	my $service = $self->createService( $accessPoint, $eventType );

    	# return just list of urns
    	$data =  $service->discover( { eventType => $eventType });
    	if ( scalar @$data < 1 ) {
    		$logger->fatal( "No urns were found at service '$accessPoint' using eventType '$eventType'");
    	}

        # freeze data
        if ( $useDB ) {
            my $serialized = Storable::freeze( $data );
            $db->setResponse( $key, $serialized );
        }
        
    } else {

    	$logger->debug( "Attempting thawing of discover of service at '$accessPoint' with eventType '$eventType'");	
        # thraw data
        $data = Storable::thaw( $response );
        
    }

	return $data;	
}




=head2 getGLS

returns the top level registered gLSs

=cut
sub getGLS
{
    my $self  = shift;
    
    $logger->debug( "Fetching GLS list from '" . ${gmaps::paths::gLSRoot} . "'" );
    my $ua = LWP::UserAgent->new;
    $ua->agent( ${gmaps::paths::version} );

    my $req = HTTP::Request->new(POST => ${gmaps::paths::gLSRoot} );
    my $res = $ua->request($req);
    
    my @gLS = ();
    if ($res->is_success) {
        
        foreach my $accessPoint ( split /\s+/, $res->content ) {

            my $accessPoint = URI::Escape::uri_unescape( $accessPoint );
            my ( $host, undef, undef ) = &perfSONAR_PS::Transport::splitURI( $accessPoint );
            # if ( utils::addresses::isIpAddress( $host ) ) {
            #     my ( $ip, $dns ) = utils::addresses::getDNS( $host );
            #     if ( $dns ) {
            #         $host = $ip;
            #     }
            # }

            my $evts = gmaps::EventType2Service::autoDetermineEventType( $accessPoint );
            
            foreach my $eventType ( @$evts ) {
                my $hash = {
                
                    accessPoint => $accessPoint,
                    #my $urn = 'urn:ogf:network:serviceType=gLS:serviceName=Lookup Service:accessPoint=' . URI::Escape::uri_escape( $accessPoint );
                    eventType => $eventType,
                    serviceType => gmaps::EventType2Service::getServiceFromEventType( $eventType )
                
                };
                ( $hash->{latitude}, $hash->{longitude} ) = gmaps::Location->getLatLong( $host, $host, undef, undef );
            
                push @gLS, $hash;
            }
        }
    }
    else {
        die( "Could get list of global Lookup services from '" . ${gmaps::paths::gLSRoot} .  "'");
    }
    
    return \@gLS;
}


=head2 getGLSUrn

get's a list of urns for the global lookup services

=cut
sub getGLSUrn
{
    
    my $self = shift;
    my @urns = ();
    foreach my $hash ( @{$self->getGLS()} ) {
        push @urns, $hash->{eventType} . ' @ ' . $hash->{accessPoint};
    }
    return \@urns;
}





=head2 fetch( uri, using, urn )

retrieve a table of information from the urn

=cut
sub fetch
{
	my ( $self, @args ) = @_;
    my $fetchArgs = $self->validateParams( @args );

	# retrieve numeric data from service
	my $service = $self->createService( $fetchArgs->{uri}, $fetchArgs->{eventType} );
	my $uri = $fetchArgs->{uri};
	delete $fetchArgs->{uri};
	my $data = $service->getData( $fetchArgs );

	# TODO: This shoudl throw an exception instead 
	if ( scalar keys %$data < 1 ) {
	    if ( defined $fetchArgs->{key} ) {
    		die( "No data was found on service '" . $uri . "' for key '" . $fetchArgs->{key} . "' using eventType '". $fetchArgs->{eventType} . "'");
	    } else {
		    die( "No data was found on service '" . $uri . "' for urn '" . $fetchArgs->{urn} . "' using eventType '". $fetchArgs->{eventType} . "'");
		}
		exit;
	}

	return ( $service->fields(), $data );
}


sub validateParams
{
    my ( $self, @args ) = @_;
	my $params = Params::Validate::validate( @args, { uri => 1, eventType => 0, urn => 0, key => 0, startTime => 0, endTime => 0, period => 0, resolution => 0, consolidationFunction => 0 });

	$params->{uri} = utils::xml::unescape( $params->{uri} );
	$params->{urn} = utils::xml::unescape( $params->{urn} );
	
	if ( ! defined $params->{eventType} ) {
	    my $evts = gmaps::EventType2Service::autoDetermineEventType( $params->{uri} );
	    if ( scalar @$evts > 1 ) {
	        die "Too many eventTypes provided by service '" . $params->{uri} . "'";
	    } else {
    	    $params->{eventType} = shift @$evts;
	    }
	}
	
	$logger->debug( "url: " . $params->{uri} . ", urn: " . $params->{urn} . ", eventType: " . $params->{eventType} . ", key: " . $params->{key} . "; start: " . $params->{startTime} . ", end: " . $params->{endTime} . ", res: " . $params->{resolution} . ", cf: " . $params->{consolidationFunction} );
	
	# do some time calculations to make things consistent
	my $fetchArgs = {
	    
	     uri => $params->{uri},
	     eventType => $params->{eventType},
	     
	     urn => $params->{urn},
 	     key => $params->{key},
 	     
	     resolution => $params->{resolution} || 300,
         consolidationFunction => $params->{consolidationFunction}
	};
	
    if ( ! defined $params->{period} ) {
        $params->{period} = 21600;
    }
    ( $fetchArgs->{startTime}, $fetchArgs->{endTime} ) = $self->checkTimeRange( $params->{startTime}, $params->{endTime}, $params->{period} );

    # throw an error if no metadata is defined to fetch
    if ( ! defined $params->{urn} && ! defined $params->{key} ) {
        $logger->logdie( "Could not determine metadata to fetch for service");
    }
    
    return $fetchArgs;
}



=head2 getTimeRange( $startTime, $endTime )

returns the 
=cut
sub checkTimeRange
{
	my $self = shift;
	my $startTime = shift;
	my $endTime = shift;
	my $period = shift;
	
	$logger->debug( "start: $startTime, end: $endTime, period: $period");
	
	# parse the times into epoch secs if not already
	# TODO

	# if no times defined, return undef	
	if ( ! defined $startTime && ! defined $endTime ) {
		$startTime = undef;
		$endTime = time();
	}
	elsif ( defined $startTime && ! defined $endTime ) {
		$endTime = time();
	}

	if( ( defined $startTime && defined $endTime )
		&& $startTime >= $endTime ) {
		$logger->error( "Start time ($startTime) is not chronologically before end time ($endTime).\n");
		exit 0;
	}		

    if ( ! defined $startTime && defined $period ) {
        $startTime = $endTime - $period;
    }

	return ( $startTime, $endTime );	
}



=head2 graph( uri, using, urn )
generates a rrd graph
=cut
sub graph
{
	my ( $self, $args ) = @_;
    my $width = $args->{width};
    delete $args->{width};
    my $height = $args->{height};
    delete $args->{height}; 
    
    my $fetchArgs = $self->validateParams( ( $args ) );
        
    my $serviceType = undef;
    if ( ! defined $fetchArgs->{eventType} ) {
        my $evts = gmaps::EventType2Service::autoDetermineService( $fetchArgs->{uri} );
        if ( scalar @$evts > 1 ) {
            die "Too many services provided by '" . $fetchArgs->{uri} . "'";
        } else {
            $serviceType = shift @$evts;
        }
    } else {
        $serviceType = gmaps::EventType2Service::getServiceFromEventType( $fetchArgs->{eventType} );
    }

	# determine the correct grpah type to create
	my $class = 'gmaps::Graph::RRD';
    if ( ! defined $serviceType ) {
		$logger->warn( "Could not determine appropriate graphing class to use for uri '" . $fetchArgs->{uri} . "' using eventType '" . $fetchArgs->{eventType} . "'");
	} else {
	    my $graphType = $serviceType;
	    if ( $serviceType eq 'BWCTL' ) {
	        $graphType = 'Throughput';
	    } elsif ( $serviceType eq 'OWAMP' ) {
	        $graphType = 'Latency';
	    }
	    $class .= '::' . $graphType;
	}
		
	# fetch the data	
	my ( $fields, $data ) = $self->fetch( $fetchArgs );
	
	### create the graph
	# get the start and end
	my @times = sort {$a <=> $b} keys %$data;
	my $start = $times[0];
	my $end = $times[$#times];

	# entries
	my $entries = scalar( @times );
	
	# don't bother if we don't have any data
	if ( $entries eq 0 ) {
		return undef;
	}
	

	# create temp rrd
	my ( undef, $rrdFile ) = &File::Temp::tempfile( ) ; #UNLINK => 1 );	
	no strict 'refs';
	my $rrd = $class->new( { filename => $rrdFile, 
	                            startTime => $start,
	                            resolution => $fetchArgs->{resolution}, 
	                            width => $width,
	                            height => $height,
	                            entries => $entries, 
	                            fields => $fields } );
	use strict 'refs';
	
	# add the data into the rrd
	my $prev = undef;
	my $realStart = undef;
	my $realEnd = undef;

	foreach my $t ( @times )
	{
		next if $t <= $prev;
		next if $t == 10;

		$realStart = $t if $t < $realStart || ! defined $realStart;
		$realEnd = $t if $t > $realEnd || ! defined $realEnd;

		$rrd->add( $t, $data->{$t} );
		
		$prev = $t;
	}
	
	# now get the graph from the rrd
	my ( undef, $pngFilename ) = &File::Temp::tempfile( UNLINK => 1 );		
	$logger->debug( "start time: $realStart, end time: $realEnd" );	
	# ref to scalar
	my $graph = $rrd->getGraph( $realStart, $realEnd, $pngFilename );

	# clean up
	unlink $pngFilename or $logger->warn( "Could not unlink '$pngFilename'" );
	undef $rrd;

	return $graph;	

}


#######################################################################
# UTILITY
#######################################################################

=head2 createService( $uri, $using )
returns the appropiate client service object for the uri. optional $using
will force it an appropiate class type
=cut
sub createService
{
	my $self = shift;
	my $accessPoint = shift;
	my $eventType = shift;
		
	# auto determine the service class to use from uri if no using supplied
	my $class = undef; # eventType mapping
	if ( ! defined $eventType ) {
		my $evts = gmaps::EventType2Service::autoDetermineService( $accessPoint );
		if ( scalar @$evts > 1 ) {
		    die "Too may services provided by '$accessPoint'";
		} else {
		    $class = shift @$evts;
		}
	} else {
		# determine the class to use
	    $class = gmaps::EventType2Service::getServiceFromEventType( $eventType );
	}
	
	if ( ! $class ) {
		$logger->logdie( "Could not determine service type from service '$accessPoint' using eventType '$eventType'");		
	}

    $logger->debug("Mapped '$accessPoint' using eventType '$eventType' to class '$class'");
	
	# create the service
	my $method = 'gmaps::Services::' . $class;
	no strict 'refs';
	my $service = $method->new( URI::Escape::uri_unescape( $accessPoint ) );
	use strict 'refs';
	$logger->debug( "Created a " . $service . " for '$accessPoint'");

	return $service;
}




# void?


=head2 getHLS

returns a list of hls's from a given gLS endpoint

=cut
sub getHLS
{
    my $self = shift;
    my $glsUrl = shift;
    
    # query a gLS for hLS's.
    my @hLS = ();
    
    my $list = $self->discover( $glsUrl, 'lookup' );
	foreach my $urn ( @$list ) {
	    
	    my $hash = utils::urn::toHash( $urn );

        if ( $hash->{serviceType} ne 'hLS' ) {
            $logger->error( "Unknown service type for '$urn'.");
            next;
	    }
	    
        push @hLS, $hash->{accessPoint}
            if $hash->{accessPoint};
	
	}
    
    return \@hLS;
}


=head2 getServices

given a hLS, will return a list (urn) of services registered on that hLS

=cut
sub getServicesFromHLS
{
    my $self = shift;
    my $hlsURL = shift;
    
    my $list = $self->discover( $hlsURL, "CRAP" );
	
	my @services = ();
	
	foreach my $urn ( @$list ) {
    
        # remap the serviceTypes
        my $hash = utils::urn::toHash( $urn );

        # need to dtermine the approrpiate service Type
        if ( $hash->{serviceType} eq 'hLS' ) {
            $hash->{eventType} = 'lookup';
        } else {
            my $evts = gmaps::EventType2Service::autoDetermineEventType( $hash->{accessPoint} );
            if ( scalar @$evts > 1 ) {
                die "Too many services provided by '" . $hash->{accessPoint} . "'";
            } else {
                $hash->{eventType} = shift @$evts;
            }
        }
        
        # need to add two service types for perfsonar buay
        if ( $hash->{serviceType} eq 'perfSONAR_BUOY' ) {
            
            my $serviceName = $hash->{serviceName};
            foreach my $type ( qw/ owamp bwctl / ) {
                $hash->{serviceType} = $type;
                $hash->{serviceName} =  $serviceName . ' (' . $type . ')';
                push @services, utils::urn::fromHash( $hash );
            }
            
        } else {    
            push @services, utils::urn::fromHash( $hash );
        }
    }
    
    return \@services;
}





=head2 getListOfServices

Queries the high level gLS and then hLS's to get service endpoints for perfsonar data

=cut
sub getServices
{
    my $self = shift;
    my $gLS = shift;
    
    # list of urn's of the endpoint services
    my @services = ();

    # find hLS's on gLS
    $logger->debug( "Querying global LS entry '" . $gLS . "'");
    my $hLS = $self->getHLS( $gLS );
    my $count = 1;
    foreach my $ls ( @$hLS ) {
        $logger->debug( "  Querying domain LS entry '$ls' ($count/" . scalar @$hLS . ")" );
        
        if ( URI::Escape::uri_unescape( $ls ) eq 'http://lab244.internet2.edu:8095/perfSONAR_PS/services/hLS' ) {
            $logger->warn( "skipping lookup of " . URI::Escape::uri_unescape($ls) );
            $count++;
            next;
        }
        
        # get endpoints for perfsonar services
        eval {
            my $services = $self->getServicesFromHLS( $ls );
            foreach my $service ( @$services ) {
                $logger->debug( "    found service $service");
                push @services, $service;
            }
        };
        if ( $@ ) {
#            $logger->warn( "ERROR! $@");
        }

        $count++;
    }

    return \@services;
}



1;


=head1 SEE ALSO

L<perfSONAR_PS::Transport>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS 
  
Questions and comments can be directed to the author, or the mailing list. 

=head1 VERSION

$Id: Interface.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, E<lt>ytl@slac.stanford.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Internet2

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

