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

TOUCH_BINARY="touch"
$TOUCH_BINARY $INSTOOLS_LOG;
chmod 776 $INSTOOLS_LOG;


	TEMP_BASE=/tmp/MP-SETUP
	SLICEURN=$1
	USERURN=$2
	GNHOST=$3
	AUTH_UUID=$4
	UNIS_ID=$5

	#$WGET_BINARY -q -P $TEMP_BASE $DOWNLOAD_PATH/$TARBALL_DIR/shadownet_public_key.tgz >>$INSTOOLS_LOG 2>&1;
	#BINARY PATHS
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
	GEMINI_ACTIVE_PKG="gemini-active-mp-ubuntu12-lite-20130701.tar.gz"
	GEMINI_ACTIVE_URL="$DOWNLOAD_PATH/$TARBALL_DIR/$GEMINI_ACTIVE_PKG"

	# Temp Directories and Log file creations
	$MKDIR_BINARY $TEMP_BASE
	cd $TEMP_BASE

if [ -e '/root/GEMINI_MP' ]; then
	#restore some user ids that are destroyed when creating Disk images
	echo 'mysql:x:27:' >>/etc/group
	echo 'mysql:!!:15742::::::' >>/etc/shadow
	echo 'mysql:x:27:27:MySQL Server:/var/lib/mysql:/bin/bash' >>/etc/passwd
fi

        echo "Installing MP software on node"  >>$INSTOOLS_LOG 2>&1;
        $WGET_BINARY -q -P $TEMP_BASE $GEMINI_ACTIVE_URL >>$INSTOOLS_LOG 2>&1;
        $TAR_BINARY -zxf $GEMINI_ACTIVE_PKG >>$INSTOOLS_LOG 2>&1;

        echo "   Installing Shared-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        ./Shared-Ubuntu.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing LAMP certificate"  >>$INSTOOLS_LOG 2>&1;
        install -o root -g perfsonar -m 440 /var/emulab/boot/lampcert.pem /usr/local/etc/protogeni/ssl/  >>$INSTOOLS_LOG 2>&1;
        echo "   Running bootstrap"   >>$INSTOOLS_LOG 2>&1;
        /usr/local/etc/lamp/bootstrap.sh ${SLICEURN} ${USERURN} ${GNHOST} ${AUTH_UUID} ${UNIS_ID} >>$INSTOOLS_LOG 2>&1;
        echo "   Installing mysql-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        ./mysql-Ubuntu.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-ServiceWatcher-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        ./perfSONAR_PS-ServiceWatcher-Ubuntu.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-psConfig-Fedora.sh"    >>$INSTOOLS_LOG 2>&1;
        ./perfSONAR_PS-pSConfig-Ubuntu.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-LSRegistrationDaemon-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        ./perfSONAR_PS-LSRegistrationDaemon-Ubuntu.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-perfSONARBUOY-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        ./perfSONAR_PS-perfSONARBUOY-Ubuntu.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-PingER-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        ./perfSONAR_PS-PingER-Ubuntu.sh  >>$INSTOOLS_LOG 2>&1;
	echo "   Installing BLiPP" >>$INSTOOLS_LOG 2>&1;
	./blipp-Ubuntu.sh >>$INSTOOLS_LOG 2>&1;
	# TODO: start this from a service checker
	echo "   Starting BLiPP" >>$INSTOOLS_LOG 2>&1;
	#GNIP=`ping -c 1 $GNHOST | awk 'NR==1{print $3}' | sed 's/(//;s/)//'`
	#echo "$GNIP server" >> /etc/hosts;
	nohup /usr/local/bin/blippd -c /usr/local/etc/blipp_default.json &> /dev/null &
	disown
	cd

	# Cleanup Temp Directories and report status as ready
	rm -rf $TEMP_BASE
