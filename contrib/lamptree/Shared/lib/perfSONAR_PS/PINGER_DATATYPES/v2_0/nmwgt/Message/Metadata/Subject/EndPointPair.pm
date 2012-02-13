package  perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair  -  this is data binding class for  'endPointPair'  element from the XML schema namespace nmwgt

=head1 DESCRIPTION

Object representation of the endPointPair element of the nmwgt XML namespace.
Object fields are:


    Object reference:   src => type HASH,
    Object reference:   dst => type HASH,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'endPointPair' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::PINGER_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::PINGER_DATATYPES::v2_0::NSMap;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Src;
use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Dst;
use fields qw(nsmap idmap LOGGER  src dst );


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         src => HASH,
         dst => HASH,

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair';
Readonly::Scalar our $LOCALNAME => 'endPointPair';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::PINGER_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'nmwgt');


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
 returns endPointPair object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $endPointPair;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $endPointPair = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                               ],
                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }

    if($self->get_src && blessed $self->get_src && $self->get_src->can("getDOM")) {
        my $srcDOM = $self->get_src->getDOM($endPointPair);
        $srcDOM?$endPointPair->appendChild($srcDOM):$self->get_LOGGER->logdie("Failed to append  src element with value:" .  $srcDOM->toString);
    }


    if($self->get_dst && blessed $self->get_dst && $self->get_dst->can("getDOM")) {
        my $dstDOM = $self->get_dst->getDOM($endPointPair);
        $dstDOM?$endPointPair->appendChild($dstDOM):$self->get_LOGGER->logdie("Failed to append  dst element with value:" .  $dstDOM->toString);
    }

      return $endPointPair;
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



=head2 get_src

 accessor  for src, assumes hash based class

=cut

sub get_src {
    my($self) = @_;
    return $self->{src};
}

=head2 set_src

mutator for src, assumes hash based class

=cut

sub set_src {
    my($self,$value) = @_;
    if($value) {
        $self->{src} = $value;
    }
    return   $self->{src};
}



=head2 get_dst

 accessor  for dst, assumes hash based class

=cut

sub get_dst {
    my($self) = @_;
    return $self->{dst};
}

=head2 set_dst

mutator for dst, assumes hash based class

=cut

sub set_dst {
    my($self,$value) = @_;
    if($value) {
        $self->{dst} = $value;
    }
    return   $self->{dst};
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

     my %defined_table = ( 'metaData' => [   'ip_name_src',    'ip_name_dst',  ],  'host' => [   'ip_name',    'ip_number',  ],  );
     $query->{metaData}{ip_name_src}= [     'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Src',     ];
     $query->{host}{ip_name}= [     'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Src',     ];
     $query->{host}{ip_number}= [     'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Src',     ];
     $query->{metaData}{ip_name_dst}= [     'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Dst',     ];
     $query->{host}{ip_name}= [     'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Dst',     ];
     $query->{host}{ip_number}= [     'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Dst',     ];

    foreach my $subname (qw/src dst/) {
        if($self->{$subname} && (ref($self->{$subname}) eq 'ARRAY' ||  blessed $self->{$subname})) {
            my @array = ref($self->{$subname}) eq 'ARRAY'?@{$self->{$subname}}:($self->{$subname});
            foreach my $el (@array) {
                if(blessed $el && $el->can('querySQL'))  {
                    $el->querySQL($query);
                    $self->get_LOGGER->debug("Querying endPointPair  for subclass $subname");
                } else {
                    $self->get_LOGGER->logdie("Failed for endPointPair Unblessed member or querySQL is not implemented by subclass $subname");
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
    

    foreach my $field (qw/src dst/) {
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
 returns nicely formatted XML string  representation of the  endPointPair object

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


    foreach my $field (qw/src dst/) {
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
 returns endPointPair  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    foreach my $childnode ($dom->childNodes) {
        my  $getname  = $childnode->getName;
        my ($nsid, $tagname) = split $COLUMN_SEPARATOR, $getname;
        next unless($nsid && $tagname);
	my $element;
	
        if ($tagname eq  'src' && $nsid eq 'nmwgt' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Src->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Src : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_src($element); ### add another src  
            } 
        elsif ($tagname eq  'dst' && $nsid eq 'nmwgt' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Dst->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Dst : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_dst($element); ### add another dst  
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


