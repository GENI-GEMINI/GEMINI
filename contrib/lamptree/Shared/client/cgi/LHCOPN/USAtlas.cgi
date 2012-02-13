#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

USAtlas.cgi - List 'USATLAS' encoded hLS instances and check if they are responsive.

=head1 DESCRIPTION

Relies on a caching program (USAtlas.pl) to build up the list of instances that
match USATLAS related keywords in the gLS.  The cache program also determines
liveness.  This CGI is really for display only.  

=cut

use HTML::Template;
use CGI;
use CGI::Carp;

use lib "/home/zurawski/perfSONAR-PS/lib";
#use lib "/usr/local/perfSONAR-PS/lib";

my $base   = "/var/www/cgi-bin/perfAdmin/USAtlas";
my $template = HTML::Template->new( filename => "etc/USAtlas.tmpl" );
my $CGI = CGI->new();

my $lastMod = "at an unknown time...";

my $hLSFile = $base . "/list.hls";
my @hlslist = ();
my @list = ();
if ( -f $hLSFile ) {
    my ($mtime) = (stat ( $hLSFile ) )[9];
    $lastMod = "on " . gmtime( $mtime ) . " UTC";

    open( READ, "<" . $hLSFile ) or croak "Can't open hLS File";
    my @hlscontent = <READ>;
    close( READ );
    
    my $counter = 1;
    foreach my $c ( @hlscontent ) {
        $c =~ s/\n//g;
        my @fields = split(/\|/, $c);
        push @hlslist, { NAME => $fields[0], COUNT => $counter, DESC => $fields[3], ALIVE => ($fields[4]+1) };
        $counter++;
    }
}
else {
    # do something...
}

print $CGI->header();

$template->param(
    MOD => $lastMod,
    HLSINSTANCES => \@hlslist
);

print $template->output;

__END__

=head1 SEE ALSO

L<HTML::Template>, L<CGI>, L<CGI::Carp>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: USAtlas.cgi 2479 2009-02-25 14:20:52Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
