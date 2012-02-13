use warnings;
use strict;
 
=head1 NAME 
             
ps_schemaPXB.pl - example of the data model definitions and API building script
                  utilization for perfSONAR-PS project

=head1 DESCRIPTION

run this script - perl -I ../lib ps_schemaPXB.pl,
it will create  temp  directory with all modules and temp/t directory with test
files, chdir to temp and run perl ./test.pl to test generated API.
See L<DataModel.pm>,L<SOnar_Model.pm> and PingER_Model.pm> for model
definitions. Please note how data model modules loaded. In order to eliminate
namespace conflicts its done at the runtime.

This is the real life example and generated classes are currently utilized by
perfSONAR-PS webservices.

=cut

use English qw( -no_match_vars);
use XML::RelaxNG::Compact::PXB 0.14;
use POD::Credentials;
use Data::Dumper;
use FindBin qw($Bin);

BEGIN {
    use Log::Log4perl qw(:easy :levels);
    Log::Log4perl->easy_init( $DEBUG );
}

my $logger = get_logger( "ps_schemaPXB" );

# top dir for the generated API
my $TOP_DIR = $Bin . '/../lib';

# namespace registries for each schema

my %NSS = (
    'PINGER_DATATYPES' => {
        'xsd'       => "http://www.w3.org/2001/XMLSchema",
        'xsi'       => "http://www.w3.org/2001/XMLSchema-instance",
        'SOAP-ENV'  => "http://schemas.xmlsoap.org/soap/envelope/",
        'nmwg'      => "http://ggf.org/ns/nmwg/base/2.0/",
        'nmwgr'     => "http://ggf.org/ns/nmwg/result/2.0/",
        'select'    => "http://ggf.org/ns/nmwg/ops/select/2.0/",
        'cdf'       => "http://ggf.org/ns/nmwg/ops/cdf/2.0/",
        'average'   => "http://ggf.org/ns/nmwg/ops/average/2.0/",
        'histogram' => "http://ggf.org/ns/nmwg/ops/histogram/2.0/",
        'median'    => "http://ggf.org/ns/nmwg/ops/median/2.0/",
        'max'       => "http://ggf.org/ns/nmwg/ops/max/2.0/",

        'min'  => "http://ggf.org/ns/nmwg/ops/min/2.0/",
        'mean' => "http://ggf.org/ns/nmwg/ops/mean/2.0/",

        'pingertopo' => "http://ogf.org/ns/nmwg/tools/pinger/landmarks/1.0/",
        'pinger'     => "http://ggf.org/ns/nmwg/tools/pinger/2.0/",
        'average'    => "http://ggf.org/ns/nmwg/ops/average/2.0/",
        'nmwgt'      => "http://ggf.org/ns/nmwg/topology/2.0/",
        'topo'       => "http://ggf.org/ns/nmwg/topology/2.0/",

        'nmtl4' => "http://ogf.org/schema/network/topology/l4/20070707",
        'nmtl3' => "http://ogf.org/schema/network/topology/l3/20070707",

        'nmtl2'  => "http://ogf.org/schema/network/topology/l2/20070707/",
        'nmtopo' => "http://ogf.org/schema/network/topology/base/20070707/",
        'nmtb'   => "http://ogf.org/schema/network/topology/base/20070707/",

        'nmtm' => "http://ggf.org/ns/nmwg/time/2.0/"
    },

    'PINGERTOPO_DATATYPES' => {

        'xsd'        => "http://www.w3.org/2001/XMLSchema",
        'xsi'        => "http://www.w3.org/2001/XMLSchema-instance",
        'SOAP-ENV'   => "http://schemas.xmlsoap.org/soap/envelope/",
        'nmwg'       => "http://ggf.org/ns/nmwg/base/2.0/",
        'nmwgr'      => "http://ggf.org/ns/nmwg/result/2.0/",
        'select'     => "http://ggf.org/ns/nmwg/ops/select/2.0/",
        'pingertopo' => "http://ogf.org/ns/nmwg/tools/pinger/landmarks/1.0/",
        'pinger'     => "http://ggf.org/ns/nmwg/tools/pinger/2.0/",
        'nmwgt'      => "http://ggf.org/ns/nmwg/topology/2.0/",
        'topo'       => "http://ggf.org/ns/nmwg/topology/2.0/",

        'nmtl4' => "http://ogf.org/schema/network/topology/l4/20070707",
        'nmtl3' => "http://ogf.org/schema/network/topology/l3/20070707",

        'nmtl2'  => "http://ogf.org/schema/network/topology/l2/20070707/",
        'nmtopo' => "http://ogf.org/schema/network/topology/base/20070707/",
        'nmtb'   => "http://ogf.org/schema/network/topology/base/20070707/",
        'nmtm'   => "http://ggf.org/ns/nmwg/time/2.0/"
    },

    'SONAR_DATATYPES' => {
        'xsd'       => "http://www.w3.org/2001/XMLSchema",
        'xsi'       => "http://www.w3.org/2001/XMLSchema-instance",
        'SOAP-ENV'  => "http://schemas.xmlsoap.org/soap/envelope/",
        'nmwg'      => "http://ggf.org/ns/nmwg/base/2.0/",
        'nmwgr'     => "http://ggf.org/ns/nmwg/result/2.0/",
        'select'    => "http://ggf.org/ns/nmwg/ops/select/2.0/",
        'cdf'       => "http://ggf.org/ns/nmwg/ops/cdf/2.0/",
        'average'   => "http://ggf.org/ns/nmwg/ops/average/2.0/",
        'histogram' => "http://ggf.org/ns/nmwg/ops/histogram/2.0/",
        'median'    => "http://ggf.org/ns/nmwg/ops/median/2.0/",
        'max'       => "http://ggf.org/ns/nmwg/ops/max/2.0/",

        'min'        => "http://ggf.org/ns/nmwg/ops/min/2.0/",
        'mean'       => "http://ggf.org/ns/nmwg/ops/mean/2.0/",
        'ifevt'      => 'http://ggf.org/ns/nmwg/event/status/base/2.0/',
        'pingertopo' => "http://ogf.org/ns/nmwg/tools/pinger/landmarks/1.0/",
        'netutil'    => "http://ggf.org/ns/nmwg/characteristic/utilization/2.0/",

        'traceroute' => "http://ggf.org/ns/nmwg/tools/traceroute/2.0/",
        'snmp'       => "http://ggf.org/ns/nmwg/tools/snmp/2.0/",
        'ping'       => "http://ggf.org/ns/nmwg/tools/ping/2.0/",
        'owamp'      => "http://ggf.org/ns/nmwg/tools/owamp/2.0/",
        'bwctl'      => "http://ggf.org/ns/nmwg/tools/bwctl/2.0/",
        'pinger'     => "http://ggf.org/ns/nmwg/tools/pinger/2.0/",
        'iperf'      => "http://ggf.org/ns/nmwg/tools/iperf/2.0/",
        'xquery'     => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/",
        'psservice'  => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/",
        'xpath'      => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xpath/1.0/",
        'sql'        => "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/sql/1.0/",
        'perfsonar'  => "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/",

        'average' => "http://ggf.org/ns/nmwg/ops/average/2.0/",
        'nmwgt'   => "http://ggf.org/ns/nmwg/topology/2.0/",
        'topo'    => "http://ggf.org/ns/nmwg/topology/2.0/",

        'nmtl4' => "http://ogf.org/schema/network/topology/l4/20070707",
        'nmtl3' => "http://ogf.org/schema/network/topology/l3/20070707",

        'nmtl2'  => "http://ogf.org/schema/network/topology/l2/20070707/",
        'nmtopo' => "http://ogf.org/schema/network/topology/base/20070707/",
        'nmtb'   => "http://ogf.org/schema/network/topology/base/20070707/",

        'nmtm' => "http://ggf.org/ns/nmwg/time/2.0/"
    },
);

# mappings for data models
my %MODELS = (
    'PINGER_DATATYPES'     => { name => 'message',  element => 'perfSONAR_PS::DataModels::PingER_Model::message' },
    'PINGERTOPO_DATATYPES' => { name => 'topology', element => 'perfSONAR_PS::DataModels::PingER_Topology::pingertopo' },
    'SONAR_DATATYPES'      => { name => 'message',  element => 'perfSONAR_PS::DataModels::Sonar_Model::message' },
);

# for every model

foreach my $type ( keys %MODELS ) {
    no strict 'refs';
    eval {
        my $class = $MODELS{$type}->{element};
	$class =~ s/\:\:\w+$//;
	eval "require $class";
	if($EVAL_ERROR) {
           $logger->logdie(" Building API failed " .  $EVAL_ERROR);
        }  
        my $api_builder =   XML::RelaxNG::Compact::PXB->new({
                                     	       top_dir =>    $TOP_DIR ,
                                     	       nsregistry =>  $NSS{$type},
					       project_root =>   'perfSONAR_PS',
                                     	       datatypes_root =>   $type,
                                     	       schema_version =>  ${"$class\:\:VERSION"},
                                     	       test_dir =>   't',
					       DEBUG => 0,
				     	       footer => POD::Credentials->new({see_also => 
qq{

To join the 'perfSONAR Users' mailing list, please visit:

   https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

   http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

   http://code.google.com/p/perfsonar-ps/issues/list
   },
					                                        author=> 'Maxim Grigoriev', 
				     						license=> 'You should have received a copy of the Fermitool license along with this software.',
									        copyright => 'Copyright (c) 2008, Fermi Research Alliance (FRA)'})
						             });
        $api_builder->buildAPI({ name =>  $MODELS{$type}->{name}, element  =>  ${$MODELS{$type}->{element}} })
    };
    if ( $EVAL_ERROR ) {
        $logger->logdie( " Building API failed " . $EVAL_ERROR );
    }
    use strict;
}

1;

__END__

=head1 SEE ALSO

L<English>, L<XML::RelaxNG::Compact::PXB>, L<POD::Credentials>, L<Data::Dumper>,
L<FindBin>

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS subversion repository is located at:

  http://anonsvn.internet2.edu/svn/perfSONAR-PS/trunk

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: ps_schemaPXB.pl 2640 2009-03-20 01:21:21Z zurawski $

=head1 AUTHOR

Maxim Grigoriev, maxim@fnal.gov

=head1 LICENSE

You should have received a copy of the Fermitools license
along with this software. 

=head1 COPYRIGHT

Copyright (c) 2008-2009, Fermi Research Alliance (FRA)

All rights reserved.

=cut
