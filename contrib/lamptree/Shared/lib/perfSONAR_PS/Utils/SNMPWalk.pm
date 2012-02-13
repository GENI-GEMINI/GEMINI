package perfSONAR_PS::Utils::SNMPWalk;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::Utils::SNMPWalk

=head1 DESCRIPTION

SNMP Walk utility

=cut

use Net::SNMP qw(:snmp DEBUG_ALL);
use Exporter;

use base 'Exporter';
our @EXPORT = qw( snmpwalk );

=head2 snmpwalk($host, $port, $oid, $community, $version)

Walk a network device with snmp given some basic information

=cut

sub snmpwalk {
    my ( $host, $port, $oid, $community, $version ) = @_;

    unless ( $host ) {
        return ( -1, "No host specified" );
    }

    # Create the SNMP session
    my ( $s, $e ) = Net::SNMP->session(
        -hostname => $host,
        ( defined $port      and $port )      ? ( -port      => $port )      : (),
        ( defined $community and $community ) ? ( -community => $community ) : (),
        ( defined $version   and $version )   ? ( -version   => $version )   : (),
    );

    # Was the session created?
    unless ( defined( $s ) ) {
        return ( -1, "Couldn't create session" );
    }

    # Perform repeated get-next-requests or get-bulk-requests (SNMPv2c)
    # until the last returned OBJECT IDENTIFIER is no longer a child of
    # OBJECT IDENTIFIER passed in on the command line.

    my @args = ( -varbindlist => [$oid] );

    my @results = ();
    if ( $s->version == SNMP_VERSION_1 ) {

        my $oid;

        while ( defined( $s->get_next_request( @args ) ) ) {
            $oid = ( $s->var_bind_names() )[0];

            if ( !oid_base_match( $ARGV[0], $oid ) ) { last; }

            my @result = ( $oid, snmp_type_ntop( $s->var_bind_types()->{$oid} ), $s->var_bind_list()->{$oid} );
            push @results, \@result;

            @args = ( -varbindlist => [$oid] );
        }

    }
    else {

        push( @args, -maxrepetitions => 25 );

    outer: while ( defined( $s->get_bulk_request( @args ) ) ) {

            my @oids = oid_lex_sort( keys( %{ $s->var_bind_list() } ) );

            foreach ( @oids ) {

                unless ( oid_base_match( $oid, $_ ) ) { last outer; }

                my @result = ( $_, snmp_type_ntop( $s->var_bind_types()->{$_} ), $s->var_bind_list()->{$_} );
                push @results, \@result;

                # Make sure we have not hit the end of the MIB
                if ( $s->var_bind_list()->{$_} eq 'endOfMibView' ) { last outer; }
            }

            # Get the last OBJECT IDENTIFIER in the returned list
            @args = ( -maxrepetitions => 25, -varbindlist => [ pop( @oids ) ] );
        }
    }

    # Let the user know about any errors
    if ( $s->error() ne q{} ) {
        return ( -1, $s->error() );
    }

    # Close the session
    $s->close();

    return ( 0, \@results );
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: SNMPWalk.pm 2646 2009-03-20 16:10:57Z aaron $

=head1 AUTHOR

David M. Town, dtown@cpan.org
Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2000-2009, David M. Town and Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
