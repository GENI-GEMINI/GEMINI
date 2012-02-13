package OWP::MeasSet;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

MeasSet.pm - handle configuration of measurements.

=head1 DESCRIPTION

This module is used to set configuration parameters for the OWP one-way-ping
mesh configuration.

To add additional "scalar" parameters, just start using them. If the new
parameter is a BOOL then also add it to the BOOL hash here. If the new parameter
is an array then add it to the ARRS hash.

=head1 SYNOPSIS

  my $conf = new OWP::Conf([
      NODE	  =>  nodename,
	  CONFDIR =>  path/to/confdir,
  ])
  
NODE will default to ($node) = ($hostname =~ /^.*-(/w)/)
CONFDIR will default to $HOME

The config files can have sections that are only relevant to a particular
system/node/addr by using the pseudo httpd.conf file syntax:

  <OS=$regex>
  osspecificsettings	val
  </OS>

The names for the headings are OS and Host.  $regex is a text string used to
match uname -s, and uname -n. It can contain the wildcard chars '*' and '?'
with '*' matching 0 or more occurances of *anything* and '?' matching exactly 1
occurance of *anything*.

=cut

require Exporter;
require 5.005;
use strict;

# use POSIX;
use FindBin;
use OWP::Conf;
use OWP::Helper;

$MeasSet::REVISION = '$Id: MeasSet.pm 3010 2009-07-20 13:11:27Z zurawski $';
$MeasSet::VERSION  = '1.0';

sub new {
    my ( $class, @initialize ) = @_;
    my $self = {};

    bless $self, $class;

    return $self->init( @initialize );
}

sub init {
    my ( $self, %args ) = @_;
    my ( @mustargnames ) = qw(CONF MEASUREMENTSET);
    my ( @argnames );

    %args = owpverify_args( \@argnames, \@mustargnames, %args );
    if ( !scalar %args ) {
        die "MeasSet::init(): Invalid args";
    }

    my $conf  = $self->{'CONF'}           = $args{'CONF'};
    my $mset  = $self->{'MEASUREMENTSET'} = $args{'MEASUREMENTSET'};
    my $group = $self->{'GROUP'}          = $conf->must_get_val(
        MEASUREMENTSET => $mset,
        ATTR           => 'GROUP'
    );
    my $grouptype = $self->{'GROUPTYPE'} = $conf->must_get_val(
        GROUP => $group,
        ATTR  => 'GROUPTYPE'
    );
    my $tspec = $self->{'TESTSPEC'} = $conf->must_get_val(
        MEASUREMENTSET => $mset,
        ATTR           => 'TESTSPEC'
    );
    my $addrtype = $self->{'ADDRTYPE'} = $conf->must_get_val(
        MEASUREMENTSET => $mset,
        ATTR           => 'ADDRTYPE'
    );
    my $exclude_self = $self->{'EXCLUDE_SELF'} = $conf->get_val(
        MEASUREMENTSET => $mset,
        ATTR           => 'EXCLUDE_SELF'
    );
    $self->{'CENTRALLY_INVOKED'} = $conf->get_val(
        MEASUREMENTSET => $mset,
        ATTR           => 'CENTRALLY_INVOKED'
    );
    my $desc = $conf->get_val(
        MEASUREMENTSET => $mset,
        ATTR           => 'DESCRIPTION'
    );

    if ( !defined( $desc ) ) {
        my $grp_desc = $conf->get_val( GROUP    => $group, ATTR => 'DESCRIPTION' );
        my $tst_desc = $conf->get_val( TESTSPEC => $tspec, ATTR => 'DESCRIPTION' );

        $desc = "";
        $desc .= $grp_desc if ( defined( $grp_desc ) );
        $desc .= ": " if ( defined( $grp_desc ) && defined( $tst_desc ) );
        $desc .= $tst_desc if ( defined( $tst_desc ) );
    }
    if ( defined( $desc ) ) {
        $self->{'DESCRIPTION'} = $desc;
    }

    #
    # Now setup the RECEIVERS/SENDERS hashes
    #
    my ( @tarr, $node, %thash );
    my ( @receivers, @senders );
    my ( $send,      $recv );

    if ( $grouptype eq 'MESH' ) {

        # compile list of receivers
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'NODES' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'INCLUDE_RECEIVERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'EXCLUDE_RECEIVERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 0;
        }

        # sort list into array for processing
        foreach $node ( sort keys %thash ) {

            # skip if node excluded from this group
            next if ( !$thash{$node} );

            # skip if node does not have proper address for this mesh
            next if ( !( $conf->get_val( NODE => $node, TYPE => $addrtype, ATTR => 'ADDR' ) ) );
            push @receivers, $node;
        }

        undef %thash;

        # compile list of senders
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'NODES' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'INCLUDE_SENDERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'EXCLUDE_SENDERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 0;
        }

        # sort list into array for processing
        foreach $node ( sort keys %thash ) {

            # skip if node excluded from this group
            next if ( !$thash{$node} );

            # skip if node does not have proper address for this mesh
            next if ( !( $conf->get_val( NODE => $node, TYPE => $addrtype, ATTR => 'ADDR' ) ) );
            push @senders, $node;
        }

        # setup receivers hash
        foreach $recv ( @receivers ) {
            if ( $exclude_self ) {
                undef @tarr;

                foreach $send ( @senders ) {
                    next if ( $recv eq $send );

                    push @tarr, $send;
                }
            }
            else {
                @tarr = @senders;
            }

            @{ $self->{'RECEIVERS'}->{$recv} } = ( @tarr );
        }

        # setup senders hash
        foreach $send ( @senders ) {
            if ( $exclude_self ) {
                undef @tarr;

                foreach $recv ( @receivers ) {
                    next if ( $send eq $recv );

                    push @tarr, $recv;
                }
            }
            else {
                @tarr = @receivers;
            }

            @{ $self->{'SENDERS'}->{$send} } = ( @tarr );
        }
    }
    elsif ( $grouptype eq 'STAR' ) {
        my ( %rhash, %shash );
        my $hnode = $conf->must_get_val( GROUP => $group, ATTR => 'HAUPTNODE' );

        # compile list of receivers
        $thash{$hnode} = 1;

        @tarr = $conf->get_val( GROUP => $group, ATTR => 'NODES' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'INCLUDE_RECEIVERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'EXCLUDE_RECEIVERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 0;
        }

        # create a clean hash - only good nodes.
        foreach $node ( keys %thash ) {

            # skip if node excluded from this group
            next if ( !$thash{$node} );

            # skip if node does not have proper address for this mesh
            next if ( !( $conf->get_val( NODE => $node, TYPE => $addrtype, ATTR => 'ADDR' ) ) );
            $rhash{$node} = 1;
        }

        undef %thash;

        # compile list of senders
        $thash{$hnode} = 1;

        @tarr = $conf->get_val( GROUP => $group, ATTR => 'NODES' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'INCLUDE_SENDERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 1;
        }
        @tarr = $conf->get_val( GROUP => $group, ATTR => 'EXCLUDE_SENDERS' );
        foreach $node ( @tarr ) {
            $thash{$node} = 0;
        }

        # create a clean hash - only good nodes.
        foreach $node ( keys %thash ) {

            # skip if node excluded from this mesh
            next if ( !$thash{$node} );

            # skip if node does not have proper address for this mesh
            next if ( !( $conf->get_val( NODE => $node, TYPE => $addrtype, ATTR => 'ADDR' ) ) );
            $shash{$node} = 1;
        }

        # setup RECEIVERS hash
        if ( $shash{$hnode} ) {
            foreach $node ( keys %rhash ) {
                next if ( $exclude_self && ( $hnode eq $node ) );
                @{ $self->{'RECEIVERS'}->{$node} } = ( $hnode );
            }
        }
        if ( $rhash{$hnode} ) {
            undef @tarr;
            foreach $node ( sort keys %shash ) {
                next if ( $exclude_self && ( $hnode eq $node ) );
                push @tarr, $node;
            }
            if ( scalar( @tarr ) ) {
                @{ $self->{'RECEIVERS'}->{$hnode} } = ( @tarr );
            }
        }

        # setup SENDERS hash
        if ( $rhash{$hnode} ) {
            foreach $node ( keys %shash ) {
                next if ( $exclude_self && ( $hnode eq $node ) );
                @{ $self->{'SENDERS'}->{$node} } = ( $hnode );
            }
        }
        if ( $shash{$hnode} ) {
            undef @tarr;
            foreach $node ( sort keys %rhash ) {
                next if ( $exclude_self && ( $hnode eq $node ) );
                push @tarr, $node;
            }
            if ( scalar( @tarr ) ) {
                @{ $self->{'SENDERS'}->{$hnode} } = ( @tarr );
            }
        }
    }
    else {
        die "Unknown GROUPTYPE=$grouptype for GROUP=$group";
    }

    return $self;
}

1;

__END__

=head1 SEE ALSO

L<POSIX>, L<FindBin>, L<OWP::Conf>, L<OWP::Helper>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: MeasSet.pm 3010 2009-07-20 13:11:27Z zurawski $

=head1 AUTHOR

Jeff Boote, boote@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut

