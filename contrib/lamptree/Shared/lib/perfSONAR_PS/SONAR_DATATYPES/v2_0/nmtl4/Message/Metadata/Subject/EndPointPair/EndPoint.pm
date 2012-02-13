package  perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint  -  this is data binding class for  'endPoint'  element from the XML schema namespace nmtl4

=head1 DESCRIPTION

Object representation of the endPoint element of the nmtl4 XML namespace.
Object fields are:


    Scalar:     protocol,
    Scalar:     role,
    Scalar:     port,
    Object reference:   address => type HASH,
    Object reference:   interface => type HASH,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'endPoint' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::SONAR_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap;
use perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address;
use perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface;
use fields qw(nsmap idmap LOGGER protocol role port address interface );


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         protocol   => undef,
         role   => undef,
         port   => undef,
         address => HASH,
         interface => HASH,

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint';
Readonly::Scalar our $LOCALNAME => 'endPoint';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'nmtl4');


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
 returns endPoint object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $endPoint;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $endPoint = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                                     ['protocol' =>  $self->get_protocol],

                                           ['role' =>  (($self->get_role    =~ m/(src|dst)$/)?$self->get_role:undef)],

                                                     ['port' =>  $self->get_port],

                                               ],
                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }

    if($self->get_address && blessed $self->get_address && $self->get_address->can("getDOM")) {
        my $addressDOM = $self->get_address->getDOM($endPoint);
        $addressDOM?$endPoint->appendChild($addressDOM):$self->get_LOGGER->logdie("Failed to append  address element with value:" .  $addressDOM->toString);
    }


    if(!($self->get_address) && $self->get_interface && blessed $self->get_interface && $self->get_interface->can("getDOM")) {
        my $interfaceDOM = $self->get_interface->getDOM($endPoint);
        $interfaceDOM?$endPoint->appendChild($interfaceDOM):$self->get_LOGGER->logdie("Failed to append  interface element with value:" .  $interfaceDOM->toString);
    }

      return $endPoint;
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



=head2 get_protocol

 accessor  for protocol, assumes hash based class

=cut

sub get_protocol {
    my($self) = @_;
    return $self->{protocol};
}

=head2 set_protocol

mutator for protocol, assumes hash based class

=cut

sub set_protocol {
    my($self,$value) = @_;
    if($value) {
        $self->{protocol} = $value;
    }
    return   $self->{protocol};
}



=head2 get_role

 accessor  for role, assumes hash based class

=cut

sub get_role {
    my($self) = @_;
    return $self->{role};
}

=head2 set_role

mutator for role, assumes hash based class

=cut

sub set_role {
    my($self,$value) = @_;
    if($value) {
        $self->{role} = $value;
    }
    return   $self->{role};
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



=head2 get_address

 accessor  for address, assumes hash based class

=cut

sub get_address {
    my($self) = @_;
    return $self->{address};
}

=head2 set_address

mutator for address, assumes hash based class

=cut

sub set_address {
    my($self,$value) = @_;
    if($value) {
        $self->{address} = $value;
    }
    return   $self->{address};
}



=head2 get_interface

 accessor  for interface, assumes hash based class

=cut

sub get_interface {
    my($self) = @_;
    return $self->{interface};
}

=head2 set_interface

mutator for interface, assumes hash based class

=cut

sub set_interface {
    my($self,$value) = @_;
    if($value) {
        $self->{interface} = $value;
    }
    return   $self->{interface};
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
     $query->{metaData}{transport}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface',     ];
     $query->{metaData}{ip_name_src}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface',     ];
     $query->{metaData}{ip_name_dst}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface',     ];
     $query->{host}{ip_name}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface',     ];
     $query->{host}{ip_number}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface',     ];
     $query->{metaData}{transport}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address',     ];
     $query->{metaData}{ip_name_src}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address',     ];
     $query->{metaData}{ip_name_dst}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address',     ];
     $query->{host}{ip_name}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address',     ];
     $query->{host}{ip_number}= [     'perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address',     ];

    foreach my $subname (qw/address interface/) {
        if($self->{$subname} && (ref($self->{$subname}) eq 'ARRAY' ||  blessed $self->{$subname})) {
            my @array = ref($self->{$subname}) eq 'ARRAY'?@{$self->{$subname}}:($self->{$subname});
            foreach my $el (@array) {
                if(blessed $el && $el->can('querySQL'))  {
                    $el->querySQL($query);
                    $self->get_LOGGER->debug("Querying endPoint  for subclass $subname");
                } else {
                    $self->get_LOGGER->logdie("Failed for endPoint Unblessed member or querySQL is not implemented by subclass $subname");
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
    

    foreach my $field (qw/address interface/) {
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
 returns nicely formatted XML string  representation of the  endPoint object

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


    foreach my $field (qw/address interface/) {
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
 returns endPoint  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    $self->set_protocol($dom->getAttribute('protocol')) if($dom->getAttribute('protocol'));

    $self->get_LOGGER->debug("Attribute protocol= ". $self->get_protocol) if $self->get_protocol;
    $self->set_role($dom->getAttribute('role')) if($dom->getAttribute('role') && ($dom->getAttribute('role')   =~ m/(src|dst)$/));

    $self->get_LOGGER->debug("Attribute role= ". $self->get_role) if $self->get_role;
    $self->set_port($dom->getAttribute('port')) if($dom->getAttribute('port'));

    $self->get_LOGGER->debug("Attribute port= ". $self->get_port) if $self->get_port;
    foreach my $childnode ($dom->childNodes) {
        my  $getname  = $childnode->getName;
        my ($nsid, $tagname) = split $COLUMN_SEPARATOR, $getname;
        next unless($nsid && $tagname);
	my $element;
	
        if ($tagname eq  'address' && $nsid eq 'nmtl4' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Address : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_address($element); ### add another address  
            } 
        elsif (!($self->get_address) && $tagname eq  'interface' && $nsid eq 'nmtl3' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtl3::Message::Metadata::Subject::Interface->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Interface : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_interface($element); ### add another interface  
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


