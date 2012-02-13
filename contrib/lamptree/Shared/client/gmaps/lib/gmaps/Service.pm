use utils::transport;
use Template;
use Log::Log4perl qw(get_logger);
use perfSONAR_PS::Transport;
use perfSONAR_PS::ParameterValidation;

use Params::Validate qw(:all);



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


package gmaps::Service;

use fields qw( URI HOST PORT ENDPOINT TEMPLATE FIELDS );

our $logger = Log::Log4perl::get_logger( 'gmaps::Service' );

use strict;


=head2 new( $uri )
create new instance from the URL uri
=cut
sub new 
{
    my $self = shift;
    my $uri = shift;	# service uri
    
    # base from a single url
    my ( $host, $port, $endpoint ) = perfSONAR_PS::Transport::splitURI( $uri );
    
    $logger->debug( "Creating service instance for '$uri' - host: $host, port: $port, endpoint: $endpoint");
    
    # see if we have a ref to the a templating class
    my $templateObj = shift;
    if ( $templateObj && UNIVERSAL::can( $templateObj, 'isa' ) ) {
    	
    	if ( $templateObj->isa( "CGI::Application") ) {
	    	$templateObj->tt_config( TEMPLATE_OPTIONS => 
                        	{ INCLUDE_PATH => ${gmaps::paths::templatePath} } );
    	} else {
    		# unset it
    		$templateObj = undef
    	}
    }
    
    # use the normal templating engine
    if ( ! defined $templateObj ) {
	    $templateObj = 
	    		Template->new( { 'INCLUDE_PATH' => ${gmaps::paths::templatePath} } )
	     	|| $logger->logdie( "Could not instanitate Template Toolkit" );	    
    }
    
	unless (ref $self) {
    	$self = fields::new($self);        
	}
	$self->{'URI'}  = $uri;
	$self->{'HOST'} = $host;
	$self->{'PORT'} = $port;
	$self->{'ENDPOINT'} = $endpoint;
	
	# list of fields for the data
	@{$self->{'FIELDS'}} = ();
	
	# initaite a template
	$self->{'TEMPLATE'} = $templateObj,
		
    return $self;
}



#######################################################################
# template and communication handling
#######################################################################

=head2 processTemplate( $xml, $vars )
process the template xml file with the variables from the hash $vars
=cut
sub processTemplate
{
	my $self = shift;
	my $xml = shift;
	my $vars = shift;
	
	my $out = undef;
	use Data::Dumper;
	$logger->debug( "STRING: " . Dumper $vars );
	
	if( $self->{TEMPLATE}->isa( 'Template' ) ) {

		$self->{TEMPLATE}->process( "$xml", $vars, \$out )
			or $logger->logdie( "Could not process template '$xml': " . $self->{TEMPLATE}->error() );
		

	} elsif ( $self->{TEMPLATE}->isa( 'gmaps::web' ) ) {
				
		$out = ${$self->{TEMPLATE}->tt_process( $xml, $vars )}
			or $logger->logdie( "Could not process template '$xml': " . $self->{TEMPLATE}->error() );

	}
	
	#$logger->fatal( "OUT: $out" );
	return $out;
}


=head2 processAndQuery( $requestXML, $vars, $filter )
process the template file $requestXML and replace with contents of the hash
$vars. After apply the xpath $filter. 
=cut
sub processAndQuery
{
	my $self = shift;
	
	my $requestXML = shift;
	my $vars = shift;
	my $filter = shift;
	
	# process template
	my $out = $self->processTemplate( $requestXML, $vars  );
	return ( &utils::transport::get( 
		$self->host(), $self->port(), $self->endpoint(), 
		$out,
		$filter ) );
}



=head2 xquery( $requestXML, $text, $filter )
Send the template file $reqestXML and replace the main content with $text.
Then on receipt filter with xpath statement $filter
=cut
sub xquery
{
	my $self = shift;
	
	my $requestXML = shift;
	my $text = shift;
	my $filter = shift;
	
	# overload xquery
	my $vars = {
		'XQUERY' => $text,
	};
	
	# process template
	my $out = $self->processTemplate( $requestXML, $vars  );
	
	return ( &utils::transport::get( 
		$self->host(), $self->port(), $self->endpoint(), 
		$out,
		$filter, 1 ) );	# the '1' is to indicate that we should convert any &lt; etc into real chars

}



#######################################################################
# accessor
#######################################################################

=head2 uri
accessor/mutator for the uri
=cut
sub uri
{
	my $self = shift;
	if ( @_ ) {
		$self->{URI} = shift;
	} 
	return $self->{URI};
}

=head2 host
accessor/mutator for the host
=cut
sub host
{
	my $self = shift;
	if ( @_ ) {
		$self->{HOST} = shift;
	} 
	return $self->{HOST};
}

=head2 port
accessor/mutator for the port
=cut
sub port
{
	my $self = shift;
	if ( @_ ) {
		$self->{PORT} = shift;
	} 
	return $self->{PORT};
}

=head2 endpoint
accessor/mutator for the endpoint
=cut
sub endpoint
{
	my $self = shift;
	if ( @_ ) {
		$self->{ENDPOINT} = shift;
	} 
	return $self->{ENDPOINT};
}


=head2 fields
accessor/mutator for the fields for the data tables
=cut
sub fields
{
	my $self = shift;
	if ( @_ ) {
		$self->{FIELDS} = shift;
	} 
	return \@{$self->{FIELDS}};
}

#######################################################################
# INTERFACE
#######################################################################


=head2 isAlive
sends a message out to see if service is alive
# TODO: use namespace classes etc to make sure it's compatiable across services
=cut
sub isAlive
{
	my $self = shift;
	my $eventType = shift; # eventype for the hello
	
	my $requestXML = 'Service/echo_xml.tt2';
	
	my $vars = {
		'EVENTTYPE' => $eventType,
	};
	
	my @nodelist = $self->processAndQuery( $requestXML, $vars, '//nmwg:message/nmwg:metadata/nmwg:eventType' );
	
	foreach my $node ( @nodelist ) {
		my $value = $node->to_literal();
		if ( $value eq 'success.echo' ) {
			return 1;
		}
		
	}
	return 0;
}

=head2 discover( )
retrieves a list of the urn's for the service
=cut
sub discover
{
	my $self = shift;
	my $params = shift;
	
	my $array = $self->getMetaData( $params );
	return $array;	
}

=head2 getData

retrieves the data related to the metadata supplied

=cut
sub getData
{
	my ( $self, @args ) = @_;
	my $params = Params::Validate::validate( @args, { urn => 0, key => 0, eventType => 0, startTime => 0, endTime => 0, resolution => 300, consolidationFunction => undef } );
		
	$logger->logdie( "fetch must be inherieted");
}

=head2 getMetaData

returns a hash of metadata elements contained at service

=cut
sub getMetaData
{
	my ( $self, @args ) = @_;
	my $params = validateParams( @args, { urn => 0, key => 0, startTime => 0, endTime => 0, resolution => 300, consolidationFunction => undef } );
		
	$logger->logdie( "fetch must be inherieted");
}

#######################################################################
# utility functions
#######################################################################




1;


=head1 SEE ALSO

L<perfSONAR_PS::Transport>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS 
  
Questions and comments can be directed to the author, or the mailing list. 

=head1 VERSION

$Id: Service.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, E<lt>ytl@slac.stanford.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Internet2

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
