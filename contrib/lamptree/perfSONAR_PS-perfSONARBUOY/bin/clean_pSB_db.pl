#!/usr/bin/perl -w

use strict;

our $VERSION = 3.1;

=head1 NAME

clean_pSB_db.pl - Dumps and removes data from the pSB database once it reaches a certain age.

=head1 DESCRIPTION

This script runs mysqldump to backup database tables of a certain age and
removes the tables. It accepts a number of options such as using owmesh.conf to get 
the database info or it may be provided directly via the command-line.

=head1 SYNOPSIS

clean_pSB_db.pl [I<options>]
clean_pSB_db.pl [B<--dbuser> username][B<--dbpassword> password][B<--dbhost> hostname][B<--dbname> database] [I<options>]
clean_pSB_db.pl [B<--owmesh-dir> owmeshdir][B<--dbtype> owamp|bwctl] [I<options>]

=over

=item B<-h,--help>

displays this message.

=item B<--maxdays> days

maximum age (in days) of data to keep in database. Only valid for owamp databases. Defaults to 90.

=item B<--maxmonths> days

maximum number of months to keep in database. Must be used for bwctl databases. Defaults to 3.

=item B<--dbtype> owamp|bwctl

indicates type of data in database. Valid value are 'owamp' or 'bwctl'. Defaults to 'owamp'.

=item B<--dbname> name

name of database to access. Defaults to 'owamp'.

=item B<--dbuser> user

name of database user. Defaults to root.

=item B<--dbpassword> password

password to access database. Defaults to empty string.

=item B<--dbhost> host

database host to access. Defaults to localhost.

=item B<--owmesh-dir> dir

location of owmesh.conf file with database username and password.

overrides dbuser, dbpassword, dbhost and dbname.

=item B<--dumpdir> dir

path to store expired table backups. Defaults to current directory.

=item B<--save-dumps>

indicates that databse dumps of expired tables should be kept in dumpdir. Active by default.

=item B<--no-save-dumps>

indicates that expired database data should be deleted and dumps not saved.

=item B<--compress-dumps>

indicates that databse dumps of expired tables should be compressed. Active by default.

=item B<--no-compress-dumps>

indicates that expired database data should remain uncompressed.

=item B<--drop-tables>

drop database tables that exceed the maximum age. Active by default.

=item B<--no-drop-tables>

do not drop database tables that exceed the maximum age.

=item B<--table-suffixes table[,table...]>

suffixes of table names to be removed/backed-up.

=item B<--tar-cmd> cmd

path to tar command.

=item B<--mysqldump-cmd> cmd

path to mysqldump command

=item B<--mysqldump-opts> opts

options to pass to the mysqldump command

=item B<--verbose>

increase amount of output from program

=back

=cut

use FindBin;
use lib "$FindBin::Bin/../lib";

use DBI;
use Getopt::Long;
use Time::Local;
use perfSONAR_PS::Config::OWP::Conf;
use POSIX;

#var definitions
my @DEFAULT_TABLES = ( 'DATA', 'DELAY', 'NODES', 'TESTSPEC', 'TTL' );
my $DEFAULT_DB_HOST = 'localhost';
my %OW_TYPES = ( 'owamp' => 'OWP', 'bwctl' => 'BW');
my %valid_tables = ();

#Set option default
my $maxdays = 90;
my $maxmonths = 0;
my $dbtype = "owamp";
my $dbname = "owamp";
my $dbuser = "root";
my $dbpassword = "";
my $dbhost= $DEFAULT_DB_HOST;
my $help = 0;
my $dumpdir = "./";
my $save_dumps = 1;
my $compress_dumps = 1;
my $drop_tables = 1;
my $tar_cmd = "tar";
my $mysqldump_cmd = "mysqldump";
my $mysqldump_opts = "";
my $owmesh_dir = "";
my @table_suffixes = ();
my $verbose = 0;

#Retrieve options
my $result = GetOptions (
    "h|help"   => \$help,
    "maxdays=i" =>\$maxdays,
    "maxmonths=i" =>\$maxmonths,
    "owmesh-dir=s" => \$owmesh_dir,
    "dbtype=s" => \$dbtype,
    "dbname=s" => \$dbname,
    "dbuser=s" => \$dbuser,
    "dbpassword=s" => \$dbpassword,
    "dbhost=s" => \$dbhost,
    "dumpdir=s" => \$dumpdir,
    "save-dumps!"   => \$save_dumps,
    "compress-dumps!"   => \$compress_dumps,
    "drop-tables!"   => \$drop_tables,
    "tar-cmd=s" => \$tar_cmd,
    "mysqldump-cmd=s" => \$mysqldump_cmd,
    "mysqldump-opts=s" => \$mysqldump_opts,
    "table-suffixes=s" => \@table_suffixes,
    "v|verbose" => \$verbose
);

# Error handling for options
if( !$result ){
    &usage();
    exit 1;
}

#set max months
if($maxmonths > 0){
    $maxdays = $maxmonths * 31;
}

if( $dbtype ne "owamp" && $dbtype ne "bwctl" ){
    print STDERR "Option 'dbtype' must be 'owamp' or 'bwctl'\n";
    &usage();
    exit 1;
}elsif( $maxdays < 1  ){
    print STDERR "Option 'maxdays' must be at least 1\n";
    &usage();
    exit 1;
}elsif($dbtype eq "bwctl" && $maxmonths <= 1 && $maxdays < 31){
    print STDERR "Option 'maxmonths' must be specified for bwctl databases\n";
    &usage();
    exit 1;
}

# print help if help option given
if( $help ){
    &usage();
    exit 0;
}

# open owmesh.conf
if($owmesh_dir){
    my $owmesh_type = $OW_TYPES{$dbtype};
    my %defaults = (
        DBHOST  => $DEFAULT_DB_HOST,
        CONFDIR => $owmesh_dir
    );
    my $conf = new perfSONAR_PS::Config::OWP::Conf( %defaults );
    $dbuser = $conf->must_get_val( ATTR => 'CentralDBUser', TYPE => $owmesh_type );
    $dbpassword = $conf->must_get_val( ATTR => 'CentralDBPass', TYPE => $owmesh_type );
    $dbhost = $conf->get_val( ATTR => 'CentralDBHost', TYPE => $owmesh_type ) || $DEFAULT_DB_HOST;
    $dbname = $conf->must_get_val( ATTR => 'CentralDBName', TYPE => $owmesh_type );
}

# Set table suffixes
if(@table_suffixes < 1){
    @table_suffixes = @DEFAULT_TABLES;
}
foreach my $suffix (@table_suffixes) {
    $valid_tables{$suffix} = 1;
}

#connect to database
my $dbh = DBI->connect("DBI:mysql:$dbname;host=$dbhost", $dbuser, $dbpassword) or die $DBI::errstr;

#Determine tables to clean
my $exp_time = time - 86400*$maxdays;
my $show_sth = $dbh->prepare("SHOW TABLES") or die $dbh->errstr;
$show_sth->execute() or die $show_sth->errstr;
my $table_count = 0;
while(my $show_row = $show_sth->fetchrow_arrayref){
    my @table_name_parts = split /_/, $show_row->[0];
    next if(!&validate_table_name(\@table_name_parts, \%valid_tables, $dbtype));
    my @dateParts = ();
    if( $dbtype eq 'owamp' ){
        push @dateParts, substr($table_name_parts[0], 6, 2);
    }else{
        push @dateParts, 1;
    }
    push @dateParts, substr($table_name_parts[0], 4, 2);
    push @dateParts, substr($table_name_parts[0], 0, 4);
    my $table_time = timelocal(59, 59, 23, $dateParts[0] , $dateParts[1] - 1, $dateParts[2] - 1900);
    next if($table_time > $exp_time);
    if($save_dumps){
        &dump_table($dbname, $dbuser, $dbpassword, $dbhost, $show_row->[0], $compress_dumps);
    }
    if($drop_tables){
        &drop_table($dbh, $show_row->[0], \@dateParts, $dbtype);
    }
    print "Cleaned table $show_row->[0].\n";
    print "\n" if $verbose;
    $table_count++;
}
$dbh->disconnect();
print "Success (cleaned $table_count tables)\n";

#
# Run mysqldump and optionally compress output
#
sub dump_table() {
     my($dbname, $dbuser, $dbpassword, $dbhost, $table, $compress) = @_;
     if($mysqldump_opts){
        $mysqldump_cmd .= " $mysqldump_opts";
     }
     print "Dumping $table...\n" if $verbose;
     system ( "$mysqldump_cmd -h $dbhost -u $dbuser --password=$dbpassword $dbname $table > $dumpdir/$table.sql" );
     if($? != 0){
        die("Unable to run mysqldump on $table" . $!);
     }
     print "Dump complete.\n" if $verbose;
     
     if($compress){
        print "Compressing $table.sql...\n" if $verbose;
        system ("$tar_cmd -C $dumpdir -czf $dumpdir/$table.sql.tgz $table.sql");
        if($? != 0){
           die("Unable to compress mysqldump of $table" . $!);
        }
        print "Compression complete.\n" if $verbose;
        
        print "Removing uncompressed file...\n" if $verbose;
        unlink "$dumpdir/$table.sql";
        print "Removal complete.\n" if $verbose;
     }
}

#
# drop given table
#
sub drop_table() {
    my($dbh, $table, $dateParts, $dbtype) = @_;
    print "Dropping table $table...\n" if $verbose;
    my $drop_sth = $dbh->prepare("DROP TABLE $table") or die $dbh->errstr;
    $drop_sth->execute() or die $drop_sth->errstr;
    my $date_sql = "DELETE FROM DATES WHERE ";
    $date_sql .= "day='" . $dateParts->[0] . "' AND " if($dbtype eq 'owamp');
    $date_sql .= "month='" . $dateParts->[1] . "' AND year='" . $dateParts->[2] . "'";
    my $deldate_sth = $dbh->prepare($date_sql) or die $dbh->errstr;
    $deldate_sth->execute() or die $deldate_sth->errstr;
    print "Table dropped\n" if $verbose;
}

#
# check whether anything should be done to given table
#
sub validate_table_name(){
    my ($table_name_parts, $valid_tables, $dbtype) = @_;
    
    if(@{$table_name_parts} < 2){
        return 0;
    }
    
    if($table_name_parts->[0] !~ /\d+/){
        return 0;
    }
    
    if($dbtype eq 'bwctl' && length($table_name_parts->[0]) != 6){
        return 0;
    }elsif($dbtype eq 'owamp' && length($table_name_parts->[0]) != 8){
        return 0;
    }
    
    if(!$valid_tables{$table_name_parts->[1]}){
        return 0;
    }
    
    return 1;
}

#
# print command usage
#
sub usage() {
    print "clean_pSB_db.pl <options>\n";
    print "    -h,--help                            displays this message.\n";
    print "    --maxdays days                       maximum age (in days) of data to keep in database. Only valid for owamp databases. Defaults to 90.\n";
    print "    --maxmonths months                   maximum number of months to keep in database. Must be used for bwctl databases. Defaults to 3.\n";
    print "    --dbtype type                        Indicates type of data in database. Valid value are 'owamp' or 'bwctl'. Defaults to 'owamp'.\n";
    print "    --dbname name                        name of database to access. Defaults to 'owamp'.\n";
    print "    --dbuser user                        name of database user. Defaults to root.\n";
    print "    --dbpassword password                password to access database. Defaults to empty string.\n";
    print "    --dbhost host                        database host to access. Defaults to localhost.\n";
    print "    --owmesh-dir dir                     location of owmesh.conf file with database username and password.\n";
    print "                                         overrides dbuser, dbpassword, dbhost and dbname.\n";
    print "    --dumpdir dir                        path to store expired table backups. Defaults to current directory.\n";
    print "    --save-dumps                         indicates that databse dumps of expired tables should be kept in dumpdir. Active by default.\n";
    print "    --no-save-dumps                      indicates that expired database data should be deleted and dumps not saved.\n";
    print "    --compress-dumps                     indicates that databse dumps of expired tables should be compressed. Active by default.\n";
    print "    --drop-tables                        drop database tables that exceed the maximum age. Active by default.";
    print "    --no-drop-tables                     do not drop database tables that exceed the maximum age.";
    print "    --no-compress-dumps                  indicates that expired database data should remain uncompressed.\n";
    print "    --table-suffixes table[,table...]    suffixes of table names to be removed/backed-up.\n";
    print "    --tar-cmd cmd                        path to tar command.\n";
    print "    --mysqldump-cmd cmd                  path to mysqldump command\n";
    print "    --mysqldump-opts opts                options to pass to the mysqldump command\n";
    print "    --verbose                            increase amount of output from program\n";
}

__END__

=head1 SEE ALSO
L<DBI>, L<Getopt::Long>, L<Time::Local>, L<POSIX>,
L<perfSONAR_PS::Config::OWP::Conf>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: perfSONARBUOY.pm 4030 2010-05-14 15:06:51Z alake $

=head1 AUTHOR

Andy Lake, andy@es.net

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2010, Internet2

All rights reserved.

=cut