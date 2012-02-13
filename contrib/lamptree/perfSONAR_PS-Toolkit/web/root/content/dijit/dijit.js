/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dijit.dijit"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dijit.dijit"] = true;
dojo.provide("dijit.dijit");

/*=====
dijit.dijit = {
	// summary: A roll-up for common dijit methods
	// description:
	//	A rollup file for the build system including the core and common
	//	dijit files.
	//	
	// example:
	// | <script type="text/javascript" src="js/dojo/dijit/dijit.js"></script>
	//
};
=====*/

// All the stuff in _base (these are the function that are guaranteed available without an explicit dojo.require)
dojo.require("dijit._base");

// And some other stuff that we tend to pull in all the time anyway
dojo.require("dojo.parser");
dojo.require("dijit._Widget");
dojo.require("dijit._Templated");
dojo.require("dijit._Container");
dojo.require("dijit.layout._LayoutWidget");
dojo.require("dijit.form._FormWidget");

}
