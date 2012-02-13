use Log::Log4perl qw( get_logger );
use RRDs;

=head1 NAME

gmaps::Graph::RRD - A wrapper class around rrd creation and graphing

=head1 DESCRIPTION

This module provides functions to quickly and easily create rrd files from a 
subset of data. It should be inherited to allow custom graphing to suit
different types of data.

=head1 SYNOPSIS

    use gmaps::Graph::RRD;
    
    # create a new graph object
    my $rrd = gmaps::Graph::RRD->new(
    				'/tmp/test/rrd',
    				$startTime,
    				$resolution,
    				$numberOfEntries,
    				@dataSourceNames ); 
				);

	$rrd->add( $time, { ds_name => 'value', ... })  

=head1 DETAILS

This API is a work in progress, and still does not reflect the general access needed in an MA.
Additional logic is needed to address issues such as different backend storage facilities.  

=head1 API

The offered API is simple, but offers the key functions we need in a measurement archive. 

=cut

package gmaps::Graph::RRD;

use fields qw( FILENAME STARTTIME RESOLUTION ENTRIES FIELDS WIDTH HEIGHT );

our $logger = Log::Log4perl->get_logger("gmaps::Graph::RRD" );

use File::Temp qw(tempfile);

use strict;



sub new {
    my gmaps::Graph::RRD $self = shift;
    my @args  = @_;
	my $params = Params::Validate::validate( @args, { filename => 1, startTime => 1, resolution => 1, entries => 1, fields => 1, width => 0, height => 0 } );
    
    unless ( ref $self ) {
		$self = fields::new( $self );
    }
    
	$self->{FILENAME} = $params->{filename};    
    $self->{STARTTIME} = $params->{startTime};
    $self->{RESOLUTION} = $params->{resolution};
    $self->{ENTRIES} = $params->{entries};
	@{$self->{FIELDS}} = @{$params->{fields}};
    $self->{WIDTH} = $params->{width} || 300;
    $self->{HEIGHT} = $params->{height} || 55;
    
    $logger->debug( "Creating rrd file $self->{FILENAME}, start time $self->{STARTTIME}, number of entries $self->{ENTRIES}, with @{$self->{FIELDS}}" );    

    # args
    my @args = ();

    my $start = $self->{STARTTIME} -1;
    push @args, "--start=" . $start;
	push @args, "--step=" . $self->{RESOLUTION};
    
    foreach my $field ( @{$self->{FIELDS}} ) {
	    push @args, "DS:" . $field . ":GAUGE:" . $self->{RESOLUTION} . ":0:U";
    }
    push @args, "RRA:AVERAGE:0:1:" . $self->{ENTRIES};
    
    $logger->debug( "RRD creation args: '@args'" );
    
    # create the rrd here
    RRDs::create $self->{FILENAME}, @args;
 	my $ans = RRDs::error;
	$logger->logdie( "Error creating rrd " . $self->{FILENAME} .  ": $ans." )
		if defined $ans || $ans ne '';   
    
    $logger->debug( "Created rrd $self->{FILENAME} with @args ");
    
    return $self;
}


sub DESTROY
{
	my $self = shift;
	unlink $self->{'FILENAME'};
	#$logger->warn( "PNG File: " . $self->{FILENAME} );
	unlink $self->{'PNG'};
	return;
}




sub add
{
	my $self = shift;
	my $time = shift;
	my $hash = shift;

	# run the update
	my $file = $self->{FILENAME};
	
	my @template = ();
	my @values = ();
	while( my ($k,$v) = each %$hash ) {
		push @template, $k;
		push @values, $v;
	}
	
	my $template = '--template=' . join( ':', @template );
	my $args = $time . ':' . join( ':', @values);
	RRDs::update	$self->{FILENAME},
					$template,
				 	$args;

	my $ans = RRDs::error;

	if( defined $ans || $ans ne '' ) {
		$logger->warn( "Error updating " . $self->{FILENAME} . " with $template $args: $ans.\n" );
		return undef if $ans =~ /illegal attempt to update using time/;
	}
	
	$logger->debug( "adding to " . $self->{FILENAME} . " $template $args" );
	
	return 0;
}



sub graphArgs
{
	my $self = shift;
	my $start = shift;
	my $end = shift;
	
	
	# assume bytes
	my $rpn = ',1,*';

	my @colours = qw( 00FF00 0000FF FF0000 );
	
	my @args = ();
	push @args, '--end=' . $end;
	push @args, '--start=' . $start;
	push @args, '--vertical-label=units';
    
	
	foreach my $field ( @{$self->{FIELDS}}) {
		push @args, 'DEF:' . $field . '=' . $self->{FILENAME} . ':' . $field . ':AVERAGE';
		push @args, 'CDEF:' . $field . 'RPN' . '=' . $field . $rpn;	
	}
	
	# graph sepcs
	my $c = 0;
	foreach my $field ( @{$self->{FIELDS}}) {
		push @args, 'LINE2:' .$field.'RPN' . '#' . $colours[$c] . ':' . $field;
		$c++;
		$c = 0 
			if $c >= ( scalar @colours )
	}
	
	$logger->debug( "args: @args" );
	
	return \@args;	
}

sub getGraph
{
	my $self = shift;
	my $start = shift;
	my $end = shift;
	my $png = shift;
	my $graphArgs = shift; # array ref

	my $delete = 0;
	# use temp png if not defined
	if ( ! defined $png ) {
		( undef, $png ) = tempfile( '/tmp/XXXXXXXX', UNLINK => 0 );
		$delete = 1;
	}
	
	# graph
	
	if ( ! defined $graphArgs ) {
		$graphArgs = $self->graphArgs( $start, $end );
	}
	
	my @args = ();
#	push @args, "--full-size-mode";
    push @args, "--width=" . $self->{WIDTH};
    push @args, "--height=" . $self->{HEIGHT};
	
	push @args, @$graphArgs;
	
	RRDs::graph $png, @args;
	
	my $ans = RRDs::error;
	die( "Error graphing " . $self->{FILENAME} . " using '@$graphArgs': $ans" )
		if $ans ne undef || $ans ne '';

	# cat out the png to a variable
	open( PNG, "<$png") or die( "Could not fetch graph: $!\n" );
	my $out = undef;
	while( <PNG> ) {
		$out .= $_;
	}
	close PNG;
	
	if ( $delete ) {
		unlink $png or $logger->warn( "Could not remove temp file '$png'");
	}

	return \$out;
}

1;



