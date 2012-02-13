package  perfSONAR_PS::SONAR_DATATYPES::v2_0::ifevt::Message::Data::Datum;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::SONAR_DATATYPES::v2_0::ifevt::Message::Data::Datum  -  this is data binding class for  'datum'  element from the XML schema namespace ifevt

=head1 DESCRIPTION

Object representation of the datum element of the ifevt XML namespace.
Object fields are:


    Scalar:     timeType,
    Scalar:     timeValue,
    Object reference:   time => type HASH,
    Object reference:   stateAdmin => type ,
    Object reference:   stateOper => type ,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'datum' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::SONAR_DATATYPES::v2_0::ifevt::Message::Data::Datum;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::SONAR_DATATYPES::v2_0::ifevt::Message::Data::Datum->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::SONAR_DATATYPES::v2_0::ifevt::Message::Data::Datum->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::SONAR_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap;
use perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtm::Message::Data::Datum::Time;
use fields qw(nsmap idmap LOGGER timeType timeValue time stateAdmin stateOper);


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         timeType   => undef,
         timeValue   => undef,
         time => HASH,

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::SONAR_DATATYPES::v2_0::ifevt::Message::Data::Datum';
Readonly::Scalar our $LOCALNAME => 'datum';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'ifevt');


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
 returns datum object DOM

=cut

sub getDOM {
    my ($self, $parent) = @_;
    my $datum;
    eval { 
        my @nss;    
        unless($parent) {
            my $nsses = $self->registerNamespaces(); 
            @nss = map {$_  if($_ && $_  ne  $self->get_nsmap->mapname( $LOCALNAME ))}  keys %{$nsses};
            push(@nss,  $self->get_nsmap->mapname( $LOCALNAME ));
        } 
        push  @nss, $self->get_nsmap->mapname( $LOCALNAME ) unless  @nss;
        $datum = getElement({name =>   $LOCALNAME, 
	                      parent => $parent,
			      ns  =>    \@nss,
                              attributes => [

                                                     ['timeType' =>  $self->get_timeType],

                                                     ['timeValue' =>  $self->get_timeValue],

                                               ],
                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
    }

    if(!($self->get_timeValue && $self->get_timeType) && $self->get_time && blessed $self->get_time && $self->get_time->can("getDOM")) {
        my $timeDOM = $self->get_time->getDOM($datum);
        $timeDOM?$datum->appendChild($timeDOM):$self->get_LOGGER->logdie("Failed to append  time element with value:" .  $timeDOM->toString);
    }



    foreach my $textnode (qw/stateAdmin stateOper/) {
        if($self->{$textnode}) {
            my  $domtext  =  getElement({name => $textnode,
                                          parent => $datum,
                                          ns => [$self->get_nsmap->mapname($LOCALNAME)],
                                          text => $self->{$textnode},
                              });
           $domtext?$datum->appendChild($domtext):
	             $self->get_LOGGER->logdie("Failed to append new text element $textnode to datum");
        }
    }
        
      return $datum;
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



=head2 get_timeType

 accessor  for timeType, assumes hash based class

=cut

sub get_timeType {
    my($self) = @_;
    return $self->{timeType};
}

=head2 set_timeType

mutator for timeType, assumes hash based class

=cut

sub set_timeType {
    my($self,$value) = @_;
    if($value) {
        $self->{timeType} = $value;
    }
    return   $self->{timeType};
}



=head2 get_timeValue

 accessor  for timeValue, assumes hash based class

=cut

sub get_timeValue {
    my($self) = @_;
    return $self->{timeValue};
}

=head2 set_timeValue

mutator for timeValue, assumes hash based class

=cut

sub set_timeValue {
    my($self,$value) = @_;
    if($value) {
        $self->{timeValue} = $value;
    }
    return   $self->{timeValue};
}



=head2 get_time

 accessor  for time, assumes hash based class

=cut

sub get_time {
    my($self) = @_;
    return $self->{time};
}

=head2 set_time

mutator for time, assumes hash based class

=cut

sub set_time {
    my($self,$value) = @_;
    if($value) {
        $self->{time} = $value;
    }
    return   $self->{time};
}



=head2 get_stateAdmin

 accessor  for stateAdmin, assumes hash based class

=cut

sub get_stateAdmin {
    my($self) = @_;
    return $self->{stateAdmin};
}

=head2 set_stateAdmin

mutator for stateAdmin, assumes hash based class

=cut

sub set_stateAdmin {
    my($self,$value) = @_;
    if($value) {
        $self->{stateAdmin} = $value;
    }
    return   $self->{stateAdmin};
}



=head2 get_stateOper

 accessor  for stateOper, assumes hash based class

=cut

sub get_stateOper {
    my($self) = @_;
    return $self->{stateOper};
}

=head2 set_stateOper

mutator for stateOper, assumes hash based class

=cut

sub set_stateOper {
    my($self,$value) = @_;
    if($value) {
        $self->{stateOper} = $value;
    }
    return   $self->{stateOper};
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


    foreach my $subname (qw/time/) {
        if($self->{$subname} && (ref($self->{$subname}) eq 'ARRAY' ||  blessed $self->{$subname})) {
            my @array = ref($self->{$subname}) eq 'ARRAY'?@{$self->{$subname}}:($self->{$subname});
            foreach my $el (@array) {
                if(blessed $el && $el->can('querySQL'))  {
                    $el->querySQL($query);
                    $self->get_LOGGER->debug("Querying datum  for subclass $subname");
                } else {
                    $self->get_LOGGER->logdie("Failed for datum Unblessed member or querySQL is not implemented by subclass $subname");
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
    

    foreach my $field (qw/time/) {
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
 returns nicely formatted XML string  representation of the  datum object

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


    foreach my $field (qw/time/) {
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
 returns datum  object

=cut

sub fromDOM {
    my ($self, $dom) = @_;

    $self->set_timeType($dom->getAttribute('timeType')) if($dom->getAttribute('timeType'));

    $self->get_LOGGER->debug("Attribute timeType= ". $self->get_timeType) if $self->get_timeType;
    $self->set_timeValue($dom->getAttribute('timeValue')) if($dom->getAttribute('timeValue'));

    $self->get_LOGGER->debug("Attribute timeValue= ". $self->get_timeValue) if $self->get_timeValue;
    foreach my $childnode ($dom->childNodes) {
        my  $getname  = $childnode->getName;
        my ($nsid, $tagname) = split $COLUMN_SEPARATOR, $getname;
        next unless($nsid && $tagname);
	my $element;
	
        if (!($self->get_timeValue && $self->get_timeType) && $tagname eq  'time' && $nsid eq 'nmtm' && $self->can("get_$tagname")) {
                eval {
                    $element = perfSONAR_PS::SONAR_DATATYPES::v2_0::nmtm::Message::Data::Datum::Time->new($childnode)
                };
                if($EVAL_ERROR || !($element  && blessed $element)) {
                    $self->get_LOGGER->logdie(" Failed to load and add  Time : " . $dom->toString . " error: " . $EVAL_ERROR);
                     return;
                }
              $self->set_time($element); ### add another time  
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


