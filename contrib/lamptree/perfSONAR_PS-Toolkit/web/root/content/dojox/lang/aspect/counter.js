/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.lang.aspect.counter"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.lang.aspect.counter"] = true;
dojo.provide("dojox.lang.aspect.counter");

(function(){
	var aop = dojox.lang.aspect;
	
	var Counter = function(){
		this.reset();
	};
	dojo.extend(Counter, {
		before: function(/*arguments*/){
			++this.calls;
		},
		afterThrowing: function(/*excp*/){
			++this.errors;
		},
		reset: function(){
			this.calls = this.errors = 0;
		}
	});
	
	aop.counter = function(){
		// summary:
		//		Returns an object, which can be used to count calls to methods.
	
		return new Counter;	// Object
	};
})();

}
