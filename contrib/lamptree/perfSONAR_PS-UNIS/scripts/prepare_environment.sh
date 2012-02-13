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

echo "Creating '/var/lib/perfsonar/unis_service'..."
$MAKEROOT mkdir -p /var/lib/perfsonar/unis_service/lookup_db
if [ ! -f /var/lib/perfsonar/unis_service/lookup_db/DB_CONFIG ];
then
    echo "Creating '/var/lib/perfsonar/unis_service/lookup_db/DB_CONFIG'..."
    $MAKEROOT `dirname $0`/../scripts/psCreateLookupDB --directory /var/lib/perfsonar/unis_service/lookup_db
fi

$MAKEROOT mkdir -p /var/lib/perfsonar/unis_service/topology_db
if [ ! -f /var/lib/perfsonar/unis_service/topology_db/DB_CONFIG ];
then
	echo "Creating '/var/lib/perfsonar/unis_service/topology_db/DB_CONFIG'..."
	$MAKEROOT `dirname $0`/../scripts/psCreateTopologyDB --directory /var/lib/perfsonar/unis_service/topology_db
fi

echo "Setting permissions in '/var/lib/perfsonar'..."
$MAKEROOT chown -R perfsonar:perfsonar /var/lib/perfsonar

echo "Linking init script..."
$MAKEROOT ln -s /opt/perfsonar_ps/unis_service/scripts/unis_service /etc/init.d/unis_service

echo "Running chkconfig..."
$MAKEROOT /sbin/chkconfig --add unis_service

echo "Starting UNIS Service..."
$MAKEROOT /etc/init.d/unis_service start

echo "Removing temporary files..."
$MAKEROOT rm -f /opt/perfsonar_ps/unis_service/dependencies
$MAKEROOT rm -f /opt/perfsonar_ps/unis_service/scripts/install_dependencies.sh
$MAKEROOT rm -f /opt/perfsonar_ps/unis_service/scripts/prepare_environment.sh

echo "Exiting prepare_environment.sh"
