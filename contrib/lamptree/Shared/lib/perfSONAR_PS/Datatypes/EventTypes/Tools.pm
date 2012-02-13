package perfSONAR_PS::Datatypes::EventTypes::Tools;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Datatypes::EventTypes::Tools

=head1 DESCRIPTION

A container for various perfSONAR http://ggf.org/ns/nmwg/tools/ eventtypes.  The
purpose of this module is to  create OO interface for tools eventtypes  and
therefore add the layer of abstraction for any tools eventtypes  related
operation ( mostly for perfSONAR response).  All  perfSONAR-PS classes should
work with the instance of this class and avoid using explicit   eventtype
declarations. 

=head1 Methods

There is accessor mutator for every defined Characteristic
 
=cut

use Log::Log4perl qw(get_logger);
use Class::Accessor;
use Class::Fields;
use base qw(Class::Accessor Class::Fields);
use fields qw( snmp pinger traceroute ping owamp bwctl  iperf);
perfSONAR_PS::Datatypes::EventTypes::Tools->mk_accessors( perfSONAR_PS::Datatypes::EventTypes::Tools->show_fields( 'Public' ) );

use constant {
    CLASSPATH => "perfSONAR_PS::Datatypes::EventTypes::Tools",
    TOOL      => "http://ggf.org/ns/nmwg/tools",
    RELEASE   => "2.0"
};

=head2 new( )

Creates a new object, pass hash ref as collection of event types for tools namespace
    
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
        $self->{$tool} = TOOL . "/$tool/" . RELEASE . "/";
    }
    return $self;
}

1;

__END__

=head1 SYNOPSIS
 
    use perfSONAR_PS::Datatypes::EventTypes::Tools; 
    
    # create Tools eventtype object with default URIs
    my $tools_event = perfSONAR_PS::Datatypes::EventTypes::Tools->new();
     
    
    # overwrite only specific Namesapce   with  custom URI 
    
    $tools_event  = perfSONAR_PS::Datatypes::EventTypes::Tools->new( {'pinger' => 'http://ggf.org/ns/nmwg/tools/pinger/2.0'});
      
    my $pinger_tool = $tools_event->pinger; ## get URI by key
    
    $tools_event->pinger(  'http://ggf.org/ns/nmwg/tools/pinger/2.0'); ## set URI by key
  
=head2  Supported Tools:  
 
'pinger'  'traceroute','snmp', 'ping', 'owamp',   'bwctl', 'pinger', 'iperf'
   
=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Tools.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
