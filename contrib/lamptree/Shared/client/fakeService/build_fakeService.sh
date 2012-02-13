#!/bin/sh

XMLROOT=$(xml2-config  --prefix)
if [ -z $XMLROOT   ]
then
    echo " libxml2 libraries must be installed on building host "
    exit
fi  

XMLLIB_SO="$XMLROOT/lib/libxml2.so.2"
XMLLIB_A="$XMLROOT/lib/libxml2.a"

EXECNAME=fakeService
echo "Building executable $EXECNAME"
 
COM="pp -c -I ../../lib -l $XMLLIB_A -l $XMLLIB_SO -o $EXECNAME fakeService.pl"

echo -e " Building ... \n  $COM  \n "
$COM
