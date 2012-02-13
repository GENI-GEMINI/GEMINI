#!/usr/bin/perl -w

use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Ajax;
use CGI::Session;
use Template;
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);
use Net::IP;
use Params::Validate;
use Data::Dumper;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";

use perfSONAR_PS::Utils::GENIPolicy qw( verify_cgi );
use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;
use perfSONAR_PS::Client::gLS::Keywords;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

$conf{sessions_directory} = "/tmp" unless ( $conf{sessions_directory} );
$conf{sessions_directory} = $basedir . "/" . $conf{sessions_directory} unless ( $conf{sessions_directory} =~ /^\// );

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

our $logger = get_logger( "perfSONAR_PS::WebAdmin::AdministrativeInfo" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

my $cgi = CGI->new();
verify_cgi( \%conf );

our $session;

if ( $cgi->param( "session_id" ) ) {
    $session = CGI::Session->new( "driver:File;serializer:Storable", $cgi->param( "session_id" ), { Directory => $conf{sessions_directory} } );
}
else {
    $session = CGI::Session->new( "driver:File;serializer:Storable", $cgi, { Directory => $conf{sessions_directory} } );
}

die( "Couldn't instantiate session: " . CGI::Session->errstr() ) unless ( $session );

our ( $administrative_info_conf, $status_msg, $error_msg, $is_modified, $initial_state_time );
if ( $session and not $session->is_expired and $session->param( "administrative_info_conf" ) ) {
    $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new( { saved_state => $session->param( "administrative_info_conf" ) } );
    $is_modified   = $session->param( "is_modified" );
    $initial_state_time = $session->param( "initial_state_time" );
    $logger->debug( "Restoring administrative_info_conf object" );
}
else {
    $logger->debug( "Reverting administrative_info_conf object" );
    reset_state();
    save_state();
}

if ($administrative_info_conf->last_modified() > $initial_state_time) {
	reset_state();
	save_state();
	$status_msg = "The on-disk configuration has changed. Any changes you made have been lost.";

	my $html = display_body();

	print "Content-Type: text/html\n\n";
	print $html;
	exit 0;
}

my $ajax = CGI::Ajax->new(
    'save_config'  => \&save_config,
    'reset_config' => \&reset_config,

    'set_host_information'   => \&set_host_information,

    'add_keyword'    => \&add_keyword,
    'delete_keyword' => \&delete_keyword,
);

my ( $header, $footer );
my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my %vars = ();

$vars{self_url}   = $cgi->self_url();
$vars{session_id} = $session->id();

fill_variables( \%vars );

my $html;

$tt->process( "full_page.tmpl", \%vars, \$html ) or die $tt->error();

print $ajax->build_html( $cgi, $html, { '-Expires' => '1d' } );

sub display_body {
    my %vars = ();

    fill_variables( \%vars );

    my $html;

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );
    $tt->process( "body.tmpl", \%vars, \$html ) or die $tt->error();

    return $html;
}

sub fill_variables {
    my ( $vars ) = @_;

    my @vars_keywords = ();
    my $known_keywords_age;

    my $keyword_client = perfSONAR_PS::Client::gLS::Keywords->new( { cache_directory => $conf{cache_directory} } );

    my ($status, $res) = $keyword_client->get_keywords();
    if ( $status == 0) {
    	$logger->debug("Got keywords: ".Dumper($res));

        $known_keywords_age = "$res->{time}";

        my $popular_keywords = $res->{keywords};

        my $keywords = $administrative_info_conf->get_keywords();

        foreach my $keyword ( @$keywords ) {

            # Get rid of any used keywords
            $keyword = "project:" . $keyword unless ( $keyword =~ /^project:/ );

            delete( $popular_keywords->{$keyword} ) if ( $popular_keywords->{$keyword} );
        }
        $logger->debug( Dumper( $popular_keywords ) );

        my @frequencies = sort { $popular_keywords->{$b} <=> $popular_keywords->{$a} } keys %$popular_keywords;

        my $max = $popular_keywords->{ $frequencies[0] };
        my $min = $popular_keywords->{ $frequencies[$#frequencies] };

        foreach my $keyword ( sort keys %$popular_keywords ) {
            next unless ( $keyword =~ /^project:/ );

            my $class;

            if ( $max == $min ) {
                $class = 1;
            }
            else {

                # 10 steps maximum
                $class = 1 + int( 9 * ( $popular_keywords->{$keyword} - $min ) / ( $max - $min ) );
            }

            my $display_keyword = $keyword;
            $display_keyword =~ s/^project://g;

            my %keyword_info = ();
            $keyword_info{keyword} = $display_keyword;
            $keyword_info{class}   = $class;
            push @vars_keywords, \%keyword_info;
        }
    }
    $vars->{known_keywords} = \@vars_keywords;
    $vars->{known_keywords_check_time} = $known_keywords_age;

    $vars->{organization_name}   = $administrative_info_conf->get_organization_name();
    $vars->{administrator_name}  = $administrative_info_conf->get_administrator_name();
    $vars->{administrator_email} = $administrative_info_conf->get_administrator_email();
    $vars->{location}            = $administrative_info_conf->get_location();
    my $keywords         = $administrative_info_conf->get_keywords();
    my @display_keywords = ();
    if ( $keywords ) {
        foreach my $keyword ( sort @{$keywords} ) {
            push @display_keywords, $keyword;
        }
    }
    $vars->{is_modified}         = $is_modified;
    $vars->{configured_keywords} = \@display_keywords;
    $vars->{status_message}      = $status_msg;
    $vars->{error_message}       = $error_msg;

    $logger->debug("Variables: ".Dumper(\%vars));

    return 0;
}

sub set_host_information  {
    my ( $organization_name, $host_location, $administrator_name, $administrator_email ) = @_;

    $administrative_info_conf->set_organization_name( { organization_name => $organization_name } );
    $administrative_info_conf->set_location( { location => $host_location } );
    $administrative_info_conf->set_administrator_name( { administrator_name => $administrator_name } );
    $administrative_info_conf->set_administrator_email( { administrator_email => $administrator_email } );

    $is_modified = 1;

    save_state();

    $status_msg = "Host information updated";
    return display_body();
}

sub add_keyword {
    my ( $value ) = @_;
    $administrative_info_conf->add_keyword( { keyword => $value } );
    $is_modified = 1;

    save_state();

    $status_msg = "Keyword $value added";
    return display_body();
}

sub delete_keyword {
    my ( $value ) = @_;
    $administrative_info_conf->delete_keyword( { keyword => $value } );

    $is_modified = 1;
    save_state();

    $status_msg = "Keyword $value deleted";
    return display_body();
}

sub save_config {
    my ($status, $res) = $administrative_info_conf->save( { restart_services => 1 } );
    if ($status != 0) {
	$error_msg = "Problem saving configuration: $res";
    } else {
        $status_msg = "Configuration Saved And Services Restarted";
	$is_modified = 0;
	$initial_state_time = $administrative_info_conf->last_modified();
    }
    save_state();

    return display_body();
}

sub reset_config {
    reset_state();
    save_state();
    $status_msg = "Configuration Reset";
    return display_body();
}

sub reset_state {
    $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
    my $res = $administrative_info_conf->init( { administrative_info_file => $conf{administrative_info_file} } );
    if ( $res != 0 ) {
        die( "Couldn't initialize Administrative Info Configuration" );
    }
    $is_modified = 0;
    $initial_state_time = $administrative_info_conf->last_modified();
}

sub save_state {
    my $state = $administrative_info_conf->save_state();
    $session->param( "administrative_info_conf", $state );
    $session->param( "is_modified", $is_modified );
    $session->param( "initial_state_time", $initial_state_time );
}

1;
