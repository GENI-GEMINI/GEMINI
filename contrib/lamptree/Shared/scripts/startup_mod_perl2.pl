# mod_perl2 startup script for Atom/PingER handler
#
# this script should be configured in the httpd/conf.d/perl.conf as
# PerlRequire /home/netadmin/LHCOPN/perfSONAR-PS/trunk/startup_mod_perl2.pl
# please change your full path
# and add next settings in the perl.conf as well:
#
# <Location /atom_ma>
#    SetHandler perl-script
#    PerlResponseHandler perfSONAR_PS::Atom::PingER 
#</Location>
#                change this lib path to your location
use lib qw(/home/netadmin/LHCOPN/perfSONAR-PS/trunk/lib);
 
use Log::Log4perl qw( :easy );
 
Log::Log4perl->easy_init($INFO);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';

 

1;
