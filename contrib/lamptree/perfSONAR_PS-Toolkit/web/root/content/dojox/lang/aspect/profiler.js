/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.lang.aspect.profiler"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.lang.aspect.profiler"] = true;
dojo.provide("dojox.lang.aspect.profiler");

(function(){
	var aop = dojox.lang.aspect,
		uniqueNumber = 0;
	
	var Profiler = function(title){
		this.args = title ? [title] : [];
		this.inCall = 0;
	};
	dojo.extend(Profiler, {
		before: function(/*arguments*/){
			if(!(this.inCall++)){
				console.profile.apply(console, this.args);
			}
		},
		after: function(/*excp*/){
			if(!--this.inCall){
				console.profileEnd();
			}
		}
	});
	
	aop.profiler = function(/*String?*/ title){
		// summary:
		//		Returns an object, which can be used to time calls to methods.
		//
		// title:
		//		The optional name of the profile section.
	
		return new Profiler(title);	// Object
	};
})();

}
