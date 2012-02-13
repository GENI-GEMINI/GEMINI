package perfSONAR_PS::NPToolkit::ConfigManager::Utils;

use strict;
use warnings;

our $VERSION = 3.1;

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);
use Module::Load;

=head1 NAME

perfSONAR_PS::NPToolkit::ConfigManager::Utils

=head1 DESCRIPTION

A module that exports functions for saving files and restarting services. In
the future, this may talk with a configuration daemon, but for now, it provides
a uniform API that all the models use.

GFR: (LAMP) Changed to do what the ConfigDaemon is doing so we don't incur the
  XMLRPC usage penalty. May be reverted if we ever do direct remote configuration.

=head1 API

=cut

use base 'Exporter';

our @EXPORT_OK = qw( save_file restart_service stop_service start_service );

=head2 save_file({ file => 1, content => 1 })

Save the specified content into the specified file.

=cut

sub save_file {
    my $parameters = validate(
        @_,
        {
            file    => 1,
            content => 1,
        }
    );

    my $file    = $parameters->{file};
    my $content = $parameters->{content};

    
    my $status;
    
    eval {
        $status = writeFile( { filename => $file, contents => $content } );
        1;
    } or do {
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->error( "Problem writing file $file: $@" );
        return -1;
    };
    
    return -1 if $status;

    return 0;
}

=head2 restart_service ({ name => 0 })

Restarts the specified service. The service can either be a named service (e.g.
'hls') in which case the service's init script will be looked up, or a direct
init script. The current code then does a "sudo" restart of the service.

=cut

sub restart_service {
    my $parameters = validate(
        @_,
        {
            name => 1,
        }
    );

    my $name    = $parameters->{name};
    
    my $status;
    
    eval {
        $status = restartService({ name => $name, ignoreEnabled => 0 });
        1;
    } or do {
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->error( "Problem restarting service $name: $@" );
        return -1;
    };
    
    return -1 if $status;
    
    return 0;
}

=head2 stop_service ({ name => 0 })

Stops the specified service. The service can either be a named service (e.g.
'hls') in which case the service's init script will be looked up, or a direct
init script. The current code then does a "sudo" stop of the service.

=cut

sub stop_service {
    my $parameters = validate(
        @_,
        {
            name => 1,
        }
    );

    my $name    = $parameters->{name};

    my $status;
    
    eval {
        $status = stopService({ name => $name, ignoreEnabled => 0 });
        1;
    } or do {
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->error( "Problem stopping service $name: $@" );
        return -1;
    };
    
    return -1 if $status;

    return 0;
}

=head2 start_service ({ name => 0 })

Starts the specified service. The service can either be a named service (e.g.
'hls') in which case the service's init script will be looked up, or a direct
init script. The current code then does a "sudo" start of the service.

=cut

sub start_service {
    my $parameters = validate(
        @_,
        {
            name => 1,
        }
    );

    my $name    = $parameters->{name};

    my $status;
    
    eval {
        $status = startService( { name => $name, ignoreEnabled => 0 } );
        1;
    } or do {
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->error( "Problem starting service $name: $@" );
        return -1;
    };
    
    return -1 if $status;

    return 0;
}

##########################################################################
# From perfSONAR_PS::NPToolkit::ConfigManager::ConfigDaemon
##########################################################################

=head2 writeFile({ filename => 1, contents => 1 })
    Handles the given configuration daemon request.
=cut

sub writeFile {
    my ( @params ) = @_;
    my $parameters = validate(
        @params,
        {
            filename   => 1,
            contents   => 1,
        }); 

    my $filename = $parameters->{filename};
    my $contents = $parameters->{contents};
    
    open( FILE, ">", $filename ) or die("Couldn't write $filename");
    print FILE $contents;
    close( FILE );

    return "";
}

=head2 restartService({ name => 1 })
    Restarts the specified service.
=cut
sub restartService {
    my ( @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name => 1,
            ignoreEnabled => 1,
        }); 

    my $name          = $parameters->{name};
    my $ignoreEnabled = $parameters->{ignoreEnabled};

    my ($status, $res);
    
    # TODO: horrible way to avoid circular reference
    load perfSONAR_PS::NPToolkit::Config::Services; 
    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $services_conf->init();

    my $service_info = $services_conf->lookup_service( { name => $name } );
    unless ($service_info) {
        my $msg = "Invalid service: $name";
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->error($msg);
        die($msg);
    }

    unless ($ignoreEnabled or $service_info->{enabled}) {
        return "";
    }

    my @service_names = ();

    if ( ref $service_info->{service_name} eq "ARRAY" ) {
        foreach my $service_name ( @{ $service_info->{service_name} } ) {
            push @service_names, $service_name;
        }
    }
    else {
        push @service_names, $service_info->{service_name};
    }
    
    $status = 0;
    foreach my $service_name ( @service_names ) {
        # XXX: hack so that during a save, it doesn't stop apache in the middle.
        # Really needs a better way of doing it.
        my $restart_cmd = "restart";
        $restart_cmd = "reload" if ($service_name =~ /httpd/);

        my $cmd = "sudo /etc/init.d/" . $service_name . " " .$restart_cmd ." &> /dev/null";
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->debug($cmd);
        system( $cmd ) and $logger->error( "Problem restarting service $service_name: $?" );
    }

    return "";
}

=head2 startService({ name => 1 })
    Starts the specified service.
=cut
sub startService {
    my ( @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name => 1,
            ignoreEnabled => 1,
        }); 

    my $name          = $parameters->{name};
    my $ignoreEnabled = $parameters->{ignoreEnabled};

    my ($status, $res);
    
    # TODO: horrible way to avoid circular reference
    load perfSONAR_PS::NPToolkit::Config::Services;
    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $services_conf->init();

    my $service_info = $services_conf->lookup_service( { name => $name } );
    unless ($service_info) {
        my $msg = "Invalid service: $name";
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->error($msg);
        die($msg);
    }

    unless ($ignoreEnabled or $service_info->{enabled}) {
        return "";
    }

    my @service_names = ();

    if ( ref $service_info->{service_name} eq "ARRAY" ) {
        foreach my $service_name ( @{ $service_info->{service_name} } ) {
            push @service_names, $service_name;
        }
    }
    else {
        push @service_names, $service_info->{service_name};
    }
    
    foreach my $service_name ( @service_names ) {
        my $cmd = "sudo /etc/init.d/" . $service_name . " start &> /dev/null";
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->debug($cmd);
        system( $cmd ) and $logger->error( "Problem starting service $service_name: $?" );
    }

    return "";
}

=head2 stopService({ name => 1 })
    Stops the specified service.
=cut
sub stopService {
    my ( @params ) = @_;
    my $parameters = validate(
        @params,
        {
            name => 1,
            ignoreEnabled => 1,
        }); 

    my $name          = $parameters->{name};
    my $ignoreEnabled = $parameters->{ignoreEnabled};

    my ($status, $res);

    # TODO: horrible way to avoid circular reference
    load perfSONAR_PS::NPToolkit::Config::Services;
    my $services_conf = perfSONAR_PS::NPToolkit::Config::Services->new();
    $services_conf->init();

    my $service_info = $services_conf->lookup_service( { name => $name } );
    unless ($service_info) {
        my $msg = "Invalid service: $name";
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->error($msg);
        die($msg);
    }

#    stop no matter what since stopping a non-enabled service doesn't matter
#    unless ($ignoreEnabled or $service_info->{enabled}) {
#        return "";
#    }

    my @service_names = ();

    if ( ref $service_info->{service_name} eq "ARRAY" ) {
        foreach my $service_name ( @{ $service_info->{service_name} } ) {
            push @service_names, $service_name;
        }
    }
    else {
        push @service_names, $service_info->{service_name};
    }
    
    foreach my $service_name ( @service_names ) {
        my $cmd = "sudo /etc/init.d/" . $service_name . " stop &> /dev/null";
        my $logger = get_logger( "perfSONAR_PS::NPToolkit::ConfigManager::Utils" );
        $logger->debug($cmd);
        system( $cmd ) and $logger->error( "Problem stopping service $service_name: $?" );
    }

    return "";
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
