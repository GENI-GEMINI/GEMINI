/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.av.widget.PlayButton"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.av.widget.PlayButton"] = true;
dojo.provide("dojox.av.widget.PlayButton");
dojo.require("dijit._Widget");
dojo.require("dijit._Templated");
dojo.require("dijit.form.Button");

dojo.declare("dojox.av.widget.PlayButton", [dijit._Widget, dijit._Templated], {
	// summary:
	//		A Play/Pause button widget to use with dojox.av.widget.Player
	//
	templateString:"<div class=\"PlayPauseToggle Pause\" dojoAttachEvent=\"click:onClick\">\n    <div class=\"icon\"></div>\n</div>\n",
	//
	postCreate: function(){
		// summary:
		//		Intialize button.
		this.showPlay();
	},
	
	setMedia: function(/* Object */med){
		// summary:
		//		A common method to set the media in all Player widgets.
		//		May do connections and initializations.
		//
		this.media = med;
		dojo.connect(this.media, "onEnd", this, "showPlay");
		dojo.connect(this.media, "onStart", this, "showPause");
	},
	
	onClick: function(){
		// summary:
		//		Fired on play or pause click.
		//
		if(this._mode=="play"){
			this.onPlay();	
		}else{
			this.onPause();
		}
	},
	
	onPlay: function(){
		// summary:
		//		Fired on play click.
		//
		if(this.media){
			this.media.play();
		}
		this.showPause();
	},
	onPause: function(){
		// summary:
		//		Fired on pause click.
		//
		if(this.media){
			this.media.pause();
		}
		this.showPlay();
	},
	showPlay: function(){
		// summary:
		//		Toggles the pause button invisible and the play 
		//		button visible..
		//
		this._mode = "play";
		dojo.removeClass(this.domNode, "Pause");
		dojo.addClass(this.domNode, "Play");
	},
	showPause: function(){
		// summary:
		//		Toggles the play button invisible and the pause 
		//		button visible.
		//
		this._mode = "pause";
		dojo.addClass(this.domNode, "Pause");
		dojo.removeClass(this.domNode, "Play");
	}
});

}
