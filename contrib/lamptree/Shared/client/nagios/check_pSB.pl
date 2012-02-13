#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

check_pSB.pl - A nagios check that queries a pSB instance for recent data 

=head1 DESCRIPTION

Plugin for nagios to check perfsonar services.  To configure in nagios, add
the following command to '$NAGIOS/etc/commands.cfg':

# 'check-perfSONAR-pSB' command definition
define command{
        command_name    check-perfSONAR-pSB   
        command_line    perl $USER1$/check_pSB.pl --server=$HOSTADDRESS$ --port=$_HOSTPORT$ --endpoint=$_HOSTENDPOINT$ --src=$_SERVICESRC$ --dst=$_SERVICEDST$ --hours=$_SERVICEHOURS$
        }

Then the test can be invoked for a given server/src/dst pair by adding the
following to area where other hosts/services are checked:

define host{
	host_name 	lab253.internet2.edu
	address		lab253.internet2.edu
	use		    perf-hosttemplate
	_port		8085
	_endpoint	perfSONAR_PS/services/pSB
	}

define service{
    use			            generic-service
	host_name 		        lab253.internet2.edu
    service_description	    Lab253 pSPT - perfSONAR-BUOY
	check_command		    check-perfSONAR-pSB
	is_volatile		        0
	check_period		    24x7
	max_check_attempts	    4
	normal_check_interval	5
	retry_check_interval	1
	contact_groups		    admins
	notification_options	w,u,c,r
	notification_interval	960
	notification_period	    24x7
	process_perf_data 	    0
	_src                    lab253.internet2.edu
	_dst                    nms-rthr2.newy32aoa.net.internet2.edu
	_hours                  12
    }

=cut

use Getopt::Long;
use English qw( -no_match_vars );
use XML::LibXML;

my $libdir  = q{};
my %NAGIOS_API_ECODES = ( 'OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3 );

# we need to figure out what the library is at compile time so that "use lib"
# doesn't fail. To do this, we enclose the calculation of it in a BEGIN block.
BEGIN {
#    $libdir = '/home/zurawski/perfSONAR-PS/Shared/lib';
    $libdir = '/home/jason/release/trunk/Shared/lib';
}
use lib "$libdir";

use perfSONAR_PS::Transport;
use perfSONAR_PS::Common qw( readXML );
use perfSONAR_PS::Utils::ParameterValidation;

our %opts = ();
our $HELP;

my $ok = GetOptions(
    'server=s'        => \$opts{HOST},
    'port=s'          => \$opts{PORT},
    'endpoint=s'      => \$opts{ENDPOINT},
    'src=s'           => \$opts{SRC},
    'dst=s'           => \$opts{DST},    
    'hours=s'         => \$opts{HOURS},
    'help'            => \$HELP
);

if ( not $ok or $HELP ) {
    help();
    exit;
}

my $host          = q{};
my $port          = q{};
my $endpoint      = q{};
my $src           = q{};
my $dst           = q{};
my $hours         = 24;

if ( exists $opts{HOST} and $opts{HOST} ) {
    $host = $opts{HOST};
}
if ( exists $opts{PORT} and $opts{PORT} ) {
    $port = $opts{PORT};
}
if ( exists $opts{ENDPOINT} and $opts{ENDPOINT} ) {
    $endpoint = $opts{ENDPOINT};
}
if ( exists $opts{SRC} and $opts{SRC} ) {
    $src = $opts{SRC};
}
if ( exists $opts{DST} and $opts{DST} ) {
    $dst = $opts{DST};
}
if ( exists $opts{HOURS} and $opts{HOURS} ) {
    $hours = $opts{HOURS};
}

unless ( $host and $port and $endpoint ) {
    help();
    exit;
}

# start a transport agent
my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );

# start with an echo message to see if the service is alive
my $xml = "<nmwg:message type=\"EchoRequest\" id=\"echo.message\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
$xml .= "  <nmwg:metadata id=\"meta\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
$xml .= "    <nmwg:eventType>echo.ma</nmwg:eventType>\n";
$xml .= "  </nmwg:metadata>\n";
$xml .= "  <nmwg:data id=\"data\" metadataIdRef=\"meta\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"/>\n";
$xml .= "</nmwg:message>\n";

# Make a SOAP envelope, use the XML file as the body.
my $envelope = &perfSONAR_PS::Common::makeEnvelope( $xml );
my $error = q{};

my $responseContent = $sender->sendReceive( $envelope, q{}, \$error );
if ( $error ) {
    print "perfSONAR Request Failed: $error\n";
    exit $NAGIOS_API_ECODES{CRITICAL};
}

&readEcho( { response => $responseContent } );

# now check a BWCTL pair
my $xml2head = "<nmwg:message type=\"SetupDataRequest\" id=\"echo.message\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" xmlns:iperf=\"http://ggf.org/ns/nmwg/tools/iperf/2.0/\" xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\">\n";
$xml2head .= "  <nmwg:metadata id=\"meta\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" >\n";
$xml2head .= "    <iperf:subject xmlns:iperf=\"http://ggf.org/ns/nmwg/tools/iperf/2.0/\" id=\"subject-0\">\n";
$xml2head .= "      <nmwgt:endPointPair xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";

my $endTime = time();
my $startTime = $endTime - ($hours * 3600);

my $xml2tail = "      </nmwgt:endPointPair>\n";
$xml2tail .= "    </iperf:subject>\n";
$xml2tail .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/tools/iperf/2.0</nmwg:eventType>\n";
$xml2tail .= "  </nmwg:metadata>\n";
$xml2tail .= "  <nmwg:metadata id=\"metac\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\" >\n";
$xml2tail .= "    <select:subject id=\"subc\" metadataIdRef=\"meta\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\"/>\n";
$xml2tail .= "    <select:parameters id=\"paramc\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\">\n";
$xml2tail .= "      <nmwg:parameter name=\"startTime\">" . $startTime . "</nmwg:parameter>\n";
$xml2tail .= "      <nmwg:parameter name=\"endTime\">" . $endTime . "</nmwg:parameter>\n";
$xml2tail .= "    </select:parameters>\n";
$xml2tail .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/ops/select/2.0</nmwg:eventType>\n";
$xml2tail .= "  </nmwg:metadata>\n";
$xml2tail .= "  <nmwg:data id=\"data\" metadataIdRef=\"metac\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"/>\n";
$xml2tail .= "</nmwg:message>\n";

if ( $src and $dst ) {

    my $xml2mid = "        <nmwgt:src value=\"" . $src . "\" />\n";
    $xml2mid .= "        <nmwgt:dst value=\"" . $dst . "\" />\n";

    $envelope = &perfSONAR_PS::Common::makeEnvelope( $xml2head . $xml2mid . $xml2tail );
    $error = q{};

    $responseContent = $sender->sendReceive( $envelope, q{}, \$error );
    if ( $error ) {
        print "perfSONAR Request Failed: $error\n";
        exit $NAGIOS_API_ECODES{CRITICAL};
    }

    &readPSB( { response => $responseContent } );
}
else {
    print "Cannot check for data from perfSONAR service.\n";
    exit $NAGIOS_API_ECODES{UNKNOWN};
}

=head2 help()

Prints the help message and then returns.

=cut

sub help {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, {} );

    print "$PROGRAM_NAME: is a script that interacts with NAGIOS to monitor perfSONAR services.\n\n";
    print "    ./check_pSB.pl --server --port --endpoint --src --dst\n\n";
    return;
}

=head2 readEcho()

Reads the response from a service to see if the EchoRequest has succeeded.

=cut

sub readEcho {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { response => 1 } );
    my $xp = q{};

    if ( ( UNIVERSAL::can( $parameters->{response}, "isa" ) ? "1" : "0" == 1 ) and ( $xml->isa( 'XML::LibXML' ) ) ) {
        $xp = $parameters->{response};
    }
    else {
        my $parser = XML::LibXML->new();
        $xp = $parser->parse_string( $parameters->{response} );
    }

    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'nmwg', 'http://ggf.org/ns/nmwg/base/2.0/' );
    my @message = $xpc->findnodes( '//nmwg:message', $xp->getDocumentElement );
    unless ( $message[0] ) {
        print "perfSONAR Request Failed\n";
        exit $NAGIOS_API_ECODES{CRITICAL};
    }
    
    my $mType = $message[0]->getAttribute( "type" );
    if ( $mType eq "EchoResponse" ) {
    
        my $xpc2 = XML::LibXML::XPathContext->new;
        $xpc2->registerNs( 'nmwg', 'http://ggf.org/ns/nmwg/base/2.0/' );
        my @res = $xpc->findnodes( '//nmwg:metadata', $message[0] );     

        my $eT = $xpc2->find( '//nmwg:eventType', $res[0] );
        my $id = $res[0]->getAttribute( "id" );
        my $dt = $xpc2->find( '//nmwg:data[@metadataIdRef="' . $id . '"]/*[local-name()="datum"]', $message[0] );
        if ( $eT->get_node(1)->toString() =~ m/success/mx ) {
            #print "perfSONAR service replied \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
            #exit $NAGIOS_API_ECODES{OK};                
            return;
        }
        elsif ( $res[0]->toString() =~ m/error/mx ) {
            print "perfSONAR service replied \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
            exit $NAGIOS_API_ECODES{CRITICAL};
        }
        else {
            print "perfSONAR service replied \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
            exit $NAGIOS_API_ECODES{UNKNOWN};
        }        
    }
    print "perfSONAR response is unreadable.\n";
    exit $NAGIOS_API_ECODES{UNKNOWN};
    return;
}

=head2 readPSB()

Reads the response from a service.

=cut

sub readPSB {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { response => 1 } );
    my $xp = q{};

    if ( ( UNIVERSAL::can( $parameters->{response}, "isa" ) ? "1" : "0" == 1 ) and ( $xml->isa( 'XML::LibXML' ) ) ) {
        $xp = $parameters->{response};
    }
    else {
        my $parser = XML::LibXML->new();
        $xp = $parser->parse_string( $parameters->{response} );
    }

    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'nmwg', 'http://ggf.org/ns/nmwg/base/2.0/' );
    my @message = $xpc->findnodes( '//nmwg:message', $xp->getDocumentElement );
    unless ( $message[0] ) {
        print "perfSONAR Request Failed\n";
        exit $NAGIOS_API_ECODES{CRITICAL};
    }
    
    my $mType = $message[0]->getAttribute( "type" );
    if ( $mType eq "SetupDataResponse" ) {
    
        my $xpc2 = XML::LibXML::XPathContext->new;
        $xpc2->registerNs( 'nmwg', 'http://ggf.org/ns/nmwg/base/2.0/' );
        my @res = $xpc->findnodes( '//nmwg:metadata', $message[0] );     

        my $eT = $xpc2->find( '//nmwg:eventType', $res[0] );
        if ( $res[0]->toString() =~ m/error/mx ) {        
            my $id = $res[0]->getAttribute( "id" );
            my $dt = $xpc2->find( '//nmwg:data[@metadataIdRef="' . $id . '"]/*[local-name()="datum"]', $message[0] );
            print "perfSONAR service replied \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
            exit $NAGIOS_API_ECODES{UNKNOWN};
        }
        else {
            my $id = $res[0]->getAttribute( "id" );
            my @datum = $xpc->findnodes( '//nmwg:data[@metadataIdRef="' . $id . '"]/*[local-name()="datum"]', $message[0] );     
            my $count = 0;
            foreach my $d ( @datum ) {
                # we can do something with this datum of course ...                
                my $value = $d->getAttribute("throughput");
                my $time = $d->getAttribute("timeValue");                
                $count++ if $time and $value;
            }                   
            if ( $count ) {
                print "perfSONAR service has data for the last $hours hour(s).\n";
                exit $NAGIOS_API_ECODES{OK};  
            }
            else {
                print "perfSONAR service does not have data for the last $hours hour(s).\n";
                exit $NAGIOS_API_ECODES{CRITICAL};  
            }            
        }
    }
    print "perfSONAR response is unreadable.\n";
    exit $NAGIOS_API_ECODES{UNKNOWN};
    return;
}

__END__

=head1 SYNOPSIS

./check_pSB.pl [--server --port --endpoint --src --dst --hours]

=head1 SEE ALSO

L<Getopt::Long>, L<English>, L<perfSONAR_PS::Transport>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list
  
=head1 VERSION

$Id: check_pSB.pl 4076 2010-05-11 19:23:12Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2010, Internet2

All rights reserved.

=cut
