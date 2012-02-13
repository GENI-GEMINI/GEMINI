
use perfSONAR_PS::DB::SQL;

package gmaps::InterfaceCache;


our $logger = Log::Log4perl::get_logger( 'gmaps::InterfaceCache' );

use strict;

# constructor
sub new
{
	my $classpath = shift;
	my $dbfile = shift;
	my $self = {};

    bless $self, $classpath;

    # set up db
	$self->{DB} = perfSONAR_PS::DB::SQL->new();

	@{$self->{DBSCHEMA}} = ( 'uri', 'response' );
	$self->{DBTABLE} = 'data';

	$self->{DB}->setName( name => 'DBI:SQLite:dbname=' . $dbfile );
	$self->{DB}->setSchema( schema => \@{$self->{DBSCHEMA}} );

	my $result = $self->{DB}->openDB();
	if ( $result == 0 ) {

		# create the table and db if not exist
		my $table = $self->{DB}->query( query => 'SELECT name FROM SQLite_Master WHERE name=\'' . $self->{DBTABLE} . "'"  );

		#$logger->debug( "TABLE EXISTS? " . scalar @$table );
		if ( scalar @$table == 0 ) {
			my $res = $self->{DB}->query( query => "CREATE TABLE " . $self->table() . " ( uri TEXT PRIMARY KEY, response BLOB, last_updated DATE ); " );
			$logger->debug( "Creating table in database '$dbfile'" );
		}
		return $self;
	} else {
	    $logger->error( "Could not open db: '$result'" );
		return undef;
	}
}



sub db
{
	my $self = shift;
	return $self->{DB};
}

sub table
{
	my $self = shift;
	return $self->{DBTABLE};
}




sub DESTROY
{
	my $self = shift;
	return $self->db()->closeDB();

}


sub getResponse
{
	my $self = shift;
	my $uri = shift;

    if ($self->db()->openDB == -1) {
      $logger->fatal( "Error opening database" );
    }

    my $this_time = time() - ${gmaps::paths::discoverExpiry};
    my $sql = "SELECT response FROM " . $self->table() . "  WHERE uri='$uri' AND last_updated > " . $this_time ;
    $logger->debug( "SQL: $sql");
	my $result = $self->db()->query( query => $sql );
	
    while ( my $row = shift @{$result} ) {
        return $row->[0];
    }

    return undef;

}


sub setResponse
{
	my $self = shift;
	my $uri = shift;
	my $response = shift; # reference to string

	my $insert = {
		'uri'	=> $uri,
		'response' => $response,
		'last_updated' => time(), # epcoh time now
	};

	# count
	my $count = $self->db()->count( query => "SELECT * from " . $self->table() . " WHERE uri='" . $insert->{uri} . "'" );
	$logger->debug( "Count " . $count );

	# insert
	if ( $count == 0 ) {
		my $status = $self->db()->insert( table => $self->table(), argvalues => $insert );
		
        $logger->debug( "Inserting cache entry for '$uri'");		
		if ( $status == -1 ) {
			$logger->warn( "Error inserting uri '" . $insert->{uri} . "'" );
			return undef;
		}
		return 1;

	} else {

        $logger->info( "Updating cache entry for '$uri'");
	    # update
		my $uri = $insert->{uri};
		delete $insert->{uri};
		while ( my ( $k,$v ) = each %$insert ) {
			$insert->{$k} = $v;	
		}
		if ( $self->db()->update( table => $self->table(), wherevalues =>  { 'uri' => "'" . $uri . "'" }, updatevalues => $insert )  == -1 ) {
			$logger->debug( "Error updating uri '" . $uri . "'" );
			return undef;
		}
		return 1;
	}

}


1;