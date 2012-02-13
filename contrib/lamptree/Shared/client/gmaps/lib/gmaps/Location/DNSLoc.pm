#!/bin/env perl

#######################################################################
# dns loc api to get info about location of an ip address
#######################################################################

use gmaps::Location;
use utils::addresses;

package gmaps::Location::DNSLoc;
@ISA = ( 'gmaps::Location' );
our $logger = Log::Log4perl::get_logger( 'gmaps::Location::DNSLoc' );

use strict;

# constructor
sub new
{
	my $classpath = shift;
	return $classpath->SUPER::new( @_ );
}


sub getLatLong
{
	my $self = shift;
	
	my $dns = shift;
	my $ip = shift;
	
	my $domain = undef;
	my $host = undef;

	$logger->debug( "using DNSLoc: dns=$dns ip=$ip" );

	# meed tje dms for lookups	
	if ( ! defined $dns ) {
		$logger->warn( "dns address must be supplied for DNSLoc lookup");
		return ( undef, undef );
	}
		
	# host only supports loc of dns address
	unless ( defined $dns && $dns ne '' ) {
		$logger->debug( "dns address of $ip could not be determined");
		return (undef, undef);
	}

	# untaint the dns
	if ( $dns =~ /\s*([\S\.]+)\s*/ ) {
		$host = $1;
	} else {
	    $host = $ip;
	}

	my $uri = '/usr/bin/host -t LOC ' . $host;
	$ENV{PATH} = "";

	# run
	my $out = `$uri`;
#aoacr1-oc192-chicr1.es.net location 40 43 12.000 N 74 0 18.000 W 0.00m 1m 1000m 10m

	my $long = undef;
	my $lat = undef;
	$logger->debug( "Running '$uri' -> '$out'" );

	if ( $out =~ / (\d+) (\d+) (\d+\.\d+) (N|S) (\d+) (\d+) (\d+\.\d+) (E|W) / )
	{
		$lat = $1 + ($2/60) + ($3/3600);
		if ( $4 eq 'S' ) {
			$lat *= -1;
		}
		$long = $5 + ($6/60) + ($7/3600);
		if ( $8 eq 'W' ) {
			$long *= -1;
		}
	}
	undef $out;

	return ( $lat, $long );

}


1;
