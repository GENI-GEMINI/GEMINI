#!/usr/bin/perl -w

use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use CGI::Ajax;
use CGI::Session;
use Template;
use Data::Dumper;
use Config::General;
use Log::Log4perl qw(get_logger :easy :levels);
use Net::IP;
use Params::Validate;
use Storable qw(store retrieve freeze thaw dclone);
use Date::Parse;
use Time::Local;

use FindBin qw($RealBin);

my $basedir = "$RealBin/";

use lib "$RealBin/../../../../lib";
use lib "/usr/local/perfSONAR-PS/perfSONAR_PS-PingER/lib";

use perfSONAR_PS::Utils::GENIPolicy qw( verify_cgi );
use perfSONAR_PS::Utils::DNS qw( reverse_dns resolve_address reverse_dns_multi resolve_address_multi );
use perfSONAR_PS::Client::gLS::Keywords;
use perfSONAR_PS::Client::Parallel::gLS;
use perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;
use perfSONAR_PS::NPToolkit::Config::RegularTesting;
use perfSONAR_PS::NPToolkit::Config::pSConfig;
use perfSONAR_PS::NPToolkit::Config::ExternalAddress;
use perfSONAR_PS::Common qw(find findvalue extract genuid);

use Data::Validate::IP qw(is_ipv4);
use Data::Validate::Domain qw(is_hostname);
use Net::IPv6Addr;

my $config_file = $basedir . '/etc/web_admin.conf';
my $conf_obj = Config::General->new( -ConfigFile => $config_file );
our %conf = $conf_obj->getall;

our %default_ports = ( pinger => undef, owamp => 861, bwctl => 4823 );

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

our $logger = get_logger( "perfSONAR_PS::WebAdmin::RegularTesting" );
if ( $conf{debug} ) {
    $logger->level( $DEBUG );
}

$logger->info( "templates dir: $conf{template_directory}" );

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

our ( $testing_conf, $lookup_info, $status_msg, $error_msg, $current_test, $dns_cache, $is_modified, $initial_state_time );
if ( $session and not $session->is_expired and $session->param( "testing_conf" ) ) {
    $testing_conf = perfSONAR_PS::NPToolkit::Config::RegularTesting->new( { saved_state => $session->param( "testing_conf" ) } );
    $lookup_info  = thaw( $session->param( "lookup_info" ) );
    $dns_cache    = thaw( $session->param( "dns_cache" ) );
    $current_test = $session->param( "current_test" );
    $is_modified  = $session->param( "is_modified" );
    $initial_state_time = $session->param( "initial_state_time" );
}
else {
    my ($status, $res) = reset_state();
    if ($status != 0) {
        $error_msg = $res;
    }

    save_state();
}

my $psconf = perfSONAR_PS::NPToolkit::Config::pSConfig->new();
$psconf->init( { unis_instance => $conf{unis_instance} } );

if ($testing_conf->last_modified() > $initial_state_time) {
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

    'show_test' => \&show_test,
    'update_owamp_test_port_range' => \&update_owamp_test_port_range,

    'add_pinger_test'    => \&add_pinger_test,
    'update_pinger_test' => \&update_pinger_test,

    'add_owamp_test'    => \&add_owamp_test,
    'update_owamp_test' => \&update_owamp_test,

    'add_bwctl_throughput_test'    => \&add_bwctl_throughput_test,
    'update_bwctl_throughput_test' => \&update_bwctl_throughput_test,

    'add_member_to_test'      => \&add_member_to_test,
    'remove_member_from_test' => \&remove_member_from_test,

    'delete_test' => \&delete_test,

    'lookup_servers' => \&lookup_servers,
);

my ( $header, $footer );
my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or die( "Couldn't initialize template toolkit" );

my %full_page_vars = ();

fill_variables( \%full_page_vars );

$logger->debug( "Using variables: " . Dumper( \%full_page_vars ) );

my $html;

$tt->process( "full_page.tmpl", \%full_page_vars, \$html ) or die $tt->error();

print $ajax->build_html( $cgi, $html, { '-Expires' => '1d' } );

exit 0;

sub save_config {
    my ( $node_id ) = $cgi->param("args");
    
    if ( defined $node_id and $node_id ) {
        $psconf->enable_service( { node_id => $node_id, type => "regular_testing" } );
        
        my $regtest = $psconf->lookup_service( { node_id => $node_id, type => "regular_testing" } );
        
        $regtest->{CONFIGURATION}->set_tests( { tests => $testing_conf->{TESTS} } );
        $regtest->{CONFIGURATION}->set_local_port_ranges( { local_port_ranges => $testing_conf->{LOCAL_PORT_RANGES} } );
        
        $psconf->save( { set_modified => 1 } );
    }
    
    reset_state();
    save_state();
    
    $status_msg = "Configuration Saved.";
    return display_body();
}

sub reset_config {
    my ( $status, $res );

    ( $status, $res ) = reset_state();
    if ( $status != 0 ) {
        $error_msg = $res;
        return display_body();
    }

    save_state();

    $status_msg = "Configuration Reset";
    return display_body();
}

sub reset_state {
    my ( $status, $res );

    $lookup_info = undef;
    $dns_cache   = {};
    
    my ( $node_id ) = $cgi->param("args");
    my $service = undef;
    if ( defined $node_id and $node_id ) {
        $service = $psconf->lookup_service( { node_id => $node_id, type => "regular_testing" } );
    }
    
    $testing_conf = perfSONAR_PS::NPToolkit::Config::RegularTesting->new();
    if ( defined $service ) {
        ( $status, $res ) = $testing_conf->init( { 
                perfsonarbuoy_conf_template => $conf{perfsonarbuoy_conf_template}, 
                perfsonarbuoy_conf_file     => $conf{perfsonarbuoy_conf_file},
                pinger_landmarks_file       => $conf{pinger_landmarks_file},
                local_port_ranges           => $service->{CONFIGURATION}->get_local_port_ranges(),
                tests                       => $service->{CONFIGURATION}->get_tests(),
            } );
    }
    else {
        ( $status, $res ) = $testing_conf->init( { perfsonarbuoy_conf_template => $conf{perfsonarbuoy_conf_template}, perfsonarbuoy_conf_file => $conf{perfsonarbuoy_conf_file}, pinger_landmarks_file => $conf{pinger_landmarks_file} } );
        $testing_conf->reset_state( { ignore_local => 1, } );
    }
    
    if ( $status != 0 ) {
        return ( $status, "Problem reading testing configuration: $res" );
    }

    $is_modified = 0;
    $initial_state_time = $testing_conf->last_modified();
    
    return ( 0, "" );
}

sub save_state {
    $session->param( "testing_conf", $testing_conf->save_state() );
    $session->param( "lookup_info",  freeze( $lookup_info ) ) if ( $lookup_info );
    $session->param( "dns_cache",    freeze( $dns_cache ) );
    $session->param( "current_test", $current_test );
    $session->param( "is_modified",   $is_modified );
    $session->param( "initial_state_time", $initial_state_time );
}

sub fill_variables {
    my ( $vars ) = @_;

    fill_variables_tests( $vars );
    fill_variables_keywords( $vars );
    fill_variables_hosts( $vars );
    fill_variables_status( $vars );
    
    $vars->{nodes} = {};
    my $nodes = $psconf->get_config_nodes();
    foreach my $node_id ( keys %{ $nodes } ) {
        $vars->{nodes}->{$node_id}->{name} = $nodes->{$node_id}->{name};
    }
    
    my ( $node_id ) = $cgi->param("args");
    $vars->{nodes}->{$node_id}->{selected} = 1 if $node_id; 
    
    $vars->{is_modified}    = $is_modified;
    $vars->{error_message}  = $error_msg;
    $vars->{status_message} = $status_msg;
    $vars->{self_url}       = $cgi->self_url();
    $vars->{session_id}     = $session->id();

    return 0;
}

sub fill_variables_tests {
    my ( $vars ) = @_;

    my ( $status, $res ) = $testing_conf->get_tests();

    my $tests;
    if ( $status == 0 ) {
        $tests = $res;
    }
    else {
        my @tests = ();
        $tests = \@tests;
    }

    my @sorted_tests = sort { $a->{id} cmp $b->{id} } @$tests;
    $tests = \@sorted_tests;

    $vars->{tests} = $tests;

    if ( $current_test ) {
        my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $current_test } );

        unless ( $status == 0 ) {
            $logger->info( "Failed to lookup test " . $current_test ) unless ( $status == 0 );
        }
        else {
            $vars->{current_test} = $res;
        }
    }

    return 0;
}

sub fill_variables_status {
    my ( $vars ) = @_;

    my ($status, $res);

    my ( $psb_owamp_enabled, $psb_bwctl_enabled, $psb_ma_enabled, $pinger_enabled ) = ( 0, 0, 0, 0 );
    
    my ( $node_id ) = $cgi->param("args"); 
    
    if ( $node_id ) {
        my $service_info;

        $service_info = $psconf->lookup_service( { node_id => $node_id, type => "pinger" } );
        if ( $service_info and $service_info->{enabled} ) {
            $pinger_enabled = 1;
        }

        $service_info = $psconf->lookup_service( { node_id => $node_id, type => "perfsonarbuoy_bwctl" } );
        if ( $service_info and $service_info->{enabled} ) {
            $psb_bwctl_enabled = 1;
        }

        $service_info = $psconf->lookup_service( { node_id => $node_id, type => "perfsonarbuoy_owamp" } );
        if ( $service_info and $service_info->{enabled} ) {
            $psb_owamp_enabled = 1;
        }

        $service_info = $psconf->lookup_service( { node_id => $node_id, type => "perfsonarbuoy_ma" } );
        if ( $service_info and $service_info->{enabled} ) {
            $psb_ma_enabled = 1;
        }
    }

    # Calculate whether or not they have a "good" configuration
    ( $status, $res ) = $testing_conf->get_tests();

    my $psb_throughput_tests = 0;
    my $pinger_tests         = 0;
    my $psb_owamp_tests      = 0;
    my $network_usage        = 0;
    my $owamp_port_usage     = 0;

    if ( $status == 0 ) {
        my $tests = $res;
        foreach my $test ( @{$tests} ) {
            if ( $test->{type} eq "bwctl/throughput" ) {
                $psb_throughput_tests++;
            }
            elsif ( $test->{type} eq "pinger" ) {
                $pinger_tests++;
            }
            elsif ( $test->{type} eq "owamp" ) {
                $psb_owamp_tests++;
            }

            if ( $test->{type} eq "owamp" ) {
                foreach my $member ( @{ $test->{members} } ) {
                    if ( $member->{sender} ) {
                        $owamp_port_usage += 2;
                    }
                    if ( $member->{receiver} ) {
                        $owamp_port_usage += 2;
                    }
                }
            }

            if ( $test->{type} eq "bwctl/throughput" ) {
                my $test_duration = $test->{parameters}->{duration};
                my $test_interval = $test->{parameters}->{test_interval};

                my $num_tests = 0;
                foreach my $member ( @{ $test->{members} } ) {
                    if ( $member->{sender} ) {
                        $num_tests++;
                    }
                    if ( $member->{receiver} ) {
                        $num_tests++;
                    }
                }

                # Add 15 seconds onto the duration to account for synchronization issues
                $test_duration += 15;

                $network_usage += ( $num_tests * $test_duration ) / $test_interval if ($test_interval > 0);
            }
        }
    }

    my %owamp_ports = ();

    ($status, $res) = $testing_conf->get_local_port_range({ test_type => "owamp" });
    if ($status == 0) {
        if ($res) {
            $owamp_ports{min_port} = $res->{min_port};
            $owamp_ports{max_port} = $res->{max_port};
        }
    }

    my $owamp_port_range;

    if (defined $owamp_ports{min_port} and defined $owamp_ports{max_port}) {
        $owamp_port_range = $owamp_ports{max_port} - $owamp_ports{min_port} + 1;
    }

    $vars->{network_percent_used} = sprintf "%.1d", $network_usage * 100;
    $vars->{owamp_ports}          = \%owamp_ports;
    $vars->{owamp_port_range}     = $owamp_port_range;
    $vars->{owamp_port_usage}     = $owamp_port_usage;
    $vars->{owamp_tests}          = $psb_owamp_tests;
    $vars->{pinger_tests}         = $pinger_tests;
    $vars->{throughput_tests}     = $psb_throughput_tests;
    $vars->{psb_bwctl_enabled}    = $psb_bwctl_enabled;
    $vars->{psb_ma_enabled}       = $psb_ma_enabled;
    $vars->{psb_owamp_enabled}    = $psb_owamp_enabled;
    $vars->{pinger_enabled}       = $pinger_enabled;

    return 0;
}

#
# GFR: Changed for LAMP.
#   We just use the list of nodes we got from UNIS. Basically we consider
#   that the names are resolvable, since this is the only way of making the
#   tests go within the virtual topology (rather than through the control plane).
#   We could also parse the addresses from the topo information, but we wouldn't
#   know what is virtual and what isn't, because some sites might have private
#   address spaces on the control/measurement planes.
#   TODO: I think the long term solution is to make test members based on port's UNIS id.
#
sub fill_variables_hosts {
    my ( $vars ) = @_;

    my @display_hosts = ();

    my %used_addresses = ();

    $logger->info( "display_found_hosts()" );

    return 0 unless ( $current_test );
    
    my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $current_test } );
    unless ( $status == 0 ) {
        $error_msg = "Invalid test";
        return;
    }
    
    my $test = $res;
    
    my @hosts = ();
    my $nodes = $psconf->get_nodes();
    foreach my $node_id ( keys %{ $nodes } ) {
        my $node = $nodes->{ $node_id };
        my %service_info = ();
        $service_info{"description"} = "";
        $service_info{"address"}     = { address => $node->{name}, dns_name => $node->{name}, ip => undef, port => $default_ports{ $test->{type} } };
        push @hosts, \%service_info;
    }

    $vars->{hosts}      = \@hosts;
    $vars->{check_time} = timelocal( strptime( $psconf->last_pull(), "%Y-%m-%d %H:%M:%S" ) );

    return 0;
}

# GFR: Not used for GENI
sub fill_variables_keywords {
    my ( $vars ) = @_;
    
    $vars->{member_keywords}            = [];
    $vars->{known_keywords}             = [];
    $vars->{known_keywords_check_time}  = undef;

    return 0;
    
    # GFR: Disabled for GENI.
    my $keyword_client = perfSONAR_PS::Client::gLS::Keywords->new( { cache_directory => $conf{cache_directory} } );

    my ($status, $res);

    my @member_keywords          = ();
    my $administrative_info_conf = perfSONAR_PS::NPToolkit::Config::AdministrativeInfo->new();
    $res = $administrative_info_conf->init( {} );
    if ( $res == 0 ) {
        my $keywords = $administrative_info_conf->get_keywords();
        $logger->info( Dumper( $keywords ) );
        foreach my $keyword ( sort @$keywords ) {
            push @member_keywords, $keyword;
        }
    }

    my @other_keywords = ();
    my $other_keywords_age;

    ($status, $res) = $keyword_client->get_keywords();
    if ( $status == 0) {
        $other_keywords_age = $res->{time};

        my $popular_keywords = $res->{keywords};

        my $keywords = $administrative_info_conf->get_keywords();

        foreach my $keyword ( @$keywords ) {
            # Get rid of any used keywords
            $keyword = "project:" . $keyword unless ( $keyword =~ /^project:/ );

            delete( $popular_keywords->{$keyword} ) if ( $popular_keywords->{$keyword} );
        }

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
            push @other_keywords, \%keyword_info;
        }
    }

    $vars->{member_keywords} = \@member_keywords;
    $vars->{known_keywords}  = \@other_keywords;
    $vars->{known_keywords_check_time}  = $other_keywords_age;

    return 0;
}

sub display_body {

    my %vars = ();

    fill_variables( \%vars );

    my $html;

    $logger->info( "Using variables: " . Dumper( \%vars ) );

    my $tt = Template->new( INCLUDE_PATH => $conf{template_directory} ) or return ( "Couldn't initialize template toolkit" );
    $tt->process( "body.tmpl", \%vars, \$html ) or return $tt->error();

    save_state();

    $logger->debug( "Returning: " . $html );

    return $html;
}

sub show_test {
    my ( $node_id, $test_id ) = @_;

    my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $test_id } );
    if ( $status != 0 ) {
        $error_msg = "Error looking up test: $res";
        return display_body();
    }

    $current_test = $test_id;

    save_state();

    return display_body();
}

sub add_bwctl_throughput_test {
    my ($node_id, $description, $duration, $test_interval, $tool, $protocol, $window_size, $udp_bandwidth) = @_;

    # Add the new group
    my ( $status, $res ) = $testing_conf->add_test_bwctl_throughput(
        {
            mesh_type     => "star",
            description   => $description,
            tool          => $tool,
            protocol      => $protocol,
            test_interval => $test_interval,
            duration      => $duration,
            window_size   => $window_size,
            udp_bandwidth => $udp_bandwidth,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $is_modified = 1;

    $current_test = $res;

    save_state();

    $status_msg = "Test ".$description." Added";
    return display_body();
}

sub update_owamp_test_port_range {
    my ($node_id, $min_port, $max_port) = @_;

    my ($status, $res);

    if ($min_port eq "NaN" or $max_port eq "NaN") {
        ( $status, $res ) = $testing_conf->reset_local_port_range({ test_type => "owamp" });
    } else {
        ( $status, $res ) = $testing_conf->set_local_port_range( { test_type => "owamp", min_port => $min_port, max_port => $max_port } );
    }

    if ( $status != 0 ) {
        $error_msg = "Port range update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    return display_body();
}

sub update_bwctl_throughput_test {
    my ($node_id, $id, $description, $duration, $test_interval, $tool, $protocol, $window_size, $udp_bandwidth) = @_;

    my ( $status, $res );

    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, description => $description } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, test_interval => $test_interval } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, tool => $tool } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, duration => $duration } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, protocol => $protocol } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, udp_bandwidth => $udp_bandwidth } );
    ( $status, $res ) = $testing_conf->update_test_bwctl_throughput( { test_id => $id, window_size => $window_size } );

    if ( $status != 0 ) {
        $error_msg = "Test update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Test updated";
    return display_body();
}

sub add_owamp_test {
    my ($node_id, $description, $packet_interval, $packet_padding, $session_packets, $sample_packets, $bucket_width, $loss_threshold) = @_;

    my ( $status, $res ) = $testing_conf->add_test_owamp(
        {
            mesh_type        => "star",
            description      => $description,
            packet_interval  => $packet_interval,
            loss_threshold   => $loss_threshold,
            session_count    => $session_packets,
            sample_count     => $sample_packets,
            packet_padding   => $packet_padding,
            bucket_width     => $bucket_width,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $current_test = $res;

    $is_modified = 1;

    save_state();

    $status_msg = "Test ".$description." Added";
    return display_body();
}

sub update_owamp_test {
    my ($node_id, $id, $description, $packet_interval, $packet_padding, $session_packets, $sample_packets, $bucket_width, $loss_threshold) = @_;

    my ( $status, $res );

    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, description => $description } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, packet_interval => $packet_interval } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, packet_padding => $packet_padding } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, bucket_width => $bucket_width } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, loss_threshold => $loss_threshold } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, session_count  => $session_packets } );
    ( $status, $res ) = $testing_conf->update_test_owamp( { test_id => $id, sample_count => $sample_packets } );

    if ( $status != 0 ) {
        $error_msg = "Test update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Test updated";
    return display_body();
}

sub add_pinger_test {
    my ($node_id, $description, $packet_size, $packet_count, $packet_interval, $test_interval, $test_offset, $ttl) = @_;

    my ( $status, $res ) = $testing_conf->add_test_pinger(
        {
            description     => $description,
            packet_size     => $packet_size,
            packet_count    => $packet_count,
            packet_interval => $packet_interval,
            test_interval   => $test_interval,
            test_offset     => $test_offset,
            ttl             => $ttl,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $current_test = $res;

    $is_modified = 1;

    save_state();

    $status_msg = "Test ".$description." Added";
    return display_body();
}

sub update_pinger_test {
    my ($node_id, $id, $description, $packet_size, $packet_count, $packet_interval, $test_interval, $test_offset, $ttl) = @_;

    my ( $status, $res );

    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, description => $description } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, packet_interval => $packet_interval } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, packet_count => $packet_count } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, packet_size => $packet_size } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, test_interval => $test_interval } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, test_offset => $test_offset } );
    ( $status, $res ) = $testing_conf->update_test_pinger( { test_id => $id, ttl => $ttl } );

    if ( $status != 0 ) {
        $error_msg = "Test update failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Test updated";
    return display_body();
}

sub add_member_to_test {
    my ($node_id, $test_id, $address, $port, $description ) = @_;

    my $hostname;

    if ( is_ipv4( $address ) ) {
        $hostname = reverse_dns( $address );
    }
    elsif ( &Net::IPv6Addr::is_ipv6( $address ) ) {
        $hostname = reverse_dns( $address );
    }
    elsif ( is_hostname( $address ) ) {
        $hostname = $address;
    }
    else {
        $error_msg = "Can't parse the specified address";
        return display_body();
    }

    my $new_description = $description;

    $new_description = $hostname if ( not $description and $hostname );
    $new_description = $address  if ( not $description and $address );

    $logger->debug( "Adding address: $address Port: $port Description: $description" );

    my ( $status, $res ) = $testing_conf->add_test_member(
        {
            test_id     => $test_id,
            address     => $address,
            port        => $port,
            description => $description,
            sender      => 1,
            receiver    => 1,
        }
    );

    if ( $status != 0 ) {
        $error_msg = "Failed to add test: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Host Added To Test";
    return display_body();
}

sub remove_member_from_test {
    my ($node_id, $test_id, $member_id ) = @_;

    my ( $status, $res ) = $testing_conf->remove_test_member( { test_id => $test_id, member_id => $member_id } );
    if ( $status != 0 ) {
        $error_msg = "Host removal failed: $res";
        return display_body();
    }

    $is_modified = 1;

    save_state();

    $status_msg = "Host removed from test";
    return display_body();
}

sub delete_test {
    my ($node_id, $test_id ) = @_;

    $testing_conf->delete_test( { test_id => $test_id } );

    $is_modified = 1;

    save_state();

    $status_msg = "Test deleted";
    return display_body();
}

sub lookup_servers {
    my ($node_id, $test_id, $keyword ) = @_;

    my ( $status, $res ) = $testing_conf->lookup_test( { test_id => $test_id } );
    unless ( $status == 0 ) {
        $error_msg = "Invalid test";
        return display_body();
    }
    
    #
    # GFR: Changed for LAMP.
    #   We just use the list of nodes we got from UNIS. Basically we consider
    #   that the names are resolvable, since this is the only way of making the
    #   tests go within the virtual topology (rather than through the control plane).
    #   We could also parse the addresses from the topo information, but we wouldn't
    #   know what is virtual and what isn't, because some sites might have private
    #   address spaces on the control/measurement planes.
    #   TODO: I think the long term solution is to make test members based on port id.
    #
    my $test = $res;
    
    my @hosts = ();
    foreach my $node ( $psconf->get_nodes() ) {
        my %service_info = ();
        $service_info{"name"}        = $node->{name};
        $service_info{"description"} = "";
        $service_info{"dns_names"}   = [ $node->{name} ];
        $service_info{"addresses"}   = [ { address => $node->{name}, dns_name => $node->{name}, ip => undef, port => undef } ];
        push @hosts, \%service_info;
    }

    my %lookup_info = ();
    $lookup_info{hosts}   = \@hosts;
    $lookup_info->{$test_id} = \%lookup_info;

    save_state();

    $status_msg = "";
    return display_body();
    
    if ($conf{"use_cache"}) {
        ($status, $res) = lookup_servers_cache($test->{type}, $keyword);
    } else {
        ($status, $res) = lookup_servers_gls($test->{type}, $keyword);
    }

    if ($status != 0) {
        $error_msg = $res;
        return display_body();
    }

    my @addresses = ();

    foreach my $service (@{ $res->{hosts} }) {
        foreach my $full_addr (@{ $service->{addresses} }) {
            my $addr;

            if ( $full_addr =~ /^(tcp|http):\/\/\[[^\]]*\]/ ) {
                $addr = $2;
            }
            elsif ( $full_addr =~ /^(tcp|http):\/\/([^\/:]*)/ ) {
                $addr = $2;
            }
            else {
                $addr = $full_addr;
            }

            push @addresses, $addr;
        }
    }

    lookup_addresses(\@addresses, $dns_cache);

    @hosts = ();

    foreach my $service (@{ $res->{hosts} }) {
        my @addrs = ();
        my @dns_names = ();
        foreach my $contact (@{ $service->{addresses} }) {

            my ( $addr, $port );
            if ( $test->{type} eq "pinger" ) {
                $addr = $contact;
            }
            else {
                # The addresses here are tcp://ip:port or tcp://[ip]:[port] or similar
                if ( $contact =~ /^tcp:\/\/[(.*)]:(\d+)$/ ) {
                    $addr = $1;
                    $port = $2;
                }
                elsif ( $contact =~ /^tcp:\/\/[(.*)]$/ ) {
                    $addr = $1;
                }
                elsif ( $contact =~ /^tcp:\/\/(.*):(\d+)$/ ) {
                    $addr = $1;
                    $port = $2;
                }
                elsif ( $contact =~ /^tcp:\/\/(.*)$/ ) {
                    $addr = $1;
                }
                else {
                    $addr = $contact;
                }
            }

            my $cached_dns_info = $dns_cache->{$addr};
            my ($dns_name, $ip);

            $logger->info("Address: ".$addr);

            if (is_ipv4($addr) or &Net::IPv6Addr::is_ipv6( $addr ) ) {
                if ( $cached_dns_info ) {
                    foreach my $dns_name (@$cached_dns_info) {
                        push @dns_names, $dns_name;
                    }
                    $dns_name = $cached_dns_info->[0];
                }

                $ip = $addr;
            } else {
                push @dns_names, $addr;
                $dns_name = $addr;
                if ( $cached_dns_info ) {
                    $ip = $cached_dns_info->[0];
                }
            }

            $logger->info("Address(Cache): ".Dumper($dns_cache));
            $logger->info("Address(post-lookup): ".$addr);

            # XXX improve this

            next if $addr =~ m/^10\./;
            next if $addr =~ m/^192\.168\./;
            next if $addr =~ m/^172\.16/;

            push @addrs, { address => $addr, dns_name => $dns_name, ip => $ip, port => $port };
        }

        my %service_info = ();
        $service_info{"name"} = $service->{name};
        $service_info{"description"} = $service->{description};
        $service_info{"dns_names"}   = \@dns_names;
        $service_info{"addresses"}   = \@addrs;

        push @hosts, \%service_info;
    }

    %lookup_info = ();
    $lookup_info{hosts}   = \@hosts;
    $lookup_info{keyword} = $keyword;
    $lookup_info{check_time} = $res->{check_time};

    $lookup_info->{$test_id} = \%lookup_info;

    save_state();

    $status_msg = "";
    return display_body();
}

sub lookup_servers_gls {
    my ( $service_type, $keyword ) = @_;

    my @hosts = ();

    my $gls = perfSONAR_PS::Client::Parallel::gLS->new( {} );

    my $parser = XML::LibXML->new();

    $logger->debug( "lookup_servers_gls($service_type, $keyword)" );

    unless ( $gls->{ROOTS} ) {
        $logger->info( "No gLS Roots found!" );
        $error_msg = "Error looking up hosts";
        return display_body();
    }

    my @eventTypes = ();
    if ( $service_type eq "pinger" ) {
        push @eventTypes, "http://ggf.org/ns/nmwg/tools/ping/1.0";
    }
    elsif ( $service_type eq "bwctl/throughput" ) {
        push @eventTypes, "http://ggf.org/ns/nmwg/tools/bwctl/1.0";
    }
    elsif ( $service_type eq "owamp" ) {
        push @eventTypes, "http://ggf.org/ns/nmwg/tools/owamp/1.0";
    }
    else {
        $error_msg = "Unknown server type specified";
        return (-1, $error_msg);
    }

    my @keywords = ( "project:" . $keyword );

    my $result;
    my $start_time = time;
    $result = $gls->getLSLocation( { eventTypes => \@eventTypes, keywords => \@keywords } );
    my $end_time = time;

    unless ( $result ) {
        $lookup_info = undef;
        $error_msg   = "Problem looking up hosts";
        return (-1, $error_msg);
    }

    foreach my $s ( @{$result} ) {
        my $doc = $parser->parse_string( $s );

        my $res;

        my $name = findvalue( $doc->getDocumentElement, ".//*[local-name()='name']", 0 );
        my $description = findvalue( $doc->getDocumentElement, ".//*[local-name()='description']", 0 );

        my @addrs = ();
        $res = find( $doc->getDocumentElement, ".//*[local-name()='address']", 0 );
        foreach my $c ( $res->get_nodelist ) {
            my $contact = extract( $c, 0 );

            $logger->info( "Adding $contact to address list" );

            push @addrs, $contact;
        }

        my %service_info = ();
        $service_info{"name"} = $name;
        $service_info{"description"} = $description;
        $service_info{"addresses"}   = \@addrs;

        push @hosts, \%service_info;
    }

    return (0, { hosts => \@hosts, check_time => time });
}

sub lookup_servers_cache {
    my ( $service_type, $keyword ) = @_;

    $logger->debug("lookup_servers_cache()");

    my $service_cache_file;
    if ( $service_type eq "pinger" ) {
        $service_cache_file = "list.ping";
    }
    elsif ( $service_type eq "bwctl/throughput" ) {
        $service_cache_file = "list.bwctl";
    }
    elsif ( $service_type eq "owamp" ) {
        $service_cache_file = "list.owamp";
    }
    else {
        $error_msg = "Unknown server type specified";
        return (-1, $error_msg);
    }

    my $project_keyword = "project:" . $keyword;

    # Find out which hLSes contain services with the keywords we want (this is,
    # i think, the best we can do with the cache, if a service is in an hLS and
    # that hLS has a certain set of keywords in it, we assume that service has
    # that set of keywords).
    my %hlses = ();

    open(HLS_CACHE_FILE, "<", $conf{cache_directory}."/list.hls") or $logger->debug("Couldn't open ".$conf{cache_directory}."/list.hls");
    while(<HLS_CACHE_FILE>) {
        chomp;

        my ($url, $name, $type, $description, $keywords) = split(/\|/, $_);

        next unless ($keywords);

        #$logger->debug("Found hLS $url/$name/$type/$description/$keywords");
        foreach my $curr_keyword (split(/,/, $keywords)) {
            #$logger->debug("hLS $url has keyword $curr_keyword($project_keyword)");
            if ($curr_keyword eq $project_keyword) {
                #$logger->debug("hLS $url has keyword $keyword. Adding to hlses hash");
                $hlses{$url} = 1;
            }
        }
    }
    close(HLS_CACHE_FILE);

    # Find out which services are contained in the hLSes found above.
    my %services = ();

    open(HLS_MAP_FILE, "<", $conf{cache_directory}."/list.hlsmap");
    while(<HLS_MAP_FILE>) {
        chomp;

        my ($url, $hosts) = split(/\|/, $_);

        #$logger->debug("Checking hLS $url which has hosts '$hosts'");
        next unless $hlses{$url};
        #$logger->debug("hLS $url was found");

        foreach my $curr_addr (split(',', $hosts)) {
            #$logger->debug("hLS $url has service $curr_addr");
            $services{$curr_addr} = 1;
        }
    }
    close(HLS_MAP_FILE);

    # Find out which services are in hLSes that contain the keyword we're
    # looking for.
    my @hosts = ();

    open(SERVICE_FILE, "<", $conf{cache_directory}."/".$service_cache_file);
    while(<SERVICE_FILE>) {
        chomp;

        my ($url, $name, $type, $description) = split(/\|/, $_);

        #$logger->debug("Found service $url");

        next unless $services{$url};

        #$logger->debug("service $url is in the set to return");

        push @hosts, { addresses => [ $url ], name => $name, description => $description };
    }
    close(HLS_MAP_FILE);

    my ( $mtime ) = ( stat( $conf{cache_directory}."/".$service_cache_file ) )[9];

    return (0, { hosts => \@hosts, check_time => $mtime });
}

sub lookup_addresses {
    my ($addresses, $dns_cache) = @_;

    my %addresses_to_lookup = ();
    my %hostnames_to_lookup = ();

    foreach my $addr (@{ $addresses }) {
            next if ($dns_cache->{$addr});

            if (is_ipv4($addr) or &Net::IPv6Addr::is_ipv6( $addr ) ) {
                $logger->debug("$addr is an IP");
                $addresses_to_lookup{$addr} = 1;
            } elsif (is_hostname($addr)) {
                $hostnames_to_lookup{$addr} = 1;
                $logger->debug("$addr is a hostname");
            } else {
                $logger->debug("$addr is unknown");
            }
    }

    my @addresses_to_lookup = keys %addresses_to_lookup;
    my @hostnames_to_lookup = keys %hostnames_to_lookup;

    my $resolved_hostnames = resolve_address_multi({ addresses => \@hostnames_to_lookup, timeout => 2 });
    foreach my $hostname (keys %{ $resolved_hostnames }) {
        $dns_cache->{$hostname} = $resolved_hostnames->{$hostname};
    }

    my $resolved_addresses = reverse_dns_multi({ addresses => \@addresses_to_lookup, timeout => 2 });

    foreach my $ip (keys %{ $resolved_addresses }) {
        $dns_cache->{$ip} = $resolved_addresses->{$ip};
    }

    return;
}


1;

# vim: expandtab shiftwidth=4 tabstop=4
