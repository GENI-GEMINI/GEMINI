#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

cloud.cgi - Generate a world could from gLS Keywords

=head1 DESCRIPTION

...

=cut

use CGI;
use CGI::Carp;

my $CGI = CGI->new();
print $CGI->header();

print "<html>\n";
print "  <head>\n";
print "    <title>perfSONAR Information Services - Keyword Status</title>\n";
print "    <link rel=\"stylesheet\" type=\"text/css\" href=\"http://visapi-gadgets.googlecode.com/svn/trunk/wordcloud/wc.css\" />\n";
print "  </head>\n";
print "  <body>\n";

my $base   = "/home/zurawski/perfSONAR-PS/client/cgi/perfAdmin/cache";

my $hLSFile = $base . "/list.hls";
my @hlslist = ();
if ( -f $hLSFile ) {
    my $lastMod = "at an unknown time...";
    my ($mtime) = ( stat ( $hLSFile ) )[9];
    $lastMod = "on " . gmtime( $mtime ) . " UTC";

    open( READ, "<" . $hLSFile ) or croak "Can't open hLS File";
    my @hlscontent = <READ>;
    close( READ );

    print "    <h1 align=\"center\">perfSONAR Information Services - Keyword Status</h1>\n";
    print "    <br>\n";
    print "    <center><i>Information Last Fetched " . $lastMod . "</i></center>\n";
    print "    <br><br>\n";

    print "    <table align=\"center\" width=\"85%\">\n";
    print "      <tr valign=\"top\">\n";
    print "        <td align=\"center\">\n";
    print "          <div id=\"wcdiv\" style=\"width: 250px; border: 1px solid #ccc\"></div>\n";
    print "        </td>\n";
    print "      </tr>\n";
    print "      <tr valign=\"top\">\n";
    print "        <td align=\"center\"><br><br></td>\n";
    print "      </tr>\n";
    print "      <tr valign=\"top\">\n";
    print "        <td align=\"center\">\n";
    print "          <div id=\"tablediv\"></div>\n";
    print "        </td>\n";
    print "      </tr>\n";
    print "    </table>\n";
    
    print "    <script type=\"text/javascript\" src=\"http://visapi-gadgets.googlecode.com/svn/trunk/wordcloud/wc.js\"></script>\n";
    print "    <script type=\"text/javascript\" src=\"http://www.google.com/jsapi\"></script>\n";
    print "    <script type=\"text/javascript\">\n";
    print "      google.load('visualization', '1', {packages: ['table']});\n";
    print "      google.setOnLoadCallback(draw);\n";
    print "      function draw() {\n";
        
    print "        var data = new google.visualization.DataTable();\n";
    print "        data.addColumn('string', 'hLS URL');\n";
    print "        data.addColumn('string', 'Description');\n";
    print "        data.addColumn('string', 'Keyword(s)');\n";
    print "        data.addRows(" . ( $#hlscontent + 1 ) . ");\n";

    my $counter = 0;
    my @keywords = ();
    foreach my $c ( @hlscontent ) {
        $c =~ s/\n//g;
        my @fields = split(/\|/, $c);
        print "        data.setCell(" . $counter . ", 0, '" . $fields[0] . "');\n";
        print "        data.setCell(" . $counter . ", 1, '" . $fields[3] . "');\n";
        print "        data.setCell(" . $counter . ", 2, '" . $fields[4] . "');\n";   
        my @kw = split(/,/, $fields[4]);
        foreach my $k ( @kw ) {
            push @keywords, $k;
        }
        $counter++;
    }

    print "        var data2 = new google.visualization.DataTable();\n";
    print "        data2.addColumn('string', 'Keyword(s)');\n";
    print "        data2.addRows(" . ( $#keywords + 1 ) . ");\n";
    $counter = 0;
    foreach my $k ( @keywords ) {
        $k =~ s/project://;
        print "        data2.setCell(" . $counter . ", 0, '" . $k . "');\n";
        $counter++;
    }
        
    print "        var outputDiv = document.getElementById('wcdiv');\n";
    print "        var wc = new WordCloud(outputDiv);\n";
    print "        wc.draw(data2, null);\n";
    print "        table = new google.visualization.Table(document.getElementById('tablediv'));\n";
    print "        table.draw(data, {showRowNumber: true});\n";
    print "      }\n";
    print "    </script>\n";
}
else {
    print "    <h1 align=\"center\">perfSONAR Information Services - Keyword Status</h1>\n";
    print "    <br>\n";
    print "    <center><font size=\"+3\" color=\"red\">Currently Unavailable</font></center>\n";
    print "    <br><br>\n";
}

print "  </body>\n";
print "</html>\n";   
    
__END__

=head1 SEE ALSO

L<CGI>, L<CGI::Carp>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: cloud.cgi 2483 2009-02-26 19:59:28Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut

