#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
# All rights reserved.
#
package GeniCredential;

#
# Some simple credential stuff.
#
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use GeniResponse;
use GeniCertificate;
use GeniUtil;
use GeniXML;
use GeniHRN;
use English;
use XML::Simple;
use XML::LibXML;
use Data::Dumper;
use File::Temp qw(tempfile);
use Date::Parse;
use POSIX qw(strftime);
use Time::Local;
use overload ('""' => 'Stringify');

# Exported variables
use vars qw(@EXPORT_OK $LOCALSA_FLAG $LOCALCM_FLAG $LOCALMA_FLAG $CHECK_UUID);

# Configure variables
my $BINDIR         = "/usr/local/etc/protogeni";
my $VERIFYCRED     = "$BINDIR/verifygenicred";
my $OPENSSL        = "/usr/bin/openssl";

# Signing flags
$LOCALSA_FLAG      = 1;
$LOCALCM_FLAG      = 2;
$LOCALMA_FLAG      = 3;
$CHECK_UUID        = 1;  # Default to true, enabling uuid checks
@EXPORT_OK         = qw($LOCALSA_FLAG $LOCALCM_FLAG $LOCALMA_FLAG $CHECK_UUID);

# Capability Flags.

  
#
# Create an unsigned credential object.
#
sub Create($$$)
{
    my ($class, $target, $owner) = @_;

    return undef
        if (! (ref($target) && ref($owner)));

    my $self = {};
    $self->{'uuid'}          = undef;
    $self->{'valid_until'}   = $target->expires();
    $self->{'target_uuid'}   = $target->uuid();
    $self->{'owner_uuid'}    = $owner->uuid();
    # Convenience stuff.
    $self->{'target_cert'}   = $target->GetCertificate();
    $self->{'owner_cert'}    = $owner->GetCertificate();
    $self->{'string'}        = undef;
    $self->{'capabilities'}  = undef;
    $self->{'extensions'}    = undef;
    $self->{'idx'}           = undef;   # Only set when stored to DB.
    bless($self, $class);

    return $self;
}
# accessors
sub field($$)           { return ($_[0]->{$_[1]}); }
sub idx($)              { return field($_[0], "idx"); }
sub uuid($)             { return field($_[0], "uuid"); }
sub expires($)          { return field($_[0], "valid_until"); }
sub target_uuid($)      { return field($_[0], "target_uuid"); }
sub slice_uuid($)       { return field($_[0], "target_uuid"); }
sub owner_uuid($)       { return field($_[0], "owner_uuid"); }
sub asString($)         { return field($_[0], "string"); }
sub capabilities($)     { return field($_[0], "capabilities"); }
sub extensions($)       { return field($_[0], "extensions"); }
sub owner_cert($)       { return $_[0]->{"owner_cert"}; }
sub target_cert($)      { return $_[0]->{"target_cert"}; }
sub hrn($)              { return $_[0]->{"target_cert"}->hrn(); }
sub target_urn($)       { return $_[0]->{"target_cert"}->urn(); }
sub owner_urn($)        { return $_[0]->{"owner_cert"}->urn(); }

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $target_uuid = $self->target_uuid();
    my $owner_uuid  = $self->owner_uuid();

    return "[GeniCredential: $target_uuid, $owner_uuid]";
}

#
# Add a capability to the array.
#
sub AddCapability($$$)
{
    my ($self, $name, $delegate) = @_;

    return -1
        if (!ref($self));

    if (!defined($self->capabilities())) {
        $self->{'capabilities'} = {};
    }
    $self->{'capabilities'}->{$name} = {"can_delegate" => $delegate};
    return 0;
}

#
# Add an extension. Each extension is an xml element.
# If the element is in a different namespace it has to be specified
# during element construction.
# It also accepts key/value pairs. When key/value pair is specified
# It converts them to <key>value</key> xml element and 
# adds under extensions.
sub AddExtension
{
    my $self = shift;
    my $elem = undef;
    return -1
              if (!ref($self));
    if (@_ == 1) {
        # it means xml element is specified.
        $elem = shift;
    }
    elsif (@_ == 2) {
        # it means key/value pair is specified.
        $elem = XML::LibXML::Element->new($_[0]);
        $elem->appendText($_[1]);
    }
    else {
        return -1;
    }
    
    my $root = $self->extensions();
    $root = XML::LibXML::Element->new("extensions")
    if (!defined($root));
    $root->appendChild($elem);
    $self->{'extensions'} = $root;
    return 0;
}

#
# Convenience function; create a signed credential for the target,
# issued to the provided user.
#
sub CreateSigned($$$;$)
{
    my ($class, $target, $owner, $signer) = @_;

    return undef
        if (! (ref($target) && ref($owner)));

    $signer = $target->GetCertificate()
        if (!defined($signer));

    my $credential = GeniCredential->Create($target, $owner);
    if (!defined($credential)) {
        print STDERR "Could not create credential for $target, $owner\n";
        return undef;
    }
    if ($credential->Sign($signer) != 0) {
        $credential->Delete();
        print STDERR "Could not sign credential for $target, $owner\n";
        return undef;
    }
    return $credential;
}

#
# Create a credential object from a signed credential string.
#
sub CreateFromSigned($$;$)
{
    my ($class, $string, $nosig) = @_;

    #
    # This flag is used to avoid verifying the signature since I do not
    # really care if the component gives me a bad ticket; I am not using
    # it locally, just passing it back to the component at some point.
    #
    $nosig = 0
        if (!defined($nosig));

    # First verify the credential
    if (! $nosig) {
        my ($fh, $filename) = tempfile(UNLINK => 0);
        return undef
            if (!defined($fh));
        print $fh $string;
        close($fh);
        system("$VERIFYCRED $filename");
        if ($?) {
            print STDERR "Credential in $filename did not verify\n";
            return undef;
        }
        unlink($filename);
    }

    # Use XML::LibXML to convert to something we can mess with.
    my $parser = XML::LibXML->new;
    my $doc;
    eval {
        $doc = $parser->parse_string($string);
    };
    if ($@) {
        print STDERR "Failed to parse credential string: $@\n";
        return undef;
    }
    my $root = $doc->documentElement();

    # Dig out the extensions
    # now extensions is an xml element.
    my ($extensions) = GeniXML::FindNodes('//n:extensions', 
                        $root)->get_nodelist;
    
    # UUID of the credential.
    my ($uuid_node) = $doc->getElementsByTagName("uuid");
    return undef
        if (!defined($uuid_node));
    my $this_uuid = $uuid_node->to_literal();

    if (! ($this_uuid =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/) && $CHECK_UUID) {
        print STDERR "Invalid this_uuid in credential\n";
        return undef;
    }

    # Expiration
    my ($expires_node) = $doc->getElementsByTagName("expires");
    if (!defined($expires_node)) {
        print STDERR "Credential is missing expires node\n";
        return undef;
    }
    my $expires = $expires_node->to_literal();

    if (! ($expires =~ /^[-\w:.\/]+/)) {
        print STDERR "Invalid expires date in credential\n";
        return undef;
    }
    # Convert to a localtime.
    my $when = timegm(strptime($expires));
    if (!defined($when)) {
        print STDERR "Could not parse expires: '$expires'\n";
        return undef;
    }
    $expires = POSIX::strftime("20%y-%m-%dT%H:%M:%S", localtime($when));

    # Dig out the target certificate.
    my ($cert_node) = $doc->getElementsByTagName("target_gid");
    return undef
        if (!defined($cert_node));
    my $target_certificate =
        GeniCertificate->LoadFromString($cert_node->to_literal());
    return undef
        if (!defined($target_certificate));

    if (!($target_certificate->uuid() =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/)
        && $CHECK_UUID) {
        print STDERR "Invalid target_uuid in credential\n";
        return undef;
    }
    if (!($target_certificate->hrn() =~ /^[-\w\.]+$/)) {
        my $hrn = $target_certificate->hrn();
        print STDERR "Invalid hrn $hrn in target of credential\n";
        return undef;
    }
    if (!GeniHRN::IsValid($target_certificate->urn())) {
        print STDERR "Invalid urn in target certificate of credential\n";
        return undef;
    }

    # Dig out the owner certificate.
    ($cert_node) = $doc->getElementsByTagName("owner_gid");
    return undef
        if (!defined($cert_node));

    my $owner_certificate =
        GeniCertificate->LoadFromString($cert_node->to_literal());
    return undef
        if (!defined($owner_certificate));

    if (!($owner_certificate->uuid() =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/)
        && $CHECK_UUID) {
        print STDERR "Invalid target_uuid in credential\n";
        return undef;
    }
    if (!($owner_certificate->hrn() =~ /^[-\w\.]+$/)) {
        my $hrn = $owner_certificate->hrn();
        print STDERR "Invalid hrn $hrn in owner of credential\n";
        return undef;
    }
    if (!GeniHRN::IsValid($owner_certificate->urn())) {
        print STDERR "Invalid urn in owner certificate of credential\n";
        return undef;
    }

    my $self = {};
    $self->{'capabilities'}  = undef;
    $self->{'extensions'}    = $extensions;
    $self->{'uuid'}          = $this_uuid;
    $self->{'valid_until'}   = $expires;
    $self->{'target_uuid'}   = $target_certificate->uuid();
    $self->{'target_cert'}   = $target_certificate;
    $self->{'owner_uuid'}    = $owner_certificate->uuid();
    $self->{'owner_cert'}    = $owner_certificate;
    $self->{'string'}        = $string;
    $self->{'idx'}           = undef;   # Only set when stored to DB.
    bless($self, $class);

    # Dig out the capabilities
    foreach my $cap (GeniXML::FindNodes('.//n:privileges/n:privilege',
                                         $root)->get_nodelist()) {
        my $name = GeniXML::FindElement('n:name', $cap);
        my $delegate = GeniXML::FindElement('n:can_delegate', $cap);
        if (defined($name) && defined($delegate)) {
            $self->AddCapability($name->textContent(),
                                 $delegate->textContent());
        }
    }

    return $self;
}

# Returns a NodeList for a given XPath using a given node as
# context. 'n' is defined to be the prefix for the namespace of the
# node.
#sub findnodes_n($$)
#{
#    my ($path, $node) = @_;
#    my $xc = XML::LibXML::XPathContext->new();
#    my $ns = $node->namespaceURI();
#    if (defined($ns)) {
#       $xc->registerNs('ns', $node->namespaceURI());
#    } else {
#       $path =~ s/\bn://g;
#    }
#    return $xc->findnodes($path, $node);
#}

# Returns the first Node which matches a given XPath against a given
# node. Works like findnodes_n.
#sub findfirst_n($$)
#{
#    my ($path, $node) = @_;
#    return findnodes_n($path, $node)->pop();
#}

sub HasPrivilege($$)
{
    my ( $self, $p ) = @_;

    return 0
        if( !defined( $self->{ 'capabilities' } ) );

    return 1
        if( defined( $self->{ 'capabilities' }->{ "*" } ) );

    return defined( $self->{ 'capabilities' }->{ $p } );
}

sub IsSliceCredential($) {
    my $self = shift;
    
    my ($authority, $type, $id) = GeniHRN::Parse($self->target_urn());
    
    return $type eq 'slice';
}

sub CheckCredential($)
{
    my $credstr = shift;
    
    my $credential = GeniCredential->CreateFromSigned($credstr);
    if (!defined($credential)) {
        return GeniResponse->Create(GENIRESPONSE_ERROR, undef,
                                    "Could not create credential object");
    }
    #
    # Well formed credentials must now have URNs.
    #
    return GeniResponse->Create(GENIRESPONSE_ERROR, undef,
                                "Malformed credentials; missing URNs")
        if (! (defined($credential->owner_urn()) &&
               defined($credential->target_urn()) &&
               GeniHRN::IsValid($credential->owner_urn()) &&
               GeniHRN::IsValid($credential->target_urn())));
        
    #
    # Make sure the credential was issued to the caller.
    #
    if ($credential->owner_urn() ne $ENV{'GENIURN'}) {
        return GeniResponse->Create(GENIRESPONSE_FORBIDDEN, undef,
                                    "This is not your credential");
    }
    
    #
    # Make sure the credential hasn't expired.
    #
    if (timelocal(strptime($credential->expires())) < time()) {
        return GeniResponse->Create(GENIRESPONSE_ERROR, undef,
                                    "Credential expired");
    }
    
    return $credential;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
