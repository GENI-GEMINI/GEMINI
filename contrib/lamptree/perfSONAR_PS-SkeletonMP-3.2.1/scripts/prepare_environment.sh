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

echo "Creating '/var/lib/perfsonar/skeleton_mp'..."
$MAKEROOT mkdir -p /var/lib/perfsonar/skeleton_mp
if [ ! -f /var/lib/perfsonar/skeleton_mp/store.xml ];
then
    echo "Creating '/var/lib/perfsonar/skeleton_mp/store.xml'..."
    $MAKEROOT `dirname $0`/../scripts/makeStore.pl /var/lib/perfsonar/skeleton_mp 1
fi

echo "Setting permissions in '/var/lib/perfsonar/skeleton_mp'"
$MAKEROOT chown -R perfsonar:perfsonar /var/lib/perfsonar/skeleton_mp

echo "Linking init script..."
$MAKEROOT ln -s /opt/perfsonar_ps/skeleton_mp/scripts/skeleton_mp /etc/init.d/skeleton_mp

echo "Running chkconfig..."
$MAKEROOT /sbin/chkconfig --add skeleton_mp

echo "Starting Lookup Service..."
$MAKEROOT /etc/init.d/skeleton_mp start

echo "Removing temporary files..."
$MAKEROOT rm -f /opt/perfsonar_ps/skeleton_mp/dependencies
$MAKEROOT rm -f /opt/perfsonar_ps/skeleton_mp/scripts/install_dependencies.sh
$MAKEROOT rm -f /opt/perfsonar_ps/skeleton_mp/scripts/prepare_environment.sh

echo "Exiting prepare_environment.sh"

