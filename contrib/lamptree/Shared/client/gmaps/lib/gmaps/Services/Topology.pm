use Template;
use utils::urn;
use Data::Dumper;

use gmaps::Location;
use Log::Log4perl qw(get_logger);



=head1 NAME

gmaps::Service - An interface to interact with a remote service.  

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


package gmaps::Services::Topology;
use base 'gmaps::Service';

our $logger = Log::Log4perl->get_logger( "gmaps::Topology::Service");

use strict;

=head2 new( uri )
creates a new instance of the client service for uri
=cut
sub new
{
	my $classname = shift;
	my $self = $classname->SUPER::new( @_ );

	return $self;
}



#######################################################################
# interface
#######################################################################

=head2 isAlive
returns a boolean of whetehr the service is alive or not.
=cut
sub isAlive
{
	my $self = shift;
	my $eventType = 'echo.ma';
	return $self->SUPER::isAlive( $eventType );
}


=head2 discover
retrieves a list of urns of all ports on the service
=cut
sub discover
{
	my $self = shift;

	my $nodes = $self->getNodes( );
	my @data = ();
	foreach my $node ( @$nodes ) {
		#$logger->debug( "Looking at " . $node->toString() );
		# get the ports of the node
		push( @data, @{$self->getPorts( $node )} );
	};
	my @urns = ();
	foreach my $a ( @data ) {
		push @urns, $a->{urn};
	}
	
	return \@urns;
}

=head2 topology
retrieves a anon hash of data for all ports on the service
=cut
sub topology
{
	my $self = shift;

	my $nodes = $self->getNodes( );
	my @data = ();
	foreach my $node ( @$nodes ) {
		#$logger->debug( "Looking at " . $node->toString() );
		# get the ports of the node
		push( @data, @{$self->getPorts( $node )} );
	};
	
	return \@data;
}



=head2 fetch( #urn )

=cut
sub fetch
{
	my $self = shift;
	$logger->logdie( "fetch using topology");
	return;
}


#######################################################################
# domain
#######################################################################


=head2 getDomains
 returns list of urn's that the topology service contains
=cut
sub getDomains
{
	my $self = shift;

	# only want the first answer
	my ( $ans, @temp ) = $self->query('
		declare namespace nmwg="http://ggf.org/ns/nmwg/base/2.0/";
		//*:domain/@id
		',
		'//nmwg:message/nmwg:data/*'
	);
	
	if ( scalar @temp ) {
		$logger->fatal( "getDomains() returned incorrect answer");
		return undef;
	}
	
	my @out = ();
	my %unique = ();
	
	$logger->debug( "Domains: '$ans' " . ref( $ans ) );

	foreach my $list ( $ans->childNodes() ) {
		foreach my $id ( split /id\=/, $list->to_literal ) {
			if( $id =~ /\"(.*)\"/g ) {
				$unique{$1}++;
			}
		}
	}
	
	my @out = keys %unique;
    $logger->info( "Found domains: @out" );
	return \@out;

}



=head2 getNodesInDomain( $domain )
returns nodes
=cut
sub getNodesInDomain
{
	my $self = shift;
	my $domain = shift; # urn
	
	my $query = undef;
	if ( defined $domain ) {
		$query = "
		declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";
		//*:domain[\@id=\'$domain\']/*:node
		";
	} else {
		$query = "
		declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";
		//*:domain/*:node
		";
	}
	
	my @nodes = $self->query( $query );
	if( scalar @nodes < 1) {
		$logger->error( "No Nodes found in domain '$domain' for " . $self->host() . ':' . $self->port() );
    }
	    
	$logger->debug( "Found nodes: @nodes ");
	foreach my $ans ( @nodes ) {
		$logger->debug( "found: " . $ans->toString() );
	}
	
	return \@nodes;
}


#######################################################################
# nodes
#######################################################################


=head2 getNodes
 gets the xml element for the node defined by the urn
 urn can be either for a port or for the hostname
=cut
sub getNodes
{
	my $self = shift;
	my $urn = shift; # urn of port/host

	my $query = undef;
	
	# if no urn supplied, then get all nodes in all domains
	if ( defined $urn ) {
	
		$logger->debug( "Querying for single urn '$urn'");
	
		# determine if node or port
		my ( $domain, $host, $port ) = utils::urn::fromUrn( $urn );
		
		my $nodeUrn = utils::urn::toUrn( { 'domain' => $domain, 'node' => $host } );
		my $portUrn = utils::urn::toUrn( { 'domain' => $domain, 'node' => $host, 'port' => $port } );
		
		# if the two are the same, then there is no port
		
		if ( defined $port ) {
			$query = "
			declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";
			//nmtb:node[child::*port[\@id='$portUrn']
			";
		} else {
			$query = "
			declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";
			//*:domain/*:node[\@id='$urn']
			";	
		}
	}
	# get all nodes
	else {
		$logger->debug( "Querying for all nodes");
		$query = "
			declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";
			//*:domain/*:node
		";
	}
	

	my @nodes = $self->query( $query );

	#$logger->debug( "found: " . $ans->toString() );

	$logger->warn( "returned more than one node (" . scalar @nodes . ")" )
		if scalar @nodes > 1;	

	return \@nodes;


}

#######################################################################
# ports
#######################################################################


=head2 getPorts
 for given node element, returns a list of the ports by hash
=cut
sub getPorts
{
	my $self = shift;
	my $nodeEl = shift; # libxml node element
	
	# list
	my @out = ();
	
	my $hostName = undef;	
	my $name = undef;
	my $description = undef;
	my $domain = undef;
	
	my $urn = $nodeEl->getAttribute( 'id' );
	my ( $domain, $host, $port ) = utils::urn::fromUrn( $urn );

	# determine the long lats for the port/node (dns, ip)
	my ( $lat, $long ) = gmaps::Location->getLatLong( $urn, $nodeEl, undef, undef );

	# TODO: deal with fact htat a node may have many ports
	foreach my $node ( $nodeEl->childNodes() ) 
	{

		if ( $node->localname() eq 'hostName' ) {
			$logger->debug( "Found hostName: $node " . $node->toString );
			$hostName = $node->to_literal();
		}
		elsif ( $node->localname() eq 'name' ) {
			$logger->debug( "Found name: $node " . $node->toString );
			$name = $node->to_literal();
		}
		elsif ( $node->localname() eq 'description' ) {
			$logger->debug( "Found description: $node " . $node->toString );
			$description = $node->to_literal();
		}

		# get ports
		elsif ( $node->localname() eq 'port' ) {
			
			$logger->debug( "Found a port: " . $node->toString );
			
			# get id
			my $urn = $node->getAttribute('id');
			
			# new port
			my $hash = {
				'hostName' => $hostName,
				'description' => $description,
				'domain' => $domain,
				'name' => $name,
				
				'longitude' => undef,
				'latitude' => undef,
				
				'urn' => $urn,
				'ipAddress' => undef,
				'ifName' => undef,
				'netmask' => undef,
				'ifDescription' => undef,
				
				# mas
				'mas' => [],
			};
				
			foreach my $item ( $node->childNodes() ) 
			{
				if ( $item->localname() eq 'ifName' ) {
					$logger->debug( "Found ifName: $item " . $item->toString );
					$hash->{'ifName'} = $item->to_literal();
				}			
				elsif ( $item->localname() eq 'ipAddress' ) {
					$logger->debug( "Found ipAddress: $item " . $item->toString );
					$hash->{'ipAddress'} = $item->to_literal();
				}	
				elsif ( $item->localname() eq 'netmask' ) {
					$logger->debug( "Found netmask: $item " . $item->toString );
					$hash->{'netmask'} = $item->to_literal();
				}
				elsif ( $item->localname() eq 'ifDescription' ) {
					$logger->debug( "Found ifDescription: $item " . $item->toString );
					$hash->{'ifDescription'} = $item->to_literal();
				}				
				
			}
			
			# set the location
			$hash->{'latitude'} = $lat;
			$hash->{'longitude'} = $long;
			
			# set the topology ma assc with this node
			
			push( @{$hash->{mas}}, { 'type' => 'topology', 'uri' => utils::xml::unescape( $self->uri() ) } ); 
			
			# addd to array
			push @out, $hash;
			
		}
		
	}	
#	use Data::Dumper;
#	$logger->debug( "Found ports: " . Dumper \@out);
	return \@out;
}






=head2 getLinks
 links
=cut
sub getLinks
{
	my $self = shift;
	my $urn = shift;
	
	


}



=head2 query
 UTLITY
=cut
sub query
{
	my $self = shift;
	my $text = shift;
	my $filter = shift;
	
	my $requestXML = 'Topology/query_xml.tt2';
	$filter = '//nmwg:message/nmwg:data/nmtopo:topology/*'
		if ! defined $filter;

	return $self->xquery( $requestXML, $text, $filter );
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

$Id: Topology.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, E<lt>ytl@slac.stanford.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Internet2

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
