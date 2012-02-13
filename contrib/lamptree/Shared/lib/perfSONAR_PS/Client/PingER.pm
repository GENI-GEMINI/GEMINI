package perfSONAR_PS::Client::PingER;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Client::PingER

=head1 DESCRIPTION

Client API for calling PingER MA from a client or another service.  Module
inherits from perfSONAR_PS::Client::MA and overloads callMA, metadataKeyRequest
and setupDataRequest Also it provides handy helper methods to get normalized
metadata and data

=cut

use Log::Log4perl qw( get_logger );
use English qw( -no_match_vars );

use perfSONAR_PS::Common qw( genuid );
use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::Client::MA;
use Data::Dumper;

use aliased 'perfSONAR_PS::Datatypes::EventTypes';

use aliased 'perfSONAR_PS::Datatypes::Message';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Data';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata::Key' => 'MetaKey';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::pinger::Message::Metadata::Parameters' => 'PingerParams';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::pinger::Message::Metadata::Subject' => 'MetaSubj';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::select::Message::Metadata::Parameters' => 'SelectParams';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::select::Message::Metadata::Subject'    => 'SelectSubj';

use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwg::Message::Metadata::Parameters::Parameter';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Dst';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair::Src';
use aliased 'perfSONAR_PS::PINGER_DATATYPES::v2_0::nmwgt::Message::Metadata::Subject::EndPointPair';

use base 'perfSONAR_PS::Client::MA';

=head2

Set custom LOGGER object. must be compatible with Log::Log4perl 

=cut

sub setLOGGER {
    my ( $self, $logger ) = @_;
    if ( $logger->isa( 'Log::Log4perl' ) ) {
        $self->{LOGGER} = $logger;
    }
    return $self->{LOGGER};

}

=head2 callMA($self { message })

Calls the MA instance with  request message DOM and returns the response message object. 

=cut

sub callMA {
    my ( $self, $message_dom ) = @_;
    my $msg;
    eval { $msg = $self->SUPER::callMA( message => $message_dom->asString, timeout => 300 ); };
    if ( $EVAL_ERROR || !$msg ) {
        $self->{LOGGER}->error( "Message element not found in return. $EVAL_ERROR" );
        return;
    }
    return Message->new( $msg );
}

=head2 metadataKeyRequest($self, { subject, eventType,  metadata, src_name => 0, dst_name => 0,   parameters })

Perform a MetadataKeyRequest, the result returned as message DOM:

  subject - subject XML
  metadata -  metadata- XML
  eventType - if other than pinger eventtype 
  src_name and dst_name are optional hostname pair
  parameters is hashref with pinger parameters from this list:  count packetSize interval 
  
=cut

sub metadataKeyRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { xml => 0, metadata => 0, subject => 0, src_name => 0, dst_name => 0, parameters => 0 } );
    my $eventType  = EventTypes->new();
    my $metaid     = genuid();
    my $message    = Message->new( { 'type' => 'MetadataKeyRequest', 'id' => 'message.' . genuid() } );
    $self->{LOGGER}->debug( "Messagge: " . $message->asString );
    if ( $parameters->{xml} ) {
        $message = Message->new( { xml => $parameters->{xml} } );
    }
    else {
        $parameters->{id}        = $metaid;
        $parameters->{eventType} = $eventType->tools->pinger;
        my $metadata = $self->getMetaSubj( $parameters );

        # create the  element
        my $data = Data->new( { 'metadataIdRef' => "metaid$metaid", 'id' => "data$metaid" } );

        $message->set_metadata( [$metadata] );
        $message->set_data(     [$data] );
    }
    $self->{LOGGER}->debug( "MDKR: " . $message->asString );
    return $self->callMA( $message );
}

=head2 getMetaSubj ($self,   { id , metadata , subject ,  key , src_name  , dst_name ,   parameters  })
   
Returns metadata object with pinger subj and pinger parameters 
   
Manditory:
   
   id => id of the metadata,
   eventType => pigner eventtype
   
Optional:
   idRef => metadataIdRef
   metadata => XML string of the whole metadata, if supplied then the rest of parameters dont matter
   
   key => key value, if supplied then the rest of parameters dont matter
   subject => XML string of the subject, if supplied then the rest of parameters dont matter
   src_name =>  source nostname
   dst_name => destination hostname
   parameters => pinger parameters from this list:  count packetSize interval 
   
=cut

sub getMetaSubj {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            id         => 1,
            metadata   => 0,
            start      => 0,
            end        => 0,
            eventType  => 1,
            subject    => 0,
            key        => 0,
            idRef      => 0,
            cf         => 0,
            resolution => 0,
            src_name   => 0,
            dst_name   => 0,
            parameters => 0
        }
    );

    my $metaid = $parameters->{id};
    my $md;
    if ( $parameters->{metadata} ) {
        $md = Metadata->new( { xml => $parameters->{metadata} } );
    }
    elsif ( $parameters->{key} ) {
        $md = Metadata->new( { key => MetaKey->new( { id => $parameters->{key} } ) } );
        if ( $parameters->{start} || $parameters->{end} ) {
            $parameters->{md} = $md;
            $md = $self->getMetaTime( $parameters );
        }
    }
    else {
        $md = Metadata->new();
        my $subject = MetaSubj->new( { id => "subj$metaid" } );
        if ( $parameters->{subject} ) {
            $subject = MetaSubj->new( { xml =>  $parameters->{subject} } );
        }
        else {

            if ( $parameters->{src_name} || $parameters->{dst_name} ) {
                my $endpoint = EndPointPair->new();
                $endpoint->set_src( Src->new( { value => $parameters->{src_name}, type => 'hostname' } ) ) if $parameters->{src_name};
                $endpoint->set_dst( Dst->new( { value => $parameters->{dst_name}, type => 'hostname' } ) ) if $parameters->{dst_name};
                $subject->set_endPointPair( $endpoint );
            }
        }
        $md->set_subject( $subject );
        if ( $parameters->{parameters} && ref $parameters->{parameters} eq 'HASH' ) {
            my @params;
            my $meta_params = PingerParams->new( { id => "params$metaid" } );
            foreach my $p ( qw/count packetSize interval/ ) {
                if ( $parameters->{parameters}->{$p} ) {
                    my $param = Parameter->new( { 'name' => $p } );
                    $param->set_text( $parameters->{parameters}->{$p} );
                    push @params, $param;
                }
            }

            # add the params to the parameters
            if ( @params ) {
                $meta_params->set_parameter( \@params );
                $md->addParameters( $meta_params );
            }
        }
    }
    $md->set_id( "metaid" . $parameters->{id} );
    $md->set_metadataIdRef( "metaid" . $parameters->{idRef} ) if $parameters->{idRef};
    $md->set_eventType( $parameters->{eventType} );
    $self->{LOGGER}->info( " metamd= " . $md->asString );
    return $md;

}

=head2 getMetaTime 

Returns metadata object with select subj and time range parameters
   
Manditory:
   
   id => 1, 
   idRef => 1,
   
Optional:
    
   metadata => 0,  
   cf => consolidationFunction ( average, min, max )
   resolution => how many datums return for the period of time ( from 0 to 1000)
   start => start time in seconds since epoch ( GMT )
   end => end  time in seconds since epoch ( GMT )
   
=cut

sub getMetaTime {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            id         => 1,
            eventType  => 1,
            metadata   => 0,
            md         => 0,
            start      => 0,
            end        => 0,
            subject    => 0,
            key        => 0,
            cf         => 0,
            resolution => 0,
            src_name   => 0,
            dst_name   => 0,
            parameters => 0
        }
    );

    my $metaid = $parameters->{id};

    my $md = $parameters->{md};
    if ( $parameters->{metadata} ) {
        $md = Metadata->new( { xml => $parameters->{metadata} } );
    }
    else {
        $md = Metadata->new() unless $md;
        my @params;
        my $time_params = PingerParams->new( { id => "params$metaid" } );
        if ( $parameters->{start} ) {
            push @params, Parameter->new( { name => 'startTime', type => 'unix', text => $parameters->{start} } );
        }
        if ( $parameters->{end} ) {
            push @params, Parameter->new( { name => 'endTime', type => 'unix', text => $parameters->{end} } );
        }
        if ( $parameters->{cf} ) {
            my $up_cf = uc( $parameters->{cf} );
            $self->{LOGGER}->logdie( "Unsupported consolidationFunction  $up_cf" )
                unless $up_cf =~ /^(AVERAGE|MIN|MAX)$/;
            push @params, Parameter->new( { name => 'consolidationFunction', text => $up_cf } );
        }
        if ( $parameters->{resolution} ) {
            $self->{LOGGER}->logdie( "Resolution must be > 0 and < 1000" ) if $parameters->{resolution} < 0 || $parameters->{resolution} > 1000;
            push @params, Parameter->new( { name => 'resolution', text => $parameters->{resolution} } );
        }

        # add the params to the parameters
        if ( @params ) {
            $time_params->set_parameter( \@params );
            $md->addParameters( $time_params );
        }

    }
    unless ( $parameters->{md} ) {
        $md->set_id( "metaid" . $metaid );
        $md->set_eventType( $parameters->{eventType} );
    }
    return $md;

}

=head2 setupDataRequest($self, { subject, eventType, src_name => 0, dst_name => 0,  parameters, start, end  })

Perform a SetupDataRequest, the result is returned  as message DOM:

  subject - subject XML
  keys - one or more keys to query, multiple keys will result in multiple subject metadatas and data elements
  eventType - if other than pinger eventtype 
  start, end   are optional time range parameters
  src_name and dst_name are optionla hostname pair
  parameters is hashref with pinger parameters from this list:  count packetSize interval 
  
=cut

sub setupDataRequest {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            xml        => 0,
            metadata   => 0,
            subject    => 0,
            keys       => 0,
            cf         => 0,
            resolution => 0,
            start      => 0,
            end        => 0,
            src_name   => 0,
            dst_name   => 0,
            parameters => 0
        }
    );
    my $eventType = EventTypes->new();
    $parameters->{eventType} = $eventType->tools->pinger;

    my $metaid = genuid();
    my $message = Message->new( { 'type' => 'SetupDataRequest', 'id' => 'message.' . genuid() } );

    if ( $parameters->{xml} ) {
        $message = Message->new( { xml => $parameters->{xml} } );
    }
    else {
        $parameters->{id} = genuid();
        my $keys = $parameters->{keys} ? delete $parameters->{keys} : undef;

        if ( $keys && ref $keys eq 'ARRAY' ) {
            foreach my $key ( @{$keys} ) {
                $parameters->{message} = $message;
                $parameters->{key}     = $key;
                $message               = $self->getPair( $parameters );
            }
        }
        else {
            my $md_time = $self->getMetaTime( $parameters );
            $message->addMetadata( $md_time );
            $parameters->{idRef} = $parameters->{id};
            $message = $self->getPair( $parameters );
        }
    }
    $self->{LOGGER}->debug( "SDR: " . $message->asString );
    return $self->callMA( $message );

}

=head2 getPair
 
Helper method accepts parameters, returns subject md / select md and data pair.

=cut

sub getPair {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            message    => 1,
            idRef      => 0,
            id         => 0,
            metadata   => 0,
            subject    => 0,
            key        => 0,
            cf         => 0,
            resolution => 0,
            start      => 0,
            end        => 0,
            src_name   => 0,
            dst_name   => 0,
            eventType  => 1,
            parameters => 0
        }
    );

    my $message = delete $parameters->{message};
    $parameters->{id} = genuid();
    my $md_pinger = $self->getMetaSubj( $parameters );

    # create the  element
    my $data = Data->new( { 'metadataIdRef' => "metaid$parameters->{id}", 'id' => "data$parameters->{id}" } );
    return unless $message;
    $message->addMetadata( $md_pinger ) if $md_pinger;
    $message->addData( $data )          if $data;
    return $message;

}

=head2 getMetaID ($message_response_object)
 
Helper method, accepts response object, returns ref to hash with pairs as:
     
     "$src:$dst:$packetSize" => { 
          src_name    => $src,
          dst_name    => $dst,
          packet_size => $packetSize,
	  keys => [ array of metadata keys assigned with "$src:$dst:$packetSize" ],
          metaIDs	 => [ array of metadata ids ]
     }

=cut

sub getMetaData {
    my ( $self, $response ) = @_;
    my $metaids = {};
    unless ( $response && $response->isa( 'perfSONAR_PS::Datatypes::Message' ) ) {
        $self->{LOGGER}->error( " Attempted to get metadata from empty response" );
        return;
    }
    foreach my $md ( @{ $response->get_metadata } ) {
        unless ( $md->get_key && $md->get_subject ) {
            $self->{LOGGER}->debug( "Skipping metadata - key or subject is missing " );
            next;
        }

        my $key_id  = $md->get_key->get_id;
        my $subject = $md->get_subject;       #first subj
        unless ( $subject && $subject->get_endPointPair ) {
            $self->{LOGGER}->get_error( "Malformed metadata in response -  subject is missing " );
            next;
        }
        my $endpoint = $subject->get_endPointPair;      # first endpoint
        my $src      = $endpoint->get_src->get_value;
        my $dst      = $endpoint->get_dst->get_value;
        my $packetSize;
        foreach my $params ( @{ $md->get_parameters } ) {
            foreach my $param ( @{ $params->get_parameter } ) {
                if ( $param->get_name eq 'packetSize' ) {
                    $packetSize = $param->get_value ? $param->get_value : $param->get_text;
                    last;
                }
            }
        }
        my $composite_key = "$src:$dst:$packetSize";
        my $data_obj      = $response->getDataByMetadataIdRef( $md->get_id );
        $key_id = $data_obj->get_key->get_id if !( defined $key_id ) && $data_obj->get_key && $data_obj->get_key->get_id;
        if ( exists $metaids->{$composite_key} ) {
            push @{ $metaids->{$composite_key}{metaIDs} }, $md->get_id;
            push @{ $metaids->{$composite_key}{keys} },    $key_id;
        }
        else {
            $metaids->{$composite_key} = {
                keys => [ ( $key_id ) ],
                src_name   => $src,
                dst_name   => $dst,
                packetSize => $packetSize,
                metaIDs    => [ ( $md->get_id ) ]
            };
        }

    }
    return $metaids;
}

=head2 getData ($message_response_object)
   
Helper method accepts response object, returns extended metadata hashref with
extra subkey - data which is ref to hash with epoch time as a key and value is
ref to hash with datums ( name => value )
      
     "$src:$dst:$packetSize" => { 
          src_name    => $src,
          dst_name    => $dst,
          packet_size => $packetSize,
	  data =>  { "$timestamp" => { "$datum_name" => "$datum_value" ...   } }
	  keys => [ array of metadata keys assigned with "$src:$dst:$packetSize" ],
          metaIDs	 => [ array of metadata ids ]
     }

=cut

sub getData {
    my ( $self, $response ) = @_;

    $self->{LOGGER}->error( "Must be perfSONAR_PS::Datatypes::Message object" )
        unless $response
            && blessed $response
            && $response->isa( 'perfSONAR_PS::Datatypes::Message' );
    my $metadata = $self->getMetaData( $response );

    foreach my $uniq_key ( keys %{$metadata} ) {

        my $metaids = $metadata->{$uniq_key}{metaIDs};
        my $data    = {};
        for ( my $count = 0; $count < scalar( @{$metaids} ); $count++ ) {
            my $metaid   = $metaids->[$count];
            my $key      = $metadata->{$uniq_key}{keys}->[$count];
            my $data_obj = $response->getDataByMetadataIdRef( $metaid );
            next unless $data_obj;
            my $times = $data_obj->get_commonTime;
            next unless $times;
            foreach my $ctime ( @{$times} ) {
                my $timev = $ctime->get_value;
                next unless $ctime->get_datum && ref $ctime->get_datum eq 'ARRAY';
                foreach my $datum ( @{ $ctime->get_datum } ) {
                    $data->{$key}{$timev}{ $datum->get_name } = $datum->get_value;
                }

            }
        }
        $metadata->{$uniq_key}{data} = $data;
    }
    return $metadata;
}

1;

__END__

=head1 SYNOPSIS

    #!/usr/bin/perl -w

    use strict;
    use warnings;
    use perfSONAR_PS::Client::PingER;

    my $metadata = qq{ <nmwg:metadata id="metaBase">
        <pinger:subject xmlns:pinger="http://ggf.org/ns/nmwg/tools/pinger/2.0/" id="subject1">
         <nmwgt:endPointPair xmlns:nmwgt="http://ggf.org/ns/nmwg/topology/2.0/">
            <nmwgt:src type="hostname" value="newmon.bnl.gov"/> 
             <nmwgt:dst type="hostname" value="pinger.slac.stanford.edu"/> 
        </nmwgt:endPointPair>
       </pinger:subject>
       <nmwg:eventType>http://ggf.org/ns/nmwg/tools/pinger/2.0/</nmwg:eventType>
       </nmwg:metadata>
  };
   

    my $ma = new perfSONAR_PS::Client::PingER(
      { instance => "http://packrat.internet2.edu:8082/perfSONAR_PS/services/pigner/ma"}
    );

    
    my ( $sec, $frac ) = Time::HiRes::gettimeofday;

    my $result = $ma->metadataKeyRequest( { 
        metadata => $metadata 
     );
     #
     #   or 
     #
     $result = $ma->metadataKeyRequest( { 
        src_name => 'www.fnal.gov', dst_name => 'some.lab.gov'
     );
     #
     #   or  with parameters
     #
     $result = $ma->metadataKeyRequest( { 
        src_name => 'www.fnal.gov', dst_name => 'some.lab.gov',
	parameters => { count => 10, packetSize => 1000 }
     );
     #
     #   get data for metadata snippet
     #
    $result = $ma->setupDataRequest( { 
         start => ($sec-3600), 
         end => $sec, 
         metadata => $metadata 
         parameters => {count => 10}
      } );
     #
     #   or with all parameters 
     #
    
     $result = $ma->setupDataRequest( { 
         start => ($sec-3600), 
         end => $sec, 
        src_name => 'www.fnal.gov', 
	dst_name => 'some.lab.gov',
        parameters => {count => 10}
      } );
      #
      #  or by Key
      #
       $result = $ma->setupDataRequest( { 
         start => ($sec-3600), 
         end => $sec, 
         key => '123456',
      } );
      #
      #   normalize metadata and print src_dst_packetsize 
      #
      
      foreach my $src_dst_packetsize (keys %{$self->getMetaData($result)})
           print "Src:DST:packetsize key = $src_dst_packetsize \n";
      }

=head1 SEE ALSO

L<Log::Log4perl>, L<English>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Utils::ParameterValidation>, L<perfSONAR_PS::Client::MA>,
L<Data::Dumper>, L<aliased>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list
 
=head1 AUTHOR

Maxim Grigoriev, maxim_at_fnal_gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software.  

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
