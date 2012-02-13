#!/usr/bin/perl -w

use strict;
use warnings;

use CGI;
use CGI::Ajax;
use Config::General qw(ParseConfig SaveConfig);
use Data::Dumper;

=head1 NAME

config.cgi - A series of menus designed to configure a perfSONAR-PS 
Daemon for any number of services.

=head1 DESCRIPTION

This CGI script is designed to be installed on the same host that 
(a) perfSONAR-PS Service(s) will be installed upon.  Following the
button driven interface it is possible to configure 'Global' options
for the daemon that will effect all services, as well as
add/delete/edit the open ports and endpoints that individual
services will need, along with specific configuration options.  This
CGI is modeled after the psConfigureDaemon command line script, and
tries to impart the same bahviour.

N.B. For now this writes to a static file (/tmp/confige/daemon.conf),
because this is hardcoded and also where the CGI user (www-data) has
write permissions.  We need to work around this.

=cut

my $cgi = new CGI();
my $pjx = new CGI::Ajax(
    'exportg'   => \&global,
    'exportg_1' => \&globalResult,
    'export1'   => \&addPort,
    'export1_1' => \&addPortResult,
    'export3'   => \&deletePort,
    'export3_1' => \&deletePortResult,
    'export4'   => \&addService,
    'export4_1' => \&addServiceResult,
    'export5'   => \&editService,
    'export5_1' => \&editServiceResult,
    'export6'   => \&deleteService,
    'export6_1' => \&deleteServiceResult
);
$pjx->js_encode_function('escape');

my $file   = "/tmp/config/daemon.conf";
my %config = ();
if ( -f $file ) {
    %config = ParseConfig($file);
}

print $pjx->build_html( $cgi, \&show_HTML );

# ------------------------------------------------------------------------------

=head2 clear()

Clear the screen.

=cut

sub clear {
    return;
}

=head2 global()

...

=cut

sub global {
    if ( -f $file ) {
        %config = ParseConfig($file);
    }

    my $html = q{};
    $html = $cgi->br;
    $html .= $cgi->start_table( { border => "0", cellpadding => "1", align => "center", width => "100%" } ) . "\n";

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->div( { -id => "global_result2" }, ( $cgi->param('global_1') ? globalResult() : "" ) );
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    my $list = configureGlobal( \%config );

    foreach my $item (@{$list}) {
        $html .= $cgi->start_Tr;
        $html .= $cgi->start_td( { align => "left", width => "40%" } );
        $html .= $item->{"prompt"};
        $html .= $cgi->end_td;
        $html .= $cgi->start_td( { align => "left", width => "60%" } );
        $html .= "<input type=\"text\" size=\"50\" name=\"" . $item->{"name"} . "\" id=\"" . $item->{"name"} . "\" value=\"" . ( exists $config{ $item->{"name"} } ? $config{ $item->{"name"} } : $item->{"default"} );
        if ( $item->{"suffix"} ) {
            $html .= "\">&nbsp;" . $item->{"suffix"};
        }
        else {
            $html .= "\">";
        }
        $html .= $cgi->end_td;
        $html .= $cgi->end_Tr;
    }
            
    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->br;
    $html .= "<input type=\"hidden\" name=\"global1\" id=\"global1\" value=\"1\">";
    $html .= "<input type=\"submit\" name=\"global_1\" id=\"global_1\" value=\"Store\" onClick=\"exportg_1([],['global_result'])\">";
    $html .= $cgi->br;
    $html .= $cgi->br;
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->end_table . "\n";

    return $html;
}

=head2 globalResult()

...

=cut

sub globalResult {
    my $html = q{};

    if ( $cgi->param('global_1') ) {
        $html .= "<i><font color=\"green\">Configuration Updated.</font></i><br><br>";

        my $list = configureGlobal( \%config );
        foreach my $item ( @{$list} ) {
            $config{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
        }

        if ( -f $file ) {
            system("cp $file $file~");
        }
        SaveConfig_mine( $file, \%config ); 
    }
    else {
        $html .= "<i><font color=\"red\">Nothing Changed.</font></i><br><br>";
    }
    return $html;
}

# ------------------------------------------------------------------------------

=head2 addPort(

Add a new port to the config file.  This step must be done before any services
are added to the daemon on an unknown port (services can be added to existing
ports rather easily).  

=cut

sub addPort {
    if ( -f $file ) {
        %config = ParseConfig($file);
    }

    my $html = q{};
    $html = $cgi->br;
    $html .= $cgi->start_table( { border => "0", cellpadding => "1", align => "center", width => "100%" } ) . "\n";

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->div( { -id => "add_result2" }, ( $cgi->param('add_port_1') ? addPortResult() : "" ) );
    $html .= $cgi->br;
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "left", width => "60%" } );
    $html .= "Enter a new port to expose ";
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "left", width => "40%" } );
    $html .= "<input type=\"text\" name=\"addPort\" id=\"addPort\">\n";
    $html .= "<input type=\"hidden\" name=\"add_port1\" id=\"add_port1\" value=\"1\">";
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->br;
    $html .= "<input type=\"submit\" name=\"add_port_1\" id=\"add_port_1\" value=\"Add\" onClick=\"export1_1([],['add_result'])\">";
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->end_table . "\n";

    return $html;
}

=head2 addPortResult()

Aux function that saves the configuration file (i.e. adds the port) and reprts
the status.

=cut

sub addPortResult {
    my $html = q{};
    if ( $cgi->param('addPort') ) {

        if ( exists $config{"port"}->{ $cgi->param('addPort') } ) {
            $html = "<br><i>Port <font color=\"red\">" . $cgi->param('addPort') . "</font> exists already.</i><br>";
        }
        else {
            $html = "<br><i>Port <font color=\"red\">" . $cgi->param('addPort') . "</font> added.</i><br>";
            $config{"port"}->{ $cgi->param('addPort') } = "";
            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
    }
    return $html;
}

# ------------------------------------------------------------------------------

=head2 deletePort()

Delete an existing port (and all associated services) from the config file.

=cut

sub deletePort {
    if ( -f $file ) {
        %config = ParseConfig($file);
    }

    my $html = q{};
    $html = $cgi->br;
    $html .= $cgi->start_table( { border => "0", cellpadding => "1", align => "center", width => "100%" } ) . "\n";

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->div( { -id => "delete_result2" }, ( $cgi->param('delete_port_1') ? deletePortResult() : "" ) );
    $html .= $cgi->br;
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    if ( ( keys %{ $config{"port"} } ) == 0 ) {
        $html .= $cgi->start_Tr;
        $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
        $html .= "<i>There are no ports configured to delete.</i><br><br>";
        $html .= $cgi->end_td;
        $html .= $cgi->end_Tr;
    }
    else {
        $html .= $cgi->start_Tr;
        $html .= $cgi->start_td( { align => "left", width => "60%" } );
        $html .= "Choose Port (<b><font color=\"red\">AND ALL ASSOCIATED ENDPOINTS/SERVICES</font></b>) to delete ";
        $html .= $cgi->end_td;
        $html .= $cgi->start_td( { align => "left", width => "40%" } );
        $html .= "<select name=\"deletePort\" id=\"deletePort\">\n";
        foreach my $p ( keys %{ $config{"port"} } ) {
            unless ( $cgi->param('deletePort') and $cgi->param('deletePort') eq $p ) {
                $html .= "  <option value=\"" . $p . "\">" . $p . "</option>\n";
            }
        }
        $html .= "</select>\n";
        $html .= "<input type=\"hidden\" name=\"delete_port1\" id=\"delete_port1\" value=\"1\">";
        $html .= $cgi->end_td;
        $html .= $cgi->end_Tr;

        $html .= $cgi->start_Tr;
        $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
        $html .= $cgi->br;
        $html .= "<input type=\"submit\" name=\"delete_port_1\" id=\"delete_port_1\" value=\"Delete\" onClick=\"export3_1([],['delete_result'])\">";
        $html .= $cgi->end_td;
        $html .= $cgi->end_Tr;
    }

    $html .= $cgi->end_table . "\n";

    return $html;
}

=head2 deletePortResult()

Aux function that saves the configuration file (i.e. deletes the port) and
reports the status.

=cut

sub deletePortResult {
    my $html = "<i>Port <font color=\"red\">" . $cgi->param('deletePort') . "</font> deleted.</i><br><br>";

    delete $config{"port"}->{ $cgi->param('deletePort') };
    if ( -f $file ) {
        system("cp $file $file~");
    }
    SaveConfig_mine( $file, \%config );

    return $html;
}

# ------------------------------------------------------------------------------

=head2 addService()

Add a new service to a port/endpoint.

=cut

sub addService {
    if ( -f $file ) {
        %config = ParseConfig($file);
    }

    my $html = q{};
    $html = $cgi->br;
    $html .= $cgi->start_table( { border => "0", cellpadding => "1", align => "center", width => "100%" } ) . "\n";

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->div( { -id => "add_s_result2" }, ( $cgi->param('add_service_1') ? addServiceResult() : "" ) );
    $html .= $cgi->div( { -id => "add_s_result3" }, ( $cgi->param('add_service_2') ? addServiceResult() : "" ) );
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "left", width => "50%", colspan => "1" } );
    $html .= "First pick a port:&nbsp;";
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "left", width => "50%", colspan => "1" } );
    $html .= "<select name=\"addService\" id=\"addService\">\n";
    foreach my $p ( keys %{ $config{"port"} } ) {
        if ( $cgi->param('addService') and $cgi->param('addService') eq $p ) {
            $html .= "  <option selected=\"true\" value=\"" . $p . "\">" . $p . "</option>\n";
        }
        else {
            $html .= "  <option value=\"" . $p . "\">" . $p . "</option>\n";
        }
    }
    $html .= "</select>\n";
    $html .= "<input type=\"hidden\" name=\"add_service1\" id=\"add_service1\" value=\"1\">";
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "left", width => "50%", colspan => "1" } );
    $html .= "Then pick a service type:&nbsp;";
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "left", width => "50%", colspan => "1" } );
    $html .= "<select name=\"addServiceType\" id=\"addServiceType\">\n";
    if ( $cgi->param('addServiceType') eq "snmp" ) {
        $html .= "  <option selected=\"true\" value=\"snmp\">snmp</option>\n";
    }
    else {
        $html .= "  <option value=\"snmp\">snmp</option>\n";
    }
    if ( $cgi->param('addServiceType') eq "ls" ) {
        $html .= "  <option selected=\"true\" value=\"ls\">ls</option>\n";
    }
    else {
        $html .= "  <option value=\"ls\">ls</option>\n";
    }
    if ( $cgi->param('addServiceType') eq "perfsonarbuoy" ) {
        $html .= "  <option selected=\"true\" value=\"perfsonarbuoy\">perfsonarbuoy</option>\n";
    }
    else {
        $html .= "  <option value=\"perfsonarbuoy\">perfsonarbuoy</option>\n";
    }
    if ( $cgi->param('addServiceType') eq "pingerma" ) {
        $html .= "  <option selected=\"true\" value=\"pingerma\">pingerma</option>\n";
    }
    else {
        $html .= "  <option value=\"pingerma\">pingerma</option>\n";
    }
    if ( $cgi->param('addServiceType') eq "pingermp" ) {
        $html .= "  <option selected=\"true\" value=\"pingermp\">pingermp</option>\n";
    }
    else {
        $html .= "  <option value=\"pingermp\">pingermp</option>\n";
    }
    $html .= "</select>\n";
    $html .= "<input type=\"hidden\" name=\"add_service1\" id=\"add_service1\" value=\"1\">";
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "left", width => "50%", colspan => "1" } );
    $html .= "Finally, enter the service endpoint (start it with a <b>/</b> please):&nbsp;";
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "left", width => "50%", colspan => "1" } );
    $html .= "<input type=\"text\" name=\"addService1\" id=\"addService1\" value=\"" . ( $cgi->param('addService1') ? $cgi->param('addService1') : "" ) . "\">";
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= "<input type=\"submit\" name=\"add_service_1\" id=\"add_service_1\" value=\"Choose\" onClick=\"export4_1([],['add_s_result'])\">";
    $html .= $cgi->end_br;
    $html .= $cgi->end_br;
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    if ( $cgi->param('addService') and $cgi->param('addServiceType') and $cgi->param('addService1') ) {

        if (   exists $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }
            or exists $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ "/" . $cgi->param('addService1') } )
        {

            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<br><i>Endpoint <font color=\"red\">" . $cgi->param('addService1') . "</font> on port <font color=\"red\">" . $cgi->param('addService') . "</font> exists, use <b>EDIT</b> command.</i><br>";
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
        else {
            if ( $cgi->param('addServiceType') eq "snmp" ) {

                my $list = configureSNMP( \%config );
                foreach my $item ( @{$list} ) {
                    $html .= $cgi->start_Tr;
                    $html .= $cgi->start_td( { align => "left", width => "40%" } );
                    $html .= $item->{"prompt"};
                    $html .= $cgi->end_td;
                    $html .= $cgi->start_td( { align => "left", width => "60%" } );
                    $html
                        .= "<input type=\"text\" size=\"45\" name=\""
                        . $item->{"name"}
                        . "\" id=\""
                        . $item->{"name"}
                        . "\" value=\""
                        . (
                        exists $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        ? $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        : $item->{"default"} );
                    if ( $item->{"suffix"} ) {
                        $html .= "\">&nbsp;" . $item->{"suffix"};
                    }
                    else {
                        $html .= "\">";
                    }
                    $html .= $cgi->end_td;
                    $html .= $cgi->end_Tr;
                }
            }
            elsif ( $cgi->param('addServiceType') eq "ls" ) {

                my $list = configureLS( \%config );
                foreach my $item ( @{$list} ) {
                    $html .= $cgi->start_Tr;
                    $html .= $cgi->start_td( { align => "left", width => "40%" } );
                    $html .= $item->{"prompt"};
                    $html .= $cgi->end_td;
                    $html .= $cgi->start_td( { align => "left", width => "60%" } );
                    $html
                        .= "<input type=\"text\" size=\"45\" name=\""
                        . $item->{"name"}
                        . "\" id=\""
                        . $item->{"name"}
                        . "\" value=\""
                        . (
                        exists $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        ? $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        : $item->{"default"} );
                    if ( $item->{"suffix"} ) {
                        $html .= "\">&nbsp;" . $item->{"suffix"};
                    }
                    else {
                        $html .= "\">";
                    }
                    $html .= $cgi->end_td;
                    $html .= $cgi->end_Tr;
                }
            }
            elsif ( $cgi->param('addServiceType') eq "perfsonarbuoy" ) {

                my $list = configurepSB( \%config );
                foreach my $item ( @{$list} ) {
                    $html .= $cgi->start_Tr;
                    $html .= $cgi->start_td( { align => "left", width => "40%" } );
                    $html .= $item->{"prompt"};
                    $html .= $cgi->end_td;
                    $html .= $cgi->start_td( { align => "left", width => "60%" } );
                    $html
                        .= "<input type=\"text\" size=\"45\" name=\""
                        . $item->{"name"}
                        . "\" id=\""
                        . $item->{"name"}
                        . "\" value=\""
                        . (
                        exists $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        ? $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        : $item->{"default"} );
                    if ( $item->{"suffix"} ) {
                        $html .= "\">&nbsp;" . $item->{"suffix"};
                    }
                    else {
                        $html .= "\">";
                    }
                    $html .= $cgi->end_td;
                    $html .= $cgi->end_Tr;
                }
            }
            elsif ( $cgi->param('addServiceType') eq "pingerma" ) {

                my $list = configurePingERMA( \%config );
                foreach my $item ( @{$list} ) {
                    $html .= $cgi->start_Tr;
                    $html .= $cgi->start_td( { align => "left", width => "40%" } );
                    $html .= $item->{"prompt"};
                    $html .= $cgi->end_td;
                    $html .= $cgi->start_td( { align => "left", width => "60%" } );
                    $html
                        .= "<input type=\"text\" size=\"45\" name=\""
                        . $item->{"name"}
                        . "\" id=\""
                        . $item->{"name"}
                        . "\" value=\""
                        . (
                        exists $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        ? $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        : $item->{"default"} );
                    if ( $item->{"suffix"} ) {
                        $html .= "\">&nbsp;" . $item->{"suffix"};
                    }
                    else {
                        $html .= "\">";
                    }
                    $html .= $cgi->end_td;
                    $html .= $cgi->end_Tr;
                }
            }
            elsif ( $cgi->param('addServiceType') eq "pingermp" ) {

                my $list = configurePingERMP( \%config );
                foreach my $item ( @{$list} ) {
                    $html .= $cgi->start_Tr;
                    $html .= $cgi->start_td( { align => "left", width => "40%" } );
                    $html .= $item->{"prompt"};
                    $html .= $cgi->end_td;
                    $html .= $cgi->start_td( { align => "left", width => "60%" } );
                    $html
                        .= "<input type=\"text\" size=\"45\" name=\""
                        . $item->{"name"}
                        . "\" id=\""
                        . $item->{"name"}
                        . "\" value=\""
                        . (
                        exists $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        ? $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} }
                        : $item->{"default"} );
                    if ( $item->{"suffix"} ) {
                        $html .= "\">&nbsp;" . $item->{"suffix"};
                    }
                    else {
                        $html .= "\">";
                    }
                    $html .= $cgi->end_td;
                    $html .= $cgi->end_Tr;
                }
            }

            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= $cgi->br;
            $html .= "<input type=\"submit\" name=\"add_service_2\" id=\"add_service_2\" value=\"Store\" onClick=\"export4_1([],['add_s_result'])\">";
            $html .= $cgi->br;
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
    }

    $html .= $cgi->end_table . "\n";

    return $html;
}

=head2 addServiceResult()

results of adding a service....

=cut

sub addServiceResult {
    my $html = q{};

    if ( $cgi->param('add_service_2') ) {
        $html = "<i>Service <font color=\"red\">" . $cgi->param('addService1') . "</font> on Port <font color=\"red\">" . $cgi->param('addService') . "</font> was added.</i><br><br>";

        if ( $cgi->param('addServiceType') eq "snmp" ) {

            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"module"}                                              = "perfSONAR_PS::Services::MA::SNMP";
            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"disabled"}                                            = "0";
            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"metadata_db_type"} = "file";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configureSNMP( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('addServiceType') eq "ls" ) {

            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"module"}   = "perfSONAR_PS::Services::LS::LS";
            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"disabled"} = "0";

            my $list = configureLS( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('addServiceType') eq "perfsonarbuoy" ) {

            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"module"}                                              = "perfSONAR_PS::Services::MA::perfSONARBOUY";
            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"disabled"}                                            = "0";
            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"metadata_db_type"} = "file";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configurepSB( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('addServiceType') eq "pingerma" ) {

            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"module"}   = "perfSONAR_PS::Services::MA::PingER";
            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"disabled"} = "0";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configurePingERMA( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('addServiceType') eq "pingermp" ) {

            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"module"}   = "perfSONAR_PS::Services::MP::PingER";
            $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{"disabled"} = "0";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configurePingERMP( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
    }

    return $html;
}

# ------------------------------------------------------------------------------

=head2 editService()

...

=cut

sub editService {
    if ( -f $file ) {
        %config = ParseConfig($file);
    }

    my $html = q{};
    $html = $cgi->br;
    $html .= $cgi->start_table( { border => "0", cellpadding => "1", align => "center", width => "100%" } ) . "\n";

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->div( { -id => "edit_s_result2" }, ( $cgi->param('edit_service_1') ? editServiceResult() : "" ) );
    $html .= $cgi->div( { -id => "edit_s_result3" }, ( $cgi->param('edit_service_2') ? editServiceResult() : "" ) );
    $html .= $cgi->div( { -id => "edit_s_result4" }, ( $cgi->param('edit_service_3') ? editServiceResult() : "" ) );
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= "First pick a port:&nbsp;";
    $html .= "<select name=\"editService\" id=\"editService\">\n";
    foreach my $p ( keys %{ $config{"port"} } ) {
        if ( $cgi->param('editService') and $cgi->param('editService') eq $p ) {
            $html .= "  <option selected=\"true\" value=\"" . $p . "\">" . $p . "</option>\n";
        }
        else {
            $html .= "  <option value=\"" . $p . "\">" . $p . "</option>\n";
        }
    }
    $html .= "</select>\n";
    $html .= "<input type=\"hidden\" name=\"edit_service1\" id=\"edit_service1\" value=\"1\">";
    $html .= "&nbsp;<input type=\"submit\" name=\"edit_service_1\" id=\"edit_service_1\" value=\"Choose\" onClick=\"export5_1([],['edit_s_result'])\">";
    $html .= $cgi->br;
    $html .= $cgi->br;
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    if ( $cgi->param('editService') ) {
        $html .= $cgi->start_Tr;
        $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
        $html .= "Choose endpoint to edit ";
        $html .= "<select name=\"editService1\" id=\"editService1\">\n";
        foreach my $e ( keys %{ $config{"port"}->{ $cgi->param('editService') }->{"endpoint"} } ) {
            if ( $cgi->param('editService1') and $cgi->param('editService1') eq $e ) {
                $html .= "  <option selected=\"true\" value=\"" . $e . "\">" . $e . "</option>\n";
            }
            else {
                $html .= "  <option value=\"" . $e . "\">" . $e . "</option>\n";
            }
        }
        $html .= "</select>\n";
        $html .= "<input type=\"hidden\" name=\"edit_service2\" id=\"edit_service2\" value=\"1\">";
        $html .= "&nbsp;<input type=\"submit\" name=\"edit_service_2\" id=\"edit_service_2\" value=\"Choose\" onClick=\"export5_1([],['edit_s_result'])\">";
        $html .= $cgi->br;
        $html .= $cgi->br;
        $html .= $cgi->end_td;
        $html .= $cgi->end_Tr;
    }

    if ( $cgi->param('editService1') ) {

        if ( exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"snmp"} ) {
            my $list = configureSNMP( \%config );

            foreach my $item ( @{$list} ) {
                $html .= $cgi->start_Tr;
                $html .= $cgi->start_td( { align => "left", width => "40%" } );
                $html .= $item->{"prompt"};
                $html .= $cgi->end_td;
                $html .= $cgi->start_td( { align => "left", width => "60%" } );
                $html
                    .= "<input type=\"text\" size=\"45\" name=\""
                    . $item->{"name"}
                    . "\" id=\""
                    . $item->{"name"}
                    . "\" value=\""
                    . (
                    exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"snmp"}->{ $item->{"name"} }
                    ? $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"snmp"}->{ $item->{"name"} }
                    : $item->{"default"} );
                if ( $item->{"suffix"} ) {
                    $html .= "\">&nbsp;" . $item->{"suffix"};
                }
                else {
                    $html .= "\">";
                }
                $html .= $cgi->end_td;
                $html .= $cgi->end_Tr;
            }

            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<input type=\"hidden\" name=\"editServiceType\" id=\"editServiceType\" value=\"snmp\">";
            $html .= "<input type=\"submit\" name=\"edit_service_3\" id=\"edit_service_3\" value=\"Edit\" onClick=\"export5_1([],['edit_s_result'])\">";
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
        elsif ( exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"perfsonarbuoy"} ) {

            my $list = configurepSB( \%config );
            foreach my $item ( @{$list} ) {
                $html .= $cgi->start_Tr;
                $html .= $cgi->start_td( { align => "left", width => "40%" } );
                $html .= $item->{"prompt"};
                $html .= $cgi->end_td;
                $html .= $cgi->start_td( { align => "left", width => "60%" } );
                $html
                    .= "<input type=\"text\" size=\"45\" name=\""
                    . $item->{"name"}
                    . "\" id=\""
                    . $item->{"name"}
                    . "\" value=\""
                    . (
                    exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"perfsonarbuoy"}->{ $item->{"name"} }
                    ? $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"perfsonarbuoy"}->{ $item->{"name"} }
                    : $item->{"default"} );
                if ( $item->{"suffix"} ) {
                    $html .= "\">&nbsp;" . $item->{"suffix"};
                }
                else {
                    $html .= "\">";
                }
                $html .= $cgi->end_td;
                $html .= $cgi->end_Tr;
            }

            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<input type=\"hidden\" name=\"editServiceType\" id=\"editServiceType\" value=\"perfsonarbuoy\">";
            $html .= "<input type=\"submit\" name=\"edit_service_3\" id=\"edit_service_3\" value=\"Edit\" onClick=\"export5_1([],['edit_s_result'])\">";
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
        elsif ( exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"ls"} ) {

            my $list = configureLS( \%config );
            foreach my $item ( @{$list} ) {
                $html .= $cgi->start_Tr;
                $html .= $cgi->start_td( { align => "left", width => "40%" } );
                $html .= $item->{"prompt"};
                $html .= $cgi->end_td;
                $html .= $cgi->start_td( { align => "left", width => "60%" } );
                $html
                    .= "<input type=\"text\" size=\"45\" name=\""
                    . $item->{"name"}
                    . "\" id=\""
                    . $item->{"name"}
                    . "\" value=\""
                    . (
                    exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"ls"}->{ $item->{"name"} } ? $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"ls"}->{ $item->{"name"} } : $item->{"default"} );
                if ( $item->{"suffix"} ) {
                    $html .= "\">&nbsp;" . $item->{"suffix"};
                }
                else {
                    $html .= "\">";
                }
                $html .= $cgi->end_td;
                $html .= $cgi->end_Tr;
            }

            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<input type=\"hidden\" name=\"editServiceType\" id=\"editServiceType\" value=\"ls\">";
            $html .= "<input type=\"submit\" name=\"edit_service_3\" id=\"edit_service_3\" value=\"Edit\" onClick=\"export5_1([],['edit_s_result'])\">";
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
        elsif ( exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"pingerma"} ) {

            my $list = configurePingERMA( \%config );
            foreach my $item ( @{$list} ) {
                $html .= $cgi->start_Tr;
                $html .= $cgi->start_td( { align => "left", width => "40%" } );
                $html .= $item->{"prompt"};
                $html .= $cgi->end_td;
                $html .= $cgi->start_td( { align => "left", width => "60%" } );
                $html
                    .= "<input type=\"text\" size=\"45\" name=\""
                    . $item->{"name"}
                    . "\" id=\""
                    . $item->{"name"}
                    . "\" value=\""
                    . (
                    exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"pingerma"}->{ $item->{"name"} }
                    ? $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"pingerma"}->{ $item->{"name"} }
                    : $item->{"default"} );
                if ( $item->{"suffix"} ) {
                    $html .= "\">&nbsp;" . $item->{"suffix"};
                }
                else {
                    $html .= "\">";
                }
                $html .= $cgi->end_td;
                $html .= $cgi->end_Tr;
            }

            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<input type=\"hidden\" name=\"editServiceType\" id=\"editServiceType\" value=\"pingerma\">";
            $html .= "<input type=\"submit\" name=\"edit_service_3\" id=\"edit_service_3\" value=\"Edit\" onClick=\"export5_1([],['edit_s_result'])\">";
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
        elsif ( exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"pingermp"} ) {

            my $list = configurePingERMP( \%config );
            foreach my $item ( @{$list} ) {
                $html .= $cgi->start_Tr;
                $html .= $cgi->start_td( { align => "left", width => "40%" } );
                $html .= $item->{"prompt"};
                $html .= $cgi->end_td;
                $html .= $cgi->start_td( { align => "left", width => "60%" } );
                $html
                    .= "<input type=\"text\" size=\"45\" name=\""
                    . $item->{"name"}
                    . "\" id=\""
                    . $item->{"name"}
                    . "\" value=\""
                    . (
                    exists $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"pingermp"}->{ $item->{"name"} }
                    ? $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"pingermp"}->{ $item->{"name"} }
                    : $item->{"default"} );
                if ( $item->{"suffix"} ) {
                    $html .= "\">&nbsp;" . $item->{"suffix"};
                }
                else {
                    $html .= "\">";
                }
                $html .= $cgi->end_td;
                $html .= $cgi->end_Tr;
            }

            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<input type=\"hidden\" name=\"editServiceType\" id=\"editServiceType\" value=\"pingermp\">";
            $html .= "<input type=\"submit\" name=\"edit_service_3\" id=\"edit_service_3\" value=\"Edit\" onClick=\"export5_1([],['edit_s_result'])\">";
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
        else {
            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<i>Unable to edit service information.</i><br><br>";
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
    }

    $html .= $cgi->end_table . "\n";

    return $html;
}

=head2 editServiceResult()

...

=cut

sub editServiceResult {
    my $html = q{};

    if ( $cgi->param('edit_service_3') ) {
        $html = "<i>Service <font color=\"red\">" . $cgi->param('editService1') . "</font> on Port <font color=\"red\">" . $cgi->param('editService') . "</font> was edited.</i><br><br>";

        if ( $cgi->param('editServiceType') eq "snmp" ) {

            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"module"}                                               = "perfSONAR_PS::Services::MA::SNMP";
            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"disabled"}                                             = "0";
            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"metadata_db_type"} = "file";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configureSNMP( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('editServiceType') eq "ls" ) {

            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"module"}   = "perfSONAR_PS::Services::LS::LS";
            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"disabled"} = "0";

            my $list = configureLS( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('editServiceType') eq "perfsonarbuoy" ) {

            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"module"}                                               = "perfSONAR_PS::Services::MA::perfSONARBOUY";
            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"disabled"}                                             = "0";
            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"metadata_db_type"} = "file";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configurepSB( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('editServiceType') eq "pingerma" ) {

            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"module"}   = "perfSONAR_PS::Services::MA::PingER";
            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"disabled"} = "0";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configurePingERMA( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
        elsif ( $cgi->param('editServiceType') eq "pingermp" ) {

            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"module"}   = "perfSONAR_PS::Services::MP::PingER";
            $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{"disabled"} = "0";
            if ( $cgi->param('ls_registration_interval') ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "1";
            }
            else {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{"enable_registration"} = "0";
            }

            my $list = configurePingERMP( \%config );
            foreach my $item ( @{$list} ) {
                $config{"port"}->{ $cgi->param('editService') }->{"endpoint"}->{ $cgi->param('editService1') }->{ $cgi->param('editServiceType') }->{ $item->{"name"} } = $cgi->param( $item->{"name"} ) if (defined $cgi->param( $item->{"name"} ));
            }

            if ( -f $file ) {
                system("cp $file $file~");
            }
            SaveConfig_mine( $file, \%config );
        }
    }

    return $html;
}

# ------------------------------------------------------------------------------

=head2 deleteService()

Select a service from the port/endpoint list and delete it.

=cut

sub deleteService {
    if ( -f $file ) {
        %config = ParseConfig($file);
    }

    my $html = q{};
    $html = $cgi->br;
    $html .= $cgi->start_table( { border => "0", cellpadding => "1", align => "center", width => "100%" } ) . "\n";

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= $cgi->div( { -id => "delete_s_result2" }, ( $cgi->param('delete_service_1') ? deleteServiceResult() : "" ) );
    $html .= $cgi->div( { -id => "delete_s_result3" }, ( $cgi->param('delete_service_2') ? deleteServiceResult() : "" ) );
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
    $html .= "First pick a port:&nbsp;";
    $html .= "<select name=\"deleteService\" id=\"deleteService\">\n";
    foreach my $p ( keys %{ $config{"port"} } ) {
        if ( $cgi->param('deleteService') and $cgi->param('deleteService') eq $p ) {
            $html .= "  <option selected=\"true\" value=\"" . $p . "\">" . $p . "</option>\n";
        }
        else {
            $html .= "  <option value=\"" . $p . "\">" . $p . "</option>\n";
        }
    }
    $html .= "</select>\n";
    $html .= "<input type=\"hidden\" name=\"delete_service1\" id=\"delete_service1\" value=\"1\">";
    $html .= "&nbsp;<input type=\"submit\" name=\"delete_service_1\" id=\"delete_service_1\" value=\"Choose\" onClick=\"export6_1([],['delete_s_result'])\">";
    $html .= $cgi->br;
    $html .= $cgi->br;
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    if ( $cgi->param('deleteService') ) {
        if ( ( keys %{ $config{"port"}->{ $cgi->param('deleteService') }->{"endpoint"} } ) == 0 ) {
            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "<i>There are no ports configured to delete.</i><br><br>";
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
        else {
            $html .= $cgi->start_Tr;
            $html .= $cgi->start_td( { align => "center", width => "100%", colspan => "2" } );
            $html .= "Choose endpoint (<b><font color=\"red\">AND ASSOCIATED SERVICE</font></b>) to delete ";
            $html .= "<select name=\"deleteService1\" id=\"deleteService1\">\n";
            foreach my $e ( keys %{ $config{"port"}->{ $cgi->param('deleteService') }->{"endpoint"} } ) {
                if ( $cgi->param('deleteService1') and $cgi->param('deleteService1') eq $e ) {
                    $html .= "  <option selected=\"true\" value=\"" . $e . "\">" . $e . "</option>\n";
                }
                else {
                    $html .= "  <option value=\"" . $e . "\">" . $e . "</option>\n";
                }
            }
            $html .= "</select>\n";
            $html .= "&nbsp;<input type=\"submit\" name=\"delete_service_2\" id=\"delete_service_2\" value=\"Delete\" onClick=\"export6_1([],['delete_s_result'])\">";
            $html .= $cgi->br;
            $html .= $cgi->br;
            $html .= $cgi->end_td;
            $html .= $cgi->end_Tr;
        }
    }
    $html .= $cgi->end_table . "\n";

    return $html;
}

=head2 deleteServiceResult()

Aux function to display the results (and save the config file) after deleting
a service.

=cut

sub deleteServiceResult {
    my $html = q{};

    if ( $cgi->param('deleteService') and $cgi->param('deleteService1') and $cgi->param('delete_service_2') ) {
        $html = "<i>Service \"" . $cgi->param('deleteService1') . "\" on Port \"" . $cgi->param('deleteService') . "\" was deleted.</i><br><br>";

        delete $config{"port"}->{ $cgi->param('deleteService') }->{"endpoint"}->{ $cgi->param('deleteService1') };
        if ( -f $file ) {
            system("cp $file $file~");
        }
        SaveConfig_mine( $file, \%config );
    }

    return $html;
}

# ------------------------------------------------------------------------------

=head2 show_HTML()

Main 'display' function for this CGI, this will present the starting page as
well as contains the div tags that are re-written on AJAX calls.

=cut

sub show_HTML {
    if ( -f $file ) {
        %config = ParseConfig($file);
    }

    my $html = $cgi->start_html( -title => 'Configuration' );
    $html .= $cgi->start_multipart_form();

    $html .= $cgi->h2( { align => "center" }, "Configuration" ) . "\n";
    $html .= $cgi->hr( { size => "4", width => "95%" } ) . "\n";
    $html .= $cgi->br;

    $html .= $cgi->start_table( { border => "2", cellpadding => "1", align => "center", width => "95%" } ) . "\n";

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_th( { align => "center", colspan => "2" } );
    $html .= $cgi->h3( { align => "center" }, "Select Configuration Option" );
    $html .= $cgi->end_th;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { colspan => "2", align => "center" } );
    $html .= $cgi->submit( { name => 'Clear', value => "Clear Screen" } );
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "50%" } );
    $html .= $cgi->submit( { name => 'Global', value => "Global" } );
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "center", width => "50%" } );
    $html .= $cgi->start_table( { border => "0", cellpadding => "0", align => "center", width => "100%" } ) . "\n";
    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "33%" } );
    $html .= $cgi->submit( { name => 'add_port', value => "    Add Port    " } );
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "center", width => "33%" } );
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "center", width => "34%" } );
    $html .= $cgi->submit( { name => 'delete_port', value => "    Delete Port   " } );
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;
    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { align => "center", width => "33%" } );
    $html .= $cgi->submit( { name => 'add_service', value => "  Add Service " } );
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "center", width => "33%" } );
    $html .= $cgi->submit( { name => 'edit_service', value => " Edit Service " } );
    $html .= $cgi->end_td;
    $html .= $cgi->start_td( { align => "center", width => "34%" } );
    $html .= $cgi->submit( { name => 'delete_service', value => "Delete service" } );
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;
    $html .= $cgi->end_table . "\n";
    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->start_Tr;
    $html .= $cgi->start_td( { colspan => "2" } );

    if ( $cgi->param('Clear') ) {
        $html .= $cgi->div( { -id => "clear_result" }, ( $cgi->param('Clear') ? clear() : "" ) );
    }
    elsif ( $cgi->param('Global') ) {
        $html .= $cgi->div( { -id => "global_result" }, ( $cgi->param('Global') ? global() : "" ) );
    }
    elsif ( $cgi->param('add_port') ) {
        $html .= $cgi->div( { -id => "add_result" }, ( $cgi->param('add_port') ? addPort() : "" ) );
    }
    elsif ( $cgi->param('delete_port') ) {
        $html .= $cgi->div( { -id => "delete_result" }, ( $cgi->param('delete_port') ? deletePort() : "" ) );
    }
    elsif ( $cgi->param('add_service') ) {
        $html .= $cgi->div( { -id => "add_s_result" }, ( $cgi->param('add_service') ? addService() : "" ) );
    }
    elsif ( $cgi->param('edit_service') ) {
        $html .= $cgi->div( { -id => "edit_s_result" }, ( $cgi->param('edit_service') ? editService() : "" ) );
    }
    elsif ( $cgi->param('delete_service') ) {
        $html .= $cgi->div( { -id => "delete_s_result" }, ( $cgi->param('delete_service') ? deleteService() : "" ) );
    }
    elsif ( $cgi->param('global_1') ) {
        $html .= $cgi->div( { -id => "global_result" }, ( $cgi->param('global_1') ? global() : "" ) );
    }
    elsif ( $cgi->param('add_port1') ) {
        $html .= $cgi->div( { -id => "add_result" }, ( $cgi->param('add_port1') ? addPort() : "" ) );
    }
    elsif ( $cgi->param('delete_port1') ) {
        $html .= $cgi->div( { -id => "delete_result" }, ( $cgi->param('delete_port1') ? deletePort() : "" ) );
    }
    elsif ( $cgi->param('add_service1') ) {
        $html .= $cgi->div( { -id => "add_s_result" }, ( $cgi->param('add_service1') ? addService() : "" ) );
    }
    elsif ( $cgi->param('edit_service1') ) {
        $html .= $cgi->div( { -id => "edit_s_result" }, ( $cgi->param('edit_service1') ? editService() : "" ) );
    }
    elsif ( $cgi->param('delete_service1') ) {
        $html .= $cgi->div( { -id => "delete_s_result" }, ( $cgi->param('delete_service1') ? deleteService() : "" ) );
    }

    $html .= $cgi->end_td;
    $html .= $cgi->end_Tr;

    $html .= $cgi->end_table . "\n";

    return ($html);
}

=head2 configureGlobal( $config )

configureGlobal...

=cut

sub configureGlobal {
    my ($config) = @_;
    
    my @list = ();
    push @list,
        {
        prompt  => "Maximum number of child processes (0 for infinite) ",
        name    => "max_worker_processes",
        default => "0"
        };
    push @list,
        {
        prompt  => "Time before killing children (0 for infinite) ",
        name    => "max_worker_lifetime",
        default => "0",
        suffix  => "seconds"
        };
    push @list,
        {
        prompt  => "Disable \"Echo\" (0 for yes, 1 for no) ",
        name    => "disable_echo",
        default => "0"
        };
    push @list,
        {
        prompt  => "LS instance to register with ",
        name    => "ls_instance",
        default => "http://packrat.internet2.edu:8005/perfSONAR_PS/services/LS"
        };
    push @list,
        {
        prompt  => "LS registration interval ",
        name    => "ls_registration_interval",
        default => "60",
        suffix  => "minutes"
        };
    push @list,
        {
        prompt  => "Interval to \"reap\" (collect and destroy) children ",
        name    => "reaper_interval",
        default => "20",
        suffix  => "seconds"
        };
    push @list,
        {
        prompt  => "Directory to store \"pid\" file ",
        name    => "pid_dir",
        default => "/var/run"
        };
    push @list,
        {
        prompt  => "Name of \"pid\" file ",
        name    => "pid_file",
        default => "ps.pid"
        };

    return \@list;
}

=head2 configureSNMP( $config )

configureSNMP...

=cut

sub configureSNMP {
    my ($config) = @_;

    unless ( $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"rrdtool"} ) {
        my $rrdtool = q{};
        if ( open( RRDTOOL, "which rrdtool |" ) ) {
            $rrdtool = <RRDTOOL>;
            $rrdtool =~ s/rrdtool:\s+//mx;
            $rrdtool =~ s/\n//gmx;
            close(RRDTOOL);
        }
        unless ($rrdtool) {
            $rrdtool = "/usr/local/bin/rrdtool";
        }
        $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"rrdtool"} = $rrdtool;
    }

    my @list = ();
    push @list,
        {
        prompt  => "Enter the location of the RRD binary ",
        name    => "rrdtool",
        default => ""
        };

    push @list,
        {
        prompt  => "Enter the default resolution of RRD queries ",
        name    => "default_resolution",
        default => "300"
        };

    # we should just set the default to be 'file', don't ask
    # push @list, {
    #     prompt => "Enter the database type to read from (file or xmldb) ",
    #     name => "metadata_db_type",
    #     default => "file"
    # };

    push @list,
        {
        prompt  => "Enter the filename of the XML file ",
        name    => "metadata_db_file",
        default => "/etc/perfsonar/store.xml"
        };

    # leave these two out for now (till we can figure out the switch between xmldb/file
    # push @list, {
    #     prompt => "Enter the directory of the XML database ",
    #     name => "metadata_db_name",
    #     default => "/etc/perfsonar/xmldb"
    # };

    # push @list, {
    #     prompt => "Enter the name of the container inside of the XML database ",
    #     name => "metadata_db_file",
    #     default => "store.dbxml"
    # };

    # load this later
    # push @list, {
    #     prompt => "Will this service register with an LS (0 for no, 1 for yes) ",
    #     name => "enable_registration",
    #     default => "0"
    # };

    push @list,
        {
        prompt  => "Interval between when LS registrations occur (0 for none) ",
        name    => "ls_registration_interval",
        default => "0",
        suffix  => "minutes"
        };

    unless ( $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} ) {
        $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} = $config->{"ls_instance"};
    }

    push @list,
        {
        prompt  => "URL of an LS to register with ",
        name    => "ls_instance",
        default => "http://packrat.internet2.edu:8005/perfSONAR_PS/services/LS"
        };
    push @list,
        {
        prompt  => "Enter a name for this service ",
        name    => "service_name",
        default => "perfSONAR-PS SNMP MA"
        };
    push @list,
        {
        prompt  => "Enter the service type ",
        name    => "service_type",
        default => "MA"
        };
    push @list,
        {
        prompt  => "Enter a service description ",
        name    => "service_description",
        default => "perfSONAR-PS SNMP MA Located Somewhere"
        };
    push @list,
        {
        prompt  => "Enter the service's URI ",
        name    => "service_accesspoint",
        default => "http://localhost:" . $cgi->param('addService') . $cgi->param('addService1')
        };

    return \@list;
}

=head2 configureLS( $config )

configureLS...

=cut

sub configureLS {
    my ($config) = @_;

    my @list = ();
    push @list,
        {
        prompt  => "Enter default TTL for registered data: ",
        name    => "ls_ttl",
        default => "240",
        suffix  => "minutes"
        };
    push @list,
        {
        prompt  => "Enter the directory of the XML database ",
        name    => "metadata_db_name",
        default => "/etc/perfsonar/xmldb"
        };
    push @list,
        {
        prompt  => "Enter the name of the container inside of the XML database ",
        name    => "metadata_db_file",
        default => "lsstore.dbxml"
        };
    push @list,
        {
        prompt  => "Enter the time between LS removal (0 for none)",
        name    => "reaper_interval",
        default => "0",
        suffix  => "minutes"
        };
    push @list,
        {
        prompt  => "Enter a name for this service ",
        name    => "service_name",
        default => "perfSONAR-PS LS"
        };
    push @list,
        {
        prompt  => "Enter the service type ",
        name    => "service_type",
        default => "LS"
        };
    push @list,
        {
        prompt  => "Enter a service description ",
        name    => "service_description",
        default => "perfSONAR-PS LS Located Somewhere"
        };
    push @list,
        {
        prompt  => "Enter the service's URI ",
        name    => "service_accesspoint",
        default => "http://localhost:" . $cgi->param('addService') . $cgi->param('addService1')
        };

    return \@list;
}

=head2 configurepSB( $config )

configurepSB...

=cut

sub configurepSB {
    my ($config) = @_;

    my @list = ();
    push @list,
        {
        prompt  => "Enter the directory <font color=\"red\"><b>LOCATION</b></font> of the <i>owmesh.conf</i> file: ",
        name    => "owmesh",
        default => "/etc/ami/etc"
        };

    # we should just set the default to be 'file', don't ask
    # push @list, {
    #     prompt => "Enter the database type to read from (file or xmldb) ",
    #     name => "metadata_db_type",
    #     default => "file"
    # };
    push @list,
        {
        prompt  => "Enter the filename of the XML file ",
        name    => "metadata_db_file",
        default => "/etc/ami/etc/store.xml"
        };

    # leave these two out for now (till we can figure out the switch between xmldb/file
    # push @list, {
    #     prompt => "Enter the directory of the XML database ",
    #     name => "metadata_db_name",
    #     default => "/etc/perfsonar/xmldb"
    # };
    # push @list, {
    #     prompt => "Enter the name of the container inside of the XML database ",
    #     name => "metadata_db_file",
    #     default => "store.dbxml"
    # };

    # load this later
    # push @list, {
    #     prompt => "Will this service register with an LS (0 for no, 1 for yes) ",
    #     name => "enable_registration",
    #     default => "0"
    # };
    push @list,
        {
        prompt  => "Interval between when LS registrations occur (0 for none) ",
        name    => "ls_registration_interval",
        default => "0",
        suffix  => "minutes"
        };

    unless ( $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} ) {
        $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} = $config->{"ls_instance"};
    }

    push @list,
        {
        prompt  => "URL of an LS to register with ",
        name    => "ls_instance",
        default => "http://packrat.internet2.edu:8005/perfSONAR_PS/services/LS"
        };

    push @list,
        {
        prompt  => "Enter a name for this service ",
        name    => "service_name",
        default => "perfSONAR-PS perfSONAR-BUOY MA"
        };
    push @list,
        {
        prompt  => "Enter the service type ",
        name    => "service_type",
        default => "MA"
        };
    push @list,
        {
        prompt  => "Enter a service description ",
        name    => "service_description",
        default => "perfSONAR-PS perfSONAR-BUOY MA Located Somewhere"
        };
    push @list,
        {
        prompt  => "Enter the service's URI ",
        name    => "service_accesspoint",
        default => "http://localhost:" . $cgi->param('addService') . $cgi->param('addService1')
        };

    return \@list;
}

=head2 configurePingERMA( $config )

configurePingERMA...

=cut

sub configurePingERMA {
    my ($config) = @_;

    my @list = ();
    push @list,
        {
        prompt  => "Enter the database type to read from (sqlite,mysql) ",
        name    => "db_type",
        default => "mysql"
        };

    #    push @list, {
    #        prompt => "Enter the filename of the SQLite database ",
    #        name => "db_file",
    #        default => "pinger.db"
    #    };

    push @list,
        {
        prompt  => "Enter the name of the MySQL database ",
        name    => "db_name",
        default => ""
        };
    push @list,
        {
        prompt  => "Enter the host for the MySQL database ",
        name    => "db_host",
        default => "localhost"
        };
    push @list,
        {
        prompt  => "Enter the port for the MySQL database (leave blank for the default) ",
        name    => "db_port",
        default => "3306"
        };
    push @list,
        {
        prompt  => "Enter the username for the MySQL database (leave blank for none) ",
        name    => "db_username",
        default => ""
        };
    push @list,
        {
        prompt  => "Enter the password for the MySQL database (leave blank for none) ",
        name    => "db_password",
        default => ""
        };

    push @list,
        {
        prompt  => "Enter the limit on query size ",
        name    => "query_size_limit",
        default => "100000"
        };

    # load this later
    # push @list, {
    #     prompt => "Will this service register with an LS (0 for no, 1 for yes) ",
    #     name => "enable_registration",
    #     default => "0"
    # };
    push @list,
        {
        prompt  => "Interval between when LS registrations occur (0 for none) ",
        name    => "ls_registration_interval",
        default => "0",
        suffix  => "minutes"
        };

    unless ( $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} ) {
        $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} = $config->{"ls_instance"};
    }

    push @list,
        {
        prompt  => "URL of an LS to register with ",
        name    => "ls_instance",
        default => "http://packrat.internet2.edu:8005/perfSONAR_PS/services/LS"
        };

    push @list,
        {
        prompt  => "Enter a name for this service ",
        name    => "service_name",
        default => "perfSONAR-PS PingER MA"
        };
    push @list,
        {
        prompt  => "Enter the service type ",
        name    => "service_type",
        default => "MA"
        };
    push @list,
        {
        prompt  => "Enter a service description ",
        name    => "service_description",
        default => "perfSONAR-PS PingER MA Located Somewhere"
        };
    push @list,
        {
        prompt  => "Enter the service's URI ",
        name    => "service_accesspoint",
        default => "http://localhost:" . $cgi->param('addService') . $cgi->param('addService1')
        };

    return \@list;
}

=head2 configurePingERMP( $config )

configurePingERMP...

=cut

sub configurePingERMP {
    my ($config) = @_;

    my @list = ();

    push @list,
        {
        prompt  => "Enter the database type to read from (sqlite,mysql) ",
        name    => "db_type",
        default => "mysql"
        };

    #    push @list, {
    #        prompt => "Enter the filename of the SQLite database ",
    #        name => "db_file",
    #        default => "pinger.db"
    #    };

    push @list,
        {
        prompt  => "Enter the name of the MySQL database ",
        name    => "db_name",
        default => ""
        };
    push @list,
        {
        prompt  => "Enter the host for the MySQL database ",
        name    => "db_host",
        default => "localhost"
        };
    push @list,
        {
        prompt  => "Enter the port for the MySQL database (leave blank for the default) ",
        name    => "db_port",
        default => "3306"
        };
    push @list,
        {
        prompt  => "Enter the username for the MySQL database (leave blank for none) ",
        name    => "db_username",
        default => ""
        };
    push @list,
        {
        prompt  => "Enter the password for the MySQL database (leave blank for none) ",
        name    => "db_password",
        default => ""
        };

    push @list,
        {
        prompt  => "Name of XML configuration file for landmarks and schedules ",
        name    => "configuration_file",
        default => "/etc/perfsonar/pinger-landmarks.xml"
        };

    # load this later
    # push @list, {
    #     prompt => "Will this service register with an LS (0 for no, 1 for yes) ",
    #     name => "enable_registration",
    #     default => "0"
    # };
    push @list,
        {
        prompt  => "Interval between when LS registrations occur (0 for none) ",
        name    => "ls_registration_interval",
        default => "0",
        suffix  => "minutes"
        };

    unless ( $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} ) {
        $config->{"port"}->{ $cgi->param('addService') }->{"endpoint"}->{ $cgi->param('addService1') }->{ $cgi->param('addServiceType') }->{"ls_instance"} = $config->{"ls_instance"};
    }

    push @list,
        {
        prompt  => "URL of an LS to register with ",
        name    => "ls_instance",
        default => "http://packrat.internet2.edu:8005/perfSONAR_PS/services/LS"
        };

    push @list,
        {
        prompt  => "Enter a name for this service ",
        name    => "service_name",
        default => "perfSONAR-PS PingER MP"
        };
    push @list,
        {
        prompt  => "Enter the service type ",
        name    => "service_type",
        default => "MP"
        };
    push @list,
        {
        prompt  => "Enter a service description ",
        name    => "service_description",
        default => "perfSONAR-PS PingER MP Located Somewhere"
        };
    push @list,
        {
        prompt  => "Enter the service's URI ",
        name    => "service_accesspoint",
        default => "http://localhost:" . $cgi->param('addService') . $cgi->param('addService1')
        };

    return \@list;
}

=head2 SaveConfig_mine( $file, $hash )

SaveConfig_mine...

=cut

sub SaveConfig_mine {
    my ( $file, $hash ) = @_;
    my $fh;
    if ( open( $fh, ">", $file ) ) {
        printValue( $fh, q{}, $hash, -4 );
        if ( close($fh) ) {
            return 0;
        }
    }
    return -1;
}

=head2 printSpaces( $fh, $count )

printSpaces...

=cut

sub printSpaces {
    my ( $fh, $count ) = @_;
    while ( $count > 0 ) {
        print $fh " ";
        $count--;
    }
    return;
}

=head2 printScalar( $fileHandle, $name, $value, $depth )

printScalar...

=cut

sub printScalar {
    my ( $fileHandle, $name, $value, $depth ) = @_;

    printSpaces( $fileHandle, $depth );
    if ( $value =~ /\n/mx ) {
        my @lines = split( $value, '\n' );
        print $fileHandle "$name     <<EOF\n";
        foreach my $line (@lines) {
            printSpaces( $fileHandle, $depth );
            print $fileHandle $line . "\n";
        }
        printSpaces( $fileHandle, $depth );
        print $fileHandle "EOF\n";
    }
    else {
        print $fileHandle "$name     " . $value . "\n";
    }
    return;
}

=head2 printValue( $fileHandle, $name, $value, $depth )

printValue...

=cut

sub printValue {
    my ( $fileHandle, $name, $value, $depth ) = @_;

    if ( ref $value eq "" ) {
        printScalar( $fileHandle, $name, $value, $depth );
        return;
    }
    elsif ( ref $value eq "ARRAY" ) {
        foreach my $elm ( @{$value} ) {
            printValue( $fileHandle, $name, $elm, $depth );
        }
        return;
    }
    elsif ( ref $value eq "HASH" ) {
        if ( $name eq "endpoint" or $name eq "port" ) {
            foreach my $elm ( sort keys %{$value} ) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "<$name $elm>\n";
                printValue( $fileHandle, q{}, $value->{$elm}, $depth + 4 );
                printSpaces( $fileHandle, $depth );
                print $fileHandle "</$name>\n";
            }
        }
        else {
            if ($name) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "<$name>\n";
            }
            foreach my $elm ( sort keys %{$value} ) {
                printValue( $fileHandle, $elm, $value->{$elm}, $depth + 4 );
            }
            if ($name) {
                printSpaces( $fileHandle, $depth );
                print $fileHandle "</$name>\n";
            }
        }
        return;
    }
}

__END__

=head1 SEE ALSO

L<CGI>, CGI::Ajax>, L<Config::General>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  https://bugs.internet2.edu/jira/browse/PSPS

=head1 VERSION

$Id: config.cgi 1878 2008-03-27 18:38:40Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2008, Internet2

All rights reserved.

=cut
