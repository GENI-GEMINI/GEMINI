package perfSONAR_PS::Utils::OSCARS;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'IDC_URL', 'CLIENT_DIR';

=head1 NAME

perfSONAR_PS::Utils::OSCARS

=head1 DESCRIPTION

Utilities for interacting with the OSCARS software.

=cut

use IO::Handle;
use Cwd;
use Params::Validate qw(:all);

=head2 new($package)

Create a new object.

=cut

sub new {
    my $package = shift;
    my $args = validate( @_, { idc_url => 0, client_directory => 0 } );

    my $self = fields::new( $package );
    $self->{IDC_URL}    = $args->{idc_url}          if ( $args->{idc_url} );
    $self->{CLIENT_DIR} = $args->{client_directory} if ( $args->{client_directory} );

    return $self;
}

=head2 getIDC($self)

Return the URL of the IDC

=cut

sub getIDC {
    my ( $self ) = @_;

    return $self->{IDC_URL};
}

=head2 getClientDirectory($self)

Return the client directory

=cut

sub getClientDirectory {
    my ( $self ) = @_;

    return $self->{CLIENT_DIR};
}

=head2 setIDC($self, $url)

Set the value of the IDC

=cut

sub setIDC {
    my ( $self, $url ) = @_;

    $self->{IDC_URL} = $url;
    return;
}

=head2 setClientDirectory($self, $dir)

Set the value of the client directory

=cut

sub setClientDirectory {
    my ( $self, $dir ) = @_;

    $self->{CLIENT_DIR} = $dir;

    return;
}

=head2 getTopology( $self, $output )

Dump the topology from the IDC

=cut

sub getTopology($$) {
    my ( $self, $output ) = @_;
    my $prev_dir = cwd;

    chdir( $self->{CLIENT_DIR} );

    my ( $status, $classpath ) = getClasspath();
    if ( $status == -1 ) {
        $$output = "Couldn't get classpath. Is environmental variable AXIS2_HOME set?" if ( $output );
        return;
    }

    my $repo_dir = $self->{CLIENT_DIR} . "/repo";

    my @input = ( "\n" );
    my $lines = exec_input( "java -cp $classpath -Djava.net.preferIPv4Stack=true GetNetworkTopologyClient $repo_dir " . $self->{IDC_URL}, \@input );

    my $cmd_output = q{};

    my $topology    = q{};
    my $in_topology = 0;
    foreach my $line ( @{$lines} ) {
        chomp( $line );
        next if ( not $line );
        if ( $in_topology ) {
            if ( $line =~ /Topology End/ ) {
                $in_topology = 0;
            }
            else {
                $topology .= $line;
            }
        }
        elsif ( $line =~ /Topology Start/ ) {
            $in_topology = 1;
        }
        $cmd_output .= $line;
    }

    chdir( $prev_dir );

    if ( $output ) {
        $$output = $cmd_output;
    }

    return $topology;
}

=head2 queryCircuits( $self, $circuit_ids )

Query the IDC for supplied circuit IDs

=cut

sub queryCircuits($$$$) {
    my ( $self, $circuit_ids ) = @_;
    my $prev_dir = cwd;

    my ( %paths, %pids );

    chdir( $self->{CLIENT_DIR} );

    my ( $status, $classpath ) = getClasspath();

    if ( $status == -1 ) {
        return \%paths;
    }

    my $repo_dir = $self->{CLIENT_DIR} . "/repo";

    foreach my $id ( @{$circuit_ids} ) {
        my ( $parent_fd, $child_fd );
        pipe( $parent_fd, $child_fd );
        my $pid = fork();
        if ( $pid != 0 ) {
            $pids{$pid} = $parent_fd;
        }
        else {
            my @input   = ();
            my $in_path = 0;

            my $lines = exec_input( "java -cp $classpath -Djava.net.preferIPv4Stack=true QueryReservationCLI -repo $repo_dir -url " . $self->{IDC_URL} . " -gri $id", \@input );
            my $ret = "$id";
            foreach my $line ( @{$lines} ) {
                if ( $line =~ /Path:/ ) {
                    $in_path = 1;
                }
                elsif ( $line =~ /\t(.*)$/ and $in_path ) {
                    $ret .= ",$1";
                }
                else {
                    $in_path = 0;
                }
            }

            print $child_fd $ret;
            exit( 0 );
        }
    }

    foreach my $pid ( keys %pids ) {
        waitpid( $pid, 0 );
        my $line;
        read $pids{$pid}, $line, 1024;
        my ( $id, @links ) = split( ',', $line );
        $paths{$id} = \@links;
    }

    chdir( $prev_dir );

    return \%paths;
}

=head2 getActiveCircuits( $self )

Get list of active circuits from the IDC.

=cut

sub getActiveCircuits($$$) {
    my ( $self ) = @_;
    my $prev_dir = cwd;
    my @ids      = ();

    chdir( $self->{CLIENT_DIR} );

    my ( $status, $classpath ) = getClasspath();
    if ( $status == -1 ) {
        return \@ids;
    }

    my $repo_dir = $self->{CLIENT_DIR} . "/repo";

    my @input = ( "\n" );
    my $lines = exec_input( "java -cp $classpath -Djava.net.preferIPv4Stack=true ListReservationCLI -repo $repo_dir -url " . $self->{IDC_URL} . " -status ACTIVE", \@input );
    my $i     = 0;
    my ( $curr_id, $owner );
    my %pids  = ();
    my %paths = ();

    foreach my $line ( @{$lines} ) {
        chomp( $line );

        if ( $line =~ /GRI: (.*)$/ ) {
            $curr_id = $1;
        }
        elsif ( $line =~ /Login: (.*)$/ ) {
            $owner = $1;
        }
        elsif ( $line =~ /Status: (.*)$/ ) {
            $status = $1;
            push @ids, $curr_id;
        }
    }

    chdir( $prev_dir );

    return \@ids;
}

=head2 getClasspath

Get the java CLASSPATH variable.

=cut

sub getClasspath() {
    my $classpath = ".";

    if ( ( not defined $ENV{"AXIS2_HOME"} ) or $ENV{"AXIS2_HOME"} eq q{} ) {
        return ( -1, "Environmental variable AXIS2_HOME undefined" );
    }

    my $dir = $ENV{"AXIS2_HOME"} . "/lib";

    opendir( DIR, $dir );
    while ( ( my $entry = readdir( DIR ) ) ) {
        if ( $entry =~ /\.jar$/ ) {
            $classpath .= ":$dir/$entry";
        }
    }
    closedir( DIR );
    $classpath .= ":OSCARS-client-api.jar:OSCARS-client-examples.jar";

    return ( 0, $classpath );
}

=head2 exec_input( $cmd, $input )

TBD

=cut

sub exec_input($$) {
    my ( $cmd, $input ) = @_;
    my $pid;
    my @lines = ();

    pipe( PC_READER, PC_WRITER );
    pipe( CP_READER, CP_WRITER );
    PC_WRITER->autoflush( 1 );
    CP_WRITER->autoflush( 1 );
    if ( $pid = fork() ) {
        close( CP_WRITER );
        close( PC_READER );
        foreach my $line ( @{$input} ) {
            print PC_WRITER $line;
            sleep( 1 );
        }
        while ( <CP_READER> ) {
            push @lines, $_;
        }

        waitpid( $pid, 0 );
    }
    else {
        close( PC_WRITER );
        close( CP_READER );
        open( STDOUT, ">&", \*CP_WRITER );
        open( STDERR, ">&", \*CP_WRITER );
        open( STDIN,  ">&", \*PC_READER );
        exec $cmd;
    }

    return \@lines;
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

$Id: OSCARS.pm 2640 2009-03-20 01:21:21Z zurawski $

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
