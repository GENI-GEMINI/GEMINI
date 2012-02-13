package perfSONAR_PS::Collectors::Base;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'CONF', 'DIRECTORY', 'LOGGER';

=head1 NAME

perfSONAR_PS::Collectors::Base - The base module for periodic collectors.

=head1 DESCRIPTION

This module provides a very simple base class to be used by all perfSONAR
collectors.

=cut

use Log::Log4perl qw(get_logger);

=head2 new($class, $conf, $directory)

TBD

=cut

sub new {
    my ( $class, $conf, $directory ) = @_;

    my $self = fields::new( $class );

    $self->{LOGGER} = get_logger( $class );

    if ( defined $conf and $conf ) {
        $self->{CONF} = \%{$conf};
    }
    if ( defined $directory and $directory ) {
        $self->{DIRECTORY} = $directory;
    }
    return $self;
}

=head2 setConf($self, $conf)

TBD

=cut

sub setConf {
    my ( $self, $conf ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Collectors::Base" );

    if ( defined $conf and $conf ) {
        $self->{CONF} = \%{$conf};
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 setDirectory($self, $directory)

TBD

=cut

sub setDirectory {
    my ( $self, $directory ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Collectors::Base" );

    if ( defined $directory and $directory ) {
        $self->{DIRECTORY} = $directory;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 init($self)

This function is called by the daemon to initialize the collector. It must
return 0 on success and -1 on failure.

=cut

sub init {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Collectors::Base" );
    return 0;
}

=head2 collectMeasurements($self)

This function is called by the daemon to collect and store measurements.

=cut

sub collectMeasurements {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::Collectors::Base" );
    $logger->error( "collectMeasurements() function is not implemented" );
    return -1;
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

$Id: Base.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
