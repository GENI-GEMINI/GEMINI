package   perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap;

use strict;
use warnings;
use version;our $VERSION = qv("v2.0");

=head1 NAME

perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap - element names to namespace prefix mapper

=head1 DESCRIPTION

this class designed to map element localname to registered namespace, the object of this
class is supposed to be member of the each PXB binded object in order to allow propagation of the
registered namespaces throughout the API

=head1 SYNOPSIS

        use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap;
	
	my $nsmap =  perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap->new();
	$nsmap->mapname($ELEMENT_LOCALNAME, 'ns_prefix');

=head1 METHODS

=head2 new({})

 new  - constructor, accepts single parameter - hashref with the hash of:
 
 <element_name> =>  <URI>,..., <element_name> =>  <URI>  #  mapped element on ns hashref
 
 the namespace registry track relation between namespace URI and used prefix

=cut

use Data::Dumper;
use Readonly;
use Log::Log4perl qw(get_logger);
use fields qw(nsmap);

Readonly::Scalar our $CLASSPATH => 'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap';
our $LOGGER =  get_logger($CLASSPATH);

sub new {
    my ($class, $param) = @_;
    $class = ref($class) || $class;
    my $self = fields::new($class);
    if ($param) {
        unless( ref($param) eq 'HASH') {
            $LOGGER->logdie("ONLY hash ref accepted as param and not: " . Dumper $param );
        }  
        foreach my $key (keys %{$param}) {
            $self->mapname($key => $param->{$key});
        }
    } else {
        $self->{nsmap} = {}; 
    }
    return $self;
}

=head2 mapname()

    maps localname on the prefix
    accepts:
        with single parameter ( element name ) it will return
       namespace prefix  and with two parameters it will map  namespace prefix
    to specific element name
    and without parameters it will return the whole namespaces hashref

=cut

sub mapname {
    my ($self, $element, $nsid) = @_;
    if ($element && $nsid) {
        $self->{nsmap}->{$element} = $nsid;
    return $self;
    } elsif($element && $self->{nsmap}->{$element} && !$nsid) {
        return $self->{nsmap}->{$element};
    } elsif(!$nsid && !$element) {
        return $self->{nsmap};
    }
    return;
}




=head2 get_nsmap

 accessor  for nsmap, assumes hash based class

=cut

sub get_nsmap {
    my($self) = @_;
    return $self->{nsmap};
}

=head2 set_nsmap

mutator for nsmap, assumes hash based class

=cut

sub set_nsmap {
    my($self,$value) = @_;
    if($value) {
        $self->{nsmap} = $value;
    }
    return   $self->{nsmap};
}



1;

__END__


=head1  SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

   https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

   http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

   http://code.google.com/p/perfsonar-ps/issues/list
   

=head1 AUTHOR

Maxim Grigoriev

=head1 COPYRIGHT

Copyright (c) 2008, Fermi Research Alliance (FRA)

=head1 LICENSE

You should have received a copy of the Fermitool license along with this software.

=cut


