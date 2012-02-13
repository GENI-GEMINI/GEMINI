#!/usr/bin/perl

use LWP::UserAgent;
use gmaps::Location;

package gmaps::Location::GeoIPTools;
@ISA = ( 'gmaps::Location');

our $timeout = 3;
our $logger = Log::Log4perl::get_logger("gmaps::Location::GeoIPTools");

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

	# TODO: remap from dns
	$logger->debug( "using GeoIPTools: dns=$dns, ip=$ip");
	
	# prefer ip
	my $host = undef;
	if ( defined $ip ) {
		$host = $ip;
	} elsif ( defined $dns ) {
		$host = $dns;
	} else {
		# exit if we cna't determine what look up
		$logger->warn( "could not determine input for lookup");
		return (undef, undef);
	}
	
	# url to fetch from
	my $uri = "http://www.geoiptool.com/en/?IP=" . $host;

	# run
	my $ua = LWP::UserAgent->new();
	$ua->timeout( $timeout );
	$ua->agent( ${gmaps::paths::version} );

	my $req = HTTP::Request->new( GET => $uri );
	my $res = $ua->request( $req );
	my $out = $res->content();

	my $lat = undef;
	my $long = undef;	
	if ( $out =~ /Latitude:.*\n.*\>(\-?\d+\.\d+)/m ) {
		$lat = $1;
	}
	if ( $out =~ /Longitude:.*\n.*\>(\-?\d+\.\d+)/m ) {
		$long = $1;
	}
	undef $out;
	
	return ( $lat, $long );
}

