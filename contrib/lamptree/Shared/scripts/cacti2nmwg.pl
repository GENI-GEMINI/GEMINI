#!/usr/bin/perl -w

use strict;
use warnings;
use DBI;
use Getopt::Long;
use Socket;

my @VERSIONS = ("0.8.6j");

my $DEBUG = '';
my $HELP = '';
my $FORCE = '';
my $USER = 'cactiuser';
my $PASS = '';
my $NAME = 'cacti';
my $HOST = 'localhost';
my $PORT = '3306';
my %opts = ();
GetOptions('verbose' => \$DEBUG,
           'help'    => \$HELP,
           'force'   => \$FORCE,
           'user=s'  => \$opts{USER}, 
           'pass=s'  => \$opts{PASS}, 
           'name=s'  => \$opts{NAME},
           'port=s'  => \$opts{PORT},
           'host=s'  => \$opts{HOST});
			 
if($HELP) {
  print "$0: Connects to a cacti database and extracts information to create the XML for a perfSONAR-PS SNMP MA store file.\n";
  print "$0 [--verbose --help --force --user=db_user_name --pass=db_user_pass --name=db_name --host=db_host_name --port=db_host_port]\n";
  exit(1);
}

$USER = $opts{USER} if defined $opts{USER};
$PASS = $opts{PASS} if defined $opts{PASS};
$NAME = $opts{NAME} if defined $opts{NAME};
$HOST = $opts{HOST} if defined $opts{HOST};
$PORT = $opts{PORT} if defined $opts{PORT};

my $connectString = "DBI:mysql:database=".$NAME.";host=".$HOST.";port=".$PORT;

my %attr = (
  RaiseError => 1,
);     
my $dbh = DBI->connect(
  $connectString,
  $USER,
  $PASS, 
  \%attr
) or print "Database \"".$connectString."\" unavailable with user \"".$USER."\" and password \"".$PASS."\".\n";

checkVersion($dbh);

printHeader();
                 
my $result = query($dbh, "select id, description, hostname from host order by id");

for(my $a = 0; $a <= $#{$result}; $a++) {
  my %md = (
    id => "",
    description => "",
    hostName => "",
    ifIndex => "",
    ifDescr => "",
    ifName => "",
    ifSpeed => "",
    ifIP => ""
  );

  $md{"id"} = $result->[$a][0];
  $md{"description"} = $result->[$a][1];
  $md{"hostName"} = $result->[$a][2];

  my $packed_ip = gethostbyname($md{"hostName"});
  if (defined $packed_ip) {
    $md{"ipAddress"} = inet_ntoa($packed_ip);
  }
  else {
    $md{"ipAddress"} = "";
  }
  
  if(!($md{"hostName"} =~ m/localhost/i) and $md{"hostName"} ne "127.0.0.1") {                
    my $result2 = query($dbh, "select id, snmp_index from data_local where host_id = \"".$result->[$a][0]."\" order by id");

    for(my $b = 0; $b <= $#{$result2}; $b++) {
      if($result2->[$b][1] and $result2->[$b][1] =~ m/^\d+$/) {
        my @list = ("ifIndex", "ifDescr", "ifName", "ifSpeed", "ifIP");
        my %lookup = ();
        foreach my $l (@list) {
          my $result4 = query($dbh, "select field_value from host_snmp_cache where host_id = \"".$result->[$a][0]."\" and field_name = \"".$l."\" and snmp_index = \"".$result2->[$b][1]."\"");
          $md{$l} = $result4->[0][0];
        }
        if(!$md{"ifIndex"}) {
          $md{"ifIndex"} = $result2->[$b][1];
        }

        my $result3 = query($dbh, "select rrd_name, rrd_path from poller_item where host_id = \"".$result->[$a][0]."\" and local_data_id = \"".$result2->[$b][0]."\"");  
        for(my $c = 0; $c <= $#{$result3}; $c++) {
          if($result3->[$c][0] =~ m/traffic/) {
            my %d = (
              id => "",
              ds => "",
              file => ""
            );      
            $d{"id"} = $result2->[$b][0];
            $d{"ds"} = $result3->[$c][0];
            $d{"file"} = $result3->[$c][1];

            if($result3->[$c][0] =~ m/in/) {
              $d{"id"} = $d{"id"} . "_in";
              $md{"ifDir"} = "in";
            }
            elsif($result3->[$c][0] =~ m/out/) {
              $d{"id"} = $d{"id"} . "_out";
              $md{"ifDir"} = "out"; 
            }
            printPair(\%md, \%d);
          }
        }
      }
    }
  }
}

printFooter();

$dbh->disconnect();





sub query {
  my($dbh, $query) = @_;
  my $sth = $dbh->prepare($query);
  $sth->execute() or print "Query error on statement \"".$query."\".\n";                  
  return $sth->fetchall_arrayref;  
}

sub checkVersion {
  my($dbh) = @_;  
  my $result = query($dbh, "select cacti from version");
  my $pass = 0;
  foreach my $ver (@VERSIONS) {
    if($ver eq $result->[0][0]) {
      $pass = 1;
    }
  }
  if(!$FORCE and !$pass) {
    print "Cacti version mismatch.  This script has only been tested with versions \"@VERSIONS\".  Use \"--force\" to override.\n";
    exit(1);
  }
  return;
}

sub printHeader {
  print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print "<nmwg:store  xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
  print "             xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\"\n";
  print "             xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"\n";
  print "             xmlns:snmp=\"http://ggf.org/ns/nmwg/tools/snmp/2.0/\">\n\n";
  return;
}

sub printPair {
  my($md, $d) = @_;
  print "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata.".$md->{"id"}."-".$d->{"id"}."\">\n";
  print "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"subject.".$md->{"id"}."-".$d->{"id"}."\">\n";
  print "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
  print "        <nmwgt:ipAddress type=\"ipv4\">".$md->{"ipAddress"}."</nmwgt:ipAddress>\n";

  if ( defined $md->{"ifIP"} ) {
    print "        <nmwgt:ifAddress type=\"ipv4\">".$md->{"ifIP"}."</nmwgt:ifAddress>\n";
  }

  print "        <nmwgt:hostName>".$md->{"hostName"}."</nmwgt:hostName>\n";
  if($md->{"ifName"}) {
    print "        <nmwgt:ifName>".$md->{"ifName"}."</nmwgt:ifName>\n";
  }
  else {
    print "        <nmwgt:ifName>".$md->{"ifDescr"}."</nmwgt:ifName>\n";
  }
  print "        <nmwgt:ifIndex>".$md->{"ifIndex"}."</nmwgt:ifIndex>\n";
  print "        <nmwgt:direction>".$md->{"ifDir"}."</nmwgt:direction>\n";
  print "        <nmwgt:capacity>".$md->{"ifSpeed"}."</nmwgt:capacity>\n";
  print "        <nmwgt:description>".$md->{"description"}."</nmwgt:description>\n";
  print "        <nmwgt:ifDescription>".$md->{"ifDescr"}."</nmwgt:ifDescription>\n";
  print "      </nmwgt:interface>\n";
  print "    </netutil:subject>\n";
  print "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:eventType>\n";
  print "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
  print "    <nmwg:parameters id=\"parameters.".$md->{"id"}."-".$d->{"id"}."\">\n";
  print "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
  print "      <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
  print "    </nmwg:parameters>\n";
  print "  </nmwg:metadata>\n\n";

  print "  <nmwg:data xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"data.".$d->{"id"}."\" metadataIdRef=\"metadata.".$md->{"id"}."-".$d->{"id"}."\">\n";
  print "    <nmwg:key id=\"key.".$d->{"id"}."\">\n";
  print "      <nmwg:parameters id=\"parametersKey.".$d->{"id"}."\">\n";
  print "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/tools/snmp/2.0</nmwg:parameter>\n";
  print "        <nmwg:parameter name=\"supportedEventType\">http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:parameter>\n";
  print "        <nmwg:parameter name=\"type\">rrd</nmwg:parameter>\n";
  print "        <nmwg:parameter name=\"file\">".$d->{"file"}."</nmwg:parameter>\n";
  print "        <nmwg:parameter name=\"valueUnits\">Bps</nmwg:parameter>\n";
  print "        <nmwg:parameter name=\"dataSource\">".$d->{"ds"}."</nmwg:parameter>\n";
  print "      </nmwg:parameters>\n";
  print "    </nmwg:key>\n";
  print "  </nmwg:data>\n\n";
  return;        
}

sub printFooter {
  print "</nmwg:store>\n";
  return;
}



__END__

=head1 NAME

cacti2nmwg.pl - Create a store.xml file from cacti data.

=head1 DESCRIPTION

Attach to a cacti database (version restrictions apply), extract some info, and
output a perfSONAR-PS SNMP MA formated store.xml file.  For now this only cares
about 'traffic' (i.e. octet counters). 
 
=head1 SYNOPSIS

./cacti2nmwg.pl [--verbose --help --force --user=db_user_name --pass=db_user_pass --name=db_name --host=db_host_name --port=db_host_port]

The verbose flag allows lots of debug statements to print to the screen.  Help
describes a simple use case.  Force can be used to press on even if the version
check against cacti fails.  The other options (user,pass,name,host,port) are
are related to the MySQL database.   

=head1 FUNCTIONS

The following functions are used in this script.

=head2 query($dbh, $query)

Given a DB handle, perform a query.  The results are returned as a 2d perl
array (i.e. $array->[$x][$y]). 

=head2 checkVersion($dbh)

Given a DB handle, checks the cacti version.  If the version doesn't match
up with something we have tested against the script will exit 
(unless --force'ed).

=head2 printHeader

Prints the 'top' portion of the store file.

=head2 printPair($md, $d)

Given a metadata/data hash pair we generate the NM-WG formated XML.

=head2 printFooter

Prints the 'bottom' portion of the store file.
         
=head1 SEE ALSO

L<Getopt::Long>, L<DBI>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS 
  
Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

https://bugs.internet2.edu/jira/browse/PSPS

=head1 VERSION

$Id: cacti2nmwg.pl 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along 
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2007, Internet2 and the University of Delaware

All rights reserved.

=cut



