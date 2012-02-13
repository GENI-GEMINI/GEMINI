package perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting;

use strict;
use warnings;

our $VERSION = 3.1;

=head1 NAME

perfSONAR_PS::NPToolkit::Config::Handlers::RegularTesting;

=head1 DESCRIPTION

TODO:

=cut

use base 'perfSONAR_PS::NPToolkit::Config::Handlers::Base';

use Log::Log4perl qw(get_logger :nowarn);
use Params::Validate qw(:all);
use Storable qw(dclone);

use perfSONAR_PS::Common qw(extract extract_first);

use fields 'LOCAL_PORT_RANGES', 'TESTS';

use constant RTEST_PSCONFIG_NS => 'http://ogf.org/schema/network/topology/psconfig/regtesting/20100914/';

=head2 init({ service => 1 })
    Initializes the module.
=cut

sub init {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    $self->SUPER::init( @params );
    
    $self->{TESTS} = {};
    $self->{LOCAL_PORT_RANGES} = {};
    
    return 0;
}

sub load_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    $self->SUPER::load_encoded( @params );
    
    $self->{TESTS} = {};
    $self->{LOCAL_PORT_RANGES} = {};
    
    my $service = $parameters->{service};
    
    foreach my $port_range ( $service->getChildrenByTagNameNS( RTEST_PSCONFIG_NS, "localPortRange" ) ) {
        my $test_type = $port_range->getAttribute( "testType" );
        my $min_port  = $port_range->getAttribute( "minPort" );
        my $max_port  = $port_range->getAttribute( "maxPort" );
        
        $self->{LOCAL_PORT_RANGES}->{$test_type}->{min_port} = $min_port;
        $self->{LOCAL_PORT_RANGES}->{$test_type}->{max_port} = $max_port;
    }
    
    foreach my $test ( $service->getChildrenByTagNameNS( RTEST_PSCONFIG_NS, "test" ) ) {
        my $id          = $test->getAttribute( "id" );
        my $type        = $test->getAttribute( "type" );
        my $mesh_type   = extract_first( $test, "meshType", RTEST_PSCONFIG_NS, 1 );
        my $name        = extract_first( $test, "name", RTEST_PSCONFIG_NS, 0, 1 );
        my $description = extract_first( $test, "description", RTEST_PSCONFIG_NS, 0, 1 );
        
        my %parameters = ();
        foreach my $param ( $test->getElementsByTagNameNS( RTEST_PSCONFIG_NS, "parameter" ) ) {
            $parameters{ $param->getAttribute( "name" ) } = extract( $param, 0, 1 );
        }
        
        my %members = ();
        foreach my $member (  $test->getElementsByTagNameNS( RTEST_PSCONFIG_NS, "member" ) ) {
            $members{ $member->getAttribute( "id" ) } = {
                id          => $member->getAttribute( "id" ),
                address     => extract_first( $member, "address", RTEST_PSCONFIG_NS, 1 ),
                name        => extract_first( $member, "name", RTEST_PSCONFIG_NS, 0, 1 ),
                port        => extract_first( $member, "port", RTEST_PSCONFIG_NS, 1 ),
                description => extract_first( $member, "description", RTEST_PSCONFIG_NS, 0, 1 ),
                sender      => extract_first( $member, "sender", RTEST_PSCONFIG_NS, 1 ),
                receiver    => extract_first( $member, "receiver", RTEST_PSCONFIG_NS, 1 ),
            };
        }
        
        $self->{TESTS}->{ $id } = {
            id          => $id,
            type        => $type,
            name        => $name,
            mesh_type   => $mesh_type,
            description => $description,
            parameters  => \%parameters,
            members     => \%members,
        };
    }
    
    $self->{EMPTY} = 0 if ( keys %{ $self->{TESTS} } or keys %{ $self->{LOCAL_PORT_RANGES} } );
    
    return 0;    
}

sub update_encoded {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { service => 1, } );
    
    return 0 unless $self->{MODIFIED};
    
    $self->SUPER::update_encoded( @params );
    
    my $service = $parameters->{service};
    
    # XXX: We replace the whole content. (Not extensible.)
    $service->removeChildNodes();
    my $dom = $service->ownerDocument();
    
    foreach my $port_range_type ( keys %{ $self->{LOCAL_PORT_RANGES} } ) {
        my $port_range = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:localPortRange" );
        $service->addChild( $port_range );
        
        $port_range->setAttribute( "testType", $port_range_type );
        $port_range->setAttribute( "minPort", $self->{LOCAL_PORT_RANGES}->{$port_range_type}->{min_port} );
        $port_range->setAttribute( "maxPort", $self->{LOCAL_PORT_RANGES}->{$port_range_type}->{max_port} );
    }
    
    foreach my $test_id ( keys %{ $self->{TESTS} } ) {
        my $test = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:test" );
        $service->addChild( $test );
        
        $test->setAttribute( "id", $test_id );
        $test->setAttribute( "type", $self->{TESTS}->{$test_id}->{type} );
        
        foreach my $keys ( ( ['mesh_type', 'meshType'], ['name', 'name'], ['description', 'description'] ) ) {
            if ( exists $self->{TESTS}->{$test_id}->{$keys->[0]} and $self->{TESTS}->{$test_id}->{$keys->[0]} ) {
                my $element = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:" . $keys->[1] );
                $test->addChild( $element );
                
                $element->appendText( $self->{TESTS}->{$test_id}->{$keys->[0]} );
            }
        }
        
        my $parameters = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:parameters" );
        $test->addChild( $parameters );
        
        foreach my $param_name ( keys %{ $self->{TESTS}->{$test_id}->{parameters} } ) {
            my $param = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:parameter" );
            $parameters->addChild( $param );
            
            $param->setAttribute( "name", $param_name );
            $param->setAttribute( "value", $self->{TESTS}->{$test_id}->{parameters}->{$param_name} );
            
        }
        
        my $members = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:members" );
        $test->addChild( $members );
        
        foreach my $member_id ( keys %{ $self->{TESTS}->{$test_id}->{members} } ) {
            my $member = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:member" );
            $members->addChild( $member );
            
            $member->setAttribute( "id", $member_id );
            
            foreach my $key ( ('address', 'name', 'port', 'description', 'sender', 'receiver' ) ) {
                my $member_ref = $self->{TESTS}->{$test_id}->{members}->{$member_id};
                if ( exists $member_ref->{$key} and $member_ref->{$key} ) {
                    my $element = $dom->createElementNS( RTEST_PSCONFIG_NS, "regtest:$key" );
                    $member->addChild( $element );
                    
                    $element->appendText( $member_ref->{$key} );
                }
            }
        }
    }
    
    return 0;
}

# TODO: Maybe shouldn't always set MODIFIED
sub set_tests {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { tests => 1, } );
    
    $self->{TESTS} = dclone( $parameters->{tests} );
    $self->{MODIFIED} = 1;
    
    return $self->{MODIFIED};
}

sub set_local_port_ranges {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, { local_port_ranges => 1, } );
    
    $self->{LOCAL_PORT_RANGES} = dclone( $parameters->{local_port_ranges} );
    $self->{MODIFIED} = 1;
    
    return $self->{MODIFIED};
}

=head2 get_tests({ })
    Returns the list of tests as a hash indexed by id.
=cut

sub get_tests {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{TESTS};
}

=head2 get_local_port_ranges({ })
    Returns the list of local_port_ranges as a hash indexed by test type.
=cut

sub get_local_port_ranges {
    my ( $self, @params ) = @_;
    my $parameters = validate( @params, {} );

    return $self->{LOCAL_PORT_RANGES};
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

$Id$

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2008-2009, Internet2

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
