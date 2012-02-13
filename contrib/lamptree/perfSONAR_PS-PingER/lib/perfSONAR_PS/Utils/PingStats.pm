package  perfSONAR_PS::Utils::PingStats;

use strict;
use warnings;
use version; our $VERSION = '3.1';

=head1 NAME

 perfSONAR_PS::Utils::PingStats - OOP approach to calculate statistical values for various  ping results

=head1 DESCRIPTION

   instance of this class is a container for all ping related statistical values.
   It will calculate min,max,mean,median values for the set of RTTs or IPDVs. For the
    number of sent/received packets and an array with sequential numbers it will calculate
   loss percentage, CLP or search for duplicates and out of order packets.
   
 
=head1 SYNOPSIS 

   use  perfSONAR_PS::Utils::PingStats;
   
   my $stats_object = perfSONAR_PS::Utils::PingStats->new({ rtts => \@rtts });
   my @rtt_values =  $stats_object->rtt_stats();
   ###
   ###
   ###
   my @ipdv_values =  $stats_object->ipdv_stats();
   ###
   ###   set sent, received, sequential arrays and calculate loss, dups, out of order, CLP
   ###
   $stats_object->sent($sent);
   $stats_object->received($received);
   $stats_object->seqs(\@seqs);
   
   my $loss_percentage =  $stats_object->loss();
   my $clp =  $stats_object->clp();
   my $dups_flag =  $stats_object->dups();
   
   ### or initialize this object at once:
   
    my $stats_object = IEPM::PingER::PingStats->new({ rtts => \@rtts,  
						      sent => '10',
						      received => '10',
						      seqs =>  \@seqs});
   
    #  and calculate everything
   
    my @rtt_values =  $stats_object->rtt_stats();
    my @ipdv_values =  $stats_object->ipdv_stats();
    my $loss_percentage =  $stats_object->loss();
    my $clp =  $stats_object->clp();
    my $dups_flag =  $stats_object->dups();
    my $ooo_flag =  $stats_object->out_of_order();
   
=head1 METHODS


=head2 new()

   constructor, accepts single argument - hashref with keys:
   rtts  sent received seqs loss clp rtt_stats ipdv_stats dups out_of_order

=head2  rtt_stats()
 
   returns  arrayref to the list with (min, max, mean, median) rtt values

=head2 ipdv_stats()

calculates min, max, mean, iqr inter-packet delay values

returns  arrayref to the list with (min, max, mean,   IQR)   inter-packet delay values and interpacketquantile


=head2  dups()

   duplicates and out-of-order packets

         
return arrayref to the list with two values where each value is enumerated string of 'false' or 'true'-
      And first member of the list is for  duplicates and another one for out of order packets
       
=head2 loss()

     returns lost packets percentage

=head2 clp()
   
Conditional Loss Probability (CLP) defined in Characterizing End-to-end Packet
Delay and Loss in the Internet by J. Bolot in the Journal of High-Speed
Networks, vol 2, no. 3 pp 305-323 December 1993.

See: http://citeseer.ist.psu.edu/bolot93characterizing.html

clp =P(rttn+1=0/rttn=0)
 
   return conditional packet loss
   also calculates plg - packet loss gap as 1/(1 - clp)
   
=cut

use Data::Dumper;
use Statistics::Descriptive;
use English qw( -no_match_vars );
use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger);

use constant PARAMS    => qw(rtts  ERROR sent received seqs loss clp plg rtt_stats ipdv_stats iqr dups out_of_order);
use constant CLASSPATH => "perfSONAR_PS::Utils::PingStats";

use fields ( PARAMS );

our $logger = Log::Log4perl::get_logger( CLASSPATH );

Params::Validate::validation_options( on_fail => sub { $logger->( error => shift ) } );

#######################################################################

no strict 'refs';
foreach my $key ( PARAMS ) {
    *{ __PACKAGE__ . "::$key" } = sub {
        my $obj   = shift;
        my $param = shift;
        if ( $param ) {
            $obj->_add_metric( $key => $param );
            $logger->debug( " Added $key => $param " );
        }
        return $obj->{"$key"};
    };
}
use strict;

sub new {
    my ( $that, $param ) = @_;
    if ( $param && ref( $param ) ne 'HASH' ) {
        $logger->error( "ONLY hash ref  parameter accepted: " . $param );
        return;
    }
    my $class = ref( $that ) || $that;
    my $self = fields::new( $class );
    foreach my $key ( PARAMS ) {
        $self->_add_metric( $key => $param->{$key} ) if $param->{$key};    ###
    }
    return $self;
}

#
#   add another measured values
#
sub _add_metric {
    my $self = shift;
    validate_pos( @_, { type => SCALAR }, { type => SCALAR | ARRAYREF } );
    my ( $key, $value ) = @_;
    ## over-write if supplied non-empty array
    if ( ref $value eq 'ARRAY' ) {
        if ( @$value ) {
            $self->{$key} = $value;
        }
        elsif ( !$self->{$key} || ( @{ $self->{$key} } < 1 ) ) {
            $logger->debug( " Empty array, this $key is missing " );
            $self->ERROR( " Empty array, this $key is missing " );
        }
    }
    else {
        $self->{$key} = $value;
    }
    if ( $key eq 'rtts' ) {
        $self->_rtt_stats();
        $self->_ipdv_stats();
    }
    else {
        foreach my $packet_metric ( qw/seqs sent received/ ) {
            if ( $key eq $packet_metric && exists $self->{received} && exists $self->{sent} ) {
                $self->_loss();
                if ( $self->{seqs} && ref $self->{seqs} eq 'ARRAY' ) {
                    $self->_dups();
                    $self->_clp();
                }
                last;
            }
        }

    }
    return $self->{$key};

}

# _rtt_stats()
#
#calculates min, max, mean, median rtt values
#returns arrayref to the  list with (min, max, mean, median) rtt values
#

sub _rtt_stats {
    my $self = shift;
    return unless($self->{rtts} && ref $self->{rtts} eq 'ARRAY');
    my $size = scalar @{ $self->{rtts} };
    $logger->debug( "input: $size " );
    my $stat = Statistics::Descriptive::Full->new();
    for ( my $i = 0; $i < $size; $i++ ) {
        $stat->add_data( $self->{rtts}[$i] );
    }
    push @{ $self->{rtt_stats} }, ( sprintf( "%0.3f", $stat->min() || '0.0' ), 
                                    sprintf( "%0.3f", $stat->max() || '0.0' ), 
                                    sprintf( "%0.3f", $stat->mean() || '0.0' ), 
				    sprintf( "%0.3f", $stat->median() || '0.0' ) );
    return $self->{rtt_stats};
}

# _ipdv_stats()
#
#calculates min, max, mean, iqr inter-packet delay values
#returns arrayref to the  list with (min, max, mean, IQR)   inter-packet delay values and interpacketquantile
#

sub _ipdv_stats {
    my $self = shift; 
    return unless($self->{rtts} && ref $self->{rtts} eq 'ARRAY');
    my $size = scalar @{ $self->{rtts} };
    $logger->debug( "input: $size" );
    my $stat = Statistics::Descriptive::Full->new();
    for ( my $i = 1; $i < $size; $i++ ) {
        my $ipd = $self->{rtts}[$i] - $self->{rtts}[ $i - 1 ];
        $ipd = abs( $ipd );
        $logger->debug( " adding $ipd" );
        $stat->add_data( $ipd );
    }
    my $iqr;
    if ( $stat->count ) {
        my $seventyfifth = $stat->percentile( 75 );
        my $twentyfifth  = $stat->percentile( 25 );
        if ( defined $seventyfifth && defined $twentyfifth ) {
            $iqr = $seventyfifth - $twentyfifth;
        }
    }
    push @{ $self->{ipdv_stats} }, ( sprintf( "%0.3f", $stat->min() || '0.0' ), sprintf( "%0.3f", $stat->max() || '0.0' ), sprintf( "%0.3f", $stat->mean() || '0.0' ), sprintf( "%0.3f", $iqr || '0.0' ) );
    return $self->{ipdv_stats};
}

### _dups
#
# duplicates and out-of-order packets calculation package
#
# return  arrayref to the list with two values where each value is enumerated string of 'false' or 'true'-
#      And first member of the list is for  duplicates and another one for out of order packets

sub _dups {
    my $self = shift;
    return unless($self->{seqs} && ref $self->{seqs} eq 'ARRAY');
    my $size = scalar @{ $self->{seqs} };
    $logger->debug( "input: sent $self->{sent}, recv $self->{received}, seqs  ($size)" );

    # dups and ooo
    my $dups = 0;
    my $ooo  = 0;

    # seen initiate with first element as loop doesn't
    # ooo
    my %seen = ( $self->{seqs}[0] => 1 );
    $logger->debug( "Searching for Out of Order packets" );

    #doubel check the input
    push @{ $self->{dups} }, ( undef, undef ) if ( $self->{seqs}[0] > $self->{sent} );

    for ( my $i = 1; $i < $size; $i++ ) {
        return ( undef, undef ) if ( $self->{seqs}[$i] > $self->{sent} );
        $logger->debug( " Looking at " . $self->{seqs}[$i] );
        if ( $self->{seqs}[$i] < $self->{seqs}[ $i - 1 ] ) {    # note < means that dups are not counted as out of order
            $logger->debug( " Found duplicate at $i / $self->{seqs}[$i]" );
            $ooo++;
        }

        # dups
        $seen{ $self->{seqs}[$i] }++;
    }
    $logger->debug( "Searching for Duplicate packets" );

    # analyse dups
    foreach my $k ( keys %seen ) {
        $logger->debug( " Saw packet #$k " . $seen{$k} . " times" );
        $dups++ if ( $seen{$k} > 1 );
    }
    push @{ $self->{dups} }, ( $dups == 0 ? 'false' : 'true', $ooo == 0 ? 'false' : 'true' );
    return $self->{dups};
}

###   _loss
#    calculates lost packets percentage, returns it
###

sub _loss {
    my $self = shift;
    $self->{received} = 0 unless defined $self->{received};
    if ( !$self->{sent} || $self->{sent} < $self->{received} ) {
        if ( $self->{sent} ) {
            $logger->debug( "Error in parsing loss with sent ($self->{sent}), received ($self->{received})" );
        }
        else {
            $logger->debug( "Error nothing sent" );
        }
        $self->{loss} = -1;
    }
    $self->{loss} = sprintf( "%0.3f", 100. - 100. * ( $self->{received} / $self->{sent} ) );
    return $self->{loss};
}

###   _clp
#    calculates  clp, returns it
###

sub _clp {
    my $self            = shift; 
    return unless($self->{seqs} && ref $self->{seqs} eq 'ARRAY');
    my $stringified_arr = join ",", @{ $self->{seqs} };
    my $size            = scalar @{ $self->{seqs} };

    $logger->debug( "Size: $size" );

    if ( $self->{received} != $size ) {
        $logger->debug( "pkts recvd ($self->{received}) is not equal to size $size of array $stringified_arr " );
        return $self->{clp} = undef;
    }
    return $self->{clp} = 0 unless $self->{sent};
    my $lost_packets            = $self->{sent} - $self->{received};
    return $self->{clp} = 0 unless $lost_packets && $lost_packets > 1;
    return $self->{clp} = 100 if $lost_packets == $self->{sent};
    ### lookup hash with sequence numbers as keys and sequence numbers + 1 as values
    ###  ( to get defined value for the first packet
    ###  duplicated packets will be considered as lost, reordered packets will be ignored
    ###  for example: 0 2 3 4 5 5 6 7 sequence with 8 packets sent and
    my %lookup_seq              = map { ( $_ + 1 ) => ( $_ + 1 ) } @{ $self->{seqs} };
    my $consecutive_packet_loss = 0;    
    $logger->debug( "input: sent  $self->{sent}  / recv  $self->{received}", sub{Dumper(\%lookup_seq)});
    $logger->debug( "Determining lost packets from sequence $stringified_arr" );
    for my $i ( 2 .. $self->{sent} ) {
        $logger->debug( " Looking at packet #$i " );
        unless ( $lookup_seq{ $i - 1 } ) {
            $consecutive_packet_loss++ unless $lookup_seq{$i};
            $logger->debug( "  Found lost packet #$i " );
        }
    }
    $logger->debug( "Determining Conditional Loss Probability where lost_packets=$lost_packets" );
    $self->{clp} = sprintf( "%0.3f", $consecutive_packet_loss * 100. /  $lost_packets  );
    $self->{plg} = sprintf( "%0.3f",  1./(1 -  $self->{clp}/100.)) if $self->{clp} < 100;    
    return $self->{clp};
}

1;

__END__

=head1 SEE ALSO

L<Data::Dumper>, L<Statistics::Descriptive>, L<Log::Log4perl>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: PingStats.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev maxim_at_fnal_dot_gov
Yee-Ting Li <ytl@slac.stanford.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2 , SLAC National Accelerator Laboratory, Fermitools

All rights reserved.

=cut
