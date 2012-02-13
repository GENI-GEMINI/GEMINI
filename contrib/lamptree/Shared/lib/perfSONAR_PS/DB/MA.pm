package perfSONAR_PS::DB::MA;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::DB::MA

=head1 DESCRIPTION

Simple database accessor class for the remote storage of local dom (LibXML) from
say MP's.  Could potentially be used as a proxy class in future to redirect
storage calls.

=cut

use XML::LibXML;
use perfSONAR_PS::Transport;
use Log::Log4perl qw(get_logger);
use English qw( -no_match_vars );

my $logger = get_logger( "perfSONAR_PS::DB::MA" );

=head2 new($package, $host, $port, $endpoint)

Create a new object.

=cut

sub new {
    my ( $package, $host, $port, $endpoint ) = @_;
    my %hash = ();
    if ( defined $host and $host ) {
        $hash{"HOST"} = $host;
    }
    if ( defined $port and $port ) {
        $hash{"PORT"} = $port;
    }
    if ( defined $endpoint and $endpoint ) {
        $hash{"ENDPOINT"} = $endpoint;
    }

    bless \%hash => $package;
    return;
}

=head2 setFile($self, $file)

Set the value of the file

=cut

sub setFile {
    my ( $self, $file ) = @_;

    if ( defined $file and $file ) {
        $self->{FILE} = $file;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 setHost

Set the value of the MA host

=cut

sub setHost {
    my ( $self, $host ) = @_;

    if ( defined $host and $host ) {
        $self->{HOST} = $host;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 setPort($self, $port)

Set the value of the MA port

=cut

sub setPort {
    my ( $self, $port ) = @_;

    if ( defined $port and $port ) {
        $self->{PORT} = $port;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 setEndpoint($self, $endPoint)

Set the value of the MA endpoint

=cut

sub setEndpoint {
    my ( $self, $endpoint ) = @_;

    if ( defined $endpoint and $endpoint ) {
        $self->{ENDPOINT} = $endpoint;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 openDB($self)

Open the database.

=cut

sub openDB {
    my ( $self ) = @_;
    if ( defined $self->{HOST} && defined $self->{PORT} && defined $self->{ENDPOINT} ) {

        eval {
            $self->{"TRANSACTION"} = new perfSONAR_PS::Transport( $self->{HOST}, $self->{PORT}, $self->{ENDPOINT} );

            #$logger->debug( "SETUP: "  . $self->{"TRANSACTION"});
        };

        # more specific error?
        if ( $EVAL_ERROR ) {
            $logger->error( "Cannot open connection to " . $self->{HOST} . ':' . $self->{PORT} . '/' . $self->{ENDPOINT} . "." );
        }
    }
    else {
        $logger->error( "Connection settings missing: " . $self->{HOST} . ':' . $self->{PORT} . '/' . $self->{ENDPOINT} . "." );
    }
    return;
}

=head2 closeDB($self)

Close the database.

=cut

sub closeDB {
    my ( $self ) = @_;

    if ( defined $self->{TRANSACTION} and $self->{TRANSACTION} ) {

        # no state, so nothing to close
    }
    else {
        $logger->error( "No connection to remote MA defined." );
    }
    return;
}

=head2 getDOM($self)

Get the value of the Internal XML dom.

=cut

sub getDOM {
    my ( $self ) = @_;
    my $logger = get_logger( "perfSONAR_PS::DB::File" );
    if ( exists $self->{XML} and $self->{XML} ) {
        return $self->{XML};
    }
    else {
        $logger->error( "LibXML DOM structure not defined." );
    }
    return;
}

=head2 setDOM($self, $dom)

Set the value of the internal XML dom.

=cut

sub setDOM {
    my ( $self, $dom ) = @_;
    if ( defined $dom and $dom ) {
        $self->{XML} = $dom;
    }
    else {
        $logger->error( "Missing argument." );
    }
    return;
}

=head2 insert($self, $dom)

Given a DOM, insert the values.

=cut

sub insert {
    my $self = shift;
    my $dom  = shift;

    if ( defined $dom ) {
        $self->setDOM( $dom );
    }

    if ( defined $self->{"TRANSACTION"} ) {
        if ( defined $self->{XML} ) {

            # Make a SOAP envelope, use the XML file as the body.
            #$logger->debug( "TRANSACTION: " . $self->{"TRANSACTION"} );
            my $envelope = $self->{"TRANSACTION"}->makeEnvelope( $self->{XML} );

            # Send/receive to the server, store the response for later processing
            my $responseContent = $self->{"TRANSACTION"}->sendReceive( $envelope );

            # TODO: should a remote ma respond with anything? like a confirmation?
            #$logger->debug( "RESPONSE: $responseContent");
        }
        else {
            $logger->error( "Could not insert blank document." );
        }

    }
    else {
        $logger->error( "Transaction has not been setup." );
    }
    return;
}

1;

__END__

=head1 SEE ALSO

L<XML::LibXML>, L<perfSONAR_PS::Transport>, L<Log::Log4perl>, L<English>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: MA.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Yee-Ting Li, ytl@slac.stanford.edu
Jason Zurawski, zurawski@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2, the University of Delaware, and SLAC National Accelerator Laboratory

All rights reserved.

=cut
