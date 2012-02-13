#!/bin/bash

if [ "$#" == "0" ]; then
	echo "lamp-send-cert.sh <username> <cert> host1 host2 ... hostN"
	exit 1
fi

USER=$1
shift
CERT=$1
shift

while (( "$#" )); do
	scp $CERT ${USER}@$1:
	ssh ${USER}@$1 "sudo mv ${CERT} /usr/local/etc/protogeni/ssl/lampcert.pem; 
			sudo chown root.perfsonar /usr/local/etc/protogeni/ssl/lampcert.pem; 
			sudo chmod 440 /usr/local/etc/protogeni/ssl/lampcert.pem;
			sudo /etc/init.d/psconfig restart"
	shift
done
