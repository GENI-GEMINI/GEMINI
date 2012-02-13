package perfSONAR_PS::Services::MP::Config::PingER;

use strict;
use warnings;

use version;
our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Services::MP::Config::PingER

=head1 DESCRIPTION

Configuration module for the support of scheduled tests for PingER.  This class
inherits perfSONAR_PS::MP::Config::Schedule in order to provide an interface to
the test periods and offsets defined for PingER tests.

In this implementation, we only handle the topology-like PingER schema.

=cut

use XML::LibXML;
use Data::Dumper;
use perfSONAR_PS::Services::MP::Config::Schedule;

use base 'perfSONAR_PS::Services::MP::Config::Schedule';

use Log::Log4perl qw( get_logger );

our $logger = Log::Log4perl->get_logger( 'perfSONAR_PS::Services::MP::Config::PingER' );

=head2 load( $file )

Loads and parses the configuration file with schedule information '$file'. If
no argument is passed, then will use the file defined in accessor/mutator
$self->configFile().

Returns
   0  = everything parsed okay
  -1  = parsing and or loading failed.

=cut

sub load {
    my $self     = shift;
    my $confFile = shift;

    if ( $confFile ) {
        $self->configFile( $confFile );
    }
    unless($self->{CONFFILE}) {
        $logger->logdie( "Landmarks file '$self->{CONFFILE}' is not defined" );
    }
    $logger->debug( "loading mp config file '" . $self->{CONFFILE} . "'" );
    if ( !-e $self->{CONFFILE} ) {
        $logger->error( "Landmarks file '$self->{CONFFILE}' does not exist" );
        exit -1;
    }

    my $parser = XML::LibXML->new();
    $parser->expand_xinclude( 1 );
    my $doc = $parser->parse_file( $self->{CONFFILE} );

    # get namespaces: TODO: use maxim's namespaces
    my $ns = {
        'pingertopo' => 'pingertopo',
        'nmtb'       => 'nmtb',
        'nmwg'       => 'nmwg',
    };

    # get the dest host s
    my $xpath = '//' . $ns->{pingertopo} . ':topology/' . $ns->{pingertopo} . ':domain/' . $ns->{pingertopo} . ':node';

    # make sure that it has children with tests
    $xpath .= '[child::' . $ns->{nmwg} . ':parameters/' . $ns->{nmwg} . ":parameter[\@name='measurementPeriod']]";

    # place to store al tests
    my $config = {};

    # keep tab on number of tests found
    my $found = 0;

    # loop through the resultant nodes with test and cast to a hash
    $logger->debug( "Finding: $xpath" );
    foreach my $node ( $doc->findnodes( $xpath ) ) {

        # get the id of the node
        my $nodeid = $node->getAttribute( 'id' );
        $logger->debug( "Found node id '$nodeid'" );

        #$logger->debug( "$node:\n"  . $node->toString() );

        my $ipAddress = undef;

        # determine the ip address also if exists
        foreach my $port ( $node->getChildrenByLocalName( 'port' ) ) {
            my $id = $port->getAttribute( 'id' );
            foreach my $ip ( $port->getChildrenByLocalName( 'ipAddress' ) ) {
                $ipAddress = $ip->textContent;
                chomp( $ipAddress );
            }
        }

        # get the destination name (hostName)
        my $destination = undef;
        foreach my $tag ( $node->getChildrenByLocalName( 'hostName' ) ) {
            $destination = $tag->textContent;
            chomp( $destination );
        }

        # get the tests and populat datastructure
        foreach my $test ( $node->getChildrenByLocalName( 'parameters' ) ) {

            #$logger->debug( "Found: " . $test->toString() );
            $logger->debug( "Found new test" );

            # find the params
            my $hash = {};
            foreach my $param ( $test->childNodes ) {
                my $tag = $param->localname();
                next
                    unless defined $tag
                        && $tag eq 'parameter';

                my $attr = $param->getAttribute( 'name' );
                if (
                    defined $attr
                    && (   $attr eq 'packetSize'
                        || $attr eq 'count'
                        || $attr eq 'packetInterval'
                        || $attr eq 'ttl'
                        || $attr eq 'measurementPeriod'
                        || $attr eq 'measurementOffset' )
                    )
                {
                    my $value = $param->textContent;
                    chomp( $value );

                    # remap the packetinterval into interval so the agent can use it
                    $attr = 'interval' if $attr eq 'packetInterval';
                    $logger->debug( "Found: '$attr' with value '$value'" );
                    $hash->{$attr} = $value;
                }

            }

            # don't bother if we don't have a period to use
            next
                if !exists $hash->{measurementPeriod};

            # create a special id to identify the test
            my $id = 'packetSize=' . $hash->{'packetSize'} . ':count=' . $hash->{count} . ':interval=' . $hash->{'interval'} . ':ttl=' . $hash->{ttl};

            # add the destination details
            $hash->{destinationIp} = $ipAddress   if $ipAddress;
            $hash->{destination}   = $destination if $destination;

            $config->{ $nodeid . ':' . $id } = $hash;
            $found++;

        }

    }

    if ( $found ) {
        $self->config( $config );
        $logger->debug( "Found $found unique tests" );
        return 0;
    }
    else {
        $logger->error( "Could not determine any scheduled tests from landmarks file '$confFile'" );
        return -1;
    }
}

1;

__END__

=head1 SYNOPSIS

  # create the configuration object
  my $schedule = perfSONAR_PS::Services::MP::Config::PingER->new();

  # set the configuration file to use (note that the definitions of how to
  # parse for the appropriate test periods, and offset times etc for the 
  #individual tests should be defined in an inherited class.
  $schedule->configFile( 'some-config-file-path' ); 
  if ( $schedule->load() == 0 ) {

	# get a list of the test id's to run
	my @testids = $schedule->getAllTestIds();
	
	# determine the period of time from now until the next test should run
	my $time = $schedule->getTestTimeFromNow( $testids[0] );

    print "The next test for '$testid' will run in $time seconds from now.";

  } else {

	print "Something went wrong with parsing file '" . $schedule->configFile() . "'\n";
    return -1;

  }
  
=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: PingER.pm 3562 2009-08-12 21:07:41Z maxim $

=head1 AUTHOR

Yee-Ting Li <ytl@slac.stanford.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2 and SLAC National Accelerator Laboratory

All rights reserved.

=cut
