#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
# All rights reserved.
#
package LAMP;

#
# The server side of the SA interface. The SA is really just a registry,
# in our case mediated by Emulab.
#
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use lib '/usr/testbed/lib';
use Genixmlrpc;
use GeniResponse;
use GeniCredential;
use GeniCertificate;
use GeniHRN;
use English;
use XML::Simple;
use Date::Parse;
use POSIX qw(strftime);
use Time::Local;

# Configure variables
my $TB            = "/usr/testbed";

my $API_VERSION = 1;

sub GetCertificate($) {
    my $arrayref = shift;
    my $argref   = $arrayref->[0];
    
    my $cred;
    if ( ref $argref->{'credential'} eq "ARRAY" ) {
        ( $cred ) = @{ $argref->{'credential'} };
    } else {
        $cred = $argref->{'credential'};
    }
    
    my $credential = GeniCredential::CheckCredential( $cred );
    
    return $credential
      if ( GeniResponse::IsResponse($credential) );
    
    return GeniResponse->Create( GENIRESPONSE_ERROR, undef,
        "Not a slice credential" ) unless $credential->IsSliceCredential();
    
    my $expiration = strftime( "%y%m%d%H%M%SZ", localtime( str2time( $credential->expires() ) ) );
    
    my ( $auth, $type, $slice ) = GeniHRN::Parse( $credential->target_urn() );
    
    my $urn = GeniHRN::Generate( $auth, "service", "lamp\@" . $slice );

    my $hrn = "lamp.$slice.$auth";
    
    #
    # Generate a certificate (and uuid) for this new slice.
    #
    my $certificate =
      GeniCertificate->Create( "service", $expiration, $urn, $hrn );
    if ( !defined($certificate) ) {
        print STDERR "Could not create new certificate for slice\n";
        return GeniResponse->Create(GENIRESPONSE_ERROR);
    }
    
    return GeniResponse->Create( GENIRESPONSE_SUCCESS,
            $certificate->asString() );
}

# _Always_ make sure that this 1 is at the end of the file...
1;
