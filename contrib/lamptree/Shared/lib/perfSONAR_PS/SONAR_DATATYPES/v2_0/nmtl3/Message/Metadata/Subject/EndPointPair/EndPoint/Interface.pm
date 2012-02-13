package  perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface  -  this is data binding class for  'interface'  element from the XML schema namespace nmtl3

=head1 DESCRIPTION

Object representation of the interface element of the nmtl3 XML namespace.
Object fields are:


    Scalar:     id,
    Scalar:     interfaceIdRef,
    Object reference:   ipAddress => type HASH,
    Object reference:   netmask => type ,
    Object reference:   ifName => type ,
    Object reference:   ifDescription => type ,
    Object reference:   ifAddress => type HASH,
    Object reference:   ifHostName => type ,
    Object reference:   ifIndex => type ,
    Object reference:   type => type ,
    Object reference:   capacity => type ,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'interface' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::SONAR_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap;
use perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface::IpAddress;
use perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface::IfAddress;
use fields qw(nsmap idmap LOGGER id interfaceIdRef ipAddress ifAddress netmask ifName ifDescription ifHostName ifIndex type capacity text );


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         id   => undef,
         interfaceIdRef   => undef,
         ipAddress => HASH,
         ifAddress => HASH,
 text => 'text'

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface';
Readonly::Scalar our $LOCALNAME => 'interface';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'nmtl3');


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
 returns interface object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $interface;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $interface = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                                     ['id' =>  $self->get_id],

                                                     ['interfaceIdRef' =>  $self->get_interfaceIdRef],

                                               ],
                                            'text' => (!($self->get_ipAddress)?$self->get_text:undef),

                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }

    if($self->get_ipAddress && blessed $self->get_ipAddress && $self->get_ipAddress->can("getDOM")) {
        my $ipAddressDOM = $self->get_ipAddress->getDOM($interface);
        $ipAddressDOM?$interface->appendChild($ipAddressDOM):$self->get_LOGGER->logdie("Failed to append  ipAddress element with value:" .  $ipAddressDOM->toString);
    }


    if($self->get_ifAddress && blessed $self->get_ifAddress && $self->get_ifAddress->can("getDOM")) {
        my $ifAddressDOM = $self->get_ifAddress->getDOM($interface);
        $ifAddressDOM?$interface->appendChild($ifAddressDOM):$self->get_LOGGER->logdie("Failed to append  ifAddress element with value:" .  $ifAddressDOM->toString);
    }



    foreach my $textnode (qw/netmask ifName ifDescription ifHostName ifIndex type capacity/) {
        if($self->{$textnode}) {
            my  $domtext  =  getElement({name => $textnode,
                                          parent => $interface,
                                          ns => [$self->get_nsmap->mapname($LOCALNAME)],
                                          text => $self->{$textnode},
                              });
           $domtext?$interface->appendChild($domtext):
	             $self->get_LOGGER->logdie("Failed to append new text element $textnode to interface");
        }
    }
        
      return $interface;
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



=head2 get_interfaceIdRef

 accessor  for interfaceIdRef, assumes hash based class

=cut

sub get_interfaceIdRef {
    my($self) = @_;
    return $self->{interfaceIdRef};
}

=head2 set_interfaceIdRef

mutator for interfaceIdRef, assumes hash based class

=cut

sub set_interfaceIdRef {
    my($self,$value) = @_;
    if($value) {
        $self->{interfaceIdRef} = $value;
    }
    return   $self->{interfaceIdRef};
}



=head2 get_ipAddress

 accessor  for ipAddress, assumes hash based class

=cut

sub get_ipAddress {
    my($self) = @_;
    return $self->{ipAddress};
}

=head2 set_ipAddress

mutator for ipAddress, assumes hash based class

=cut

sub set_ipAddress {
    my($self,$value) = @_;
    if($value) {
        $self->{ipAddress} = $value;
    }
    return   $self->{ipAddress};
}



=head2 get_ifAddress

 accessor  for ifAddress, assumes hash based class

=cut

sub get_ifAddress {
    my($self) = @_;
    return $self->{ifAddress};
}

=head2 set_ifAddress

mutator for ifAddress, assumes hash based class

=cut

sub set_ifAddress {
    my($self,$value) = @_;
    if($value) {
        $self->{ifAddress} = $value;
    }
    return   $self->{ifAddress};
}



=head2 get_netmask

 accessor  for netmask, assumes hash based class

=cut

sub get_netmask {
    my($self) = @_;
    return $self->{netmask};
}

=head2 set_netmask

mutator for netmask, assumes hash based class

=cut

sub set_netmask {
    my($self,$value) = @_;
    if($value) {
        $self->{netmask} = $value;
    }
    return   $self->{netmask};
}



=head2 get_ifName

 accessor  for ifName, assumes hash based class

=cut

sub get_ifName {
    my($self) = @_;
    return $self->{ifName};
}

=head2 set_ifName

mutator for ifName, assumes hash based class

=cut

sub set_ifName {
    my($self,$value) = @_;
    if($value) {
        $self->{ifName} = $value;
    }
    return   $self->{ifName};
}



=head2 get_ifDescription

 accessor  for ifDescription, assumes hash based class

=cut

sub get_ifDescription {
    my($self) = @_;
    return $self->{ifDescription};
}

=head2 set_ifDescription

mutator for ifDescription, assumes hash based class

=cut

sub set_ifDescription {
    my($self,$value) = @_;
    if($value) {
        $self->{ifDescription} = $value;
    }
    return   $self->{ifDescription};
}



=head2 get_ifHostName

 accessor  for ifHostName, assumes hash based class

=cut

sub get_ifHostName {
    my($self) = @_;
    return $self->{ifHostName};
}

=head2 set_ifHostName

mutator for ifHostName, assumes hash based class

=cut

sub set_ifHostName {
    my($self,$value) = @_;
    if($value) {
        $self->{ifHostName} = $value;
    }
    return   $self->{ifHostName};
}



=head2 get_ifIndex

 accessor  for ifIndex, assumes hash based class

=cut

sub get_ifIndex {
    my($self) = @_;
    return $self->{ifIndex};
}

=head2 set_ifIndex

mutator for ifIndex, assumes hash based class

=cut

sub set_ifIndex {
    my($self,$value) = @_;
    if($value) {
        $self->{ifIndex} = $value;
    }
    return   $self->{ifIndex};
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



=head2 get_capacity

 accessor  for capacity, assumes hash based class

=cut

sub get_capacity {
    my($self) = @_;
    return $self->{capacity};
}

=head2 set_capacity

mutator for capacity, assumes hash based class

=cut

sub set_capacity {
    my($self,$value) = @_;
    if($value) {
        $self->{capacity} = $value;
    }
    return   $self->{capacity};
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

     my %defined_table = ( 'metaData' => [   'transport',    'ip_name_src',    'ip_name_dst',  ],  'host' => [   'ip_name',    'ip_number',  ],  );
     $query->{metaData}{transport}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface::IpAddress',     ];
     $query->{host}{ip_number}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface::IpAddress',     ];
     $query->{metaData}{ip_name_src}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface' ] if!(defined $query->{metaData}{ip_name_src}) || ref($query->{metaData}{ip_name_src});
     $query->{metaData}{ip_name_dst}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface' ] if!(defined $query->{metaData}{ip_name_dst}) || ref($query->{metaData}{ip_name_dst});
     $query->{host}{ip_name}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface' ] if!(defined $query->{host}{ip_name}) || ref($query->{host}{ip_name});

    foreach my $subname (qw/ipAddress ifAddress/) {
        if($self->{$subname} && (ref($self->{$subname}) eq 'ARRAY' ||  blessed $self->{$subname})) {
            my @array = ref($self->{$subname}) eq 'ARRAY'?@{$self->{$subname}}:($self->{$subname});
            foreach my $el (@array) {
                if(blessed $el && $el->can('querySQL'))  {
                    $el->querySQL($query);
                    $self->get_LOGGER->debug("Querying interface  for subclass $subname");
                } else {
                    $self->get_LOGGER->logdie("Failed for interface Unblessed member or querySQL is not implemented by subclass $subname");
                }
           }
        }
    }
         

    eval {
        foreach my $table  ( keys %defined_table) {
            foreach my $entry (@{$defined_table{$table}}) {
                if(ref($query->{$table}{$entry}) eq 'ARRAY') {
                    foreach my $classes (@{$query->{$table}{$entry}}) {
                         if($classes && $classes eq 'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::EndPointPair::EndPoint::Interface') {
        

                         }
                     }
                 }
             }
        }
    };
    if($EVAL_ERROR) {
            $self->get_LOGGER->logdie("SQL query building is failed  here " . $EVAL_ERROR);
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
    

    foreach my $field (qw/ipAddress ifAddress/) {
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
 returns nicely formatted XML string  representation of the  interface object

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


    foreach my $field (qw/ipAddress ifAddress/) {
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
 returns interface  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    $self->set_id($dom->getAttribute('id')) if($dom->getAttribute('id'));

    $self->get_LOGGER->debug("Attribute id= ". $self->get_id) if $self->get_id;
    $self->set_interfaceIdRef($dom->getAttribute('interfaceIdRef')) if($dom->getAttribute('interfaceIdRef'));

    $self->get_LOGGER->debug("Attribute interfaceIdRef= ". $self->get_interfaceIdRef) if $self->get_interfaceIdRef;
    $self->set_text($dom->textContent) if(!($self->get_ipAddress) && $dom->textContent);

    foreach my $childnode ($dom->childNodes) {
        my  $getname  = $childnode->getName;
        my ($nsid, $tagname) = split $COLUMN_SEPARATOR, $getname;
        next unless($nsid && $tagname);
	my $element;
	
        if ($tagname eq  'ipAddress' && $nsid eq 'nmtl3' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface::IpAddress->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  IpAddress : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_ipAddress($element); ### add another ipAddress  
            } 
        elsif ($tagname eq  'ifAddress' && $nsid eq 'nmtl3' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface::IfAddress->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  IfAddress : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_ifAddress($element); ### add another ifAddress  
            } 
      elsif ($childnode->textContent && $self->can("get_$tagname")) {
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


