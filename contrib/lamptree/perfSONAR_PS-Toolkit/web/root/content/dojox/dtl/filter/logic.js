/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.dtl.filter.logic"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.dtl.filter.logic"] = true;
dojo.provide("dojox.dtl.filter.logic");

dojo.mixin(dojox.dtl.filter.logic, {
	default_: function(value, arg){
		// summary: If value is unavailable, use given default
		return value || arg || "";
	},
	default_if_none: function(value, arg){
		// summary: If value is null, use given default
		return (value === null) ? arg || "" : value || "";
	},
	divisibleby: function(value, arg){
		// summary: Returns true if the value is devisible by the argument"
		return (parseInt(value, 10) % parseInt(arg, 10)) === 0;
	},
	_yesno: /\s*,\s*/g,
	yesno: function(value, arg){
		// summary:
		//		arg being a comma-delimited string, value of true/false/none
		//		chooses the appropriate item from the string
		if(!arg){
			arg = 'yes,no,maybe';
		}
		var parts = arg.split(dojox.dtl.filter.logic._yesno);
		if(parts.length < 2){
			return value;
		}
		if(value){
			return parts[0];
		}
		if((!value && value !== null) || parts.length < 3){
			return parts[1];
		}
		return parts[2];
	}
});

}
