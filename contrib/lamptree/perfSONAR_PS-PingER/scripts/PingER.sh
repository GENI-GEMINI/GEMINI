#!/bin/bash
#
# Init file for perfSONAR Collector Daemon
#
# chkconfig: 2345 60 20
# description: perfSONAR Collector Daemon
#

PREFIX=/opt/perfsonar_ps/PingER
BINDIR=${PREFIX}/bin
CONFDIR=/etc/PingER
VARDIR=/var/run/PingER
SERVICE=daemon.pl
CONFIGBIN=${BINDIR}/pinger_ConfigureDaemon

COLLECTORCONF=${CONFDIR}/daemon.conf
LOGGERCONF=${CONFDIR}/daemon_logger.conf
PIDDIR=${VARDIR}
PIDFILE=pinger.pid

USER=perfsonar
GROUP=perfsonar

PERFSONAR="${BINDIR}/${SERVICE}   --config=${COLLECTORCONF} --piddir=${PIDDIR}  --pidfile=${PIDFILE} --logger=${LOGGERCONF} --user=${USER} --group=${GROUP}"

ERROR=0
ARGV="$@"
if [ "x$ARGV" = "x" ] ; then 
    ARGS="help"
fi

for ARG in $@ $ARGS
do
    # check for pidfile
    if [ -f  $PIDDIR/$PIDFILE ] ; then
	PID=`cat  $PIDDIR/$PIDFILE`
	if [ "x$PID" != "x" ] && kill -0 $PID 2>/dev/null ; then
	    STATUS="$SERVICE (pid $PID) running"
	    RUNNING=1
	else
	    STATUS="$SERVICE (pid $PID?) not running"
	    RUNNING=0
	fi
    else
	STATUS="$SERVICE (no pid file) not running"
	RUNNING=0
    fi

    case $ARG in
    start)
	if [ $RUNNING -eq 1 ]; then
	    echo "$0 $ARG: $SERVICE (pid $PID) already running"
	    continue
	fi

	echo $PERFSONAR

	if $PERFSONAR ; then
	    echo "$0 $ARG: $SERVICE started"
	else
	    echo "$0 $ARG: $SERVICE could not be started"
	    ERROR=3
	fi
	;;
    stop)
	if [ $RUNNING -eq 0 ]; then
	    echo "$0 $ARG: $STATUS"
	    continue
	fi
	if kill $PID ; then
	    echo "$0 $ARG: $SERVICE stopped"
	else
	    echo "$0 $ARG: $SERVICE could not be stopped"
	    ERROR=4
	fi
	;;    
     configure)
	 if [ $RUNNING -eq 1 ]; then
	    $CONFIGBIN  $COLLECTORCONF
	    $0 restart;
	  else
            $CONFIGBIN  $COLLECTORCONF
	 fi
	 ;;
    restart)
    	$0 stop; echo "waiting..."; sleep 10; $0 start;
	;;
 
    *)
	echo "usage: $0 (start|stop|restart|help)"
	cat <<EOF

start      - start $SERVICE
stop       - stop $SERVICE
restart    - restart $SERVICE if running by sending a SIGHUP or start if 
             not running
configure  - configure service (and restart if it was running )	     
help       - this screen

EOF
	ERROR=2
    ;;

    esac

done

exit $ERROR
