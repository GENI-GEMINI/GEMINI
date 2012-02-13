package perfSONAR_PS::Atom::PingER;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Atom::PingER-  Atom 1.0 feed publisher for PingER MA ( THIS IS PROOF OF CONCEPT MODULE !)

=head1 DESCRIPTION

Atom feed publisher for PingER MA, implemented as mod_perl2 handler,  gets list
of metadata from gLS and checks if lossPercent was > 5 then reports that link is
having a problem updates for the past 30 minutes For startup.pl script see
trunk/startup.pl

=cut

use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Const -compile => qw(:common :context HTTP_BAD_REQUEST OR_ALL EXEC_ON_READ RAW_ARGS);
use Cache::FileCache;
use Storable qw(freeze thaw);

use perfSONAR_PS::Client::PingER;
use perfSONAR_PS::Datatypes::EventTypes;
use Data::Dumper;
use Log::Log4perl qw( get_logger);
use Data::UUID;
use POSIX qw(strftime);
use XML::Atom::SimpleFeed;
use perfSONAR_PS::Client::gLS;
use perfSONAR_PS::Common;
use aliased 'perfSONAR_PS::SONAR_DATATYPES::v2_0::psservice::Message::Metadata::Subject::Service';

$LOGGER = get_logger( "perfSONAR_PS::Atom::PingER" );
our $gls        = perfSONAR_PS::Client::gLS->new( { url => "http://www.perfsonar.net/gls.root.hints" } );
our $event      = perfSONAR_PS::Datatypes::EventTypes->new();
our @eventTypes = ( "http://ggf.org/ns/nmwg/tools/pinger/2.0", "http://ggf.org/ns/nmwg/tools/pinger/2.0/" );
our $result;

=head2 handler

standard mod_perl2 handler

=cut

sub handler {
    my $req = shift;
    $req->content_type( 'application/atom+xml' );

    printFeed( $req );
    return Apache2::Const::OK;
}

=head2 printFeed

prints feed for the supplied request object

=cut

sub printFeed {
    my $req = shift;

    my $uuid_obj = Data::UUID->new();
    my $uuid     = $uuid_obj->create_from_name( $event->tools->pinger, 'pinger' );
    my $now      = strftime '%Y-%m-%dT%H:%M:%SZ', gmtime;
    my $feed     = XML::Atom::SimpleFeed->new(
        title   => 'Pinger MA metadata updated in the past 30 minutes',
        link    => { rel => 'self', href => 'http://lhcopnmon1-mgm.fnal.gov:9090/atom_ma', },
        updated => $now,
        author  => 'perfSONAR gLS',
        id      => "urn:uuid:" . $uuid_obj->to_string( $uuid ),
    );
    my $error = setMetaFeed( $req, $feed, $uuid_obj, $now );
    if ( $error ) {
        $req->print( " No data available or error <b>$error</b> " );
    }
    else {
        $feed->print;
    }
}

=head2  setMetaFeed

for current $feed object, $uuid object and current timestamp sets entries for
the feed

=cut

sub setMetaFeed {
    my ( $req, $feed, $uuid_obj, $now ) = @_;
    my $time_start = time() - 1800;
    my $time_end   = time();
    my $cache      = new Cache::FileCache(
        {
            'namespace'          => $event->tools->pinger,
            'default_expires_in' => 300
        }
    );
    my ( $CACHED_MDKR, $CACHED_SDR ) = ();
    unless ( $cache ) {
        $LOGGER->error( " Could not instantiate FileCache." );
        return Apache2::Const::SERVER_ERROR;
    }
    else {
        my $stored = $cache->get( 'hashed_mdkr' );
        $CACHED_MDKR = thaw( $stored ) if $stored;

        #$LOGGER->info(" MD dump:" . Dumper   $CACHED_MDKR);

        $stored = $cache->get( 'hashed_sdr' );
        $CACHED_SDR = thaw( $stored ) if $stored;

        #$LOGGER->info(" Data dump:" . Dumper   $CACHED_SDR);

    }
    $result = $gls->getLSLocation( { eventTypes => \@eventTypes } );
    #### my @result  = qw{ http://lhcopnmon1-mgm.fnal.gov:8075/perfSONAR_PS/services/pinger/ma http://newmon.bnl.gov:8077/perfSONAR_PS/services/pinger/ma};
    ##########
    foreach my $s ( @{$result} ) {

        #my $ma = $url =~ /^http\:/s?$url:$url;
        my $service = Service->new( { xml => $s } );
        my $url     = $service->get_accessPoint;
        my $ma      = new perfSONAR_PS::Client::PingER( { instance => $url } );
        $ma->setLOGGER( $LOGGER );

        if ( !$CACHED_MDKR || !$CACHED_MDKR->{$url} ) {
            my $result = $ma->metadataKeyRequest();
            $CACHED_MDKR->{$url} = $ma->getMetaData( $result );
        }

        my ( @keys_send, $data ) = ();
        ## getting keys to send SDR
        foreach my $id ( keys %{ $CACHED_MDKR->{$url} } ) {
            next if ( %{ $CACHED_SDR->{$url}{$id}{data} } || !@{ $CACHED_MDKR->{$url}{$id}{keys} } );
            push @keys_send, @{ $CACHED_MDKR->{$url}{$id}{keys} };
        }

        if ( @keys_send ) {
            my $dresult = $ma->setupDataRequest(
                {
                    start      => $time_start,
                    end        => $time_end,
                    cf         => 'AVERAGE',
                    resolution => 10,
                    keys       => \@keys_send,

                }
            );
            $data = $ma->getData( $dresult );
        }
        foreach $id ( sort keys %{ $CACHED_MDKR->{$url} } ) {
            next unless $CACHED_MDKR->{$url}{$id};
            my $src   = $CACHED_MDKR->{$url}{$id}{src_name};
            my $dst   = $CACHED_MDKR->{$url}{$id}{dst_name};
            my $pkgsz = $CACHED_MDKR->{$url}{$id}{packetSize};

            #
            $LOGGER->info( " Next::id = $id  $src - $dst  $pkgsz" );

            $CACHED_SDR->{$url}{$id}{data} = $data->{$id}{data} if ( !$CACHED_SDR->{$url}{$id}{data} );
            my $loss_flag = 0;
            foreach my $key ( @{ $CACHED_MDKR->{$url}{$id}{keys} } ) {
                foreach my $timev ( keys %{ $CACHED_SDR->{$url}{$id}{data}{$key} } ) {
                    $loss_flag = $CACHED_SDR->{$url}{$id}{data}{$key}{$timev}{'lossPercent'}
                        if $loss_flag
                            && $loss_flag < $CACHED_SDR->{$url}{$id}{data}{$key}{$timev}{'lossPercent'};
                }
            }
            my $t_start = strftime "%Y-%m-%dT%H:%M:%S", localtime( $time_start );
            my $t_end   = strftime "%Y-%m-%dT%H:%M:%S", localtime( $time_end );
            my $uuid = $uuid_obj->create_from_name( 'http://ggf.org/ns/nmwg/base/2.0/', $CACHED_MDKR->{$url}{$id}{keys}[0] );
            $feed->add_entry(
                title    => "Link: ( $src - $dst ) and  PacketSize = $pkgsz bytes",
                link     => "http://tukki.fnal.gov/pinger/pingerUI.pl?ma=$url&get_it=jh34587wuhlkh789hbyf78343gort03idjuhf3785t0gfgofbf78o4348orgofg7o4fg7&link=$id&time_start=$t_start&time_end=$t_end&upper_rtt=auto&gmt_offset=-5&gtype=rtloss&gpresent=lines",
                id       => "urn:uuid:" . $uuid_obj->to_string( $uuid ),
                updated  => $now,
                category => 'perfSONAR-PS',
                summary  => "Link "
                    . ( $loss_flag > 5 ? $loss_flag > 95 ? 'is <red>DOWN</red>' : " is OK, BUT packets loss=$loss_flag\% is observed" : " is OK" )
                    . "</br> Most recent RTT and Loss rate: <img src=\"http://tukki.fnal.gov/pinger/pingerUI.pl?ma=$url&get_it=jh34587wuhlkh789hbyf78343gort03idjuhf3785t0gfgofbf78o4348orgofg7o4fg7&link=$id&time_start=$t_start&time_end=$t_end&upper_rtt=auto&gmt_offset=-5&gtype=rtloss&gpresent=lines\"/>",
            );
        }
    }

    $cache->set( 'hashed_mdkr', freeze( $CACHED_MDKR ) ) if ref $CACHED_MDKR;
    $cache->set( 'hashed_sdr',  freeze( $CACHED_SDR ) )  if ref $CACHED_SDR;
    return;
}

1;

__END__

=head1 SEE ALSO

L<Apache2::RequestRec>, L<Apache2::RequestIO>, L<Apache2::Const>,
L<Cache::FileCache>, L<Storable>, L<perfSONAR_PS::Client::PingER>,
L<perfSONAR_PS::Datatypes::EventTypes>, L<Data::Dumper>, L<Log::Log4perl>,
L<Data::UUID>, L<POSIX>, L<XML::Atom::SimpleFeed>, L<perfSONAR_PS::Client::gLS>,
L<perfSONAR_PS::Common>, L<aliased>
 
To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: PingER.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
