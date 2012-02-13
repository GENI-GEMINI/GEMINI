/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.lang.aspect.cflow"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.lang.aspect.cflow"] = true;
dojo.provide("dojox.lang.aspect.cflow");


(function(){
	var aop = dojox.lang.aspect;
	
	aop.cflow = function(/*Object*/ instance, /*String|RegExp|Array?*/ method){
		// summary:
		//		Returns true if the context stack contains a context for a given
		//		instance that satisfies a given method name criteria.
		//
		// instance:
		//		An instance to be matched. If null, any context will be examined.
		//		Otherwise the context should belong to this instance.
		//
		// method:
		//		An optional pattern to be matched against a method name. Can be a string,
		//		a RegExp object or an array of strings and RegExp objects.
		//		If it is omitted, any name will satisfy the criteria.
	
		if(arguments.length > 1 && !(method instanceof Array)){
			method = [method];
		}
	
		var contextStack = aop.getContextStack();
		for(var i = contextStack.length - 1; i >= 0; --i){
			var c = contextStack[i];
			// check if instance matches
			if(instance && c.instance != instance){ continue; }
			if(!method){ return true; }
			var n = c.joinPoint.targetName;
			for(var j = method.length - 1; j >= 0; --j){
				var m = method[j];
				if(m instanceof RegExp){
					if(m.test(n)){ return true; }
				}else{
					if(n == m){ return true; }
				}
			}
		}
		return false;	// Boolean
	};
})();

}
