use Log::Log4perl qw( get_logger );

package gmaps::Graph::RRD::PingER;
use base 'gmaps::Graph::RRD';


our $logger = Log::Log4perl->get_logger("gmaps::Graph::RRD::PingER" );


=head2 getGraphArgs
returns the rrd graph arguments to produce a graph of utilisation data
=cut
sub graphArgs
{
	my $self = shift;
	my $start = shift;
	my $end = shift;
	

	my @args = ();
	push @args, '--end=' . $end;
	push @args, '--start=' . $start;
	push @args, '--vertical-label=msec';
	foreach my $field ( qw/ minRtt meanRtt iqrIpd meanIpd / ) {
		push @args, 'DEF:' . $field . '=' . $self->{FILENAME} . ':' . $field . ':AVERAGE';
	}

	# do some colourful representation of metrics	
	push @args, 'CDEF:jitterIqrRange=iqrIpd,2,*',
				'CDEF:jitterIqrStart=meanRtt,iqrIpd,-',
				'CDEF:jitterMeanRange=meanIpd,2,*',
				'CDEF:jitterMeanStart=meanRtt,meanIpd,-',
				'LINE1:jitterMeanStart',
				'AREA:jitterMeanRange#FF9900:meanIpd:STACK',
				'LINE1:jitterIqrStart',
				'AREA:jitterIqrRange#FF0000:iqrIpd:STACK',
				'LINE1:meanRtt#000000:meanRtt',
				'LINE2:minRtt#00FF00:minRtt';
	
	$logger->debug( "args: @args" );
	
	return \@args;
	
}

1;