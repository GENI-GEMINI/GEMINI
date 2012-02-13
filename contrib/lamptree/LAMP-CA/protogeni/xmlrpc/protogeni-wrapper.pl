#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
# All rights reserved.
#

#
# Simple CGI interface to the GENI xmlrpc interface. This script is invoked
# from the web server. The certificate information is in the environment
# set up by apache.
#
use strict;
use English;
use Frontier::Responder;
use Frontier::RPC2;
use Data::Dumper;
use POSIX;
use Crypt::X509;
use Crypt::OpenSSL::X509;

# Yack. apache does not close fds before the exec, and if this dies
# we are left with a giant mess.
BEGIN {
    no warnings;
    for (my $i = 3; $i < 1024; $i++) {
      POSIX:close($i);
    }
}

# Configure variables
my $MAINSITE 	   = 0;
my $TBOPS          = "root\@localhost";
my $MODULE;
my $GENIURN;

# Testbed libraries.
use lib '/usr/testbed/lib';
use Genixmlrpc;
use GeniResponse;
use LAMP;

# Need a command line option.
my $debug      = 0;
my $mailerrors = 1;

# Determined by version.
my $responder;

#
# Turn off line buffering on output
#
$| = 1;

#
# Untaint the path
#
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

#
# Helper function to return a properly formated XML error.
#
sub XMLError($$)
{
    my ($code, $string) = @_;

    my $decoder = Frontier::RPC2->new();
    print "Content-Type: text/xml \n\n";
    print $decoder->encode_fault($code, $string);
    exit(0);
}

#
# Make sure the client presented a valid certificate that apache says
# is okay.
#
# THIS HAS TO BE HERE! Why? Cause recent security patches disable SSL
# renegotiation, which is needed when a subdir turns on ssl client
# verification (as httpd.conf used to). Now, we set it to "optional",
# which avoids the renegotiation problem, but we have to make that
# this interface is always invoked by a client supplying a verifiable
# certificate. 
#
if (! (exists($ENV{'SSL_CLIENT_VERIFY'}) &&
       $ENV{'SSL_CLIENT_VERIFY'} eq "SUCCESS")) {
    XMLError(-1, "Invalid or missing certificate");
}

#
# The UUID of the client certificate is in the env var SSL_CLIENT_S_DN_CN.
# If it actually looks like a UUID, then this correponds to an actual user,
# and the supplied credentials/tickets must match. At present, if there is
# no UUID, it is another emulab making a request directly, with no user
# context, and we just let that pass for now.
#
if (exists($ENV{'SSL_CLIENT_S_DN_CN'}) &&
    $ENV{'SSL_CLIENT_S_DN_CN'} =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/) {
    $ENV{'GENIUSER'} = $ENV{'SSL_CLIENT_S_DN_CN'};
    $ENV{'GENIUUID'} = $ENV{'SSL_CLIENT_S_DN_CN'};
}
else {
    XMLError(-1, "Invalid certificate; no UUID");
}

#
# The CERT data from apache holds the URN of the caller. 
#
if (exists($ENV{'SSL_CLIENT_CERT'})) {
    my $x509 = eval {
	Crypt::OpenSSL::X509->new_from_string($ENV{'SSL_CLIENT_CERT'}); };
    if ($@) {
	XMLError(-1, "Invalid certificate: $@");
    }
    my $cert = $x509->as_string(Crypt::OpenSSL::X509::FORMAT_ASN1);
    XMLError(-1, "Could not convert certificate to ASN1")
	if (!defined($cert) || $cert eq '');
    my $decoded = Crypt::X509->new( cert => $cert );
    if ($decoded->error) {
	XMLError(-1, "Error decoding certificate:" . $decoded->error);
    }
    foreach my $tmp (@{ $decoded->SubjectAltName }) {
	if ($tmp =~ /^uniformResourceIdentifier=(.*)$/ ||
	    $tmp =~ /^(urn:.*)$/) {
	    $GENIURN = $ENV{'GENIURN'} = $1;
	}
    }
}
XMLError(-1, "Invalid authentication certificate; no URN. Please regenerate.")
    if (!exists($ENV{'GENIURN'}));

#
# Reaching into the Frontier code so I can debug this crap.
#
my $request = Frontier::Responder::get_cgi_request();
if (!defined($request)) {
    print "Content-Type: text/txt\n\n";
    exit(0);
}

#
# This is lifted from the Frontier code. I want the actual response
# object, not the XML. 
#
my $decoder   = Frontier::RPC2->new();
my $call;
my $response;

$request =~ s/(<\?XML\s+VERSION)/\L$1\E/;
eval { $call = $decoder->decode($request) };
if ($@) {
    XMLError(1, "error decoding RPC:\n" . $@);
}
if ($call->{'type'} ne 'call') {
    XMLError(1, "expected RPC methodCall, got $call->{'type'}");
}
my $method = $call->{'method_name'};
unless ( $method eq "GetLAMPSliceCertificate" ) {
    XMLError(3, "no such method $method\n");
}

my $result;
my $message =
    "URN:     $GENIURN\n".
    "Module:  LAMP\n".
    "Method:  $method\n";
    
eval { $result = LAMP::GetCertificate( $call->{'value'} ) };
if ($@) {
    #
    # These errors should get mailed to tbops.
    #
    print STDERR "Error executing RPC method $method:\n" . $@ . "\n";
    $response = $decoder->encode_fault(4, "Internal Error executing $method");
}
else {
    if (GeniResponse::IsError($result)) {
	$message .= "Error:   " . $result->{'code'} . "\n";
    }
    else {
	$message .= "Code:    " . $result->{'code'} . "\n";
    }
    $message .= "Output:  " . $result->{'output'} . "\n"
	if (defined($result->{'output'}));

    $message .= "Result:\n"  . Dumper($result->{'value'}) . "\n\n";
    $message .= "Request:\n" . $request . "\n";
    
    $response = $decoder->encode_response($result);
}

if ($debug) {
    print STDERR "Debugging is on.\n";
}

print "Content-Type: text/xml \n\n" . $response;
exit(0);

#
# Want to prevent bad exit.
#
END {
    my $exitcode = $?;

    if ($exitcode) {
	my $decoder = Frontier::RPC2->new();
	print "Content-Type: text/xml \n\n";
	print $decoder->encode_fault(-2, "XMLRPC Server Error");

	# Since we converted to a normal error and sent the log message.
	$? = 0;
    }
}

