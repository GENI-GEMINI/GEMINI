#!/usr/bin/perl

# 1. obtain the xml file from the IDC
# 2. grab the 'last updated' time for the domain from the topology server
# 3. if the last updated time is < the time in the xml file from the IDC, update the server
# 4. add the domain info to the LS
use strict;
use warnings;
use Getopt::Long;
use Config::General;
use Data::Dumper;
use XML::LibXML;

my $CONFIG_FILE;
my $DEBUGFLAG;
my $HELP;
my $LOGGER_CONF;
my $NEW_TOPOLOGY;

my ($status, $res, $res2);

$status = GetOptions (
        'config=s' => \$CONFIG_FILE,
        'logger=s' => \$LOGGER_CONF,
        'new_topology=s' => \$NEW_TOPOLOGY,
        'verbose' => \$DEBUGFLAG,
        'help' => \$HELP,
        );

if (not $status or $HELP) {
    print "$0: starts the DCN topology agent\n";
    print "\t$0 [--verbose --help --config=config.file --logger=logger/filename.conf --new_topology=topology_file.xml]\n";
    exit(1);
}

if (not $CONFIG_FILE) {
    $CONFIG_FILE = "dcn_agent.conf";
}

my $logger;
if (!defined $LOGGER_CONF or $LOGGER_CONF eq "") {
    use Log::Log4perl qw(:easy);

    my $output_level = $INFO;
    if ($DEBUGFLAG) {
        $output_level = $DEBUG;
    }

    my %logger_opts = (
            level => $output_level,
            layout => '%d (%P) %p> %F{1}:%L %M - %m%n',
            );

    Log::Log4perl->easy_init( \%logger_opts );
    $logger = get_logger("perfSONAR_PS");
} else {
    use Log::Log4perl qw(get_logger :levels);

    my $output_level = $INFO;
    if($DEBUGFLAG) {
        $output_level = $DEBUG;
    }

    Log::Log4perl->init($LOGGER_CONF);
    $logger = get_logger("perfSONAR_PS");
    $logger->level($output_level);
}

my $config = Config::General->new($CONFIG_FILE);
my %conf = $config->getall;

if (not $conf{"ls_uri"}) {
    $logger->error("You must specify a 'ls_uri' in the config file");
    exit(-1);
}

if (not $conf{"topology_uri"}) {
    $logger->error("You must specify a 'topology_uri' in the config file");
    exit(-1);
}

if (not $conf{"idc_uri"}) {
    $logger->error("You must specify a 'idc_uri' in the config file");
    exit(-1);
}

if (not $conf{"domain"}) {
    $logger->error("You must specify the domain name in the config file");
    exit(-1);
}

if (not $conf{"oscars_client"}) {
    $logger->error("You must specify the oscars client directory in the config file");
    exit(-1);
}

my $repeat;
$repeat = 1 if ($conf{"interval"});

my @ls_uris = split(',', $conf{"ls_uri"});

do {
    my $agent = perfSONAR_PS::Client::DCN::TopologyAgent->new(ls_uri => \@ls_uris, topology_uri => $conf{"topology_uri"}, idc_uri => $conf{"idc_uri"}, domain => $conf{"domain"}, oscars_client => $conf{"oscars_client"});

    $agent->getLocalTopology(file => $NEW_TOPOLOGY, do_register => 1);
    $agent->getNeighborTopologies();

    if ($conf{"interval"}) {
        $logger->debug("Sleeping for ".($conf{"interval"})." seconds");
        sleep ($conf{"interval"});
    }
} while($repeat);

exit (-1);

package perfSONAR_PS::Client::DCN::TopologyAgent;

use lib "lib";
use lib "../lib";

use XML::LibXML;

use strict;
use warnings;

use Log::Log4perl qw(get_logger :nowarn);
use Params::Validate qw(:all);
use Data::Dumper;

use perfSONAR_PS::Common;
use perfSONAR_PS::Topology::ID;
use perfSONAR_PS::Client::LS::Remote;
use perfSONAR_PS::Client::Topology::MA;
use perfSONAR_PS::OSCARS;

use fields 'LOGGER', 'DOMAIN', 'DOMAINID', 'TOPOLOGY_CLIENT', 'TOPOLOGY_URI', 'LS_CLIENTS', 'LS_URIS', 'IDC_URI', 'NEIGHBORS', 'OSCARS_CLIENT_DIR';

sub new {
    my $package = shift;
    my $args = validate(@_, { domain => 1, ls_uri => 1, topology_uri => 1, idc_uri => 1, oscars_client => 1});

    my $self = fields::new($package);

    $self->{LOGGER} = get_logger("perfSONAR_PS::Client::DCN::TopologyAgent");
    $self->{DOMAIN} = $args->{domain};
    $self->{IDC_URI} = $args->{idc_uri};
    $self->{DOMAINID} = "urn:ogf:network:domain=".$args->{domain};
    $self->{OSCARS_CLIENT_DIR} = $args->{oscars_client};

    my $ls_uris;
    if (ref $args->{ls_uri} eq "ARRAY") {
        $ls_uris = $args->{ls_uri};
    } else {
        my @ls_array = ( $args->{ls_uri} );
        $ls_uris = \@ls_array;
    }

    my @ls_clients = ();
    foreach my $ls_uri (@{ $ls_uris }) {
        my %ls_conf = (
                LS_INSTANCE => $ls_uri,
                SERVICE_TYPE => "TS",
                SERVICE_ACCESSPOINT => $args->{topology_uri},
                );
        push @ls_clients, perfSONAR_PS::Client::LS::Remote->new($ls_uri, \%ls_conf);
    }
    $self->{LS_CLIENTS} = \@ls_clients;
    $self->{LS_URIS} = $ls_uris;

    $self->{TOPOLOGY_URI} = $args->{topology_uri};
    $self->{TOPOLOGY_CLIENT} = perfSONAR_PS::Client::Topology::MA->new($args->{topology_uri});

    my %tmp = ();
    $self->{NEIGHBORS} = \%tmp;

    return $self;
}

=head2 registerLS
This function registers the domain in the topology service with the
lookup service.
=cut
sub registerLS {
    my $self = shift;
    my $md = buildLSMetadata($self->{DOMAINID});
    my @mds = ( "$md" );

    foreach my $ls_client (@{ $self->{LS_CLIENTS} }) {
        $ls_client->registerStatic(\@mds);
    }
}

=head2 getLocalTopology
This function grabs the topology of the local domain, and puts it into
the database if it's newer than the topology already in there.
=cut
sub getLocalTopology {
    my $self = shift;
    my $args = validate(@_, { do_register => 0, file => 1 });

    ($status, $res, $res2) = $self->retrieveIDCDomain($args->{file});
    if ($status != 0) {
        my $msg = "Failed to retrieve the topology from the IDC: $res";
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $domain = $res;
    my $time = $res2;

    if ($domain->getAttribute("id") ne $self->{DOMAINID}) {
        my $msg = "ID of domain returned by IDC does not match our own: ".$domain->getAttribute("id")." vs ".$self->{DOMAINID};
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    $self->updateDomainIfNewer(domain => $domain);

    if ($args->{do_register}) {
        $self->registerLS;
    }

    my %neighbors = ();
    $self->findNeighbors($domain, \%neighbors);
    $self->{NEIGHBORS} = \%neighbors;
    $self->{LOGGER}->debug("Found neighbors: ".Dumper(\%neighbors));

    return (0, "");
}

=head2 getNeighborTopologies
This function goes through the list of neighbors, finds the topology
service containing information on that domain, downloads the topology
and updates its local copy if the topology is newer.
=cut
sub getNeighborTopologies {
    my ($self) = shift;

    foreach my $neighbor (keys %{ $self->{NEIGHBORS} }) {
        my $neighbor_id = "urn:ogf:network:domain=".$neighbor;

        my ($status, $res) = $self->lookupNeighborTS($neighbor);

        next if ($status != 0);

        my $topology_uri = $res;

        my $topology_client = perfSONAR_PS::Client::Topology::MA->new($topology_uri);

        ($status, $res) = $topology_client->getAll();
        if ($status == -1) {
            $self->{LOGGER}->error("Problem getting data from topology service: $topology_uri");
            next;
        }

        foreach my $domain ($res->getChildrenByLocalName("domain")) {
            my $domain_id = $domain->getAttribute("id");

            next if ($domain_id eq $self->{DOMAINID});

            $self->updateDomainIfNewer(domain => $domain);

        }
    }
}

#     retrieveIDCDomain
#    This function retrieves the topology information from the local IDC. It
#    also ensures that the format of the domain contains a "lifetime/start"
#    elements. XXX This is a stub function that just reads from a file.
sub retrieveIDCDomain {
    my ($self, $file) = @_;
    my $output;

    my $oscars_client = perfSONAR_PS::OSCARS->new({ idc_url => $self->{IDC_URI}, client_directory => $self->{OSCARS_CLIENT_DIR} });

    my $topology_str = $oscars_client->getTopology(\$output);
    if (not $topology_str) {
        return (-1, "Failed to get topology from ".$self->{IDC_URI}.": $output");
    }

    my $parser = XML::LibXML->new();
    my $dom;
    eval {
        $dom = $parser->parse_string($topology_str);
    };
    if($@) {
        my $msg = escapeString("Parse of response failed: ".$@);
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $timeValue = findvalue($dom->getDocumentElement, "//*[local-name()='topology']/*[local-name()='lifetime']/*[local-name()='start']");
    if (not $timeValue) {
        my $topo_id = findvalue($dom->getDocumentElement, "//*[local-name()='topology']/\@id");
        if ($topo_id and $topo_id =~ /(.*)-(\d+)/) {
            $timeValue = $2;
        }
    }

    if (not $timeValue) {
        my $msg = "No time defined";
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $domain = find($dom->getDocumentElement, "./*[local-name()='domain']", 1);
    if (not defined $domain) {
        my $msg = "Updated topology does not contain a domain";
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $lifetime = find($domain, "./*[local-name()='lifetime']", 1);
    if (not $lifetime) {
        $lifetime = $domain->ownerDocument->createElement("lifetime");
        $lifetime->setNamespace($domain->namespaceURI(), $domain->prefix, 1);
        $domain->addChild($lifetime);
    }

    my $start = find($lifetime, "./*[local-name()='start']", 1);
    if (not $start) {
        $start = $lifetime->ownerDocument->createElement("start");
        $start->setNamespace($domain->namespaceURI(), $domain->prefix, 1);
        $lifetime->addChild($start);
    }

    my $text = $start->ownerDocument->createTextNode($timeValue);
    $start->addChild($text);

    return (0, $domain, $timeValue);
}

#    queryDomainModificationTime
#     This function takes a topology client and a domain id, and looks up and
#     returns the 'start' time for the domain in the topology service.
sub queryDomainModificationTime {
    my $self = shift;
    my $args = validate(@_, { topology_client => 1, domain_id => 1 });
    my $domain = $args->{domain_id};
    my $topology_client = $args->{topology_client};

    my $xquery = "//*[\@id='".$domain."']/*[local-name()='lifetime']/*[local-name()='start']";

    my ($status, $res) = $topology_client->xQuery($xquery);

    if ($status != 0) {
        $self->{LOGGER}->debug("Couldn't query topology service to find the timestamp for the current topology information");
        return (-1, $res);
    }

    my $parser = XML::LibXML->new();
    my $dom;
    eval {
        $dom = $parser->parse_string($res);
    };
    if($@) {
        my $msg = escapeString("Parse of response failed: ".$@);
        $self->{LOGGER}->error($msg);
        return (-1, $msg);
    }

    my $time_value = findvalue($dom->getDocumentElement, "//*[local-name()='start']");
    if (not $time_value) {
        return (-1, "Domain does not have time information");
    }

    return (0, $time_value);
}

#     buildLSMetadata
#    This function is used to build the metadata that will be registered
#    with the lookup service(s).
sub buildLSMetadata {
    my ($id) = @_;
    my $md = q{};
    my $mdId = "meta".genuid();

    $md .= "<nmwg:metadata id=\"$mdId\">\n";
    $md .= " <nmwg:subject id=\"sub0\">\n";
    $md .= "  <nmtb:domain xmlns:nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\" id=\"$id\" />\n";
    $md .= " </nmwg:subject>\n";
    $md .= " <nmwg:eventType>topology</nmwg:eventType>\n";
    $md .= " <nmwg:eventType>http://ggf.org/ns/nmwg/topology/query/all/20070809</nmwg:eventType>\n";
    $md .= " <nmwg:eventType>http://ggf.org/ns/nmwg/topology/query/xquery/20070809</nmwg:eventType>\n";
    $md .= " <nmwg:eventType>http://ggf.org/ns/nmwg/topology/change/add/20070809</nmwg:eventType>\n";
    $md .= " <nmwg:eventType>http://ggf.org/ns/nmwg/topology/change/update/20070809</nmwg:eventType>\n";
    $md .= " <nmwg:eventType>http://ggf.org/ns/nmwg/topology/change/replace/20070809</nmwg:eventType>\n";
    $md .= "</nmwg:metadata>\n";

    return $md;
}

#   updateDomainIfNewer
#    This function grabs the time of the domain, checks it against the
#    timestamp in the database, and updates if either the domain and/or
#    timestamp in the database doesn't exist, or the timestamp of the
#    current domain is newer.
sub updateDomainIfNewer {
    my $self = shift;
    my $args = validate(@_, { domain => 1 });

    my $domain = $args->{domain};
    my $domain_id = $domain->getAttribute("id");

    my $new_time = findvalue($domain, "./*[local-name()='lifetime']/*[local-name()='start']");

# if there is no timestamp or identifier, don't update.
    if (not $new_time or not $domain_id) {
        return;
    }

    ($status, $res) = $self->queryDomainModificationTime(topology_client => $self->{TOPOLOGY_CLIENT}, domain_id => $domain_id);

    my $existing_time;
    if ($status == 0) {
        $existing_time = $res;
    }

    if (not $existing_time) {
        $self->{LOGGER}->debug("No existing time, updating any copies in there");
    } else {
        $self->{LOGGER}->debug("Existing time: $existing_time");
    }

    if (not $existing_time or $existing_time < $new_time) {
        $self->{LOGGER}->debug("Updating local cache for topology information from $domain_id");

        my $args = validate(@_, { domain => 1 });

        my $topology = $self->wrapDomain($domain);

        $self->{TOPOLOGY_CLIENT}->changeTopology("replace", $topology);
    }

    return;
}

#   wrapDomain
#    This function wraps the domain element in a topology envelope so it can be
#    passed to the Topology client functions.
sub wrapDomain {
    my ($self, $domain) = @_;

    my $topology = $domain->ownerDocument->createElement("topology");
    $topology->setNamespace($domain->namespaceURI(), $domain->prefix, 1);
    $topology->addChild($domain);

    return $topology;
}

#   lookupNeighborTS
#    This function consults the set of lookup services and finds the topology
#    service for the specified neighbor. The 'neighbor' variable is the
#    DNS-name (e.g. dcn.internet2.edu)
sub lookupNeighborTS {
    my ($self, $neighbor) = @_;

    $self->{LOGGER}->debug("Looking up ".$neighbor);

    foreach my $ls_client (@{ $self->{LS_CLIENTS} }) {
        my $xquery = q{};
        $xquery .= "  declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n";
        $xquery .= "  for \$data in /nmwg:store/nmwg:data\n";
        $xquery .= "    let \$metadata_id := \$data/\@metadataIdRef\n";
        $xquery .= "    where \$data//*:domain[\@id=\"urn:ogf:network:domain=$neighbor\"] and \$data//nmwg:eventType[text()=\"http://ggf.org/ns/nmwg/topology/query/all/20070809\"]\n";
        $xquery .= "    return /nmwg:store/nmwg:metadata[\@id=\$metadata_id]\n";

        my %queries = ();
        $queries{"neighbor"} = $xquery;
        my ($status, $res) = $ls_client->query(\%queries);

        if ($status != 0 or not defined $res->{"neighbor"}) {
            next;
        }

        ($status, $res) = @{ $res->{"neighbor"} };
        if ($status != 0) {
            next;
        }

        my $accessPoint = findvalue($res, "./psservice:datum/nmwg:metadata/perfsonar:subject/psservice:service/psservice:accessPoint");

        if ($accessPoint) {
            return (0, $accessPoint)
        }
    }

    my $msg = "No topology service found for neighbor: $neighbor";
    $self->{LOGGER}->error($msg);
    return (-1, $msg);
}

#   findNeighbors
#    This function recursively scans through a DOM looking for 'remoteLinkId'
#    elements. If it finds them, it pulls out the DNS name from the identifier
#    and adds it to the neighbors hash.
sub findNeighbors {
    my ($self, $node, $neighbors) = @_;

    if ($node->localname and $node->localname eq "remoteLinkId") {
        my $id = $node->textContent;
        if (not $id) {
            $self->{LOGGER}->error("remoteLinkId has no id.");
            return;
        }

        if ($id =~ /domain=([^:]+):/) {
            if (not defined $neighbors->{$1} and $self->{DOMAIN} ne $1 and $1 ne "*") {
                $neighbors->{$1} = 1;
            }
        }
    } elsif($node->hasChildNodes()) {
        foreach my $c ($node->childNodes) {
            $self->findNeighbors($c, $neighbors);
        }
    }

    return;
}

# vim: expandtab shiftwidth=4 tabstop=4
