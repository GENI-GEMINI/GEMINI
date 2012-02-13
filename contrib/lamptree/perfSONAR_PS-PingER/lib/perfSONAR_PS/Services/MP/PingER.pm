package perfSONAR_PS::Services::MP::PingER;

use strict;

#use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::MP::PingER

=head1 DESCRIPTION

A module that performs the tasks of an MP designed for the ping measurement
under the framework of the PingER project.  The purpose of this module is to
create objects that contain all necessary information to make ping measurements
to various hosts. It supports a scheduler to perform the pings as defined in the
store.xml file (which is locally stored under $self->{'STORE'}).

Internally, two helper packages are part of this module: an Agent class, which
performs the tests, a Scheduler class which organises the tests to be run, and a
Config class which parses the STORE file.

=head1 API

=cut

use English qw( -no_match_vars);

# db storage
use perfSONAR_PS::DB::SQL::PingER;

# agent class for pinger
use perfSONAR_PS::Services::MP::Agent::PingER;

# config and scheduling
use perfSONAR_PS::Services::MP::Config::PingER;

use perfSONAR_PS::Client::LS::Remote;
use perfSONAR_PS::Topology::ID qw(idIsFQ);

use Scalar::Util qw(blessed);
use Data::Dumper;

# inherit from the the scheduler class to enable random waits between tests
use perfSONAR_PS::Services::MP::Scheduler;

use base 'perfSONAR_PS::Services::MP::Scheduler';

use fields qw( DATABASE LS_CLIENT eventTypes);

use Log::Log4perl qw(get_logger);
our $logger = get_logger( "perfSONAR_PS::Services::MP::PingER" );

# use this to identify the configuration element to pick up
our $basename = 'pingermp';

our $processName     = 'perfSONAR-PS PingER MP';
our $ping_parameters = ' -c %count% -i %interval% -s %packetSize% -t %ttl% %destination%';

=head2 new( $conf )

create a new MP instance from hash array $conf.

=cut

sub new {
    my $that  = shift;
    my $class = ref( $that ) || $that;
    my $self  = fields::new( $class );
    $self                = $self->SUPER::new( @_ );
    $self->{'DATABASE'}  = undef;
    $self->{'LS_CLIENT'} = undef;
    $self->{eventTypes}  = perfSONAR_PS::Datatypes::EventTypes->new();
    return $self;
}

=head2 init( )

Set up the MP and configure the relevant handlers to use in order to enable 
on-demand measurements.

=cut

sub init {
    my $self    = shift;
    my $handler = shift;

    # check handler type
    $logger->logdie( "Handler is of incorrect type: $handler" )
        unless ( blessed $handler && $handler->isa( 'perfSONAR_PS::RequestHandler' ) );

    eval {

        # ls stuff
        $self->configureConf( 'enable_registration', '0', $self->getConf( 'enable_registration' ) );

        # setup defaults etc
        $self->configureConf( 'service_name', $processName, $self->getConf( 'service_name' ) );
        $self->configureConf( 'service_type', 'MP', $self->getConf( 'service_type' ) );

        my $default_description = $processName . ' Service';
        if ( $self->getConf( "site_name" ) ) {
            $default_description .= " at " . $self->getConf( "site_name" );
        }
        if ( $self->getConf( "site_location" ) ) {
            $default_description .= " in " . $self->getConf( "site_location" );
        }
        $self->configureConf( 'service_description', $default_description, $self->getConf( 'service_description' ) );
        
        if ( $self->getConf( "enable_registration" ) and not ( $self->getConf( "service_node" ) or $self->getConf( "node_id" ) ) ) {
            # XXX: For now we make this a hard fail since the rest of the GENI infrastructure will depend on it.
            $logger->logdie( "This service requires the service_node or node_id to be set, exiting." );
        }
        
        $self->configureConf( 'service_node', $self->getConf( 'node_id' ), $self->getConf( 'service_node' ) );
        
        if ( $self->getConf( "enable_registration" ) and not idIsFQ( $self->getConf( 'service_node' ), "node" ) ) {
            $logger->logdie( "service_node (or node_id) is not a fully-qualified UNIS node id, exiting." );
        }
        
        $self->configureConf( 'default_scheme', "http", $self->getConf( 'default_scheme' ) );
        
        my $default_accesspoint;
        if ( $self->getConf( "external_address" ) ) {
            $default_accesspoint = $self->getConf( 'default_scheme' ) . '://' . $self->getConf( "external_address" ) . ':' . $self->{PORT} . $self->{ENDPOINT};
        }
    
        $self->configureConf( 'service_accesspoint', $default_accesspoint, $self->getConf( 'service_accesspoint' ) );
        if ( $self->getConf( "enable_registration" ) and not $self->getConf( "service_accesspoint" ) ) {
            $logger->logdie( "Must have either a service_accesspoint or an external address specified if you enable registration" );
        }
        $self->configureConf( 'ping_exec', '/bin/ping', $self->getConf( 'ping_exec' ) );

        $self->configureConf( 'db_host', undef, $self->getConf( 'db_host' ) );

        $self->configureConf( 'db_port', undef,              $self->getConf( 'db_port' ) );
        $self->configureConf( 'db_type', 'SQLite',           $self->getConf( 'db_type' ) );
        $self->configureConf( 'db_name', 'pingerMA.sqlite3', $self->getConf( 'db_name' ) );

        $self->configureConf( 'db_username', undef, $self->getConf( 'db_username' ) );
        $self->configureConf( 'db_password', undef, $self->getConf( 'db_password' ) );

        # die if we don't have the confi file
        $self->configureConf( 'configuration_file', undef, $self->getConf( 'configuration_file' ), 1 );
        $self->configureConf( 'root_hints_url', 'http://www.perfsonar.net/gls.root.hints', $self->getConf( 'root_hints_url' ) );

        # agent stuff
        $self->configureConf( 'service_timeout',      30, $self->getConf( 'service_timeout' )      || $self->{'CONF'}->{'service_timeout'} );
        $self->configureConf( 'max_worker_processes', 5,  $self->getConf( 'max_worker_processes' ) || $self->{'CONF'}->{'max_worker_processes'} );
    };
    if ( $EVAL_ERROR ) {
        $logger->logdie( "Configuration incorrect" );
        return -1;
    }

    # setup the config and schedule
    $logger->info( "Initialising PingER MP" );

    #$logger->debug(sub{Dumper($self->{CONF})});

    my $config = perfSONAR_PS::Services::MP::Config::PingER->new();
    $config->load( $self->getConf( 'configuration_file' ) );

    # set up the schedule with the list of tests
    $self->addTestSchedule( $config );

    # set max children for parent class
    $self->{MAXCHILDREN} = $self->getConf( 'max_worker_processes' );

    # do not add any handlers as we do not want to support on-demand
    # tests yet.
    #$handler->addMessageHandler("SetupDataRequest", "", $self);

    # start the daemon manager for measurements
    return $self->run( $processName );
}

=head2 database

accessor/mutator for database instance

=cut

sub database {
    my $self = shift;
    if ( @_ ) {
        $self->{DATABASE} = shift;
    }

    #$logger->debug( "database: ", sub{Dumper($self->{DATABASE})}) ;
    return $self->{DATABASE};
}

=head2 configureConf

setup defaults and or new values for the modules configuration variables

=cut

sub configureConf {
    my $self    = shift;
    my $key     = shift;
    my $default = shift;
    my $value   = shift;

    my $fatal = shift;    # if set, then if there is no value, will return -1

    if ( defined $value ) {
        if ( $value =~ /^ARRAY/ ) {
            my $index = scalar @$value - 1;

            #$logger->info( "VALUE: $value,  SIZE: $index");

            $value = $value->[$index];
            $logger->fatal( "Value for '$key' set to '$value'" );
        }
        $self->{CONF}->{$basename}->{$key} = $value;
    }
    else {
        if ( !$fatal ) {
            if ( defined $default ) {
                $self->{CONF}->{$basename}->{$key} = $default;
                $logger->warn( "Setting '$key' to '$default'" );
            }
            else {
                $self->{CONF}->{$basename}->{$key} = undef;
                $logger->warn( "Setting '$key' to null" );
            }
        }
        else {
            $logger->logdie( "Value for '$key' is not set" );
        }
    }

    return 0;
}

=head2 getConf

returns the defined key on from teh configuration

=cut

sub getConf {
    my $self = shift;
    my $key  = shift;
    if ( defined $self->{'CONF'}->{$basename}->{$key} ) {
        return $self->{'CONF'}->{$basename}->{$key};
    }
    else {
        return $self->{'CONF'}->{$key};
    }
}

=head2 ls

accessor/mutator for the lookup service

=cut

sub ls {
    my $self = shift;
    if ( @_ ) {
        $self->{'LS_CLIENT'} = shift;
    }
    return $self->{'LS_CLIENT'};
}

=head2 needLS

Do we want to register with the LS?

=cut

sub needLS($) {
    my $self = shift;
    return $self->getConf( "enable_registration" );
}

=head2 registerLS

Actually register with the LS information about the pinger mp service. 
in this case we only register the existance of the MP with teh LS.

=cut

sub registerLS($) {
    my $self = shift;

    $0 = $processName . ' LS Registration';

    $logger->info( "Registering PingER MP with LS" );
    my @ls_array = ();
    my @array = split( /\s+/, $self->getConf( 'ls_instance' ) );
    foreach my $l ( @array ) {
        $l =~ s/(\s|\n)*//g;
        push @ls_array, $l if $l;
    }
    my @hints_array = ();
    @array = split( /\s+/, $self->getConf( "root_hints_url" ) );
    foreach my $h ( @array ) {
        $h =~ s/(\s|\n)*//g;
        push @hints_array, $h if $h;
    }

    # create new client if required
    if ( !defined $self->ls() ) {
        my $ls_conf = {
            'SERVICE_NODE'        => $self->getConf( 'service_node' ),
            'SERVICE_TYPE'        => $self->getConf( 'service_type' ),
            'SERVICE_NAME'        => $self->getConf( 'service_name' ),
            'SERVICE_DESCRIPTION' => $self->getConf( 'service_description' ),
            'SERVICE_ACCESSPOINT' => $self->getConf( 'service_accesspoint' ),
        };
        my $ls = new perfSONAR_PS::Client::LS::Remote( \@ls_array, $ls_conf, \@hints_array );
        $self->ls( $ls );
    }

    # register nothing but the service instance with teh LS
    my @sendToLS = ();

    # add empty string to register MP
    push @sendToLS, '';

    # register with LS
    return $self->ls()->registerStatic( \@sendToLS );
}

=head2 parseMetadata()

Parses the configuration files to ready the schedule for tests

=cut

sub parseMetadata {
    my $self = shift;
    return $self->SUPER::parseMetadata( @_ );
}

=head2 prepareMetadata()

Prepares the schedule from the parsed metadata

=cut

sub prepareMetadata {
    my $self = shift;
    return $self->SUPER::prepareMetadata( @_ );
}

=head2 run

Starts the MP server to run forever the tests defined through init().

Iterating through the list of scheduled tests, it will create the relevant 
agents (which can be overridden with teh getAgent() method locally) to perform
the tests defined by their testid.

Each test will be forked off upto a maximum of $self->maxChildren() forks, and 
tests behind schedule will be delayed.

Once an $agent has completed its collectMeasurements() call, the forked process
will call $self->storeData() in order to store the output of the $agent into
a MA or similar.

=cut

sub run {
    my $self = shift;

    my $dbStatus = $self->setupDatabase();
    return $dbStatus
        if $dbStatus != 0;

    return $self->SUPER::run( @_ );
}

=head2 setupDatabase

TBD

=cut

sub setupDatabase {
    my $self = shift;

    my $err = 0;

    # setup database
    $logger->debug( "initializing database " . $self->getConf( "db_type" ) );

    if ( $self->getConf( "db_type" ) eq "SQLite" || $self->getConf( "db_type" ) eq "mysql" ) {

        # setup DB  object
        eval {
            my $dbo = perfSONAR_PS::DB::SQL::PingER->new(
                {

                    driver   => $self->getConf( "db_type" ),
                    database => $self->getConf( "db_name" ),
                    host     => $self->getConf( "db_host" ),
                    port     => $self->getConf( "db_port" ),
                    username => $self->getConf( "db_username" ),
                    password => $self->getConf( "db_password" ),
                }
            );

            my $status = $dbo->openDB();
            if ( $status == 0 ) {
                $self->database( $dbo );
            }
            else {
                $logger->logdie( " Failed to open DB" . $dbo->ERRORMSG );
                return -1;
            }
        };
        if ( $EVAL_ERROR ) {
            $logger->logdie( "Failed to connect to database '" . $self->getConf( 'db_type' ) . "' for '" . $self->getConf( 'db_name' ) . "' using '" . $self->getConf( 'db_username' ) . "'$EVAL_ERROR" );
        }

    }
    else {
        $logger->logdie( "Database type '" . $self->getConf( "db_type" ) . "' is not supported." );
        return -1;
    }
    return 0;
}

=head2 storeData( $agent, $testid )

Does the relevant storage of data collected from the $agent for the test id
$testid. For PingER, we only care for storge into the SQL backend provided
by the $agent itself.

Returns
   0 = everything okay
  -1 = somethign went wrong

=cut

sub storeData {
    my $self   = shift;
    my $agent  = shift;
    my $testid = shift;

    $logger->logdie( "Argument 'agent' is of wrong type" )
        unless blessed $agent && $agent->isa( 'perfSONAR_PS::Services::MP::Agent::Base' );
    unless ( $self && $self->database() ) {
        $logger->error( "!!! Database handler was lost, check database server" );
        return -1;
    }

    #  remap the rtts and seqs
    my $rtts;
    my $seqs;
    if ( $agent->results() ) {
        if ( $agent->results()->{'rtts'} && ref $agent->results()->{'rtts'} eq 'ARRAY' ) {
            $rtts = join ',', @{ $agent->results()->{'rtts'} };
            $logger->debug( "constructing array from rtts '$rtts'" );
        }
        if ( $agent->results()->{'seqs'} && ref $agent->results()->{'seqs'} eq 'ARRAY' ) {
            $seqs = join ',', @{ $agent->results()->{'seqs'} };
            $logger->debug( "constructing array from seqs '$seqs'" );
        }
    }

    # store results
    my ( $src, $dst, $md, $data );
    unless ( $agent->sourceIp() && $agent->destinationIp() ) {
        $logger->warn( " !!! Undefined source or destination IP ( unreachable host or parsing problem ?): ", sub { Dumper( $agent ) } );
        return -1;
    }
    my $ip_name = $agent->source() ? $agent->source() : $agent->sourceIp();

    eval { $src = $self->database()->soi_host( { ip_name => $ip_name, ip_number => $agent->sourceIp() } ); };
    if ( $EVAL_ERROR || !$src || $src !~ /^[\-\w\.]+$/ ) {
        $logger->error( "Failed: " . ( $EVAL_ERROR ? $EVAL_ERROR : '' ) . " - to find or insert soi_host:   $ip_name   " . $agent->sourceIp() . " Reason: " . $self->database()->ERRORMSG );
        return -1;
    }
    $ip_name = $agent->destination() ? $agent->destination() : $agent->destinationIp();
    eval { 
        $dst = $self->database()->soi_host( { ip_name => $ip_name, ip_number => $agent->destinationIp() } ); 
    };
    if ( $EVAL_ERROR || !$dst || $dst !~ /^[\-\w\.]+$/ ) {
        $logger->error(  "Failed: " . ($EVAL_ERROR?$EVAL_ERROR : '') . 
	                 "- to find or insert soi_host:  " . ($ip_name?"$ip_name " : ' no HOSTNAME ')  . 
			 ($agent->destinationIp()?$agent->destinationIp() : ' no destination IP ') .
			 " Reason: " .
			 ($self->database()->ERRORMSG?$self->database()->ERRORMSG : ' no error message available ')
		      );
        return -1;
    }
    eval {
        $md = $self->database()->soi_metadata(
            {
                ip_name_src      => $src,
                ip_name_dst      => $dst,
                'transport'      => 'ICMP',
                'packetSize'     => $agent->packetSize(),
                'count'          => $agent->count(),
                'packetInterval' => $agent->interval(),
                'ttl'            => $agent->ttl(),
            }
        );

    };
    if ( $EVAL_ERROR || !$md || $md < 0 ) {
        $logger->error( "Failed: " . ( $EVAL_ERROR ? $EVAL_ERROR : '' ) . "  -  to find or insert  soi_metadata: " . $agent->packetSize() . "  " . $agent->count() . "  " . $agent->interval() . "  " . $agent->ttl() . " Reason: " . $self->database()->ERRORMSG );
        return -1;
    }
    eval {
        $data = $self->database()->insertData(
            {
                metaID => $md,

                #time
                'timestamp' => $agent->results()->{'startTime'},

                # rtt
                'minRtt'  => $agent->results()->{'minRtt'},
                'maxRtt'  => $agent->results()->{'maxRtt'},
                'meanRtt' => $agent->results()->{'meanRtt'},

                # ipd
                'minIpd'  => $agent->results()->{'minIpd'},
                'meanIpd' => $agent->results()->{'meanIpd'},
                'maxIpd'  => $agent->results()->{'maxIpd'},

                # jitter
                'iqrIpd'    => $agent->results()->{'iqrIpd'},
                'medianRtt' => $agent->results()->{'medianRtt'},

                # other
                'duplicates' => $agent->results()->{'duplicates'},
                'outOfOrder' => $agent->results()->{'outOfOrder'},

                # loss
                'lossPercent' => $agent->results()->{'lossPercent'},
                'clp'         => $agent->results()->{'clp'},

                # raw
                'rtts'    => ( $rtts ? $rtts : '' ),
                'seqNums' => ( $seqs ? $seqs : '' ),

            }
        );
    };
    if ( $EVAL_ERROR || $data == -1 ) {
        $logger->error( "Failed:  " . ( $EVAL_ERROR ? $EVAL_ERROR : '' ) . " -   to find or insert  insertdata: " . $md . ", " . $agent->results()->{'startTime'} . ",  " . $agent->results()->{'meanRtt'} . " Reason: " . $self->database()->ERRORMSG );
        return -1;

    }
    return 0;
}

=head2 getAgent( $test )

Creates and returns a PingER Agent to run the given $test; must set the 
relevant data structures so that calling $agent->collectMeasurements() will
actually run the test provided.

$test is expected to be a hash of key/values for the ping test

=cut

sub getAgent {

    my $self = shift;
    my $test = shift;

    $logger->logdie( "Missing argument test hash" )
        unless defined $test;

    # get the appropiate agent and init it.
    my $command = '';
    if ( $self->getConf( 'ping_exec' ) && -e $self->getConf( 'ping_exec' ) ) {
        $command = $self->getConf( 'ping_exec' ) . $ping_parameters;
    }
    my $agent = perfSONAR_PS::Services::MP::Agent::PingER->new( $command );
    $agent->init();

    # determine if we want to use the destination IP or the DNS
    $agent->destination( $test->{destination} );
    $agent->destinationIp( $test->{destinationIp} );

    $agent->count( $test->{count} )           if $test->{count};
    $agent->packetSize( $test->{packetSize} ) if $test->{packetSize};
    $agent->ttl( $test->{ttl} )               if $test->{ttl};
    $agent->interval( $test->{interval} )     if $test->{interval};

    # timeouts
    $agent->timeout( $self->getConf( 'service_timeout' ) );

    return $agent;
}

=head2 handleMessageBegin

Do something with the message.

=cut

sub handleMessageBegin($$$$$$$$) {
    my ( $self, $ret_message, $messageId, $messageType, $msgParams, $request, $retMessageType, $retMessageNamespaces );
    return 0;
}

=head2 handleMessageEnd

Do something with the message.

=cut

sub handleMessageEnd($$$$$$$$) {
    my ( $self, $ret_message, $messageId );
    return 0;

}

=head2 handleEvent

deal with on-demand measurements through here

=cut

sub handleEvent($$$$$$$$$) {
    my ( $self, @args ) = @_;
    my $parameters = validate(
        @args,
        {
            output            => 1,
            messageId         => 1,
            messageType       => 1,
            messageParameters => 1,
            eventType         => 1,
            subject           => 1,
            filterChain       => 1,
            data              => 1,
            rawRequest        => 1,
            doOutputMetadata  => 1,
        }
    );

    # shoudl do some validation on the eventType
    ${ $parameters->{"doOutputMetadata"} } = 0;

    # shoudl do some validation on the eventType
    $logger->debug( "\n\n\nOUTPUT: " . $parameters->{"output"} . " / " . $parameters->{"rawRequest"} );
    if ( $parameters->{"messageType"} eq "MetadataKeyRequest" ) {

        #return $self->maMetadataKeyRequest($output, $md, $raw_request, $message_parameters);
    }
    else {

        #return $self->maSetupDataRequest($output, $md, $raw_request, $message_parameters);
    }

    $logger->debug( 'handle event ' . $parameters->{"rawRequest"} );
    my $response = $self->handleRequest( $parameters->{"rawRequest"} );
    $parameters->{"output"}->addExistingXMLElement( $response->getDOM() );

    return 0;
}

1;

__END__

=head1 SYNOPSIS

    use perfSONAR_PS::Services::MP::PingER;

    my %conf = ();
    
    # definition of where the list of hosts and parameters to ping are located
    $conf{"METADATA_DB_TYPE"} = "file";
    $conf{"METADATA_DB_NAME"} = "";
    $conf{"METADATA_DB_FILE"} = "pinger-configuraiton.xml";

    # create a new instance of the MP
    my $mp = new perfSONAR_PS::MP::PingER( \%conf );
    
    # or:
    #
    # $mp = new perfSONAR_PS::MP::PingER;
    # $mp->setConf(\%conf);

	# initiate the mp
    $mp->init();
    
=head1 SEE ALSO

L<perfSONAR_PS::Services::MP::Base>, 
L<perfSONAR_PS::Services::MP::Scheduler>, 
L<perfSONAR_PS::Services::Common>, 
L<perfSONAR_PS::Services::MP::Agent::PingER>, 
L<perfSONAR_PS::DB::PingER>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: PingER.pm 2777 2009-04-20 17:36:00Z maxim $

=head1 AUTHOR

Yee-Ting Li, ytl@slac.stanford.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut
