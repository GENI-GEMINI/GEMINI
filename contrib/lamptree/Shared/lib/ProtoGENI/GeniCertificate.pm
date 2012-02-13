#!/usr/bin/perl -w
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
# All rights reserved.
#
package ProtoGENI::GeniCertificate;

#
# Some simple certificate stuff.
#
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

# Must come after package declaration!
use English;
use XML::Simple;
use XML::LibXML;
use Data::Dumper;
use File::Temp qw(tempfile);
use overload ('""' => 'Stringify');

# Configure variables
my $BINDIR         = "/usr/local/etc/protogeni";
my $SIGNCRED	   = "$BINDIR/signgenicred";
my $VERIFYCRED	   = "$BINDIR/verifygenicred";
my $OPENSSL	   = "/usr/bin/openssl";
my $MKCERT         = "$BINDIR/mksyscert";

# Cache of instances to avoid regenerating them.
my %certificates  = ();
BEGIN { use ProtoGENI::GeniUtil; ProtoGENI::GeniUtil::AddCache(\%certificates); }

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $uuid = $self->uuid();
    my $hrn  = $self->hrn();

    return "[GeniCertificate: $uuid, $hrn]";
}

# accessors
sub field($$) { return ((! ref($_[0])) ? -1 : $_[0]->{'CERT'}->{$_[1]}); }
sub uuid($)		{ return field($_[0], "uuid"); }
# This will always be undefined, but we need the method.
sub expires($)		{ return undef; }
sub created($)		{ return field($_[0], "created"); }
sub cert($)		{ return field($_[0], "cert"); }
sub DN($)		{ return field($_[0], "DN"); }
sub privkey($)		{ return field($_[0], "privkey"); }
sub revoked($)		{ return field($_[0], "revoked"); }
sub certfile($)		{ return field($_[0], "certfile"); }
sub uri($)              { return field($_[0], "uri"); }
sub urn($)              { return field($_[0], "urn"); }
sub GetCertificate($)   { return $_[0]; }

#
# The fields are buried inside the DN.
#
sub hrn($)
{
    my ($self) = @_;

    if ($self->DN() =~ /\/OU=([-\w\.]+)\//) {
	return $1
	    if ($1 ne "");
    }
    # GENI AM compatibility with PlanetLab
    # Use the URN from the Subject Alt Name to create the HRN
    my ($authority, $type, $name) = GeniHRN::Parse($self->urn());
    # Match authority up to the first colon, then add "." and name.
    if ($authority =~ /^([^:]+):/) {
        my $hrn = $1 . "." . $name;
        return $hrn;
    }
    print STDERR "Cannot find hrn inside DN: '" . $self->DN() . "'\n";
    print STDERR "Cannot find hrn inside urn: '" . $self->urn() . "'\n";
    return "unknown";
}
sub email($)
{
    my ($self) = @_;

    if ($self->DN() =~ /\/emailAddress=(.*)/) {
	return $1
	    if ($1 ne "");
    }
    print STDERR "Cannot find email inside DN: '" . $self->DN() . "'\n";
    return "unknown";
}

#
# Create a certificate pair, which gives us a uuid to use for an object.
#
sub Create($$$$$;$$)
{
    my ($class, $what, $urn, $hrn, $email, $uuid, $url) = @_;
    # Let mkcert generate a new one.
    $uuid = ""
	if (!defined($uuid));
    $url  = (defined($url) ? "-u $url" : "");

    if (! open(CERT, "$MKCERT -i \"$urn\" $url -e \"$email\" $hrn $uuid |")) {
	print STDERR "Could not start $MKCERT\n";
	return undef;
    }
    my @certlines = ();
    while (<CERT>) {
	push(@certlines, $_);
    }
    if (!close(CERT)) {
	print STDERR "$MKCERT failed!\n";
	return undef;
    }
    my $cert;
    my $privkey;
    my $string;
    foreach my $line (@certlines) {
	if ($line =~ /^-----BEGIN CERT/ ||
	    $line =~ /^-----BEGIN RSA/) {
	    $string = "";
	    next;
	}
	if ($line =~ /^-----END CERT/) {
	    $cert = $string;
	    $string = undef;
	    next;
	}
	if ($line =~ /^-----END RSA/) {
	    $privkey = $string;
	    $string = undef;
	    next;
	}
	$string .= $line
	    if (defined($string));
    }
    if (! (defined($privkey) && defined($cert))) {
	print STDERR "Could not generate a new certificate with $MKCERT\n";
	foreach my $line (@certlines) {
	    print STDERR $line;
	}
	return undef;
    }
    if (! ($cert =~ /^[\012\015\040-\176]*$/)) {
	print STDERR "Improper chars in certificate string\n";
	foreach my $line (@certlines) {
	    print STDERR $line;
	}
	return undef;
    }

    my $certificate = ProtoGENI::GeniCertificate->LoadFromString($cert);
    return undef
	if (!defined($certificate));

    $certificate->{'CERT'}->{'privkey'} = $privkey;
    if ($certificate->Store() != 0) {
	print STDERR "Could not write new certificate to DB\n";
	return undef;
    }
    return $certificate;
}

#
# Flush from our little cache.
#
sub Flush($)
{
    my ($self) = @_;

    $self->GetCertificate()->Flush();
    delete($certificates{$self->uuid()});
}

#
# Load a certificate from a string. This creates an object, but does
# not store it in the DB.
#
sub LoadFromString($$)
{
    my ($class, $string) = @_;

    if (! ($string =~ /^[\012\015\040-\176]*$/)) {
	print STDERR "Improper chars in certificate string\n";
	return undef;
    }
    my ($tempfile, $filename) = tempfile(UNLINK => 1);
    if (!$tempfile) {
	print STDERR "Could not create tempfile for cert string\n";
	return undef;
    }

    # The certificate might already have the header and footer
    # so only add them if needed.
    if ($string =~ /^-----BEGIN CERTIFICATE-----/) {
        print $tempfile $string;
    } else {
        print $tempfile "-----BEGIN CERTIFICATE-----\n";
        print $tempfile $string;
        print $tempfile "-----END CERTIFICATE-----\n";
    }

    my $certificate = ProtoGENI::GeniCertificate->LoadFromFile($filename);
    unlink($filename);
    return undef
	if (!defined($certificate));
    
    $certificate->{'CERT'}->{'certfile'} = undef;
    return $certificate;
}

#
# Load a certificate from a file. This creates an object, but does
# not store it in the DB.
#
sub LoadFromFile($$)
{
    my ($class, $filename) = @_;
    my $url;
    my $urn;

    if (! open(X509, "$OPENSSL x509 -in $filename -subject -text |")) {
	print STDERR "Could not start $OPENSSL on $filename\n";
	return undef;
    }
    my @certlines = ();
    while (<X509>) {
	push(@certlines, $_);
    }
    if (!close(X509) || !@certlines) {
	print STDERR "Could not load certificate from $filename\n";
	return undef;
    }

    #
    # The first line is the DN (subject).
    #
    my $DN = shift(@certlines);
    chomp($DN);

    #
    # The text output is next. Look for the URL in the extensions. Stop
    # when we get to the certificate line.
    #
    my ($alturi,$accessuri);
    my $altname = 0;
    my $accessinfo = 0;
    while (@certlines) {
	my $line = shift(@certlines);
	last
	    if ($line =~ /^-----BEGIN CERT/);

	if( $line =~ /^\s+X509v3 Subject Alternative Name:\s*$/ ) {
	    $altname = 1;
	} elsif( $line =~ /^\s+Authority Information Access:\s*$/ ) {
	    $accessinfo = 1;
	} elsif( $altname ) {
	    m'^\s*URI:(urn:publicid:[-!#$%()*+,./0-9:;=?@A-Z_a-z~]+)\s*$' and $alturi = $1
		foreach split( /, /, $line );
	    $altname = 0;
	} elsif( $accessinfo ) {
	    m'^\s*[0-9.]+ - URI:([-!#$%()*+,./0-9:;=?@A-Z_a-z~]+)\s*$' 
		and $accessuri = $1 foreach split( /, /, $line );
	    $accessinfo = 0;
	}
    }
    if (!@certlines) {
	print STDERR "Could not parse certificate from $filename\n";
	return undef;
    }

    if( defined( $alturi ) && $alturi =~ /^urn:/ ) {
	$urn = $alturi;
    }

    if( defined( $accessuri ) ) {
	$url = $accessuri;
    } elsif( defined( $alturi ) && $alturi !~ /^urn:/ ) {
	$url = $alturi;
    }

    #
    # Throw away last line; the cert is rest.
    #
    pop(@certlines);
    my $cert = join("", @certlines);

    # Dig out the uuid.
    my $uuid;
    if ($DN =~ /\/CN=([-\w]*)/) {
	$uuid = $1;
    }
    else {
	print STDERR "Could not find uuid in 'DN'\n";
	return undef;
    }
    
    # GENI AM: CN might not be a UUID, so check it.
    # If it is not a UUID, make one up.
    if ($uuid !~ /^\w+\-\w+\-\w+\-\w+\-\w+$/) {
        $uuid = ProtoGENI::GeniUtil::NewUUID();
    }

    my $self          = {};
    $self->{'CERT'}   = {};
    $self->{'stored'} = 0;
    bless($self, $class);

    $self->{'CERT'}->{'uuid'}      = $uuid;
    $self->{'CERT'}->{'cert'}      = $cert;
    $self->{'CERT'}->{'DN'}        = $DN;
    $self->{'CERT'}->{'privkey'}   = undef;
    $self->{'CERT'}->{'revoked'}   = undef;
    $self->{'CERT'}->{'created'}   = undef;
    $self->{'CERT'}->{'certfile'}  = $filename;
    $self->{'CERT'}->{'uri'}       = $url;
    $self->{'CERT'}->{'urn'}       = $urn;
    return $self;
}


#
# Write a certificate and private key to a tempfile, as for signing with it.
#
sub WriteToFile($;$)
{
    my ($self, $withkey) = @_;

    $withkey = 0
	if (!defined($withkey));
    
    # We want this file to be passed back. 
    my ($tempfile, $filename) = tempfile(UNLINK => 1);
    print $tempfile "-----BEGIN CERTIFICATE-----\n";
    print $tempfile $self->cert();
    print $tempfile "-----END CERTIFICATE-----\n";
    if ($withkey && $self->privkey()) {
	print $tempfile "-----BEGIN RSA PRIVATE KEY-----\n";
	print $tempfile $self->privkey();
	print $tempfile "-----END RSA PRIVATE KEY-----\n";
    }
    return $filename;
}

#
# The URL is buried in an extension so we have to parse the text output.
#
sub URL($)
{
    my ($self) = @_;
    my $url    = $self->{'URL'};

    return $url
	if (defined($url));

    my $filename = $self->WriteToFile();
    if (! open(X509, "$OPENSSL x509 -in $filename -text -noout |")) {
	print STDERR "Could not start $OPENSSL on $filename\n";
	return undef;
    }
    # Note that we really want to put only URNs in the subjectAltName,
    # and all URLs in the subjectInfoAccess.  However, old certificates
    # used subjectAltName for URLs, so for temporary backward compatibility
    # we'll look in both places.
    my ($alturl,$accessurl);
    my $altname = 0;
    my $accessinfo = 0;
    while (<X509>) {
	if( /^\s+X509v3 Subject Alternative Name:\s*$/ ) {
	    $altname = 1;
	} elsif( /^\s+Authority Information Access:\s*$/ ) {
	    $accessinfo = 1;
	} elsif( $altname ) {
	    # Gah!  OpenSSL is horrible.  Apparently the text output format
	    # for the subject alternative name is fixed, and neither
	    # -nameopt nor -certopt will help us.  Worse still, the
	    # directory entries (e.g. URI, email) are comma separated...
	    # but commas are legal characters in URIs (see RFC 3986, section
	    # 2.2)!  We'll have to assume the delimiter is the ", " (comma,
	    # space) pair...
	    m'^\s*URI:([-!#$%()*+,./0-9:;=?@A-Z_a-z~]+)\s*$' and $alturl = $1
		foreach split( /, / );
	    $altname = 0;
	} elsif( $accessinfo ) {
	    m'^\s*[0-9.]+ - URI:([-!#$%()*+,./0-9:;=?@A-Z_a-z~]+)\s*$' and $accessurl = $1
		foreach split( /, / );
	    $accessinfo = 0;
	}
    }
    $url = defined( $accessurl ) ? $accessurl : 
	defined( $alturl ) ? $alturl : undef;
    if (!close(X509) || !defined($url)) {
	print STDERR "Could not find url in certificate from $filename\n";
	return undef;
    }
    unlink($filename);
    $self->{'CERT'}->{'uri'} = $url;
    $self->{'URL'} = $url;
    return $url;
}

#
# The URN is slightly easier, since it is always in the same place.
#
sub URN($)
{
    my ($self) = @_;
    my $urn    = $self->{'URN'};

    return $urn
	if (defined($urn));

    my $filename = $self->WriteToFile();
    if (! open(X509, "$OPENSSL x509 -in $filename -text -noout |")) {
	print STDERR "Could not start $OPENSSL on $filename\n";
	return undef;
    }
    my $altname = 0;
    while (<X509>) {
	if( /^\s+X509v3 Subject Alternative Name:\s*$/ ) {
	    $altname = 1;
	} elsif( $altname ) {
	    m'^\s*URI:([-!#$%()*+,./0-9:;=?@A-Z_a-z~]+)\s*$' and $urn = $1
		foreach split( /, / );
	    $altname = 0;
	}
    }
    if (!close(X509) || !defined($urn)) {
	print STDERR "Could not find URN in certificate from $filename\n";
	return undef;
    }
    unlink($filename);
    $self->{'URN'} = $urn;
    return $urn;
}

sub asText($)
{
    my ($self) = @_;
    my $text   = "";

    my $filename = $self->WriteToFile();
    if (! open(X509, "$OPENSSL x509 -in $filename -text |")) {
	print STDERR "Could not start $OPENSSL on $filename\n";
	return undef;
    }
    while (<X509>) {
	$text .= $_;
    }
    if (!close(X509) || $text eq "") {
	print STDERR "Could not dump text of certificate from $filename\n";
	return undef;
    }
    unlink($filename);
    return $text;
}


# _Always_ make sure that this 1 is at the end of the file...
1;
