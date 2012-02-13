#!/usr/bin/perl -w

use strict;
use warnings;

=head1 NAME

LHC.pl - cache program to aid LHC.cgi

=head1 DESCRIPTION

Builds up a list (flat file) of hLS instances that match a certain keyword
query (e.g. 'LHC' and related combinations).  Run this via cron.  

=cut

use XML::LibXML;
use Carp;
use Getopt::Long;
use Data::Dumper;
use Data::Validate::IP qw(is_ipv4);
use Data::Validate::Domain qw( is_domain );
use Net::IPv6Addr;
use Net::CIDR;

use lib "/home/zurawski/perfSONAR-PS/lib";
#use lib "/usr/local/perfSONAR-PS/lib";

use perfSONAR_PS::Common qw( extract find unescapeString escapeString );
use perfSONAR_PS::Client::gLS;
use perfSONAR_PS::Client::Echo;

my $DEBUGFLAG   = q{};
my $HELP        = q{};

my $status = GetOptions(
    'verbose'   => \$DEBUGFLAG,
    'help'      => \$HELP
);

if ( $HELP ) {
    print "$0: starts the gLS cache script.\n";
    print "\t$0 [--verbose --help]\n";
    exit(1);
}

my $parser = XML::LibXML->new();
my $hints  = "http://www.perfsonar.net/gls.root.hints";
my @private_list = ( "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16" );
my $base = "/var/www/cgi-bin/perfAdmin/LHC";

my %hls = ();
my $gls = perfSONAR_PS::Client::gLS->new( { url => $hints } );

croak "roots not found" unless ( $#{ $gls->{ROOTS} } > -1 );

for my $root ( @{ $gls->{ROOTS} } ) {
    print "Root:\t" , $root , "\n" if $DEBUGFLAG;
    my $result = $gls->getLSQueryRaw(
        {
            ls => $root,
            xquery => "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";
  for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata
    let \$metadata_id := \$metadata/\@id
    let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef=\$metadata_id]
    where \$data/nmwg:metadata[((.//nmwg:parameter[\@name=\"keyword\" and (\@value=\"project:LHCOPN\" or text()=\"project:LHCOPN\")]) or (.//nmwg:parameter[\@name=\"keyword\" and (\@value=\"project:LHC-OPN\" or text()=\"project:LHC-OPN\")]) or (.//nmwg:parameter[\@name=\"keyword\" and (\@value=\"project:lhc\" or text()=\"project:lhc\")]) or (.//nmwg:parameter[\@name=\"keyword\" and (\@value=\"project:LHC\" or text()=\"project:LHC\")]))]
    return \$metadata"
        }
    );
    if ( exists $result->{eventType} and not( $result->{eventType} =~ m/^error/ ) ) {
        print "\tEventType:\t" , $result->{eventType} , "\n" if $DEBUGFLAG;
        my $doc = $parser->parse_string( $result->{response} ) if exists $result->{response};
        my $service = find( $doc->getDocumentElement, ".//*[local-name()='service']", 0 );

        foreach my $s ( $service->get_nodelist ) {

            my $accessPoint = extract( find( $s, ".//*[local-name()='accessPoint']", 1 ), 0 );
            my $serviceName = extract( find( $s, ".//*[local-name()='serviceName']", 1 ), 0 );
            my $serviceType = extract( find( $s, ".//*[local-name()='serviceType']", 1 ), 0 );
            my $serviceDescription = extract( find( $s, ".//*[local-name()='serviceDescription']", 1 ), 0 );

            if ( $accessPoint ) {
                print "\t\thLS:\t" , $accessPoint , "\n" if $DEBUGFLAG;

                my $test = $accessPoint;                
                $test =~ s/^http:\/\///;
                my ( $unt_test ) = $test =~ /^(.+):/;
                if ( $unt_test and is_ipv4( $unt_test ) ) {
                    if ( Net::CIDR::cidrlookup( $unt_test, @private_list ) ) {
                        print "\t\t\tReject:\t" , $unt_test , "\n" if $DEBUGFLAG;
                    }
                    else {
                        my $echo_service = perfSONAR_PS::Client::Echo->new( $accessPoint );
                        my ( $status, $res ) = $echo_service->ping();
                        $hls{$accessPoint} = $accessPoint."|".$serviceName."|".$serviceType."|".$serviceDescription."|".$status;
                    }
                }
                elsif ( $unt_test and &Net::IPv6Addr::is_ipv6( $unt_test ) ) {
                    # do noting (for now)
                    my $echo_service = perfSONAR_PS::Client::Echo->new( $accessPoint );
                    my ( $status, $res ) = $echo_service->ping();
                    $hls{$accessPoint} = $accessPoint."|".$serviceName."|".$serviceType."|".$serviceDescription."|".$status;
                }
                else {
                    if ( is_domain( $unt_test ) ) {
                        if ( $unt_test =~ m/^localhost/ ) {
                            print "\t\t\tReject:\t" , $unt_test , "\n" if $DEBUGFLAG;
                        }
                        else {
                            my $echo_service = perfSONAR_PS::Client::Echo->new( $accessPoint );
                            my ( $status, $res ) = $echo_service->ping();
                            $hls{$accessPoint} = $accessPoint."|".$serviceName."|".$serviceType."|".$serviceDescription."|".$status;
                        }  
                    }
                    else {
                        print "\t\t\tReject:\t" , $unt_test , "\n" if $DEBUGFLAG;
                    }
                }
            }
        }
        last;
    }
    else {
        if ( $DEBUGFLAG ) {
            print "\tResult:\t" , Dumper($result) , "\n";
        }
    }
}

print "\n" if $DEBUGFLAG;

open( FILE, ">" . $base . "/list.hls" ) or croak "can't open hls list";
foreach my $h ( keys %hls ) {
    print FILE $hls{$h} , "\n";
}
close(FILE);

__END__

=head1 SEE ALSO

L<XML::LibXML>, L<Carp>, L<Getopt::Long>, L<Data::Dumper>,
L<Data::Validate::IP>, L<Data::Validate::Domain>, L<Net::IPv6Addr>,
L<Net::CIDR>

To join the 'perfSONAR-PS' mailing list, please visit:

  https://mail.internet2.edu/wws/info/i2-perfsonar

The perfSONAR-PS subversion repository is located at:

  https://svn.internet2.edu/svn/perfSONAR-PS

Questions and comments can be directed to the author, or the mailing list.  Bugs,
feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: LHC.pl 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2007-2009, Internet2

All rights reserved.

=cut

