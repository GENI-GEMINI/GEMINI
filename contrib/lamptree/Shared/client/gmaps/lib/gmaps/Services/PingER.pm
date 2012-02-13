use utils::urn;
use gmaps::Location;
use Log::Log4perl qw(get_logger);


=head1 NAME

gmaps::Services::PingER - An interface to interact with a remote 
PingER service.  

=head1 DESCRIPTION

This module provides functions to query a remote perfsonar measurement point
or measurement archive. Inherited classes should overload the appropiate
methods to provide customised access to the service in question.

=head1 SYNOPSIS

    use gmaps::Services::PingER;
    
    # create a new service
    my $service = gmaps::Service::PingER->new( 'http://localhost:8080/endpoint' );
  
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

package gmaps::Services::PingER;
use base 'gmaps::Service';

our $logger = Log::Log4perl->get_logger( "gmaps::Services::PingER");

use strict;

=head2 new( uri )
Create a new client object to interact with the uri
=cut
sub new
{
	my gmaps::Services::PingER $class = shift;
	my $self = fields::new( $class ); 
	$self->SUPER::new( @_ );

	return $self;
}

#######################################################################
# INTERFACE
#######################################################################

=head2 isAlive
returns aboolean of whether the pinger service is alive or not
=cut
sub isAlive
{
	my $self = shift;
	my $eventType = 'echo';
	return $self->SUPER::isAlive( $eventType );
}



=head2 fetch( urn )
returns a hashof $hash->{$time}->{metric} values for the specified urn.
=cut
sub getData
{
	my ( $self, @args ) = @_;
	my $params = Params::Validate::validate( @args, { urn => 0, key => 0, eventType =>0, startTime => 0, endTime => 0, resolution => 0, consolidationFunction => 0 } );
	
	my ( $temp, $temp, $temp, $path, @params ) = split /\:/, $params->{urn}; 
	$logger->debug( "PATH: $path, @params");
	
	if ( ! defined $params->{key} ) {
    	my $src = undef;
    	my $dst = undef;
    	if( $path =~ m/^path\=(.*) to (.*)$/ ) {
    		$src = $1;
    		$dst = $2;
    	} else {
    		$logger->logdie( "Could not determine source and destination or urn '" . $params->{urn} . "'");
    	}
	
    	$logger->debug( "Fetching '" . $params->{urn} . "': path='$src' to '$dst' params='@params'" );

    	# determine if the port is a ip address
    	$params->{src} = $src;
    	$params->{dst} = $dst;
    } 

	# form the parameters
	foreach my $s ( @params ) {
		my ( $k, $v ) = split /\=/, $s;
		$params->{$k} = $v;
	}

	# fetch the data form the ma
	my $requestXML = 'PingER/fetch_xml.tt2';
	my $filter = '//nmwg:message';
	
	# we only get one message back, so 
	my @temp = ();
	my ( $message, @temp ) = $self->processAndQuery( $requestXML, $params, $filter );
	
	# now get teh actually data elements
	return $self->parseData( $message );
	
}

=head2 getGraphArgs
returns the rrd graph arguments to produce a graph of utilisation data
=cut
sub getGraphArgs
{
	my $self = shift;
	my $start = shift;
	my $end = shift;
	
	# assume bytes
	my $rpn = ',8,*';

	my @args = ();
	push @args, '--end=' . $end;
	push @args, '--start=' . $start;
	push @args, '--vertical-label=units';
	foreach my $field ( @{$self->{FIELDS}}) {
		push @args, 'DEF:' . $field . '=' . $self->{FILENAME} . ':' . $field . ':AVERAGE';
		push @args, 'CDEF:' . $field . 'RPN' . '=' . $field . $rpn;	
	}
	
	# graph sepcs
	push @args, 'LINE2:inRPN' . '#00FF00' . ':in';
	push @args, 'AREA:outRPN' . '#0000FF' . ':out';
	
	#$logger->warn( "args: @args" );
	
	return \@args;
	
}




#######################################################################
# UTILITY
#######################################################################


###
# returns list of urns of monitorign ports
###
sub getMetaData
{
	my $self = shift;
	my @args = @_;
	my $params = Params::Validate::validate( @args, { urn => 0, key => 0, eventType =>0, startTime => 0, endTime => 0, resolution => 0, consolidationFunction => 0 } );

	
	my $requestXML = 'PingER/query-all-ports_xml.tt2';
	my $filter = '//nmwg:message/nmwg:metadata[@id]';

	# overload query
	my $vars = {
	};
	my @ans = $self->processAndQuery( $requestXML, $vars, $filter );
		
	my @out = ();
	foreach my $item ( @ans ) {

		my $hash = {};
		
		my $meta = {};
		
		foreach my $node ( $item->childNodes() ) 
		{
			# hostnames
			# TODO: support other topology type (with ip address)
			#$logger->debug( "TAG: " . $node->localname() );
			if ( $node->localname() eq 'subject' ) {
				foreach my $subnode ( $node->childNodes() )  {
					if ( $subnode->localname() eq 'endPointPair' ) {
						foreach my $subsubnode ( $subnode->childNodes() ) {
							if ( $subsubnode->localname() eq 'src' ) {
								if ( $subsubnode->getAttribute('type') eq 'hostname' ) {
									$hash->{src} = $subsubnode->getAttribute('value');
								}
							}
							elsif ( $subsubnode->localname() eq 'dst' ) {
								if ( $subsubnode->getAttribute('type') eq 'hostname' ) {
									$hash->{dst} = $subsubnode->getAttribute('value');
								}
							}					
						}
					}
				} #subnode
			}
						
			# params
			# elsif ( $node->localname() eq 'key' ) {
			# 	foreach my $subnode ( $node->childNodes() )  {
					elsif ( $node->localname() eq 'parameters' ) {
						foreach my $subnode ( $node->childNodes() ) {
							if ( $subnode->localname() eq 'parameter' ) {
								my $param = $subnode->getAttribute('name');
								$meta->{$param} = $subnode->getAttribute('value');
							}
						}
					}
					elsif ( $node->localname() eq 'key' ) {
					    $meta->{key} = $node->getAttribute('id');
					}
			# 	} #subnode
			# }
			
		}
		

		# don't bother if we don't have a valid port for this node
		next unless ( $hash->{src} && $hash->{dst} );

		# determine urn for item
		my $urn = &utils::urn::toUrn( { 'src' => $hash->{src}, 'dst' => $hash->{dst} } );
		my @keys = ();
		foreach my $k ( keys %$meta ) {
			next if $k eq 'src' or $k eq 'dst' 
			  or $k eq 'mas' or $k eq 'urn'
			  or $k eq 'latitude' or $k eq 'longitude';
			push @keys, $k;
		}
		# add params to urn (prob not what we want to do...)
		$urn .= ':'
			if scalar @keys;
		for( my $i=0; $i<scalar @keys; $i++ ) {
			$urn .= $keys[$i] . '=' . $meta->{$keys[$i]};
			$urn .= ':' unless $i eq scalar @keys - 1;
		}

		# add own ma
		$hash->{eventType} = $params->{eventType};
		$hash->{serviceType} => gmaps::EventType2Service::getServiceFromEventType( $hash->{eventType} );
		
		my $urns = ();
		push @$urns, { urn => $urn };
        $hash->{urns} = $urns;

        $hash->{accessPoint} = $self->uri();

		# determine coordinate posisionts
		# get urns for source and dst for location lookups etc
		( $hash->{srcLatitude}, $hash->{srcLongitude} ) = gmaps::Location->getLatLong( $hash->{src}, $hash->{src}, undef, undef );
		( $hash->{dstLatitude}, $hash->{dstLongitude} ) = gmaps::Location->getLatLong( $hash->{dst}, $hash->{dst}, undef, undef );

		# add it
		push @out, $hash;
		
			
	}
	#$logger->info( "Found ports: @out");
	return \@out;
}

#######################################################################
# data handling
#######################################################################

=head2 parseData
given the <nmwg:message/> element, will parse through and retrieve a 
hash of $hash->{$time}->{minRtt|maxRtt...} values;
=cut
sub parseData
{
	my $self = shift;
    my $el = shift; # //message

    $logger->debug( "Getting pinger data" );
    my $tuples = {};

	# get the correct metadata
	### TODO: lets's jsut assume that it's correct

	my %seen = ();

	foreach my $child ( $el->childNodes() ) {
		if ( $child->localname() eq 'data'
#		  && $child->getAttribute( 'metadataIdRef' ) eq $metadataIdRef )
		)
		{
			$logger->debug( "Found! <data/>" );
			foreach my $commonTime ( $child->childNodes() ) {
				if( $commonTime->localname() eq 'commonTime' ) {
					$logger->debug(" commonTime" );
					my $time = $commonTime->getAttribute( 'value' );
					next unless $time =~ /^\d+$/;
	
					foreach my $datum ( $commonTime->childNodes() ) {
					
					
						if( $datum->localname() eq 'datum' ) {
							# get the time of the datum
								
							my $param = $datum->getAttribute( 'name');
						
							# get the value
							my $value = $datum->getAttribute('value');
							next if $value eq 'nan';
							$logger->debug("  datum $param = $value" );
							
							# remap boolean values
							if ( $value eq 'false' ) {
								$value = 0;
							} elsif ( $value eq 'true' ) {
								$value = 1;
							}
							
							# keep tabs on what params we've seen
							$seen{$param}++;
															
							# add
							$tuples->{$time}->{$param} = $value;
							
						}
					}
					
					# add loss as its not currently returned unless there is loss

				}
			}
			last; # don't bother searching through the rest of it
		}
	}

	# add zero values for some params
	foreach my $t ( keys %$tuples ) {
		foreach my $param ( qw/ iqrIpd maxIpd meanIpd /) {
			if ( ! exists $tuples->{$t}->{$param} ) {
			#	$logger->warn( "$param @ $t -> 0");
				$tuples->{$t}->{$param} = 0;
			}
			$seen{$param}++;
		}
	}


	@{$self->{FIELDS}} = keys %seen;
	undef %seen;

    $logger->debug( "Entries = " . scalar keys %$tuples );

    return $tuples;
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

$Id: PingER.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, E<lt>ytl@slac.stanford.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Internet2

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
