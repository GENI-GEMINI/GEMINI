#!/bin/bash
# -----------------------------------------------------------------------------
#
# Copyright (c) 2010 University of Kentucky
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and/or hardware specification (the "Work") to deal in the
# Work without restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Work, and to permit persons to whom the Work is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Work.

# THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS IN THE WORK.
#
# -----------------------------------------------------------------------------

# Variable Definations
source /usr/testbed/bin/measure-scripts/INSTALL_DEFS.sh
export PATH=$PATH:/usr/sbin

TOUCH_BINARY="touch"
$TOUCH_BINARY $INSTOOLS_LOG;
chmod 776 $INSTOOLS_LOG;


	TEMP_BASE=/tmp/GN-SETUP
	SLICEURN=$1
	USERURN=$2
	GNHOST=$3
	AUTH_UUID=$4
	
	#$WGET_BINARY -q -P $TEMP_BASE $DOWNLOAD_PATH/$TARBALL_DIR/shadownet_public_key.tgz >>$INSTOOLS_LOG 2>&1;
	#BINARY PATHS
	RPM_DIR="public/rpms"
	TARBALL_DIR="tarballs"
	PUBLIC_TGZ_DIR="public/tgz"
	SCRIPTS_DIR="scripts"
	PATCH_DIR="patches"
	DB_DIR="db"
	PATCH_BINARY="/usr/bin/patch"
	CHKCONF_BINARY="/sbin/chkconfig"
	SERVICE_BINARY="/sbin/service"
	WGET_BINARY="wget"
	MKDIR_BINARY="mkdir"
	YUM_BINARY="yum"
	RPM_BINARY="rpm"
	TAR_BINARY="tar"
	MAKE_BINARY="make"
	CAT_BINARY="cat"
	GEMINI_ACTIVE_PKG="gemini-active-gn-fedora15-20141013.tar.gz"
	GEMINI_ACTIVE_URL="$DOWNLOAD_PATH/$TARBALL_DIR/$GEMINI_ACTIVE_PKG"

	# Temp Directories and Log file creations
	$MKDIR_BINARY $TEMP_BASE

if [ -e '/root/GEMINI_GN' ]; then
	#restore some user ids that are destroyed when creating Disk images
	echo 'mongod:x:497:' >>/etc/group
	echo 'mongod:!!:15742::::::' >>/etc/shadow
	echo 'mongod:x:497:497:mongod:/var/lib/mongo:/bin/false' >>/etc/passwd
fi
	cd $TEMP_BASE
	echo "Installing GN software" >>$INSTOOLS_LOG 2>&1;
        $WGET_BINARY -q -P $TEMP_BASE $GEMINI_ACTIVE_URL >>$INSTOOLS_LOG 2>&1;
        $TAR_BINARY -zxf $GEMINI_ACTIVE_PKG >>$INSTOOLS_LOG 2>&1;
        echo "	 Installing Shared-Fedora.sh"  >>$INSTOOLS_LOG 2>&1;
        ./shared-fedora.sh >>$INSTOOLS_LOG 2>&1;
        echo "   Installing LAMP certificate" >>$INSTOOLS_LOG 2>&1;
        install -o root -g perfsonar -m 440 /var/emulab/boot/lampcert.pem /usr/local/etc/protogeni/ssl/
        echo "   Running bootstrap" >>$INSTOOLS_LOG 2>&1;
        /usr/local/etc/lamp/bootstrap.sh ${SLICEURN} ${USERURN} ${GNHOST} ${AUTH_UUID} >> $INSTOOLS_LOG 2>&1;
        #echo "   Installing apache2-fedora.sh"  >>$INSTOOLS_LOG 2>&1;
	#adduser nobody 
	#groupadd perfsonar
	#usermod -aG perfsonar nobody
	#rm -rf /etc/apache2/sites-enabled/ssl
        #./apache2-fedora.sh >>$INSTOOLS_LOG 2>&1;
        #echo "   Installing perfSONAR_PS-Toolkit-fedora.sh"  >>$INSTOOLS_LOG 2>&1;
        #./perfSONAR_PS-Toolkit-fedora.sh >>$INSTOOLS_LOG 2>&1;
	echo "   Installng Measurement Store" >> $INSTOOLS_LOG 2>&1;
	./peri-tornado-fedora.sh >>$INSTOOLS_LOG 2>&1;
	echo "   Installing NL_WRAPPER" >> $INSTOOLS_LOG 2>&1;
	./nl_wrapper.sh >> $INSTOOLS_LOG 2>&1;
	echo "smallfiles = true" >> /etc/mongod.conf;
	echo "nojournal = true" >> /etc/mongod.conf;
	echo "   Starting Mongo DB" >>$INSTOOLS_LOG 2>&1;
	/etc/init.d/mongod start >>$INSTOOLS_LOG 2>&1;
        echo "   Starting Redis" >>$INSTOOLS_LOG 2>&1;
        /etc/init.d/redis start >>$INSTOOLS_LOG 2>&1;
        # TODO: start this from a service checker
	echo "   Starting the Measurement Store" >>$INSTOOLS_LOG 2>&1;
	# wait to make sure mongod is running first
	sleep 5
	cd /tmp
	export OPENSSL_ALLOW_PROXY_CERTS=1
	nohup periscoped &> /tmp/peri.log &
	disown
	cd
	# test blipp_logger startup
        echo "   Starting the blipp_logger" >>$INSTOOLS_LOG 2>&1;
	cd /opt/perfsonar_ps/perfSONAR_PS-Toolkit/web/root/logging
	chmod 755 blipp_logger.py
        echo "   Starting nohup" >>$INSTOOLS_LOG 2>&1;
	nohup ./blipp_logger.py &> /tmp/blipp.log &
        echo "   disown it" >>$INSTOOLS_LOG 2>&1;
	disown
	cd
        echo "   end of blipp_logger" >>$INSTOOLS_LOG 2>&1;

	echo " Setting up webGUI" >>$INSTOOLS_LOG 2>&1;
	$WGET_BINARY -q -P $TEMP_BASE $DOWNLOAD_PATH/$RPM_DIR/nodejs-0.10.32-1.fc15.x86_64.rpm >>$INSTOOLS_LOG 2>&1;
	$WGET_BINARY -q -P $TEMP_BASE $DOWNLOAD_PATH/$RPM_DIR/nodejs-binary-0.10.32-1.fc15.x86_64.rpm >>$INSTOOLS_LOG 2>&1;
	$WGET_BINARY -q -P $TEMP_BASE $DOWNLOAD_PATH/$RPM_DIR/nodejs-npm-0.10.32-1.fc15.x86_64.rpm >>$INSTOOLS_LOG 2>&1;
	$WGET_BINARY -q -P $TEMP_BASE $DOWNLOAD_PATH/$TARBALL_DIR/peri-js-fedora15.tar.gz >>$INSTOOLS_LOG 2>&1;
	cd $TEMP_BASE
	rpm -ivh nodejs*.rpm >>$INSTOOLS_LOG 2>&1;
	$TAR_BINARY -zxf peri-js-fedora15.tar.gz -C /usr/local
	cd /usr/local/peri-js
	npm install
	npm install -g bower
	npm install -g forever
	bower install --allow-root --config.interactive=false
	sudo forever start server.js
	echo " End of webGUI setup" >>$INSTOOLS_LOG 2>&1;
	cd
	# Cleanup Temp Directories and report status as ready
	rm -rf $TEMP_BASE
