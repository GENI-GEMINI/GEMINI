package perfSONAR_PS::Client::Parallel::gLS;

use strict;
use warnings;

our $VERSION = 3.1;

use fields 'ROOTS', 'HINTS', 'LOGGER', 'FILE';

=head1 NAME

perfSONAR_PS::Client::Parallel::gLS  

=head1 DESCRIPTION

API for interacting with the gLS and hLS instances to take some of the mystery
out of queries.  The API identifies several common functions that will be of use
to clients and services in the perfSONAR framework for extracting information
from the gLS. This module is nearly identical to the normal
perfSONAR_PS::Client::gLS. However, it uses the
perfSONAR_PS::Client::Parallel::LS client under the hood, allowing much of the
high-level querying to happen in parallel.

=cut

use Log::Log4perl qw( get_logger );
use Params::Validate qw( :all );
use English qw( -no_match_vars );
use LWP::Simple;
use Net::Ping;
use XML::LibXML;
use Digest::MD5 qw(md5_hex);
use Data::Dumper;

use perfSONAR_PS::Utils::ParameterValidation;
use perfSONAR_PS::Client::Echo;
use perfSONAR_PS::Client::LS;
use perfSONAR_PS::Client::Parallel::LS;
use perfSONAR_PS::Common qw( genuid find extract );

=head2 new( $package, { url } )

Create new object, set the gls.hints URL and call init if applicable.

=cut

sub new {
    my ( $package, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            url  => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF | Params::Validate::SCALAR, optional => 1 },
            file => { type => Params::Validate::SCALAR | Params::Validate::UNDEF,                              optional => 1 }
        }
    );

    my $self = fields::new( $package );
    my @temp = ();
    $self->{ROOTS}  = \@temp;
    $self->{HINTS}  = ();
    $self->{LOGGER} = get_logger( "perfSONAR_PS::Client::gLS" );

    if ( exists $parameters->{"file"} and $parameters->{"file"} and -f $parameters->{"file"} ) {
        $self->{FILE} = $parameters->{"file"};
        $self->init();
    }
    else {
        my $url = $parameters->{"url"};
        $url = "http://www.perfsonar.net/gls.root.hints" unless ( $url );

        if ( ref( $url ) eq "ARRAY" ) {
            my $complete = 0;
            foreach my $url ( @{$url} ) {
                if ( $url =~ m/^http:\/\// ) {
                    push @{ $self->{HINTS} }, $url;
                    $complete++;
                }
                else {
                    $self->{LOGGER}->error( "URL must be of the form http://ADDRESS." );
                }
            }
            $self->init() if $complete;
        }
        else {
            if ( $url =~ m/^http:\/\// ) {
                push @{ $self->{HINTS} }, $url;
                $self->init();
            }
            else {
                $self->{LOGGER}->error( "URL must be of the form http://ADDRESS." );
            }
        }
    }

    $self->{LOGGER}->info( "Finished gLS new" );

    return $self;
}

=head2 clearURLs( $self, {} )

Clear the URL list.

=cut

sub clearURLs {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );
    undef $self->{HINTS};
    return;
}

=head2 addURL( $self, { url } )

Set the gls.hints url and call init if applicable.

=cut

sub addURL {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { url => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF | Params::Validate::SCALAR } } );

    if ( ref( $parameters->{"url"} ) eq "ARRAY" ) {
        my $complete = 0;
        foreach my $url ( @{ $parameters->{"url"} } ) {
            if ( $url =~ m/^http:\/\// ) {
                push @{ $self->{HINTS} }, $url;
                $complete++;
            }
            else {
                $self->{LOGGER}->error( "URL must be of the form http://ADDRESS." );
            }
        }
        $self->init() if $complete;
    }
    else {
        if ( $parameters->{"url"} =~ m/^http:\/\// ) {
            push @{ $self->{HINTS} }, $parameters->{"url"};
            $self->init();
        }
        else {
            $self->{LOGGER}->error( "URL must be of the form http://ADDRESS." );
        }
    }
    return 0;
}

=head2 setFile( $self, { file } )

Supply a file of gls roots.

=cut

sub setFile {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { file => { type => Params::Validate::SCALAR } } );

    if ( $parameters->{"file"} and -f $parameters->{"file"} ) {
        $self->{FILE} = $parameters->{"file"};
        $self->init();
    }
    else {
        $self->{LOGGER}->error( "File does not exist." );
        return -1;
    }
    return 0;
}

=head2 init( $self, { } )

Used to extract gLS instances from some hints file, order the resulting gLS
instances by connectivity.

=cut

sub init {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    unless ( exists $self->{HINTS} or exists $self->{FILE} ) {
        $self->{LOGGER}->error( "Cannot call init without setting hints URL or file." );
        return -1;
    }

    my @roots = ();
    if ( exists $self->{HINTS} and $self->{HINTS} ) {
        my $complete = 0;
        foreach my $url ( @{ $self->{HINTS} } ) {
            my $content = get $url;
            if ( $content ) {
                @roots = split( /\n/, $content );
                $complete++;
                last;
            }
            else {
                $self->{LOGGER}->error( "There was an error accessing " . $url . "." );
            }
        }
        unless ( $complete ) {
            $self->{LOGGER}->error( "There was an error accessing the hints file(s), exiting." );
            return -1;
        }
    }

    if ( exists $self->{FILE} and $self->{FILE} ) {
        if ( -f $self->{FILE} ) {
            open( HINTS, $self->{FILE} );
            while ( <HINTS> ) {
                $_ =~ s/\n$//;
                push @roots, $_ if $_;
            }
            close( HINTS );
        }
        else {
            $self->{LOGGER}->error( "There was an error accessing " . $self->{FILE} . "." );
            return -1;
        }
    }

    $self->orderRoots( { roots => \@roots } );

    return 0;
}

=head2 orderRoots( $self, { roots } )

For each gLS root in the gls.hints file, check to see if the service is
available, then order the resulting services by latency.

=cut

sub orderRoots {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { roots => 0 } );

    my @roots = ();
    if ( exists $parameters->{roots} and $parameters->{roots} ) {
        @roots = @{ $parameters->{roots} };
    }
    else {
        if ( exists $self->{ROOTS} and $self->{ROOTS} ) {
            @roots = @{ $self->{ROOTS} };
        }
    }
    undef $self->{ROOTS};

    # remove duplicates
    my %rootHash = map { $_, 1 } @roots;
    @roots = keys %rootHash;

    # Randomize array
    my $array = shift;
    my $i;
    for ( $i = @roots; --$i; ) {
        my $j = int rand( $i + 1 );
        next if $i == $j;
        @roots[ $i, $j ] = @roots[ $j, $i ];
    }

    my $found_top = 0;
    do {
        if ( $roots[0] ) {

            # do some basic sanity checking
            my $ping = Net::Ping->new();
            if ( $roots[0] =~ /^http/ ) {
                my ( $unt_host, $unt_port ) = $roots[0] =~ /^http:\/\/(.+):([0-9]+)/;
                my ( $ret, $duration, $ip ) = $ping->ping( $unt_host, 2 );
                if ( $ret ) {
                    $found_top = 1;
                }
                else {
                    shift( @roots );
                }
            }
            $ping->close();
        }
    } while ( not $found_top and scalar( @roots ) > 0 );

    $self->{ROOTS} = \@roots;

    return;
}

=head2 addRoot( $self, { priority, root } )

Add a root gLS to the roots list.

=cut

sub addRoot {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            priority => { type => Params::Validate::SCALAR, optional => 1 },
            root     => { type => Params::Validate::SCALAR }
        }
    );

    if ( $parameters->{root} =~ m/^http:\/\// ) {
        unless ( $self->verifyURL( { url => $parameters->{root} } ) == -1 ) {
            if ( exists $parameters->{priority} and $parameters->{priority} ) {
                unshift @{ $self->{ROOTS} }, $parameters->{root};
            }
            else {
                push @{ $self->{ROOTS} }, $parameters->{root};
            }
        }
    }
    else {
        $self->{LOGGER}->error( "Root must be of the form http://ADDRESS." );
    }
    return -1;
}

=head2 verifyURL( $self, { url } )

Given a url, see if it is contactable via the echo interface.

=cut

sub verifyURL {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, { url => { type => Params::Validate::SCALAR } } );

    if ( $parameters->{url} =~ m/^http:\/\// ) {
        my $echo_service = perfSONAR_PS::Client::Echo->new( $parameters->{url} );
        my ( $status, $res ) = $echo_service->ping();
        return 0 if $status > -1;
    }
    else {
        $self->{LOGGER}->error( "URL must be of the form http://ADDRESS." );
    }
    return -1;
}

=head2 getRoot( $self, { } )

Extract the first usable root element.  In the event you exhaust the list, try
again (once only, covers the case where a previously 'dead' root may come back).

=cut

sub getRoot {
    my ( $self, @args ) = @_;
    my $parameters = validateParams( @args, {} );

    my $flag = 0;
    while ( $flag <= 1 ) {
        foreach my $root ( @{ $self->{ROOTS} } ) {
            my $echo_service = perfSONAR_PS::Client::Echo->new( $root );
            my ( $status, $res ) = $echo_service->ping();
            return $root if $status != -1;
        }
        $self->init();
        $flag++;
    }
    return;
}

=head2 createSummaryMetadata( $self, { addresses, domains, eventTypes, keywords } )

Given the data items of the summary metadata (addresses, domains, eventTypes), 
create and return this XML.

=cut

sub createSummaryMetadata {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            addresses  => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            domains    => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            eventTypes => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            keywords   => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 }
        }
    );

    my $subject = "    <summary:subject id=\"subject." . genuid() . "\" xmlns:summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\">\n";
    foreach my $addr ( @{ $parameters->{addresses} } ) {
        if ( ref( $addr ) eq "ARRAY" ) {
            if ( $addr->[0] and $addr->[1] ) {
                $subject .= "      <nmtb:address xmlns:nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\" type=\"" . $addr->[1] . "\">" . $addr->[0] . "</nmtb:address>\n";
            }
            else {
                $subject .= "      <nmtb:address xmlns:nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\" type=\"ipv4\">" . $addr->[0] . "</nmtb:address>\n";
            }
        }
        else {
            $subject .= "      <nmtb:address xmlns:nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\" type=\"ipv4\">" . $addr . "</nmtb:address>\n";
        }
    }
    foreach my $domain ( @{ $parameters->{domains} } ) {
        $subject .= "      <nmtb:domain xmlns:nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\">\n";
        $subject .= "        <nmtb:name type=\"dns\">" . $domain . "</nmtb:name>\n";
        $subject .= "      </nmtb:domain>\n";
    }
    foreach my $eT ( @{ $parameters->{eventTypes} } ) {
        $subject .= "      <nmwg:eventType>" . $eT . "</nmwg:eventType>\n";
    }
    $subject .= "    </summary:subject>\n";

    if ( exists $parameters->{keywords} ) {
        $subject .= "    <summary:parameters>\n";
    }
    foreach my $k ( @{ $parameters->{keywords} } ) {
        $subject .= "      <nmwg:parameter name=\"keyword\">" . $k . "</nmwg:parameter>\n";
    }
    if ( exists $parameters->{keywords} ) {
        $subject .= "    </summary:parameters>\n";
    }

    return $subject;
}

=head2 summaryToXQuery( $self, { addresses, domains, eventTypes, keywords } )

Form an XQuery expression (as general as possible) for a given set of summary items.

=cut

sub summaryToXQuery {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            addresses  => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            domains    => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            eventTypes => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            service    => { type => Params::Validate::HASHREF | Params::Validate::UNDEF,  optional => 1 },
            keywords   => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 }
        }
    );

    my $qflag = 0;
    my $query = "  declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
    $query .= "  for \$metadata in /nmwg:store[\@type=\"LSStore\"]/nmwg:metadata\n";
    $query .= "    let \$metadata_id := \$metadata/\@id\n";
    $query .= "    let \$data := /nmwg:store[\@type=\"LSStore\"]/nmwg:data[\@metadataIdRef=\$metadata_id]\n";

    my @size = keys %{ $parameters->{service} };
    if ( $#size > -1 ) {
        $query .= "    where \$metadata/*[local-name()=\"subject\"]/*[local-name()=\"service\"";
        foreach my $element ( keys %{ $parameters->{service} } ) {
            $query .= " and ./*[local-name()=\"" . $element . "\" and text()=\"" . $parameters->{service}->{$element} . "\"]";
        }
        $query .= "]\n";
    }
    $query .= "    return \$data/nmwg:metadata[";

    if ( $#{ $parameters->{eventTypes} } > -1 ) {
        my $eflag = 0;
        $query .= "(";
        foreach my $eT ( @{ $parameters->{eventTypes} } ) {
            if ( $eflag ) {
                $query .= " and (.//nmwg:eventType[text()=\"" . $eT . "\"] or .//nmwg:parameter[(\@name=\"eventType\" or \@name=\"supportedEventType\") and (\@value=\"" . $eT . "\" or text()=\"" . $eT . "\")])";
            }
            else {
                $query .= "(.//nmwg:eventType[text()=\"" . $eT . "\"] or .//nmwg:parameter[(\@name=\"eventType\" or \@name=\"supportedEventType\") and (\@value=\"" . $eT . "\" or text()=\"" . $eT . "\")])";
                $eflag++ if not $eflag;
            }
            $qflag++ if not $qflag;
        }
        $query .= ")";
    }

    if ( $#{ $parameters->{keywords} } > -1 ) {
        my $kflag = 0;
        if ( $qflag ) {
            $query .= " and (";
        }
        else {
            $query .= "(";
        }
        foreach my $k ( @{ $parameters->{keywords} } ) {
            if ( $kflag ) {
                $query .= " and (.//nmwg:parameter[\@name=\"keyword\" and (\@value=\"" . $k . "\" or text()=\"" . $k . "\")])";
            }
            else {
                $query .= "(.//nmwg:parameter[\@name=\"keyword\" and (\@value=\"" . $k . "\" or text()=\"" . $k . "\")])";
                $kflag++ if not $kflag;
            }
            $qflag++ if not $qflag;
        }
        $query .= ")";
    }

    if ( $#{ $parameters->{domains} } > -1 ) {
        my $dflag = 0;
        if ( $qflag ) {
            $query .= " and (";
        }
        else {
            $query .= "(";
        }
        foreach my $d ( @{ $parameters->{domains} } ) {
            if ( $dflag ) {
                $query .= " and (.//*[local-name()=\"hostName\" and fn:matches(text(), \"" . $d
                    . "\")] or .//*[(local-name()=\"endPoint\" or local-name()=\"endPointPair\" or local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"hostname\" or \@type=\"hostName\" or \@type=\"host\" or \@type=\"dns\" or \@type=\"DNS\") and (fn:matches(text(), \""
                    . $d
                    . "\") or fn:matches(\@value, \""
                    . $d
                    . "\"))]) ";
            }
            else {
                $query .= "(.//*[local-name()=\"hostName\" and fn:matches(text(), \"" . $d
                    . "\")] or .//*[(local-name()=\"endPoint\" or local-name()=\"endPointPair\" or local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"hostname\" or \@type=\"hostName\" or \@type=\"host\" or \@type=\"dns\" or \@type=\"DNS\") and (fn:matches(text(), \""
                    . $d
                    . "\") or fn:matches(\@value, \""
                    . $d
                    . "\"))]) ";
                $dflag++ if not $dflag;
            }
            $qflag++ if not $qflag;
        }
        $query .= ")";
    }

    if ( $#{ $parameters->{addresses} } > -1 ) {
        my $aflag = 0;
        if ( $qflag ) {
            $query .= " and (";
        }
        else {
            $query .= "(";
        }
        foreach my $addr ( @{ $parameters->{addresses} } ) {
            if ( ref( $addr ) eq "ARRAY" ) {
                if ( $addr->[0] and $addr->[1] and $addr->[1] =~ m/ipv6/i ) {
                    if ( $aflag ) {
                        $query
                            .= " and (.//*[(local-name()=\"endPoint\" and local-name()=\"endPointPair\" and local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"ipv6\" or \@type=\"IPv6\") and (text()=\""
                            . $addr->[0]
                            . "\" or \@value=\""
                            . $addr->[0] . "\")])";
                    }
                    else {
                        $query
                            .= "(.//*[(local-name()=\"endPoint\" and local-name()=\"endPointPair\" and local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"ipv6\" or \@type=\"IPv6\") and (text()=\""
                            . $addr->[0]
                            . "\" or \@value=\""
                            . $addr->[0] . "\")])";
                        $aflag++ if not $aflag;
                    }
                }
                else {
                    if ( $aflag ) {
                        $query
                            .= " and (.//*[(local-name()=\"endPoint\" and local-name()=\"endPointPair\" and local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"ipv4\" or \@type=\"IPv4\") and (text()=\""
                            . $addr->[0]
                            . "\" or \@value=\""
                            . $addr->[0] . "\")])";
                    }
                    else {
                        $query
                            .= "(.//*[(local-name()=\"endPoint\" and local-name()=\"endPointPair\" and local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"ipv4\" or \@type=\"IPv4\") and (text()=\""
                            . $addr->[0]
                            . "\" or \@value=\""
                            . $addr->[0] . "\")])";
                        $aflag++ if not $aflag;
                    }
                }
            }
            else {
                if ( $aflag ) {
                    $query
                        .= " and (.//*[(local-name()=\"endPoint\" and local-name()=\"endPointPair\" and local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"ipv4\" or \@type=\"IPv4\") and (text()=\""
                        . $a
                        . "\" or \@value=\""
                        . $a . "\")])";
                }
                else {
                    $query
                        .= "(.//*[(local-name()=\"endPoint\" and local-name()=\"endPointPair\" and local-name()=\"address\" or local-name()=\"ipAddress\" or local-name()=\"ifAddress\" or local-name()=\"name\" or local-name()=\"src\" or local-name()=\"dst\") and (\@type=\"ipv4\" or \@type=\"IPv4\") and (text()=\""
                        . $a
                        . "\" or \@value=\""
                        . $a . "\")])";
                    $aflag++ if not $aflag;
                }
            }
            $qflag++ if not $qflag;
        }
        $query .= ")";
    }
    $query .= "]\n";
    return $query;
}

=head2 LEVEL 0 API

The following functions are classified according to the gLS design document
as existing in "Level 0".

=head3 getLSDiscoverRaw( $self, { ls, xquery } )

Perform the given XQuery on the root, or if supplied, some other LS instance.
This query is destined for the Summary data set by virtue of the eventType
that is used. Both gLS and hLS instances have this summary dataset, but gLS
instances are understood to know about much more.

=cut

sub getLSDiscoverRaw {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            ls     => 0,
            xquery => { type => Params::Validate::SCALAR }
        }
    );

    my $ls = perfSONAR_PS::Client::LS->new();
    if ( exists $parameters->{ls} and $parameters->{ls} =~ m/^http:\/\// ) {
        unless ( $self->verifyURL( { url => $parameters->{ls} } ) == 0 ) {
            $self->{LOGGER}->error( "Supplied server \"" . $parameters->{ls} . "\" could not be contacted." );
            return;
        }
        $ls->setInstance( { instance => $parameters->{ls} } );
    }
    else {
        my $ls_instance = $self->getRoot();
        unless ( $ls_instance ) {
            $self->{LOGGER}->error( "gLS Root servers could not be contacted." );
            return;
        }
        $ls->setInstance( { instance => $ls_instance } );
    }

    my $eventType = "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/xquery/2.0";
    my $result = $ls->queryRequestLS( { query => $parameters->{xquery}, format => 1, eventType => $eventType } );
    return $result;
}

=head3 getLSDiscoverRaw( $self, { ls, xquery } )

Perform the given XQuery on some LS instance.  This query is destined for the
regular data set by virtue of the eventType that is used. Both gLS and hLS
instances have this dataset, but gLS instances are understood to not accept
common service registration, while hLS instances will.

=cut

sub getLSQueryRaw {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            ls        => { type => Params::Validate::SCALAR },
            xquery    => { type => Params::Validate::SCALAR },
            eventType => 0
        }
    );

    my $result;
    my $ls = perfSONAR_PS::Client::LS->new();
    if ( $parameters->{ls} =~ m/^http:\/\// ) {
        unless ( $self->verifyURL( { url => $parameters->{ls} } ) == 0 ) {
            $self->{LOGGER}->error( "Supplied server \"" . $parameters->{ls} . "\" could not be contacted." );
            return;
        }
        $ls->setInstance( { instance => $parameters->{ls} } );
    }
    else {
        $self->{LOGGER}->error( "LS must be of the form http://ADDRESS." );
        return $result;
    }

    my $eventType = "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/query/xquery/2.0";
    if ( exists $parameters->{eventType} and ( $parameters->{eventType} eq "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/query/xquery/2.0" or $parameters->{eventType} eq "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0" ) ) {
        $eventType = $parameters->{eventType};
    }

    $result = $ls->queryRequestLS( { query => $parameters->{xquery}, format => 1, eventType => $eventType } );
    return $result;
}

=head3 getLSDiscoverControlRaw( $self, { ls, xquery } )

Not implemented.

=cut

=head3 getLSQueryControlRaw( $self, { ls, xquery } )

Not implemented.

=cut

=head2 LEVEL 1 API

The following functions are classified according to the gLS design document
as existing in "Level 1".

=head3 getLSDiscovery( $self, { ls, addresses, domains, eventTypes, service, keywords } )

Perform discovery on the gLS, or if applicable on the supplied (g|h)LS, and the
supplied arguments:

 - array of arrays of ip addresses: ( ( ADDRESS, "ipv4"), ( ADDRESS, "ipv6") )
 - array of domains: ( "edu", "udel.edu" )
 - array of eventTypes: ( http://ggf.org/ns/nmwg/tools/owamp/2.0" )
 - hash of service variables: ( 
   { 
     serviceType => "MA", 
     psservice:serviceType => "MA" 
   } 
 )

The result is a list of URLs that correspond to hLS instances to contact for
more information.

=cut

sub getLSDiscovery {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            ls         => 0,
            addresses  => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            domains    => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            eventTypes => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            service    => { type => Params::Validate::HASHREF | Params::Validate::UNDEF, optional => 1 },
            keywords   => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 }
        }
    );

    my $ls = perfSONAR_PS::Client::LS->new();
    if ( exists $parameters->{ls} and $parameters->{ls} =~ m/^http:\/\// ) {
        unless ( $self->verifyURL( { url => $parameters->{ls} } ) == 0 ) {
            $self->{LOGGER}->error( "Supplied server \"" . $parameters->{ls} . "\" could not be contacted." );
            return;
        }
        $ls->setInstance( { instance => $parameters->{ls} } );
    }
    else {
        my $ls_instance = $self->getRoot();
        unless ( $ls_instance ) {
            $self->{LOGGER}->error( "gLS Root servers could not be contacted." );
            return;
        }
        $ls->setInstance( { instance => $ls_instance } );
    }

    my $subject = $self->createSummaryMetadata(
        {
            addresses  => $parameters->{addresses},
            domains    => $parameters->{domains},
            eventTypes => $parameters->{eventTypes},
            keywords   => $parameters->{keywords}
        }
    );

    my @urls      = ();
    my %list      = ();
    my $eventType = "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0";
    my $result    = $ls->queryRequestLS( { subject => $subject, eventType => $eventType } );
    if ( exists $result->{eventType} and $result->{eventType} eq "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0" ) {
        if ( exists $result->{response} and $result->{response} ) {
            my $parser  = XML::LibXML->new();
            my $doc     = $parser->parse_string( $result->{response} );
            my $service = find( $doc->getDocumentElement, ".//nmwg:data/nmwg:metadata/*[local-name()='subject']/*[local-name()='service']", 0 );
            foreach my $s ( $service->get_nodelist ) {
                my $flag = 1;
                foreach my $element ( keys %{ $parameters->{service} } ) {
                    my $value = q{};
                    if ( $element =~ m/:/ ) {
                        $value = extract( find( $s, "./" . $element . "[text()=\"" . $parameters->{service}->{$element} . "\" or value=\"" . $parameters->{service}->{$element} . "\"]", 1 ), 0 );
                        unless ( $value ) {
                            $flag = 0;
                            last;
                        }
                    }
                    else {
                        $value = extract( find( $s, "./*[local-name()='" . $element . "' and (text()=\"" . $parameters->{service}->{$element} . "\" or value=\"" . $parameters->{service}->{$element} . "\")]", 1 ), 0 );
                        unless ( $value ) {
                            $flag = 0;
                            last;
                        }
                    }
                }
                if ( $flag ) {
                    my $value = extract( find( $s, "./psservice:accessPoint", 1 ), 0 );
                    my $vh = md5_hex( $value );
                    push @urls, $value if $value and ( not exists $list{$vh} );
                    $list{$vh}++;
                }
            }
        }
    }
    return \@urls;
}

=head3 getLSQueryLocation( $self, { ls, addresses, domains, eventTypes, service, keywords } )

Perform query on the supplied hLS and using the supplied arguments:

 - array of arrays of ip addresses: ( ( ADDRESS, "ipv4"), ( ADDRESS, "ipv6") )
 - array of domains: ( "edu", "udel.edu" )
 - array of eventTypes: ( http://ggf.org/ns/nmwg/tools/owamp/2.0" )
 - hash of service variables: ( 
   { 
     serviceType => "MA", 
     psservice:serviceType => "MA" 
   } 
 )

The result is a list of Service elements (service XML) of services to contact
for more information.

=cut

sub getLSQueryLocation {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            ls          => { type => Params::Validate::ARRAYREF },
            addresses   => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            domains     => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            eventTypes  => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            service     => { type => Params::Validate::HASHREF | Params::Validate::UNDEF, optional => 1 },
            keywords    => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            timeout     => { type => Params::Validate::SCALAR | Params::Validate::UNDEF, optional => 1 },
            parallelism => { type => Params::Validate::SCALAR | Params::Validate::UNDEF, optional => 1 },
        }
    );

    my $subject = $self->createSummaryMetadata(
        {
            addresses  => $parameters->{addresses},
            domains    => $parameters->{domains},
            eventTypes => $parameters->{eventTypes},
            keywords   => $parameters->{keywords}
        }
    );

    my $eventType = "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0";

    my %mappings = ();

    my $ls_client = perfSONAR_PS::Client::Parallel::LS->new();
    $ls_client->init();

    foreach my $ls ( @{ $parameters->{ls} } ) {
        my $cookie = $ls_client->add_query( { url => $ls, subject => $subject, event_type => $eventType, format => 1, timeout => 10 } );
        $mappings{$cookie} = $ls;
    }

    my $results = $ls_client->wait_all( { timeout => $parameters->{timeout}, parallelism => $parameters->{parallelism} } );

    $self->{LOGGER}->debug( "Results: " . Dumper( $results ) );

    my %retval = ();

    foreach my $cookie ( keys %mappings ) {
        $self->{LOGGER}->debug( "Checking cookie: $cookie" );
        unless ( $results->{$cookie} ) {
            $self->{LOGGER}->debug( "No results for $cookie" );
            next;
        }

        my $result = $results->{$cookie};
        my $ls     = $mappings{$cookie};

        unless ( $result->{event_type} and $result->{event_type} eq "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0" ) {
            $self->{LOGGER}->debug( "Invalid event type: " . $results->{event_type} ) if ( $result->{event_type} );
            next;
        }

        my %list     = ();
        my @services = ();

        my $service = find( $result->{content}, ".//nmwg:data/nmwg:metadata/*[local-name()='subject']/*[local-name()='service']", 0 );
        if ( $service ) {
            foreach my $s ( $service->get_nodelist ) {
                $self->{LOGGER}->debug( "Found service" );
                my $flag = 1;
                foreach my $element ( keys %{ $parameters->{service} } ) {
                    my $value = q{};
                    if ( $element =~ m/:/ ) {
                        $value = extract( find( $s, "./" . $element . "[text()=\"" . $parameters->{service}->{$element} . "\" or value=\"" . $parameters->{service}->{$element} . "\"]", 1 ), 0 );
                        unless ( $value ) {
                            $flag = 0;
                            last;
                        }
                    }
                    else {
                        $value = extract( find( $s, "./*[local-name()='" . $element . "' and (text()=\"" . $parameters->{service}->{$element} . "\" or value=\"" . $parameters->{service}->{$element} . "\")]", 1 ), 0 );
                        unless ( $value ) {
                            $flag = 0;
                            last;
                        }
                    }
                }
                if ( $flag ) {
                    my $value = $s->toString;
                    my $vh    = md5_hex( $value );
                    push @services, $value if $value and ( not exists $list{$vh} );
                    $list{$vh}++;
                }
            }
        }

        $retval{ $mappings{$cookie} } = \@services;
    }

    return \%retval;
}

=head3 getLSQueryContent( $self, { ls, addresses, domains, eventTypes, keywords } )

Perform query on the supplied hLSes and using the supplied arguments:

 - array of arrays of ip addresses: ( ( ADDRESS, "ipv4"), ( ADDRESS, "ipv6") )
 - array of domains: ( "edu", "udel.edu" )
 - array of eventTypes: ( http://ggf.org/ns/nmwg/tools/owamp/2.0" )
 - hash of service variables: ( 
   { 
     serviceType => "MA", 
     psservice:serviceType => "MA" 
   } 
 )

The result is a list of metadata elements (metadata XML) from registered services.

=cut

sub getLSQueryContent {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            ls          => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            addresses   => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            domains     => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            eventTypes  => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            service     => { type => Params::Validate::HASHREF | Params::Validate::UNDEF,  optional => 1 },
            keywords    => { type => Params::Validate::ARRAYREF | Params::Validate::UNDEF, optional => 1 },
            timeout     => { type => Params::Validate::SCALAR | Params::Validate::UNDEF,   optional => 1 },
            parallelism => { type => Params::Validate::SCALAR | Params::Validate::UNDEF,   optional => 1 },
        }
    );

    my @metadata = ();

    my $query = $self->summaryToXQuery(
        {
            addresses  => $parameters->{addresses},
            domains    => $parameters->{domains},
            eventTypes => $parameters->{eventTypes},
            service    => $parameters->{service},
            keywords   => $parameters->{keywords}
        }
    );

    my $eventType = "http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/query/xquery/2.0";

    my %mappings = ();

    my $ls_client = perfSONAR_PS::Client::Parallel::LS->new();
    $ls_client->init();

    foreach my $ls ( @{ $parameters->{ls} } ) {
        my $cookie = $ls_client->add_query( { xquery => $query, event_type => $eventType, format => 1, timeout => 10 } );
        $mappings{$cookie} = $ls;
    }

    my $results = $ls_client->wait_all( { timeout => $parameters->{timeout}, parallelism => $parameters->{parallelism} } );

    $self->{LOGGER}->debug( "Results: " . Dumper( $results ) );

    my %retval = ();

    foreach my $cookie ( keys %mappings ) {
        $self->{LOGGER}->debug( "Checking cookie $cookie" );

        unless ( $results->{$cookie} ) {
            $self->{LOGGER}->debug( "No results for $cookie" );
            next;
        }

        my @metadata = ();
        my %list     = ();

        my $metadata = find( $results->{$cookie}->{content}, ".//nmwg:metadata", 0 );
        foreach my $m ( $metadata->get_nodelist ) {
            my $value = $m->toString;
            my $vh    = md5_hex( $value );
            push @metadata, $value if $value and ( not exists $list{$vh} );
            $list{$vh}++;
        }

        $retval{ $mappings{$cookie} } = \@metadata;
    }

    return \%retval;
}

=head3 getLSSummaryControlDirect( $self, { } )

Pending Implementation.

=cut

=head3 getLSRegistrationControlDirect( $self, { } )

Not implemented.

=cut

=head2 LEVEL 2 API

The following functions are classified according to the gLS design document
as existing in "Level 2".

=head3 getLSLocation( $self, { addresses, domains, eventTypes, service, keywords } )

Perform query at the root (or through the supplied hLS url) using the supplied
arguments:

 - array of arrays of ip addresses: ( ( ADDRESS, "ipv4"), ( ADDRESS, "ipv6") )
 - array of domains: ( "edu", "udel.edu" )
 - array of eventTypes: ( http://ggf.org/ns/nmwg/tools/owamp/2.0" )
 - hash of service variables: ( 
   { 
     serviceType => "MA", 
     psservice:serviceType => "MA" 
   } 
 )

The result is a list of Service elements (service XML) of services to contact
for more information.

=cut

sub getLSLocation {
    my ( $self, @args ) = @_;
    my $parameters = validateParams(
        @args,
        {
            ls          => 0,
            addresses   => { type => Params::Validate::ARRAYREF, optional => 1 },
            domains     => { type => Params::Validate::ARRAYREF, optional => 1 },
            eventTypes  => { type => Params::Validate::ARRAYREF, optional => 1 },
            service     => { type => Params::Validate::HASHREF, optional => 1 },
            keywords    => { type => Params::Validate::ARRAYREF, optional => 1 },
            parallelism => { type => Params::Validate::SCALAR | Params::Validate::UNDEF, optional => 1 },
        }
    );

    my $hls_array = $self->getLSDiscovery(
        {
            addresses  => $parameters->{addresses},
            domains    => $parameters->{domains},
            eventTypes => $parameters->{eventTypes},
            keywords   => $parameters->{keywords}
        }
    );

    my @services = ();

    if ( $hls_array ) {
        $self->{LOGGER}->debug( "HLS Array: " . Dumper( $hls_array ) );

        my $results = $self->getLSQueryLocation(
            {
                ls         => $hls_array,
                addresses  => $parameters->{addresses},
                domains    => $parameters->{domains},
                eventTypes => $parameters->{eventTypes},
                service    => $parameters->{service},
                keywords   => $parameters->{keywords}
            }
        );

        $self->{LOGGER}->debug( "RESULTS: " . Dumper( $results ) );

        foreach my $ls ( keys %{$results} ) {
            push @services, @{ $results->{$ls} } if ( $results->{$ls} );
        }
    }

    return \@services;
}

1;

__END__

=head1 SYNOPSIS

    #!/usr/bin/perl -w

    use strict;
    use warnings;

    use perfSONAR_PS::Client::gLS;
    use Data::Dumper;
    my $url = "http://dc211.internet2.edu/gls.root.hints";
    my $hls = "http://dc211.internet2.edu:8080/perfSONAR_PS/services/LS";

    my $gls = perfSONAR_PS::Client::gLS->new( { url => $url} );
    foreach my $root ( @{ $gls->{ROOTS} } ) {
        print "Root:\t" , $root , "\n";
    }

    unless ( $#{ $gls->{ROOTS} } > -1 ) {
        print "Root not found, exiting...\n";
        exit(1);
    }

    my $result = $gls->getLSDiscoverRaw( { xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:metadata" } );
    print Dumper($result) , "\n"; 
        
    my $result = $gls->getLSQueryRaw( { ls => $hls, xquery => "/nmwg:store[\@type=\"LSStore\"]/nmwg:metadata" } );
    print Dumper($result) , "\n"; 

    # baselines:
    my @ipaddresses = ();
    my @eventTypes = ();
    my @domains = ("edu");
    my @keywords = ();
    my %service = ();

    $result = $gls->getLSDiscovery( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
    print Dumper($result) , "\n"; 
    
    $result = $gls->getLSQueryLocation( { ls => $h, addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
    print Dumper($result) , "\n"; 
    
    $result = $gls->getLSQueryContent( { ls => $h, addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
    print Dumper($result) , "\n"; 
    
    $result = $gls->getLSLocation( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
    print Dumper($result) , "\n"; 
    
    $result = $gls->getLSContent( { addresses => \@ipaddresses, domains => \@domains, eventTypes => \@eventTypes, service => \%service, keywords => \@keywords } );
    print Dumper($result) , "\n"; 

=head1 SEE ALSO

L<Log::Log4perl>, L<Params::Validate>, L<English>, L<LWP::Simple>, L<Net::Ping>,
L<XML::LibXML>, L<Digest::MD5>, L<perfSONAR_PS::Utils::ParameterValidation>,
L<perfSONAR_PS::Client::Echo>, L<perfSONAR_PS::Client::LS>,
L<perfSONAR_PS::Common>
 
To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: gLS.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework along
with this software.  If not, see <http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

