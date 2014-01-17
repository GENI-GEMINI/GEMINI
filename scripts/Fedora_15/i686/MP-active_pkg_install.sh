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


	TEMP_BASE=/tmp/GN-SETUP
	SLICEURN=$1
	USERURN=$2
	
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
	GEMINI_ACTIVE_PKG="gemini-mp-active-fedora15-20120531.tar.gz"
	GEMINI_ACTIVE_URL="https://github.com/downloads/GENI-GEMINI/GEMINI/"$GEMINI_ACTIVE_PKG

	# Temp Directories and Log file creations
	$MKDIR_BINARY $TEMP_BASE


        echo "Installing MP software on node"  >>$INSTOOLS_LOG 2>&1;
        $WGET_BINARY -q -P $TEMP_BASE $GEMINI_ACTIVE_URL >>$INSTOOLS_LOG 2>&1;
	cd $TEMP_BASE
        $TAR_BINARY -zxf $GEMINI_ACTIVE_PKG >>$INSTOOLS_LOG 2>&1;

        echo "   Installing Shared-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        $TEMP_BASE/Shared-Fedora.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing LAMP certificate"  >>$INSTOOLS_LOG 2>&1;
        install -o root -g perfsonar -m 440 lampcert.pem /usr/local/etc/protogeni/ssl/  >>$INSTOOLS_LOG 2>&1;
        echo "   Running bootstrap"   >>$INSTOOLS_LOG 2>&1;
        /usr/local/etc/lamp/bootstrap.sh ${SLICEURN} ${USERURN}  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing mysql-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        $TEMP_BASE/mysql-Fedora.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-ServiceWatcher-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        $TEMP_BASE/perfSONAR_PS-ServiceWatcher-Fedora.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-psConfig-Fedora.sh"    >>$INSTOOLS_LOG 2>&1;
        $TEMP_BASE/perfSONAR_PS-pSConfig-Fedora.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-LSRegistrationDaemon-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        $TEMP_BASE/perfSONAR_PS-LSRegistrationDaemon-Fedora.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-perfSONARBUOY-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        $TEMP_BASE/perfSONAR_PS-perfSONARBUOY-Fedora.sh  >>$INSTOOLS_LOG 2>&1;
        echo "   Installing perfSONAR_PS-PingER-Fedora.sh"   >>$INSTOOLS_LOG 2>&1;
        $TEMP_BASE/perfSONAR_PS-PingER-Fedora.sh  >>$INSTOOLS_LOG 2>&1;

	# Cleanup Temp Directories and report status as ready
	rm -rf $TEMP_BASE
