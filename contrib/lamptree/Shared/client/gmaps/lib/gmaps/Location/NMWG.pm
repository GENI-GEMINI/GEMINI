#!/usr/bin/perl


# use the nmwg schema to return the location

use gmaps::Location;

package gmaps::Location::NMWG;
@ISA = ( 'gmaps::Location');
our $logger = Log::Log4perl::get_logger( 'gmaps::Location::NMWG' );


use strict;


# constructor
sub new
{
	my $classpath = shift;
	return $classpath->SUPER::new( @_ );
}


###
# getLocation - returns the hash representing the geographical location of the port
###
sub getLatLong
{
	my $self = shift;

	# not used.
	my $dns = shift;
	my $ip = shift;
	
	my $nodeEl = shift; # node element

	my $urn = shift; # don't really care

	
	# can be either in the bit directly underneath or in the location element
	my $long = undef;
	my $lat = undef;
	
	# try directly underneath
	foreach my $node ( $nodeEl->childNodes() ) 
	{
		if ( $node->localname() eq 'latitude' ) {
			$logger->debug( "Found latitude: $node " . $node->toString );
			$lat = $node->to_literal();
		}
		elsif ( $node->localname() eq 'longitude' ) {
			$logger->debug( "Found longitutde: $node " . $node->toString );
			$long = $node->to_literal();
		}
		# insdie
		elsif ( $node->localname() eq 'location' ) {
		
			foreach my $loc ( $node->childNodes() ) {
				if ( $loc->localname() eq 'latitude' ) {
					$logger->debug( "Found latitude: $node " . $loc->toString );
					$lat = $loc->to_literal();
				}	
				elsif ( $loc->localname() eq 'longitude' ) {
					$logger->debug( "Found longitutde: $node " . $loc->toString );
					$long = $loc->to_literal();
				}
			}
		
		}
	}

	return ( $lat, $long );

}


1;
