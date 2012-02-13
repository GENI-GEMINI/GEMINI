#!/bin/env perl

#######################################################################
# quick hack to create rrd graphs
#######################################################################

use Log::Log4perl qw( get_logger :levels );

use RRDs;
package utils::rrd;
our $logger = Log::Log4perl->get_logger("utils::rrd" );

use strict;



sub new {
    my $class = shift;
    
    my $self  = { };
    bless( $self, $class );

	$self->{filename} = shift;    
    $self->{startTime} = shift;
    $self->{entries} = shift;

    $logger->debug( "Creating rrd file $self->{filename}, start time $self->{startTime}, number of entries $self->{entries}" );    

    # args
    my @args = ();
    push @args, "--start=" . $self->{startTime};
    push @args, "DS:in:GAUGE:500:0:U";
    push @args, "DS:out:GAUGE:500:0:U";
    push @args, "RRA:AVERAGE:0:1:" . $self->{entries};
    
    # create the rrd here
    RRDs::create $self->{filename}, @args;
 	my $ans = RRDs::error;
	$logger->logdie( "Error creating rrd " . $self->{filename} .  ": $ans." )
		if defined $ans || $ans ne '';   
    
    return $self;
}


sub DESTROY
{
	my $self = shift;
	unlink $self->{'filename'};
	unlink $self->{'png'};
	return;
}




sub add
{
	my $self = shift;
	my $time = shift;
	my $template = shift;
	my @values = @_;

	# run the update
	my $file = $self->{filename};
	my $args = $time . ':' . join( ':', @values);
	
	RRDs::update	$self->{filename},
					'--template=' . $template,
				 	$args;
#	`/usr/bin/rrdtool update $file --template=$template $args`;

	my $ans = RRDs::error;

	if( defined $ans || $ans ne '' ) {
		return undef if $ans =~ /illegal attempt to update using time/;
		$logger->warn( "Error updating " . $self->{filename} . " $ans.\n" );
	} else {
		$logger->debug( "adding to " . $self->{filename} . " --template=$template $args");
	}
	
	return undef;
}


sub getGraph
{
	my $self = shift;
	my $png = shift;
	my $start = shift;
	my $end = shift;
	
	my $rpn = shift;
	
	# assume bytes
	$rpn = ',8,*'
		if ! defined $rpn;
	
	my @args = ();
	push @args, '--end=' . $end;
	push @args, '--start=' . $start;
	push @args, '--vertical-label=bits/sec';
	push @args, 'DEF:in=' . $self->{filename} . ':in:AVERAGE';
	push @args, 'DEF:out=' . $self->{filename} . ':out:AVERAGE';
	push @args, 'CDEF:inBits=in' . $rpn;
	push @args, 'CDEF:outBits=out' . $rpn;
	
	# graph sepcs
	push @args, 'AREA:inBits#00FF00:in';
	push @args, 'LINE2:outBits#0000FF:out';

	$logger->debug( "args: @args" );

	$self->{'png'} = $png;
	RRDs::graph $png, @args;
	
	my $ans = RRDs::error;
	$logger->fatal( "Error graphing " . $self->{filename} . " $ans.\n" )
		if $ans ne undef || $ans ne '';

	# cat out the png to a variable
	open( PNG, "<$png") or $logger->fatal( "Could not fetch graph: $!\n" );
	my $out = undef;
	while( <PNG> ) {
		$out .= $_;
	}
	close PNG;

	return \$out;
}

1;



