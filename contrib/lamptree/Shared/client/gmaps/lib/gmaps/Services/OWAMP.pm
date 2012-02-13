use utils::urn;
use gmaps::Location;
use Log::Log4perl qw(get_logger);
use Date::Parse;
use utils::addresses;

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
package gmaps::Services::OWAMP;
use base 'gmaps::Service';

our $logger = Log::Log4perl->get_logger( "gmaps::Services::OWAMP");

use Data::Dumper;
use strict;

=head2 new( uri )
create a new instance of a utilisation client service
=cut
sub new
{
	my gmaps::Services::OWAMP $class = shift;
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
		
	my ( $temp, $temp, $temp, $path, @params ) = split /\:/, $params->{urn}; 
	$logger->debug( "PATH: $path, @params");
	
	if( $path =~ m/^path\=(.*) to (.*)$/ ) {
        # TODO: check if ip address only
		$params->{src} = $1;
		$params->{dst} = $2;
	} else {
		$logger->logdie( "Could not determine source and destination or urn");
	}
	$logger->debug( "Fetching '" . $params->{urn} . "': path='" . $params->{src} . "' to '" . $params->{dst} . "' params='@params'" );

	# form the parameters
	foreach my $s ( @params ) {
		my ( $k, $v ) = split /\=/, $s;
		$params->{$k} = $v;
	}

	# fetch the data form the ma
	my $requestXML = 'OWAMP/fetch_xml.tt2';
	my $filter = '//nmwg:message';
	
	# we only get one message back, so 
	my @temp = ();
	my ( $message, @temp ) = $self->processAndQuery( $requestXML, $params, $filter );
	
	# now get teh actually data elements
	return $self->parseData( $message );
	
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
	
	my $requestXML = 'OWAMP/query-all-ports_xml.tt2';
	my $filter = '//nmwg:message/nmwg:metadata[@id]';

	# overload query
	my $vars = {
	};
	my @ans = $self->processAndQuery( $requestXML, $vars, $filter );
		
	my @out = ();
	foreach my $meta ( @ans ) {

		my $hash = {
		};
			
		foreach my $node ( $meta->childNodes() ) 
		{
			if ( $node->localname() eq 'subject' ) {
				foreach my $subnode ( $node->childNodes() )  {
				    
					if ( $subnode->localname() eq 'endPointPair' ) {
						foreach my $subsubnode ( $subnode->childNodes() ) {
							if ( $subsubnode->localname() eq 'src' ) {
								if ( $subsubnode->getAttribute('type') eq 'hostname' ) {
									$hash->{src} = $subsubnode->getAttribute('value');
								} elsif ( $subsubnode->getAttribute('type') eq 'ipv4' ) {
    								$hash->{src} = $subsubnode->getAttribute('value');
    							}
							}
							elsif ( $subsubnode->localname() eq 'dst' ) {
								if ( $subsubnode->getAttribute('type') eq 'hostname' ) {
									$hash->{dst} = $subsubnode->getAttribute('value');
								} elsif ( $subsubnode->getAttribute('type') eq 'ipv4' ) {
    								$hash->{dst} = $subsubnode->getAttribute('value');
    							}
							}
						}
					}
					
				} #subnode
			}
    		elsif ( $node->localname() eq 'parameters' ) {
    			foreach my $subnode ( $node->childNodes() ) {
    				if ( $subnode->localname() eq 'parameter' ) {
    					my $param = $subnode->getAttribute('name');
    					$hash->{$param} = $subnode->getAttribute('value');
                        $hash->{$param} = $subnode->textContent()
                            if ! defined $hash->{$param};
    				}
    			}
    		}

		}

		# don't bother if we don't have a valid port for this node
		next unless ( $hash->{src} && $hash->{dst} );


        # get urn for item
		my $urn = &utils::urn::toUrn( { 'src' => $hash->{src}, 'dst' => $hash->{dst} } );

        # try to resolve to useful dns names
        my $src_ip = undef;
        my $dst_ip = undef;
        my $src_dns = undef;
        my $dst_dns = undef;
        
        ( $src_ip, $src_dns )  = utils::addresses::getDNS( $hash->{src} );
        ( $dst_ip, $dst_dns )  = utils::addresses::getDNS( $hash->{dst} );

        if ( $src_dns ) {
            $hash->{src} = $src_dns;
        }
        if ( $dst_dns ) {
            $hash->{dst} = $dst_dns;
        }

		my @keys = ();
		foreach my $k ( keys %$hash ) {
			next if $k eq 'src' or $k eq 'dst';
				push @keys, $k;
		}
		
		# add params to urn (prob not what we want to do...)
		$urn .= ':'
			if scalar @keys;

		for( my $i=0; $i<scalar @keys; $i++ ) {
			$urn .= $keys[$i] . '=' . $hash->{$keys[$i]};
			$urn .= ':' unless $i eq scalar @keys - 1;
		}

		my $urns = ();
		push @$urns, { urn => $urn };
        $hash->{urns} = $urns;

		# add own ma
		if ( ! defined $params->{eventType} ) {
		    $params->{eventType} = 'http://ggf.org/ns/nmwg/tools/owamp/2.0';
	    }
		$hash->{eventType} = $params->{eventType};
		$hash->{serviceType} = gmaps::EventType2Service::getServiceFromEventType( $hash->{eventType} );
        $hash->{accessPoint} = $self->uri();

		( $hash->{srcLatitude}, $hash->{srcLongitude} ) = gmaps::Location->getLatLong( $hash->{src}, $src_ip, undef, undef );
		( $hash->{dstLatitude}, $hash->{dstLongitude} ) = gmaps::Location->getLatLong( $hash->{dst}, $dst_ip, undef, undef );

		# add it
		$logger->debug( "Adding " . Data::Dumper::Dumper $hash );
		push @out, $hash;

	}
	#$logger->info( "Found ports: @out");
	return \@out;
}



#######################################################################
# data handling
#######################################################################


sub parseData
{
	my $self = shift;
    my $el = shift; # //message
    
    $logger->debug( "Getting owamp data" );
    my $tuples = {};
    my %seen = ();
	# get the correct metadata
	### TODO: lets's jsut assume that it's correct


	foreach my $child ( $el->childNodes() ) {
		if ( $child->localname() eq 'data' )
		{

            foreach my $datum ( $child->childNodes() ) {

                if( $datum->localname() eq 'datum' ) {
                
                    # get time
                    my $timeType = $datum->getAttribute( 'timeType' );
                    my $time = undef;
                    if ( $timeType eq 'iso' || $timeType eq undef ) {
                        $time = $datum->getAttribute( 'startTime');
                        # parse into epoch
                        $time = Date::Parse::str2time( $time );
                    } else {
                        $logger->error( "unsupported time type '$timeType'");
                    }
                
                    next unless defined $time;
                
                    # get data
                    my @attributelist = $datum->attributes();
                    foreach my $attr ( @attributelist ) {
                        
                        next unless $attr->isa( 'XML::LibXML::Attr' );
                        my $key = $attr->nodeName();
                        next if $key =~ /time/i;
                        my $value = $attr->getValue();
                        
                        # convert to msec
                        if ( $key =~ /delay$/ || $key =~ /^maxError$/ ) {
                            $value = $value * 1000;
                        }
                        
                        $seen{$key}++;
	                    $tuples->{$time}->{$key} = $value;
        
                    }
                                
                    #$logger->debug( "$time : $value");
                
                }
            
            }

        }
        
    } # foreach

    @{$self->{FIELDS}} = keys %seen;

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

$Id: OWAMP.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, E<lt>ytl@slac.stanford.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Internet2

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
