package perfSONAR_PS::Services::UNIS::UNIS;

use warnings;
use strict;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::UNIS::UNIS

=head1 DESCRIPTION

For now this is a wrapper around TS and gLS. The appropriate module
is chosen based on the message type. Only UNIS is registered on the LS.

=head1 API

=cut

use base 'perfSONAR_PS::Services::Base';

use fields 'CLIENT', 'LS_CLIENT', 'LOGGER', 'HLS_MODULE', 'TS_MODULE';

use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);

use perfSONAR_PS::Common;
use perfSONAR_PS::Messages;
use perfSONAR_PS::Topology::Common qw( normalizeTopology validateDomain validateNode validatePort validateLink getTopologyNamespaces );
use perfSONAR_PS::Topology::ID qw( idEncode idBaseLevel );
use perfSONAR_PS::DB::TopologyXMLDB;
use perfSONAR_PS::Client::LS::Remote;
use perfSONAR_PS::Utils::ParameterValidation;

use perfSONAR_PS::Services::LS::gLS;
use perfSONAR_PS::Services::TS::TS;
use ProtoGENI::GeniCredential;

=head2 new(\%conf, \%ns)

The accepted arguments may also be ommited in favor of the 'set' functions.

=cut

sub new {
    my ( $class, $conf, $port, $endpoint, $directory ) = @_;

    my $self = fields::new( $class );
    
    $self->{'HLS_MODULE'} = perfSONAR_PS::Services::LS::gLS->new( $conf, $port, $endpoint, $directory );
    $self->{'TS_MODULE'} = perfSONAR_PS::Services::TS::TS->new( $conf, $port, $endpoint, $directory );
    
    $self->{'HLS_MODULE'}->{CONF}->{"gls"}->{"is_unis"} = 1;
    $self->{'TS_MODULE'}->{CONF}->{"topology"}->{"is_unis"} = 1;
    
    if ( defined $conf and $conf ) {
        $self->{CONF} = \%{$conf};
    }

    if ( defined $directory and $directory ) {
        $self->{DIRECTORY} = $directory;
    }

    if ( defined $port and $port ) {
        $self->{PORT} = $port;
    }

    if ( defined $endpoint and $endpoint ) {
        $self->{ENDPOINT} = $endpoint;
    }

    return $self;
}

=head2 init 

Called at startup by the daemon when this particular module is loaded into the
perfSONAR-PS deployment. Checks the configuration file for the necessary items
and fills in others when needed. Initializes the backed metadata storage (Oracle
Sleepycat XML Database). Finally the message handler registers the appropriate
message types and eventTypes for this module. Any other 'pre-startup' tasks
should be placed in this function.

=cut

sub init {
    my ( $self, $handler ) = @_;

    $self->{LOGGER} = get_logger( "perfSONAR_PS::Services::UNIS" );
    
    if ( $self->{'HLS_MODULE'}->init( $handler ) != 0 ) {
        $self->{LOGGER}->error( "Failed to initialize module " . $self->{'HLS_MODULE'} . " on $handler" );
        exit( -1 );
    }
    
    if ( $self->{'TS_MODULE'}->init( $handler ) != 0 ) {
        $self->{LOGGER}->error( "Failed to initialize module " . $self->{'TS_MODULE'} . " on $handler" );
        exit( -1 );
    }
    
    #
    # XXX: This is just LS registration configuration, but note that UNIS
    # doesn't register itself yet, it delegates to the TS and hLS modules.
    # 
    if ( $self->{CONF}->{"unis"}->{"enable_registration"} ) {
        unless ( exists $self->{CONF}->{service_accesspoint} and $self->{CONF}->{service_accesspoint} ) {
            unless ( exists $self->{CONF}->{external_address} and $self->{CONF}->{external_address} ) {
                $self->{LOGGER}->error( "With LS registration enabled, you need to specify either the service accessPoint for the service or the external_address" );
                return -1;
            }

            $self->{LOGGER}->info( "Setting service access point to https://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT} );
            $self->{CONF}->{"unis"}->{"service_accesspoint"} = "https://" . $self->{CONF}->{external_address} . ":" . $self->{PORT} . $self->{ENDPOINT};
        }

        unless ( exists $self->{CONF}->{"unis"}->{"ls_instance"} and $self->{CONF}->{"unis"}->{"ls_instance"} ) {
            $self->{CONF}->{"unis"}->{"ls_instance"} = $self->{CONF}->{"ls_instance"};
        }

        unless ( exists $self->{CONF}->{"unis"}->{"ls_instance"} and $self->{CONF}->{"unis"}->{"ls_instance"} ) {
            $self->{LOGGER}->warn( "No LS instance specified for Topology Service. Will select one to register with." );

            unless ( exists $self->{CONF}->{"root_hints_url"} and $self->{CONF}->{"root_hints_url"} ) {
                $self->{CONF}->{"root_hints_url"} = "http://www.perfsonar.net/gls.root.hints";
                $self->{LOGGER}->warn( "gLS Hints file not set, using default at \"http://www.perfsonar.net/gls.root.hints\"." );
            }
        }

        if ( not exists $self->{CONF}->{"unis"}->{"ls_registration_interval"} or $self->{CONF}->{"unis"}->{"ls_registration_interval"} eq q{} ) {
            if ( exists $self->{CONF}->{"ls_registration_interval"} and $self->{CONF}->{"ls_registration_interval"} ne q{} ) {
                $self->{CONF}->{"unis"}->{"ls_registration_interval"} = $self->{CONF}->{"ls_registration_interval"};
            }
            else {
                $self->{LOGGER}->warn( "Setting registration interval to 30 minutes" );
                $self->{CONF}->{"unis"}->{"ls_registration_interval"} = 1800;
            }
        }
        else {

            # turn the registration interval from minutes to seconds
            $self->{CONF}->{"unis"}->{"ls_registration_interval"} *= 60;
        }

        unless ( exists $self->{CONF}->{"unis"}->{"service_description"} and $self->{CONF}->{"unis"}->{"service_description"} ) {
            my $description = "perfSONAR_PS UNIS Service";
            if ( exists $self->{CONF}->{site_name} and $self->{CONF}->{site_name} ) {
                $description .= " at " . $self->{CONF}->{site_name};
            }
            if ( exists $self->{CONF}->{site_location} and $self->{CONF}->{site_location} ) {
                $description .= " in " . $self->{CONF}->{site_location};
            }
            $self->{CONF}->{"unis"}->{"service_description"} = $description;
            $self->{LOGGER}->warn( "Setting 'service_description' to '$description'." );
        }

        if ( not exists $self->{CONF}->{"unis"}->{"service_name"}
            or $self->{CONF}->{"unis"}->{"service_name"} eq q{} )
        {
            $self->{CONF}->{"unis"}->{"service_name"} = "UNIS Service";
            $self->{LOGGER}->warn( "Setting 'service_name' to 'UNIS Service'." );
        }

        if ( not exists $self->{CONF}->{"unis"}->{"service_type"}
            or $self->{CONF}->{"unis"}->{"service_type"} eq q{} )
        {
            $self->{CONF}->{"unis"}->{"service_type"} = "UNIS";
            $self->{LOGGER}->warn( "Setting 'service_type' to 'UNIS'." );
        }
        
        if ( ( not exists $self->{CONF}->{"unis"}->{"service_domain"}
            or $self->{CONF}->{"unis"}->{"service_domain"} eq q{} ) 
            and exists $self->{CONF}->{"service_domain"}
            and $self->{CONF}->{"service_domain"} )
        {
            $self->{CONF}->{"unis"}->{"service_domain"} = $self->{CONF}->{"service_domain"};
        }
    }
    
    $handler->registerCredentialHandler( "http://perfsonar.net/ns/protogeni/auth/credential/1", \&ProtoGENI::GeniCredential::CheckCredential );
    
    return 0;
}

=head2 needLS

Returns whether or not this service will be registering with a Lookup Service.

=cut

sub needLS {
    my ( $self ) = @_;

    return ( $self->{CONF}->{"unis"}->{"enable_registration"} );
}

=head2 registerLS($self $sleep_time)

I *think* we can just call them each at a time since the TS registers
with ourselves (our hLS module) and the hLS will just push the summaries
to the gLS.

=cut

sub registerLS {
    my ( $self, $sleep_time ) = @_;
    
    my $old_sleep_time = ${$sleep_time};
    
    my $n = $self->{'TS_MODULE'}->registerLS( $sleep_time );
    $self->{'HLS_MODULE'}->registerLS( \$old_sleep_time );
    
    if ( $sleep_time ) {
        ${$sleep_time} = $self->{CONF}->{"unis"}->{"ls_registration_interval"};
    }
    
    return $n;
}

#
# The following functions are stubs for the gLS maintenance functions.
#

sub maintenance {
    my ( $self, @args ) = @_;
    return $self->{'HLS_MODULE'}->maintenance( @args );
}

sub cleanLS {
    my ( $self, @args ) = @_;
    return $self->{'HLS_MODULE'}->cleanLS( @args );
}

sub summarizeLS {
    my ( $self, @args ) = @_;
    return $self->{'HLS_MODULE'}->summarizeLS( @args );
}

1;

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Services::Base>, L<perfSONAR_PS::Services::MA::General>,
L<perfSONAR_PS::Common>, L<perfSONAR_PS::Messages>,
L<perfSONAR_PS::Client::LS::Remote>, L<perfSONAR_PS::Topology::Common>,
L<perfSONAR_PS::Client::Topology::XMLDB>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: TS.pm 2721 2009-04-03 16:55:55Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
