package  perfSONAR_PS::DataModels::Base_Model;

use strict;
use warnings;

use version;
our $VERSION = '2.0';

=head1 NAME

perfSONAR_PS::DataModels:Base_Model

=cut

=head1 DESCRIPTION

perfSONAR base schema  expressed in perl, used to build binding perl objects
collection.  perfSONAR base schema with several base extensions, see:

  http://anonsvn.internet2.edu/svn/nmwg/trunk/nmwg/schema/rnc/nmbase.rnc 
  http://anonsvn.internet2.edu/svn/nmwg/trunk/nmwg/schema/rnc/event.rnc
  http://anonsvn.internet2.edu/svn/nmwg/trunk/nmwg/schema/rnc/nmtopo-l3.rnc
  http://anonsvn.internet2.edu/svn/nmwg/trunk/nmwg/schema/rnc/nmtopo-l4.rnc
  http://anonsvn.internet2.edu/svn/nmwg/trunk/nmwg/schema/rnc/nmtopo.rnc

=cut

use Exporter ();
use base 'Exporter';

=head1 Exported Variables ( on demand )
 
 $message $metadata   $data   $resultDatum   $key $endPointPairL4  $endPointL4 $commonTime 
 $endPointPairL3 $interfaceL3 $addressL4 $addressL3 $endPointPair $key 
 $time $event_datum  $parameter $parameters
 $endPoint $message $metadata  

=head1 Exported Callbacks ( through closures)
		      
 $service_parameters   $service_parameter  $service_subject $service_datum 

=cut

our @EXPORT    = qw( );
our @EXPORT_OK = qw( $message $metadata   $data   $resultDatum   $key $endPointPairL4  $endPointL4 $commonTime
    $endPointPairL3 $interfaceL3 $addressL4 $addressL3 $endPointPair $key  $time $event_datum  $parameter $parameters
    $endPoint $service_parameters $service_subject $service_parameter $service_datum
);

our (
    $message,      $metadata, $data, $key,        $endPointPairL4, $resultDatum,        $commonTime,      $endPointL4,        $endPointPairL3, $interfaceL3, $addressL4, $addressL3,
    $endPointPair, $subject,  $time, $parameters, $parameter,      $service_parameters, $service_subject, $service_parameter, $service_datum,  $event_datum, $endPoint
);

$subject = {
    attrs    => { id => 'scalar', metadataIdRef => 'scalar', xmlns => 'nmwg' },
    elements => [],
};

$parameter = {
    attrs => { name => 'scalar', value => 'scalar', xmlns => 'nmwg' },
    text  => 'unless:value',
};

### callback to add choice of different parameter elements

sub addParameter {
    my $extras = [ [$parameter] ];
    return sub {
        push @{$extras}, [@_] if @_;
        return $extras;
        }
}
$service_parameter = addParameter();

$parameters = {
    attrs    => { id => 'scalar', xmlns => 'nmwg' },
    elements => [
        [ parameter => $service_parameter->() ],

    ],
};

### callback to add choice of different parameters elements

sub addParameters {
    my $extras = [ [$parameters] ];
    return sub {
        push @{$extras}, [@_] if @_;
        return $extras;
        }
}

$service_parameters = addParameters();

### callback to add choice of different subject  elements

sub addSubject {
    my $extras = [$subject];
    return sub {
        push @{$extras}, @_ if @_;
        return $extras;
        }
}
$service_subject = addSubject();

foreach my $filters ( qw/select average mean median max min cdf histogram/ ) {
    $service_parameters->(
        {
            attrs => { id => 'scalar', xmlns => $filters },
            elements => [ [ parameter => [$parameter] ], ],
        }
    );

    $service_subject->(
        {
            attrs    => { id => 'scalar', metadataIdRef => 'scalar', xmlns => $filters },
            elements => [],
        }
    );
}

$key = {
    attrs => { id => 'scalar', xmlns => 'nmwg' },
    elements => [ [ parameters => [$parameters] ], ],
};

$resultDatum = {
    attrs    => { type => 'scalar', xmlns => 'nmwgr' },
    elements => [],
    text     => 'scalar',
};

### callback to add choice of different datum  elements

sub addDatum {
    my $extras = [ [$resultDatum] ];
    return sub {
        push @{$extras}, [@_] if @_;
        return $extras;
        }
}
$service_datum = addDatum();

$time = {
    attrs    => { type => 'scalar', value => 'scalar', duration => 'scalar', inclusive => 'scalar', xmlns => 'nmtm' },
    elements => [],
    text     => 'unless:value',
};

$event_datum = {
    attrs    => { timeType => 'scalar', timeValue => 'scalar', xmlns => 'ifevt' },
    elements => [
        [ time       => $time, 'unless:timeValue,timeType' ],
        [ stateAdmin => 'text' ],
        [ stateOper  => 'text' ],

    ],

};

$addressL4 = {
    attrs    => { value => 'scalar', type => 'scalar', xmlns => 'nmtl4' },
    elements => [],
    text     => 'unless:value',

};

$addressL3 = {
    attrs    => { value => 'scalar', type => 'scalar', xmlns => 'nmtl3' },
    elements => [],
    text     => 'unless:value',

};

$interfaceL3 = {
    attrs => { id => 'scalar', interfaceIdRef => 'scalar', xmlns => 'nmtl3' },
    elements => [ [ ipAddress => $addressL3 ], [ netmask => 'text' ], [ ifName => 'text' ], [ ifDescription => 'text' ], [ ifAddress => $addressL3 ], [ ifHostName => 'text' ], [ ifIndex => 'text' ], [ type => 'text' ], [ capacity => 'text' ], ],
    text => 'unless:ipAddress',

};

$endPointL4 = {
    attrs => { port => 'scalar', protocol => 'scalar', role => 'enum:src,dst', xmlns => 'nmtl4' },
    elements => [ [ address => $addressL4 ], [ interface => $interfaceL3, 'unless:address' ], ],
};

$endPointPairL4 = {
    attrs => { xmlns => 'nmtl4' },
    elements => [ [ endPoint => [$endPointL4] ], ],
};
$endPoint = {
    attrs    => { value => 'scalar', type => 'scalar', port => 'scalar', xmlns => 'nmwgt' },
    elements => [],
    text     => 'unless:value',
};

$endPointPair = {
    attrs => { xmlns => 'nmwgt' },
    elements => [ [ src => $endPoint ], [ dst => $endPoint ], ],

};

$commonTime = {
    attrs => { type => 'scalar', value => 'scalar', duration => 'scalar', inclusive => 'scalar', xmlns => 'nmwg' },
    elements => [ [ 'start' => $time, 'unless:value' ], [ 'end' => $time, 'if:value,start' ], [ datum => $service_datum->() ], ],

};

$data = {
    attrs => { id => 'scalar', metadataIdRef => 'scalar', xmlns => 'nmwg' },
    elements => [ [ commonTime => [$commonTime] ], [ datum => $service_datum->(), 'unless:commonTime' ], [ key => $key, 'unless:commonTime,datum' ], ],

};

$metadata = {
    attrs => { id => 'scalar', metadataIdRef => 'scalar', xmlns => 'nmwg' },
    elements => [ [ subject => $service_subject->() ], [ parameters => $service_parameters->() ], [ eventType => 'text' ], [ key => $key ], ],
};

$message = {
    attrs => { id => 'scalar', type => 'scalar', xmlns => 'nmwg' },
    elements => [ [ parameters => $service_parameters->() ], [ metadata => [$metadata] ], [ data => [$data] ] ],
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

$Id: Base_Model.pm 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
