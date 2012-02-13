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

echo "Creating '/var/lib/perfsonar/skeleton_mp_diy'..."
$MAKEROOT mkdir -p /var/lib/perfsonar/skeleton_mp_diy
if [ ! -f /var/lib/perfsonar/skeleton_mp_diy/store.xml ];
then
    echo "Creating '/var/lib/perfsonar/skeleton_mp_diy/store.xml'..."
    $MAKEROOT `dirname $0`/../scripts/makeStore.pl /var/lib/perfsonar/skeleton_mp_diy 1
fi

echo "Setting permissions in '/var/lib/perfsonar/skeleton_mp_diy'"
$MAKEROOT chown -R perfsonar:perfsonar /var/lib/perfsonar/skeleton_mp_diy

echo "Linking init script..."
$MAKEROOT ln -s /opt/perfsonar_ps/skeleton_mp_diy/scripts/skeleton_mp_diy /etc/init.d/skeleton_mp_diy

echo "Running chkconfig..."
$MAKEROOT /sbin/chkconfig --add skeleton_mp_diy

echo "Starting Service..."
$MAKEROOT /etc/init.d/skeleton_mp_diy start

echo "Removing temporary files..."
$MAKEROOT rm -f /opt/perfsonar_ps/skeleton_mp_diy/dependencies
$MAKEROOT rm -f /opt/perfsonar_ps/skeleton_mp_diy/scripts/install_dependencies.sh
$MAKEROOT rm -f /opt/perfsonar_ps/skeleton_mp_diy/scripts/prepare_environment.sh

echo "Exiting prepare_environment.sh"

