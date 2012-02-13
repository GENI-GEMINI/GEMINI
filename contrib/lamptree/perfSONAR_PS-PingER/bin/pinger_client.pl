#!/usr/bin/perl -w

use strict;
use warnings;

=head1  NAME  

pinger_client.pl
 
=head1 DESCRIPTION

TBD

=cut

use FindBin qw($Bin);
use lib "$Bin/../lib";

use perfSONAR_PS::Client::PingER;
use Data::Dumper;
use Getopt::Long;
use POSIX qw(strftime);

use Log::Log4perl qw(:easy);

my $debug;
my $url = 'http://localhost:8075/perfSONAR_PS/services/pinger/ma';
my $help;
my $data;
my $ok = GetOptions(
    'debug|d'  => \$debug,
    'url=s'    => \$url,
    'data'     => \$data,
    'help|?|h' => \$help,
);

if ( !$ok || !$url || $help ) {
    print " $0: sends an  XML request over SOAP to the pinger MA and prints response \n";
    print " $0   [--url=<pinger_MA_url, default is localhost> --debug|-d ] \n";
    exit 0;
}
my $level = $INFO;

if ( $debug ) {
    $level = $DEBUG;
}

Log::Log4perl->easy_init( $level );
my $logger = get_logger( "pinger_client" );

my $ma = new perfSONAR_PS::Client::PingER( { instance => $url } );

my $result = $ma->metadataKeyRequest();

my $metaids = $ma->getMetaData( $result );

my $time_start = time() - 1800;
my $time_end   = time();
my $ptime      = sub { strftime " %Y-%m-%d %H:%M", localtime( shift ) };
my %keys       = ();
foreach my $meta ( keys %{$metaids} ) {
    print "Metadata: src=$metaids->{$meta}{src_name} dst=$metaids->{$meta}{dst_name}  packetSize=$metaids->{$meta}{packetSize}\nMetadata Key(s):";
    map { print " $_ :" } @{ $metaids->{$meta}{keys} };
    print "\n";
    map { $keys{$_}++ } @{ $metaids->{$meta}{keys} };
}
if ( $data && %keys ) {
    $ma = new perfSONAR_PS::Client::PingER( { instance => $url } );

    my $dresult = $ma->setupDataRequest(
        {
            start      => $time_start,
            end        => $time_end,
            keys       => [ keys %keys ],
            cf         => 'AVERAGE',
            resolution => 5,
        }
    );

    my $data_md = $ma->getData( $dresult );
    foreach my $key_id ( keys %{$data_md} ) {
        print "\n---- Key: $key_id \n";
        foreach my $id ( keys %{ $data_md->{$key_id}{data} } ) {
            foreach my $timev ( sort { $a <=> $b } keys %{ $data_md->{$key_id}{data}{$id} } ) {
                print "Data: tm=" . $ptime->( $timev ) . "\n datums: ";
                map { print "$_ = $data_md->{$key_id}{data}{$id}{$timev}{$_} " } keys %{ $data_md->{$key_id}{data}{$id}{$timev} };
                print "\n";
            }

        }
    }
}

__END__

=head1 SEE ALSO

L<perfSONAR_PS::Client::PingER>, L<Data::Dumper>, L<Getopt::Long>, L<POSIX>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: pinger_client.pl 2774 2009-04-17 00:13:13Z aaron $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
