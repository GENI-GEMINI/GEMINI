package perfSONAR_PS::Services::MP::Agent::Ping;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::MP::Agent::Ping

=head1 DESCRIPTION

A module that will run a ping and return it's output in a suitable internal data
structure.

Inherited perfSONAR_PS::Services::MP::Agent::CommandLine class that allows a
command to be executed. This class overwrites the parse and 

=cut

# derive from teh base agent class
use perfSONAR_PS::Services::MP::Agent::CommandLine;
use base qw(perfSONAR_PS::Services::MP::Agent::CommandLine);

use Log::Log4perl qw(get_logger);
our $logger = Log::Log4perl::get_logger( 'perfSONAR_PS::Services::MP::Agent::Ping' );

# default command line
our $default_command = '/bin/ping -c %count% -i %interval% -s %packetSize% -t %ttl% %destination%';

=head2 new( $command, $options, $namespace)

Creates a new ping agent class

=cut

sub new {
    my $package = shift;
    my $command = shift;
    my %hash    = ();

    # grab from the global variable
    if ( defined $command and $command ne "" ) {
        $hash{"CMD"} = $command;
    }
    else {
        $hash{"CMD"} = $default_command;
    }
    $hash{"OPTIONS"} = {
        'transport'  => 'ICMP',
        'count'      => 10,
        'interval'   => 1,
        'packetSize' => 1000,
        'ttl'        => 255
    };
    %{ $hash{"RESULTS"} } = ();

    bless \%hash => $package;
}

=head2 count( $string )

accessor/mutator method to set the number of packets to ping to

=cut

sub count {
    my $self = shift;
    if ( @_ ) {
        $self->{'OPTIONS'}->{count} = shift;
    }
    return $self->{'OPTIONS'}->{count};
}

=head2 interval( $string )

accessor/mutator method to set the period between packet pings

=cut

sub interval {
    my $self = shift;
    if ( @_ ) {
        $self->{'OPTIONS'}->{interval} = shift;
    }
    return $self->{'OPTIONS'}->{interval};
}

=head2 packetInterval( $string )

accessor/mutator method to set the period between packet pings

=cut

sub packetInterval {
    my $self = shift;
    return $self->interval( @_ );
}

=head2 deadline( $string )

accessor/mutator method to set the deadline value of the pings

=cut

sub deadline {
    my $self = shift;
    if ( @_ ) {
        $self->{'OPTIONS'}->{deadline} = shift;
    }
    return $self->{'OPTIONS'}->{deadline};
}

=head2 packetSize( $string )

accessor/mutator method to set the packetSize of the pings

=cut

sub packetSize {
    my $self = shift;
    if ( @_ ) {
        $self->{'OPTIONS'}->{packetSize} = shift;
    }
    return $self->{'OPTIONS'}->{packetSize};
}

=head2 ttl( $string )

accessor/mutator method to set the ttl of the pings

=cut

sub ttl {
    my $self = shift;
    if ( @_ ) {
        $self->{'OPTIONS'}->{ttl} = shift;
    }

    return $self->{'OPTIONS'}->{ttl};
}

=head2 ttl( $string )

accessor/mutator method to set the ttl of the pings

=cut

sub transport {
    my $self = shift;
    if ( @_ ) {
        $self->{'OPTIONS'}->{ttl} = shift;
    }
    return $self->{'OPTIONS'}->{ttl};
}

=head2 parse()

parses the output from a command line measurement of pings

=cut

sub parse {
    my $self      = shift;
    my $cmdOutput = shift;

    # use this as indication of the start of the test in epoch secs
    my $time    = shift;    # work out start time of time
    my $endtime = shift;
    my $cmdRan  = shift;

    my @pings = ();
    my @rtts  = ();
    my @seqs  = ();

    for ( my $x = 1; $x < scalar @$cmdOutput - 4; $x++ ) {
        $logger->debug( "Analysing line: " . $cmdOutput->[$x] );
        my @string = split /:/, $cmdOutput->[$x];
        my $v = {};

        ( $v->{'bytes'} = $string[0] ) =~ s/\s*bytes.*$//;
        if ( $string[0] =~ m/ from(.*)\((.*)\)/ ) {
            my $dest = $1;
            $dest =~ s/\s//g;
            $self->destination( $dest ) if $dest ne '';
            $self->destinationIp( $2 );
            $logger->debug( "reformatting destination to '" . $self->destination() . "' and destination ip '" . $self->destinationIp() . "'" );
        }
        if ( $string[1] ) {
            foreach my $t ( split /\s+/, $string[1] ) {
                $logger->debug( "looking at $t" );
                if ( $t =~ m/(.*)=(\s*\d+\.?\d*)/ ) {
                    $v->{$1} = $2;
                    $logger->debug( "  found $1 with $2" );
                }
                else {
                    $v->{'units'} = $t;
                }
            }
        }
        my $ms_time = $v->{'time'} ? $v->{'time'} : 0;
        push( @rtts, $ms_time );

        # next time stamp
        $time = $time + ( $ms_time / 1000 );

        push @pings, {
            'timeValue' => $time,                   #timestamp,
            'value'     => $ms_time,                # rtt
            'seqNum'    => $v->{'icmp_seq'},        #seq
            'ttl'       => $v->{'ttl'},             #ttl
            'numBytes'  => $v->{'bytes'},           #bytes
            'units'     => $v->{'units'} || 'ms',
        };
        push( @seqs, $v->{'icmp_seq'} ) if $v->{'icmp_seq'} && $v->{'icmp_seq'} =~ /^\d+$/;

    }

    # get rest of results
    my ( $sent, $meanRtt, $maxRtt, $recv, $minRtt );

    # hires results from ping output
    for ( my $x = ( scalar @$cmdOutput - 2 ); $x < ( scalar @$cmdOutput ); $x++ ) {
        $logger->debug( "Analysing line: " . $cmdOutput->[$x] );
        if ( $cmdOutput->[$x] =~ /(\d+) packets transmitted, (\d+) (?:packets )?received/ ) {
            $sent = $1;
            $recv = $2;
        }
        elsif ( $cmdOutput->[$x] =~ /(?:rtt|round-trip) min\/avg\/max\/(?:mdev|stddev) \= (\d+\.\d+)\/(\d+\.\d+)\/(\d+\.\d+)\/\d+\.\d+ ms/ ) {
            $minRtt  = $1;
            $meanRtt = $2;
            $maxRtt  = $3;
        }
    }

    # set the internal results
    $self->results(
        {
            'sent'       => $sent,
            'recv'       => $recv,
            'minRtt'     => $minRtt,
            'meanRtt'    => $meanRtt,
            'maxRtt'     => $maxRtt,
            'singletons' => \@pings,
            'rtts'       => \@rtts,
            'seqs'       => \@seqs
        }
    );

    return 0;
}

1;

__END__

=head1 SYNOPSIS

  # create and setup a new Agent  
  my $agent = perfSONAR_PS::Services::MP::Agent::Ping( );
  $agent->init();
  
  # collect the results (i.e. run the command)
  if( $mp->collectMeasurements() == 0 )
  {
  	
  	# get the raw datastructure for the measurement
  	use Data::Dumper;
  	print "Results:\n" . Dumper $self->results() . "\n";

  }
  # opps! something went wrong! :(
  else {
    
    print STDERR "Command: '" . $self->commandString() . "' failed with result '" . $self->results() . "': " . $agent->error() . "\n"; 
    
  }

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Ping.pm 2760 2009-04-14 22:32:34Z maxim $

=head1 AUTHOR

Yee-Ting Li <ytl@slac.stanford.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2 and SLAC National Accelerator Laboratory

All rights reserved.

=cut

