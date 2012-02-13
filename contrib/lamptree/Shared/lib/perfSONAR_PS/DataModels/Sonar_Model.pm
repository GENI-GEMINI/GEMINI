package  perfSONAR_PS::DataModels::Sonar_Model;

use strict;
use warnings;

use version;
our $VERSION = '2.0';

=head1 NAME

perfSONAR_PS::DataModels::Sonar_Model
 
=head1 DESCRIPTION

perfSONAR schemas expressed in perl, used to build binding perl objects
collection.  'sonar' extension  of the perfSONAR_PS RelaxNG Compact schema for
the perfSONAR services metadata ( perfsonar NS) see:

  http://anonsvn.internet2.edu/svn/nmwg/trunk/nmwg/schema/rnc/sonar.rnc
   
=cut

use Exporter ();
use base 'Exporter';

=head1 Exported Variables
 
$message

=cut

our @EXPORT    = qw();
our @EXPORT_OK = qw($message);
use perfSONAR_PS::DataModels::Base_Model 2.0 qw($endPointPair $interfaceL3    $endPointL4   $service_parameter
    $service_subject $parameter $service_parameters $metadata $data
    $message   $service_datum $event_datum    $endPointPairL4);

our ( $service_element );

$service_datum->( $event_datum );

$service_parameters->(
    {
        attrs => { id => 'scalar', xmlns => 'psservice' },
        elements => [ [ parameter => $service_parameter->() ], ],
    }
);

$service_element = {
    attrs => { id => 'scalar', xmlns => 'psservice' },
    elements => [ [ serviceName => 'text' ], [ accessPoint => 'text' ], [ serviceType => 'text' ], [ serviceDescription => 'text' ], ],

};

$service_subject->(
    {
        attrs => { id => 'scalar', xmlns => 'psservice' },
        elements => [ [ service => $service_element ], ],
        text => 'unless:service',
    }
);

foreach my $subj ( qw/xpath sql xquery/ ) {
    $service_subject->(
        {
            attrs    => { id => 'scalar', xmlns => $subj },
            elements => [],
            text     => 'scalar',
        }
    );
    $service_parameters->(
        {
            attrs => { id => 'scalar', xmlns => $subj },
            elements => [ [ parameter => [$parameter] ], ],
        }
    );
}

$service_subject->(
    {
        attrs => { id => 'scalar', metadataIdRef => 'scalar', xmlns => 'perfsonar' },
        elements => [ [ interface => $interfaceL3 ], [ endPointPair => [ $endPointPair, $endPointPairL4 ], 'unless:interface' ], [ service => $service_element ], ],
    }
);

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

$Id: Sonar_Model.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut 
