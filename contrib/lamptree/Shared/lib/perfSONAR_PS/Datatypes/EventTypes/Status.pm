package perfSONAR_PS::Datatypes::EventTypes::Status;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Datatypes::EventTypes::Status 

=head1 DESCRIPTION

A container for various perfSONAR http://schemas.perfsonar.net/status/
eventtypes.  The purpose of this module is to  create OO interface for status
eventtypes  and therefore add the layer of abstraction for any  status
eventtypes related operation ( mostly for perfSONAR response).  All perfSONAR-PS
classes should work with the instance of this class and avoid using explicit
eventtype  declarations. 

=head1 Methods

There is accessor mutator for every defined  status

=cut

use Log::Log4perl qw(get_logger);
use Class::Accessor;
use Class::Fields;
use base qw(Class::Accessor Class::Fields);
use fields qw( success failure operation);
perfSONAR_PS::Datatypes::EventTypes::Status->mk_accessors( perfSONAR_PS::Datatypes::EventTypes::Status->show_fields( 'Public' ) );

use constant {
    CLASSPATH => "perfSONAR_PS::Datatypes::EventTypes::Status",
    STATUS    => "http://schemas.perfsonar.net/status",
    RELEASE   => "1.0"
};

=head2 new('operationName')

Creates a new object, accepts scalar operation name, if missed then default is
'echo'
    
=cut

sub new {
    my $that      = shift;
    my $operation = shift;

    my $logger = get_logger( CLASSPATH );

    if ( $operation && !ref( $operation ) ) {
        $logger->error( "ONLY single scalar parameter accepted" . $operation );
        return undef;
    }
    my $class = ref( $that ) || $that;
    my $self = fields::new( $class );
    $operation = 'echo' unless $operation;
    $self->_init( $operation );
    return $self;

}

=head2 _init

initialize status types with operation
    
=cut

sub _init {
    my $self      = shift;
    my $operation = shift;
    foreach my $tool ( qw/success failure/ ) {
        $self->{$tool} = STATUS . "/$tool/$operation/" . RELEASE . "/";
    }

}

=head2 operation('operationName')

Resets  current operation or returns it if argument is missed 
    
=cut

sub operation {
    my $self      = shift;
    my $operation = shift;
    if ( $operation ) {
        $self->_init( $operation );
    }
    else {
        return $self->{operation};
    }
}

1;

__END__

=head1 SYNOPSIS
 
    use perfSONAR_PS::Datatypes::EventTypes::Status; 
    
    # create Status eventtype object with default URIs
    my $sd_status = perfSONAR_PS::Datatypes::EventTypes::Status->new('setupdata');
     
    print  $sd_status->success
    # will print: "http://schemas.perfsonar.net/status/success/setupdata/1.0/"
    # overwrite only specific Namesapce   with  custom URI 
       
=head2  Supported Status:  
 
success / failure 
   
=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Status.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
