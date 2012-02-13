/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.rpc.Client"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.rpc.Client"] = true;
dojo.provide("dojox.rpc.Client");
// Provide extra headers for robust client and server communication
(function() {
	dojo._defaultXhr = dojo.xhr;
	dojo.xhr = function(method,args){
		var headers = args.headers = args.headers || {};
		// set the client id, this can be used by servers to maintain state information with the
		// a specific client. Many servers rely on sessions for this, but sessions are shared
		// between tabs/windows, so this is not appropriate for application state, it
		// really only useful for storing user authentication
		headers["Client-Id"] = dojox.rpc.Client.clientId;
		// set the sequence id. HTTP is non-deterministic, message can arrive at the server
		// out of order. In complex Ajax applications, it may be more to ensure that messages
		// can be properly sequenced deterministically. This applies a sequency id to each
		// XHR request so that the server can order them.
		headers["Seq-Id"] = dojox._reqSeqId = (dojox._reqSeqId||0)+1;
		return dojo._defaultXhr.apply(dojo,arguments);
	}
})();
// initiate the client id to a good random number
dojox.rpc.Client.clientId = (Math.random() + '').substring(2,14);

}
