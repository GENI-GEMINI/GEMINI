/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.xmpp.widget.ChatSession"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.xmpp.widget.ChatSession"] = true;
dojo.provide("dojox.xmpp.widget.ChatSession");
dojo.declare("dojox.xmpp.widget.ChatSession",
	[dijit.layout.LayoutContainer, dijit._Templated],
	{
			templateString:"<div>\n<div dojoAttachPoint=\"messages\" dojoType=\"dijit.layout.ContentPane\" layoutAlign=\"client\" style=\"overflow:auto\">\n</div>\n<div dojoType=\"dijit.layout.ContentPane\" layoutAlign=\"bottom\" style=\"border-top: 2px solid #333333; height: 35px;\"><input dojoAttachPoint=\"chatInput\" dojoAttachEvent=\"onkeypress: onKeyPress\" style=\"width: 100%;height: 35px;\" /></div>\n</div>\n",
			enableSubWidgets: true, 
			widgetsInTemplate: true,
			
			widgetType: "ChatSession",
			chatWith: null,
			instance: null,
			postCreate: function(){
				//console.log("Neato!");
			},
	
			displayMessage: function(message, type) {
				//console.log("displayMessage", this, message);
				if(message) {
					var name =  message.from ? this.chatWith : "me";
					this.messages.domNode.innerHTML += "<b>" + name + ":</b> " +   message.body + "<br/>";
					this.goToLastMessage();
				}
				
			},
			
			goToLastMessage: function() {
				this.messages.domNode.scrollTop = this.messages.domNode.scrollHeight;
			},
			
			onKeyPress: function(e){
				var key = e.keyCode || e.charCode;
				if ((key == dojo.keys.ENTER) && (this.chatInput.value != "")){
					this.instance.sendMessage({body: this.chatInput.value});
					this.displayMessage( {body: this.chatInput.value}, "out");
					this.chatInput.value = "";
				}
			}
});

}
