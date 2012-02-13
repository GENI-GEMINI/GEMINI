package gmaps::paths;

our $templatePath = '../templates/';
our $imagePath = '../html/images/';

our $googleMapKey = 'ABQIAAAAVyIxGI3Xe9C2hg8IelerBBSxuTV5jGC7iqe3CBEO67Q89TZmIxSf-liBltLkv8fiOfBtSRo2MwLYiw';

our $logFile = '/tmp/gmaps.logging';

our $gLSRoot = 'http://www.perfsonar.net/gls.root.hint';

# caceh for location coordinates of urn
# if not defined, will not use a cache
our $doLocation = 1;
our $locationCache = '/tmp/gmaps-location.db';
our $locationExpiry = '3600';
our $locationDoDNSLoc = 1;
our $locationDoGeoIPTools = 1;

our $discoverCache = '/tmp/gmaps-discover.db';
our $discoverExpiry = '7200';   # seconds for metadata to be considered old

our $version = 'perfSONAR-PS-gmaps/3.0';


1;
