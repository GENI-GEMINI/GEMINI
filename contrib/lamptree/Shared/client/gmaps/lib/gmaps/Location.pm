#######################################################################
# class to query idetermine long lat location of a node
#######################################################################

use utils::urn;

use gmaps::Location::NMWG;
use gmaps::Location::GeoIPTools;
use gmaps::Location::DNSLoc;
use gmaps::Location::SQLite;

package gmaps::Location;

use Log::Log4perl qw( get_logger );
our $logger = Log::Log4perl->get_logger( "gmaps::Location" );


###
# create new instance from url; if 3 arguments, assumes that its, host, port, endpoint
###
sub new 
{
    my $className = shift;
    
    # get a unique id for the semaphore reference
    my $self= {
    };
    
    bless $self, $className;
    return $self;
}

###
# dispatch the fetching of location
# prefer in order, xml, dns loc, geoiptools
###
sub getLatLong
{
	my $self = shift;

	my $dns = shift;
	my $ip = shift;

	my $nodeEl = shift; # libxml
	my $urn = shift;

	my @classes = ();

	my $lat = undef;
	my $long = undef;

	$logger->debug( "dns: $dns, ip: $ip, node: $nodeEl, urn: $urn");

	# chekc to make sure we cant to do local caching
	my $useDB = 1;
	$useDB = 0
		if ( ! defined ${gmaps::paths::locationCache} 
			or ${gmaps::paths::locationCache} eq '' );

    # store only the ip address in the database
    # determine the ip address
    if ( defined $ip && utils::addresses::isIpAddress( $ip ) ) {
      #good   
    } else {
        if ( ! defined $dns ) {
            # work out from urn
            my ( $domain, $host, $port ) = utils::urn::fromUrn( $urn );
    		if ( utils::addresses::isIpAddress( $port ) ) {
    			$ip = $port;
    		}
        }

        ( $ip, $dns ) = utils::addresses::getDNS( $dns )
            if $dns;

    }

    my $db = undef;       
	if ( $useDB )
	{
		# cache so that we don't have to worry about dynamic loksup
		$db = gmaps::Location::SQLite->new( ${gmaps::paths::locationCache} );

		# try the cache first
		( $lat, $long ) = $db->getLatLong( $dns, $ip );

        if ( defined $lat && defined $long ) {
		    $logger->debug( "resolved node '$ip' to ( $lat, $long )");
		    return ( $lat, $long ) 
		}    
		        
	}

	# if doesn't exist, find another way...

	# determine what fucntions to call to determine lat long
	# determine if we have a valid libxml doc
	if ( $nodeEl ) {
	        push @classes, 'gmaps::Location::NMWG';
	}
	# dns loc?
	push( @classes, 'gmaps::Location::DNSLoc' )
		if ${gmaps::paths::locationDoDNSLoc};
       
	# geoiptools as last resort
	push( @classes, 'gmaps::Location::GeoIPTools' )
		if ${gmaps::paths::locationDoDNSLoc};

	foreach my $class ( @classes ) {
		( $lat, $long ) = $class->getLatLong( $dns, $ip, $nodeEl, $urn );
		$logger->debug( "Querying $class for location of dns $dns, ip $ip; returned ($lat,$long)");
		last if defined $lat && defined $long;
	}

	 if ( ! defined $lat && ! defined $long  ) {
		$lat = 'NULL';
		$long = 'NULL';
		$logger->warn( "Could not determine location for dns '$dns' and ip '$ip'" )
		   if scalar @classes > 1;
	 } else {
	     # store into cache
    	 $db->setLatLong( $ip, $lat, $long )
    	         if ( $useDB );
    }

	return ( $lat, $long );
}



1;
