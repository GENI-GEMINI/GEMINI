/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.data.JsonQueryRestStore"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.data.JsonQueryRestStore"] = true;
dojo.provide("dojox.data.JsonQueryRestStore");
dojo.require("dojox.data.JsonRestStore");
dojo.require("dojox.data.util.JsonQuery");

dojo.requireIf(!!dojox.data.ClientFilter,"dojox.json.query"); // this is so we can perform queries locally 

// this is an extension of JsonRestStore to convert object attribute queries to 
// JSONQuery/JSONPath syntax to be sent to the server. This also enables
//	JSONQuery/JSONPath queries to be performed locally if dojox.data.ClientFilter
//	has been loaded
dojo.declare("dojox.data.JsonQueryRestStore",[dojox.data.JsonRestStore,dojox.data.util.JsonQuery],{
	matchesQuery: function(item,request){
		return item.__id && (item.__id.indexOf("#") == -1) && this.inherited(arguments);
	}
});

}
