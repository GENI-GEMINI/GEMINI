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
DEFS_FILE="/usr/testbed/bin/measure-scripts/INSTALL_DEFS.sh"
while [ ! -e $DEFS_FILE ];do
	echo "/usr/testbed/bin/measure-scripts/INSTALL_DEFS.sh does not exist. Will check again after 30 secs"
    sleep 30
done
source $DEFS_FILE 

ACTIVE_NODETYPE=$1
ACTIVE_OPTION=$2
if [[ $3 != "" ]]; then
	SLICEURN=$3
fi
if [[ $4 != "" ]]; then
	USERURN=$4
fi
if [[ $5 != "" ]]; then
        GNHOST=$5
fi
if [[ $6 != "" ]]; then
        AUTH_UUID=$6
fi
if [[ $7 != "" ]]; then
	UNIS_ID=$7
fi


RM_BINARY="rm -rf"
TEMP=/tmp
$TOUCH_BINARY $INSTOOLS_LOG;
chmod 776 $INSTOOLS_LOG;

version_check
FILE_PATH=$VERSION
if [[ $FILE_PATH == "" ]]; then
	echo "This OS version does NOT support Active Measurement installation" >>$INSTOOLS_LOG 2>&1;
	# Setup flag to inform calling program this node setup is complete : This will be changed later to a different status
	 $TOUCH_BINARY $NOTSUPPORTED_FLAG
	 exit 1
fi
echo "Supported OS Found.." >>$INSTOOLS_LOG 2>&1;
if [[ $ACTIVE_OPTION == "INSTALL" ]]; then
	SETUP_FILE=$ACTIVE_NODETYPE"-active_pkg_install.sh" >>$INSTOOLS_LOG 2>&1;
	echo "Starting install.." >>$INSTOOLS_LOG 2>&1;
else
	SETUP_FILE=$ACTIVE_NODETYPE"-active_pkg_remove.sh" >>$INSTOOLS_LOG 2>&1;
	echo "Starting uninstall.." >>$INSTOOLS_LOG 2>&1;
fi
$WGET_BINARY -q -P $TEMP $DOWNLOAD_PATH/$SCRIPTS_DIR/$FILE_PATH/$SETUP_FILE >>$INSTOOLS_LOG 2>&1;
cd $TEMP
chmod +x $SETUP_FILE
./$SETUP_FILE $SLICEURN $USERURN $GNHOST $AUTH_UUID $UNIS_ID
