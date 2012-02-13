package perfSONAR_PS::Services::MP::Agent::ConstantValue;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::MP::Agent::ConstantValue

=head1 DESCRIPTION

A perfsonar MP Agent class that returns a constant value.  This module returns
a constant value. It inherits from perfSONAR_PS::MP::Agent::Base to provide a
consistent interface.

=cut

use perfSONAR_PS::Common;

# derive from the base agent class
use perfSONAR_PS::Services::MP::Agent::Base;
our @ISA = qw(perfSONAR_PS::Services::MP::Agent::Base);

use Log::Log4perl qw(get_logger);
our $logger = Log::Log4perl::get_logger( 'perfSONAR_PS::Services::MP::Agent::ConstantValue' );

=head2 new( $value )

Creates a new agent class

  $value = constant value to set

=cut

sub new {
    my ( $package, $value ) = @_;
    my %hash = ();

    $hash{"RESULTS"} = $value if defined $value;

    bless \%hash => $package;
}

=head2 init()

No initiation needed, do nothing

=cut

sub init {
    my $self = shift;
    return 0;
}

=head2 collectMeasurements( )

Always okay as long as the constant value is set.

 -1 = something failed
  0 = command ran okay

=cut

sub collectMeasurements {
    my ( $self ) = @_;

    if ( defined $self->results() ) {
        $logger->debug( "Collecting constant value '" . $self->results() . "'" );
        return 0;
    }
    else {
        $self->error( "No constant value defined" );
        $logger->error( $self->error() );
        return -1;
    }
}

=head2 results( )

Returns the results (ie the constant value assigned in the constructor). No need to redefine 
here as it's inherited.

=cut

1;

__END__

=head1 SYNOPSIS

  # create and setup a new Agent  
  my $agent = perfSONAR_PS::Services::MP::Agent::ConstantValue( 5 );
  
  # collect the results (i.e. run the command)
  if( $mp->collectMeasurements() == 0 )
  {
  	
  	# get the raw datastructure for the measurement
  	print "Results:\n" . $self->results() . "\n";

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

$Id: ConstantValue.pm 2640 2009-03-20 01:21:21Z zurawski $

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
