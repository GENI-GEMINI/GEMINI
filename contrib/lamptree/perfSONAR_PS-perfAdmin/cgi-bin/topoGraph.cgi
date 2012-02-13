#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

topoGraph.cgi - CGI script that graphs the output of the perfSONAR TS.

=head1 DESCRIPTION

Given a url of an hLS and TS, graph the output of the TS for a given domain.

=cut

use CGI;
use XML::LibXML;
use Date::Manip;
use Socket;
use POSIX;
use Time::Local 'timelocal_nocheck';
use English qw( -no_match_vars );
use HTML::Entities;
use URI::Escape;
use File::Temp qw(tempfile);

use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib "$RealBin/../lib";

use perfSONAR_PS::Client::DCN;
use perfSONAR_PS::Common qw( extract find );

my $cgi = new CGI;
if ( $cgi->param( 'domain' ) and $cgi->param( 'hLS' ) and $cgi->param( 'ts' ) ) {
    my $dcn = new perfSONAR_PS::Client::DCN( { instance => $cgi->param( 'hLS' ) } );

    my $result = $dcn->queryTS( { topology => $cgi->param( 'ts' ), domain => $cgi->param( 'domain' ) } );

    my ( $fileHandle_dot, $fileName_dot ) = tempfile();
    my ( $fileHandle_png, $fileName_png ) = tempfile();
    close( $fileHandle_png );

    my $parser = XML::LibXML->new();
    my $dom    = $parser->parse_string( $result->{response} );

    my %nodes        = ();
    my %domains      = ();
    my @colors       = ( "mediumslateblue", "crimson", "chartreuse", "yellow", "darkorchid", "orange", "greenyellow" );
    my $colorCounter = 0;

    print $fileHandle_dot "graph g {\n";
    print $fileHandle_dot "  nodesep=1.5;\n";
    print $fileHandle_dot "  ranksep=1.5;\n";

    foreach my $l ( $dom->getElementsByLocalName( "link" ) ) {
        my $id      = $l->find( "./\@id" );
        my %id_hash = ();

        $id =~ s/^urn:ogf:network://;
        $id = uri_unescape( $id );
        my @array = split( /:/, $id );
        foreach my $a ( @array ) {
            my @array2 = split( /=/, $a );
            $id_hash{ $array2[0] } = $array2[1];
        }

        unless ( exists $domains{ $id_hash{"domain"} } ) {
            $domains{ $id_hash{"domain"} } = $colorCounter;
            $colorCounter++;
        }
        unless ( exists $nodes{ $id_hash{"node"} } ) {
            $nodes{ $id_hash{"node"} } = $domains{ $id_hash{"domain"} };
        }

        if ( $id ) {
            if ( $l->find( "./*[local-name()=\"remoteLinkId\"]" ) ) {
                my $rid      = $l->find( "./*[local-name()=\"remoteLinkId\"]/text()" )->get_node( 1 )->toString;
                my %rid_hash = ();
                $rid =~ s/^urn:ogf:network://;
                $rid = uri_unescape( $rid );
                my @array3 = split( /:/, $rid );
                foreach my $a ( @array3 ) {
                    my @array4 = split( /=/, $a );
                    $rid_hash{ $array4[0] } = $array4[1];
                }

                unless ( exists $domains{ $id_hash{"domain"} } ) {
                    $domains{ $id_hash{"domain"} } = $colorCounter;
                    $colorCounter++;
                }
                unless ( exists $nodes{ $id_hash{"node"} } ) {
                    $nodes{ $id_hash{"node"} } = $domains{ $id_hash{"domain"} };
                }

                unless ( $id_hash{"node"} eq "*" or $rid_hash{"node"} eq "*" ) {
                    print $fileHandle_dot "  \"", $id_hash{"node"}, "\" -- \"", $rid_hash{"node"}, "\" [ labeldistance=2, labelfontsize=8, arrowhead=none, arrowtail=none, headlabel=\"" . $id_hash{"port"} . "\", taillabel=\"" . $rid_hash{"port"} . "\" ];\n";
                }
            }
        }
    }
    foreach my $n ( keys %nodes ) {
        print $fileHandle_dot "  \"" . $n . "\" [ color=" . $colors[ $nodes{$n} ] . ", style=filled ];\n";
    }
    print $fileHandle_dot "}\n";
    close( $fileHandle_dot );

    print "Content-type: image/png\n\n";
    system( "/usr/bin/fdp " . $fileName_dot . " -Tpng" );
}
else {
    print "Content-type: text/html\n\n";
    print "<html><head><title>perfSONAR-PS perfAdmin Topology Graph</title></head>";
    print "<body><h2 align=\"center\">Graph error, cannot find 'domain', 'ts', or 'hLS' to contact; Close window and try again.</h2></body></html>";
    exit( 1 );
}

__END__

=head1 SEE ALSO

L<CGI>, L<XML::LibXML>, L<Date::Manip>, L<Socket>, L<POSIX>, L<Time::Local>,
L<English>, L<HTML::Entities>, L<URI::Escape>, L<File::Temp>,
L<perfSONAR_PS::Client::MA>, L<perfSONAR_PS::Common>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: topoGraph.cgi 3662 2009-08-28 15:30:51Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and The University of Delaware

All rights reserved.

=cut
