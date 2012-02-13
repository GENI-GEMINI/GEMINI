package perfSONAR_PS::Datatypes::Message;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Datatypes::Message  -  this is a message handler object

=head1 DESCRIPTION

New will return undef in case of wrong parameters ( will return Error object in
the future ) it accepts only one parameter -  reference, thats it

The reference might be of type:
   hashref to the hash  with named parameters which can be used to initialize this object
      or
   DOM object 
     or 
   hashref with single key { xml => <xmlString>}, where xmlString ,must be valid Message xml element  or document

It extends: 
     
    use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message; 
   
Namespaces will be added dynamically from the underlying data and metadata

=head1 Methods   
   
=cut

use English qw( -no_match_vars);
use Log::Log4perl qw(get_logger);
###use Clone::Fast qw(clone);
use XML::LibXML;
use Scalar::Util qw(blessed);
use Data::Dumper;

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgr::Message::Data::Datum' => 'ResultDatum';

use perfSONAR_PS::Datatypes::EventTypes;

use base qw(perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message);
use fields qw(eventTypes mdID dataID filters DBO);

Readonly::Scalar our $CLASSPATH => 'perfSONAR_PS::Datatypes::Message';
Readonly::Scalar our $LOCALNAME => 'message';

=head2 new( )
   
Creates message object, accepts parameter in form of:
      
  DOM with nmwg:message element tree or hashref to the list of
    type => <string>, id => <string> , namespace => {}, metadata => {}, ...,   data   => { }  ,
 	 
  or DOM object or hashref with single key { xml => <xmlString>}

It extends:
     use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message 

All parameters will be passed first to superclass
  
=cut

sub new {
    my $that  = shift;
    my $param = shift;

    my $class = ref( $that ) || $that;
    my $self = fields::new( $class );
    $self = $self->SUPER::new( $param );    # init base fields
    $self->eventTypes( perfSONAR_PS::Datatypes::EventTypes->new() );
    $self->set_LOGGER( get_logger( $CLASSPATH ) );
    $self->mdID( 1 );
    $self->dataID( 1 );
    $self->set_nsmap( perfSONAR_PS::PINGER_DATATYPES::v2_0::NSMap->new() );
    $self->get_nsmap->mapname( $LOCALNAME, 'nmwg' );

    if ( $param && ref $param eq 'HASH' ) {
        $self->filters( $param->{filters} ) if $param->{filters};
        $self->DBO( $param->{DBO} )         if $param->{DBO};
    }

    #$self->get_LOGGER->debug("  nsmap = ". Dumper $self  );

    return $self;
}

=head2 filters 

add another filter object ( md ) or return array of filters

=cut

sub addFilter {
    my $self = shift;
    my $arg  = shift;
    if ( $arg ) {
        return push @{ $self->{filters} }, $arg;
    }
    else {
        return $self->{filters};
    }
}

=head2  getDataByMetadataIdRef()

get specific element from the array of data elements by  MetadataIdRef ( if   MetadataIdRef is supported by this element )

Accepts single param -  MetadataIdRef 
 
If there is no array then it will return just an object

=cut

sub getDataByMetadataIdRef {
    my ( $self, $idref ) = @_;

    if ( ref( $self->get_data ) eq 'ARRAY' ) {
        foreach my $data ( @{ $self->get_data } ) {
            return $data if $data->get_metadataIdRef eq $idref;
        }
    }
    elsif ( !ref( $self->get_data ) || ref( $self->get_data ) ne 'ARRAY' ) {
        return $self->get_data;
    }
    $self->get_LOGGER->warn( "Requested element for non-existent metadataIdRef: $idref" );
    return;
}

=head2 filters 

set filters array or return it

=cut

sub filters {
    my $self = shift;
    my $arg  = shift;
    if ( $arg ) {
        return $self->{filters} = $arg;
    }
    else {
        return $self->{filters};
    }
}

=head2 eventTypes

set or return eventType 

=cut

sub eventTypes {
    my $self = shift;
    my $arg  = shift;
    if ( $arg ) {
        return $self->{eventTypes} = $arg;
    }
    else {
        return $self->{eventTypes};
    }
}

=head2 DBO

set or return DB object

=cut

sub DBO {
    my $self = shift;
    my $arg  = shift;
    if ( $arg ) {
        return $self->{DBO} = $arg;
    }
    else {
        return $self->{DBO};
    }
}

=head2  mdID

set id number for metadata element if no argument supplied then just return the
current one

=cut

sub mdID {
    my $self = shift;
    my $arg  = shift;
    if ( $arg ) {
        return $self->{mdID} = $arg;
    }
    else {
        return $self->{mdID};
    }
}

=head2 add_mdID

increment id number for metadata element

=cut

sub add_mdID {
    my $self = shift;
    $self->{mdID}++;
    return $self->{mdID};
}

=head2 add_dataID

increment id number for  data element

=cut

sub add_dataID {
    my $self = shift;
    $self->{dataID}++;
    return $self->{dataID};
}

=head2  dataID

set id number for  data element if no argument supplied then just return the
current one

=cut

sub dataID {
    my $self = shift;
    my $arg  = shift;
    if ( $arg ) {
        return $self->{dataID} = $arg;
    }
    else {
        return $self->{dataID};
    }

}

###=head2 getChain
###
###      accept current metadata and chain this metadata with every reffered metadata,
###      clone it, merge it with chained metadata and return new metadata
###       eventType must be the same or eventTypes->ops->select
###=cut
###
###sub getChain {
###    my $self = shift;
###    my $currentmd = shift;
###    ## clone this metadata
###   my $newmd = clone( $currentmd );
###   my $idref = $newmd->get_metadataIdRef;
###    ##check if its refered and eventType is the same
######    ##if($newmd->key &&   $newmd->key->id) {
###    ##    ## stop chaining since we found a key
###    ##    return $newmd;
###   ##}
######    if($idref) {
###        my $checkmd =   $self->getMetadataById($idref);
###        if(($newmd->get_eventType  eq    $checkmd->get_eventType) || ($checkmd->get_eventType eq $self->eventTypes->ops->select)) {
###           # recursion
###            my  $newInChain = $self->getChain($checkmd);
###           # merge according to implementation ( without filtering )
###	    $newmd->merge($newInChain);
###        } else {
###	    $self->get_LOGGER->error(" Reffered wrong eventType in the chain: " . $checkmd->get_eventType->asString );
###	}
###    }
###    return $newmd;
###}

=head2  addIDMetadata 
     
add supplied  metadata, set id and set supplied eventtype

arguments: $md,   $eventType 

md id will be set as  "meta$someid" then metaId counter will be increased

returns:  set metadata id
     
=cut

sub addIDMetadata {
    my ( $self, $md, $event ) = @_;
    my $current_mdid = $self->mdID;
    $md->set_id( "meta" . $self->mdID );
    $md->set_eventType( $event );
    $self->addMetadata( $md );    # send back original request
    $self->add_mdID;
    return $current_mdid;
}

=head2  addResultData

add  data with result datum only to the   message

arguments: hashref with keys - {metadataIdRef => $metaidkey, message =>  $message, eventType => $eventType})
      
returns:  set data id

=cut

sub addResultData {
    my ( $self, $params ) = @_;
    unless ( $params && ref( $params ) eq 'HASH' && $params->{metadataID} ) {
        $self->get_LOGGER->error( "Parameters missed:  addResultData Usage:: addResultData(\$params) where \$params is hashref" );
        return;
    }

    $params->{message} = ' no message ' unless $params->{message};
    my $current_id = $self->dataID;
    my $data       = Data->new(
        {
            id            => "data" . $self->dataID,
            metadataIdRef => "meta" . $params->{metadataID},
            datum         => [ ResultDatum->new( { text => $params->{message} } ) ]
        }
    );
    $self->addData( $data );
    $self->add_dataID;
    return $current_id;
}

=head2  addResultResponse

add md with eventype and data with result datum, where contents of the datum is some message

arguments: hashref - {md => $md, message =>  $message, eventType => $eventType})

if $md is not supplied then new will be created and 

returns: $self

=cut

sub addResultResponse {
    my ( $self, $params ) = @_;
    unless ( $params && ref( $params ) eq 'HASH' && $params->{eventType} ) {
        $self->get_LOGGER->error( "Parameters missed:  addResultResponse Usage:: addResultResponse(\$params) where \$params is hashref" );
        return;
    }
    unless ( $params->{md} && blessed $params->{md} ) {
        $params->{md} = Metadata->new();
        $self->get_LOGGER->debug( " New md was generated " );
    }
    $params->{message} = ' no message ' unless $params->{message};
    my $md_id = $self->addIDMetadata( $params->{md}, $params->{eventType} );
    $self->addResultData( { message => $params->{message}, metadataID => $md_id } );
    return $self;
}

=head2   MetadataKeyRequest

this is abstract handler method for MetadataKey request, accepts response Message object 

returns filled response message object  or error message
 
=cut

sub MetadataKeyRequest {
    my $self     = shift;
    my $response = shift;
    $self->get_LOGGER->debug( "MetadataKeyRequest  ..." );
    $self->get_LOGGER->error( "MetadataKeyRequest  handler  Not   implemented by the service " );
    return "MetadataKeyRequest  handler  Not   implemented by the service ";
}

=head2   SetupDataRequest

this is abstract handler method forSetupData request,  accepts response Message object 

returns filled response message object  or error message 

=cut

sub SetupDataRequest {
    my $self     = shift;
    my $response = shift;
    $self->get_LOGGER->debug( "SetupDataRequest  ..." );
    $self->get_LOGGER->error( " SetupDataRequest handler  Not   implemented by the service " );
    return "SetupDataRequest handler  Not   implemented by the service";
}

=head2   MeasurementArchiveStoreRequest

this is abstract method for MeasurementArchiveStore request, must be implemented by the tool

returns filled response message object  or error message 
    
=cut

sub MeasurementArchiveStoreRequest {
    my $self     = shift;
    my $response = shift;
    $self->get_LOGGER->error( " MeasurementArchiveStoreRequest   handler Not   implemented by the service " );
    return " MeasurementArchiveStoreRequest   handler Not   implemented by the service ";

}

=head2 buildQuery
 
build query for sql specific operation: ['lt', 'gt','eq','ge','le','ne'] 

arguments: operation and  element object to run querySQL on

returns: hashref to the found parameters and query as arrayref of form [  entryname1 => {'operator' => 'value1'},   entryname2 => {'operator' => 'value2'}, .... ]

the whole structure will look as:

{  'query_<tablename>' => [ <query> ], '<tablename>' => { sql_entry1 => value1, sql_entry2 => value2, ...} }
      
=cut

sub buildQuery {
    my $self    = shift;
    my $oper    = shift;
    my $element = shift;
    $self->get_LOGGER->debug( "  Quering...  " );

    my $queryhash = {};
    $element->querySQL( $queryhash );
    $self->get_LOGGER->debug( "  Done  " );

    foreach my $table ( keys %{$queryhash} ) {
        foreach my $entry ( keys %{ $queryhash->{$table} } ) {
            push @{ $queryhash->{"query_$table"} }, ( $entry => { $oper => $queryhash->{$table}{$entry} } ) if $queryhash->{$table}{$entry} && !ref( $queryhash->{$table}{$entry} );
        }
    }
    return $queryhash;
}

=head2  processTime
    
finds set time range from  any  element in the Message objects tree which is
able to contain nmtm parameter with startTime/endTime selects or timestamp

returns:  hashref suitable for SQL query in form of - { gt => <unix epoch time>, lt => <unix epoch time>} or { eq => <unix epoch time>}
    $timequery->{eq|gt|lt} = unix_time

arguments: hashref - {element => <element object with time inside>, timehash => <timehash in form of  {'start' => <>, 'end' =>'', duration => ''}>}
    
=cut

sub processTime {
    my $self   = shift;
    my $params = shift;
    unless (
           $params
        && ref( $params ) eq 'HASH'
        && (   ( $params->{timehash} && ref( $params->{timehash} ) eq 'HASH' )
            || ( $params->{element} && blessed $params->{element} && $params->{element}->can( "querySQL" ) ) )
        )
    {
        $self->get_LOGGER->error( "Parameters missed: element or timequery  " );
        return;
    }

    my $One_DAY_inSec = 86400;
    $params->{element}->querySQL( $params->{timehash} ) unless $params->{timehash};

    ##$self->get_LOGGER->debug("  -------> Timestamp=  ",  sub{Dumper($params->{timehash})});

    my %timequery = ( gt => time() - $One_DAY_inSec, lt => time() );

    $timequery{gt} = $params->{timehash}->{'start'} if $params->{timehash}->{'start'} && !ref( $params->{timehash}->{'start'} );
    if ( $params->{timehash}->{'duration'} && !ref( $params->{timehash}->{'duration'} ) ) {
        $timequery{lt} = $timequery{gt} + $params->{timehash}->{'duration'};
    }
    elsif ( $params->{timehash}->{'end'} && !ref( $params->{timehash}->{'end'} ) ) {
        $timequery{lt} = $params->{timehash}->{'end'};
    }
    else {
        %timequery = ( eq => $timequery{gt} );
    }
    unless ( $timequery{eq} || $timequery{gt} ) {
        $self->get_LOGGER->error( " Failed to get time values,possible missed start time or timestamp from the data element commonTime  " );
        return;
    }

    if ( $params->{timehash}{'cf'} && $params->{timehash}{'resolution'} ) {
        $timequery{count} = $params->{timehash}->{'resolution'};
        $timequery{function} = $params->{timehash}->{'cf'} eq 'AVERAGE' ? 'avg' : $params->{timehash}->{'cf'};
    }
    else {
        $self->get_LOGGER->debug( "  ---No cf -  full search : ", sub { Dumper( $params ) } );
    }
    $self->get_LOGGER->debug( "  -------> Processed Timestamp=  ", sub { Dumper( \%timequery ) } );
    return \%timequery;
}

1;

__END__

=head1 SYNOPSIS
             
  
	     use perfSONAR_PS::Datatypes::Message ;
	   
	     
	     my ($DOM) = $requestMessage->getElementsByTag('message');
	    
	     my $message = new perfSONAR_PS::Datatypes::Message($DOM);
             $message = new perfSONAR_PS::Datatypes::Message({id => '2345', 
	                                                     type = 'SetupdataResponse',
							     metadata => {'id1' =>   <obj>},
							     data=> {'id1' => <obj>}}); 
	 
	    #######   add data element, namespaces will be added from this object to Message object namespace declaration
             $message->addPartById('id1', 'data', new perfSONAR_PS::Datatypes::Message::data({id=> 'id1', metadataIdRef => 'metaid1' }));
        
	    ########add metadata element, namespaces will be added from this object to Message object namespace declaration
	     $message->addPartById('id1', 'metadata',  new perfSONAR_PS::Datatypes::Message::metadata({id=> 'id1' });
	     
	     my $dom = $message->getDOM(); # get as DOM 
	     print $message->asString();  # print the whole message

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Message.pm 3713 2009-09-22 22:22:03Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
