package  perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address  -  this is data binding class for  'address'  element from the XML schema namespace nmtl4

=head1 DESCRIPTION

Object representation of the address element of the nmtl4 XML namespace.
Object fields are:


    Scalar:     value,
    Scalar:     type,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'address' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::PINGER_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::PINGER_DATATYPES::v2_0::NSMap;
use fields qw(nsmap idmap LOGGER value type   text );


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         value   => undef,
         type   => undef,
 text => 'text'

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address';
Readonly::Scalar our $LOCALNAME => 'address';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::PINGER_DATATYPES::v2_0::NSMap->new());
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
 returns address object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $address;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $address = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                                     ['value' =>  $self->get_value],

                                                     ['type' =>  $self->get_type],

                                               ],
                                            'text' => (!($self->get_value)?$self->get_text:undef),

                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }
      return $address;
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



=head2 get_value

 accessor  for value, assumes hash based class

=cut

sub get_value {
    my($self) = @_;
    return $self->{value};
}

=head2 set_value

mutator for value, assumes hash based class

=cut

sub set_value {
    my($self,$value) = @_;
    if($value) {
        $self->{value} = $value;
    }
    return   $self->{value};
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



=head2  querySQL ()

 depending on SQL mapping declaration it will return some hash ref  to the  declared fields
 for example querySQL ()
 
 Accepts one optional parameter - query hashref, it will fill this hashref
 
 will return:    
    { <table_name1> =>  {<field name1> => <value>, ...},...}

=cut

sub  querySQL {
    my ($self, $query) = @_;

     my %defined_table = ( 'metaData' => [   'ip_name_src',    'ip_name_dst',  ],  'host' => [   'ip_number',  ],  );
     $query->{metaData}{ip_name_src}= [ 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address' ] if!(defined $query->{metaData}{ip_name_src}) || ref($query->{metaData}{ip_name_src});
     $query->{metaData}{ip_name_dst}= [ 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address' ] if!(defined $query->{metaData}{ip_name_dst}) || ref($query->{metaData}{ip_name_dst});
     $query->{host}{ip_number}= [ 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address' ] if!(defined $query->{host}{ip_number}) || ref($query->{host}{ip_number});
     $query->{metaData}{ip_name_src}= [ 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address' ] if!(defined $query->{metaData}{ip_name_src}) || ref($query->{metaData}{ip_name_src});
     $query->{metaData}{ip_name_dst}= [ 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address' ] if!(defined $query->{metaData}{ip_name_dst}) || ref($query->{metaData}{ip_name_dst});
     $query->{host}{ip_number}= [ 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address' ] if!(defined $query->{host}{ip_number}) || ref($query->{host}{ip_number});

    eval {
        foreach my $table  ( keys %defined_table) {
            foreach my $entry (@{$defined_table{$table}}) {
                if(ref($query->{$table}{$entry}) eq 'ARRAY') {
                    foreach my $classes (@{$query->{$table}{$entry}}) {
                         if($classes && $classes eq 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmtl4::Message::Metadata::Subject::EndPointPair::EndPoint::Address') {
        
                            if    ($self->get_value && ( (  ($entry eq 'ip_name_src') or  ($entry eq 'ip_name_dst')) || (  ( ($self->get_type eq 'ipv4')  && $entry eq 'ip_number')) )) {
                                $query->{$table}{$entry} =  $self->get_value;
                                $self->get_LOGGER->debug(" Got value for SQL query $table.$entry: " . $self->get_value);
                                last;  
                            }

                            elsif ($self->get_text && ( (  ($entry eq 'ip_name_src') or  ($entry eq 'ip_name_dst')) || (  ( ($self->get_type eq 'ipv4')  && $entry eq 'ip_number')) )) {
                                $query->{$table}{$entry} =  $self->get_text;
                                $self->get_LOGGER->debug(" Got value for SQL query $table.$entry: " . $self->get_text);
                                last;  
                            }


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
    
    return;
}

=head2  asString()

 shortcut to get DOM and convert into the XML string
 returns nicely formatted XML string  representation of the  address object

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
 returns address  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    $self->set_value($dom->getAttribute('value')) if($dom->getAttribute('value'));

    $self->get_LOGGER->debug("Attribute value= ". $self->get_value) if $self->get_value;
    $self->set_type($dom->getAttribute('type')) if($dom->getAttribute('type'));

    $self->get_LOGGER->debug("Attribute type= ". $self->get_type) if $self->get_type;
    $self->set_text($dom->textContent) if(!($self->get_value) && $dom->textContent);

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


