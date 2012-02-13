#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

ndt.cgi - 
=head1 DESCRIPTION

Generate a list of NDT services from both a supplied perfSONAR cache as well as a static listing.


=cut

use CGI;
use CGI::Carp;
use IO::Socket;
use IO::Socket::INET6;
use IO::Socket::INET;

# change this to the location where you install perfSONAR-PS

use lib "/home/jason/RELEASE/RELEASE_3.1/Shared/lib";

use perfSONAR_PS::Transport;

my $CGI = CGI->new();
print $CGI->header();

print "<html>\n";
print "  <head>\n";
print "    <title>perfSONAR Information Services - NDT</title>\n";
print "  </head>\n";
print "  <body>\n";
print "    <h1 align=\"center\">perfSONAR Information Services - NDT</h1>\n";
print "    <br>\n";

my $base   = "/home/zurawski/perfSONAR-PS/client/cgi/perfAdmin/cache";

my $hLSFile = $base . "/list.ndt";
my @hlslist = ();
if ( -f $hLSFile ) {
    my $lastMod = "at an unknown time...";
    my ($mtime) = ( stat ( $hLSFile ) )[9];
    $lastMod = "on " . gmtime( $mtime ) . " UTC";

    open( READ, "<" . $hLSFile ) or croak "Can't open NDT File";
    my @ndtcontent = <READ>;
    close( READ );

    print "    <center><i>Information Last Fetched " . $lastMod . "</i></center>\n";
    print "    <br><br>\n";

    print "    <table align=\"center\" width=\"85%\">\n";
    print "      <tr valign=\"top\">\n";
    print "        <td align=\"center\">\n";
    print "          <div id=\"tablediv\"></div>\n";
    print "        </td>\n";
    print "      </tr>\n";
    print "      <tr valign=\"top\">\n";
    print "        <td align=\"center\">\n";
    print "          <br><br><a name=\"NB\" /><font size=\"+2\" color=\"red\">*</font> <font size=\"-1\">These NDT services are reachable <i>from <b>this</b> web server</i>.  They may or may not be reachable <i>from <b>your</b> computer</i> due to private network deployments.</font>\n";  
    print "        </td>\n";
    print "      </tr>\n";    
    print "    </table>\n";
    
    print "    <script type=\"text/javascript\" src=\"http://www.google.com/jsapi\"></script>\n";
    print "    <script type=\"text/javascript\">\n";
    print "      google.load('visualization', '1', {packages: ['table']});\n";
    print "      google.setOnLoadCallback(draw);\n";
    print "      function draw() {\n";
        
    print "        var data = new google.visualization.DataTable();\n";
    print "        data.addColumn('string', 'NDT Address');\n";
    print "        data.addColumn('string', 'NDT Address2');\n";
    print "        data.addColumn('string', 'Name');\n";
    print "        data.addColumn('string', 'Description');\n";
    print "        data.addColumn('number', 'Reachable<sub><a href=\"#NB\">*</a></sub>');\n";
    print "        data.addRows(" . ( $#ndtcontent + 1 ) . ");\n";

    my $counter = 0;
    foreach my $c ( @ndtcontent ) {
        $c =~ s/\n//g;
        my @fields = split(/\|/, $c);
        print "        data.setCell(" . $counter . ", 0, '" . $fields[0] . "');\n";
        print "        data.setCell(" . $counter . ", 1, '" . $fields[0] . "');\n";
        print "        data.setCell(" . $counter . ", 2, '" . $fields[1] . "');\n";
        print "        data.setCell(" . $counter . ", 3, '" . $fields[3] . "');\n";    
        my ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $fields[0] );
        if ( is_up( $host, $port ) ) {
            print "        data.setCell(" . $counter . ", 4, 1, 'Up');\n"; 
        }
        else {
            print "        data.setCell(" . $counter . ", 4, -1, 'Down');\n"; 
        }
        $counter++;
    }

    print "        var table = new google.visualization.Table(document.getElementById('tablediv'));\n";

    print "        var formatter = new google.visualization.TablePatternFormat('<a href=\"{1}\">{0}</a>');\n";
    print "        formatter.format(data, [0, 1]);\n";

    print "        var formatter = new google.visualization.TableArrowFormat();\n";
    print "        formatter.format(data, 4);\n";

    print "        var view = new google.visualization.DataView(data);\n";
    print "        view.setColumns([0, 2, 3, 4]);\n";
    print "        table.draw(view, {allowHtml: true, showRowNumber: true});\n";
    print "      }\n";
    print "    </script>\n";
}
else {
    print "    <center><font size=\"+3\" color=\"red\">Currently Unavailable</font></center>\n";
    print "    <br><br>\n";
}

print "  </body>\n";
print "</html>\n";   

sub is_up {
    my ( $addr, $port ) = @_;
    my $sock = q{};
    if ( $addr =~ /:/ ) {
        $sock = IO::Socket::INET6->new( PeerAddr => $addr, PeerPort => $port, Proto => 'tcp', Timeout => 5 );
    }
    else {
        $sock = IO::Socket::INET->new( PeerAddr => $addr, PeerPort => $port, Proto => 'tcp', Timeout => 5 );
    }
    if ( $sock ) {
        $sock->close;
        return 1;
    }
    return 0;
}    
    
__END__

=head1 SEE ALSO

L<CGI>, L<CGI::Carp>, L<IO::Socket>, L<IO::Socket::INET6>, L<IO::Socket::INET>,
L<perfSONAR_PS::Transport>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: ndt.cgi 2870 2009-07-02 13:17:22Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut

