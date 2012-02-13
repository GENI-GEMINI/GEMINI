package perfSONAR_PS::NPToolkit::Config::NTP;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::NTP

=head1 DESCRIPTION

Module for configuring the ntp configuration. The module is currently very
simple and only allows configuration of the servers contained in the
configuration. Longer term, it might make sense to allow a more fine-grained
configuration. This module can read/write ntp.conf as well as
/usr/local/etc/ntp.known_servers and uses the ntp_conf.tmpl file for writing
the ntp.conf file.

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'NTP_SERVERS', 'NTP_CONF_FILE', 'NTP_CONF_TEMPLATE_FILE', 'KNOWN_SERVERS_FILE';

use Template;
use Data::Dumper;
use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);

use perfSONAR_PS::Utils::Config::NTP qw( ntp_conf_read_file );
use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw( save_file restart_service );

# These are the defaults for LAMP
my %defaults = (
    ntp_conf          => "/etc/ntp.conf",
    known_servers     => "/usr/local/etc/ntp_known_servers",
    ntp_conf_template => "/usr/local/etc/ntp_conf.tmpl",
);

=head2 init({ ntp_conf_template => 0, known_servers => 0, ntp_conf => 0 })

Initializes the client. Returns 0 on success and -1 on failure. If specified,
the parameters can be used to set which ntp.conf file, ntp.known_servers file
and ntp.conf template are used for configuration. The defaults are where these
files are located on the current NPToolkit version.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            ntp_conf_template => 0,
            known_servers     => 0,
            ntp_conf          => 0,
            ntp_servers       => 0,
        }
    );

    # Initialize the defaults
    $self->{NTP_CONF_TEMPLATE_FILE} = $defaults{ntp_conf_template};
    $self->{NTP_CONF_FILE}          = $defaults{ntp_conf};
    $self->{KNOWN_SERVERS_FILE}     = $defaults{known_servers};

    # Override any
    $self->{NTP_CONF_TEMPLATE_FILE} = $parameters->{ntp_conf_template} if ( $parameters->{ntp_conf_template} );
    $self->{NTP_CONF_FILE}          = $parameters->{ntp_conf}          if ( $parameters->{ntp_conf} );
    $self->{KNOWN_SERVERS_FILE}     = $parameters->{known_servers}     if ( $parameters->{known_servers} );
    
    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }
    
    $self->{NTP_SERVERS} = dclone( $parameters->{ntp_servers} ) if $parameters->{ntp_servers};
    
    return 0;
}

=head2 save({ restart_services => 0 })
    Saves the configuration to disk. NTP can be restarted by specifying the
    "restart_services" parameter as 1. 
=cut

sub save {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { save_ntp_conf => 0, save_known_servers => 0, restart_services => 0, } );
    
    my $res;
    
    # The web-side of pSConfig doesn't save the ntp_conf file, 
    # but saves the known server list (which is local, not node specific).
    if ( $parameters->{save_ntp_conf} ) {
        my $ntp_conf_output          = $self->generate_ntp_conf();
        
        return (-1, "Problem generating NTP configuration") unless ( $ntp_conf_output );
        
        $res = save_file( { file => $self->{NTP_CONF_FILE}, content => $ntp_conf_output } );
        if ( $res == -1 ) {
            $self->{LOGGER}->error( "File save failed: " . $self->{NTP_CONF_FILE} );
            return (-1, "Problem saving NTP configuration");
        }
    }
    
    # The node-side of pSConfig, on the other hand, only saves the ntp_conf file. 
    if ( $parameters->{save_known_servers} ) {
        my $ntp_known_servers_output = $self->generate_ntp_server_list();
    
        return (-1, "Problem generating list of known servers") unless ( $ntp_known_servers_output );
        
        $res = save_file( { file => $self->{KNOWN_SERVERS_FILE}, content => $ntp_known_servers_output } );
        if ( $res == -1 ) {
            $self->{LOGGER}->error( "File save failed: " . $self->{KNOWN_SERVERS_FILE} );
            return (-1, "Problem saving list of known NTP servers");
        }
    }
    
    if ( $parameters->{restart_services} ) {
        $res = restart_service( { name => "ntp" } );
        if ( $res == -1 ) {
            $self->{LOGGER}->error( "restart failed" );
            return (-1, "Problem restarting NTP");
        }
    }

    return 0;
}

=head2 add_server({ address => 1, description => 1, selected => 1 })

Adds a new server with the specified description and whether it is one of the
servers that NTP should be consulting.  Returns 0 on success and -1 on failure.
Returns -1 if a server with the specified address already exists. The
description parameter contains a text description of the server. The selected
parameter is 1 or 0 depending on whether the server is selected to be in the
ntp.conf file.

=cut

sub add_server {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            address     => 1,
            description => 1,
            selected    => 1,
        }
    );

    my $address     = $parameters->{address};
    my $description = $parameters->{description};
    my $selected    = $parameters->{selected};

    if ( $self->{NTP_SERVERS}->{$address} ) {
        return -1;
    }

    $self->{NTP_SERVERS}->{$address} = {
        address     => $address,
        description => $description,
        selected    => $selected,
    };
    return 0;
}

=head2 update_server({ address => 1, description => 0, selected => 0 })

Updates the server's description and whether it should be used in the ntp
configuration. Returns 0 on success and -1 on failure. A server with the
specified address must exist or -1 is returned. The description parameter
contains a text description of the server. The selected parameter is 1 or 0
depending on whether the server is selected to be in the ntp.conf file.

=cut

sub update_server {
    my ( $self, @params ) = @_;
    my $parameters = validate(
        @params,
        {
            address     => 1,
            description => 0,
            selected    => 0,
        }
    );

    my $address     = $parameters->{address};
    my $description = $parameters->{description};
    my $selected    = $parameters->{selected};

    return -1 unless ( $self->{NTP_SERVERS}->{$address} );

    $self->{NTP_SERVERS}->{$address}->{description} = $description if ( defined $description );
    $self->{NTP_SERVERS}->{$address}->{selected}    = $selected    if ( defined $selected );

    return 0;
}

=head2 get_servers ({})
    Returns the list of known servers as a hash keyed on the servers' addresses.
=cut

sub get_servers {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{NTP_SERVERS};
}

=head2 lookup_server ({ address => 1 })
    Returns a description of the specified server or undefined if the server
    does not exist. The description is a hash containing a description key and
    a selected key.
=cut

sub lookup_server {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { address => 1, } );

    my $address = $parameters->{address};

    return ( $self->{NTP_SERVERS}->{$address} );
}

=head2 delete_server ({ address => 1 })
    Removes the selected server from the list. A return value of 0 means the
    server is not in the list. 
=cut

sub delete_server {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { address => 1, } );

    my $address = $parameters->{address};

    delete( $self->{NTP_SERVERS}->{$address} );

    return 0;
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    my ($mtime1) = (stat ( $self->{KNOWN_SERVERS_FILE} ) )[9];
    
    # GFR: Disabled for LAMP
    #my ($mtime2) = (stat ( $self->{NTP_CONF_FILE} ) )[9];

    #my $mtime = ($mtime1 > $mtime2)?$mtime1:$mtime2;

    return $mtime1;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %new_ntp_servers = ();

    if ( $self->{KNOWN_SERVERS_FILE} ) {
        my ( $status, $res ) = $self->read_ntp_server_list( { file => $self->{KNOWN_SERVERS_FILE} } );
        if ( $status != 0 ) {
            $self->{LOGGER}->error( "Couldn't read NTP server list: " . $res );
        }
        else {
            my $servers = $res;

            foreach my $key ( keys %{$servers} ) {
                my $server = $servers->{$key};

                next if ( $new_ntp_servers{ $server->{address} } );

                my %ntp_server = (
                    address     => $server->{address},
                    description => $server->{description},
                );

                $new_ntp_servers{ $server->{address} } = \%ntp_server;
            }
        }
    }
    
    # GFR: Disabled for LAMP
    if ( undef and $self->{NTP_CONF_FILE} ) {
        my ( $status, $res ) = ntp_conf_read_file( { file => $self->{NTP_CONF_FILE} } );
        if ( $status != 0 ) {
            return $status;
        }

        foreach my $address ( @{$res} ) {
            if ( $new_ntp_servers{$address} ) {
                $new_ntp_servers{$address}->{selected} = 1;
                next;
            }

            my %ntp_server = (
                address  => $address,
                selected => 1,
            );

            $new_ntp_servers{$address} = \%ntp_server;
        }
    }

    $self->{NTP_SERVERS} = \%new_ntp_servers;

    return 0;
}

=head2 generate_ntp_conf ({})
    Converts the internal configuration into the expected template toolkit
    variables, and passes them to template toolkit along with the configured
    template.
=cut

sub generate_ntp_conf {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    my %vars         = ();
    my @vars_servers = ();
    foreach my $key ( sort keys %{ $self->{NTP_SERVERS} } ) {
        my $ntp_server = $self->{NTP_SERVERS}->{$key};

        if ( $ntp_server->{selected} ) {
            my %server_desc = ();
            $server_desc{address}     = $ntp_server->{address};
            $server_desc{description} = $ntp_server->{description};

            push @vars_servers, \%server_desc;
        }
    }
    $vars{servers} = \@vars_servers;

    my $config;

    my $tt = Template->new( ABSOLUTE => 1 );
    unless ( $tt ) {
        $self->{LOGGER}->error( "Couldn't initialize template toolkit" );
        return;
    }

    unless ( $tt->process( $self->{NTP_CONF_TEMPLATE_FILE}, \%vars, \$config ) ) {
        $self->{LOGGER}->error( "Error writing ntp.conf: " . $tt->error() );
        return;
    }

    return $config;
}

=head2 read_ntp_server_list ({ file => 1 })
    Reads the specified ntp.known_server file and returns a hash keyed on the
    addresses with hash values being a hash containing the description.
=cut

sub read_ntp_server_list {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { file => 1, } );

    unless ( open( NTP_SERVERS_FILE, $parameters->{file} ) ) {
        return ( -1, "Couldn't open file: " . $parameters->{file} );
    }

    my %ntp_servers = ();

    while ( <NTP_SERVERS_FILE> ) {
        chomp;

        my ( $address, $description ) = split( ':', $_ );

        next unless ( $address );

        my %ntp_server = (
            address     => $address,
            description => $description,
        );

        $ntp_servers{$address} = \%ntp_server;
    }

    close( NTP_SERVERS_FILE );

    return ( 0, \%ntp_servers );
}

=head2 generate_ntp_server_list
    Takes the internal representation of the known ntp servers and returns a
    string representation of the contents of a ntp.known_servers file
    containing those servers.
=cut

sub generate_ntp_server_list {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my $output = "";

    foreach my $key ( sort keys %{ $self->{NTP_SERVERS} } ) {
        my $ntp_server = $self->{NTP_SERVERS}->{$key};

        $output .= $ntp_server->{address} . ':';
        $output .= $ntp_server->{description} if ( $ntp_server->{description} );
        $output .= "\n";
    }

    return $output;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        ntp_servers        => $self->{NTP_SERVERS},
        ntp_conf           => $self->{NTP_CONF_FILE},
        ntp_conf_template  => $self->{NTP_CONF_TEMPLATE_FILE},
        known_servers_file => $self->{KNOWN_SERVERS_FILE},
    );

    my $str = freeze( \%state );

    return $str;
}

=head2 restore_state({ state => \$state })
    Restores the modules state based on a string provided by the "save_state"
    function above.
=cut

sub restore_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { state => 1, } );

    my $state = thaw( $parameters->{state} );

    $self->{NTP_SERVERS}            = $state->{ntp_servers};
    $self->{NTP_CONF_FILE}          = $state->{ntp_conf};
    $self->{NTP_CONF_TEMPLATE_FILE} = $state->{ntp_conf_template};
    $self->{KNOWN_SERVERS_FILE}     = $state->{known_servers_file};

    return;
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
