/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dijit.TitlePane"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dijit.TitlePane"] = true;
dojo.provide("dijit.TitlePane");

dojo.require("dojo.fx");

dojo.require("dijit._Templated");
dojo.require("dijit.layout.ContentPane");

dojo.declare(
	"dijit.TitlePane",
	[dijit.layout.ContentPane, dijit._Templated],
{
	// summary:
	//		A pane with a title on top, that can be expanded or collapsed.
	//
	// description:
	//		An accessible container with a Title Heading, and a content
	//		section that slides open and closed. TitlePane is an extension to 
	//		`dijit.layout.ContentPane`, providing all the usesful content-control aspects from it.
	//
	// example:
	// | 	// load a TitlePane from remote file:
	// |	var foo = new dijit.TitlePane({ href: "foobar.html", title:"Title" });
	// |	foo.startup();
	//
	// example:
	// |	<!-- markup href example: -->
	// |	<div dojoType="dijit.TitlePane" href="foobar.html" title="Title"></div>
	// 
	// example:
	// |	<!-- markup with inline data -->
	// | 	<div dojoType="dijit.TitlePane" title="Title">
	// |		<p>I am content</p>
	// |	</div>

	// title: String
	//		Title of the pane
	title: "",

	// open: Boolean
	//		Whether pane is opened or closed.
	open: true,

	// duration: Integer
	//		Time in milliseconds to fade in/fade out
	duration: dijit.defaultDuration,

	// baseClass: [protected] String
	//		The root className to use for the various states of this widget
	baseClass: "dijitTitlePane",

	templateString:"<div class=\"${baseClass}\">\n\t<div dojoAttachEvent=\"onclick:toggle, onkeypress:_onTitleKey, onfocus:_handleFocus, onblur:_handleFocus, onmouseenter:_onTitleEnter, onmouseleave:_onTitleLeave\" tabindex=\"0\"\n\t\t\twaiRole=\"button\" class=\"dijitTitlePaneTitle\" dojoAttachPoint=\"titleBarNode,focusNode\">\n\t\t<img src=\"${_blankGif}\" alt=\"\" dojoAttachPoint=\"arrowNode\" class=\"dijitArrowNode\" waiRole=\"presentation\"\n\t\t><span dojoAttachPoint=\"arrowNodeInner\" class=\"dijitArrowNodeInner\"></span\n\t\t><span dojoAttachPoint=\"titleNode\" class=\"dijitTitlePaneTextNode\"></span>\n\t</div>\n\t<div class=\"dijitTitlePaneContentOuter\" dojoAttachPoint=\"hideNode\">\n\t\t<div class=\"dijitReset\" dojoAttachPoint=\"wipeNode\">\n\t\t\t<div class=\"dijitTitlePaneContentInner\" dojoAttachPoint=\"containerNode\" waiRole=\"region\" tabindex=\"-1\">\n\t\t\t\t<!-- nested divs because wipeIn()/wipeOut() doesn't work right on node w/padding etc.  Put padding on inner div. -->\n\t\t\t</div>\n\t\t</div>\n\t</div>\n</div>\n",

	attributeMap: dojo.delegate(dijit.layout.ContentPane.prototype.attributeMap, {
		title: { node: "titleNode", type: "innerHTML" }
	}),

	postCreate: function(){
		if(!this.open){
			this.hideNode.style.display = this.wipeNode.style.display = "none";
		}
		this._setCss();
		dojo.setSelectable(this.titleNode, false);
		dijit.setWaiState(this.containerNode, "labelledby", this.titleNode.id);
		dijit.setWaiState(this.focusNode, "haspopup", "true");

		// setup open/close animations
		var hideNode = this.hideNode, wipeNode = this.wipeNode;
		this._wipeIn = dojo.fx.wipeIn({
			node: this.wipeNode,
			duration: this.duration,
			beforeBegin: function(){
				hideNode.style.display="";
			}
		});
		this._wipeOut = dojo.fx.wipeOut({
			node: this.wipeNode,
			duration: this.duration,
			onEnd: function(){
				hideNode.style.display="none";
			}
		});
		this.inherited(arguments);
	},

	_setOpenAttr: function(/* Boolean */ open){
		// summary:
		//		Hook to make attr("open", boolean) control the open/closed state of the pane.
		// open: Boolean
		//		True if you want to open the pane, false if you want to close it.
		if(this.open !== open){ this.toggle(); }
	},

	_setContentAttr: function(content){
		// summary:
		//		Hook to make attr("content", ...) work.
		// 		Typically called when an href is loaded.  Our job is to make the animation smooth.

		if(!this.open || !this._wipeOut || this._wipeOut.status() == "playing"){
			// we are currently *closing* the pane (or the pane is closed), so just let that continue
			this.inherited(arguments);
		}else{
			if(this._wipeIn && this._wipeIn.status() == "playing"){
				this._wipeIn.stop();
			}

			// freeze container at current height so that adding new content doesn't make it jump
			dojo.marginBox(this.wipeNode, { h: dojo.marginBox(this.wipeNode).h });

			// add the new content (erasing the old content, if any)
			this.inherited(arguments);

			// call _wipeIn.play() to animate from current height to new height
			if(this._wipeIn){
				this._wipeIn.play();
			}else{
				this.hideNode.style.display = "";
			}
		}
	},

	toggle: function(){
		// summary:
		//		Switches between opened and closed state
		// tags:
		//		private

		dojo.forEach([this._wipeIn, this._wipeOut], function(animation){
			if(animation && animation.status() == "playing"){
				animation.stop();
			}
		});

		var anim = this[this.open ? "_wipeOut" : "_wipeIn"]
		if(anim){
			anim.play();
		}else{
			this.hideNode.style.display = this.open ? "" : "none";
		}
		this.open =! this.open;

		// load content (if this is the first time we are opening the TitlePane
		// and content is specified as an href, or href was set when hidden)
		this._onShow();

		this._setCss();
	},

	_setCss: function(){
		// summary:
		//		Set the open/close css state for the TitlePane
		// tags:
		//		private

		var classes = ["dijitClosed", "dijitOpen"];
		var boolIndex = this.open;
		var node = this.titleBarNode || this.focusNode;
		dojo.removeClass(node, classes[!boolIndex+0]);
		node.className += " " + classes[boolIndex+0];

		// provide a character based indicator for images-off mode
		this.arrowNodeInner.innerHTML = this.open ? "-" : "+";
	},

	_onTitleKey: function(/*Event*/ e){
		// summary:
		//		Handler for when user hits a key
		// tags:
		//		private

		if(e.charOrCode == dojo.keys.ENTER || e.charOrCode == ' '){
			this.toggle();
		}else if(e.charOrCode == dojo.keys.DOWN_ARROW && this.open){
			this.containerNode.focus();
			e.preventDefault();
	 	}
	},
	
	_onTitleEnter: function(){
		// summary:
		//		Handler for when someone hovers over my title
		// tags:
		//		private
		dojo.addClass(this.focusNode, "dijitTitlePaneTitle-hover");
	},

	_onTitleLeave: function(){
		// summary:
		//		Handler when someone stops hovering over my title
		// tags:
		//		private
		dojo.removeClass(this.focusNode, "dijitTitlePaneTitle-hover");
	},

	_handleFocus: function(/*Event*/ e){
		// summary:
		//		Handle blur and focus for this widget
		// tags:
		//		private
		
		// add/removeClass is safe to call without hasClass in this case
		dojo[(e.type == "focus" ? "addClass" : "removeClass")](this.focusNode, this.baseClass + "Focused");
	},

	setTitle: function(/*String*/ title){
		// summary:
		//		Deprecated.  Use attr('title', ...) instead.
		// tags:
		//		deprecated
		dojo.deprecated("dijit.TitlePane.setTitle() is deprecated.  Use attr('title', ...) instead.", "", "2.0");
		this.titleNode.innerHTML = title;
	}
});

}
