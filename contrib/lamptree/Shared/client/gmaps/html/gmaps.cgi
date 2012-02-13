#!/usr/local/bin/perl

#######################################################################
# User configuration
#######################################################################

# base directory for distribution's libraries
#use lib '/home/ytl/svn-branches/yee/gmaps-with-topologyservice/lib/';
use lib '/afs/slac.stanford.edu/g/scs/net/netmon/perfSONAR/perfSONAR-PS/trunk/client/gmaps/lib/';

# base directory for perfsonar-ps libraries
#use lib '/home/ytl/svn-branches/merge/lib/';
use lib '/afs/slac.stanford.edu/g/scs/net/netmon/perfSONAR/perfSONAR-PS/trunk/lib/';
use lib '/u/sf/ytl/lib/site_perl';

# set the path to the template directory from the main distribution
my $basePath = '/afs/slac.stanford.edu/g/scs/net/netmon/perfSONAR/perfSONAR-PS/trunk/client/gmaps/';
#my $baseTemplatePath = '/home/ytl/svn-branches/yee/gmaps-with-topologyservice/templates/';
my $baseTemplatePath = $basePath . 'templates/';
my $baseImagePath = $basePath . 'html/images/';

# google maps api key
# key for http://packrat.internet2.edu:8008
#my $key = 'ABQIAAAAVyIxGI3Xe9C2hg8IelerBBSFy_mUREMGUpX34adV9Mvl5aD4pBR2JOSPu3HOy4flLnGZ0Zme_8n3OA';
# key for http://pinger-new.slac.stanford.edu/
my $key = 'ABQIAAAAVyIxGI3Xe9C2hg8IelerBBRZGch4cVt17FSIStSbZeDGl_7soRRsE8wrluG53EVaW9yRQxH5h8W83g';

# cache file for location/coordinate lookups
my $locationCache = '/tmp/location.db';

#######################################################################


use Log::Log4perl qw(:easy);
use gmaps::paths;
use gmaps::Interface::web;

use strict;

if ( -e ${gmaps::paths::logFile} ) {
  Log::Log4perl->init( ${gmaps::paths::logFile} );
} else {
  Log::Log4perl->easy_init($INFO);
}

${gmaps::paths::templatePath} = $baseTemplatePath;
${gmaps::paths::locationCache} = $locationCache;

${gmaps::paths::imagePath} = $baseImagePath;
${gmaps::paths::googleMapKey} = $key;

# start the web application
my $app = gmaps::Interface::web->new( );

$app->run();

exit;
