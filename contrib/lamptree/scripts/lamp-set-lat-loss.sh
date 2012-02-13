#!/bin/bash

if [ "$#" -lt "2" ]; then 
	echo "lamp-set-lat-loss.sh <iface> [ clear |  <lat> <loss> [rate] ]";
	exit 1;
fi

IFACE=$1
LAT=$2
LOSS=$3
RATE=$4

echo "Resetting ${IFACE}..."
/sbin/tc qdisc del dev ${IFACE} root
/sbin/tc qdisc del dev ${IFACE} ingress
/sbin/tc qdisc del dev ifb0 root

if [ "$LAT" == "clear" ]; then
	echo "done!"
	exit 1;
fi

if [ ! -z $RATE ]; then
	echo "Setting ${RATE}Mbit/s bottleneck on ${IFACE}."
	/sbin/tc qdisc replace dev ${IFACE} root handle 1: tbf rate ${RATE}Mbit burst 2mb latency 100ms
	echo "Adding ${LAT}ms latency and ${LOSS}% loss.";
	/sbin/tc qdisc replace dev ${IFACE} parent 1: handle 10: netem loss ${LOSS} limit 40000 delay ${LAT}ms
else
	echo "Setting ${IFACE} with ${LAT}ms latency and ${LOSS}% loss.";
	/sbin/tc qdisc replace dev ${IFACE} root handle 1 netem loss ${LOSS} limit 40000 delay ${LAT}ms
fi

modprobe ifb
/sbin/ip link set dev ifb0 up
/sbin/tc qdisc replace dev ${IFACE} ingress
/sbin/tc filter replace dev ${IFACE} parent ffff: protocol ip u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb0
/sbin/tc qdisc replace dev ifb0 root netem loss ${LOSS} limit 40000 delay ${LAT}ms
