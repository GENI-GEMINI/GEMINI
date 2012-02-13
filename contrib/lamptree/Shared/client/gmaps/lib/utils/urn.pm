#!/bin/env perl

#######################################################################
# handles all urn descriptions
#######################################################################

package utils::urn;
use Log::Log4perl qw(get_logger);
our $logger = Log::Log4perl::get_logger( 'utils::xml');

use strict;

our $unknown = 'unknown';

=head2 toUrn

given a hash with domain, node and port as keys, will return the relevant urn for that 
hash can be:
	$hash = {
		domain => undef,	# domain name of 
		node => undef,		# fqn or name of host
		port => undef,		# port of host (if interface or ipaddress)
		
		# for paths expect '$src to $dst'
		src => undef,		# fqn of source node
		dst => undef,		# fqn of dest node
	};
=cut
sub toUrn
{
	my $hash = shift;
	
	my $urn = 'urn:ogf:network';
	
	my $domain = undef;
	my $host = undef;

	
	# get the domain
	if ( defined $hash->{domain} ) {
		$domain = $hash->{domain};
		if ( defined $hash->{node} ) {
			$host = $hash->{node};
		}
	} elsif ( defined $hash->{node} ) {
		my @fqn = split /\./, $hash->{node};
		$logger->debug( "FQN: @fqn");
		if ( scalar @fqn > 1 ) {
			$host = shift @fqn;
			$domain = join '.', @fqn, 
		} 
	}
	
	# get the port
	my $port = undef;
	if ( defined $hash->{port} ) {
		$port = $hash->{port};
	}
	
	# construct a path
	my $path = undef;
	if ( defined $hash->{src} && defined $hash->{dst} ) {
		$path = $hash->{src} . ' to ' . $hash->{dst};
	}
	
	# construct final urn
	if ( ! defined $path ) {
		
		# must have domain
		$urn .= ':domain=' . $domain;
		
		# host
		$urn .= ':node=' . $host
			if defined $host;
		
		$urn .= ':port=' . $port 
			if defined $port;
		
	}
	# paths
	else {
		
		$urn .= ':path=' . $path;
		
	}
	
	return $urn;		
}


sub fromUrn
{
	my $urn = shift;
	
	if ( $urn =~ /^urn:ogf:network:domain=(.*):node=(.*):port=(.*)$/ ) {
		my $domain = $1;
		$domain = undef if $domain eq $unknown;
		return ( $domain, $2, $3 );
	} elsif ( $urn =~ /^urn:ogf:network:domain=(.*):node=(.*)$/ ) {
		my $domain = $1;
		$domain = undef if $domain eq $unknown;
		return ( $domain, $2, undef );
	} elsif ( $urn =~ /^urn:ogf:network:domain=(.*)$/ ) {
		my $domain = $1;
		$domain = undef if $domain eq $unknown;
		return ( $domain, undef, undef );
	} else {
#		$logger->warn( "Could not parse urn '$urn'");
		return ( undef, undef, undef );
	}

}

=head2 getHash

split the urn

=cut
sub toHash
{
    my $urn = shift;
    my $hash = {};
    if ( $urn =~ /^urn:ogf:network:(.*)$/ ) {
        my @stuff = split /\:/, $1;
        foreach my $item ( @stuff ) {
            my ( $key, $value ) = split /\=/, $item;
            $hash->{$key} = $value;
        }
    }
    return $hash;
}

=head2 fromHash

=cut
sub fromHash
{
    my $hash = shift;
    
    my $urn = 'urn:ogf:network';
    
    my $okay = 0;
    foreach my $key ( sort keys %$hash ) {
        $urn .= ':' . $key . '=' . $hash->{$key};
        $okay = 1;
    }
    
    return undef
        if ! $okay;
        
    return $urn;
}


1;
