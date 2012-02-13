package perfSONAR_PS::NPToolkit::Config::AdministrativeInfo;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::AdministrativeInfo

=head1 DESCRIPTION

Module for configuring the "Administrative Information". This includes the
keywords for the node, the node's organization and location, the administrators
name and email. When this module's save function is called, it also configures
NDT and NPAD since they both use these same settings for their configuration.

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'SITE_INFO_FILE', 'ADMINISTRATOR_NAME', 'ADMINISTRATOR_EMAIL', 'ORGANIZATION_NAME', 'LOCATION', 'KEYWORDS';

use Params::Validate qw(:all);
use Storable qw(store retrieve freeze thaw dclone);
use Data::Dumper;

# These are the defaults for the current LAMP I&M System
my %defaults = ( administrative_info_file => "/usr/local/etc/site.info", );

=head2 init({ administrative_info_file => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
administrative_info_file, if specified, should point to the file that gets read/written
by the module.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { administrative_info_file => 0, } );

    # Initialize the defaults
    $self->{SITE_INFO_FILE} = $defaults{administrative_info_file};

    # Override any
    $self->{SITE_INFO_FILE} = $parameters->{administrative_info_file} if ( $parameters->{administrative_info_file} );

    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 set_organization_name({ organization_name => 1 })
Sets the organization's name
=cut

sub set_organization_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { organization_name => 1, } );

    my $organization_name = $parameters->{organization_name};

    $self->{ORGANIZATION_NAME} = $organization_name;

    return 0;
}

=head2 set_administrator_name({ administrator_name => 1 })
Sets the administrator's name
=cut

sub set_administrator_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { administrator_name => 1, } );

    my $admin_name = $parameters->{administrator_name};

    $self->{ADMINISTRATOR_NAME} = $admin_name;

    return 0;
}

=head2 set_administrator_email({ administrator_email => 1 })
Sets the administrator's email 
=cut

sub set_administrator_email {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { administrator_email => 1, } );

    my $admin_email = $parameters->{administrator_email};

    $self->{ADMINISTRATOR_EMAIL} = $admin_email;

    return 0;
}

=head2 set_location({ location => 1 })
Sets the box's location
=cut

sub set_location {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { location => 1, } );

    my $location = $parameters->{location};

    $self->{LOCATION} = $location;

    return 0;
}

=head2 add_keyword ({ keyword => 1 })

Adds the specified keyword to the configuration. Returns 0 on success, -1 on
failure. No current failure conditions exist.

=cut

sub add_keyword {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { keyword => 1, } );

    $self->{KEYWORDS}->{ $parameters->{keyword} } = 1;

    return 0;
}

=head2 delete_keyword ({ keyword => 1 })

Deletes the specified keyword to the configuration. Returns 0 on success, -1 on
failure. No current failure conditions exist.

=cut

sub delete_keyword {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { keyword => 1, } );

    delete( $self->{KEYWORDS}->{ $parameters->{keyword} } );

    return 0;
}

=head2 get_keywords ({})

Returns the list of currently configured keywords as an array. 

=cut

sub get_keywords {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my @keywords = keys %{ $self->{KEYWORDS} };

    return \@keywords;
}

=head2 get_administrator_name ({})
Returns the administrator's name
=cut

sub get_administrator_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ADMINISTRATOR_NAME};
}

=head2 get_administrator_email ({})
Returns the administrator's email
=cut

sub get_administrator_email {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ADMINISTRATOR_EMAIL};
}

=head2 get_organization_name ({})
Returns the organization's name
=cut

sub get_organization_name {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ORGANIZATION_NAME};
}

=head2 get_location ({})
Returns the node's configured location
=cut

sub get_location {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{LOCATION};
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ($mtime) = (stat ( $self->{SITE_INFO_FILE} ) )[9];

    return $mtime;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my ( $status, $res ) = read_administrative_info_file( { file => $self->{SITE_INFO_FILE} } );
    if ( $status == 0 ) {
        $self->{ORGANIZATION_NAME}   = $res->{organization_name};
        $self->{ADMINISTRATOR_EMAIL} = $res->{administrator_email};
        $self->{ADMINISTRATOR_NAME}  = $res->{administrator_name};
        $self->{LOCATION}            = $res->{location};
        $self->{KEYWORDS}            = $res->{keywords};
    }

    return 0;
}

=head2 read_administrative_info_file ({ file => 1 })

Reads the site.info file specified in the parameters and returns a hash containing administrator_email, keywords, organization_name, administrator_name and location as keys.

=cut

sub read_administrative_info_file {
    my $parameters = validate( @_, { file => 1, } );

    unless ( open( SITE_INFO_FILE, $parameters->{file} ) ) {
        my %info     = ();
        my %keywords = ();
        $info{keywords} = \%keywords;
        return ( 0, \%info );
    }

    my $administrator_name;
    my $organization_name;
    my $location;
    my $email_user;
    my $email_host;
    my $administrator_email;
    my %keywords = ();

    while ( <SITE_INFO_FILE> ) {
        chomp;
        my ( $variable, $value ) = split( '=' );
        $value =~ s/^\s+//;
        $value =~ s/\s+$//;

        if ( $variable eq "full_name" ) {
            $administrator_name = $value;
        }
        elsif ( $variable eq "site_name" ) {
            $organization_name = $value;
        }
        elsif ( $variable eq "site_location" ) {
            $location = $value;
        }
        elsif ( $variable eq "email_usr" ) {
            $email_user = $value;
        }
        elsif ( $variable eq "email_hst" ) {
            $email_host = $value;
        }
        elsif ( $variable eq "administrator_email" ) {
            $administrator_email = $value;
        }
        elsif ( $variable eq "site_project" ) {
            $keywords{$value} = 1;
        }
    }

    unless ( $administrator_email ) {
        if ( $email_host and $email_user ) {
            $administrator_email = $email_user . "@" . $email_host;
        }
    }
    close( SITE_INFO_FILE );

    my %info = (
        administrator_email => $administrator_email,
        keywords            => \%keywords,
        organization_name   => $organization_name,
        administrator_name  => $administrator_name,
        location            => $location,
    );

    return ( 0, \%info );
}

=head2 generate_administrative_info_file({})

Takes the current configuration for the module and generates the content for the site.info file.

=cut

sub generate_administrative_info_file {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    # The chosen names for this file are quite stupid, but retained for
    # backward compatibility.

    my $output = "";

    $output .= "full_name=" . $self->{ADMINISTRATOR_NAME} . "\n";
    $output .= "site_name=" . $self->{ORGANIZATION_NAME} . "\n";
    $output .= "site_location=" . $self->{LOCATION} . "\n";
    foreach my $keyword ( keys %{ $self->{KEYWORDS} } ) {
        $output .= "site_project=" . $keyword . "\n";
    }
    $output .= "administrator_email=" . $self->{ADMINISTRATOR_EMAIL} . "\n";

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
        administrative_info_file    => $self->{SITE_INFO_FILE},
        admin_name        => $self->{ADMINISTRATOR_NAME},
        admin_email       => $self->{ADMINISTRATOR_EMAIL},
        organization_name => $self->{ORGANIZATION_NAME},
        location          => $self->{LOCATION},
        keywords          => $self->{KEYWORDS},
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

    $self->{SITE_INFO_FILE} = $state->{'administrative_info_file'}, $self->{ADMINISTRATOR_NAME} = $state->{'admin_name'}, $self->{ADMINISTRATOR_EMAIL} = $state->{'admin_email'}, $self->{ORGANIZATION_NAME} = $state->{'organization_name'}, $self->{LOCATION} = $state->{'location'},
        $self->{KEYWORDS} = $state->{'keywords'},

        $self->{LOGGER}->debug( "State: " . Dumper( $state ) );
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
