#!/usr/bin/perl -w 

use strict;
use warnings;

=head1 NAME

bwctl.cgi - BWCTL Mesh Status 

=head1 DESCRIPTION

CGI script to talk to the perfSONAR-BUOY database and get the most recent values for some mesh of tests.  

=cut

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use HTML::Template;
use DBI;

# ###############################
#
# Make sure we get any URL arguments (e.g. we need the mesh name)
#

my $cgi = CGI->new();
print $cgi->header();
my $template = q{};

my $name;
if ( $cgi->param('name') ) {
    $name = $cgi->param('name');
}
else {
    die "Mesh name not provided, aborting.  Set ?name=SOMENAME in the URL."
}

# ###############################
#
# OWP specific libraries and defaults
#

use lib "/usr/local/ami/server/lib";

use OWP;
use OWP::Utils;

my %amidefaults;
BEGIN{
    %amidefaults = (
        CONFDIR => "/usr/local/etc",
        LIBDIR  => "/usr/local/ami/server/lib",
    );
}

my $conf = new OWP::Conf(%amidefaults);

# ###############################
#
# Unroll the owmesh file, get anything we need from there (mesh defns + database info)
#

my $dbhost = $conf->must_get_val(ATTR=>'CentralDBHost');
my $dbtype = $conf->must_get_val(ATTR=>'CentralDBType');
my $dbname = $conf->must_get_val(ATTR=>'BWCentralDBName');
my $dbuser = $conf->must_get_val(ATTR=>'CGIDBUser');
my $dbpass = $conf->get_val(ATTR=>'CGIDBPass');

my @measurement_sets = $conf->get_val( ATTR => 'MEASUREMENTSETLIST' );
my %temp = map { $_ => 1 } @measurement_sets;
die "Cannot find '". $name ."' on this server, aborting.\n" unless exists $temp{$name};

my $group = $conf->get_val( MEASUREMENTSET => $name, ATTR => 'GROUP' );
my $g_type = $conf->get_val( GROUP => $group, ATTR => 'GROUPTYPE' );
die "Measurement set '". $name ."' is not a mesh (stored as a '".$g_type."'), aborting.\n" unless $g_type eq "MESH";

my $meas_desc = $conf->get_val( MEASUREMENTSET => $name, ATTR => 'DESCRIPTION' );
my $testspec = $conf->get_val( MEASUREMENTSET => $name, ATTR => 'TESTSPEC' );
my $addrtype = $conf->get_val( MEASUREMENTSET => $name, ATTR => 'ADDRTYPE' );

my @nodes = $conf->get_val( GROUP => $group, ATTR => 'NODES' );
my $group_desc = $conf->get_val( GROUP => $group, ATTR => 'DESCRIPTION' );

my $test_reportinterval = $conf->get_val( TESTSPEC => $testspec, ATTR => 'BWREPORTINTERVAL' );
my $test_tool = $conf->get_val( TESTSPEC => $testspec, ATTR => 'TOOL' );
my $test_type = $conf->get_val( TESTSPEC => $testspec, ATTR => 'BWTCP' );
my $test_desc = $conf->get_val( TESTSPEC => $testspec, ATTR => 'DESCRIPTION' );
my $test_duration = $conf->get_val( TESTSPEC => $testspec, ATTR => 'BWTESTDURATION' );
my $test_interval = $conf->get_val( TESTSPEC => $testspec, ATTR => 'BWTESTINTERVAL' );
my $test_windowsize = $conf->get_val( TESTSPEC => $testspec, ATTR => 'BWWINDOWSIZE' );



# ###############################
#
# Time information (e.g. we want to check for the most recent of the last 5 test results)
#

my $endTime = time;
my($e_sec,$e_min,$e_hour,$e_mday,$e_mon,$e_year)=gmtime($endTime);

my $startTime = $endTime - ( 5 * $test_interval );
my($s_sec,$s_min,$s_hour,$s_mday,$s_mon,$s_year)=gmtime($startTime);



# ###############################
#
# Connect to the database, get the actual data
#

my $dbsource = $dbtype . ":" . $dbname . ":" . $dbhost;
my $dbh = DBI->connect(
    $dbsource,
    $dbuser,
    $dbpass,
    {
        RaiseError => 0,
        PrintError => 1
    }
) || croak "Couldn't connect to database";


#
#  Sanity check the DB to be sure we have the proper date(s) stored
#
my $sql = "select * from DATES where year=".($s_year+1900)." and month=".($s_mon+1);
my $s_date_ref  = $dbh->selectall_arrayref($sql);
$sql = "select * from DATES where year=".($e_year+1900)." and month=".($e_mon+1);
my $e_date_ref  = $dbh->selectall_arrayref($sql);

my %res = ();
my %node_info;
if ( $#{ $s_date_ref } == 0 or $#{ $e_date_ref } == 0 ) {

    if ( $s_year == $e_year ) {
        # do one select statement

        # get the testspecid
        $sql = "select tspec_id from ".$e_date_ref->[0][0].sprintf("%02d", $e_date_ref->[0][1])."_TESTSPEC where description='".$name."'";
        my $t_ref = $dbh->selectall_arrayref($sql);
        my $tspec_id = "(";      
        my $counter = 0;
        foreach my $id ( @{ $t_ref } ) {
            $tspec_id .= " or " if $counter;
            $tspec_id .= "tspec_id ='" . $id->[0] . "'";
            $counter++;
        }
        $tspec_id .= ")";

        # first do the node info
        foreach my $node ( @nodes ) {
            $node_info{$node}{"LONGNAME"} = $conf->get_val( NODE => $node, ATTR => 'LONGNAME' );
            $node_info{$node}{"ADDRESS"} = $conf->get_val( NODE => $node, ATTR => 'ADDR', TYPE => $addrtype );
            $sql = "select node_id,last from ".$e_date_ref->[0][0].sprintf("%02d", $e_date_ref->[0][1])."_NODES where node_name='".$node."'";
            $t_ref = $dbh->selectall_arrayref($sql);
            $node_info{$node}{"ID"} = $t_ref->[0][0] if $t_ref->[0][0];
            $node_info{$node}{"LAST"} = $t_ref->[0][1] if $t_ref->[0][1];
        }

        foreach my $r ( @nodes ) {
            foreach my $s ( @nodes ) {
                next if $r eq $s;
                $sql = "select max(timestamp) from ".$e_date_ref->[0][0].sprintf("%02d", $e_date_ref->[0][1])."_DATA where ".$tspec_id." and recv_id='".$node_info{$r}{"ID"}."' and send_id='".$node_info{$s}{"ID"}."' and timestamp > ".time2owptime($startTime)." and timestamp < ".time2owptime($endTime);
                my $d_ref1 = $dbh->selectall_arrayref($sql);
	        $sql = "select * from ".$e_date_ref->[0][0].sprintf("%02d", $e_date_ref->[0][1])."_DATA where ".$tspec_id." and recv_id='".$node_info{$r}{"ID"}."' and send_id='".$node_info{$s}{"ID"}."' and timestamp=".$d_ref1->[0][0]; 
                my $d_ref = $dbh->selectall_arrayref($sql);
                $res{$r}{$s}{"TIME"} = $d_ref->[0][4] if $d_ref->[0][4];
                $res{$r}{$s}{"VALUE"} = eval( $d_ref->[0][5] ) if $d_ref->[0][5];
            }
        }     

    }
    else {
        # do two select statements
    }

}
else {
    # error - load junk into the template?
}



# ###############################
#
# Load the template, then display
#

my $meshName = $meas_desc;
my $sites = $#nodes+1;
my $type = $test_tool;

my @header = ();
foreach my $site ( @nodes ) {
    push @header, { VAL => $node_info{$site}{"LONGNAME"} }
}

my @rec = ();
foreach my $r ( @nodes ) {
    my @send = ();
    foreach my $s ( @nodes ) {
        if ( $r eq $s ) {
            push @send, { VALUE => -1, TIME => -1, ALIVE => 0};
        }
        else {
            if ( exists $res{$r}{$s}{"TIME"} and exists $res{$r}{$s}{"VALUE"} ) {
                my($sec,$min,$hour,$mday,$mon,$year)=gmtime( owptime2time ( $res{$r}{$s}{"TIME"} ) );
                my $timestring = ($year+1900)."-".sprintf("%02d",($mon+1))."-".sprintf("%02d",$mday)." ".sprintf("%02d",$hour).":".sprintf("%02d",$min).":".sprintf("%02d",$sec)."UTC";
                my $bps = $res{$r}{$s}{"VALUE"};
                if ( $bps ) {
                    $bps /= 1048576;
                    if ( $bps >= 1000 ) {
                        $bps = 1073741824;
                    }
                }
                else {
                    $bps = 0;
                }
                $res{$r}{$s}{"VALUE"} = sprintf("%.2f Mbps", $bps );
                push @send, { VALUE => $res{$r}{$s}{"VALUE"}, TIME => $timestring, ALIVE => 1};
            }
            else {
                push @send, { VALUE => -1, TIME => -1, ALIVE => 0};
            }
        }
    }
    push @rec, { HEADER => $node_info{$r}{"LONGNAME"}, SEND => \@send };
}

$template = HTML::Template->new( filename => "etc/bwctl.tmpl" );
$template->param( 
    NAME => $meshName,
    COLS => $sites + 2,
    TYPE => $type,
    HEADER => \@header,
    RECV => \@rec
);

print $template->output;

__END__

=head1 SEE ALSO

L<CGI>, L<CGI::Carp>, L<HTML::Template>, L<DBI>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: bwctl.cgi 2521 2009-03-11 15:15:49Z aaron $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
