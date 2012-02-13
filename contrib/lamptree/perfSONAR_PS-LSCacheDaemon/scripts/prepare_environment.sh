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

echo "Linking init script..."
$MAKEROOT ln -s /opt/perfsonar_ps/ls_cache_daemon/scripts/ls_cache_daemon /etc/init.d/ls_cache_daemon

if [ -e /sbin/chkconfig ];
then
echo "Running chkconfig..."
    $MAKEROOT /sbin/chkconfig --add ls_cache_daemon
fi

echo "Starting Lookup Service..."
$MAKEROOT /etc/init.d/ls_cache_daemon start

echo "Removing temporary files..."
$MAKEROOT rm -f /opt/perfsonar_ps/ls_cache_daemon/dependencies
$MAKEROOT rm -f /opt/perfsonar_ps/ls_cache_daemon/scripts/install_dependencies.sh
$MAKEROOT rm -f /opt/perfsonar_ps/ls_cache_daemon/scripts/prepare_environment.sh

echo "Exiting prepare_environment.sh"
