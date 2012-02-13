#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2009 University of Utah and the Flux Group.
# All rights reserved.
#
# Perl code to access an XMLRPC server using http. Derived from the
# Emulab library (pretty sure Dave wrote the http code in that file,
# and I'm just stealing it).
#
package ProtoGENI::GeniResponse;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA    = "Exporter";
@EXPORT = qw (GENIRESPONSE_SUCCESS GENIRESPONSE_BADARGS GENIRESPONSE_ERROR
	      GENIRESPONSE_FORBIDDEN GENIRESPONSE_BADVERSION
	      GENIRESPONSE_SERVERERROR
	      GENIRESPONSE_TOOBIG GENIRESPONSE_REFUSED
	      GENIRESPONSE_TIMEDOUT GENIRESPONSE_DBERROR
	      GENIRESPONSE_RPCERROR GENIRESPONSE_UNAVAILABLE
	      GENIRESPONSE_SEARCHFAILED GENIRESPONSE_UNSUPPORTED
	      GENIRESPONSE_BUSY GENIRESPONSE_EXPIRED GENIRESPONSE_INPROGRESS
	      GENIRESPONSE);

use overload ('""' => 'Stringify');
my $current_response = undef;

#
# GENI XMLRPC defs. Also see ../lib/Protogeni.pm.in if you change this.
#
sub GENIRESPONSE_SUCCESS()        { 0; }
sub GENIRESPONSE_BADARGS()        { 1; }
sub GENIRESPONSE_ERROR()          { 2; }
sub GENIRESPONSE_FORBIDDEN()      { 3; }
sub GENIRESPONSE_BADVERSION()     { 4; }
sub GENIRESPONSE_SERVERERROR()    { 5; }
sub GENIRESPONSE_TOOBIG()         { 6; }
sub GENIRESPONSE_REFUSED()        { 7; }
sub GENIRESPONSE_TIMEDOUT()       { 8; }
sub GENIRESPONSE_DBERROR()        { 9; }
sub GENIRESPONSE_RPCERROR()       {10; }
sub GENIRESPONSE_UNAVAILABLE()    {11; }
sub GENIRESPONSE_SEARCHFAILED()   {12; }
sub GENIRESPONSE_UNSUPPORTED()    {13; }
sub GENIRESPONSE_BUSY()           {14; }
sub GENIRESPONSE_EXPIRED()        {15; }
sub GENIRESPONSE_INPROGRESS()     {16; }
sub GENIRESPONSE()		  { return $current_response; }

my @GENIRESPONSE_STRINGS =
    (
     "Success",
     "Bad Arguments",
     "Error",
     "Operation Forbidden",
     "Bad Version",
     "Server Error",
     "Too Big",
     "Operation Refused",
     "Operation Times Out",
     "Database Error",
     "RPC Error",
     "Unavailable",
     "Search Failed",
     "Operation Unsupported",
     "Busy",
     "Expired",
     "In Progress",
    );

#
# This is the (python-style) "structure" we want to return.
#
# class Response:
#    def __init__(self, code, value=0, output=""):
#        self.code     = code            # A RESPONSE code
#        self.value    = value           # A return value; any valid XML type.
#        self.output   = output          # Pithy output to print
#        return
#
# For debugging, stash the method and arguments in case we want to
# print things out.
#
sub new($$;$$)
{
    my ($class, $code, $value, $output) = @_;

    $output = ""
	if (!defined($output));
    $value = 0
	if (!defined($value));

    my $self = {"code"      => $code,
		"value"     => $value,
		"output"    => $output};
    bless($self, $class);
    return $self;
}

sub Create($$;$$)
{
    my ($class, $code, $value, $output) = @_;

    $output = ""
	if (!defined($output));
    $value = 0
	if (!defined($value));

    my $self = {"code"   => $code,
		"value"  => $value,
		"output" => $output};

    $current_response = $self;
    return $self;
}

# accessors
sub field($$)           { return ($_[0]->{$_[1]}); }
sub code($)		{ return field($_[0], "code"); }
sub value($)		{ return field($_[0], "value"); }
sub output($)		{ return field($_[0], "output"); }

# Check for response object. Very bad, but the XML encoder does not
# allow me to intercept the encoding operation on a blessed object.
sub IsResponse($)
{
    my ($arg) = @_;
    
    return (ref($arg) eq "HASH" &&
	    exists($arg->{'code'}) && exists($arg->{'value'}));
}
sub IsError($)
{
    my ($arg) = @_;

    if (ref($arg) eq "GeniResponse") {
	return $arg->code() ne GENIRESPONSE_SUCCESS;
    }
    return (ref($arg) eq "HASH" &&
	    exists($arg->{'code'}) && exists($arg->{'value'}) &&
	    $arg->{'code'} ne GENIRESPONSE_SUCCESS);
}

sub Dump($)
{
    my ($self) = @_;
    
    my $code   = $self->code();
    my $value  = $self->value();
    my $string = $GENIRESPONSE_STRINGS[$code] || "Unknown";
    my $output;

    $output = $self->output()
	if (defined($self->output()) && $self->output() ne "");

    return "code:$code ($string), value:$value" .
	(defined($output) ? ", output:$output" : "");
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $code   = $self->code();
    my $value  = $self->value();
    my $string = $GENIRESPONSE_STRINGS[$code] || "Unknown";

    return "[GeniResponse: code:$code ($string), value:$value]";
}

sub MalformedArgsResponse($;$)
{
    my (undef,$msg) = @_;
    my $saywhat = "Malformed arguments";
    
    $saywhat .= ": $msg"
	if (defined($msg));

    return ProtoGENI::GeniResponse->Create(GENIRESPONSE_BADARGS, undef, $saywhat);
}

sub BusyResponse($;$)
{
    my (undef,$resource) = @_;

    $resource = "resource"
	if (!defined($resource));
    
    return ProtoGENI::GeniResponse->Create(GENIRESPONSE_BUSY,
				undef, "$resource is busy; try again later");
}

sub BadArgsResponse(;$)
{
    my ($msg) = @_;

    $msg = "Bad arguments to method"
	if (!defined($msg));
    
    return ProtoGENI::GeniResponse->Create(GENIRESPONSE_BADARGS, undef, $msg);
}

# _Always_ make sure that this 1 is at the end of the file...
1;
