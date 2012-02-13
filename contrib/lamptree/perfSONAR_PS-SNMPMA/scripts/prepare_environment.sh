#!/bin/bash

MAKEROOT=""
if [[ $EUID -ne 0 ]];
then
    MAKEROOT="sudo "
fi

echo "Adding 'perfsonar' user and group..."
$MAKEROOT /usr/sbin/groupadd perfsonar 2> /dev/null || :
$MAKEROOT /usr/sbin/useradd -g perfsonar -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

echo "Creating '/var/log/perfsonar'..."
$MAKEROOT mkdir -p /var/log/perfsonar
$MAKEROOT chown perfsonar:perfsonar /var/log/perfsonar

echo "Creating '/var/lib/perfsonar/snmp_ma'..."
$MAKEROOT mkdir -p /var/lib/perfsonar/snmp_ma
if [ ! -f /var/lib/perfsonar/snmp_ma/store.xml ];
then
    echo "Creating '/var/lib/perfsonar/snmp_ma/store.xml'..."
    $MAKEROOT `dirname $0`/../scripts/makeStore.pl /var/lib/perfsonar/snmp_ma 1
fi

echo "Setting permissions in '/var/lib/perfsonar/snmp_ma'"
$MAKEROOT chown -R perfsonar:perfsonar /var/lib/perfsonar/snmp_ma

echo "Linking init script..."
$MAKEROOT ln -s /opt/perfsonar_ps/snmp_ma/scripts/snmp_ma /etc/init.d/snmp_ma

echo "Running chkconfig..."
$MAKEROOT /sbin/chkconfig --add snmp_ma

echo "Starting Lookup Service..."
$MAKEROOT /etc/init.d/snmp_ma start

echo "Removing temporary files..."
$MAKEROOT rm -f /opt/perfsonar_ps/snmp_ma/dependencies
$MAKEROOT rm -f /opt/perfsonar_ps/snmp_ma/scripts/install_dependencies.sh
$MAKEROOT rm -f /opt/perfsonar_ps/snmp_ma/scripts/prepare_environment.sh

echo "Exiting prepare_environment.sh"

