package perfSONAR_PS::Datatypes::EventTypes::Ops;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Datatypes::EventTypes::Ops

=head1 DESCRIPTION

A container for various perfSONAR http://ggf.org/ns/nmwg/ops/ eventtypes.  The
purpose of this module is to  create OO interface for ops eventtypes  and
therefore add the layer of abstraction for any ops eventtypes  related operation
( mostly for perfSONAR response).  All  perfSONAR-PS classes should work with
the instance of this class and avoid using explicit   eventtype  declarations. 

=head1 Methods

There is accessor mutator for every defined Characteristic

=cut

use Log::Log4perl qw(get_logger);
use Class::Accessor;
use Class::Fields;
use base qw(Class::Accessor Class::Fields);
use fields qw( select average histogram cdf median max min mean);
perfSONAR_PS::Datatypes::EventTypes::Ops->mk_accessors( perfSONAR_PS::Datatypes::EventTypes::Ops->show_fields( 'Public' ) );

use constant {
    CLASSPATH => "perfSONAR_PS::Datatypes::EventTypes::Ops",
    OPS       => "http://ggf.org/ns/nmwg/ops",
    RELEASE   => "2.0"
};

=head2 new( )

Creates a new object, pass hash ref as collection of event types for ops
namespace
    
=cut

sub new {
    my $that  = shift;
    my $param = shift;

    my $logger = get_logger( CLASSPATH );

    if ( $param && ref( $param ) ne 'HASH' ) {
        $logger->error( "ONLY hash ref accepted as param " . $param );
        return undef;
    }
    my $class = ref( $that ) || $that;
    my $self = fields::new( $class );
    foreach my $tool ( $self->show_fields( 'Public' ) ) {
        $self->{$tool} = OPS . "/$tool/" . RELEASE . "/";
    }
    return $self;

}

1;

__END__

=head1 SYNOPSIS
 
    use perfSONAR_PS::Datatypes::EventTypes::Ops; 
    
    # create Ops eventtype object with default URIs
    my $ops_event = perfSONAR_PS::Datatypes::EventTypes::Ops->new();
     
    
    # overwrite only specific Namesapce   with  custom URI 
    
    $ops_event  = perfSONAR_PS::Datatypes::EventTypes::Ops->new( {'select' => 'http://ggf.org/ns/nmwg/ops/select/2.0'});
      
    my $select_event = $ops_event->select; ## get URI by key
    
    $ops_event->pinger(  'http://ggf.org/ns/nmwg/ops/select/2.0'); ## set URI by key
  
=head2  Supported Ops:  
 
'select'  'average','histogram', 'cdf'  'median''max' 'min'    'mean'
   
=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Ops.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
