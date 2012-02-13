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

echo "Creating '/var/lib/perfsonar/perfsonarbuoy_ma'..."
$MAKEROOT mkdir -p /var/lib/perfsonar/perfsonarbuoy_ma
$MAKEROOT chown -R perfsonar:perfsonar /var/lib/perfsonar/perfsonarbuoy_ma

echo "Linking init scripts..."
$MAKEROOT ln -s /opt/perfsonar_ps/perfsonarbuoy_ma/scripts/perfsonarbuoy_owp_master /etc/init.d/perfsonarbuoy_owp_master
$MAKEROOT ln -s /opt/perfsonar_ps/perfsonarbuoy_ma/scripts/perfsonarbuoy_bw_master /etc/init.d/perfsonarbuoy_bw_master

echo "Running chkconfig..."
$MAKEROOT /sbin/chkconfig --add perfsonarbuoy_owp_master
$MAKEROOT /sbin/chkconfig --add perfsonarbuoy_bw_master

echo "Removing temporary files..."
$MAKEROOT rm -f /opt/perfsonar_ps/perfsonarbuoy_ma/dependencies
$MAKEROOT rm -f /opt/perfsonar_ps/perfsonarbuoy_ma/modules.rules
$MAKEROOT rm -f /opt/perfsonar_ps/perfsonarbuoy_ma/scripts/install_dependencies.sh
$MAKEROOT rm -f /opt/perfsonar_ps/perfsonarbuoy_ma/scripts/prepare_environment_client.sh

echo "Exiting prepare_environment.sh"
