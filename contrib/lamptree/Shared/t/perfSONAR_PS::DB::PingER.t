use Test::More 'no_plan';
use Log::Log4perl qw( :levels);
use POSIX;
use Time::HiRes qw ( &gettimeofday );

Log::Log4perl->easy_init($DEBUG);

# configs
my $tempDB = '/tmp/pingerMA.sqlite3';

# my $config = {
#	'DB_DRIVER' => 'SQLite',
#        'DB_TYPE' => 'SQLite',
#	'DB_NAME' => $tempDB,
#	'DB_USER' => 'pinger',
#	'DB_PASS' => 'pinger',		
#};

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";


# create a blank database using sqlite for now
`rm $tempDB; sqlite3 $tempDB < util/create_pingerMA_SQLite.sql`; 
ok( -e $tempDB, "create temporary database $tempDB" );

# use class
use_ok('perfSONAR_PS::DB::PingER');

my $basename = ${perfSONAR_PS::DB::PingER::basename}
    if (${perfSONAR_PS::DB::PingER::basename});

# instantiate
my $register = perfSONAR_PS::DB::PingER->register_db( 
    domain       => 'default', 
    type         => 'default', 
    driver       => 'SQLite', 
    database     => $tempDB,
    username     => 'pinger',
    password     => 'pinger' );
ok( $register, "register_db" );

my $db = perfSONAR_PS::DB::PingER->new_or_cached();
ok( $db != 0, "instantiation" );
print "DB object instantiated\n";

# open the database and load the dynamic modules for the rose::db::objects
ok( $db->openDB() == 0, "open database" );
print "DB opened\n";

###
# try using hte objects directly
###

### Hosts table

my $ip_name = 'localhost';
my $ip_number = '127.0.0.1';

my $obj = $basename . '::Host';
my $man = $basename . '::Host::Manager';

# create
my $src = $obj->new( 
				'ip_name' => $ip_name, 
				'ip_number' => $ip_number )->save;
ok( UNIVERSAL::can( $src, 'isa') && $src->isa( $basename . '::Host'), "create host" );

# read
my $hosts = $man->get_host( 
		query => [ 'ip_name' => { 'eq' => $ip_name },
					'ip_number' => { 'eq' => $ip_number }, ],
	);
ok( scalar @$hosts && UNIVERSAL::can( $hosts->[0], 'isa') && $hosts->[0]->isa( $basename . '::Host'), "read host" );

# update
# cant on this table

# delete
ok( $hosts->[0]->delete, "delete host");

### Metadata table

# create
$src = $obj->new( 
				'ip_name' => 'source',
				'ip_number' => '1.1.1.1' )->save;
my $dst = $obj->new( 
				'ip_name' => 'dest',
				'ip_number' => '2.2.2.2' )->save;
my $transport = 'ICMP';
my $packetSize = '1008';
my $count = '10';
my $packetInterval = '1';
my $ttl = '64';

$obj = $basename . '::MetaData';
$man = $basename . '::MetaData::Manager';

my $metadata = $obj->new(
					'ip_name_src' => $src->ip_name(),
					'ip_name_dst' => $dst->ip_name(),
					'transport'	  => $transport,
					'packetSize'  => $packetSize,
					'count'		  => $count,
					'packetInterval' => $packetInterval,
					'ttl'		  => $ttl )->save;
ok( UNIVERSAL::can( $metadata, 'isa') && $metadata->isa( $basename . '::MetaData'), "create metadata" );

# read
my $metadatas = $man->get_metaData( 
		query => [ 	'ip_name_src' => { 'eq' => $src->ip_name() },
					'ip_name_dst' => { 'eq' => $dst->ip_name() },
					'transport'	  => { 'eq' => $transport },
					'packetSize'  => { 'eq' => $packetSize },
					'count'		  => { 'eq' => $count },
					'packetInterval' => { 'eq' => $packetInterval },
					'ttl'		  => { 'eq' => $ttl },
				 ] );
ok( scalar @$metadatas && UNIVERSAL::can( $metadatas->[0], 'isa') && $metadatas->[0]->isa( $basename . '::MetaData'), "read metadata" );
				 
# update
foreach my $md ( @$metadatas ) {
	$md->count( 20 );
	$md->save;
	ok( $md->count() eq 20, "updated metadata");
}

# delete
ok( $metadatas->[0]->delete, 'delete metadata' );

### data table
$metadata = $obj->new(
					'ip_name_src' => $src->ip_name(),
					'ip_name_dst' => $dst->ip_name(),
					'transport'	  => $transport,
					'packetSize'  => $packetSize,
					'count'		  => $count,
					'packetInterval' => $packetInterval,
					'ttl'		  => $ttl )->save;

# create					
use Time::HiRes qw ( &gettimeofday );
my ( $nowTime, $nowMSec ) = &gettimeofday;

$obj = $basename . '::Data';
$man = $basename . '::Data::Manager';

my $data = $obj->new(
				'metaID'	=> $metadata->metaID,
				'timestamp' => $nowTime,
				'minRtt'	=> '0.023',
				'maxRtt'	=> '0.030',
				'meanRtt'	=> '0.026',
				'minIpd'	=> '0.0',
				'maxIpd'	=> '0.002',
				'meanIpd'	=> '0.006',
				'iqrIpd'	=> '0.0001',
				'lossPercent'	=> '0.0',
				'outOfOrder'	=> 'true',									
				'duplicates'	=> 'false',	
			)->save;
ok( UNIVERSAL::can( $data, 'isa') && $data->isa( $basename . '::Data'), "create data" );

# read
my $iter = $man->get_data_iterator;
while( $data = $iter->next ) {
	ok( UNIVERSAL::can( $data, 'isa' ) && $data->isa( $basename . '::Data'), 'read data' );	
}

# another read
my $datas = $man->get_data(
			'query' => [ 'timestamp' => { 'eq' => $nowTime } ],
		);
$datas->[0]->lossPercent( '100.0' ); 
$datas->[0]->save;
ok( $datas->[0]->lossPercent() eq '100.0' , 'update data');

# delete
ok( $datas->[0]->delete, 'delete data' );


###
# try the 'select or insert' (soi) wrapper classes
###
# host
my $host = $db->soi_host( 'somehost', '111.111.111.111');
ok( UNIVERSAL::can( $host, 'isa' ) && $host->isa( $basename . '::Host' ), 'wrapper create host' );
# create this one before hand to test that the wrapper is selecting an not creating
$obj = $basename . '::Host';
$obj->new( 
				'ip_name' => 'anotherhost',
				'ip_number' => '222.222.222.222' )->save;
my $host2 = $db->soi_host( 'anotherhost', '222.222.222.222');
ok( UNIVERSAL::can( $host2, 'isa' ) && $host2->isa( $basename . '::Host' ), 'wrapper select host' );

# metadata

#create
my $meta = $db->soi_metadata( $host, $host2, {
					'transport' => 'ICMP',
					'packetSize' => 1008,
					'packetInterval' => 1,
					'count'	=> 10,
					'ttl'	=> 64,
				});
ok( UNIVERSAL::can( $meta, 'isa' ) && $meta->isa( $basename . '::MetaData' ), 'wrapper insert metadata' );
#read - use same 
$meta = $db->soi_metadata( $host, $host2, {
					'transport' => 'ICMP',
					'packetSize' => 1008,
					'packetInterval' => 1,
					'count'	=> 10,
					'ttl'	=> 64,
				});
ok( UNIVERSAL::can( $meta, 'isa' ) && $meta->isa( $basename . '::MetaData' ), 'wrapper read metadata' );

# data

# load
my $time = 1196932989; # dec 2007
# be sure to enable creation of the table in the get_rose_objects_for_timestamp
# otherwise the table won't get created later
( $obj, $manager ) = $db->get_rose_objects_for_timestamp( $time, undef, 1 );
print "OBJ: @$obj, MAN: @$manager\n";
ok( $obj->[0] eq $basename . '::Data200712' && $manager->[0] eq $basename . '::Data200712::Manager', 'dynamic rose object load using object for timestamp with table create');

my $time2 = 1210260189; # may 2008
( $obj, $manager ) = &perfSONAR_PS::DB::PingER::get_rose_objects_for_timestamp( $time2, undef, 1 );
#print "OBJ: @$obj, MAN: @$manager\n";
ok( $obj->[0] eq $basename . '::Data200805' && $manager->[0] eq $basename . '::Data200805::Manager', 'dynamic rose object load using static for timestamp with table create');

my $time_x = 1196932989;
my $time_y = 1210260189;

# get list of months
my %unique = ();
for ( my $t = $time_x; $t <= $time_y; $t += 86400 ) {
	my $month = strftime( "%Y%m", gmtime( $t ) );
	$unique{$month}++;
}
my @dates = sort { $a <=> $b } keys %unique;

( $obj, $manager ) = &perfSONAR_PS::DB::PingER::get_rose_objects_for_timestamp( $time_x, $time_y, 1 );
for ( my $i=0; $i<scalar @$obj; $i++ ) {
	my $date = shift @dates;
	#print "Got " . $obj->[$i] . " : " . $manager->[$i] . " --> DATE: $date\n";
	ok( $obj->[$i] eq $basename . '::Data' . $date && $manager->[$i] eq $basename . '::Data' . $date . '::Manager', 'dynamic rose object load for table ' . $date . ' using static for timerange');
}

# try loading again
my @dates = sort { $a <=> $b } keys %unique;

( $obj, $manager ) = &perfSONAR_PS::DB::PingER::get_rose_objects_for_timestamp( $time_x, $time_y, 1 );
for ( my $i=0; $i<scalar @$obj; $i++ ) {
        my $date = shift @dates;
	ok( $obj->[$i] eq $basename . '::Data' . $date && $manager->[$i] eq $basename . '::Data' . $date . '::Manager', 'reload of rose object load for table ' . $date . ' using static for timerange');
}


# insert some data

my $res = $db->insert_data( $meta, {
				'timestamp' => $time,
				'minRtt'	=> '0.023',
				'maxRtt'	=> '0.030',
				'meanRtt'	=> '0.026',
				'minIpd'	=> '0.0',
				'maxIpd'	=> '0.002',
				'meanIpd'	=> '0.006',
				'iqrIpd'	=> '0.0001',
				'lossPercent'	=> '0.0',
				'outOfOrder'	=> 'true',									
				'duplicates'	=> 'false',	
				'rtts'		=> [ 3,4,5,6,7,8 ],
				'seqNums'	=> [ 0,3,4,5,6,7 ],
			});
print $db->error() if $res < 0;
ok( $res eq 0, 'insert data into existing table' );

# insert into undefined table
$res = $db->insert_data( $meta, {
				'timestamp' => 1251415389, # aug 2009
				'minRtt'	=> '0.053',
				'maxRtt'	=> '0.050',
				'meanRtt'	=> '0.016',
				'minIpd'	=> '0.0',
				'maxIpd'	=> '0.032',
				'meanIpd'	=> '0.06',
				'iqrIpd'	=> '0.04',
				'lossPercent'	=> '0.0',
				'outOfOrder'	=> 'true',									
				'duplicates'	=> 'false',	
				'rtts'		=> [ 0.0,0.04,0.05,0.04,0.03 ],
				'seqNums'	=> [ 0,4,5,6,7 ],
			});
print $db->error() if $res < 0;
ok( $res eq 0, 'insert data into non-existing table' );

# remove temp file
#`rm $tempDB`;

print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n";
