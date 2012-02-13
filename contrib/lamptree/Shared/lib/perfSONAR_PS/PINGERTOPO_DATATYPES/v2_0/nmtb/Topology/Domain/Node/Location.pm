package  perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location  -  this is data binding class for  'location'  element from the XML schema namespace nmtb

=head1 DESCRIPTION

Object representation of the location element of the nmtb XML namespace.
Object fields are:


    Object reference:   continent => type ,
    Object reference:   country => type ,
    Object reference:   zipcode => type ,
    Object reference:   state => type ,
    Object reference:   institution => type ,
    Object reference:   city => type ,
    Object reference:   streetAddress => type ,
    Object reference:   floor => type ,
    Object reference:   room => type ,
    Object reference:   cage => type ,
    Object reference:   rack => type ,
    Object reference:   shelf => type ,
    Object reference:   latitude => type ,
    Object reference:   longitude => type ,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'location' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap;
use fields qw(nsmap idmap LOGGER   continent country zipcode state institution city streetAddress floor room cage rack shelf latitude longitude);


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:


returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location';
Readonly::Scalar our $LOCALNAME => 'location';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'nmtb');


    if($param) {
        if(blessed $param && $param->can('getName')  && ($param->getName =~ m/$LOCALNAME$/xm) ) {
            return  $self->fromDOM($param);
        } elsif(ref($param) ne 'HASH')   {
            $self->get_LOGGER->logdie("ONLY hash ref accepted as param " . $param );
            return;
        }
        if($param->{xml}) {
            my $parser = XML::LibXML->new();
	    $parser->expand_xinclude(1);
            my $dom;
            eval {
                my $doc = $parser->parse_string($param->{xml});
                $dom = $doc->getDocumentElement;
            };
            if($EVAL_ERROR) {
                $self->get_LOGGER->logdie(" Failed to parse XML :" . $param->{xml} . " \n ERROR: \n" . $EVAL_ERROR);
                return;
            }
            return  $self->fromDOM($dom);
        }
        $self->get_LOGGER->debug("Parsing parameters: " . (join ' : ', keys %{$param}));

        foreach my $param_key (keys %{$param}) {
            $self->{$param_key} = $param->{$param_key} if $self->can("get_$param_key");
        }
        $self->get_LOGGER->debug("Done");
    }
    return $self;
}

=head2   getDOM ($parent)

 accepts parent DOM  serializes current object into the DOM, attaches it to the parent DOM tree and
 returns location object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $location;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $location = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                               ],
                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }


    foreach my $textnode (qw/continent country zipcode state institution city streetAddress floor room cage rack shelf latitude longitude/) {
        if($self->{$textnode}) {
            my  $domtext  =  getElement({name => $textnode,
                                          parent => $location,
                                          ns => [$self->get_nsmap->mapname($LOCALNAME)],
                                          text => $self->{$textnode},
                              });
           $domtext?$location->appendChild($domtext):
	             $self->get_LOGGER->logdie("Failed to append new text element $textnode to location");
        }
    }
        
      return $location;
}


=head2 get_LOGGER

 accessor  for LOGGER, assumes hash based class

=cut

sub get_LOGGER {
    my($self) = @_;
    return $self->{LOGGER};
}

=head2 set_LOGGER

mutator for LOGGER, assumes hash based class

=cut

sub set_LOGGER {
    my($self,$value) = @_;
    if($value) {
        $self->{LOGGER} = $value;
    }
    return   $self->{LOGGER};
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



=head2 get_idmap

 accessor  for idmap, assumes hash based class

=cut

sub get_idmap {
    my($self) = @_;
    return $self->{idmap};
}

=head2 set_idmap

mutator for idmap, assumes hash based class

=cut

sub set_idmap {
    my($self,$value) = @_;
    if($value) {
        $self->{idmap} = $value;
    }
    return   $self->{idmap};
}



=head2 get_text

 accessor  for text, assumes hash based class

=cut

sub get_text {
    my($self) = @_;
    return $self->{text};
}

=head2 set_text

mutator for text, assumes hash based class

=cut

sub set_text {
    my($self,$value) = @_;
    if($value) {
        $self->{text} = $value;
    }
    return   $self->{text};
}



=head2 get_continent

 accessor  for continent, assumes hash based class

=cut

sub get_continent {
    my($self) = @_;
    return $self->{continent};
}

=head2 set_continent

mutator for continent, assumes hash based class

=cut

sub set_continent {
    my($self,$value) = @_;
    if($value) {
        $self->{continent} = $value;
    }
    return   $self->{continent};
}



=head2 get_country

 accessor  for country, assumes hash based class

=cut

sub get_country {
    my($self) = @_;
    return $self->{country};
}

=head2 set_country

mutator for country, assumes hash based class

=cut

sub set_country {
    my($self,$value) = @_;
    if($value) {
        $self->{country} = $value;
    }
    return   $self->{country};
}



=head2 get_zipcode

 accessor  for zipcode, assumes hash based class

=cut

sub get_zipcode {
    my($self) = @_;
    return $self->{zipcode};
}

=head2 set_zipcode

mutator for zipcode, assumes hash based class

=cut

sub set_zipcode {
    my($self,$value) = @_;
    if($value) {
        $self->{zipcode} = $value;
    }
    return   $self->{zipcode};
}



=head2 get_state

 accessor  for state, assumes hash based class

=cut

sub get_state {
    my($self) = @_;
    return $self->{state};
}

=head2 set_state

mutator for state, assumes hash based class

=cut

sub set_state {
    my($self,$value) = @_;
    if($value) {
        $self->{state} = $value;
    }
    return   $self->{state};
}



=head2 get_institution

 accessor  for institution, assumes hash based class

=cut

sub get_institution {
    my($self) = @_;
    return $self->{institution};
}

=head2 set_institution

mutator for institution, assumes hash based class

=cut

sub set_institution {
    my($self,$value) = @_;
    if($value) {
        $self->{institution} = $value;
    }
    return   $self->{institution};
}



=head2 get_city

 accessor  for city, assumes hash based class

=cut

sub get_city {
    my($self) = @_;
    return $self->{city};
}

=head2 set_city

mutator for city, assumes hash based class

=cut

sub set_city {
    my($self,$value) = @_;
    if($value) {
        $self->{city} = $value;
    }
    return   $self->{city};
}



=head2 get_streetAddress

 accessor  for streetAddress, assumes hash based class

=cut

sub get_streetAddress {
    my($self) = @_;
    return $self->{streetAddress};
}

=head2 set_streetAddress

mutator for streetAddress, assumes hash based class

=cut

sub set_streetAddress {
    my($self,$value) = @_;
    if($value) {
        $self->{streetAddress} = $value;
    }
    return   $self->{streetAddress};
}



=head2 get_floor

 accessor  for floor, assumes hash based class

=cut

sub get_floor {
    my($self) = @_;
    return $self->{floor};
}

=head2 set_floor

mutator for floor, assumes hash based class

=cut

sub set_floor {
    my($self,$value) = @_;
    if($value) {
        $self->{floor} = $value;
    }
    return   $self->{floor};
}



=head2 get_room

 accessor  for room, assumes hash based class

=cut

sub get_room {
    my($self) = @_;
    return $self->{room};
}

=head2 set_room

mutator for room, assumes hash based class

=cut

sub set_room {
    my($self,$value) = @_;
    if($value) {
        $self->{room} = $value;
    }
    return   $self->{room};
}



=head2 get_cage

 accessor  for cage, assumes hash based class

=cut

sub get_cage {
    my($self) = @_;
    return $self->{cage};
}

=head2 set_cage

mutator for cage, assumes hash based class

=cut

sub set_cage {
    my($self,$value) = @_;
    if($value) {
        $self->{cage} = $value;
    }
    return   $self->{cage};
}



=head2 get_rack

 accessor  for rack, assumes hash based class

=cut

sub get_rack {
    my($self) = @_;
    return $self->{rack};
}

=head2 set_rack

mutator for rack, assumes hash based class

=cut

sub set_rack {
    my($self,$value) = @_;
    if($value) {
        $self->{rack} = $value;
    }
    return   $self->{rack};
}



=head2 get_shelf

 accessor  for shelf, assumes hash based class

=cut

sub get_shelf {
    my($self) = @_;
    return $self->{shelf};
}

=head2 set_shelf

mutator for shelf, assumes hash based class

=cut

sub set_shelf {
    my($self,$value) = @_;
    if($value) {
        $self->{shelf} = $value;
    }
    return   $self->{shelf};
}



=head2 get_latitude

 accessor  for latitude, assumes hash based class

=cut

sub get_latitude {
    my($self) = @_;
    return $self->{latitude};
}

=head2 set_latitude

mutator for latitude, assumes hash based class

=cut

sub set_latitude {
    my($self,$value) = @_;
    if($value) {
        $self->{latitude} = $value;
    }
    return   $self->{latitude};
}



=head2 get_longitude

 accessor  for longitude, assumes hash based class

=cut

sub get_longitude {
    my($self) = @_;
    return $self->{longitude};
}

=head2 set_longitude

mutator for longitude, assumes hash based class

=cut

sub set_longitude {
    my($self,$value) = @_;
    if($value) {
        $self->{longitude} = $value;
    }
    return   $self->{longitude};
}



=head2  querySQL ()

 depending on SQL mapping declaration it will return some hash ref  to the  declared fields
 for example querySQL ()
 
 Accepts one optional parameter - query hashref, it will fill this hashref
 
 will return:    
    { <table_name1> =>  {<field name1> => <value>, ...},...}

=cut

sub  querySQL {
    my ($self, $query) = @_;

    return $query;
}


=head2  buildIdMap()

 if any of subelements has id then get a map of it in form of
 hashref to { element}{id} = index in array and store in the idmap field

=cut

sub  buildIdMap {
    my $self = shift;
    my %map = ();
    
    return;
}

=head2  asString()

 shortcut to get DOM and convert into the XML string
 returns nicely formatted XML string  representation of the  location object

=cut

sub asString {
    my $self = shift;
    my $dom = $self->getDOM();
    return $dom->toString('1');
}

=head2 registerNamespaces ()

 will parse all subelements
 returns reference to hash with namespace prefixes
 
 most parsers are expecting to see namespace registration info in the document root element declaration

=cut

sub registerNamespaces {
    my ($self, $nsids) = @_;
    my $local_nss = {reverse %{$self->get_nsmap->mapname}};
    unless($nsids) {
        $nsids = $local_nss;
    }  else {
        %{$nsids} = (%{$local_nss}, %{$nsids});
    }

    return $nsids;
}


=head2  fromDOM ($)

 accepts parent XML DOM  element  tree as parameter
 returns location  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    foreach my $childnode ($dom->childNodes) {
        my  $getname  = $childnode->getName;
        my ($nsid, $tagname) = split $COLUMN_SEPARATOR, $getname;
        next unless($nsid && $tagname);
	my $element;
	
      if ($childnode->textContent && $self->can("get_$tagname")) {
            $self->{$tagname} =  $childnode->textContent; ## text node
        }
    }
    $self->buildIdMap;
    $self->registerNamespaces;
    return $self;
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


