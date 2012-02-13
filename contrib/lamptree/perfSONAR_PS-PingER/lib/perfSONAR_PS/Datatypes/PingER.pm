package perfSONAR_PS::Datatypes::PingER;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Datatypes::PingER - implemenataion of the handler for the PingER MA messages

=head1 DESCRIPTION

This is a pinger message handler object.  It inherits everything from
perfSONAR_PS::Datatypes::Message and only implements  request handlers with
pinger specifics 

=head1 Methods
    
=cut

use English qw( -no_match_vars);
use Log::Log4perl qw(get_logger);
use POSIX qw(strftime);
use Data::Dumper;
use Scalar::Util qw(blessed);

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata::Key' => 'MetaKey';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data::Key'     => 'DataKey';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data::CommonTime';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgr::Message::Data::Datum'           => 'ResultDatum';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::pinger::Message::Metadata::Parameters' => 'PingerParams';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::pinger::Message::Metadata::Subject'       => 'PingerSubj';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::pinger::Message::Data::CommonTime::Datum' => 'PingerDatum';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::select::Message::Metadata::Parameters' => 'SelectParams';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::select::Message::Metadata::Subject'    => 'SelectSubj';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata::Parameters::Parameter';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Dst';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Src';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair';

use perfSONAR_PS::Datatypes::Message;
use perfSONAR_PS::Datatypes::EventTypes;
use perfSONAR_PS::DB::SQL::PingER;

use base qw(perfSONAR_PS::Datatypes::Message);

Readonly::Scalar our $CLASSPATH => 'perfSONAR_PS::Datatypes::PingER';
Readonly::Scalar our $LOCALNAME => 'message';

#
#   internal limit for the number of the data/metadata in the response message
#
our $_sizeLimit = '1000000';

=head2 new( )
   
Creates message object, accepts parameter in form of:

  DOM with nmwg:message element tree or hashref to the list of
    type => <string>, id => <string> , namespace => {}, metadata => {}, ...,   
    data   => { }  ,
 
  or DOM object or hashref with single key { xml => <xmlString>}

it extends:
  use perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message 

All parameters will be passed first to superclass
  
=cut

sub new {
    my $that  = shift;
    my $param = shift;

    my $class = ref( $that ) || $that;
    my $self = fields::new( $class );
    $self = $self->SUPER::new( $param );    # init base fields
    $self->get_nsmap->mapname( $LOCALNAME, 'nmwg' );
    $self->set_LOGGER( get_logger( $CLASSPATH ) );
    return $self;
}

=head2 handle 

Dispatch method. accepts type of request,response object and MA config hashref
as parameters, returns fully built response object, sets query size limit  

=cut

sub handle {
    my $self     = shift;
    my $type     = shift;
    my $response = shift;
    my $maconfig = shift;

    if ( $self->can( $type ) ) {
        eval {
            no strict 'refs';
            $_sizeLimit = $maconfig->{query_size_limit} if $maconfig && ref( $maconfig ) eq 'HASH' && $maconfig->{query_size_limit};
            $self->get_LOGGER->debug( " Size limit set to:  $_sizeLimit " );
            $type->( $self, $response );
        };
        if ( $EVAL_ERROR ) {
            $self->get_LOGGER->logdie( " Handler for $type failed: $EVAL_ERROR" );
        }
    }
    $self->get_LOGGER->debug( " Handler for $type Not supported" );
    return;
}

=head2   MetadataKeyRequest

Method for MetadataKey request,  works per event ( single pre-merged md  and
data pair) returns filled response message object 

  ##################  From Jason's SNMP MA code ##################
  # MA MetadataKeyRequest Steps
  # ---------------------
  # Is there a key?
  #   Y: do queries against key 
  #      return key as md AND d
  #   N: Is there a chain?
  #     Y: Is there a key
  #       Y: do queries against key, add in select stuff to key, return key as md AND d
  #       N: do md/d queries against md return results with altered key
  #     N: do md/d queries against md return results
  #--------------------------
 
=cut

sub MetadataKeyRequest {
    my $self     = shift;
    my $response = shift;
    $self->get_LOGGER->debug( "MetadataKeyRequest  ..." );

    unless ( $response && blessed $response && $response->can( "getDOM" ) ) {
        $self->get_LOGGER->error( " Please supply  metadata  object and not the:" . ref( $response ) );
        return " System error, API incomplete";
    }
    ##my $message_params = perfSONAR_PS::PINGER_DATATYPES::v2_0::select::Message::Parameters->new();
    ##my $message_limit = Message::Parameters::Parameter->new({name => 'sizeLimit', value =>  $_sizeLimit});
    ##$message_params->addParameter($message_limit);
    ##$response->addParameters($message_params);
    #### setting status URI for response
    $self->eventTypes->status->operation( 'metadatakey' );
    my $metadata = $self->get_metadata;
    $self->get_LOGGER->error( " Please supply  array of metadata and not: $metadata" ) unless $metadata && ref $metadata eq 'ARRAY';
    my $data      = $self->get_data->[0];
    my $requestmd = $metadata->[0];
    my $objects;    ### iterator returned by backend query
    if ( $requestmd->get_key && $requestmd->get_key->get_id ) {
        $self->get_LOGGER->debug( " Found Key =" . $requestmd->get_key->get_id );
        eval { $objects = $self->DBO->getMeta( [ metaID => { eq => $requestmd->get_key->get_id } ], 1 ); };
        if ( $EVAL_ERROR ) {
            $self->get_LOGGER->logdie( "PingER backend  Query failed: " . $EVAL_ERROR );
        }
    }
    elsif ( ( $requestmd->get_subject ) || ( $requestmd->get_parameters ) ) {
        my $query = { query_metaData => [] };
        $query = $self->buildQuery( 'eq', $requestmd );
        $query = { query_metaData => [] } unless $query;
        $self->get_LOGGER->debug( " Will query = ", sub { Dumper( $query ) } );
        eval { $objects = $self->DBO->getMeta( $query->{query_metaData}, _mdSetLimit( $query->{query_limit} ) ); };
        if ( $EVAL_ERROR ) {
            $self->get_LOGGER->logdie( "PingER backend  Query failed: " . $EVAL_ERROR );
        }
    }
    else {
        $self->get_LOGGER->warn( "Malformed request or missing key or parameters, md=" . $requestmd->get_id );
        $response->addResultResponse( { md => $requestmd, message => 'Malformed request or missing key or parameters', eventType => $self->eventTypes->status->failure } );
        return;
    }

    if ( $objects && ref $objects eq 'HASH' && %{$objects} ) {
        foreach my $metaid ( keys %{$objects} ) {
            $self->get_LOGGER->debug( "Found metaID " . $metaid );
            my $md = $self->ressurectMd( { md_row => $objects->{$metaid} } );
            my $md_id = $response->addIDMetadata( $md, $self->eventTypes->tools->pinger );
            $self->get_LOGGER->debug( " MD created: \n " . $md->asString );
            my $key = DataKey->new( { id => $metaid } );
            $self->get_LOGGER->debug( " KEY  created: \n " . $key->asString );
            my $data = Data->new( { id => "data" . $response->dataID, metadataIdRef => "meta$md_id", key => $key } );
            $self->get_LOGGER->debug( " DATA created: \n " . $data->asString );
            $response->addData( $data );    ##
            $self->get_LOGGER->debug( " DATA added" );
            $response->add_dataID;
        }
    }
    else {
        $response->addResultResponse( { md => $requestmd, message => ' no metadata found ', eventType => $self->eventTypes->status->failure } );
    }
    return 0;
}

=head2   SetupDataRequest

SetupData request, works per event ( single pre-merged md  and data pair)
returns filled response message object.  returns filled response  

  ##################  From Jason's SNMP MA code ##################
  # MA SetupdataRequest Steps
  # ---------------------
  #   Is there a key?
  #     Y: key in db?
  #         Y: chain metadata      
  #            extract data
  #         N: error out
  #     N: Is it a select?
  #         Y: Is there a matching MD?
  #             Y: Is there a key in the matching md?
  #                  Y: key in db?
  #                      Y: chain metadata 
  #                         extract data
  #                      N: error out
  #                 N:  chain metadata
  #                     extract data     
  #             N: Error out
  #        N: chain metadata
  #           extract data 

=cut

sub SetupDataRequest {
    my $self     = shift;
    my $response = shift;

    $self->get_LOGGER->debug( "SetupdataKeyRequest  ..." );

    unless ( $response && blessed $response && $response->can( "getDOM" ) ) {
        $self->get_LOGGER->error( " Please supply defined object of metadata and not:" . ref( $response ) );
        return "System error,  API incomplete";
    }
    ##my $message_params = SelectParams->new();
    ##my $message_limit  = Parameter->new({name => 'sizeLimit', value =>  $_sizeLimit});
    ##$message_params->addParameter($message_limit);
    ##$response->addParameters($message_params);
    #### setting status URI for response
    $self->eventTypes->status->operation( 'setupdata' );
    ####
    ### hashref to hold relation between metaID DB key and meta id
    my $metaids = {};
    ###  hashref to contain time selects metadata which will be
    ###  chained to the response metadata with pinger key (to re-use time range selects from request)
    my $time_selects = {};
    $self->get_LOGGER->debug( " Whole message : " . $self->asString );
    ### single data only ( per event ) set filters array as well
    my $data      = $self->get_data->[0];
    my $requestmd = $self->get_metadata->[0];
    my @filters   = $self->filters ? @{ $self->filters } : ();

    unless ( $requestmd ) {
        $self->get_LOGGER->error( "Orphaned data   - no  metadata found for metadataRefid:" . $data->get_metadataIdRef );
        return;
    }
    else {
        $self->get_LOGGER->debug( "Found metadata in request id=" . $requestmd->get_id . " metadata=" . $requestmd->asString );
    }
    ### objects hashref  returned by backend query with metaID as key
    my $objects_hashref = {};

    # if there is a Key, then get data arrayref
    my $query = {};
    if ( $requestmd->get_key && $requestmd->get_key->get_id ) {
        foreach my $supplied_md ( $requestmd, @filters ) {
            %{$query} = ( %{$query}, %{ $self->buildQuery( 'eq', $supplied_md ) } );
        }
        if (
            $self->_retrieveDataByKey(
                {
                    md          => $requestmd,
                    datas       => $objects_hashref,
                    timequery   => $self->processTime( { timehash => $query->{time} } ),
                    timeselects => $time_selects,
                    metaids     => $metaids,
                    response    => $response
                }
            )
            )
        {
            $response->addResultResponse( { md => $requestmd, message => 'no  matching data found', eventType => $self->eventTypes->status->failure } );
            return $response;
        }
    }
    elsif ( $requestmd->get_subject || $requestmd->get_parameters ) {
        my $md_objects = undef;
        eval {
            foreach my $supplied_md ( $requestmd, @filters )
            {
                %{$query} = ( %{$query}, %{ $self->buildQuery( 'eq', $supplied_md ) } );
            }
            $self->get_LOGGER->debug( " Will query = ", sub { Dumper( $query ) } );
            unless ( $query && $query->{query_metaData} && ref( $query->{query_metaData} ) eq 'ARRAY' && scalar @{ $query->{query_metaData} } >= 1 ) {
                $self->get_LOGGER->warn( " Nothing to query about for md=" . $requestmd->get_id);
                $response->addResultResponse(
                    {
                        md        => $requestmd,
                        message   => 'Nothing to query about(no key or parameters supplied)',
                        eventType => $self->eventTypes->status->failure
                    }
                );
                return $response;
            }
            $md_objects = $self->DBO->getMeta( $query->{query_metaData}, _mdSetLimit( $query->{query_limit} ) );
        };
        if ( $EVAL_ERROR ) {
            $self->get_LOGGER->logdie( "PingER backend  Query failed: " . $EVAL_ERROR );
        }
        my $timequery = $self->processTime( { timehash => $query->{time} } );

        if ( $md_objects && ( ref $md_objects eq 'HASH' ) && %{$md_objects} ) {
            foreach my $metaid ( sort { $a <=> $b } keys %{$md_objects} ) {
                my $md = $self->ressurectMd( { md_row => $md_objects->{$metaid} } );
                if (
                    $self->_retrieveDataByKey(
                        {
                            key         => $metaid,
                            timequery   => $timequery,
                            timeselects => $time_selects,
                            metaids     => $metaids,
                            datas       => $objects_hashref,
                            response    => $response
                        }
                    )
                    )
                {
                    $response->addResultResponse( { md => $md, message => 'no  matching data found', eventType => $self->eventTypes->status->failure } );
                    return $response;
                }
            }
        }
        else {
            $response->addResultResponse( { md => $requestmd, message => 'no metadata found', eventType => $self->eventTypes->status->failure } );
        }
    }
    else {
        $response->addResultResponse( { md => $requestmd, message => 'no key and no select in metadata  submitted', eventType => $self->eventTypes->status->failure } );
    }

    if ( $objects_hashref && ref $objects_hashref eq 'HASH' ) {
        ############################################################   here add all those found data elements
        foreach my $metaid ( keys %{$objects_hashref} ) {
            if ( %{ $objects_hashref->{$metaid} } ) {
                my $data = Data->new( { id => "data" . $response->dataID, metadataIdRef => "meta" . $metaids->{$metaid} } );
                foreach my $data_metaid ( sort { $a <=> $b } keys %{ $objects_hashref->{$metaid} } ) {
                    foreach my $timev ( sort { $a <=> $b } keys %{ $objects_hashref->{$metaid}->{$data_metaid} } ) {
                        $self->get_LOGGER->debug( " What is data row :", sub { Dumper( $objects_hashref->{$metaid}->{$data_metaid}->{$timev} ) } );
                        my $ctime = CommonTime->new( { type => 'unix', value => $timev } );

                        foreach my $entry ( qw/minRtt maxRtt medianRtt meanRtt clp iqrIpd lostPercent  maxIpd minIpd meanIpd duplicates outOfOrder/ ) {
                            next unless $objects_hashref->{$metaid}->{$data_metaid}->{$timev}->{$entry};
                            my $value = $objects_hashref->{$metaid}->{$data_metaid}->{$timev}->{$entry};
                            my $datum = PingerDatum->new( { name => $entry, value => $value } );
                            $ctime->addDatum( $datum );
                        }
                        $data->addCommonTime( $ctime );
                    }
                }
                $response->addData( $data );    ##
                $response->add_dataID;
            }
        }
    }
    return $response;
}

#  auxiliary private function
#  check if setLimit was requested in the query
#  if not then set default
#
sub _mdSetLimit {
    my $query = shift;
    if (   $query
        && ref $query eq 'ARRAY'
        && $query->[0]
        && ref $query->[0] eq 'HASH'
        && $query->[0]->{setLimit}
        && ref $query->[0]->{setLimit} eq 'HASH'
        && $query->[0]->{setLimit}->{eq}
        && $query->[0]->{setLimit}->{eq} >= 1 )
    {
        return $query->[0]->{setLimit}->{eq};
    }
    return $_sizeLimit;
}

=head2 ressurectMd
  
accepts SQL row or metaID and will create md element   and returns it as object

params: { metaId => <>, md_row => <> }
   
=cut

sub ressurectMd {
    my ( $self, $params ) = @_;
    unless ( $params && ref $params eq 'HASH' && ( $params->{md_row} || $params->{metaID} ) ) {
        $self->get_LOGGER->error( "Parameters missed:  md_row or metaID  are  required parameters" );
        return ' Parameters missed:  md_row , timequery are required parameters';
    }
    my $md;
    if ( $params->{metaID} ) {
        eval { ( $params->{metaID}, $params->{md_row} ) = each %{ $self->DBO->getMeta( [ 'metaID', { 'eq' => $params->{metaID} } ], 1 ) }; };
        if ( $EVAL_ERROR ) {
            $self->get_LOGGER->logdie( " Fatal error while calling Rose::DB object query" . $EVAL_ERROR );
        }
    }
    else {
        $params->{metaID} = $params->{md_row}->{metaID};
    }
    my $metaid = $params->{metaID};
    $md = Metadata->new();
    my $key = MetaKey->new( { id => $metaid } );

    my $subject = PingerSubj->new(
        {
            id           => "subj$metaid",
            endPointPair => EndPointPair->new(
                {
                    src => Src->new( { value => $params->{md_row}->{ip_name_src}, type => 'hostname' } ),
                    dst => Dst->new( { value => $params->{md_row}->{ip_name_dst}, type => 'hostname' } )
                }
            )
        }
    );

    my $pinger_params = PingerParams->new( { id => "params$metaid" } );
    my $param_arrref = [];
    no strict 'refs';

    foreach my $pparam ( qw/count packetSize ttl transport packetInterval protocol/ ) {
        if ( $params->{md_row}->{$pparam} ) {
            push @{$param_arrref}, Parameter->new( { name => $pparam, value => $params->{md_row}->{$pparam} } );
        }
    }
    use strict;
    $md->set_subject( $subject );
    if ( $param_arrref && @{$param_arrref} ) {
        $pinger_params->set_parameter( $param_arrref );
        $md->addParameters( $pinger_params );
    }
    $md->set_key( $key );
    return $md;
}

=head2 _createTimeSelect
  
auxiliary private function, creates time range select metadata and store it for reuse in timeselects hashref
   
=cut

sub _createTimeSelect {
    my ( $self, $params ) = @_;
    unless ( $params->{timequery} && ( ref $params->{timequery} eq 'HASH' ) && $params->{response} && $params->{timeselects} ) {
        $self->get_LOGGER->error( "Parameters missed:    timequery,  response and timeselects are  required parameters" );
        return ' Parameters missed:  timequery,  response and timeselects are required parameters';
    }
    my $id = $params->{timequery}->{eq} ? "eq=" . $params->{timequery}->{eq} : "lt=" . $params->{timequery}->{lt} . "_gt=" . $params->{timequery}->{gt};

    return $params->{timeselects}{$id}{md} if ( $params->{timeselects}{$id} && $params->{timeselects}{$id}{md} );
    my $selects = [];
    if ( $params->{timequery}->{eq} ) {
        push @{$selects}, Parameter->new( { name => 'timeStamp', value => $params->{timequery}->{eq} } );
    }
    elsif ( $params->{timequery}->{gt} && $params->{timequery}->{lt} ) {
        push @{$selects}, Parameter->new( { name => 'startTime', value => $params->{timequery}->{gt} } );
        push @{$selects}, Parameter->new( { name => 'endTime',   value => $params->{timequery}->{lt} } );
    }
    if ( $selects && @{$selects} ) {
        my $md = Metadata->new();
        $md->set_subject( SelectSubj->new( { id => "subj" . $params->{response}->mdID } ) );

        my $param_selects = SelectParams->new( { id => "params" . $params->{response}->mdID, parameter => $selects } );
        $md->addParameters( $param_selects );
        $self->get_LOGGER->debug( "--------- Created New time select: " . $md->asString );
        $params->{timeselects}{$id}{md} = $params->{response}->addIDMetadata( $md, $self->eventTypes->ops->select );
        return $params->{timeselects}{$id}{md};
    }
    return 'Malformed request - missing time range';
}

=head2 _createTimeSelect
  
auxiliary private function, this one will find time range from md, find proper
list of data tables and will query data tables by metaID key

parameters - hashref to { md => $metadata_obj, datas => $iterators_attayref, key => $metaKey, timequery => $timequery_hashref, tables => $tables_hashref, response => response} 

return 0 if everything OK, result will be added as data objects arrayref to the
  {datas} arrayref
return 1 if something is wrong
   
=cut

sub _retrieveDataByKey {
    my ( $self, $params ) = @_;
    unless ( $params
        && ref $params eq 'HASH'
        && ( $params->{key} || ( $params->{md} && blessed $params->{md} ) )
        && $params->{response}
        && blessed $params->{response}
        && $params->{metaids}
        && $params->{datas}
        && $params->{timeselects} )
    {
        $self->get_LOGGER->error( "Parameters missed:  md,response,iterators,metaids,timeselects are required parameters" );
        return -1;
    }
    my $keyid = $params->{key} ? $params->{key} : ( $params->{md} && blessed $params->{md} ) ? $params->{md}->get_key->get_id : $self->get_LOGGER->( " md or key MUST be provided" );
    return ' Key parameter  missed ' unless $keyid;
    $params->{timequery} = $self->processTime( { element => $params->{md} } ) unless $params->{timequery};

    unless ( $params->{timequery} && ref( $params->{timequery} ) eq 'HASH' ) {
        $self->get_LOGGER->error( "No time range in the query found" );
        $params->{response}->addResultResponse( { md => $params->{md}, message => 'No time range in the query found', eventType => $self->eventTypes->status->failure } );
        return -1;
    }

    my @timestamp_conditions = map { ( 'timestamp' => { $_ => $params->{timequery}->{$_} } ) } keys %{ $params->{timequery} };
    my $iterator_local = $self->DBO->getData( [ metaID => { eq => $keyid }, @timestamp_conditions ], undef, $_sizeLimit );
    if ( %{$iterator_local} ) {
        $params->{datas}->{$keyid} = $iterator_local;
        my $idref = $self->_createTimeSelect( $params );
        $self->get_LOGGER->debug( " Created Time Select ..... ......id=$idref" );
        my $pinger_md = $self->ressurectMd( { metaID => $keyid } );
        $pinger_md->set_metadataIdRef( $idref ) if $idref;
        $params->{metaids}->{$keyid} = $params->{response}->addIDMetadata( $pinger_md, $self->eventTypes->tools->pinger );
        return;
    }
    return -1;

}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: PingER.pm 4097 2010-05-13 19:42:25Z maxim $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
