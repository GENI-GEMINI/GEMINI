#!/usr/bin/perl -w

use strict;
use warnings;
use CGI;
use CGI::Ajax;

use lib "/home/jason/RELEASE/RELEASE_3.1/perfSONAR_PS-LookupService/lib";
use perfSONAR_PS::Client::DCN;
use perfSONAR_PS::Common qw( escapeString );

my $cgi = new CGI;

my $INSTANCE = "http://dcn-ls.internet2.edu:8006/perfSONAR_PS/services/hLS";
if ( $cgi->param( 'hls' ) ) {
    $INSTANCE = $cgi->param( 'hls' );
}

my $pjx = new CGI::Ajax( 'exported_func' => \&delete );

print $pjx->build_html( $cgi, \&display );

# Call/Display the DCN mappings

sub delete {
    my ( $hls, $load, $hostname, $linkid, $add, $institution, $longitude, $latitude, $kw ) = @_;

    my @kw = ();
    @kw = split( /\n/, $kw ) if $kw;

    my $html = q{};
    unless ( defined $load and $load and defined $hls and $hls ) {
        return $html;
    }

    my $dcn = new perfSONAR_PS::Client::DCN( 
        { 
            instance => $hls, 
            myAddress => "https://dcn-ls.internet2.edu/dcnAdmin.cgi", 
            myName => "DCN Registration CGI", 
            myType => "dcnmap" 
        } 
    );

    $html = "<br>\n";
    if ( $hostname or $linkid ) {
        $html .= "<table width=\"100%\" align=\"center\" border=\"2\">\n";
        $html .= "<tr><th align=\"center\" colspan=\"2\" >Operation Status</th></tr>\n";
        $html .= "<tr>\n";
        if ( $hostname and $linkid ) {
            if ( $add ) {
                my $code = $dcn->insert(
                    {
                        name        => $hostname,
                        id          => $linkid,  
                        institution => $institution, 
                        longitude   => $longitude,
                        latitude    => $latitude,
                        keywords    => \@kw
                    }
                );
                if ( $code == 0 ) {
                    $html .= "<td align=\"center\" ><b><font color=\"green\"/>Insert</font></b></td>\n";
                    $html .= "<td align=\"center\" ><i>Insert of \"" . $hostname . "\" and \"" . $linkid . "\" worked.</i></td>\n</tr>\n";
                }
                else {
                    $html .= "<td align=\"center\" ><b><font color=\"red\"/>Insert</font></b></td>\n";
                    $html .= "<td align=\"center\" ><i>Insert of \"" . $hostname . "\" and \"" . $linkid . "\" failed.</i></td>\n</tr>\n";
                }
            }
            else {
               my $code = $dcn->remove(
                    {
                        name => $hostname,
                        id   => $linkid
                    }
                );
                if ( $code == 0 ) {
                    $html .= "<td align=\"center\" ><b><font color=\"green\"/>Delete</font></b></td>\n";
                    $html .= "<td align=\"center\" ><i>Delete of \"" . $hostname . "\" and \"" . $linkid . "\" worked.</i></td>\n</tr>\n";
                }
                else {
                    $html .= "<td align=\"center\" ><b><font color=\"red\"/>Delete</font></b></td>\n";
                    $html .= "<td align=\"center\" ><i>Delete of \"" . $hostname . "\" and \"" . $linkid . "\" failed.</i></td>\n</tr>\n";
                }
            }
        }
        else {
            $html .= "<td align=\"center\" ><b><font color=\"red\"/>Insert</font></b></td>\n";
            $html .= "<td align=\"center\" ><i>Insert of \"" . $hostname . "\" and \"" . $linkid . "\" failed - need to specify both fields.</i></td>\n</tr>\n";
        }
        $html .= "</tr>\n";
        $html .= "</table>\n";
        $html .= "<br>\n";
    }

    $html .= "<table border=\"0\" align=\"center\" width=\"60%\" >\n";

    $html .= "<tr>\n";
    $html .= "<td colspan=\"4\" align=\"center\">\n";
    $html .= "<input type=\"submit\" name=\"insert\" ";
    $html .= "value=\"Insert\" onclick=\"exported_func( ";
    $html .= "['hls', 'loadQuery', 'hostname', 'linkid', 'add', 'institution', 'longitude', 'latitude', 'kw'], ['resultdiv'] );\">\n";
    $html .= "<input type=\"hidden\" name=\"add\" value=\"1\" id=\"add\" >\n";
    $html .= "</td>\n";
    $html .= "</tr>\n";
    
    $html .= "<tr>\n";
    $html .= "<td align=\"center\" colspan=\"2\">\n";
    $html .= "Hostname: <input type=\"text\" name=\"hostname\" id=\"hostname\" />\n";
    $html .= "</td>\n";
    $html .= "<td align=\"center\" colspan=\"2\">\n";
    $html .= "LinkID: <input type=\"text\" name=\"linkid\" id=\"linkid\" />\n";
    $html .= "</td>\n";
    $html .= "</tr>\n";

    $html .= "<tr>\n";
    $html .= "<td align=\"center\" colspan=\"4\">\n";
    $html .= "<br><font color=\"blue\">Institution: </font><input type=\"text\" name=\"institution\" id=\"institution\" />\n";
    $html .= "</td>\n";
    $html .= "</tr>\n";

    $html .= "<tr>\n";
    $html .= "<td align=\"center\" colspan=4>\n";
    $html .= "<br><font color=\"blue\">Keywords:</font><br><textarea cols=\"30\" rows=\"5\" name=\"kw\" id=\"kw\" /></textarea><br><br>\n";
    $html .= "</td>\n";
    $html .= "</tr>\n";

    $html .= "<tr>\n";
    $html .= "<td align=\"center\" colspan=\"2\">\n";
    $html .= "<font color=\"blue\">Longitude: </font><input type=\"text\" name=\"longitude\" id=\"longitude\" />\n";
    $html .= "</td>\n";
    $html .= "<td align=\"center\" colspan=\"2\">\n";
    $html .= "<font color=\"blue\">Latitude: </font><input type=\"text\" name=\"latitude\" id=\"latitude\" />\n";
    $html .= "</td>\n";
    $html .= "</tr>\n";

    $html .= "</table><br><br><br>\n";

    my $map = $dcn->getMappings;
    $html .= "<table width=\"100%\" align=\"center\" border=\"0\">\n";

    if ( $#$map == -1 ) {
        $html .= "<tr>";
        $html .= "<td align=\"center\" colspan=\"6\">";
        $html .= "<i>No data to display.</i>";
        $html .= "</td>";
        $html .= "</tr>\n";
    }
    else {
        $html .= "<tr>";
        $html .= "<th align=\"center\"><i>Name</i></th>";
        $html .= "<th align=\"center\"><i>Id</i></th>";
        $html .= "<th align=\"center\"><i>Institution</i></th>";
        $html .= "<th align=\"center\"><i>Coordinates</i></th>";
        $html .= "<th align=\"center\"><i>Keywords</i></th>";
        $html .= "<th align=\"center\"><br></th>";
        $html .= "</tr>";        

        my $counter = 0;
        foreach my $m ( @$map ) {
            $html .= "<tr>\n";
            $html .= "<td><input type=\"text\" name=\"hostname." . $counter . "\" value=\"" . $m->[0] . "\" size=\"20\" id=\"hostname." . $counter . "\" /></td>\n";
            $html .= "<td><input type=\"text\" name=\"linkid." . $counter . "\" value=\"" . $m->[1] . "\" size=\"65\" id=\"linkid." . $counter . "\" /></td>\n";

            if ( exists $m->[2] and $m->[2] ) {
                if ( $m->[2]->{institution} ) {
                    $html .= "<td>" . $m->[2]->{institution} . "</td>";
                }
                else {
                    $html .= "<td><br></td>";
                }

                if ( $m->[2]->{longitude} or $m->[2]->{latitude} ) {
                    $html .= "<td>\"" . $m->[2]->{longitude} . "\", \"" . $m->[2]->{latitude} . "\"</td>";
                }
                else {
                    $html .= "<td><br></td>";
                }

                if ( $m->[2]->{keywords} ) {
                    $html .= "<td>";
                    my $kwc = 0;
                    foreach my $kw ( @{ $m->[2]->{keywords} } ) {
                        $html .= ", " if $kwc;
                        $html .= $kw;
                        $kwc++;
                    }
                    $html .= "</td>";
                }
                else {
                    $html .= "<td><br></td>";
                }
                
                if ( exists $m->[2]->{authoratative} and $m->[2]->{authoratative} ) {
                    $html .= "<td>\n";
                    $html .= "<input type=\"submit\" name=\"submit." . $counter . "\" ";
                    $html .= "value=\"Delete\" onclick=\"exported_func( ";
                    $html .= "['hls', 'loadQuery', 'hostname." . $counter . "', 'linkid." . $counter . "'], ";
                    $html .= "['resultdiv'] );\">\n";         
                    $html .= "</td>\n";       
                }
                else {
                    $html .= "<td><br></td>"; 
                }
                
            }
            else {
                $html .= "<td><br></td>";
                $html .= "<td><br></td>";
                $html .= "<td><br></td>";
                $html .= "<td><br></td>";               
            }
            $html .= "</tr>\n";
            $counter++;
        }
    }
    $html .= "</table>\n";
    $html .= "<br>\n";

    return $html;
}

# Main Page Display

sub display {

    #  my $html = $cgi->start_html(-title=>'DCN Administrative Tool',
    #			      -style=>{'src'=>'../html/dcn.css'});

    my $html = $cgi->start_html( -title => 'DCN Administrative Tool' );

    $html .= $cgi->h2( { align => "center" }, "DCN Administrative Tool" ) . "\n";
    $html .= $cgi->br;
    if ( $INSTANCE ) {
        $html .= $cgi->h3( { align => "center" }, $INSTANCE ) . "\n";

        $html .= $cgi->hr( { size => "4", width => "95%" } ) . "\n";

        $html .= $cgi->br;
        $html .= $cgi->br;

        $html .= $cgi->start_table( { border => "2", cellpadding => "1", align => "center", width => "95%" } ) . "\n";

        $html .= $cgi->start_Tr;
        $html .= $cgi->start_th( { align => "center" } );
        $html .= $cgi->h3( { align => "center" }, "Connection Mappings" );
        $html .= $cgi->end_td;
        $html .= $cgi->end_Tr;

        $html .= $cgi->start_Tr;
        $html .= $cgi->start_td( { align => "center" } );
        $html .= "<input type=\"hidden\" name=\"hls\" id=\"hls\" ";
        $html .= "value=\"" . $INSTANCE . "\">\n";

        $html .= "<input type=\"submit\" name=\"query\" ";
        $html .= "value=\"Query LS\" onclick=\"exported_func( ";
        $html .= "['hls', 'loadQuery'], ['resultdiv'] );\">\n";

        $html .= "<input type=\"reset\" name=\"query_reset\" ";
        $html .= "value=\"Reset\" onclick=\"exported_func( ";
        $html .= "['hls'], ['resultdiv'] );\">\n";

        $html .= "<input type=\"hidden\" name=\"loadQuery\" ";
        $html .= "id=\"loadQuery\" value=\"1\" />\n";

        $html .= "<div id=\"resultdiv\"></div>\n";
        $html .= $cgi->end_td;
        $html .= $cgi->end_Tr;

        $html .= $cgi->end_table . "\n";

        $html .= $cgi->br;
        $html .= $cgi->br;
    }
    else {
        $html .= $cgi->h3( { align => "center" }, "hLS Instance Not Defined" ) . "\n";
    }

    $html .= $cgi->hr( { size => "4", width => "95%" } ) . "\n";

    $html .= $cgi->end_html . "\n";
    return $html;
}

