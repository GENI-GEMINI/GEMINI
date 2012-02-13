package perfSONAR_PS::NPToolkit::Config::RegisteredServices;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::RegisteredServices

=head1 DESCRIPTION

Module for configuring the set of services for the toolkit. Currently, this is
only used to enable/disable services. Longer term, it'd be good to think about
how the enable/disable configuration integrates with the configuration for each
service.

=cut

use Data::Dumper;

use base 'perfSONAR_PS::NPToolkit::Config::Base';

use fields 'UNIS_INSTANCE', 'NODES', 'ANCHORS', 'DAEMONS', 'SERVICES', 'CACHE_DIRECTORY', 'XQUERY';

use Params::Validate qw(:all);
use Log::Log4perl qw(get_logger :nowarn);
use Storable qw(store retrieve freeze thaw dclone);
use POSIX;

use perfSONAR_PS::Common qw(extract find unescapeString escapeString parseToDOM);
use perfSONAR_PS::Client::Parallel::LS;
use perfSONAR_PS::Topology::ID qw(idBaseLevel);
  
use constant LS_DISCOVERY_ET => 'http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/xquery/2.0';

use constant SERVICES_XQUERY => "
declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";
declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";
for \$store in /nmwg:store[\@type='LSStore'] return
    if (exists(\$store/nmwg:metadata)) then
        let \$metadata := \$store/nmwg:metadata
        let \$node_id := \$metadata/perfsonar:subject/*[local-name()='service']/*[local-name()='serviceNode' or local-name()='node']
        where contains(\$node_id, '__DOMAIN__:node=')
        return \$store
    else if (exists(\$store/nmwg:data)) then
        let \$data := \$store/nmwg:data
        let \$metadata_id := \$data/\@metadataIdRef
        where exists( /nmwg:store[\@type='LSStore']/nmwg:metadata[\@id=\$metadata_id
                      ]/perfsonar:subject/*[local-name()='service']/*[(local-name()='serviceNode' or local-name()='node') 
                                                             and contains(., '__DOMAIN__:node=')])
        return \$store
    else ()
";

my %defaults = ( cache_directory => "/var/lib/perfsonar/ls_cache", );


# This is a sort of reverse mapping of %serviceMap.
# GFR: I have to disagree with this mapping though. The characteristics namespace
#   shouldn't be tied to a specific service, especially in a non-pSPS specific
#   environment like GENI.
my %eT_file_map = (
    # SNMP MA eTs. 
    "http://ggf.org/ns/nmwg/characteristic/utilization/2.0" => "list.snmpma",
    "http://ggf.org/ns/nmwg/tools/snmp/2.0"                 => "list.snmpma",
    
    # PingER eTs. 
    "http://ggf.org/ns/nmwg/tools/pinger/2.0/"              => "list.pinger",
    "http://ggf.org/ns/nmwg/tools/pinger/2.0"               => "list.pinger",
    
    # PSB eTs. (GFR: Do we really have to handle typos on eTs?)
    "http://ggf.org/ns/nmwg/characteristics/bandwidth/acheiveable/2.0" => "list.psb.bwctl",
    "http://ggf.org/ns/nmwg/characteristics/bandwidth/achieveable/2.0" => "list.psb.bwctl",
    "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0"  => "list.psb.bwctl",
    "http://ggf.org/ns/nmwg/tools/iperf/2.0"                           => "list.psb.bwctl",
    
    "http://ggf.org/ns/nmwg/tools/owamp/2.0"                           => "list.psb.owamp",
    "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921"     => "list.psb.owamp",
    
    # Daemon eTs.
    "http://ggf.org/ns/nmwg/tools/bwctl/1.0"        => "list.bwctl",
    "http://ggf.org/ns/nmwg/tools/traceroute/1.0"   => "list.traceroute",
    "http://ggf.org/ns/nmwg/tools/npad/1.0"         => "list.npad",
    "http://ggf.org/ns/nmwg/tools/ndt/1.0"          => "list.ndt",
    "http://ggf.org/ns/nmwg/tools/owamp/1.0"        => "list.owamp",
    "http://ggf.org/ns/nmwg/tools/ping/1.0"         => "list.ping",
    "http://ggf.org/ns/nmwg/tools/phoebus/1.0"      => "list.phoebus",
    "http://ggf.org/ns/nmwg/tools/psed/2.0"         => "list.psed",
);

my %serviceMap = (
    "list.snmpma" => {
        "EVENTTYPE" => [
            "http://ggf.org/ns/nmwg/tools/ganglia/2.0",
            "http://ggf.org/ns/nmwg/characteristic/utilization/2.0",
            "http://ggf.org/ns/nmwg/tools/snmp/2.0"
        ],
        "TYPE" => "SNMP"
    },
    "list.psb.bwctl" => {
        "EVENTTYPE" => [
            "http://ggf.org/ns/nmwg/tools/iperf/2.0",
            "http://ggf.org/ns/nmwg/characteristics/bandwidth/acheiveable/2.0",
            "http://ggf.org/ns/nmwg/characteristics/bandwidth/achieveable/2.0",
            "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0"
        ],
        "TYPE" => "PSB_BWCTL"
    },
    "list.psb.owamp" => {
        "EVENTTYPE" => [
            "http://ggf.org/ns/nmwg/tools/owamp/2.0",
            "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921"
        ],
        "TYPE" => "PSB_OWAMP"
    },
    "list.pinger" => {
        "EVENTTYPE" => [
            "http://ggf.org/ns/nmwg/tools/pinger/2.0/",
            "http://ggf.org/ns/nmwg/tools/pinger/2.0"
        ],
        "TYPE" => "PINGER"
    }
);

my %daemonMap = (
    "list.owamp" => {
        "EVENTTYPE" => ["http://ggf.org/ns/nmwg/tools/owamp/1.0"],
        "TYPE"      => "OWAMP"
    },
    "list.traceroute" => {
        "EVENTTYPE" => ["http://ggf.org/ns/nmwg/tools/traceroute/1.0"],
        "TYPE"      => "TRACEROUTE"
    },
    "list.ping" => {
        "EVENTTYPE" => ["http://ggf.org/ns/nmwg/tools/ping/1.0"],
        "TYPE"      => "PING"
    },
    "list.npad" => {
        "EVENTTYPE" => ["http://ggf.org/ns/nmwg/tools/npad/1.0"],
        "TYPE"      => "NPAD"
    },
    "list.ndt" => {
        "EVENTTYPE" => ["http://ggf.org/ns/nmwg/tools/ndt/1.0"],
        "TYPE"      => "NDT"
    },
    "list.bwctl" => {
        "EVENTTYPE" => ["http://ggf.org/ns/nmwg/tools/bwctl/1.0"],
        "TYPE"      => "BWCTL"
    },
    "list.phoebus" => {
        "EVENTTYPE" => ["http://ggf.org/ns/nmwg/tools/phoebus/1.0"],
        "TYPE"      => "PHOEBUS"
    }
);

=head2 init({ unis_instance => 1, domain_id => 1, cache_directory => 0 })

Initializes the client. Returns 0 on success and -1 on failure. The
enabled_services_file parameter can be specified to set which file the module
should use for reading/writing the configuration.

=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { unis_instance => 1, domain_id => 1, cache_directory => 0 } );

    # Initialize the defaults
    $self->{CACHE_DIRECTORY} = $defaults{cache_directory};

    # Override any
    $self->{CACHE_DIRECTORY} = $parameters->{cache_directory}
      if ( $parameters->{cache_directory} );

    # XXX: This could be determined through the hints file, especially
    #   as there might be the need for querying multiple UNIS instances
    $self->{UNIS_INSTANCE} = $parameters->{unis_instance};
    
    $self->{XQUERY} = SERVICES_XQUERY;
    $self->{XQUERY} =~ s/__DOMAIN__/$parameters->{domain_id}/g;
    
    my $res = $self->reset_state();
    if ( $res != 0 ) {
        return $res;
    }

    return 0;
}

=head2 reset_state()
    Resets the state of the module to the state immediately after having run "init()".
    Pulls the current configuration from UNIS if there's no local copy.
=cut

sub reset_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    my $counter = $self->parse_cache_directory();
    
    return $self->pull_registered() if $counter < 1;
    
    return 0;
}    

=head2 parse_cache_directory ({ })
    TODO:
=cut

sub parse_cache_directory() {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    my @daemonList  = ();
    my @serviceList = ();
    my @anchors     = ();
    
    my $total_counter = 0;
    if ( -d $self->{CACHE_DIRECTORY} ) {
        my @daemon_anch = ();
        my $counter1    = 0;
        foreach my $file ( keys %daemonMap ) {
            if ( -f $self->{CACHE_DIRECTORY} . "/" . $file ) {
                open( READ, "<" . $self->{CACHE_DIRECTORY} . "/" . $file )
                  or next;
                my @content = <READ>;
                close(READ);

                my @temp     = ();
                my $counter2 = 0;
                my $viewFlag = 0;
                foreach my $c (@content) {
                    my @daemon = split( /\|/, $c );
                    my $node_name = "";
                    $node_name = idBaseLevel( $daemon[4] ) if $daemon[4];
                    if ( $daemon[0] =~ m/^https?:\/\// ) {
                        push @temp,
                          {
                            daemon => $daemon[0],
                            name   => $daemon[1],
                            type   => $daemon[2],
                            desc   => $daemon[3],
                            node   => $node_name,
                            count1 => $counter1,
                            count2 => $counter2,
                            view   => 1
                          };
                        $viewFlag++;
                    }
                    else {
                        push @temp,
                          {
                            daemon => $daemon[0],
                            name   => $daemon[1],
                            type   => $daemon[2],
                            desc   => $daemon[3],
                            node   => $node_name,
                            count1 => $counter1,
                            count2 => $counter2,
                            view   => 0
                          };
                    }
                    $counter2++;
                }
                push @daemonList,
                  {
                    type     => $daemonMap{$file}{"TYPE"},
                    contents => \@temp,
                    view     => $viewFlag
                  };
                  
                $total_counter += $counter2;
            }
            push @daemon_anch,
              {
                anchor => $daemonMap{$file}{"TYPE"},
                name   => $daemonMap{$file}{"TYPE"} . " Daemons"
              };
            $counter1++;
        }
        push @anchors,
          {
            anchor      => "daemons",
            type        => "Measurement Tools",
            anchoritems => \@daemon_anch
          };

        my @service_anch  = ();
        $counter1      = 0;
        foreach my $file ( keys %serviceMap ) {
            if ( -f $self->{CACHE_DIRECTORY} . "/" . $file ) {
                open( READ, "<" . $self->{CACHE_DIRECTORY} . "/" . $file )
                  or next;
                my @content = <READ>;
                close(READ);

                my @temp     = ();
                my $counter2 = 0;
                foreach my $c (@content) {
                    my @service = split( /\|/, $c );
                    my $node_name = "";
                    $node_name = idBaseLevel( $service[4] ) if $service[4];
                    push @temp,
                      {
                        service   => $service[0],
                        name      => $service[1],
                        type      => $service[2],
                        desc      => $service[3],
                        node      => $node_name,
                        count1    => $counter1,
                        count2    => $counter2,
                        eventtype => $serviceMap{$file}{"EVENTTYPE"}[0]
                      };
                    $counter2++;
                }
                push @serviceList,
                  { type => $serviceMap{$file}{"TYPE"}, contents => \@temp };
                $total_counter += $counter2;
            }
            push @service_anch,
              {
                anchor => $serviceMap{$file}{"TYPE"},
                name   => $serviceMap{$file}{"TYPE"} . " Services"
              };
            $counter1++;
        }
        push @anchors,
          {
            anchor      => "services",
            type        => "perfSONAR Services",
            anchoritems => \@service_anch
          };
    }
    
    $self->{ANCHORS}  = \@anchors;
    $self->{SERVICES} = \@serviceList;
    $self->{DAEMONS}  = \@daemonList;
    
    return $total_counter;
}

=head2 pull_registered ({ })
    TODO:
=cut

sub pull_registered {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my $ls = perfSONAR_PS::Client::Parallel::LS->new();
    $ls->init();
    
    my %hls_results = ();
    # TODO: For now we only use the single UNIS instance, 
    # but should use the gLS to get all UNIS services available
    my @hlses       = ( $self->{UNIS_INSTANCE}, );
    
    my $results = $self->query_hlses( { ls_client => $ls, hlses => \@hlses, event_type => LS_DISCOVERY_ET, format => 1 } );
    
    my @java_hlses = ();
    
    foreach my $h ( keys %{$results} ) {
        $self->{LOGGER}->debug( "Trying '" . $h . "'\n" );
        my $result_info = $results->{$h};
        if ( exists $result_info->{event_type} and $result_info->{event_type} eq "error.ls.query.ls_output_not_accepted" ) {
            $self->{LOGGER}->debug( "\t\tskipping...\n" );
            push @java_hlses, $h;
            next;
        }
        $hls_results{$h} = $results->{$h};
    }
    
    ## The Java hLS doesn't like the format parameter, treat it 'special'
    if ( scalar( @java_hlses ) > 0 ) {
        $results = $self->query_hlses( { ls_client => $ls, hlses => \@java_hlses, event_type => LS_DISCOVERY_ET, format => 0 } );
        foreach my $h ( keys %{$results} ) {
             $self->{LOGGER}->debug( "Trying '" . $h . "'\n" );
            my $result_info = $results->{$h};
            if ( exists $result_info->{event_type} and $result_info->{event_type} =~ m/^error/ ) {
                 $self->{LOGGER}->debug( "\t\tskipping...\n" );
                next;
            }
            else {
                $results->{$h}->{content} = unescapeString( $results->{$h}->{content}->toString );
                $hls_results{$h} = $results->{$h};
            }
        }
    }
    
    my %list = ();
    my %dups = ();
    
    foreach my $h ( keys %hls_results ) {
    
        $self->{LOGGER}->debug( "decoding: '" . $h . "'\n" );
    
        my $response_info = $hls_results{$h};
    
        # Skip any errors
        unless ( $response_info->{event_type} and $response_info->{event_type} !~ m/^error/ ) {
            if ( $response_info->{event_type} ) {
                 $self->{LOGGER}->debug( "Response info error: $h: " . $response_info->{event_type} . "\n" );
            }
            elsif ( $response_info->{error_msg} ) {
                 $self->{LOGGER}->debug( "Response info error: $h: " . $response_info->{error_msg} . "\n" );
            }
            else {
                 $self->{LOGGER}->debug( "Response info error: $h" );
            }
            $self->{LOGGER}->debug( "\tSkipping\n" );
            next;
        }
    
        $self->{LOGGER}->debug( "Handling $h" );
    
        my $response_message = $response_info->{content};
    
        unless ( UNIVERSAL::isa( $response_message, "SCALAR" ) ) {
            $self->{LOGGER}->debug( "\tConvert to LibXML object\n" );
            my $doc;
            eval { $doc = parseToDOM( $response_message ); } or do {
                $self->{LOGGER}->debug( "Failed to parse " . $h . ": " . $@ );
                next;
            };
            $response_message = $doc->getDocumentElement;
        }
    
        my $md = find( $response_message, "./nmwg:store/nmwg:metadata", 0 );
        my $d  = find( $response_message, "./nmwg:store/nmwg:data",     0 );
        my %keywords = ();
        foreach my $m1 ( $md->get_nodelist ) {
            my $id = $m1->getAttribute( "id" );
    
            my $contactPoint = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='accessPoint']", 1 ), 0 );
            unless ( $contactPoint ) {
                $contactPoint = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='address']", 1 ), 0 );
                next unless $contactPoint;
            }
            my $serviceName = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='serviceName']", 1 ), 0 );
            unless ( $serviceName ) {
                $serviceName = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='name']", 1 ), 0 );
            }
            my $serviceType = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='serviceType']", 1 ), 0 );
            unless ( $serviceType ) {
                $serviceType = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='type']", 1 ), 0 );
            }
            my $serviceDescription = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='serviceDescription']", 1 ), 0 );
            unless ( $serviceDescription ) {
                $serviceDescription = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='description']", 1 ), 0 );
            }
            my $serviceNode = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='serviceNode']", 1 ), 0 );
            unless ( $serviceNode ) {
                $serviceNode = extract( find( $m1, "./*[local-name()='subject']//*[local-name()='node']", 1 ), 0 );
            }
    
            foreach my $d1 ( $d->get_nodelist ) {
                my $metadataIdRef = $d1->getAttribute( "metadataIdRef" );
                next unless $id eq $metadataIdRef;
    
                $self->{LOGGER}->debug( "Found matching data\n" );
    
                $self->{LOGGER}->debug( "Querying for keywords in :" . $d1->toString . "\n" );
    
                # get the keywords
                my $keywords = find( $d1, "./nmwg:metadata/summary:parameters/nmwg:parameter", 0 );
                foreach my $k ( $keywords->get_nodelist ) {
                    $self->{LOGGER}->debug( "Found attribute: " . $k->getAttribute( "name" ) );
                    my $name = $k->getAttribute( "name" );
                    next unless $name eq "keyword";
                    my $value = extract( $k, 0 );
                    if ( $value ) {
                        $keywords{$value} = 1;
                    }
                    $self->{LOGGER}->debug( "Found keyword: " . $value );
                }
                $self->{LOGGER}->debug( "Done querying for keywords\n" );
    
                # get the eventTypes
                my $eventTypes = find( $d1, "./nmwg:metadata/nmwg:eventType", 0 );
                foreach my $e ( $eventTypes->get_nodelist ) {
                    my $value = extract( $e, 0 );
                    if ( $value ) {
    
                        if ( $value eq "http://ggf.org/ns/nmwg/tools/snmp/2.0" ) {
                            $value = "http://ggf.org/ns/nmwg/characteristic/utilization/2.0";
                        }
                        elsif ( $value eq "http://ggf.org/ns/nmwg/tools/pinger/2.0/" ) {
                            $value = "http://ggf.org/ns/nmwg/tools/pinger/2.0";
                        }
                        elsif ( $value eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/acheiveable/2.0" or $value eq "http://ggf.org/ns/nmwg/characteristics/bandwidth/achieveable/2.0" ) {
                            $value = "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0";
                        }
                        elsif ( $value eq "http://ggf.org/ns/nmwg/tools/iperf/2.0" ) {
                            $value = "http://ggf.org/ns/nmwg/characteristics/bandwidth/achievable/2.0";
                        }
                        elsif ( $value eq "http://ggf.org/ns/nmwg/characteristic/delay/summary/20070921" ) {
                            $value = "http://ggf.org/ns/nmwg/tools/owamp/2.0";
                        }
                        # more eventTypes as needed...
    
                        # we should be tracking things here, eliminate duplicates
                        unless ( exists $dups{$value}{$contactPoint} and $dups{$value}{$contactPoint} ) {
                            $dups{$value}{$contactPoint} = 1;
    
                            if ( exists $list{$value} ) {
                                push @{ $list{$value} }, { CONTACT => $contactPoint, NAME => $serviceName, TYPE => $serviceType, DESC => $serviceDescription, NODE => $serviceNode };
                            }
                            else {
                                my @temp = ( { CONTACT => $contactPoint, NAME => $serviceName, TYPE => $serviceType, DESC => $serviceDescription, NODE => $serviceNode } );
                                $list{$value} = \@temp;
                            }
                        }
                    }
                }
                last;
            }
        }
        
        # Clean cache directory first
        foreach my $file ( keys %daemonMap ) {
            unlink ( $self->{CACHE_DIRECTORY} . "/" . $file ) if ( -f $self->{CACHE_DIRECTORY} . "/" . $file );
        }
        foreach my $file ( keys %serviceMap ) {
            unlink ( $self->{CACHE_DIRECTORY} . "/" . $file ) if ( -f $self->{CACHE_DIRECTORY} . "/" . $file );
        }
        
        my %counter = ();
        foreach my $et ( keys %list ) {
            my $file = q{};
            $file = $eT_file_map{ $et } if exists $eT_file_map{ $et };
            next unless $file;
        
            my $writetype = ">";
            $writetype = ">>" if exists $counter{$file};
            $counter{$file} = 1;
        
            open( OUT, $writetype . $self->{CACHE_DIRECTORY} . "/" . $file )  or croak ( "can't open " . $self->{CACHE_DIRECTORY} . "/$file." );
            foreach my $host ( @{ $list{$et} } ) {
                print OUT $host->{"CONTACT"}, "|";
                print OUT $host->{"NAME"} if $host->{"NAME"};
                print OUT "|";
                print OUT $host->{"TYPE"} if $host->{"TYPE"};
                print OUT "|";
                print OUT $host->{"DESC"} if $host->{"DESC"};
                print OUT "|";
                print OUT $host->{"NODE"} if $host->{"NODE"};
                print OUT "\n";
            }
            close( OUT );
        }
    }
    
    return 0;
}

sub query_hlses {
    my ( $self, @params ) = @_;
    my $args = validate(
        @params,
        {
            ls_client  => 1,
            hlses      => 1,
            event_type => 1,
            format     => 1,
        }
    );

    my %mappings = ();

    foreach my $h ( @{ $args->{hlses} } ) {
        my $cookie = $args->{ls_client}->add_query(
            {
                url    => $h,
                xquery => $self->{XQUERY},
                event_type => $args->{event_type},
                format     => $args->{format},
                timeout    => 15,
            }
        );

        $mappings{$cookie} = $h;
    }

    my $results = $args->{ls_client}->wait_all( { timeout => 60, parallelism => 8 } );

    my %ret_results = ();
    foreach my $key ( keys %{$results} ) {
        my $response_info = $results->{$key};

        # Skip any bad responses
        next unless ( $response_info->{cookie} and $mappings{ $response_info->{cookie} } );

        my $h = $mappings{ $response_info->{cookie} };

        $ret_results{$h} = $response_info;
    }

    return \%ret_results;
}

=head2 parse_configuration ({ node_list => 1 })
    TODO:
=cut

sub parse_configuration {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { node_list => 1 } );

    return 0;
}

=head2 get_nodes ({})
    Returns the list of nodes as a hash indexed by UNIS id. The hash values are
    hashes containing the node's properties (including a services hash).
=cut

sub get_nodes {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{NODES};
}

=head2 get_services ({ })
    Returns the list of services as an array ref.
=cut

sub get_services {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{SERVICES};
}

=head2 get_anchors ({ })
    Returns the list of anchors as an array ref.
=cut

sub get_anchors {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{ANCHORS};
}

=head2 get_daemons ({ })
    Returns the list of daemons as an array ref.
=cut

sub get_daemons {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{DAEMONS};
}

=head2 last_modified()
    Returns when the site information was last saved.
=cut

sub last_modified {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );
    
    # Check each file that we care about and see which one has the
    # latest modified time. We use this as our last modified date.
    my $max_mtime = 0;
    
    if ( -d $self->{CACHE_DIRECTORY} ) {
        foreach my $file ( keys %daemonMap ) {
            if ( -f $self->{CACHE_DIRECTORY} . "/" . $file ) {
                my ($mtime) = ( stat( $self->{CACHE_DIRECTORY} . "/" . $file ) )[9];
                $max_mtime = $mtime if $mtime > $max_mtime;
            }
        }
        foreach my $file ( keys %serviceMap ) {
            if ( -f $self->{CACHE_DIRECTORY} . "/" . $file ) {
                my ($mtime) = ( stat( $self->{CACHE_DIRECTORY} . "/" . $file ) )[9];
                $max_mtime = $mtime if $mtime > $max_mtime;
            }
        }
    }
    
    unless ( $max_mtime == 0 ) {
        $max_mtime = POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime( $max_mtime) );
    }
    else {
        $max_mtime = "unknown";
    }
    
    return $max_mtime;
}

=head2 save_state()
    Saves the current state of the module as a string. This state allows the
    module to be recreated later.
=cut

sub save_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    my %state = (
        services              => $self->{SERVICES},
        enabled_services_file => $self->{ENABLED_SERVICES_FILE},
    );

    my $str = freeze( \%state );

    return $str;
}

=head2 restore_state({ state => \$state })
    Restores the modules state based on a string provided by the "save_state"
    function above.
=cut

sub restore_state {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { state => 1, } );

    my $state = thaw( $parameters->{state} );

    $self->{SERVICES}              = $state->{services};
    $self->{ENABLED_SERVICES_FILE} = $state->{enabled_services_file};

    return;
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

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
