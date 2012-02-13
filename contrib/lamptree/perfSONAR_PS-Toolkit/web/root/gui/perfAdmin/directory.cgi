#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

directory.cgi - Script that takes a global inventory of the perfSONAR
information space and presents the results.

=head1 DESCRIPTION

Using the gLS infrastructure, locate all available perfSONAR services and
display the results in a tabulated form.  Using links to GUIs, present the
data for the viewer.

=cut

use Template;
use CGI;
use Log::Log4perl qw(get_logger :easy :levels);
use Config::General;
use JSON::XS;

use FindBin qw($RealBin);
my $basedir = "$RealBin/";
use lib "$RealBin/../../../../lib";

use perfSONAR_PS::Utils::GENIPolicy qw( verify_cgi );
use perfSONAR_PS::Topology::ID qw(idRemoveLevel);
use perfSONAR_PS::NPToolkit::Config::RegisteredServices;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

my $CGI      = CGI->new();
verify_cgi( \%conf );

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

$conf{cache_directory} = "/var/lib/perfsonar/ls_cache" unless ( $conf{cache_directory} );
$conf{cache_directory} = $basedir . "/" . $conf{cache_directory} unless ( $conf{cache_directory} =~ /^\// );

if ( $conf{logger_conf} ) {
    unless ( $conf{logger_conf} =~ /^\// ) {
        $conf{logger_conf} = $basedir . "/etc/" . $conf{logger_conf};
    }

    Log::Log4perl->init( $conf{logger_conf} );
}
else {

    # If they've not specified a logger, send it all to /dev/null
    Log::Log4perl->easy_init( { level => $DEBUG, file => "/dev/null" } );
}

our $logger = get_logger( "perfSONAR_PS::WebGUI::Directory" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $domain_id = idRemoveLevel( $conf{node_id} );

my $registered_services = perfSONAR_PS::NPToolkit::Config::RegisteredServices->new();
$registered_services->init( { unis_instance => $conf{unis_instance}, domain_id => $domain_id } );

my $function = $CGI->param("fname");
unless ( $function ) {
    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
    
    my $html;
    
    my %vars = (
        modification_time   => $registered_services->last_modified(),
        anchortypes         => $registered_services->get_anchors(),
        daemons             => $registered_services->get_daemons(),
        services            => $registered_services->get_services(),
        nodes               => $registered_services->get_nodes(),
    );
    
    $tt->process( "directory.tmpl", \%vars, \$html ) or die $tt->error();
    
    print $CGI->header();
    print $html;

} 
elsif ($function eq "pull_registered") {
    my $res = $registered_services->pull_registered();
    if ( $res != 0 ) {
        my %resp = ( error => "Couldn't pull registered services." );
        print "Content-type: text/json\n\n";
        print encode_json(\%resp);
        return;
    }

    my %resp = (
        last_pull_date     => $registered_services->last_modified(),
    );
    
    print "Content-type: text/json\n\n";
    print encode_json(\%resp);
}
else {
    die("Unknown function: $function");
}

exit 0;

__END__

=head1 SEE ALSO

L<HTML::Template>, L<CGI>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: directory.cgi 2948 2009-07-14 14:08:43Z zurawski $

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
