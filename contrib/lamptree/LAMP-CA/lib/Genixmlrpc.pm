#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
# All rights reserved.
#
# Perl code to access an XMLRPC server using http. Derived from the
# Emulab library (pretty sure Dave wrote the http code in that file,
# and I'm just stealing it).
#
package Genixmlrpc;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA    = "Exporter";
@EXPORT = qw();

# Must come after package declaration.
use English;
use GeniResponse;
#use IO::Socket::SSL;
use RPC::XML;
use RPC::XML::Parser;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTTP::Headers;
use Data::Dumper;

my $debug   = 1;

# Let the caller set a timeout for a call.
my $timeout = 500;

##
# The package version number
#
my $PACKAGE_VERSION = 0.1;

#
# This is the "structure" returned by the RPC server. It gets converted into
# a perl hash by the unmarshaller, and we return that directly to the caller
# (as a reference).
#
# class EmulabResponse:
#    def __init__(self, code, value=0, output=""):
#        self.code     = code            # A RESPONSE code
#        self.value    = value           # A return value; any valid XML type.
#        self.output   = output          # Pithy output to print
#        return
#

#
# This is the context for making rpc calls. Gives the certificate and an
# optional password. The caller hangs onto this and passes it back in below.
#
# class XmlRpcContext:
#    def __init__(self, certificate, keyfile, password=None):
#        self.certificate = certificate
#        self.keyfile     = keyfile
#        self.password    = password
#        return
#
sub Context($$;$$)
{
    my ($class, $certificate, $keyfile, $password) = @_;

    $keyfile = $certificate->certfile()
	if (!defined($keyfile));

    my $self = {"certificate"  => $certificate,
		"certfile"     => $certificate->certfile(),
		"keyfile"      => $keyfile,
		"password"     => $password};
    bless($self, $class);
    return $self;
}

#
# This is a context for a user. Used only on Emulab bossnode. Use the
# Context() routine above on clients.
#
sub UserContext($$)
{
    my ($class, $user) = @_;
    my $password;

    my $pkcs12 = $user->HomeDir() . "/.ssl/encrypted.p12";
    $user->SSLPassPhrase(1, \$password) == 0
	or return undef;

    my $self = {"certificate"  => undef,
		"certfile"     => $pkcs12,
		"keyfile"      => $pkcs12,
		"password"     => $password,
		"user"	       => $user};
    bless($self, $class);
    return $self;
}
# accessors
sub field($$)           { return ($_[0]->{$_[1]}); }
sub certificate($)	{ return field($_[0], "certificate"); }
sub certfile($)		{ return field($_[0], "certfile"); }
sub keyfile($)		{ return field($_[0], "keyfile"); }
sub password($)		{ return field($_[0], "password"); }
sub user($)		{ return field($_[0], "user"); }

#
# Context for making calls.
#
my $MyContext;

# Set the context for subsequent calls made to the clearing house.
#
sub SetContext($$)
{
    my ($class, $context) = @_;

    $MyContext = $context;
    return 0;
}
sub GetContext($)
{
    my ($class) = @_;

    return $MyContext;
}
sub SetTimeout($$)
{
    my ($class, $to) = @_;

    $timeout = $to;
    return 0;
}

#
# Call to a non-Emulab xmlrpc server.  
# If there was an HTTP error, the hash also contains the keys
# httpcode and httpmsg.
#
sub CallMethod($$$@)
{
    my ($httpURL, $context, $method, @args) = @_;

    # Default context if not set.
    $context = $MyContext
	if (!defined($context));

    # But must have a context;
    if (!defined($context)) {
	print STDERR "Must provide an rpc context\n";	
	return GeniResponse->new(GENIRESPONSE_RPCERROR, -1,
				 "Must provide an rpc context");
    }

    if (0) {
	#
	# This does not work. Not sure why, but need to figure it out
	# cause it does cert chains while Crypt::SSL (below) does not. 
	#
	$IO::Socket::SSL::DEBUG = 4;
	$Net::SSLeay::slowly = 1;
	
	$IO::Socket::SSL::GLOBAL_CONTEXT_ARGS->{'SSL_key_file'} =
	    $context->keyfile();	    
	$IO::Socket::SSL::GLOBAL_CONTEXT_ARGS->{'SSL_cert_file'} =
	    $context->certfile();	    
	$IO::Socket::SSL::GLOBAL_CONTEXT_ARGS->{'SSL_use_cert'} = 1;

	#
	# If we have a passphrase in the context, then provide a callback
	# to hand it back. Otherwise the user gets prompted for it.
	#
	if (defined($context->password())) {
	    $IO::Socket::SSL::GLOBAL_CONTEXT_ARGS->{'SSL_passwd_cb'} =
		sub { return $context->password(); };
	}
    }
    else {
	#
	# This is for the Crypt::SSL library, many levels down. It
	# appears to be the only way to specify this. Even worse, when
	# we want to use an encrypted key belonging to a user, have to
	# use the pkcs12 format of the file, since that is the only
	# format for which we can provide the passphrase.
	#
	if (!defined($context->password())) {
	    $ENV{'HTTPS_CERT_FILE'} = $context->certfile();
	    $ENV{'HTTPS_KEY_FILE'}  = $context->keyfile();
	}
	else {
	    $ENV{'HTTPS_PKCS12_FILE'}     = $context->certfile();
	    $ENV{'HTTPS_PKCS12_PASSWORD'} = $context->password();
	}
    }
    my $request = new RPC::XML::request($method, @args);
    if ($debug > 1) {
	print STDERR "xml request: $httpURL:" . $request->as_string();
	print STDERR "\n";
    }

    #
    # Send an http post.
    #
    my $reqstr = $request->as_string();
    my $ua = LWP::UserAgent->new();
    $ua->timeout($timeout)
	if ($timeout > 0);
    my $hreq = HTTP::Request->new(POST => $httpURL);
    $hreq->content_type('text/xml');
    $hreq->content($reqstr);
    my $hresp = $ua->request($hreq);

    # Do this or the next call gets messed up.
    delete($ENV{'HTTPS_CERT_FILE'});
    delete($ENV{'HTTPS_KEY_FILE'});
    delete($ENV{'HTTPS_PKCS12_FILE'});
    delete($ENV{'HTTPS_PKCS12_PASSWORD'});
    
    if ($debug > 1 || ($debug && !$hresp->is_success())) {
	print STDERR "xml response: " . $hresp->as_string();
	print STDERR "\n";
    }
    
    if (!$hresp->is_success()) {
	return GeniResponse->new(GENIRESPONSE_RPCERROR,
				 $hresp->code(), $hresp->message());
    }

    #
    # Read back the xmlgoo from the child.
    #
    my $xmlgoo = $hresp->content();

    if ($debug > 1) {
	print STDERR "xmlgoo: " . $xmlgoo;
	print STDERR "\n";
    }

    #
    # Convert the xmlgoo to Perl and return it.
    #
    my $parser   = RPC::XML::Parser->new();
    my $goo      = $parser->parse($xmlgoo);
    my ($value,$output,$code);

    #print Dumper($goo);
    
    # Python servers seem to return faults in structs, not as <fault> elements.
    # Sigh.
    if (!ref($goo)) {
        print STDERR "Error in XMLRPC parse: $goo\n";
        return undef;
    }
    elsif ($goo->value()->is_fault() 
	|| (ref($goo->value()) && UNIVERSAL::isa($goo->value(),"HASH") 
	    && exists($goo->value()->{'faultCode'}))) {
	$code   = GENIRESPONSE_RPCERROR();
	$value  = $goo->value()->{"faultCode"}->value;
	$output = $goo->value()->{"faultString"}->value;
    }
    else {
	$code   = $goo->value()->{'code'}->value;
	$value  = $goo->value()->{'value'}->value;
	$output = $goo->value()->{'output'}->value;
    }
    if ($debug > 1 && $code) {
	print STDERR "CallMethod: $method failed: $code";
	print STDERR ", $output\n" if (defined($output) && $output ne "");
    }
    return GeniResponse->new($code, $value, $output);

}

# _Always_ make sure that this 1 is at the end of the file...
1;
