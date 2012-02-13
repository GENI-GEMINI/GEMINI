#!/bin/bash

# Example command line:
# ./web100clt -n ndt.iupui.mlab3.dfw01.measurement-lab.org -p 3001

#Check args
if [ $# -ne 2 ]
then
  echo "Usage: `basename $0` host timeout"
  exit 2
fi

host=$1
timeout=$2

command="./web100clt -n $host -p 3001"

# run $command in background, slee, then kill the process if it is running
# web100clt will return 0 on timeout, so we can't use the return status only
sh -c "$command 1>/dev/null" & 
pid=$!
echo "sleep $timeout; kill $pid 2>/dev/null" | at now 2>/dev/null
wait $pid #&> /dev/null
if [ $? -eq 143 ]; then
echo "SERVER NOT RESPONDING: command was terminated - timeout of $timeout secs reached."
exit 2
fi

ret=$?

if [ $ret != "0" ] ; then
  echo "$host failed test. Status: $ret"
  exit 2
fi
