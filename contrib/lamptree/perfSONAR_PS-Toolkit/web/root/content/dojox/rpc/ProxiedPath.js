/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.rpc.ProxiedPath"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.rpc.ProxiedPath"] = true;
dojo.provide("dojox.rpc.ProxiedPath");
dojo.require("dojox.rpc.Service");

dojox.rpc.envelopeRegistry.register(
	"PROXIED-PATH",function(str){return str == "PROXIED-PATH"},{
		serialize:function(smd, method, data){
			var i;
			var target = dojox.rpc.getTarget(smd, method);
			if(dojo.isArray(data)){
				for(i = 0; i < data.length;i++){
					target += '/' + (data[i] == null ? "" : data[i]);
				}
			}else{
				for(i in data){
					target += '/' + i + '/' + data[i];
				}
			}
			return {
				data:'',
				target: (method.proxyUrl || smd.proxyUrl) + "?url=" + encodeURIComponent(target)
			};
		},
		deserialize:function(results){
			return results;
		}
	}
);

}
