package  perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum;

use strict;
use warnings;
use utf8;
use English qw(-no_match_vars);
use version; our $VERSION = 'v2.0';

=head1 NAME

perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum  -  this is data binding class for  'datum'  element from the XML schema namespace pinger

=head1 DESCRIPTION

Object representation of the datum element of the pinger XML namespace.
Object fields are:


    Scalar:     timeType,
    Scalar:     ttl,
    Scalar:     numBytes,
    Scalar:     value,
    Scalar:     name,
    Scalar:     valueUnits,
    Scalar:     timeValue,
    Scalar:     seqNum,


The constructor accepts only single parameter, it could be a hashref with keyd  parameters hash  or DOM of the  'datum' element
Alternative way to create this object is to pass hashref to this hash: { xml => <xml string> }
Please remember that namespace prefix is used as namespace id for mapping which not how it was intended by XML standard. The consequence of that
is if you serve some XML on one end of the webservices pipeline then the same namespace prefixes MUST be used on the one for the same namespace URNs.
This constraint can be fixed in the future releases.

Note: this class utilizes L<Log::Log4perl> module, see corresponded docs on CPAN.

=head1 SYNOPSIS

          use perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum;
          use Log::Log4perl qw(:easy);

          Log::Log4perl->easy_init();

          my $el =  perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum->new($DOM_Obj);

          my $xml_string = $el->asString();

          my $el2 = perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum->new({xml => $xml_string});


          see more available methods below


=head1   METHODS

=cut


use XML::LibXML;
use Scalar::Util qw(blessed);
use Log::Log4perl qw(get_logger);
use Readonly;
    
use perfSONAR_PS::SONAR_DATATYPES::v2_0::Element qw(getElement);
use perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap;
use fields qw(nsmap idmap LOGGER timeType ttl numBytes value name valueUnits timeValue seqNum  );


=head2 new({})

 creates   object, accepts DOM with element's tree or hashref to the list of
 keyed parameters:

         timeType   => undef,
         ttl   => undef,
         numBytes   => undef,
         value   => undef,
         name   => undef,
         valueUnits   => undef,
         timeValue   => undef,
         seqNum   => undef,

returns: $self

=cut

Readonly::Scalar our $COLUMN_SEPARATOR => ':';
Readonly::Scalar our $CLASSPATH =>  'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum';
Readonly::Scalar our $LOCALNAME => 'datum';

sub new {
    my ($that, $param) = @_;
    my $class = ref($that) || $that;
    my $self =  fields::new($class );
    $self->set_LOGGER(get_logger($CLASSPATH));
    $self->set_nsmap(perfSONAR_PS::SONAR_DATATYPES::v2_0::NSMap->new());
    $self->get_nsmap->mapname($LOCALNAME, 'pinger');


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

                                                     ['ttl' =>  $self->get_ttl],

                                                     ['numBytes' =>  $self->get_numBytes],

                                                     ['value' =>  $self->get_value],

                                           ['name' =>  (($self->get_name    =~ m/(minRtt|maxRtt|meanRtt|medianRtt|lossPercent|clp|minIpd|maxIpd|iqrIpd|meanIpd|duplicates|outOfOrder)$/)?$self->get_name:undef)],

                                                     ['valueUnits' =>  $self->get_valueUnits],

                                                     ['timeValue' =>  $self->get_timeValue],

                                                     ['seqNum' =>  $self->get_seqNum],

                                               ],
                               });
        };
    if($EVAL_ERROR) {
         $self->get_LOGGER->logdie(" Failed at creating DOM: $EVAL_ERROR");
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



=head2 get_ttl

 accessor  for ttl, assumes hash based class

=cut

sub get_ttl {
    my($self) = @_;
    return $self->{ttl};
}

=head2 set_ttl

mutator for ttl, assumes hash based class

=cut

sub set_ttl {
    my($self,$value) = @_;
    if($value) {
        $self->{ttl} = $value;
    }
    return   $self->{ttl};
}



=head2 get_numBytes

 accessor  for numBytes, assumes hash based class

=cut

sub get_numBytes {
    my($self) = @_;
    return $self->{numBytes};
}

=head2 set_numBytes

mutator for numBytes, assumes hash based class

=cut

sub set_numBytes {
    my($self,$value) = @_;
    if($value) {
        $self->{numBytes} = $value;
    }
    return   $self->{numBytes};
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



=head2 get_valueUnits

 accessor  for valueUnits, assumes hash based class

=cut

sub get_valueUnits {
    my($self) = @_;
    return $self->{valueUnits};
}

=head2 set_valueUnits

mutator for valueUnits, assumes hash based class

=cut

sub set_valueUnits {
    my($self,$value) = @_;
    if($value) {
        $self->{valueUnits} = $value;
    }
    return   $self->{valueUnits};
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



=head2 get_seqNum

 accessor  for seqNum, assumes hash based class

=cut

sub get_seqNum {
    my($self) = @_;
    return $self->{seqNum};
}

=head2 set_seqNum

mutator for seqNum, assumes hash based class

=cut

sub set_seqNum {
    my($self,$value) = @_;
    if($value) {
        $self->{seqNum} = $value;
    }
    return   $self->{seqNum};
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

     my %defined_table = ( 'data' => [   'minRtt',    'ttl',    'numBytes',    'outOfOrder',    'maxRtt',    'rtts',    'clp',    'medianRtt',    'meanRtt',    'duplicates',    'maxIpd',    'meanIpd',    'minIpd',    'seqNums',    'lossPercent',    'iqrIpd',  ],  );
     $query->{data}{numBytes}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{numBytes}) || ref($query->{data}{numBytes});
     $query->{data}{ttl}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{ttl}) || ref($query->{data}{ttl});
     $query->{data}{minRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{minRtt}) || ref($query->{data}{minRtt});
     $query->{data}{maxRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{maxRtt}) || ref($query->{data}{maxRtt});
     $query->{data}{outOfOrder}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{outOfOrder}) || ref($query->{data}{outOfOrder});
     $query->{data}{medianRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{medianRtt}) || ref($query->{data}{medianRtt});
     $query->{data}{clp}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{clp}) || ref($query->{data}{clp});
     $query->{data}{meanRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{meanRtt}) || ref($query->{data}{meanRtt});
     $query->{data}{duplicates}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{duplicates}) || ref($query->{data}{duplicates});
     $query->{data}{maxIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{maxIpd}) || ref($query->{data}{maxIpd});
     $query->{data}{minIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{minIpd}) || ref($query->{data}{minIpd});
     $query->{data}{meanIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{meanIpd}) || ref($query->{data}{meanIpd});
     $query->{data}{iqrIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{iqrIpd}) || ref($query->{data}{iqrIpd});
     $query->{data}{lossPercent}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{lossPercent}) || ref($query->{data}{lossPercent});
     $query->{data}{minRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{minRtt}) || ref($query->{data}{minRtt});
     $query->{data}{maxRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{maxRtt}) || ref($query->{data}{maxRtt});
     $query->{data}{outOfOrder}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{outOfOrder}) || ref($query->{data}{outOfOrder});
     $query->{data}{rtts}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{rtts}) || ref($query->{data}{rtts});
     $query->{data}{medianRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{medianRtt}) || ref($query->{data}{medianRtt});
     $query->{data}{clp}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{clp}) || ref($query->{data}{clp});
     $query->{data}{meanRtt}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{meanRtt}) || ref($query->{data}{meanRtt});
     $query->{data}{maxIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{maxIpd}) || ref($query->{data}{maxIpd});
     $query->{data}{duplicates}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{duplicates}) || ref($query->{data}{duplicates});
     $query->{data}{minIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{minIpd}) || ref($query->{data}{minIpd});
     $query->{data}{meanIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{meanIpd}) || ref($query->{data}{meanIpd});
     $query->{data}{iqrIpd}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{iqrIpd}) || ref($query->{data}{iqrIpd});
     $query->{data}{lossPercent}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{lossPercent}) || ref($query->{data}{lossPercent});
     $query->{data}{seqNums}= [ 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum' ] if!(defined $query->{data}{seqNums}) || ref($query->{data}{seqNums});

    eval {
        foreach my $table  ( keys %defined_table) {
            foreach my $entry (@{$defined_table{$table}}) {
                if(ref($query->{$table}{$entry}) eq 'ARRAY') {
                    foreach my $classes (@{$query->{$table}{$entry}}) {
                         if($classes && $classes eq 'perfSONAR_PS::SONAR_DATATYPES::v2_0::pinger::Message::Data::Datum') {
        
                            if    ($self->get_ttl && ( (  ($entry eq 'ttl')) )) {
                                $query->{$table}{$entry} =  $self->get_ttl;
                                $self->get_LOGGER->debug(" Got value for SQL query $table.$entry: " . $self->get_ttl);
                                last;  
                            }

                            elsif ($self->get_numBytes && ( (  ($entry eq 'numBytes')) )) {
                                $query->{$table}{$entry} =  $self->get_numBytes;
                                $self->get_LOGGER->debug(" Got value for SQL query $table.$entry: " . $self->get_numBytes);
                                last;  
                            }

                            elsif ($self->get_value && ( (  ( ($self->get_name eq 'minRtt')  && $entry eq 'minRtt') or  ( ($self->get_name eq 'maxRtt')  && $entry eq 'maxRtt') or  ( ($self->get_name eq 'outOfOrder')  && $entry eq 'outOfOrder') or  ($entry eq 'rtts') or  ( ($self->get_name eq 'medianRtt')  && $entry eq 'medianRtt') or  ( ($self->get_name eq 'clp')  && $entry eq 'clp') or  ( ($self->get_name eq 'meanRtt')  && $entry eq 'meanRtt') or  ( ($self->get_name eq 'maxIpd')  && $entry eq 'maxIpd') or  ( ($self->get_name eq 'duplicates')  && $entry eq 'duplicates') or  ( ($self->get_name eq 'minIpd')  && $entry eq 'minIpd') or  ( ($self->get_name eq 'meanIpd')  && $entry eq 'meanIpd') or  ( ($self->get_name eq 'iqrIpd')  && $entry eq 'iqrIpd') or  ( ($self->get_name eq 'lossPercent')  && $entry eq 'lossPercent')) )) {
                                $query->{$table}{$entry} =  $self->get_value;
                                $self->get_LOGGER->debug(" Got value for SQL query $table.$entry: " . $self->get_value);
                                last;  
                            }

                            elsif ($self->get_seqNum && ( (  ($entry eq 'seqNums')) )) {
                                $query->{$table}{$entry} =  $self->get_seqNum;
                                $self->get_LOGGER->debug(" Got value for SQL query $table.$entry: " . $self->get_seqNum);
                                last;  
                            }

                            elsif ($self->get_text && ( (  ( ($self->get_name eq 'minRtt')  && $entry eq 'minRtt') or  ( ($self->get_name eq 'maxRtt')  && $entry eq 'maxRtt') or  ( ($self->get_name eq 'outOfOrder')  && $entry eq 'outOfOrder') or  ( ($self->get_name eq 'medianRtt')  && $entry eq 'medianRtt') or  ( ($self->get_name eq 'clp')  && $entry eq 'clp') or  ( ($self->get_name eq 'meanRtt')  && $entry eq 'meanRtt') or  ( ($self->get_name eq 'duplicates')  && $entry eq 'duplicates') or  ( ($self->get_name eq 'maxIpd')  && $entry eq 'maxIpd') or  ( ($self->get_name eq 'minIpd')  && $entry eq 'minIpd') or  ( ($self->get_name eq 'meanIpd')  && $entry eq 'meanIpd') or  ( ($self->get_name eq 'iqrIpd')  && $entry eq 'iqrIpd') or  ( ($self->get_name eq 'lossPercent')  && $entry eq 'lossPercent')) )) {
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
    $self->set_ttl($dom->getAttribute('ttl')) if($dom->getAttribute('ttl'));

    $self->get_LOGGER->debug("Attribute ttl= ". $self->get_ttl) if $self->get_ttl;
    $self->set_numBytes($dom->getAttribute('numBytes')) if($dom->getAttribute('numBytes'));

    $self->get_LOGGER->debug("Attribute numBytes= ". $self->get_numBytes) if $self->get_numBytes;
    $self->set_value($dom->getAttribute('value')) if($dom->getAttribute('value'));

    $self->get_LOGGER->debug("Attribute value= ". $self->get_value) if $self->get_value;
    $self->set_name($dom->getAttribute('name')) if($dom->getAttribute('name') && ($dom->getAttribute('name')   =~ m/(minRtt|maxRtt|meanRtt|medianRtt|lossPercent|clp|minIpd|maxIpd|iqrIpd|meanIpd|duplicates|outOfOrder)$/));

    $self->get_LOGGER->debug("Attribute name= ". $self->get_name) if $self->get_name;
    $self->set_valueUnits($dom->getAttribute('valueUnits')) if($dom->getAttribute('valueUnits'));

    $self->get_LOGGER->debug("Attribute valueUnits= ". $self->get_valueUnits) if $self->get_valueUnits;
    $self->set_timeValue($dom->getAttribute('timeValue')) if($dom->getAttribute('timeValue'));

    $self->get_LOGGER->debug("Attribute timeValue= ". $self->get_timeValue) if $self->get_timeValue;
    $self->set_seqNum($dom->getAttribute('seqNum')) if($dom->getAttribute('seqNum'));

    $self->get_LOGGER->debug("Attribute seqNum= ". $self->get_seqNum) if $self->get_seqNum;
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


