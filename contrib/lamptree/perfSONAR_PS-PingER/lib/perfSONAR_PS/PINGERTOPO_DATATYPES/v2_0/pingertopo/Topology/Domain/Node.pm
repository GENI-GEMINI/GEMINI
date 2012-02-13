package  perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node  -  this is data binding class for  'node'  element from the XML schema namespace pingertopo

=head1 DESCRIPTION

Object representation of the node element of the pingertopo XML namespace.
Object fields are:


    Scalar:     metadataIdRef,
    Scalar:     id,
    Object reference:   name => type HASH,
    Object reference:   hostName => type HASH,
    Object reference:   description => type HASH,
    Object reference:   location => type HASH,
    Object reference:   contact => type HASH,
    Object reference:   parameters => type HASH,
    Object reference:   port => type HASH,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'node' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap;
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Name;
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::HostName;
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Description;
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location;
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Contact;
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters;
use perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtl3::Topology::Domain::Node::Port;
use fields qw(nsmap idmap LOGGER metadataIdRef id name hostName description location contact parameters port );


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         metadataIdRef   => undef,
         id   => undef,
         name => HASH,
         hostName => HASH,
         description => HASH,
         location => HASH,
         contact => HASH,
         parameters => HASH,
         port => HASH,

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::pingertopo::Topology::Domain::Node';
Readonly::Scalar our $LOCALNAME => 'node';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'pingertopo');


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
 returns node object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $node;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $node = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                                     ['metadataIdRef' =>  $self->get_metadataIdRef],

                                                     ['id' =>  $self->get_id],

                                               ],
                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }

    if($self->get_name && blessed $self->get_name && $self->get_name->can("getDOM")) {
        my $nameDOM = $self->get_name->getDOM($node);
        $nameDOM?$node->appendChild($nameDOM):$self->get_LOGGER->logdie("Failed to append  name element with value:" .  $nameDOM->toString);
    }


    if($self->get_hostName && blessed $self->get_hostName && $self->get_hostName->can("getDOM")) {
        my $hostNameDOM = $self->get_hostName->getDOM($node);
        $hostNameDOM?$node->appendChild($hostNameDOM):$self->get_LOGGER->logdie("Failed to append  hostName element with value:" .  $hostNameDOM->toString);
    }


    if($self->get_description && blessed $self->get_description && $self->get_description->can("getDOM")) {
        my $descriptionDOM = $self->get_description->getDOM($node);
        $descriptionDOM?$node->appendChild($descriptionDOM):$self->get_LOGGER->logdie("Failed to append  description element with value:" .  $descriptionDOM->toString);
    }


    if($self->get_location && blessed $self->get_location && $self->get_location->can("getDOM")) {
        my $locationDOM = $self->get_location->getDOM($node);
        $locationDOM?$node->appendChild($locationDOM):$self->get_LOGGER->logdie("Failed to append  location element with value:" .  $locationDOM->toString);
    }


    if($self->get_contact && blessed $self->get_contact && $self->get_contact->can("getDOM")) {
        my $contactDOM = $self->get_contact->getDOM($node);
        $contactDOM?$node->appendChild($contactDOM):$self->get_LOGGER->logdie("Failed to append  contact element with value:" .  $contactDOM->toString);
    }


    if($self->get_parameters && blessed $self->get_parameters && $self->get_parameters->can("getDOM")) {
        my $parametersDOM = $self->get_parameters->getDOM($node);
        $parametersDOM?$node->appendChild($parametersDOM):$self->get_LOGGER->logdie("Failed to append  parameters element with value:" .  $parametersDOM->toString);
    }


    if($self->get_port && blessed $self->get_port && $self->get_port->can("getDOM")) {
        my $portDOM = $self->get_port->getDOM($node);
        $portDOM?$node->appendChild($portDOM):$self->get_LOGGER->logdie("Failed to append  port element with value:" .  $portDOM->toString);
    }

      return $node;
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



=head2 get_metadataIdRef

 accessor  for metadataIdRef, assumes hash based class

=cut

sub get_metadataIdRef {
    my($self) = @_;
    return $self->{metadataIdRef};
}

=head2 set_metadataIdRef

mutator for metadataIdRef, assumes hash based class

=cut

sub set_metadataIdRef {
    my($self,$value) = @_;
    if($value) {
        $self->{metadataIdRef} = $value;
    }
    return   $self->{metadataIdRef};
}



=head2 get_id

 accessor  for id, assumes hash based class

=cut

sub get_id {
    my($self) = @_;
    return $self->{id};
}

=head2 set_id

mutator for id, assumes hash based class

=cut

sub set_id {
    my($self,$value) = @_;
    if($value) {
        $self->{id} = $value;
    }
    return   $self->{id};
}



=head2 get_name

 accessor  for name, assumes hash based class

=cut

sub get_name {
    my($self) = @_;
    return $self->{name};
}

=head2 set_name

mutator for name, assumes hash based class

=cut

sub set_name {
    my($self,$value) = @_;
    if($value) {
        $self->{name} = $value;
    }
    return   $self->{name};
}



=head2 get_hostName

 accessor  for hostName, assumes hash based class

=cut

sub get_hostName {
    my($self) = @_;
    return $self->{hostName};
}

=head2 set_hostName

mutator for hostName, assumes hash based class

=cut

sub set_hostName {
    my($self,$value) = @_;
    if($value) {
        $self->{hostName} = $value;
    }
    return   $self->{hostName};
}



=head2 get_description

 accessor  for description, assumes hash based class

=cut

sub get_description {
    my($self) = @_;
    return $self->{description};
}

=head2 set_description

mutator for description, assumes hash based class

=cut

sub set_description {
    my($self,$value) = @_;
    if($value) {
        $self->{description} = $value;
    }
    return   $self->{description};
}



=head2 get_location

 accessor  for location, assumes hash based class

=cut

sub get_location {
    my($self) = @_;
    return $self->{location};
}

=head2 set_location

mutator for location, assumes hash based class

=cut

sub set_location {
    my($self,$value) = @_;
    if($value) {
        $self->{location} = $value;
    }
    return   $self->{location};
}



=head2 get_contact

 accessor  for contact, assumes hash based class

=cut

sub get_contact {
    my($self) = @_;
    return $self->{contact};
}

=head2 set_contact

mutator for contact, assumes hash based class

=cut

sub set_contact {
    my($self,$value) = @_;
    if($value) {
        $self->{contact} = $value;
    }
    return   $self->{contact};
}



=head2 get_parameters

 accessor  for parameters, assumes hash based class

=cut

sub get_parameters {
    my($self) = @_;
    return $self->{parameters};
}

=head2 set_parameters

mutator for parameters, assumes hash based class

=cut

sub set_parameters {
    my($self,$value) = @_;
    if($value) {
        $self->{parameters} = $value;
    }
    return   $self->{parameters};
}



=head2 get_port

 accessor  for port, assumes hash based class

=cut

sub get_port {
    my($self) = @_;
    return $self->{port};
}

=head2 set_port

mutator for port, assumes hash based class

=cut

sub set_port {
    my($self,$value) = @_;
    if($value) {
        $self->{port} = $value;
    }
    return   $self->{port};
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


    foreach my $subname (qw/name hostName description location contact parameters port/) {
        if($self->{$subname} && (ref($self->{$subname}) eq 'ARRAY' ||  blessed $self->{$subname})) {
            my @array = ref($self->{$subname}) eq 'ARRAY'?@{$self->{$subname}}:($self->{$subname});
            foreach my $el (@array) {
                if(blessed $el && $el->can('querySQL'))  {
                    $el->querySQL($query);
                    $self->get_LOGGER->debug("Querying node  for subclass $subname");
                } else {
                    $self->get_LOGGER->logdie("Failed for node Unblessed member or querySQL is not implemented by subclass $subname");
                }
           }
        }
    }
         
    return $query;
}


=head2  buildIdMap()

 if any of subelements has id then get a map of it in form of
 hashref to { element}{id} = index in array and store in the idmap field

=cut

sub  buildIdMap {
    my $self = shift;
    my %map = ();
    

    foreach my $field (qw/name hostName description location contact parameters port/) {
        my @array = ref($self->{$field}) eq 'ARRAY'?@{$self->{$field}}:($self->{$field});
        my $i = 0;
        foreach my $el (@array)  {
            if($el && blessed $el && $el->can('get_id') &&  $el->get_id)  {
                $map{$field}{$el->get_id} = $i;
            }
            $i++;
        }
    }
    return $self->set_idmap(\%map);
        
}

=head2  asString()

 shortcut to get DOM and convert into the XML string
 returns nicely formatted XML string  representation of the  node object

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


    foreach my $field (qw/name hostName description location contact parameters port/) {
        my @array = ref($self->{$field}) eq 'ARRAY'?@{$self->{$field}}:($self->{$field});
        foreach my $el (@array) {
            if(blessed $el &&  $el->can('registerNamespaces') ) {
                my $fromNSmap = $el->registerNamespaces($nsids);
                my %ns_idmap = %{$fromNSmap};
                foreach my $ns (keys %ns_idmap)  {
                    $nsids->{$ns}++;
                }
            }
        }
    }

    return $nsids;
}


=head2  fromDOM ($)

 accepts parent XML DOM  element  tree as parameter
 returns node  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    $self->set_metadataIdRef($dom->getAttribute('metadataIdRef')) if($dom->getAttribute('metadataIdRef'));

    $self->get_LOGGER->debug("Attribute metadataIdRef= ". $self->get_metadataIdRef) if $self->get_metadataIdRef;
    $self->set_id($dom->getAttribute('id')) if($dom->getAttribute('id'));

    $self->get_LOGGER->debug("Attribute id= ". $self->get_id) if $self->get_id;
    foreach my $childnode ($dom->childNodes) {
        my  $getname  = $childnode->getName;
        my ($nsid, $tagname) = split $COLUMN_SEPARATOR, $getname;
        next unless($nsid && $tagname);
	my $element;
	
        if ($tagname eq  'name' && $nsid eq 'nmtb' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Name->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Name : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_name($element); ### add another name  
            } 
        elsif ($tagname eq  'hostName' && $nsid eq 'nmtb' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::HostName->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  HostName : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_hostName($element); ### add another hostName  
            } 
        elsif ($tagname eq  'description' && $nsid eq 'nmtb' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Description->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Description : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_description($element); ### add another description  
            } 
        elsif ($tagname eq  'location' && $nsid eq 'nmtb' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Location->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Location : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_location($element); ### add another location  
            } 
        elsif ($tagname eq  'contact' && $nsid eq 'nmtb' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtb::Topology::Domain::Node::Contact->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Contact : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_contact($element); ### add another contact  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'nmwg' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmwg::Topology::Domain::Node::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_parameters($element); ### add another parameters  
            } 
        elsif ($tagname eq  'port' && $nsid eq 'nmtl3' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGERTOPO_DATATYPES::v2_0::nmtl3::Topology::Domain::Node::Port->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Port : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_port($element); ### add another port  
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


