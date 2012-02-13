package  perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message  -  this is data binding class for  'message'  element from the XML schema namespace nmwg

=head1 DESCRIPTION

Object representation of the message element of the nmwg XML namespace.
Object fields are:


    Scalar:     type,
    Scalar:     id,
    Object reference:   parameters => type ARRAY,
    Object reference:   metadata => type ARRAY,
    Object reference:   data => type ARRAY,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'message' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::PINGER_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::PINGER_DATATYPES::v2_0::NSMap;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data::Key::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::min::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::max::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::median::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::mean::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::histogram::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::average::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::cdf::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::select::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::pinger::Message::Metadata::Parameters;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data;
use fields qw(nsmap idmap LOGGER type id parameters metadata data );


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         type   => undef,
         id   => undef,
         parameters => ARRAY,
         metadata => ARRAY,
         data => ARRAY,

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message';
Readonly::Scalar our $LOCALNAME => 'message';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::PINGER_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'nmwg');


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
 returns message object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $message;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $message = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                                     ['type' =>  $self->get_type],

                                                     ['id' =>  $self->get_id],

                                               ],
                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }

    if($self->get_parameters && ref($self->get_parameters) eq 'ARRAY') {
        foreach my $subel (@{$self->get_parameters}) {
            if(blessed $subel && $subel->can("getDOM")) {
                my $subDOM = $subel->getDOM($message);
                $subDOM?$message->appendChild($subDOM):$self->get_LOGGER->logdie("Failed to append  parameters element  with value:" .  $subDOM->toString);
            }
        }
    }


    if($self->get_metadata && ref($self->get_metadata) eq 'ARRAY') {
        foreach my $subel (@{$self->get_metadata}) {
            if(blessed $subel && $subel->can("getDOM")) {
                my $subDOM = $subel->getDOM($message);
                $subDOM?$message->appendChild($subDOM):$self->get_LOGGER->logdie("Failed to append  metadata element  with value:" .  $subDOM->toString);
            }
        }
    }


    if($self->get_data && ref($self->get_data) eq 'ARRAY') {
        foreach my $subel (@{$self->get_data}) {
            if(blessed $subel && $subel->can("getDOM")) {
                my $subDOM = $subel->getDOM($message);
                $subDOM?$message->appendChild($subDOM):$self->get_LOGGER->logdie("Failed to append  data element  with value:" .  $subDOM->toString);
            }
        }
    }

      return $message;
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



=head2 get_type

 accessor  for type, assumes hash based class

=cut

sub get_type {
    my($self) = @_;
    return $self->{type};
}

=head2 set_type

mutator for type, assumes hash based class

=cut

sub set_type {
    my($self,$value) = @_;
    if($value) {
        $self->{type} = $value;
    }
    return   $self->{type};
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



=head2 get_metadata

 accessor  for metadata, assumes hash based class

=cut

sub get_metadata {
    my($self) = @_;
    return $self->{metadata};
}

=head2 set_metadata

mutator for metadata, assumes hash based class

=cut

sub set_metadata {
    my($self,$value) = @_;
    if($value) {
        $self->{metadata} = $value;
    }
    return   $self->{metadata};
}



=head2 get_data

 accessor  for data, assumes hash based class

=cut

sub get_data {
    my($self) = @_;
    return $self->{data};
}

=head2 set_data

mutator for data, assumes hash based class

=cut

sub set_data {
    my($self,$value) = @_;
    if($value) {
        $self->{data} = $value;
    }
    return   $self->{data};
}



=head2  addParameters()

 if any of subelements can be an array then this method will provide
 facility to add another element to the  array and will return ref to such array
 or just set the element to a new one, if element has and 'id' attribute then it will
 create idmap  
 
 Accepts:  obj
 Returns: arrayref of objects

=cut

sub addParameters {
    my ($self,$new) = @_;

    $self->get_parameters && ref($self->get_parameters) eq 'ARRAY'?push @{$self->get_parameters}, $new:
                                                                 $self->set_parameters([$new]);
    $self->get_LOGGER->debug("Added new to parameters");
    $self->buildIdMap; ## rebuild index map
    return $self->get_parameters;
}

=head2  removeParametersById()

 removes specific element from the array of parameters elements by id ( if id is supported by this element )
 Accepts:  single param - id - which is id attribute of the element
 
 if there is no array then it will return undef and warning
 if it removed some id then $id will be returned

=cut

sub removeParametersById {
    my ($self, $id) = @_;
    if(ref($self->get_parameters) eq 'ARRAY' && $self->get_idmap->{parameters} &&  
       exists $self->get_idmap->{parameters}{$id}) {
        undef $self->get_parameters->[$self->get_idmap->{parameters}{$id}];
        my @tmp =  grep { defined $_ } @{$self->get_parameters};
        $self->set_parameters([@tmp]);
        $self->buildIdMap; ## rebuild index map
        return $id;
    } elsif(!ref($self->get_parameters)  || ref($self->get_parameters) ne 'ARRAY')  {
        $self->get_LOGGER->warn("Failed to remove  element because parameters not an array for non-existent id:$id");
    } else {
        $self->get_LOGGER->warn("Failed to remove element for non-existent id:$id");
    }
    return;
}

=head2  getParametersById()

 get specific element from the array of parameters elements by id ( if id is supported by this element )
 Accepts single param - id
 
 if there is no array then it will return just an object

=cut

sub getParametersById {
    my ($self, $id) = @_;

    if(ref($self->get_parameters) eq 'ARRAY' && $self->get_idmap->{parameters} && 
       exists $self->get_idmap->{parameters}{$id} ) {
        return $self->get_parameters->[$self->get_idmap->{parameters}{$id}];
    } elsif(!ref($self->get_parameters) || ref($self->get_parameters) ne 'ARRAY')  {
        return $self->get_parameters;
    }
    $self->get_LOGGER->warn("Requested element for non-existent id:$id");
    return;
}
            


=head2  addMetadata()

 if any of subelements can be an array then this method will provide
 facility to add another element to the  array and will return ref to such array
 or just set the element to a new one, if element has and 'id' attribute then it will
 create idmap  
 
 Accepts:  obj
 Returns: arrayref of objects

=cut

sub addMetadata {
    my ($self,$new) = @_;

    $self->get_metadata && ref($self->get_metadata) eq 'ARRAY'?push @{$self->get_metadata}, $new:
                                                                 $self->set_metadata([$new]);
    $self->get_LOGGER->debug("Added new to metadata");
    $self->buildIdMap; ## rebuild index map
    return $self->get_metadata;
}

=head2  removeMetadataById()

 removes specific element from the array of metadata elements by id ( if id is supported by this element )
 Accepts:  single param - id - which is id attribute of the element
 
 if there is no array then it will return undef and warning
 if it removed some id then $id will be returned

=cut

sub removeMetadataById {
    my ($self, $id) = @_;
    if(ref($self->get_metadata) eq 'ARRAY' && $self->get_idmap->{metadata} &&  
       exists $self->get_idmap->{metadata}{$id}) {
        undef $self->get_metadata->[$self->get_idmap->{metadata}{$id}];
        my @tmp =  grep { defined $_ } @{$self->get_metadata};
        $self->set_metadata([@tmp]);
        $self->buildIdMap; ## rebuild index map
        return $id;
    } elsif(!ref($self->get_metadata)  || ref($self->get_metadata) ne 'ARRAY')  {
        $self->get_LOGGER->warn("Failed to remove  element because metadata not an array for non-existent id:$id");
    } else {
        $self->get_LOGGER->warn("Failed to remove element for non-existent id:$id");
    }
    return;
}

=head2  getMetadataById()

 get specific element from the array of metadata elements by id ( if id is supported by this element )
 Accepts single param - id
 
 if there is no array then it will return just an object

=cut

sub getMetadataById {
    my ($self, $id) = @_;

    if(ref($self->get_metadata) eq 'ARRAY' && $self->get_idmap->{metadata} && 
       exists $self->get_idmap->{metadata}{$id} ) {
        return $self->get_metadata->[$self->get_idmap->{metadata}{$id}];
    } elsif(!ref($self->get_metadata) || ref($self->get_metadata) ne 'ARRAY')  {
        return $self->get_metadata;
    }
    $self->get_LOGGER->warn("Requested element for non-existent id:$id");
    return;
}
            


=head2  addData()

 if any of subelements can be an array then this method will provide
 facility to add another element to the  array and will return ref to such array
 or just set the element to a new one, if element has and 'id' attribute then it will
 create idmap  
 
 Accepts:  obj
 Returns: arrayref of objects

=cut

sub addData {
    my ($self,$new) = @_;

    $self->get_data && ref($self->get_data) eq 'ARRAY'?push @{$self->get_data}, $new:
                                                                 $self->set_data([$new]);
    $self->get_LOGGER->debug("Added new to data");
    $self->buildIdMap; ## rebuild index map
    return $self->get_data;
}

=head2  removeDataById()

 removes specific element from the array of data elements by id ( if id is supported by this element )
 Accepts:  single param - id - which is id attribute of the element
 
 if there is no array then it will return undef and warning
 if it removed some id then $id will be returned

=cut

sub removeDataById {
    my ($self, $id) = @_;
    if(ref($self->get_data) eq 'ARRAY' && $self->get_idmap->{data} &&  
       exists $self->get_idmap->{data}{$id}) {
        undef $self->get_data->[$self->get_idmap->{data}{$id}];
        my @tmp =  grep { defined $_ } @{$self->get_data};
        $self->set_data([@tmp]);
        $self->buildIdMap; ## rebuild index map
        return $id;
    } elsif(!ref($self->get_data)  || ref($self->get_data) ne 'ARRAY')  {
        $self->get_LOGGER->warn("Failed to remove  element because data not an array for non-existent id:$id");
    } else {
        $self->get_LOGGER->warn("Failed to remove element for non-existent id:$id");
    }
    return;
}

=head2  getDataById()

 get specific element from the array of data elements by id ( if id is supported by this element )
 Accepts single param - id
 
 if there is no array then it will return just an object

=cut

sub getDataById {
    my ($self, $id) = @_;

    if(ref($self->get_data) eq 'ARRAY' && $self->get_idmap->{data} && 
       exists $self->get_idmap->{data}{$id} ) {
        return $self->get_data->[$self->get_idmap->{data}{$id}];
    } elsif(!ref($self->get_data) || ref($self->get_data) ne 'ARRAY')  {
        return $self->get_data;
    }
    $self->get_LOGGER->warn("Requested element for non-existent id:$id");
    return;
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


    foreach my $subname (qw/parameters metadata data/) {
        if($self->{$subname} && (ref($self->{$subname}) eq 'ARRAY' ||  blessed $self->{$subname})) {
            my @array = ref($self->{$subname}) eq 'ARRAY'?@{$self->{$subname}}:($self->{$subname});
            foreach my $el (@array) {
                if(blessed $el && $el->can('querySQL'))  {
                    $el->querySQL($query);
                    $self->get_LOGGER->debug("Querying message  for subclass $subname");
                } else {
                    $self->get_LOGGER->logdie("Failed for message Unblessed member or querySQL is not implemented by subclass $subname");
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
    

    foreach my $field (qw/parameters metadata data/) {
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
 returns nicely formatted XML string  representation of the  message object

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


    foreach my $field (qw/parameters metadata data/) {
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
 returns message  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    $self->set_type($dom->getAttribute('type')) if($dom->getAttribute('type'));

    $self->get_LOGGER->debug("Attribute type= ". $self->get_type) if $self->get_type;
    $self->set_id($dom->getAttribute('id')) if($dom->getAttribute('id'));

    $self->get_LOGGER->debug("Attribute id= ". $self->get_id) if $self->get_id;
    foreach my $childnode ($dom->childNodes) {
        my  $getname  = $childnode->getName;
        my ($nsid, $tagname) = split $COLUMN_SEPARATOR, $getname;
        next unless($nsid && $tagname);
	my $element;
	
        if ($tagname eq  'parameters' && $nsid eq 'nmwg' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data::Key::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'select' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::select::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'average' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::average::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'mean' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::mean::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'median' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::median::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'max' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::max::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'min' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::min::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'cdf' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::cdf::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'histogram' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::histogram::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'parameters' && $nsid eq 'pinger' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::pinger::Message::Metadata::Parameters->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Parameters : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_parameters && ref($self->get_parameters) eq 'ARRAY')?push @{$self->get_parameters}, $element:
                                                                                                        $self->set_parameters([$element]);; ### add another parameters  
            } 
        elsif ($tagname eq  'metadata' && $nsid eq 'nmwg' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Metadata : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_metadata && ref($self->get_metadata) eq 'ARRAY')?push @{$self->get_metadata}, $element:
                                                                                                        $self->set_metadata([$element]);; ### add another metadata  
            } 
        elsif ($tagname eq  'data' && $nsid eq 'nmwg' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Data : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
               ($self->get_data && ref($self->get_data) eq 'ARRAY')?push @{$self->get_data}, $element:
                                                                                                        $self->set_data([$element]);; ### add another data  
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


