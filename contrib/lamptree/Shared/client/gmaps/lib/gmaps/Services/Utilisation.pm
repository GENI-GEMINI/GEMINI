use utils::urn;
use gmaps::Location;
use Log::Log4perl qw(get_logger);


=head1 NAME

gmaps::Services::Utilisation - An interface to interact with a remote 
utilisation service.  

=head1 DESCRIPTION

This module provides functions to query a remote perfsonar measurement point
or measurement archive. Inherited classes should overload the appropiate
methods to provide customised access to the service in question.

=head1 SYNOPSIS

    use gmaps::Services::Utilisation;
    
    # create a new service
    my $service = gmaps::Service::Utilisation->new( 'http://localhost:8080/endpoint' );
  
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
package gmaps::Services::Utilisation;
use base 'gmaps::Service';

our $logger = Log::Log4perl->get_logger( "gmaps::Services::Utilisation");

our $eventType = 'http://ggf.org/ns/nmwg/characteristic/utilization/2.0';

use Data::Dumper;
use strict;

=head2 new( uri )
create a new instance of a utilisation client service
=cut
sub new
{
	my gmaps::Services::Utilisation $class = shift;
	my $self = fields::new( $class );
	$self->SUPER::new( @_ );
	return $self;
}


#######################################################################
# INTERFACE
#######################################################################


=head2 isAlive
returns boolean of whether the client service is alive or not 
=cut
sub isAlive
{
	my $self = shift;
	my $eventType = 'echo.ls';
	return $self->SUPER::isAlive( $eventType );
}




=head2 fetch( uri, startTime, endTime )
retrieves the data for the urn
=cut
sub getData
{
	my ( $self, @args ) = @_;
	my $params = Params::Validate::validate( @args, { urn => 0, key => 0, eventType =>0, startTime => 0, endTime => 0, resolution => 0, consolidationFunction => 0 } );


    if ( defined $params->{key} ) {
        
        # FIXME: how to deal with only single keys (ie in or out) - query on and return on single column.
        
        # assume that the key is composed of keyIn,KeyOut
        ( $params->{keyIn}, $params->{keyOut} ) = split /\,/, $params->{key};
        
    } else {

        my $hash = &utils::urn::toHash( $params->{urn} );

    	# determine if the port is a ip address
    	$params->{ifName} = $hash->{port};
    	$params->{hostName} = $hash->{node};
    	
    	if ( $hash->{domain} ne 'unknown' ) {
	   	    $params->{authRealm} = $hash->{domain};
    	}
    }

	# fetch the data form the ma
	my $requestXML = 'Utilisation/fetch_xml.tt2';
	my $filter = '//nmwg:message';
	
	# we only get one message back, so 
	my @temp = ();
	my ( $message, @temp ) = $self->processAndQuery( $requestXML, $params, $filter );

	my $idRef = $self->getDataId( $message );	
	$logger->debug( "Found metadata ids for in=" . $idRef->{in} . ' and out=' . $idRef->{out} );
	
	# list the fields as in and out
	@{$self->{FIELDS}} = qw( in out );
	
	# now get teh actually data elements
	return parseData( $message, $idRef );
	
}


#######################################################################
# UTILITY
#######################################################################

=head2 getPorts( urn )
 returns list of urns of monitorign ports
=cut
sub getMetaData
{
	my $self = shift;
	my @args = @_;
	my $params = Params::Validate::validate( @args, { urn => 0, key => 0, eventType =>0, startTime => 0, endTime => 0, resolution => 0, consolidationFunction => 0 } );

	my $requestXML = 'Utilisation/query-all-ports_xml.tt2';
	my $filter = '//nmwg:message'; # /nmwg:metadata[@id]/netutil:subject/nmwgt:interface

	# overload query
	my $vars = {
		'eventType' => $eventType,
	};
	my @ans = $self->processAndQuery( $requestXML, $vars, $filter );
		
	my $data = {};
	
	foreach my $element ( @ans ) {

    	foreach my $top ( $element->childNodes() ) 
		{
        
            $logger->debug( 'TOP ' . $top->localname() );
            if ( $top->localname() eq 'metadata' ) {
                
                my $id = $top->getAttribute( 'id' );
                $logger->debug( " GOT ID: $id");
                my $hash = $data->{$id};
                
                
                foreach my $meta ( $top->childNodes() ) {
                    
                    $logger->debug( "  " . $meta->localname() );
                    if ( $meta->localname() eq 'subject') {
                        
                        foreach my $subject ( $meta->childNodes() ) {

                            $logger->debug( "   " . $subject->localname() );
                            if ( $subject->localname() eq 'interface') {
                            
                        		foreach my $node ( $subject->childNodes() ) 
                        		{
                        			if ( $node->localname() eq 'hostName' ) {
                        				$data->{$id}->{node} = $node->to_literal();
                        				$data->{$id}->{hostName} = $node->to_literal();
                        				$data->{$id}->{name} = $node->to_literal();
                        			} elsif ( $node->localname() eq 'ifAddress' ) {
                        				$data->{$id}->{ipAddress} = $node->to_literal();
                        			} elsif ( $node->localname() eq 'ifName' ) {
                        				$data->{$id}->{ifName} = $node->to_literal();
                        			} elsif ( $node->localname() eq 'ifDescription' ) {
                        				$data->{$id}->{ifDescription} = $node->to_literal();	
                        			} elsif ( $node->localname() eq 'capacity' ) {
                        				$data->{$id}->{capacity} = $node->to_literal();
                        			} elsif ( $node->localname() eq 'authRealm' ) {
                        				$data->{$id}->{domain} = $node->to_literal();
                        			} elsif ( $node->localname() eq 'direction' ) {
                        				$data->{$id}->{direction} = $node->to_literal();
                        			}
                        		}

                        		# problem is that some of the services out there are all layer 3 - however, 
                        		# are configured incorrectly such that the only discernable difference between
                        		# metadata is that of the ifName as the ipAddress points at the management ip
                        		# rather than the router/gateway ip.
                        		# determine layer
                        		if ( $data->{$id}->{ipAddress} && $data->{$id}->{ifName} ) {
                        			$data->{$id}->{port} = $data->{$id}->{ifName};
                        		} elsif( ! $data->{$id}->{ifName} ) {
                        			$data->{$id}->{port} = $data->{$id}->{ipAddress};
                        		} else {
                        			$data->{$id}->{port} = $data->{$id}->{ifName};
                        		}

                        		# if null domain
                        		if ( ! defined $data->{$id}->{domain} ) {
                        			$data->{$id}->{domain} = ${utils::urn::unknown};
                        		}

                                
                            }
                            
                        }
                        
                    }
                    
                }
            
            } elsif ( $top->localname() eq 'data' ) {
            # link keys into the hash
            
                my $id = $top->getAttribute( 'metadataIdRef');
                $logger->debug( " GOT ID $id");
            
                foreach my $key ( $top->childNodes() ) {
                    
                    $logger->debug( " " . $key->localname() );
                    foreach my $params ( $key->childNodes() ) {
                        
                        $logger->debug( "  " . $params->localname() );
                        foreach my $param ( $params->childNodes() ) {
                            
                            $logger->debug( "   " . $param->localname() . " id = " . $param->getAttribute( 'name') );
                            if ( $param->getAttribute('name') eq 'maKey' ) {
                                $logger->debug( "    setting key to " . $param->to_literal() );
                                $data->{$id}->{key} = $param->to_literal();
                            }
                             
                        }
                    }
                    
                }
                
                
            }
        
        }

	}
	
    
    # a problem is that the snmp ma reports two separate meta data for in and out traffic for the same interface
    # as a result, in order to get a full view of an interface, one needs to actually query two separate
    # metadata to get both in and out.
    # we solve this by iterating through the list of metadataId's and determining if the
    # urn's match (ie, it's the same interface we're looking at). need to build the relevant keys for that interface
    # we use the key names keyIn and keyOut to signify the relevant in and out keys for the interface (assumes two metadata)
    
    # add new data to each metadata
    my %seen = ();
    foreach my $id ( keys %$data ) {
        
        # don't bother if we don't have a valid port for this node
		next unless ( $data->{$id}->{port} );
        
		# determine urn for node
		$data->{$id}->{urn} = &utils::urn::toUrn( { 'domain' => $data->{$id}->{domain}, 'node' => $data->{$id}->{node}, 'port' => $data->{$id}->{port}});
        # build array of matching
        push @{$seen{$data->{$id}->{urn}}}, $id;

        $data->{$id}->{accessPoint} = $self->uri();

    }


    my $final = {};
    # determine same interfaces and work out in and out metadata blocks
    foreach my $urn ( keys %seen ) {
        
        foreach my $id ( @{$seen{$urn}} ) {

            if ( defined $data->{$id}->{key} ) {
                
                my $keyDir = 'key' . ucfirst( $data->{$id}->{direction} );
                
                $logger->debug( "merging data from $id to $urn with $keyDir key " . $data->{$id}->{key});

                # copy hash, not reference as we need to add data
                while( my ( $k, $v ) = each %{$data->{$id}} ) {
                    next if defined $final->{$urn}->{$k};
                    $final->{$urn}->{$k} = $v;
                }
                
                $final->{$urn}->{$keyDir} = $data->{$id}->{key};
                
                delete $final->{$urn}->{key};
            }


        }
    }

    # add to final out
    my @out = ();

    foreach my $urn ( keys %$final ) {
        
        # modify urn to have keys
        $final->{$urn}->{accessPoint} = $self->uri();
        $final->{$urn}->{eventType} = $params->{eventType};
        $final->{$urn}->{serviceType} = gmaps::EventType2Service::getServiceFromEventType( $params->{eventType} );

        # determine coordinate posisionts
        # TODO: host name may need to be qualified
        ( $final->{$urn}->{latitude}, $final->{$urn}->{longitude} ) = gmaps::Location->getLatLong( $final->{$urn}->{hostName}, $final->{$urn}->{ipAddress}, undef, undef );

        $final->{$urn}->{urn} .= ':key=' . $final->{$urn}->{keyIn} . ',' . $final->{$urn}->{keyOut};

        my $urns = ();
        push @$urns, { id => $final->{$urn}->{port}, urn => $final->{$urn}->{urn} };
        $final->{$urn}->{urns} = $urns;
                
        $logger->debug( Data::Dumper::Dumper( $final->{$urn} ) );


        push @out, $final->{$urn};
        
        
    }

	return \@out;
}



sub getDomains
{
	my $self = shift;

}




#######################################################################
# data handling
#######################################################################

# determines the appropiate id for the in and out
sub getDataId
{
	my $self = shift;
	my $message = shift;

	# METHOD 1:
        # determine the appropiate id's for the metadata/data relation from their direction
        # use the fact htat we have loaded the query with metaIn and metaOut, so search for these
        # in the metadata attribute list as metadataIdRef="#metaIn".
        # then we need to match the @id value to the @metadataidRef in the relevant //nmwg:data element

        my $idRef = {
                'in' => undef,
                'out' => undef,
        };
        foreach my $meta ( $message->findnodes( "//nmwg:metadata[\@id]" ) ) {
                $logger->debug( "META: $meta \n" . $meta->toString() );
                # get attribute
                if ( $meta->getAttribute( 'metadataIdRef') eq '#metaIn' ) {
                        $idRef->{in} = $meta->getAttribute( 'id' );
                }
                elsif ( $meta->getAttribute( 'metadataIdRef') eq '#metaOut' ) {
                        $idRef->{out} = $meta->getAttribute( 'id' );
                }

        }

	if ( defined $idRef->{in} && defined $idRef->{out} ) {
		return $idRef;
	}

	$logger->debug( "Trying method 2 to determine metadata/data relations" );

	# however, the java implementation rewrites the tags... :(
	# METHOD 2
	# do through each meta data and determine whether the direction is in or out	
	foreach my $direction ( qw/in out/ ) {
		my $xpath = "//nmwg:metadata[\@id][descendant::nmwgt:direction[text()='" . $direction . "']]" ;
		foreach my $meta ( ${utils::xml::xpc}->find( $xpath, $message )->get_nodelist() ) {
			$idRef->{$direction} = $meta->getAttribute( 'id' );
		}
	}

	if ( defined $idRef->{in} && defined $idRef->{out} ) {
                return $idRef;
    } else {
		$logger->fatal( "Could not determine appropiate metadata/data relationship" );
	}


}

sub parseData
{
        my $el = shift;# output of getUtilization
        my $idRefs = shift;

        my $data = undef;

		$logger->debug( "Metadata id's for in: " . $idRefs->{in} . ", out: " . $idRefs->{out});

        # now we need to fetch the data from the xpath xml structure
        $data = &mergeUtilizationData(
                                &getUtilizationData( $el, $idRefs->{in} ),
                                &getUtilizationData( $el, $idRefs->{out} )
                        );

        #$logger->debug( Dumper $data );
                
        return $data;
}



sub mergeUtilizationData
{
	my $in = shift;
	my $out = shift;
	
	my %data = ();
		
	foreach my $i ( @$in ) {
		my ( $inTime, $inValue ) = split /:/, $i;
		$data{$inTime}{in} = $inValue;
	}

	foreach my $o ( @$out) {
		my ( $outTime, $outValue ) = split /:/, $o;
		$data{$outTime}{out} = $outValue;
	}

	return \%data;
}


sub getUtilizationData
{
        my $el = shift; # //message
        my $metadataIdRef = shift;

        $logger->debug( "Getting utilisation data using '$metadataIdRef'" );
        my @tuples = ();

	foreach my $child ( $el->childNodes() ) {
		
		#$logger->fatal( " $metadataIdRef -> " . $child->localname() );
		
		if ( $child->localname() eq 'data'
		  && $child->getAttribute( 'metadataIdRef' ) eq $metadataIdRef )
		{
			$logger->debug( "Found! <data/> for $metadataIdRef" );
			
			foreach my $datum ( $child->childNodes() ) {
				if( $datum->localname() eq 'datum' ) {
					
					#$logger->info( "  " . $datum->toString );
					
					# get the time of the datum
					my $time = $datum->getAttribute( 'timeValue' );
					if ( ! $time ) {
						$time = $datum->getAttribute( 'time' );
					}
					next unless $time =~ /^\d+$/;

					# fix bug
					next if $time < 1000000;

					# get the value
					my $value = $datum->getAttribute('value');
					next if $value eq 'nan';

					# add
					push( @tuples, $time . ':' . $value );
				}
			}
			last; # don't bother searching through the rest of it
		}
	}

        $logger->debug( "Entries = " . scalar @tuples );

        return \@tuples ;
}




1;


=head1 SEE ALSO

L<gmaps::Service>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS 
  
Questions and comments can be directed to the author, or the mailing list. 

=head1 VERSION

$Id: Utilisation.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, E<lt>ytl@slac.stanford.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Internet2

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
