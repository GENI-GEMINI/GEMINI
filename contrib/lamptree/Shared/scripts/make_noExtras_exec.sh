#!/bin/env  bash
#
#    just perl and libxml2, no db stuff
#
 
tolower()
{
local char="$*"

out=$(echo $char | tr [:upper:] [:lower:])
local retval=$?
echo "$out"
unset out
unset char
return $retval
}


XMLROOT=$(xml2-config  --prefix)
if [ -z $XMLROOT   ]
then
echo " libxml2 libraries must be installed on building host "
exit
fi  
 
XMLLIB_SO="$XMLROOT/lib/libxml2.so.2"
XMLLIB_A="$XMLROOT/lib/libxml2.a"


MODULE=$1

if ( [ ! -e "../lib/perfSONAR_PS/Services/MA/$MODULE.pm" ] || [ !  -e "../lib/perfSONAR_PS/Services/MP/$MODULE.pm" ] )
then
echo " Usage: make_exec.sh <service module name  - for example PingER> "
echo "        for service XXX next modules must exist: ../lib/perfSONAR_PS/Services/M[PA]/XXX.pm "
exit
fi
 

EXECNAME=$(tolower $MODULE) 
echo "Building executable ps-$EXECNAME  for $MODULE MA and MP"
 
COM="pp -I ../lib/  -M  Sleepycat::DbXml  -M perfSONAR_PS::Services::LS  \
 -M perfSONAR_PS::Services::Echo -M  perfSONAR_PS::Request \
 -M perfSONAR_PS::RequestHandler  -M perfSONAR_PS::DB::RRD \
 -M perfSONAR_PS::DB::File  -M perfSONAR_PS::DB::XMLDB \
 -M perfSONAR_PS::DB::SQL -M perfSONAR_PS::DB::SQL::PingER \
 -M fields -M DateTime::Locale::en  \
 -M perfSONAR_PS::Services::MP::$MODULE  \
 -M perfSONAR_PS::Services::MA::$MODULE \
 -l  $XMLLIB_A  \
 -l  $XMLLIB_SO  \
 -o ps-$EXECNAME  ../perfsonar-daemon.pl"

echo -e " Building ... \n  $COM  \n "
$COM
