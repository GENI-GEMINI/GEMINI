#!/usr/bin/perl

use strict;
use warnings;
use CGI;
use CGI::Ajax;
use Log::Log4perl qw(get_logger :easy :levels);
use Template;
use POSIX;
use Config::General;
use JSON::XS;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::Utils::GENIPolicy qw( verify_cgi );
use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;
use perfSONAR_PS::NPToolkit::Config::pSConfig;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{template_directory} = "templates" unless ( $conf{template_directory} );
$conf{template_directory} = $basedir . "/" . $conf{template_directory} unless ( $conf{template_directory} =~ /^\// );

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

our $logger = get_logger( "perfSONAR_PS::WebGUI::ServiceStatus" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $psconf = perfSONAR_PS::NPToolkit::Config::pSConfig->new();
$psconf->init( { unis_instance => $conf{unis_instance} } );

my $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
$administrative_info_conf->init( { administrative_info_file => $conf{administrative_info_file} } );

my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my $html;

my %vars = ();

my $cgi = CGI->new();
verify_cgi( \%conf );

my $function = $cgi->param("fname");
unless ( $function ) {
    $vars{site_name}          = $administrative_info_conf->get_organization_name();
    $vars{site_location}      = $administrative_info_conf->get_location();
    $vars{nodes}              = $psconf->get_config_nodes();
    $vars{last_pull_date}     = $psconf->last_pull();
    $vars{last_modified_date} = $psconf->last_modified();

    unless ( $vars{last_modified_date} ) {
        $vars{last_modified_date} = "never";
    }
    
    $tt->process( "status.tmpl", \%vars, \$html ) or die $tt->error();

    print $cgi->header;
    print $html;
} 
elsif ($function eq "pull") {
    pull_config();
}
elsif ($function eq "push") {
    push_config();
}
else {
    die("Unknown function: $function");
}

sub push_config {
    my ($status, $res) = $psconf->push_configuration();
    if ( $status != 0 ) {
        my %resp = ( error => "Couldn't push Services Configuration: $res" );
        print "Content-type: text/json\n\n";
        print encode_json(\%resp);
        return;
    }

    my %resp = ( 
        message            => "Configuration pushed to UNIS.",
        last_pull_date     => $psconf->last_pull(),
        last_modified_date => "never",
    );
    
    print "Content-type: text/json\n\n";
    print encode_json(\%resp);
}

sub pull_config {
    my $res = $psconf->pull_configuration();
    if ( $res != 0 ) {
        my %resp = ( error => "Couldn't pull Services Configuration." );
        print "Content-type: text/json\n\n";
        print encode_json(\%resp);
        return;
    }

    my %resp = ( 
        message            => "Configuration pulled from UNIS.",
        last_pull_date     => $psconf->last_pull(),
        last_modified_date => "never",
    );
    
    print "Content-type: text/json\n\n";
    print encode_json(\%resp);
}

exit 0;

# vim: expandtab shiftwidth=4 tabstop=4
