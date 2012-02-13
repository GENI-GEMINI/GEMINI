#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
# All rights reserved.
#
package ProtoGENI::GeniUtil;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw(NewUUID GENI_PURGEFLAG FindHostname);

use English;
use Data::Dumper;
use XML::Simple;
use ProtoGENI::GeniHRN;

# Configure variables
my $UUIDGEN	       = "/usr/bin/uuidgen";
my $user	       = "geniuser";
my $group              = "GeniSlices";

use vars qw($EXTENSIONS_NS $XSI_NS $EXTENSIONS_PREFIX $EXTENSIONS_SCHEMA_LOCATION $CREDENTIAL_SCHEMA_LOCATION);
#Extensions namespace URI.
$EXTENSIONS_NS = "http://www.protogeni.net/resources/credential/ext/policy/1";
$XSI_NS = "http://www.w3.org/2001/XMLSchema-instance";
$EXTENSIONS_PREFIX = "policyExt";
$EXTENSIONS_SCHEMA_LOCATION = "http://www.protogeni.net/resources/credential/ext/policy/1/policy.xsd"; 
$CREDENTIAL_SCHEMA_LOCATION = "http://www.protogeni.net/resources/credential/credential.xsd";

sub GENI_PURGEFLAG()	{ return 1; }

#
# In the prototype, we accept certificate signed by trusted roots (CA
# certs we have locally cached). Scripts runs as "geniuser" so that
# there is an emulab user context, or many of the scripts we invoke
# will complain and croak.
#
sub FlipToGeniUser()
{
    my $unix_uid = getpwnam("$user") or
	die("*** $0:\n".
	    "    No such user $user\n");
    my $unix_gid = getgrnam("$group") or
	die("*** $0:\n".
	    "    No such group $group\n");

    $GID            = $unix_gid;
    $EGID           = "$unix_gid $unix_gid";
    $EUID = $UID    = $unix_uid;
    $ENV{'USER'}    = $user;
    $ENV{'LOGNAME'} = $user;
    return 0;
}

#
# Store up the list of caches to flush
#
my @ourcaches = ();

sub AddCache($)
{
    my ($ref) = @_;

    push(@ourcaches, $ref);
}
sub FlushCaches()
{
    foreach my $ref (@ourcaches) {
	%$ref = ();
    }
}

#
# Get me a UUID (universally unique identifier). Its really nice that there
# is a program that does this! They look like this:
#
#	047edb7b-d346-11db-96cb-001143e453fe
#
sub NewUUID()
{
    my $uuid = `$UUIDGEN`;

    if ($uuid =~ /^(\w{8}\-\w{4}\-\w{4}\-\w{4}\-\w{12})$/) {
	return $1;
    }
    return undef;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
