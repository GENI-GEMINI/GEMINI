/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.lang.aspect.timer"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.lang.aspect.timer"] = true;
dojo.provide("dojox.lang.aspect.timer");

(function(){
	var aop = dojox.lang.aspect,
		uniqueNumber = 0;
	
	var Timer = function(name){
		this.name = name || ("DojoAopTimer #" + ++uniqueNumber);
		this.inCall = 0;
	};
	dojo.extend(Timer, {
		before: function(/*arguments*/){
			if(!(this.inCall++)){
				console.time(this.name);
			}
		},
		after: function(/*excp*/){
			if(!--this.inCall){
				console.timeEnd(this.name);
			}
		}
	});
	
	aop.timer = function(/*String?*/ name){
		// summary:
		//		Returns an object, which can be used to time calls to methods.
		//
		// name:
		//		The optional unique name of the timer.

		return new Timer(name);	// Object
	};
})();

}
