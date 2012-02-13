package  perfSONAR_PS::DataModels::PingER_Topology;

use strict;
use warnings;

use version;
our $VERSION = '2.0';

=head1 NAME

perfSONAR_PS::DataModels::PingER_Topology
 
=head1 DESCRIPTION

perfSONAR pinger topology schema  expressed in perl.  'pingertopo' extension of
the perfSONAR_PS RelaxNG Compact schema for  the perfSONAR services metadata,
see:  
    
  http://anonsvn.internet2.edu/svn/nmwg/trunk/nmwg/schema/rnc/pinger-landmarks.rnc
    
=cut

our @EXPORT    = qw( );
our @EXPORT_OK = qw($pingertopo  $port   $node $domain);

=head1 Exported Variables
 
$pingertopo  $port   $node $domain

=cut

our ( $pingertopo, $port, $parameters, $parameter, $location, $contact, $basename, $node, $domain, $textnode_nmtb );

use perfSONAR_PS::DataModels::Base_Model 2.0 qw($addressL3);

$port = {
    attrs => { id => 'scalar', xmlns => 'nmtl3' },
    elements => [ [ ipAddress => $addressL3 ], ],
};

$parameter = {
    attrs => {
        name  => 'enum:count,packetInterval,packetSize,ttl,measurementPeriod,measurementOffset,project',
        value => 'scalar',
        xmlns => 'nmwg'
    },
    elements => [],
    text     => 'unless:value',
};

$parameters = {
    attrs => { id => 'scalar', xmlns => 'nmwg' },
    elements => [ [ parameter => [$parameter] ], ],
};

$basename = {
    attrs    => { type => 'scalar', xmlns => 'nmtb' },
    elements => [],
    text     => 'scalar',
};

$location = {
    attrs    => { xmlns => 'nmtb' },
    elements => [
        [ continent     => 'text' ],
        [ country       => 'text' ],
        [ zipcode       => 'text' ],
        [ state         => 'text' ],
        [ institution   => 'text' ],
        [ city          => 'text' ],
        [ streetAddress => 'text' ],
        [ floor         => 'text' ],
        [ room          => 'text' ],
        [ cage          => 'text' ],
        [ rack          => 'text' ],
        [ shelf         => 'text' ],
        [ latitude      => 'text' ],
        [ longitude     => 'text' ],
    ],
};

$contact = {
    attrs => { xmlns => 'nmtb' },
    elements => [ [ email => 'text' ], [ phoneNumber => 'text' ], [ administrator => 'text' ], [ institution => 'text' ], ],
};

$textnode_nmtb = {
    attrs    => { xmlns => 'nmtb' },
    elements => [],
    text     => 'scalar',
};

$node = {
    attrs => { id => 'scalar', metadataIdRef => 'scalar', xmlns => 'pingertopo' },
    elements => [ [ name => $basename ], [ hostName => $textnode_nmtb ], [ description => $textnode_nmtb ], [ location => $location ], [ contact => $contact ], [ parameters => $parameters ], [ port => $port ], ],
};

$domain = {
    attrs => { id => 'scalar', xmlns => 'pingertopo' },
    elements => [ [ comments => $textnode_nmtb ], [ node => [$node] ], ],
};

$pingertopo = {
    attrs => { xmlns => 'pingertopo' },
    elements => [ [ domain => [$domain] ], ],
};

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

$Id: PingER_Topology.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
