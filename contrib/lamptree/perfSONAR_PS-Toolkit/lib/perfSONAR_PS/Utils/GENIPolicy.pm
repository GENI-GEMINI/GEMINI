package perfSONAR_PS::Utils::GENIPolicy;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw( verify_cgi );

use Crypt::X509;
use Crypt::OpenSSL::X509;

our %defaults = (
    valid_peers_file => "/usr/local/etc/protogeni/ssl/valid_peers",
);

sub verify_cgi {
    my ( $conf ) = @_;
    
    my $VALID_PEERS_FILE;
    my %valid_peers = ();
    
    # ssl_verify_peers = 1 is default
    return 0 if $conf and exists $conf->{ssl_verify_peers} and not $conf->{ssl_verify_peers};
    
    if ( $conf and exists $conf->{"ssl_valid_peers_file"} and $conf->{"ssl_valid_peers_file"} ) {
         $VALID_PEERS_FILE = $conf->{"ssl_valid_peers_file"};
    }
    else {
        $VALID_PEERS_FILE = $defaults{valid_peers_file};
    }
    
    if ( -e $VALID_PEERS_FILE ) {
        open( VALIDPEERS, "< $VALID_PEERS_FILE" ) or die $!;
        for my $line ( <VALIDPEERS> ) {
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            next if !$line or $line =~ /^#/;
            
            $valid_peers{$line} = 1;
        }
        close( VALIDPEERS ) or die $!;
    } 
    else {
        # Be conservative and die.
        print "Error: Not able to find the valid_peers file at $VALID_PEERS_FILE.\n";
        exit( -1 );
    }
    
    if (! (exists($ENV{'SSL_CLIENT_VERIFY'}) &&
           $ENV{'SSL_CLIENT_VERIFY'} eq "SUCCESS")) {
        die "Invalid or missing certificate";
    }
    
    if (exists($ENV{'SSL_CLIENT_S_DN_CN'}) &&
        $ENV{'SSL_CLIENT_S_DN_CN'} =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/) {
        $ENV{'GENIUSER'} = $ENV{'SSL_CLIENT_S_DN_CN'};
        $ENV{'GENIUUID'} = $ENV{'SSL_CLIENT_S_DN_CN'};
    }
    else {
        die "Invalid certificate; no UUID";
    }
    
    my $GENIURN;
    # The CERT data from apache holds the URN of the caller. 
    #
    if (exists($ENV{'SSL_CLIENT_CERT'})) {
        my $x509 = eval {
            Crypt::OpenSSL::X509->new_from_string($ENV{'SSL_CLIENT_CERT'}); };
        if ($@) {
            die "Invalid certificate: $@";
        }
        my $cert = $x509->as_string(Crypt::OpenSSL::X509::FORMAT_ASN1);
        die "Could not convert certificate to ASN1"
            if (!defined($cert) || $cert eq '');
        my $decoded = Crypt::X509->new( cert => $cert );
        if ($decoded->error) {
            die "Error decoding certificate:" . $decoded->error;
        }
        foreach my $tmp (@{ $decoded->SubjectAltName }) {
            if ($tmp =~ /^uniformResourceIdentifier=(.*)$/ ||
                $tmp =~ /^(urn:.*)$/) {
                $GENIURN = $ENV{'GENIURN'} = $1;
            }
        }
    }
    
    die "Invalid authentication certificate; no URN. Please regenerate."
        if (!exists($ENV{'GENIURN'}));
    
    die "You're not authorized to access this service." unless exists $valid_peers{'*'} or exists $valid_peers{ $GENIURN };

   return 0;
}