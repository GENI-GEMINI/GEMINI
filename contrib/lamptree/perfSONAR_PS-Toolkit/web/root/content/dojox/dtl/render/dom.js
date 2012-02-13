/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.dtl.render.dom"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.dtl.render.dom"] = true;
dojo.provide("dojox.dtl.render.dom");

dojo.require("dojox.dtl.Context");
dojo.require("dojox.dtl.dom");

dojox.dtl.render.dom.Render = function(/*DOMNode?*/ attachPoint, /*dojox.dtl.DomTemplate?*/ tpl){
	this._tpl = tpl;
	this.domNode = dojo.byId(attachPoint);
}
dojo.extend(dojox.dtl.render.dom.Render, {
	setAttachPoint: function(/*Node*/ node){
		this.domNode = node;
	},
	render: function(/*Object*/ context, /*dojox.dtl.DomTemplate?*/ tpl, /*dojox.dtl.DomBuffer?*/ buffer){
		if(!this.domNode){
			throw new Error("You cannot use the Render object without specifying where you want to render it");
		}

		this._tpl = tpl = tpl || this._tpl;
		buffer = buffer || tpl.getBuffer();
		context = context || new dojox.dtl.Context();

		var frag = tpl.render(context, buffer).getParent();
		if(!frag){
			throw new Error("Rendered template does not have a root node");
		}

		if(this.domNode !== frag){
			this.domNode.parentNode.replaceChild(frag, this.domNode);
			this.domNode = frag;
		}
	}
});

}
