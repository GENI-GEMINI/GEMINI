#! /usr/bin/env python
#
# GENIPUBLIC-COPYRIGHT
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
# All rights reserved.
# 
# Permission to use, copy, modify and distribute this software is hereby
# granted provided that (1) source code retains these copyright, permission,
# and disclaimer notices, and (2) redistributions including binaries
# reproduce the notices in supporting documentation.
#
# THE UNIVERSITY OF UTAH ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS"
# CONDITION.  THE UNIVERSITY OF UTAH DISCLAIMS ANY LIABILITY OF ANY KIND
# FOR ANY DAMAGES WHATSOEVER RESULTING FROM THE USE OF THIS SOFTWARE.
#

#
#
import sys
import pwd
import getopt
import os
import time
import re
import xmlrpclib
from M2Crypto import X509

ACCEPTSLICENAME=1

execfile( os.path.dirname(os.path.abspath(__file__)) + os.sep + "test-common.py" )

if len(REQARGS) > 0:
    Usage()
    sys.exit( 1 )

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential, looking up " + SLICENAME

#
# Lookup slice.
#
params = {}
params["credential"] = mycredential
params["type"]       = "Slice"
params["hrn"]        = SLICENAME
rval,response = do_method("sa", "Resolve", params)
if rval:
    #
    # Exit
    #
    Fatal("Error resolving slice: " + response);
    pass
else:
    #
    # Get the slice credential.
    #
    print "Asking for slice credential for " + SLICENAME
    myslice = get_slice_credential( response[ "value" ], mycredential )
    print "Got the slice credential"
    pass


print "Asking for my lamp certificate"

lampca = "https://blackseal.damsl.cis.udel.edu/protogeni/xmlrpc/lampca"

params = {}
params["credential"] = (myslice,)
rval,response = do_method("lamp", "GetLAMPSliceCertificate", params, URI=lampca)
if rval:
    Fatal("Could not get ticket: " + response)
    pass

print "Paste the following certificate *as is* into a file called lampcert.pem"
print "Upload the certificate to all LAMP enabled nodes at /usr/local/etc/protogeni/ssl/lampcert.pem"
print response["value"]

