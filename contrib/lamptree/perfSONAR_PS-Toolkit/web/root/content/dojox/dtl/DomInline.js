/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.dtl.DomInline"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.dtl.DomInline"] = true;
dojo.provide("dojox.dtl.DomInline");
dojo.require("dojox.dtl.dom");

dojo.require("dijit._Widget");

dojox.dtl.DomInline = dojo.extend(function(args, node){
	this.create(args, node);
},
dijit._Widget.prototype,
{
	context: null,
	render: function(/*dojox.dtl.Context?*/ context){
		this.context = context || this.context;
		this.postMixInProperties();
		var root = this.template.render(this.context).getRootNode();
		if(root != this.containerNode){
			this.containerNode.parentNode.replaceChild(root, this.containerNode);
			this.containerNode = root;
		}
	},
	declaredClass: "dojox.dtl.Inline",
	buildRendering: function(){
		var div = this.domNode = document.createElement("div");
		this.containerNode = div.appendChild(document.createElement("div"));
		var node = this.srcNodeRef;
		if(node.parentNode){
			node.parentNode.replaceChild(div, node);
		}

		this.template = new dojox.dtl.DomTemplate(dojo.trim(node.text), true);
		this.render();
	},
	postMixInProperties: function(){
		this.context = (this.context.get === dojox.dtl._Context.prototype.get) ? this.context : new dojox.dtl.Context(this.context);
	}
});

}
