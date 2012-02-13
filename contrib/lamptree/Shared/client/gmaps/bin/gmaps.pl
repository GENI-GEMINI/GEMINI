#!/usr/local/bin/perl -I ../lib

use Log::Log4perl qw(:easy);
use gmaps::paths;

use gmaps::Interface::commandline;

use warnings;
use strict;

use Getopt::Long;

=head1 NAME

gmaps.pl: command line access to various gmap functionalities 

=head1 DESCRIPTION

This script allows access to the various client services available for perfSONAR services.

=head1 SYNOPSIS

  # get a list of available data urn's for a perfSONAR service
  gmaps.pl --psService=http://mea1.es.net:8080/perfSONAR_PS/services/snmpMA
  
  # get a table of ( epoch_time, input utilisation, output utilisation )
  gmaps.pl --psService=http://mea1.es.net:8080/perfSONAR_PS/services/snmpMA \
              --urn=urn:ogf:network:domain=ESnet-Public:node=wash-sdn1.es.net:port=TenGigabitEthernet1/1

  # generate a RRD PNG graph of the utilisation
  gmaps.pl --psService=http://mea1.es.net:8080/perfSONAR_PS/services/snmpMA \
              --urn=urn:ogf:network:domain=ESnet-Public:node=wash-sdn1.es.net:port=TenGigabitEthernet1/1
              --graph
  
=head1 TODO

- Add LS integration
- Add Topology Integration
- Add PingER Support

=head1 DETAILS

This API is a work in progress, and still does not reflect the general access needed.

=cut

our $LOG_PATTERN = '%d %C::%M - %m%n';

my $service = undef;
my $eventType = undef;

my @urn = ();
my $key = undef;

my $graph = undef;

my $period = undef;
my $startTime = undef;
my $endTime = undef;

my $cf = undef,
my $resolution = undef,

my $nocache = 0;

my $HELP = 0;
my $debug = 0;

my $ok = GetOptions (

		'service=s' => \$service,
		'eventType=s' => \$eventType,
		
		'urn=s' => sub{  push( @urn, $_[1] ); },
        'key=s' => \$key,

        'period=s'  => \$period,
		'startTime=i' => \$startTime,
		'endTime=i' => \$endTime,

		'cf=s'	=> \$cf,
		'resolution=i'	=> \$resolution,
		
		'nocache' => \$nocache,
		
		'graph' => \$graph,
		
		'verbose' => \$debug,
		'help' => \$HELP,
		
		);

if ( ! $ok or $HELP ) {

	&help();
    exit -1;	
}


# remap time if period exists
if ( defined $period ) {
    if ( ! defined $startTime ) {
        $endTime = time();
    }
    
    # parse the period
    if ( $period =~ /^(\d+)((h|d|w|m))$/ ) {
        
        my $scope = $2;
        my $multiplier = 1;
        if ( $scope eq 'h' ) {
            $multiplier = 3600;
        } elsif ( $scope eq 'd' ) {
            $multiplier = 24 * 3600;
        } elsif ( $scope eq 'w' ) {
            $multiplier = 7 * 24 * 3600;
        } elsif ( $scope eq 'm' ) {
            $multiplier = 24 * 3600 * 31;
        }
        
        $startTime = $endTime - ( $1 * $multiplier );
    }

}


# set up the logger
my %logging = (
	"log4perl.logger.perfSONAR_PS"	=> "DEBUG, OUT",
	"log4perl.logger.gmaps"	=> "DEBUG, OUT",
	"log4perl.appender.OUT" => "Log::Log4perl::Appender::ScreenColoredLevels",
	"log4perl.appender.OUT.filename" => "STDOUT",
	"log4perl.appender.OUT.mode" => "append",
	"log4perl.appender.OUT.layout" => "PatternLayout",
	"log4perl.appender.OUT.layout.ConversionPattern" => $LOG_PATTERN,
);

# instatnita telogger logging
if ( -e ${gmaps::paths::logFile} )  {
  Log::Log4perl->init( ${gmaps::paths::logFile} );
} else {

if ( $debug ) {
  $logging{'log4perl.logger.perfSONAR_PS'} = 'DEBUG, OUT';
  $logging{'log4perl.logger.gmaps'}	= "DEBUG, OUT";
  $logging{'log4perl.logger.utils'}	= "DEBUG, OUT";
  $logging{'log4perl.appender.OUT.layout.ConversionPattern'} = "%d %C::%M - %m%n";
} else {
  $logging{'log4perl.logger.perfSONAR_PS'} = 'INFO, OUT';
  $logging{'log4perl.logger.gmaps'}	= "INFO, OUT";
  $logging{'log4perl.logger.utils'}	= "INFO, OUT";
  $logging{'log4perl.appender.OUT.layout.ConversionPattern'} = "%m%n";	
  #Log::Log4perl->easy_init($INFO);
}

Log::Log4perl->init( \%logging );

}

our $logger = get_logger( 'gmaps.pl');


# caching
if ( $nocache ) {
    ${gmaps::paths::discoverCache} = undef;
    $logger->debug( "Disabling caching");
}

# start a new instance of interface
my $client = gmaps::commandline->new();


## work out the urn's if it's serviceType
my $urn = undef;
if ( scalar @urn > 2 ) {
    $logger->logdie( "Too many urn definitions provided (only one service and one data urn allowed max).")
}
foreach my $u ( @urn ) {
    
    my $hash = utils::urn::toHash( $u );
    
    # found a service to get
    my $serviceDefinition = 0;
    
    if ( exists $hash->{'accessPoint'} ) {
        $service = $hash->{'accessPoint'};
        $serviceDefinition=1;
    }
    if ( exists $hash->{'eventType'} ) {
        $eventType = $hash->{'eventType'};
    }
    
    if ( ! $serviceDefinition ) {
        $urn = $u;
    }
}

###
# query the root LS for a list of services
###
if ( ! defined $service  && ( scalar @urn < 1 || ! defined $key ) ) {
    
    # get a list of gLSs
    my $gLSes = $client->getGLSUrn();
    foreach my $gLS ( @$gLSes ) {
        print( $gLS . "\n" );
    }
    
    exit 0;

}

###
# deal with a lookup service
###
my $urnHash = utils::urn::toHash( $urn );

if ( ! defined $service && ( defined $urn || defined $key ) ) {

    $service = $urnHash->{accessPoint};
    $eventType = $urnHash->{eventType} unless defined $eventType;

    # clear urn
    $urn = undef;

    if ( ! defined $service ) {
        $logger->logdie( "Service not defined.")
    }

}

###    
# query the specified service 
###
if ( ! defined $eventType ) {
    my $evts = gmaps::EventType2Service::autoDetermineEventType( $service );
    if ( scalar @$evts > 1 ) {
        $logger->logdie( "Service '$service' provides many eventTypes: @$evts");
    } else {
        $eventType = shift @$evts;
    }
}
    
# if no urn defined, get list of urns from service
if ( defined $service && ! ( defined $urn || defined $key ) ) {
    
	my $list = $client->list( $service, $eventType );
	foreach my $urn ( @$list ) {
		print( $urn ."\n");
	}
} 


else {

    if ( ! defined $key ) {
        $key = $urnHash->{key};
    }

    my $args = {    uri => $service, 
                    eventType => $eventType,
                    urn => $urn, 
                    key => $key,
                    startTime => $startTime, 
                    endTime => $endTime,
                    period => $period,
                    resolution => $resolution, 
                    consolidationFunction => $cf  };

	# return a graph or text?
	if ( $graph ) {

		my $output = $client->graph( $args );
		print $$output;

	} else {
	
		$endTime = time()
			if ( ! defined $endTime );
	
		my ( $fields, $data ) = $client->fetch( $args );

		my $table = &formatAsTable( $data, @$fields );
		foreach my $line ( @$table ) {
			print  $line . "\n";
		}

	} 

}


exit 0;



###
# output hlep prompt
###
sub help
{
	print STDERR "$0: A command line interface to perfSONAR data (currently supports utilisation)\n";
    print STDERR "\n";
	print STDERR "  Usage: $0 [--graph|--urn=STRING] --service=URI\n";
    print STDERR "\n";
	print STDERR "  --service         URI of perfSONAR Service to interrogate\n";
	print STDERR "  --eventType       eventType of perfSONAR Service to interrogate\n";
	print STDERR "  --urn             urn of item in service to fetch\n";
	print STDERR "  --key             key of item in service to fetch\n";
	print STDERR "  --graph           generate a png graph of data\n";
	print STDERR "  --period          fetch data from this period 1w, 1d etc\n";
	print STDERR "  --startTime       fetch data from this time (epoch secs)\n";
	print STDERR "  --endTime         fetch data upto this time (epoch secs)\n";
	print STDERR "  --cf              use the defined consolidation function\n";
	print STDERR "  --resolution      use the defined resolution\n";
	print STDERR "\n";
	print STDERR "Comments and suggestions to \<ytl\@slac.stanford.edu\>\n";
	print STDERR "\n";
}



###
# output the data structure as a table
###
sub formatAsTable
{
	my $data = shift;
	my @fields = @_;
	
	my @array = ();
	
	push @array, "#time\t" . join "\t", @fields;
	for my $t ( sort {$a <=> $b} keys %$data ) {
		
		my $string = $t . "\t";
		
		for( my $i=0; $i<scalar @fields; $i++ ) {
			
			if ( defined $data->{$t}->{$fields[$i]} ) {
				$string .= $data->{$t}->{$fields[$i]};
			} else {
				$string .= '-';
			}
			$string .= "\t" unless $i eq scalar @fields - 1;
			
		}
		
		push( @array, $string );
	}

	return \@array;
}
