=head1 NAME

gmaps::Interface::web - An google maps based interface to interact with 
perfsonar services  

=head1 DESCRIPTION

This module provides functions to query a remote perfsonar measurement point
or measurement archive. Inherited classes should overload the appropiate
methods to provide customised access to the service in question.

=head1 SYNOPSIS

    use gmaps::Interface::web;
    
    # create a new service
    my $service = gmaps::Interface::web->new();
  
    # get a list of all urn's available on a perfsonar service endpoint
	my $list = $service->discover( 'http://localhost:8080/endpoint' );
	
	foreach my $urn ( @$list ) {
		print "$urn\n";
	}
	
	# get a data table of the values for the service
	my $table = $service->fetch( 'http://localhost:8080/endpoint', 
						'urn:ogf:network:domain=localdomain:host=localhost');

	# graph the data table (also does a fetch)
	my $png = $service->graph( 'http://localhost:8080/endpoint', 
						'urn:ogf:network:domain=localdomain:host=localhost');
	# if you already have the data you can also
	# my $png = $service->getGraph( $table );
	
	
	

=head1 DETAILS

This API is a work in progress, and still does not reflect the general access needed in an MA.
Additional logic is needed to address issues such as different backend storage facilities.  

=head1 API

The offered API is simple, but offers the key functions we need in a measurement archive. 

=cut

use Params::Validate qw(:all);




package gmaps::Interface::web;

use CGI::Application;
use gmaps::Interface;


BEGIN{
	@ISA = ( 'CGI::Application', 'gmaps::Interface' );
}



use CGI::Application::Plugin::TT;


# logging
use Log::Log4perl qw( get_logger );
our $logger = Log::Log4perl::get_logger( 'gmaps::web');

use strict;


#######################################################################
# pre stuff
#######################################################################


###
# setup for mode switching
###
sub setup {
    my($self) = @_;
    
    $self->start_mode('map');
    $self->mode_param('mode');
    $self->run_modes(

        'map'		=> 'map',		# returns the googlemap with async. xml of nodes (createXml)
		
        'getGLS'    => 'getGLS', # returns a list of glses

        # 'services'  => 'getServices', # returns an xml of the service endpoints from teh given gLS

        'discover'	=> 'discover',	# does the actual perfsonar topology discovery from a service

        'graph'		=> 'graph',     # returns the for the data fetch graph

   	);

    # instantiate the interface

   return undef;    
}




# run these before calling runbmode
# set up db and templates
sub cgiapp_prerun
{
	my $self = shift;
	$logger->debug( "Using template path '${gmaps::paths::templatePath}'");
    $self->tt_include_path( ${gmaps::paths::templatePath} );
    $self->tt_config(
              TEMPLATE_OPTIONS => {
                        INCLUDE_PATH => ${gmaps::paths::templatePath},
              } );
	return;     
}


###
# overrides parents
###
sub processTemplate
{
	my $self = shift;
	my $xml = shift;
	my $vars = shift;

	$logger->debug( "Processing template '$xml' using $vars");

	return $self->tt_process( $xml, $vars )
		or $logger->logdie( "Could not process template '$xml': " . $self->param( 'tt' )->error() );
}


#######################################################################
# html frontends
#######################################################################


###
# returns the map
###
sub map
{
	my $self = shift;
	
	my $vars = {
		'GOOGLEMAPKEY' => ${gmaps::paths::googleMapKey},
	};
	
	my $template = 'web/map_html.tt2';
	return $self->processTemplate( $template, $vars );
}




=head2 getGLS

returns the markers for the perfsonar top level GLS

=cut
sub getGLS
{
    my $self = shift;
    $logger->debug( "Fetching list of gls $self");
    my $gls = $self->SUPER::getGLS();
	return $self->getMarkers( $gls );
}

=head2 discover

determines the markers for all the metadata at the service uri

=cut
sub discover
{
	my $self = shift;
	
	my $accessPoint = $self->query()->param('accessPoint');
	my $eventType = $self->query()->param('eventType');
	my $urn = $self->query()->param('urn');
    
    #$logger->warn( "access: $accessPoint, event: $eventType");
    
    # if no eventType do automatic remap
    if ( ! defined $eventType ) {
        my $evts = gmaps::EventType2Service::autoDetermineEventType( $accessPoint );
        if ( scalar @$evts > 1 ) {
            die "Too many eventTypes provided by '$accessPoint'";
        } else {
            $eventType = shift @$evts;
        }
    }
    
	my $markers = undef;
	$markers = $self->SUPER::discover( $accessPoint, $eventType );

	return $self->getMarkers( $markers );
}


sub showErrorPage
{
    my $self = shift;
    my @error = @_;
    
    print "<html><head>";
    print "<title>CGI Test</title>";
    print "</head>";
    print "<body><h2>Error Encounters</h2>@error";
    print "</body></html>";
    
    return;
}


#######################################################################
# utility methods
#######################################################################


sub getDomainFromFQDN
{
    my $self = shift;
    my $node = shift;
    
    if ( utils::addresses::isIpAddress( $node ) ) {
        return $node;
    }
    
    my @bits = split /\./, $node;
    
    shift @bits;
    
    return join( '.', @bits );
}



sub getNode
{
    my $self = shift;
    my $params = Params::Validate::validate( @_, { id => 1, domain => 1, latitude => 0, longitude => 0, services => 0, urns => 0 } );

    return $params;
}

sub getLink
{
    my $self = shift;
    my $params = Params::Validate::validate( @_, { src_id => 1, dst_id => 1, src_domain => 1, dst_domain => 1, eventType => 1, serviceType => 1, accessPoint => 1, urns => 1} );

    return $params;
}


=head2 getMarkers

 given a list of hashes representing the nodes,
 spit out the relevant xml for it

=cut
sub getMarkers
{
	my $self = shift;
	my $data = shift;
	
	# determine appropriate domain and path info
	# if path stuff, then create a path

	my $vars = {};
    my %seen = {};

	# if physical port for snmp, then
	foreach my $hash ( @$data ) {
	    
    	#$logger->warn( "ENTRY: " . Data::Dumper::Dumper $hash );

        # work out ma services
        if ( ! exists $hash->{urns} ) {
            
            #$logger->warn( "Adding MA");
            
            my ( $host, undef, undef ) = &perfSONAR_PS::Transport::splitURI( utils::xml::unescape( $hash->{accessPoint} ) );
            # try to resolve ip into a dns
            if ( utils::addresses::isIpAddress( $host ) ) {
                my ( $ip, $dns ) = utils::addresses::getDNS( $host );
                if ( defined $dns ) {
                    $host = $dns;
                }
            }

            # don't bother adding if already seen
            #$logger->warn( "HOST: $host, EVENT: " . $hash->{eventType} );
            my $uniq = $host . ':' . $hash->{serviceType};
            
            my $services = ();
            push @$services, { id => $host . ':' . $hash->{serviceType}, serviceType => $hash->{serviceType}, eventType => $hash->{eventType}, accessPoint => $hash->{accessPoint} };
            my $item = $self->getNode( 
                    { 
                        id => $host,
                        domain => $self->getDomainFromFQDN( $host ), 
                        latitude => $hash->{latitude}, 
                        longitude => $hash->{longitude}, 
                        services => $services
                        } );

            push @{$vars->{NODES}}, $item
                unless $seen{$uniq}++;
            
        } elsif ( exists $hash->{urns} ) {

            #$logger->warn( "Adding URN");

            # if there is a urn defined, then it's real data that can be fetched
            # we consider links first (ie tools that supply src to dst)
            # TODO: if it is of serviceType Utilisation, then we do something else
            my $serviceType = gmaps::EventType2Service::getServiceFromEventType( $hash->{eventType} );
            my $item = {};

            if ( $serviceType eq 'Utilisation' ) {
                
                # FIXME: id should be fqdn, try to reduce xml output?
                my $item = $self->getNode( 
                    { id => $hash->{node},
                        domain => $self->getDomainFromFQDN( $hash->{node} ), 
                        latitude => $hash->{latitude}, 
                        longitude => $hash->{longitude}
                    } );

                $item->{eventType} = $hash->{eventType};
                $item->{serviceType} = gmaps::EventType2Service::getServiceFromEventType( $hash->{eventType} );
                $item->{accessPoint} = $hash->{accessPoint};
                
                $item->{urns} = $hash->{urns};
                
                push @{$vars->{NODES}}, $item;

            } else {

                push @{$vars->{NODES}}, $self->getNode( 
                    { id => $hash->{src}, 
                        domain => $self->getDomainFromFQDN( $hash->{src} ), 
                        latitude => $hash->{srcLatitude}, 
                        longitude => $hash->{dstLongitude} } )
                    unless $seen{$hash->{src}}++;

	            push @{$vars->{NODES}}, $self->getNode( 
	                { id => $hash->{dst}, 
	                    domain => $self->getDomainFromFQDN( $hash->{dst} ), 
	                    latitude => $hash->{dstLatitude}, 
	                    longitude => $hash->{dstLongitude} } )
	                unless $seen{$hash->{dst}}++;

                # create a id for the link
                for( my $i=0; $i<scalar( @{$hash->{urns}} ); $i++ ) {
                    $hash->{urns}->[$i]->{id} = $hash->{src} . ' to ' . $hash->{dst} . ':' . $serviceType;
                }
                push @{$vars->{LINKS}}, $self->getLink( 
                    { src_id => $hash->{src}, 
                        dst_id => $hash->{dst}, 
                        src_domain => $self->getDomainFromFQDN( $hash->{src} ),
                        dst_domain => $self->getDomainFromFQDN( $hash->{dst} ),
                        serviceType => $serviceType,
                        eventType => $hash->{eventType},
                        accessPoint => $hash->{accessPoint},
                        urns => $hash->{urns} } );
                                
            }
                        
        }
	    
	}

	#$logger->info( "Found " . scalar @{$vars->{NODES}}  );
	
	my $template = 'web/data_xml.tt2';
	return $self->processTemplate( $template, $vars );
	
}




=head2 getServices

=cut
sub getServices
{
    my $self = shift;
	my $uri = $self->query()->param('gLS');
    
    my $services = $self->SUPER::getServices( $uri );
    
    my @list = ();
    
    foreach my $service ( @$services ) {
        my $hash = utils::urn::toHash( $service );
        push @list, $hash; 
    }
    
    my $vars = {
        'SERVICES' => \@list,
    };
    my $template = 'web/services_xml.tt2';
    return $self->processTemplate( $template, $vars );
}


sub catFile
{
    my $png = shift;
    open( PNG, "<$png") or die( "Could not fetch graph: $!\n" );
	my $out = undef;
	while( <PNG> ) {
		$out .= $_;
	}
	return \$out;
}

sub graph
{
	my $self = shift;
	my $args = {    uri => $self->query()->param('accessPoint'), 
                    eventType => $self->query()->param('eventType') || undef,
                    key => $self->query()->param('key') || undef,
                    urn => $self->query()->param('urn') || undef,
                    startTime => $self->query()->param('startTime') || undef, 
                    endTime => $self->query()->param('endTime') || undef,
                    period => $self->query()->param('period') || undef,
                    resolution => $self->query()->param('resolution') || undef, 
                    consolidationFunction => $self->query()->param('consolidationFunction') || undef
                };
	
	#$logger->warn( "graph args: $args:" . Data::Dumper::Dumper($args) );
	my $graph = undef;
	eval {
	    $graph = $self->SUPER::graph( $args );
    };
    if ( my $err = "$@" ) {
        $logger->fatal( "ERROR: $err" );
        if ( $err =~ /No data/ ) {
            $graph = &catFile( ${gmaps::paths::imagePath} . '/nodata.png' );
        }
    }
	$self->header_add( -type => 'image/png' );
	return $$graph;
}


1;
