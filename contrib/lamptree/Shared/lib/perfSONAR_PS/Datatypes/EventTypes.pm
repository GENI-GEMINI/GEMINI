package perfSONAR_PS::Datatypes::EventTypes;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

EventTypes

=head1 DESCRIPTION

A container for various perfSONAR eventtypes.  The purpose of this module is to
create OO interface to eventtype registration and therefore add the layer of
abstraction for any eventtype related operation.  All perfSONAR-PS classes
should work with the instance of this class and avoid using explicit eventtype
declarations. 

=head1 Methods

=cut

use Readonly;
use Log::Log4perl qw(get_logger);
use perfSONAR_PS::Datatypes::EventTypes::Tools;
use perfSONAR_PS::Datatypes::EventTypes::Characteristics;
use perfSONAR_PS::Datatypes::EventTypes::Ops;
use perfSONAR_PS::Datatypes::EventTypes::Status;
use Class::Accessor;
use Class::Fields;
use base qw(Class::Accessor Class::Fields);
use fields qw( tools  characteristics ops status);
perfSONAR_PS::Datatypes::EventTypes->mk_accessors( perfSONAR_PS::Datatypes::EventTypes->show_fields( 'Public' ) );

Readonly::Scalar our $CLASSPATH => "perfSONAR_PS::Datatypes::EventTypes";

=head2 new({})

Creates a new object, accepts only single parameter - hash ref

=cut

sub new {
    my ( $that, $param ) = @_;
    my $logger = get_logger( $CLASSPATH );

    if ( $param && ref( $param ) ne 'HASH' ) {
        $logger->error( "ONLY hash ref  parameter accepted: " . $param );
        return;
    }
    my $class = ref( $that ) || $that;
    my $self = fields::new( $class );
    $self->tools( perfSONAR_PS::Datatypes::EventTypes::Tools->new() );
    $self->characteristics( perfSONAR_PS::Datatypes::EventTypes::Characteristics->new() );
    $self->ops( perfSONAR_PS::Datatypes::EventTypes::Ops->new() );
    $self->status( perfSONAR_PS::Datatypes::EventTypes::Status->new( ( ( $param && $param->{operation} ) ? $param->{operation} : q{} ) ) );

    return $self;
}

1;

__END__

=head1 SYNOPSIS
 
    use perfSONAR_PS::Datatypes::EventTypes; 
    use perfSONAR_PS::Datatypes::EventTypes::Tools; 
    use perfSONAR_PS::Datatypes::EventTypes::Ops;
    use perfSONAR_PS::Datatypes::EventTypes::Characteristics; 
     
    my $tool = perfSONAR_PS::Datatypes::EventTypes::Tools->new({'pinger' => 'http://ogf.org/ns/nmwg/pinger/3.0 '});
   
    # create  EventTypes object and pass operation name to status class
    my $event= perfSONAR_PS::Datatypes::EventTypes->new({ operation => 'setupdata'});
    
    # overwrite only specific EventType  with  custom  one  
    $pinger_tool = $event->tools->pinger; ## get URI by key
    $event->tools->pinger('http://newpinger/eventtype/'); ## set URI for pinger key
    
=head1 API

There are get/set methods for tools and characteristics  fields
 
=head2 Supported Accessors/Mutators

tools, characteristics, ops, status
 
=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: EventTypes.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
