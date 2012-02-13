#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

check_perfSONAR.pl - A nagios service check that queries a designated perfSONAR service.

=head1 DESCRIPTION

This nagios service check performs an Echo or DataRequest for perfSONAR MA services.
 
=cut

use Getopt::Long;
use XML::LibXML;
use Carp;
use English qw( -no_match_vars );
use Params::Validate qw(:all);

my $curTime = time();
my $dirname = q{};
my $libdir  = q{};

my %NAGIOS_API_ECODES = ( 'OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'UNKNOWN' => 3 );
my $_intDegCount = 0;

# we need to figure out what the library is at compile time so that "use lib"
# doesn't fail. To do this, we enclose the calculation of it in a BEGIN block.
BEGIN {
    $libdir = '/home/jason/perfSONAR-PS/lib/';
}
use lib "$libdir";

use perfSONAR_PS::Transport;
use perfSONAR_PS::Common qw( readXML );
use perfSONAR_PS::Utils::ParameterValidation;

our $DEBUGFLAG;
our %opts = ();
our $help_needed;

my $ok = GetOptions(
    'debug'           => \$DEBUGFLAG,
    'server=s'        => \$opts{HOST},
    'port=s'          => \$opts{PORT},
    'endpoint=s'      => \$opts{ENDPOINT},
    'filter=s'        => \$opts{FILTER},
    'help'            => \$help_needed,
    'interfaceIP=s'   => \$opts{INTERFACEIP},
    'hostname=s'      => \$opts{HOSTNAME},
    'interfaceName=s' => \$opts{INTERFACENAME},
    'template=s'      => \$opts{TEMPLATE}
);

if ( not $ok or $help_needed ) {
    print_help();
    exit( 1 );
}

my $file          = q{};
my $xml           = q{};
my $filter        = '/';
my $host          = q{};
my $port          = q{};
my $endpoint      = q{};
my $interfaceIP   = q{};
my $hostname      = q{};
my $interfaceName = q{};
my $template      = q{};

if ( scalar @ARGV == 1 ) {
    ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $ARGV[0] );
    unless ( $host and $port and $endpoint ) {
        print_help();
        croak "Argument 1 must be a URL if more than one parameter used.\n";
    }
}
elsif ( scalar @ARGV == 2 ) {
    ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $ARGV[0] );
    unless ( $host and $port and $endpoint ) {
        print_help();
        croak "Argument 1 must be a URL if more than one parameter used.\n";
    }
    $file = $ARGV[1];
}
else {
}

if ( $file and ( not -f $file ) ) {
    croak "File $file does not exist";
}

# find options
if ( exists $opts{HOST} and $opts{HOST} ) {
    $host = $opts{HOST};
}
if ( exists $opts{PORT} and $opts{PORT} ) {
    $port = $opts{PORT};
}
if ( exists $opts{ENDPOINT} and $opts{ENDPOINT} ) {
    $endpoint = $opts{ENDPOINT};
}
if ( exists $opts{FILTER} and $opts{FILTER} ) {
    $filter = $opts{FILTER};
}
if ( exists $opts{INTERFACEIP} and $opts{INTERFACEIP} ) {
    $interfaceIP = $opts{INTERFACEIP};
}
if ( exists $opts{HOSTNAME} and $opts{HOSTNAME} ) {
    $hostname = $opts{HOSTNAME};
}
if ( exists $opts{INTERFACENAME} and $opts{INTERFACENAME} ) {
    $interfaceName = $opts{INTERFACENAME};
}
if ( exists $opts{TEMPLATE} and $opts{TEMPLATE} ) {
    $template = $opts{TEMPLATE};
}

unless ( $host and $port and $endpoint ) {
    print_help();
    croak "You must specify the host, port and endpoint as either a URI or via the command line switches";
}

# start a transport agent
my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );

if ( $file and -f $file ) {

    # Read the source XML file
    $xml = readXML( $file );
}
else {

    #echo request
    if ( $template == 2 ) {

        $xml = "<nmwg:message type=\"EchoRequest\"\n";
        $xml .= "             id=\"echo.message\"\n";
        $xml .= "             xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
        $xml .= "  <nmwg:metadata id=\"meta\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
        $xml .= "    <nmwg:eventType>echo.ma</nmwg:eventType>\n";
        $xml .= "  </nmwg:metadata>\n";
        $xml .= "  <nmwg:data id=\"data\" metadataIdRef=\"meta\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"/>\n";
        $xml .= "</nmwg:message>\n";
    }
    else {
        $xml = "<nmwg:message type=\"SetupDataRequest\" id=\"setupDataRequest1\"\n";
        $xml .= "             xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\"\n";
        $xml .= "             xmlns:neterr=\"http://ggf.org/ns/nmwg/characteristic/errors/2.0/\"\n";
        $xml .= "             xmlns:netdisc=\"http://ggf.org/ns/nmwg/characteristic/discards/2.0/\"\n";
        $xml .= "             xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"\n";
        $xml .= "             xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\"\n";
        $xml .= "             xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\"\n";
        $xml .= "             xmlns:snmp=\"http://ggf.org/ns/nmwg/tools/snmp/2.0/\"\n";
        $xml .= "             xmlns:nmtm=\"http://ggf.org/ns/nmwg/time/2.0/\">\n";

        $xml .= "  <nmwg:metadata id=\"meta\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
        $xml .= "    <netutil:subject xmlns:netutil=\"http://ggf.org/ns/nmwg/characteristic/utilization/2.0/\" id=\"sub\">\n";
        $xml .= "      <nmwgt:interface xmlns:nmwgt=\"http://ggf.org/ns/nmwg/topology/2.0/\">\n";
        $xml .= "        <nmwgt:ifAddress type=\"ipv4\">" . $interfaceIP . "</nmwgt:ifAddress>\n";
        $xml .= "        <nmwgt:hostName>" . $hostname . "</nmwgt:hostName>\n";
        $xml .= "        <nmwgt:ifName>" . $interfaceName . "</nmwgt:ifName>\n";
        $xml .= "        <nmwgt:direction>in</nmwgt:direction>\n";
        $xml .= "      </nmwgt:interface>\n";
        $xml .= "    </netutil:subject>\n";
        $xml .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/characteristic/utilization/2.0</nmwg:eventType>\n";
        $xml .= "  </nmwg:metadata>\n";

        $xml .= "  <nmwg:metadata id=\"metac\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">\n";
        $xml .= "    <select:subject id=\"subc\" metadataIdRef=\"meta\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\"/>\n";
        $xml .= "    <select:parameters id=\"paramc\" xmlns:select=\"http://ggf.org/ns/nmwg/ops/select/2.0/\">\n";
        $xml .= "      <nmwg:parameter name=\"startTime\">" . ( $curTime - 100 ) . "</nmwg:parameter>\n";
        $xml .= "      <nmwg:parameter name=\"endTime\">" . $curTime . "</nmwg:parameter>\n";
        $xml .= "      <nmwg:parameter name=\"consolidationFunction\">AVERAGE</nmwg:parameter>\n";
        $xml .= "      <nmwg:parameter name=\"resolution\">10</nmwg:parameter>\n";
        $xml .= "    </select:parameters>\n";
        $xml .= "    <nmwg:eventType>http://ggf.org/ns/nmwg/ops/select/2.0</nmwg:eventType>\n";
        $xml .= "  </nmwg:metadata>\n";
        $xml .= "  <nmwg:data id=\"data\" metadataIdRef=\"metac\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"/>\n";
        $xml .= "</nmwg:message>\n";
    }
}

# Make a SOAP envelope, use the XML file as the body.
my $envelope = &perfSONAR_PS::Common::makeEnvelope( $xml );
my $error    = q{};

my $responseContent = $sender->sendReceive( $envelope, q{}, \$error );

croak "Error sending request to service: $error" if $error;

&extract( { response => $responseContent, find => $filter } );

print "perfSONAR service has returned unexpected response.\n";
exit $NAGIOS_API_ECODES{UNKNOWN};

=head2 extract( { response, find } )

Print out results of service message.  

=cut

sub extract {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { response => 1, find => 1 } );
    my $xp = q{};

    if ( ( UNIVERSAL::can( $parameters->{response}, "isa" ) ? "1" : "0" == 1 ) and ( $xml->isa( 'XML::LibXML' ) ) ) {
        $xp = $parameters->{response};
    }
    else {
        my $parser = XML::LibXML->new();
        $xp = $parser->parse_string( $parameters->{response} );
    }

        # first parse, try to grab the message and puke if we can't find it
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs( 'nmwg', 'http://ggf.org/ns/nmwg/base/2.0/' );
    my @message = $xpc->findnodes( '//nmwg:message', $xp->getDocumentElement );
    unless ( $message[0] ) {
        print "perfSONAR Request Failed\n";
        exit $NAGIOS_API_ECODES{CRITICAL};
    }
    
        # evaluation step, we want to handle message types differently
    my $mType = $message[0]->getAttribute( "type" );
    if ( $mType eq "EchoResponse" ) {
            # EchoRequest/EchoResponse case.  Doing this for traditional echo
            #  only.  Would be nice to extract the datum response from the
            #  correct md/d pair.  Have some exit conditions if the message
            #  is not well formed.  
    
        my $xpc = XML::LibXML::XPathContext->new;
        $xpc->registerNs( 'nmwg', 'http://ggf.org/ns/nmwg/base/2.0/' );
        my @res = $xpc->findnodes( '//nmwg:metadata', $message[0] );     

        my $eT = q{};
        my $dt = q{};
        foreach my $n ( @res ) {
            $eT = $xpc->find( '//nmwg:eventType', $n );
            my $id = $n->getAttribute( "id" );
            my $dt = $xpc->find( '//nmwg:data[@metadataIdRef="' . $id . '"]/*[local-name()="datum"]', $message[0] );            
            next unless $eT and $dt;
          
            if ( $eT->get_node(1)->toString() =~ m/success/mx ) {
                print "perfSONAR service replied \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
                exit $NAGIOS_API_ECODES{OK};                
            }
            elsif ( $n->toString() =~ m/error/mx ) {
                print "perfSONAR service replied \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
                exit $NAGIOS_API_ECODES{CRITICAL};
            }
            else {
                print "perfSONAR service replied \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
                exit $NAGIOS_API_ECODES{UNKNOWN};
            }
        }
        if ( $dt ) {
            print "perfSONAR service has returned unexpected response \"" . &perfSONAR_PS::Common::extract( $dt->get_node(1), 0 ) . "\"\n";
        }
        else {
            print "perfSONAR service has returned unexpected response.\n";
        }
        exit $NAGIOS_API_ECODES{UNKNOWN};
    }
    elsif ( $mType eq "SetupDataResponse" ) {
            # SetupDataRequest/SetupDataResponse case.  Want to do some more
            #   sophisitcated parsing here to evaluate the results and get a
            #   more exact message for nagios.  
            
        my $xpc = XML::LibXML::XPathContext->new;
        $xpc->registerNs( 'nmwg', 'http://ggf.org/ns/nmwg/base/2.0/' );
        my @res = $xpc->findnodes( $parameters->{find}, $message[0] );
        foreach my $n ( @res ) {
            if ( $n->toString() =~ m/success/mx ) {
            }
            elsif ( $n->toString() =~ m/error/mx ) {
                $_intDegCount++;
            }
        }

        if ( $_intDegCount > 0 ) {
            print "perfSONAR Request Failed\n";
            exit $NAGIOS_API_ECODES{CRITICAL};
        }
        else {
            print "perfSONAR Request Successful\n";
            exit $NAGIOS_API_ECODES{OK};
        }
    }
    else {
        # Catch All.
        print "perfSONAR response is unreadable.\n";
        exit $NAGIOS_API_ECODES{UNKNOWN};
    }
    return;
}

=head2 help()

Print a help message

=cut

sub print_help {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, {} );

    print "$PROGRAM_NAME: sends an xml request to a perfSONAR server.\n\n";
    print "    ./check_perfSonar.pl URI [--server --port --endpoint] [--template #] [--interfaceIP=xxx.xxx.xxx.xxx --hostname=xxx.yyy.zzz --interfaceName=xo-0/0/0.0] [FILE]\n\n";
    print "        Templates: 1 - Data Request (default)\n";
    print "                   2 - Echo Request\n\n";
    return;
}

__END__

=head1 SYNOPSIS

./check_perfSonar.pl URI [--server --port --endpoint] [--template #] [--interfaceIP=xxx.xxx.xxx.xxx --hostname=xxx.yyy.zzz --interfaceName=xo-0/0/0.0] [FILE]

  --server = Hostname to contact
  --port = port of host
  --endpoint = contact point of perfSONAR service
  --template = Template 'type' to use, 1 for setup data request, 2 for echo request
  --interfaceIP = for use with template 2, the ip address of an interface, e.g. xxx.xxx.xxx.xxx
  --hostname = for use with template 2, the hostname of an interface, e.g. xxx.yyy.zzz
  --interfaceName = for use with template 2, the name of an interface, e.g. xo-0/0/0.0

=head1 SEE ALSO

L<Getopt::Long>, L<XML::LibXML>, L<Carp>, L<English>, L<Params::Validate>,
L<perfSONAR_PS::Transport>, L<perfSONAR_PS::Common>,
L<perfSONAR_PS::Utils::ParameterValidation>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: check_perfSONAR.pl 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Yee-Ting Li, ytl@slac.stanford.edu
Chad E. Kotil, ckotil@grnoc.iu.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2, Indianna Univesrity, SLAC, and the University of Delaware

All rights reserved.

=cut
