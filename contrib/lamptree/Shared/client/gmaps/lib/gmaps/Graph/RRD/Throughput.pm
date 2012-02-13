use Log::Log4perl qw( get_logger );

package gmaps::Graph::RRD::Throughput;
use base 'gmaps::Graph::RRD';


our $logger = Log::Log4perl->get_logger("gmaps::Graph::RRD::Throughput" );






=head2 getGraphArgs
returns the rrd graph arguments to produce a graph of utilisation data
=cut
sub graphArgs
{
	my $self = shift;
	my $start = shift;
	my $end = shift;
	
	# assume bytes
	my $rpn = ',1,*';

	my @args = ();
	push @args, '--end=' . $end;
	push @args, '--start=' . $start;
	push @args, '--vertical-label=bps';
	foreach my $field ( @{$self->{FIELDS}}) {
		push @args, 'DEF:' . $field . '=' . $self->{FILENAME} . ':' . $field . ':AVERAGE';
		push @args, 'CDEF:' . $field . 'RPN' . '=' . $field . $rpn;	
	}
	
	# graph sepcs
	push @args, 'AREA:outRPN' . '#0000FF' . ':out';
	
	$logger->debug( "args: @args" );
	
	return \@args;
	
}

1;
