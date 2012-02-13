package perfSONAR_PS::Datatypes::EventTypes::Characteristics;
{

    use strict;
    use warnings;

    use version;
    our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Datatypes::EventTypes::Characteristics

=head1 DESCRIPTION

A container for various perfSONAR http://ggf.org/ns/nmwg/characteristics/
eventtypes The purpose of this module is to  create OO interface for
characteristics eventtypes  and therefore add the layer of abstraction for any
characteristic eventtype  ( mostly for perfSONAR response).  All perfSONAR-PS
classes should work with the instance of this class and avoid using explicit
eventtype declarations. 

=head1 Methods

There is accessor mutator for every defined Characteristic

=cut

    use Log::Log4perl qw(get_logger);
    use Class::Accessor;
    use Class::Fields;
    use base qw(Class::Accessor Class::Fields);
    use fields qw(name errors utilization discards pinger minRtt maxRtt medianRtt meanRtt lossPercents duplicates outOfOrder clp iqrIpd meanIpd minIpd maxIpd);
    perfSONAR_PS::Datatypes::EventTypes::Characteristics->mk_accessors( perfSONAR_PS::Datatypes::EventTypes::Characteristics->show_fields( 'Public' ) );

    use constant {
        CLASSPATH      => "perfSONAR_PS::Datatypes::EventTypes::Characteristics",
        CHARACTERISTIC => "http://ggf.org/ns/nmwg/characteristic",
        RELEASE        => "2.0"
    };

=head2 new( )

Creates a new object, pass hash ref as hash  of event type => characteristic URI

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
        foreach my $char ( $self->show_fields( 'Public' ) ) {
            $self->{$char} = CHARACTERISTIC . "/$char/" . RELEASE . "/";
        }
        return $self;

    }

}

1;

__END__ 

=head1 SYNOPSIS
 
    use perfSONAR_PS::Datatypes::EventTypes::Characteristics; 
    # create Characteristics eventtype object with default URIs
    my $characteristics_event = perfSONAR_PS::Datatypes::EventTypes::Characteristics->new();
    
    # overwrite only specific Namesapce   with  custom URI 
    
    $characteristics_event  = perfSONAR_PS::Datatypes::EventTypes::Characteristics->new( {'pinger' => 'http://ggf.org/ns/nmwg/characteristics/pinger/2.0'});
      
    my $pinger_event = $characteristics_event->pinger; ## get URI by key
    $characteristics_event->pinger('http://ggf.org/ns/nmwg/characteristics/pinger/2.0'); ## set URI by key
    
=head2  Supported Characteristics  
 
errors utilization discards pinger minRtt maxRtt medianRtt meanRtt lossPercents duplicates outOfOrder clp iqrIpd meanIpd minIpd maxIpd 

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Characteristics.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
