#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

view.cgi - View the contents of an hLS. 

=head1 DESCRIPTION

Supply an hLs argument, and see the internal XML contents of that hLS.

=cut

use CGI;
use HTML::Template;
use XML::LibXML;
use CGI::Carp qw(fatalsToBrowser);
use English qw( -no_match_vars );
use Config::General;

use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib "$RealBin/../../../../lib";

use perfSONAR_PS::Utils::GENIPolicy qw( verify_cgi );
use perfSONAR_PS::Common qw( unescapeString escapeString find extract );
use perfSONAR_PS::Client::LS;

my $cgi    = new CGI;
my $parser = XML::LibXML->new();

croak "hLS instance not provided unless " unless $cgi->param( 'hls' );

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

verify_cgi( \%conf );

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

my $INSTANCE = $cgi->param( 'hls' );
my $template = HTML::Template->new( filename => "$conf{template_directory}/view.tmpl" );

my @data  = ();
my $ls    = new perfSONAR_PS::Client::LS( { instance => $INSTANCE } );
my @eT    = ( "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/query/xquery/2.0", "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/xquery/2.0" );
my @store = ( "LSStore", "LSStore-summary", "LSStore-control" );

foreach my $e ( @eT ) {
    foreach my $s ( @store ) {
        my $METADATA = q{};
        my $q        = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n/nmwg:store[\@type=\"" . $s . "\"]/nmwg:metadata\n";
        my $result   = $ls->queryRequestLS( { query => $q, eventType => $e, format => 1 } );
        if ( exists $result->{"eventType"} and not( $result->{"eventType"} =~ m/^error/ ) ) {
            my $doc = q{};
            eval { $doc = $parser->parse_string( $result->{"response"} ) if exists $result->{"response"}; };
            if ( $EVAL_ERROR ) {
                $METADATA .= "Cannot parse XML output from service.";
            }
            else {
                my $md = find( $doc->getDocumentElement, ".//nmwg:metadata", 0 );
                foreach my $m ( $md->get_nodelist ) {
                    $METADATA .= escapeString( $m->toString ) . "\n";
                }
            }
        }
        else {
            if ( exists $result->{"eventType"} and $result->{"eventType"} eq "error.ls.query.ls_output_not_accepted" ) {
                $result = $ls->queryRequestLS( { query => $q, eventType => $e, format => 0 } );
                $result->{"response"} = unescapeString( $result->{"response"} );
                if ( exists $result->{"eventType"} and not( $result->{"eventType"} =~ m/^error/ ) ) {
                    my $doc = q{};
                    eval { $doc = $parser->parse_string( $result->{"response"} ) if exists $result->{"response"}; };
                    if ( $EVAL_ERROR ) {
                        $METADATA .= "Cannot parse XML output from service.";
                    }
                    else {
                        my $md = find( $doc->getDocumentElement, ".//nmwg:metadata", 0 );
                        foreach my $m ( $md->get_nodelist ) {
                            $METADATA .= escapeString( $m->toString ) . "\n";
                        }
                    }
                }
                else {
                    $METADATA = "EventType:\t" . $result->{'eventType'} . "\nResponse:\t" . $result->{"response"};
                }
            }
            else {
                $METADATA = "EventType:\t" . $result->{'eventType'} . "\nResponse:\t" . $result->{"response"};
            }
        }

        my $DATA = q{};
        $q = "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n/nmwg:store[\@type=\"" . $s . "\"]/nmwg:data\n";
        $result = $ls->queryRequestLS( { query => $q, eventType => $e, format => 1 } );
        if ( exists $result->{eventType} and not( $result->{eventType} =~ m/^error/ ) ) {
            my $doc = q{};
            eval { $doc = $parser->parse_string( $result->{response} ) if exists $result->{response}; };
            if ( $EVAL_ERROR ) {
                $DATA .= "Cannot parse XML output from service.";
            }
            else {
                my $data = find( $doc->getDocumentElement, ".//nmwg:data", 0 );
                foreach my $d ( $data->get_nodelist ) {
                    $DATA .= escapeString( $d->toString ) . "\n";
                }
            }
        }
        else {
            if ( exists $result->{"eventType"} and $result->{"eventType"} eq "error.ls.query.ls_output_not_accepted" ) {
                $result = $ls->queryRequestLS( { query => $q, eventType => $e, format => 0 } );
                $result->{"response"} = unescapeString( $result->{"response"} );
                if ( exists $result->{"eventType"} and not( $result->{"eventType"} =~ m/^error/ ) ) {
                    my $doc = q{};
                    eval { $doc = $parser->parse_string( $result->{"response"} ) if exists $result->{"response"}; };
                    if ( $EVAL_ERROR ) {
                        $DATA .= "Cannot parse XML output from service.";
                    }
                    else {
                        my $data = find( $doc->getDocumentElement, ".//nmwg:data", 0 );
                        foreach my $d ( $data->get_nodelist ) {
                            $DATA .= escapeString( $d->toString ) . "\n";
                        }
                    }
                }
                else {
                    $DATA = "EventType:\t" . $result->{'eventType'} . "\nResponse:\t" . $result->{"response"};
                }
            }
            else {
                $DATA = "EventType:\t" . $result->{'eventType'} . "\nResponse:\t" . $result->{"response"};
            }
        }

        push @data, { COLLECTION => $e, STORE => $s, METADATA => $METADATA, DATA => $DATA };
    }
}

print $cgi->header();

$template->param(
    INSTANCE => $INSTANCE,
    DATA     => \@data
);

print $template->output;

__END__

=head1 SEE ALSO

L<CGI>, L<HTML::Template>, L<XML::LibXML>, L<CGI::Carp>, L<FindBin>, L<English>,
L<perfSONAR_PS::Client::DCN>, L<perfSONAR_PS::Common>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: view.cgi 3617 2009-08-24 16:52:58Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut
