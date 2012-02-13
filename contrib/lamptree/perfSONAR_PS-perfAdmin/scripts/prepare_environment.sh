#!/bin/bash

MAKEROOT=""
if [[ $EUID -ne 0 ]];
then
    MAKEROOT="sudo "
fi

DIRECTORY=`dirname "$0"`

echo "Adding 'perfsonar' user and group..."
$MAKEROOT /usr/sbin/groupadd perfsonar 2> /dev/null || :
$MAKEROOT /usr/sbin/useradd -g perfsonar -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

echo "Creating '/var/log/perfsonar'..."
$MAKEROOT mkdir -p /var/log/perfsonar
$MAKEROOT chown perfsonar:perfsonar /var/log/perfsonar

echo "Creating '/var/lib/perfsonar/perfAdmin'..."
$MAKEROOT mkdir -p /var/lib/perfsonar/perfAdmin/cache
$MAKEROOT chown -R perfsonar:perfsonar /var/lib/perfsonar/perfAdmin

echo "Installing '/etc/cron.d/perfAdmin.cron'..."
$MAKEROOT mv $DIRECTORY/perfAdmin.cron /etc/cron.d
$MAKEROOT chown root:root /etc/cron.d/perfAdmin.cron
$MAKEROOT chmod 600 /etc/cron.d/perfAdmin.cron

echo "Installing '/etc/httpd/conf.d/perfAdmin.conf'..."
$MAKEROOT mv $DIRECTORY/perfAdmin.conf /etc/httpd/conf.d
$MAKEROOT chown root:root /etc/httpd/conf.d/perfAdmin.conf
$MAKEROOT chmod 644 /etc/httpd/conf.d/perfAdmin.conf

echo "Setting permissions in '/opt/perfsonar_ps/perfAdmin'"
$MAKEROOT chown -R perfsonar:perfsonar /opt/perfsonar_ps/perfAdmin
$MAKEROOT chown -R apache:apache /opt/perfsonar_ps/perfAdmin/etc

echo "Restarting cron..."
$MAKEROOT /etc/init.d/crond restart

echo "Restarting apache..."
$MAKEROOT /etc/init.d/httpd restart

echo "Removing temporary files..."
$MAKEROOT rm -f /opt/perfsonar_ps/perfAdmin/dependencies
$MAKEROOT rm -frd /opt/perfsonar_ps/perfAdmin/scripts

echo "Exiting prepare_environment.sh"
