package perfSONAR_PS::DB::Ganglia;

use strict;
use warnings;

our $VERSION = 3.2;

use fields 'LOGGER', 'CONF', 'FILE', 'STORE', 'RRDTOOL', 'TELNET', 'MAP', 'TEMPLATES';

=head1 NAME

perfSONAR_PS::DB::Ganglia

=head1 DESCRIPTION

Module used to interact with the Ganglia cluster monitoring system.

=cut

use Expect;
use Log::Log4perl qw(get_logger);
use Params::Validate qw(:all);
use English qw( -no_match_vars );
use Config::General qw(ParseConfig);
use perfSONAR_PS::Utils::ParameterValidation;
use Storable qw( dclone );

=head2 new($package, { file })

Create a new object.  

=cut

use constant METRICS => {
    "http://ggf.org/ns/nmwg/characteristic/system/time/boot/2.0" => {
            name => "boottime",
            description => "Last Boot Time",
            type        => "time",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/disk/free/2.0" => {
            name        => "disk_free",
            description => "Total free disk space",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/disk/total/2.0" => {
            name => "disk_total",
            description => "Total available disk space",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/disk/partitions/used/2.0" => {
            name => "part_max_used",
            description => "Maximum percent used for all partitions",
            type        => "percentage",
    },
    "http://ggf.org/ns/nmwg/characteristic/network/utilization/bytes/2.0" => {
            name => "bytes_per_sec",
            description => "Number of bytes per second",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/network/utilization/bytes/received/2.0" => {
            name => "bytes_in",
            description => "Number of bytes in per second",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/network/utilization/bytes/sent/2.0" => {
            name => "bytes_out",
            description => "Number of bytes out per second",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/network/utilization/packets/2.0" => {
            name => "pkts_per_sec",
            description => "Packets per second",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/network/utilization/packets/received/2.0" => {
            name => "pkts_in",
            description => "Packets in per second",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/network/utilization/packets/sent/2.0" => {
            name => "pkts_out",
            description => "Packets out per second",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/process/total/2.0" => {
            name => "proc_total",
            description => "Total number of processes",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/process/running/2.0" => {
            name => "proc_run",
            description => "Total number of running processes",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/utilization/nice/2.0" => {
            name => "cpu_nice",
            description => "Percentage of CPU utilization at user level with nice priority",
            type        => "percentage",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/speed/2.0" => {
            name => "cpu_speed",
            description => "CPU Speed in terms of MHz",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/time/iowait/2.0" => {
            name => "cpu_wio",
            description => "Percentage of CPU idle time with outstanding disk I/O requests",
            type        => "percentage",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/utilization/user/2.0" => {
            name => "cpu_user",
            description => "Percentage of CPU utilization at user level",
            type        => "percentage",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/time/idle/2.0" => {
            name => "cpu_idle",
            description => "Percentage of CPU idle time without outstanding disk I/O requests",
            type        => "percentage",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/count/2.0" => {
            name => "cpu_num",
            description => "Total number of CPUs",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/utilization/system/2.0" => {
            name => "cpu_system",
            description => "Percentage of CPU utilization at system level",
            type        => "percentage",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/time/aidle/2.0" => {
            name => "cpu_aidle",
            description =>"Percent of time since boot idle CPU",
            type        => "percentage",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/load/oneminute/2.0" => {
            name => "load_one",
            description => "CPU one minute load average",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/load/fiveminute/2.0" => {
            name => "load_five",
            description => "CPU five minute load average",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/cpu/load/fifteenminute/2.0" => {
            name => "load_fifteen",
            description => "CPU fifteen minute load average",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/cached/total/2.0" => {
            name => "mem_cached",
            description => "Amount of cached memory in KBs",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/main/free/2.0" => {
            name => "mem_free",
            description => "Amount of available memory in KBs",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/main/total/2.0" => {
            name => "mem_total",
            description => "Total amount of memory displayed in KBs",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/buffers/total/2.0" => {
            name => "mem_buffers",
            description => "Amount of buffered memory in KBs",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/shared/total/2.0" => {
            name => "mem_shared",
            description => "Amount of shared memory in KBs",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/swap/free/2.0" => {
            name => "swap_free",
            description => "Amount of available swap memory in KBs",
            type        => "numeric",
    },
    "http://ggf.org/ns/nmwg/characteristic/memory/swap/total/2.0" => {
            name => "swap_total",
            description => "Total amount of swap space displayed in KBs",
            type        => "numeric",
    },
};

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams( @args, { conf => 0, file => 0, rrd => 0, telnet => 0 } );

    my $self = fields::new( $package );
    $self->{STORE}  = q{};
    $self->{LOGGER} = get_logger( "perfSONAR_PS::DB::Ganglia" );
    $self->{MAP}    = ();

    $self->{MAP}{"boottime"}{"eventTypes"}      = [ "http://ggf.org/ns/nmwg/tools/ganglia/system/time/boot/2.0", "http://ggf.org/ns/nmwg/characteristic/system/time/boot/2.0" ];
    $self->{MAP}{"boottime"}{"type"}            = "node";
    $self->{MAP}{"boottime"}{"ds"}              = "sum";
    $self->{MAP}{"disk_free"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/disk/free/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/disk/free/2.0" ];
    $self->{MAP}{"disk_free"}{"type"}           = "node";
    $self->{MAP}{"disk_free"}{"ds"}             = "sum";
    $self->{MAP}{"disk_total"}{"eventTypes"}    = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/disk/total/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/disk/total/2.0" ];
    $self->{MAP}{"disk_total"}{"type"}          = "node";
    $self->{MAP}{"disk_total"}{"ds"}            = "sum";
    $self->{MAP}{"part_max_used"}{"eventTypes"} = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/disk/partitions/used/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/disk/partitions/used/2.0" ];
    $self->{MAP}{"part_max_used"}{"type"}       = "node";
    $self->{MAP}{"part_max_used"}{"ds"}         = "sum";
    $self->{MAP}{"bytes_in"}{"eventTypes"}      = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/bytes/received/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/bytes/received/2.0", "http://ggf.org/ns/nmwg/characteristic/utilization/2.0" ];
    $self->{MAP}{"bytes_in"}{"type"}            = "node";
    $self->{MAP}{"bytes_in"}{"ds"}              = "sum";
    $self->{MAP}{"bytes_out"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/bytes/sent/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/bytes/sent/2.0", "http://ggf.org/ns/nmwg/characteristic/utilization/2.0" ];
    $self->{MAP}{"bytes_out"}{"type"}           = "node";
    $self->{MAP}{"bytes_out"}{"ds"}             = "sum";
    $self->{MAP}{"pkts_in"}{"eventTypes"}       = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/packets/received/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/packets/received/2.0" ];
    $self->{MAP}{"pkts_in"}{"type"}             = "node";
    $self->{MAP}{"pkts_in"}{"ds"}               = "sum";
    $self->{MAP}{"pkts_out"}{"eventTypes"}      = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/packets/sent/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/packets/sent/2.0" ];
    $self->{MAP}{"pkts_out"}{"type"}            = "node";
    $self->{MAP}{"pkts_out"}{"ds"}              = "sum";
    $self->{MAP}{"proc_total"}{"eventTypes"}   = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/process/total/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/process/total/2.0" ];
    $self->{MAP}{"proc_total"}{"type"}         = "node";
    $self->{MAP}{"proc_total"}{"ds"}           = "sum";
    $self->{MAP}{"proc_run"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/process/running/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/process/running/2.0" ];
    $self->{MAP}{"proc_run"}{"type"}           = "node";
    $self->{MAP}{"proc_run"}{"ds"}             = "sum";
    $self->{MAP}{"cpu_nice"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/utilization/nice/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/utilization/nice/2.0" ];
    $self->{MAP}{"cpu_nice"}{"type"}           = "node";
    $self->{MAP}{"cpu_nice"}{"ds"}             = "sum";
    $self->{MAP}{"cpu_speed"}{"eventTypes"}    = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/speed/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/speed/2.0" ];
    $self->{MAP}{"cpu_speed"}{"type"}          = "node";
    $self->{MAP}{"cpu_speed"}{"ds"}            = "sum";
    $self->{MAP}{"cpu_wio"}{"eventTypes"}      = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/time/iowait/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/time/iowait/2.0" ];
    $self->{MAP}{"cpu_wio"}{"type"}            = "node";
    $self->{MAP}{"cpu_wio"}{"ds"}              = "sum";
    $self->{MAP}{"cpu_user"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/utilization/user/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/utilization/user/2.0" ];
    $self->{MAP}{"cpu_user"}{"type"}           = "node";
    $self->{MAP}{"cpu_user"}{"ds"}             = "sum";
    $self->{MAP}{"cpu_idle"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/time/idle/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/time/idle/2.0" ];
    $self->{MAP}{"cpu_idle"}{"type"}           = "node";
    $self->{MAP}{"cpu_idle"}{"ds"}             = "sum";
    $self->{MAP}{"cpu_num"}{"eventTypes"}      = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/count/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/count/2.0" ];
    $self->{MAP}{"cpu_num"}{"type"}            = "node";
    $self->{MAP}{"cpu_num"}{"ds"}              = "sum";
    $self->{MAP}{"cpu_system"}{"eventTypes"}   = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/utilization/system/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/utilization/system/2.0" ];
    $self->{MAP}{"cpu_system"}{"type"}         = "node";
    $self->{MAP}{"cpu_system"}{"ds"}           = "sum";
    $self->{MAP}{"cpu_aidle"}{"eventTypes"}    = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/time/aidle/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/time/aidle/2.0" ];
    $self->{MAP}{"cpu_aidle"}{"type"}          = "node";
    $self->{MAP}{"cpu_aidle"}{"ds"}            = "sum";
    $self->{MAP}{"load_one"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/load/oneminute/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/load/oneminute/2.0" ];
    $self->{MAP}{"load_one"}{"type"}           = "node";
    $self->{MAP}{"load_one"}{"ds"}             = "sum";
    $self->{MAP}{"load_five"}{"eventTypes"}    = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/load/fiveminute/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/load/fiveminute/2.0" ];
    $self->{MAP}{"load_five"}{"type"}          = "node";
    $self->{MAP}{"load_five"}{"ds"}            = "sum";
    $self->{MAP}{"load_fifteen"}{"eventTypes"} = [ "http://ggf.org/ns/nmwg/tools/ganglia/cpu/load/fifteenminute/2.0", "http://ggf.org/ns/nmwg/characteristic/cpu/load/fifteenminute/2.0" ];
    $self->{MAP}{"load_fifteen"}{"type"}       = "node";
    $self->{MAP}{"load_fifteen"}{"ds"}         = "sum";
    $self->{MAP}{"mem_cached"}{"eventTypes"}   = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/cached/total/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/cached/total/2.0" ];
    $self->{MAP}{"mem_cached"}{"type"}         = "node";
    $self->{MAP}{"mem_cached"}{"ds"}           = "sum";
    $self->{MAP}{"mem_free"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/main/free/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/main/free/2.0" ];
    $self->{MAP}{"mem_free"}{"type"}           = "node";
    $self->{MAP}{"mem_free"}{"ds"}             = "sum";
    $self->{MAP}{"mem_total"}{"eventTypes"}    = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/main/total/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/main/total/2.0" ];
    $self->{MAP}{"mem_total"}{"type"}          = "node";
    $self->{MAP}{"mem_total"}{"ds"}            = "sum";
    $self->{MAP}{"mem_buffers"}{"eventTypes"}  = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/buffers/total/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/buffers/total/2.0" ];
    $self->{MAP}{"mem_buffers"}{"type"}        = "node";
    $self->{MAP}{"mem_buffers"}{"ds"}          = "sum";
    $self->{MAP}{"mem_shared"}{"eventTypes"}   = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/shared/total/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/shared/total/2.0" ];
    $self->{MAP}{"mem_shared"}{"type"}         = "node";
    $self->{MAP}{"mem_shared"}{"ds"}           = "sum";
    $self->{MAP}{"swap_free"}{"eventTypes"}    = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/swap/free/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/swap/free/2.0" ];
    $self->{MAP}{"swap_free"}{"type"}          = "node";
    $self->{MAP}{"swap_free"}{"ds"}            = "sum";
    $self->{MAP}{"swap_total"}{"eventTypes"}   = [ "http://ggf.org/ns/nmwg/tools/ganglia/memory/swap/total/2.0", "http://ggf.org/ns/nmwg/characteristic/memory/swap/total/2.0" ];
    $self->{MAP}{"swap_total"}{"type"}         = "node";
    $self->{MAP}{"swap_total"}{"ds"}           = "sum";

    $self->{TEMPLATES}{"bytes_in_\\w+"}{"eventTypes"}      = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/bytes/received/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/bytes/2.0", "http://ggf.org/ns/nmwg/characteristic/utilization/2.0" ];
    $self->{TEMPLATES}{"bytes_in_\\w+"}{"type"}            = "interface";
    $self->{TEMPLATES}{"bytes_in_\\w+"}{"ds"}              = "sum";
    $self->{TEMPLATES}{"bytes_in_\\w+"}{"ifNameRegex"}     = "bytes_in_(\\w+)";
    
    $self->{TEMPLATES}{"bytes_out_\\w+"}{"eventTypes"}     = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/bytes/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/bytes/2.0", "http://ggf.org/ns/nmwg/characteristic/utilization/2.0" ];
    $self->{TEMPLATES}{"bytes_out_\\w+"}{"type"}           = "interface";
    $self->{TEMPLATES}{"bytes_out_\\w+"}{"ds"}             = "sum";
    $self->{TEMPLATES}{"bytes_out_\\w+"}{"ifNameRegex"}    = "bytes_out_(\\w+)";
    
    $self->{TEMPLATES}{"pkts_in_\\w+"}{"eventTypes"}       = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/packets/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/packets/2.0" ];
    $self->{TEMPLATES}{"pkts_in_\\w+"}{"type"}             = "interface";
    $self->{TEMPLATES}{"pkts_in_\\w+"}{"ds"}               = "sum";
    $self->{TEMPLATES}{"pkts_in_\\w+"}{"ifNameRegex"}      = "pkts_in_(\\w+)";
    
    $self->{TEMPLATES}{"pkts_out_\\w+"}{"eventTypes"}      = [ "http://ggf.org/ns/nmwg/tools/ganglia/network/utilization/packets/2.0", "http://ggf.org/ns/nmwg/characteristic/network/utilization/packets/2.0" ];
    $self->{TEMPLATES}{"pkts_out_\\w+"}{"type"}            = "interface";
    $self->{TEMPLATES}{"pkts_out_\\w+"}{"ds"}              = "sum";
    $self->{TEMPLATES}{"pkts_out_\\w+"}{"ifNameRegex"}     = "pkts_out_(\\w+)";
    
    if ( exists $parameters->{conf} and $parameters->{conf} ) {
        $self->{CONF} = $parameters->{conf};
    }

    if ( exists $parameters->{file} and $parameters->{file} ) {
        $self->{FILE} = $parameters->{file};
    }

    if ( exists $parameters->{rrd} and $parameters->{rrd} ) {
        $self->{RRDTOOL} = $parameters->{rrd};
    }
    else {
        $self->{RRDTOOL} = "rrdtool";
    }

    if ( exists $parameters->{telnet} and $parameters->{telnet} ) {
        $self->{TELNET} = $parameters->{telnet};
    }
    else {
        $self->{TELNET} = "telnet";
    }

    return $self;
}

=head2 setConf($self, { conf })

Set the cacti configuration file.

=cut

sub setConf {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { conf => 1 } );

    if ( $parameters->{conf} =~ m/\/.*\.conf$/mx ) {
        $self->{CONF} = $parameters->{conf};
        return 0;
    }
    else {
        $self->{LOGGER}->error( "Cannot set configuration file." );
        return -1;
    }
}

=head2 setFile($self, { file })

set the output store file.

=cut

sub setFile {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { file => 1 } );

    if ( $parameters->{file} =~ m/\.xml$/mx ) {
        $self->{FILE} = $parameters->{file};
        return 0;
    }
    else {
        $self->{LOGGER}->error( "Cannot set filename." );
        return -1;
    }
}

=head2 setRRD($self, { rrd })

set the location of RRDtool

=cut

sub setRRD {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { rrd => 1 } );

    if ( $parameters->{rrd} =~ m/^\//mx ) {
        $self->{RRDTOOL} = $parameters->{rrd};
        return 0;
    }
    else {
        $self->{LOGGER}->error( "Cannot set rrd location" );
        return -1;
    }
}

=head2 setTelnet($self, { telnet })

set the location of telnet

=cut

sub setTelnet {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { telnet => 1 } );

    if ( $parameters->{telnet} =~ m/^\//mx ) {
        $self->{TELNET} = $parameters->{telnet};
        return 0;
    }
    else {
        $self->{LOGGER}->error( "Cannot set telnet location" );
        return -1;
    }
}

=head2 openDB($self, {  })

Open the connection to the cacti databases, iterate through making the store.xml
file.

=cut

sub openDB {
    my ( $self, @args ) = @_;
    my $parametersx = validateParams( @args, {} );

    unless ( $self->{CONF} ) {
        $self->{LOGGER}->fatal( "Configuration file not found" );
        return -1;
    }
    my %config = ParseConfig( $self->{CONF} );

    if ( defined $config{"data_source"} and $config{"data_source"} ) {

        # need to break this up, the format is: "string" [interval] hostlist

        my $startString = index $config{"data_source"}, "\"";
        my $endString = index $config{"data_source"}, "\"", ( $startString + 1 );

        # the string is between quotes (always)
        $config{"data_source_string"} = substr( $config{"data_source"}, $startString, ( $endString - $startString + 1 ) );

        # this is the list after the string
        my @values = split( / /, substr( $config{"data_source"}, ( $endString - $startString + 2 ) ) );

        # if the first item is an integer, set the interval
        if ( $values[0] and $values[0] =~ m/\d+/ ) {
            $config{"data_source_interval"} = $values[0];
        }
        else {

            # iterate over the list and get the hosts
            my $localSeen = 0;
            foreach my $v ( @values ) {
                $localSeen++ if lc $v eq "localhost";
                push @{ $config{"data_source_host"} }, $v;
            }

            # this is a 'default', make sure we add it
            push @{ $config{"data_source_host"} }, "localhost" unless $localSeen;
        }
    }

    # Go with the 'data_source'.
    $config{"data_source_interval"} = "15"   unless defined $config{"data_source_interval"};
    $config{"data_source_port"}     = "8649" unless defined $config{"data_source_port"};

    # name of the grid
    $config{"gridname"} = "unspecified" unless defined $config{"gridname"};

    # gmetad host
    $config{"gmetad_host"} = "localhost" unless defined $config{"gmetad_host"};

    # gmetad port (requests for XML)
    $config{"xml_port"} = "8651" unless defined $config{"xml_port"};

    # gmetad port (queries for XML)
    $config{"interactive_port"} = "8652" unless defined $config{"interactive_port"};

    # lcoation of RRD files
    $config{"rrd_rootdir"} = "/var/lib/ganglia/rrds" unless defined $config{"rrd_rootdir"};

    my @params = ( $config{"gmetad_host"}, $config{"interactive_port"} );
    my $exp = Expect->spawn( $self->{TELNET}, @params ) or die "Cannot spawn $self->{TELNET}: $!\n";
    $exp->log_stdout( 0 );
    $exp->send( "/" . $config{"gridname"} . "\n" );
    my @array = $exp->expect( 10, 'eof' );
    $exp->soft_close();

    my @xml = split( "\n", $array[3] );
    shift @xml;
    shift @xml;
    shift @xml;
    shift @xml;
    pop @xml;

    my $parser = XML::LibXML->new();
    my $xmlobj = $parser->parse_string( join( '', @xml ) );

    my $rrddb = new perfSONAR_PS::DB::RRD( { path => $self->{RRDTOOL}, error => 1 } );
    $rrddb->openDB;

    $self->{STORE} = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    $self->{STORE} .= "<nmwg:store  xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
    $self->{STORE} .= "             xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"\n";
    $self->{STORE} .= "             xmlns:nmwgt3=\"http://ggf.org/ns/nmwg/topology/base/3.0/\"\n";
    $self->{STORE} .= "             xmlns:ganglia=\"http://ggf.org/ns/nmwg/tools/ganglia/2.0/\">\n\n";

    my %struct = ();
    foreach my $grid ( $xmlobj->getDocumentElement->getChildrenByTagName( "GRID" ) ) {
        foreach my $cluster ( $grid->getChildrenByTagName( "CLUSTER" ) ) {
            foreach my $host ( $cluster->getChildrenByTagName( "HOST" ) ) {

                $struct{ $grid->getAttribute( "NAME" ) }{ $cluster->getAttribute( "NAME" ) }{ $host->getAttribute( "NAME" ) }{"host_info"}{"NAME"}      = "host_info";
                $struct{ $grid->getAttribute( "NAME" ) }{ $cluster->getAttribute( "NAME" ) }{ $host->getAttribute( "NAME" ) }{"host_info"}{"HOSTNAME"}  = $host->getAttribute( "NAME" );
                $struct{ $grid->getAttribute( "NAME" ) }{ $cluster->getAttribute( "NAME" ) }{ $host->getAttribute( "NAME" ) }{"host_info"}{"IPADDRESS"} = $host->getAttribute( "IP" );

                foreach my $metric ( $host->getChildrenByTagName( "METRIC" ) ) {
                    $struct{ $grid->getAttribute( "NAME" ) }{ $cluster->getAttribute( "NAME" ) }{ $host->getAttribute( "NAME" ) }{ $metric->getAttribute( "NAME" ) }{"NAME"}  = $metric->getAttribute( "NAME" );
                    $struct{ $grid->getAttribute( "NAME" ) }{ $cluster->getAttribute( "NAME" ) }{ $host->getAttribute( "NAME" ) }{ $metric->getAttribute( "NAME" ) }{"UNITS"} = $metric->getAttribute( "UNITS" );
                    $struct{ $grid->getAttribute( "NAME" ) }{ $cluster->getAttribute( "NAME" ) }{ $host->getAttribute( "NAME" ) }{ $metric->getAttribute( "NAME" ) }{"VALUE"} = $metric->getAttribute( "VAL" );
                }
            }
        }
    }

    my $c = 0;
    foreach my $grid ( keys %struct ) {
        foreach my $cluster ( keys %{ $struct{$grid} } ) {
            foreach my $host ( keys %{ $struct{$grid}{$cluster} } ) {
                foreach my $metric ( keys %{ $struct{$grid}{$cluster}{$host} } ) {
                    my $metric_name = $struct{$grid}{$cluster}{$host}{$metric}{"NAME"};
                    
                    my $meta = undef;
                    if ( exists $self->{MAP}{ $metric_name } ) {
                        $meta = $self->{MAP}{ $metric_name };
                    } 
                    else {
                        for my $template ( keys %{ $self->{TEMPLATES} } ) {
                            if ( $metric_name =~ m/$template/ ) {
                                $meta = $self->{TEMPLATES}{ $template };
                                last;
                            }
                        }
                    }
                    
                    if ( $meta ) {
                        $self->{STORE} .= "  <nmwg:metadata xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"metadata." . $c . "\">\n";
                        $self->{STORE} .= "    <ganglia:subject xmlns:ganglia=\"http://ggf.org/ns/nmwg/tools/ganglia/2.0/\" id=\"subject\">\n";

                        if ( $meta->{"type"} eq "node" ) {
                            $self->{STORE} .= "      <nmwgt3:node xmlns:nmwgt3=\"http://ggf.org/ns/nmwg/topology/base/3.0/\" id=\"node\">\n";
                            $self->{STORE} .= "        <nmwgt3:name>" . $grid . "-" . $cluster . "-" . $host . "</nmwgt3:name>\n";
                            $self->{STORE} .= "        <nmwgt3:hostName>" . $struct{$grid}{$cluster}{$host}{"host_info"}{"HOSTNAME"} . "</nmwgt3:hostName>\n" if exists $struct{$grid}{$cluster}{$host}{"host_info"}{"HOSTNAME"};
                            $self->{STORE} .= "        <nmwgt3:cpu>" . $struct{$grid}{$cluster}{$host}{"machine_type"}{"VALUE"} . "</nmwgt3:cpu>\n" if exists $struct{$grid}{$cluster}{$host}{"machine_type"};
                            $self->{STORE} .= "        <nmwgt3:operSys>" . $struct{$grid}{$cluster}{$host}{"os_name"}{"VALUE"} . " " . $struct{$grid}{$cluster}{$host}{"os_release"}{"VALUE"} . "</nmwgt3:operSys>\n";
                            $self->{STORE} .= "      </nmwgt3:node>\n";
                        }
                        elsif ( $meta->{"type"} eq "interface" ) {
                            $self->{STORE} .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
                            $self->{STORE} .= "        <nmwgt:hostName>" . $struct{$grid}{$cluster}{$host}{"host_info"}{"HOSTNAME"} . "</nmwgt:hostName>\n" if $struct{$grid}{$cluster}{$host}{"host_info"}{"HOSTNAME"};
                            
                            $metric_name =~ m/$meta->{ifNameRegex}/;
                            $self->{STORE} .= "        <nmwgt:ifName>" . $1 . "</nmwgt:ifName>\n";
                            
                            if ( $metric_name =~ m/.*_in(_.*)?$/ ) {
                                $self->{STORE} .= "        <nmwgt:direction>in</nmwgt:direction>\n";
                            }
                            elsif ( $metric_name =~ m/.*out(_.*)?$/ ) {
                                $self->{STORE} .= "        <nmwgt:direction>out</nmwgt:direction>\n";
                            }
                            $self->{STORE} .= "      </nmwgt:interface>\n";
                        }
                        $self->{STORE} .= "    </ganglia:subject>\n";
                        
                        foreach my $eT ( @{ $meta->{"eventTypes"} } ) {
                            $self->{STORE} .= "    <nmwg:eventType>" . $eT . "</nmwg:eventType>\n";
                        }
                        $self->{STORE} .= "    <nmwg:parameters id=\"parameters\">\n";
                        foreach my $eT ( @{ $meta->{"eventTypes"} } ) {
                            $self->{STORE} .= "      <nmwg:parameter name=\"supportedEventType\">" . $eT . "</nmwg:parameter>\n";
                        }
                        $self->{STORE} .= "    </nmwg:parameters>\n";
                        $self->{STORE} .= "  </nmwg:metadata>\n\n";

                        $self->{STORE} .= "  <nmwg:data xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" id=\"data." . $c . "\" metadataIdRef=\"metadata." . $c . "\">\n";
                        $self->{STORE} .= "    <nmwg:key id=\"key\">\n";
                        $self->{STORE} .= "      <nmwg:parameters id=\"pkey\">\n";
                        foreach my $eT ( @{ $meta->{"eventTypes"} } ) {
                            $self->{STORE} .= "      <nmwg:parameter name=\"supportedEventType\">" . $eT . "</nmwg:parameter>\n";
                        }
                        $self->{STORE} .= "        <nmwg:parameter name=\"type\">rrd</nmwg:parameter>\n";
                        $self->{STORE} .= "        <nmwg:parameter name=\"file\">" . $config{"rrd_rootdir"} . "/" . $cluster . "/" . $struct{$grid}{$cluster}{$host}{"host_info"}{"HOSTNAME"} . "/" . $struct{$grid}{$cluster}{$host}{$metric}{"NAME"} . ".rrd</nmwg:parameter>\n";
                        $self->{STORE} .= "        <nmwg:parameter name=\"valueUnits\">" . $struct{$grid}{$cluster}{$host}{$metric}{"UNITS"} . "</nmwg:parameter>\n";
                        $self->{STORE} .= "        <nmwg:parameter name=\"dataSource\">" . $meta->{"ds"} . "</nmwg:parameter>\n";

                        if ( $rrddb ) {
                            $rrddb->setFile( { file => $config{"rrd_rootdir"} . "/" . $config{"gridname"} . "/" . $struct{$grid}{$cluster}{$host}{"host_info"}{"HOSTNAME"} . "/" . $struct{$grid}{$cluster}{$host}{$metric}{"NAME"} . ".rrd" } );
                            my $first      = $rrddb->firstValue();
                            my $rrd_result = $rrddb->info();

                            unless ( $rrddb->getErrorMessage ) {
                                my %lookup = ();
                                foreach my $rra ( sort keys %{ $rrd_result->{"rra"} } ) {

                                    # XXX JZ 8/26/2010
                                    # This 'next' evaluation shouldn't be
                                    #   needed.  The RRD files appear to
                                    #   have an RRA for the 'step' size, but
                                    #   RRDFile doesn't return it.
                                    next if $rrd_result->{"rra"}->{$rra}->{"pdp_per_row"} == "1";
                                    push @{ $lookup{ $rrd_result->{"rra"}->{$rra}->{"cf"} } }, ( $rrd_result->{"rra"}->{$rra}->{"pdp_per_row"} * $rrd_result->{"step"} );
                                }
                                foreach my $cf ( keys %lookup ) {
                                    $self->{STORE} .= "        <nmwg:parameter name=\"consolidationFunction\" value=\"" . $cf . "\">\n";
                                    foreach my $res ( @{ $lookup{$cf} } ) {
                                        $self->{STORE} .= "          <nmwg:parameter name=\"resolution\">" . $res . "</nmwg:parameter>\n";
                                    }
                                    $self->{STORE} .= "        </nmwg:parameter>\n";
                                }
                                $self->{STORE} .= "        <nmwg:parameter name=\"lastTime\">" . $rrd_result->{"last_update"} . "</nmwg:parameter>\n" if $rrd_result->{"last_update"};
                            }
                            $self->{STORE} .= "        <nmwg:parameter name=\"firstTime\">" . $first . "</nmwg:parameter>\n" if $first;
                        }
                        $self->{STORE} .= "      </nmwg:parameters>\n";
                        $self->{STORE} .= "    </nmwg:key>\n";
                        $self->{STORE} .= "  </nmwg:data>\n\n";
                        $c++;
                    }
                }
            }
        }
    }

    $self->{STORE} .= "</nmwg:store>\n";

    $rrddb->closeDB;

    return 0;
}

=head2 commitDB($self, { })

Closes out the database, writes it to a file.  

=cut

sub commitDB {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    unless ( $self->{FILE} ) {
        $self->{LOGGER}->error( "Output file not set, aborting." );
        return -1;
    }
    if ( $self->{STORE} ) {
        open( OUTPUT, ">" . $self->{FILE} );
        print OUTPUT $self->{STORE};
        close( OUTPUT );
        return 0;
    }
    $self->{LOGGER}->error( "Ganglia xml content is empty, did you call \"openDB\"?" );
    return -1;
}

=head2 closeDB($self, { })

'Closes' the store.xml database that is created from the Ganglia data by
commiting the changes.

=cut

sub closeDB {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );
    $self->commitDB();
    return;
}

=head2 getMetric($class, { eventType => 1 } )

Returns the metric information of the given eventType.

=cut

sub getMetric {
    my ( $class, $et ) = @_;
    
    return undef unless exists METRICS->{ $et };
    
    return dclone( METRICS->{ $et } );
}

1;

__END__

=head1 SEE ALSO

L<Expect>, L<Log::Log4perl>, L<Params::Validate>, L<English>,
L<Config::General>, L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR-PS Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Ganglia.pm 4363 2010-08-27 01:45:36Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Guilherme Fernandes, fernande@cis.udel.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2010, Internet2 and the University of Delaware

All rights reserved.

=cut
