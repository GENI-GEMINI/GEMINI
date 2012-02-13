/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dijit._editor.plugins.TextColor"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dijit._editor.plugins.TextColor"] = true;
dojo.provide("dijit._editor.plugins.TextColor");

dojo.require("dijit._editor._Plugin");
dojo.require("dijit.ColorPalette");

dojo.declare("dijit._editor.plugins.TextColor",
	dijit._editor._Plugin,
	{
		//	summary:
		//		This plugin provides dropdown color pickers for setting text color and background color
		//
		//	description:
		//		The commands provided by this plugin are:
		//		* foreColor - sets the text color
		//		* hiliteColor - sets the background color

		// Override _Plugin.buttonClass to use DropDownButton (with ColorPalette) to control this plugin
		buttonClass: dijit.form.DropDownButton,

//TODO: set initial focus/selection state?

		constructor: function(){
			this.dropDown = new dijit.ColorPalette();
			this.connect(this.dropDown, "onChange", function(color){
				this.editor.execCommand(this.command, color);
			});
		}
	}
);

// Register this plugin.
dojo.subscribe(dijit._scopeName + ".Editor.getPlugin",null,function(o){
	if(o.plugin){ return; }
	switch(o.args.name){
	case "foreColor": case "hiliteColor":
		o.plugin = new dijit._editor.plugins.TextColor({command: o.args.name});
	}
});

}
