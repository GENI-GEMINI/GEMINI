#!/usr/bin/perl -w

use strict;
use warnings;

our $VERSION = 3.2;

=head1 NAME

dump.pl - Dumps the contents of an XMLDB.

=head1 DESCRIPTION

Given the information on an XMLDB, connect and dump all metadata and data
elements.

=head1 SYNOPSIS

    # this will send the xml file echo-req.xml to srv4.dir.garr.it on port 8080
    # and endpoint /axis/services/MeasurementArchiveService
    $ client.pl \
           http://srv4.dir.garr.it:8080/axis/services/MeasurementArchiveService \
           echo-req.xml

    # ditto
    $ client.pl \
           --server=srv4.dir.garr.it \
           --port=8080 \
           --endpoint=/axis/services/MeasurementArchiveService \
           echo-req.xml
	       
    # this will override the port 8080 with the specified port 80
    $ client.pl \
           --port=80
           http://srv4.dir.garr.it:8080/axis/services/MeasurementArchiveService \
           echo-req.xml

    # this will override the endpoint with 
    # /perfsonar-RRDMA/services/MeasurementArchiveService
    $ client.pl \
           --endpoint=/perfsonar-RRDMA/services/MeasurementArchiveService
           http://srv4.dir.garr.it:8080/axis/services/MeasurementArchiveService \
           echo-req.xml
	        
    # this will filter the output of the returned xml to only show the elements
    # that have qname nmwg:data
    $ client.pl \
           --filter='//nmwg:data' \
           http://srv4.dir.garr.it:8080/axis/services/MeasurementArchiveService \
           echo-req.xml
           
=cut

use Getopt::Long;
use Log::Log4perl qw(:easy);
use XML::LibXML;
use File::Basename;
use Carp;
use Params::Validate qw(:all);
use English qw( -no_match_vars );

my $dirname;
my $libdir;

# we need to figure out what the library is at compile time so that "use lib"
# doesn't fail. To do this, we enclose the calculation of it in a BEGIN block.
BEGIN {
    $dirname = dirname( $PROGRAM_NAME );
    $libdir  = $dirname . "/../lib";
}

use lib "$libdir";

use perfSONAR_PS::Transport;
use perfSONAR_PS::Common qw( readXML );
use perfSONAR_PS::Utils::ParameterValidation;

our $DEBUGFLAG;
our %opts = ();
our $help_needed;

my $ok = GetOptions(
    'debug'      => \$DEBUGFLAG,
    'server=s'   => \$opts{HOST},
    'port=s'     => \$opts{PORT},
    'endpoint=s' => \$opts{ENDPOINT},
    'filter=s'   => \$opts{FILTER},
    'help'       => \$help_needed
);

if ( not $ok or $help_needed ) {
    print_help();
    exit( 1 );
}

our $level = $INFO;
$level = $DEBUG if $DEBUGFLAG;

Log::Log4perl->easy_init( $level );
my $logger = get_logger( "perfSONAR_PS" );

my $host     = q{};
my $port     = q{};
my $endpoint = q{};
my $filter   = '/';
my $file     = q{};
if ( scalar @ARGV == 2 ) {
    ( $host, $port, $endpoint ) = &perfSONAR_PS::Transport::splitURI( $ARGV[0] );

    unless ( $host and $port and $endpoint ) {
        print_help();
        croak "Argument 1 must be a URI if more than one parameter used.\n";
    }

    $file = $ARGV[1];
}
elsif ( scalar @ARGV == 1 ) {
    $file = $ARGV[0];
}
else {
    print_help();
    croak "Invalid number of parameters: must be 1 for just a file, or 2 for a uri and a file";
}

croak "File $file does not exist" unless -f $file;

if ( defined $opts{HOST} ) {
    $host = $opts{HOST};
}
if ( defined $opts{PORT} ) {
    $port = $opts{PORT};
}
if ( defined $opts{ENDPOINT} ) {
    $endpoint = $opts{ENDPOINT};
}
if ( defined $opts{FILTER} ) {
    $filter = $opts{FILTER};
}

unless ( $host and $port and $endpoint ) {
    print_help();
    croak "You must specify the host, port and endpoint as either a URI or via the command line switches";
}

# start a transport agent
my $sender = new perfSONAR_PS::Transport( $host, $port, $endpoint );

# Read the source XML file
my $xml = readXML( $file );

# Make a SOAP envelope, use the XML file as the body.
my $envelope = &perfSONAR_PS::Common::makeEnvelope( $xml );
my $error;

# Send/receive to the server, store the response for later processing
my $responseContent = $sender->sendReceive( $envelope, q{}, \$error );

croak "Error sending request to service: $error" if $error;

# dump the content to screen, using the xpath statement if necessary
&dump( { response => $responseContent, find => $filter } );

exit( 0 );

=head2 dump( { response, find } )

Print out results of service message.  

=cut

sub dump {
    my ( @args ) = @_;
    my $parameters = validateParams( @args, { response => 1, find => 1 } );
    my $xp = q{};

    if ( ( UNIVERSAL::can( $parameters->{response}, "isa" ) ? 1 : 0 == 1 ) and ( $xml->isa( 'XML::LibXML' ) ) ) {
        $xp = $parameters->{response};
    }
    else {
        my $parser = XML::LibXML->new();
        $xp = $parser->parse_string( $parameters->{response} );
    }

    my @res = $xp->findnodes( $parameters->{find} );
    foreach my $n ( @res ) {
        print $n->toString() . "\n";
    }
    return;
}

=head2 help()

Print a help message

=cut

sub print_help {
    print "$PROGRAM_NAME: sends an xml file to the server on specified port.\n";
    print "    ./client.pl [--server=xxx.yyy.zzz --port=n --endpoint=ENDPOINT] [URI] FILENAME\n";
    return;
}

__END__

=head1 SEE ALSO

L<use Getopt::Long>, L<perfSONAR_PS::DB::XMLDB>

To join the 'perfSONAR Users' mailing list, please visit:

  https://lists.internet2.edu/sympa/info/perfsonar-ps-users

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: client.pl 4475 2010-09-29 13:18:06Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu
Yee-Ting Li <ytl@slac.stanford.edu>

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2010, Internet2 and the University of Delaware

All rights reserved.

=cut
