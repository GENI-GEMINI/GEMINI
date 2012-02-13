use Log::Log4perl qw( get_logger );

package gmaps::Graph::RRD::Latency;
use base 'gmaps::Graph::RRD';


our $logger = Log::Log4perl->get_logger("gmaps::Graph::RRD::Latency" );






=head2 getGraphArgs
returns the rrd graph arguments to produce a graph of utilisation data
=cut
sub graphArgs
{
	my $self = shift;
	my $start = shift;
	my $end = shift;
	
	# assume bytes
	my $rpn = ',8,*';

	my @args = ();
	push @args, '--end=' . $end;
	push @args, '--start=' . $start;
	push @args, '--vertical-label=msec';
	foreach my $field ( qw/ min_delay max_delay loss sent / ) {
		push @args, 'DEF:' . $field . '=' . $self->{FILENAME} . ':' . $field . ':AVERAGE';
	}
	
	# graph sepcs
	# do some colourful representation of metrics	
	push @args, 'CDEF:min=min_delay',
				'CDEF:max=max_delay',
				'CDEF:lostPackets=loss,sent,/',
				'CDEF:lost000=lostPackets,0,GT,INF,0,IF',
				'CDEF:lost001=lostPackets,1,GE,INF,0,IF',
				'CDEF:lost005=lostPackets,5,GE,INF,0,IF',
				'CDEF:lost010=lostPackets,10,GE,INF,0,IF',
				'CDEF:lost020=lostPackets,20,GE,INF,0,IF',
				'CDEF:lost030=lostPackets,30,GE,INF,0,IF',
				'CDEF:lost040=lostPackets,40,GE,INF,0,IF',
				'CDEF:lost050=lostPackets,50,GE,INF,0,IF',
				'CDEF:lost060=lostPackets,60,GE,INF,0,IF',
				'CDEF:lost070=lostPackets,70,GE,INF,0,IF',
				'CDEF:lost080=lostPackets,80,GE,INF,0,IF',
				'CDEF:lost090=lostPackets,90,GE,INF,0,IF',
				'CDEF:lost100=lostPackets,100,EQ,INF,0,IF',
				'COMMENT:loss\:',
                'AREA:lost000#08589E:>0%',
                'AREA:lost001#365EA8:>1%',
                'AREA:lost005#4F94CD:>5%',
                'AREA:lost010#FFED99:>10%',
                'AREA:lost020#FFD976:>20%',
                'AREA:lost030#FEB24C:>30%',
                'AREA:lost040#FD8D3C:>40%',
                'AREA:lost050#FE4D29:>50%',
                'AREA:lost060#E31A1C:>60%',
                'AREA:lost070#D80024:>70%',
                'AREA:lost080#790024:>80%',
                'AREA:lost090#62000C:>90%',
                'AREA:lost100#000000:100%\n',
                'COMMENT:latency\:',
				'LINE2:min#006600:min',
				'LINE2:max#00FF00:max';
	
	$logger->debug( "args: @args" );
	
	return \@args;
	
}

1;