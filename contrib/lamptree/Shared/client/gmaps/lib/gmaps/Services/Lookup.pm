use utils::urn;
use gmaps::Location;
use Log::Log4perl qw(get_logger);


=head1 NAME

gmaps::Services::Lookup - An interface to interact with a global lookup service 

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

package gmaps::Services::Lookup;
use base 'gmaps::Service';

our $logger = Log::Log4perl->get_logger( "gmaps::Services::Lookup");

use strict;

=head2 new( uri )
Create a new client object to interact with the uri
=cut
sub new
{
	my gmaps::Services::Lookup $class = shift;
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
	my $self = shift;
	my $urn = shift;
	
	my $period = undef;
	
	my ( $temp, $temp, $temp, $path, @params ) = split /\:/, $urn; 
	$logger->debug( "PATH: $path, @params");
	
	my $src = undef;
	my $dst = undef;
	if( $path =~ m/^path\=(.*) to (.*)$/ ) {
		$src = $1;
		$dst = $2;
	} else {
		
		$logger->logdie( "Could not determine source and destination or urn");
		
	}
	$logger->debug( "Fetching '$urn': path='$src' to '$dst' params='@params'" );

	# determine if the port is a ip address
	my $vars = {
			'src' => $src,
			'dst' => $dst,
		};

	# form the parameters
	foreach my $s ( @params ) {
		my ( $k, $v ) = split /\=/, $s;
		$vars->{$k} = $v;
	}

	if ( defined $period ) {
		$vars->{'PERIOD'} = $period;
	} else {
		$vars->{'PERIOD'} = 86400;
	}
	# need to have real time becuase of problems with using N
	$vars->{"ENDTIME"} = time();
	$vars->{'STARTTIME'} = $vars->{'ENDTIME'} - $vars->{'PERIOD'};

	# fetch the data form the ma
	my $requestXML = 'Lookup/fetch_xml.tt2';
	my $filter = '//nmwg:message';
	
	# we only get one message back, so 
	my @temp = ();
	my ( $message, @temp ) = $self->processAndQuery( $requestXML, $vars, $filter );
	
	# now get teh actually data elements
	return $self->parseData( $message );
	
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
	my $params = Params::Validate::validate( @args, { urn => 0, key => 0, eventType =>0 } );
	
	my $requestXML = 'Lookup/query-all-ports_xml.tt2';
	my $filter = '//nmwg:message/nmwg:data[@id]/nmwg:metadata';

	# overload query
	my $vars = {
	};
	my @ans = $self->processAndQuery( $requestXML, $vars, $filter );
	
	# renove unique urns
	my %seen = ();
	
	my @out = ();
	foreach my $meta ( @ans ) {

		my $hash = {};
			
		foreach my $node ( $meta->childNodes() ) 
		{
			# hostnames
			# TODO: support other topology type (with ip address)
			#$logger->warn( "TAG: " . $node->localname() );
			
			if ( $node->localname() eq 'subject' ) {
				foreach my $subnode ( $node->childNodes() )  {
				    				    
        			#$logger->warn( "SUBTAG: " . $subnode->localname() );

					if ( $subnode->localname() eq 'service' ) {
						foreach my $subsubnode ( $subnode->childNodes() ) {
							if ( $subsubnode->localname() eq 'serviceName' ) {
								$hash->{serviceName} = $subsubnode->textContent;
							}
							elsif ( $subsubnode->localname() eq 'accessPoint' ) {
								$hash->{accessPoint} = $subsubnode->textContent;
							}
							elsif ( $subsubnode->localname() eq 'serviceType' ) {
								$hash->{serviceType} = $subsubnode->textContent;
							}
							elsif ( $subsubnode->localname() eq 'serviceDescription' ) {
								$hash->{serviceDescription} = $subsubnode->textContent;
							}
						}
					}
				} #subnode
			}

		}

		# don't bother if we don't have a valid port for this node
		next unless ( $hash->{accessPoint} );

        # remap accessPoint to URL
        $hash->{accessPoint} = URI::Escape::uri_unescape( $hash->{accessPoint} );
        
		# add params to urn (prob not what we want to do...)
		# my $urn = 'urn:ogf:network:serviceType=' . $hash->{serviceType} . ':serviceName=' . $hash->{serviceName} . ':accessPoint=' . URI::Escape::uri_escape( $hash->{accessPoint} );

        # no point adding it more than once
        $seen{$hash->{accessPoint}}++;
        next if $seen{$hash->{accessPoint}} > 1;
        
		# determine coordinates for host
        my ( $host, undef, undef ) = &perfSONAR_PS::Transport::splitURI( utils::xml::unescape( $hash->{accessPoint} ) );
		( $hash->{latitude}, $hash->{longitude} ) = gmaps::Location->getLatLong( $host, $host, undef, undef );
        
        # enumerate for each service the accessPoint provides
        my $services = gmaps::EventType2Service::autoDetermineService( $hash->{accessPoint} );

        foreach my $service ( @$services ) {
            
            # need to make copy of hash
            my %this_hash = %$hash;
            
		    # add ma
    		$this_hash{eventType} = gmaps::EventType2Service::getEventTypeFromService( $service );
            if ( $this_hash{serviceType} eq 'MA' && defined $this_hash{eventType}) {
                 $this_hash{serviceType} = gmaps::EventType2Service::getServiceFromEventType( $this_hash{eventType} );
            }

		    # add it
		    push @out, \%this_hash;
        }

	}
	
    # $logger->info( "FOUND:");
    # foreach my $item ( @out ) {
    #       $logger->info( "item " . Data::Dumper::Dumper $item );      
    # }
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
    
    $logger->logdie( "Fetch not implemented in LS lookups");
    return undef;
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

$Id: Lookup.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, E<lt>ytl@slac.stanford.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Internet2

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
