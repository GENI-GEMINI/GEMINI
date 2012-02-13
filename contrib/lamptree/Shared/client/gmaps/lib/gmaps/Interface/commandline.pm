use Template;
use Log::Log4perl qw( get_logger );

=head1 NAME

gmaps::Interface::commandline - An commandline interface to interact with 
perfsonar services  

=head1 DESCRIPTION

This module provides functions to query a remote perfsonar measurement point
or measurement archive. Inherited classes should overload the appropiate
methods to provide customised access to the service in question.

=head1 SYNOPSIS

    use gmaps::Interface::commandline;
    
    # create a new service
    my $service = gmaps::Interface::commandline->new();
  
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
package gmaps::commandline;
use base 'gmaps::Interface';

# logging
our $logger = Log::Log4perl::get_logger( 'gmaps::web');

use strict;

=head2 new( )
create a new instance of the command line interface for perfsonar clients
=cut
sub new
{
	my $class = shift;
	my $self = fields::new($class);
	$self->SUPER::new( @_ );
	my $config = {
		'INCLUDE_PATH' => $gmaps::paths::templatePath,
	};
	$self->{'TEMPLATE'} = Template->new( $config );
	
	return $self;
}

#######################################################################
# TEMPLATES
#######################################################################

=head2

=cut
sub processTemplate
{
	my $self = shift;
	my $xml = shift;
	my $vars = shift;

	$logger->debug( "Processing template '$xml' using $vars");

	$self->template()->process( $xml, $vars )
		or $logger->logdie( "Could not process template '$xml': " . $self->template()->error() );
}


#######################################################################
# INTERFACE
#######################################################################

=head2 discover( $uri, $using )
retrieves a list of urn's that are being monitored by the service
=cut
sub discover
{
	my $self = shift;
	return $self->SUPER::discover( @_ );	
}

=head2 fetch( urn )
retrieve a table of information from the urn
=cut
sub fetch
{
	my $self = shift;
	return $self->SUPER::fetch( @_ );
}




1;