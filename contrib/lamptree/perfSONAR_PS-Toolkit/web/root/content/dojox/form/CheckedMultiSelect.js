/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.form.CheckedMultiSelect"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.form.CheckedMultiSelect"] = true;
dojo.provide("dojox.form.CheckedMultiSelect");

dojo.require("dijit.form.CheckBox");
dojo.require("dojox.form._FormSelectWidget");

dojo.declare("dojox.form._CheckedMultiSelectItem", 
	[dijit._Widget, dijit._Templated],
	{
	// summary:
	//		The individual items for a CheckedMultiSelect

	widgetsInTemplate: true,
	templateString:"<div class=\"dijitReset ${baseClass}\"\n\t><input class=\"${baseClass}Box\" dojoType=\"dijit.form.CheckBox\" dojoAttachPoint=\"checkBox\" \n\t\tdojoAttachEvent=\"_onClick:_changeBox\" type=\"${_type.type}\" baseClass=\"${_type.baseClass}\"\n\t><div class=\"dijitInline ${baseClass}Label\" dojoAttachPoint=\"labelNode\" dojoAttachEvent=\"onmousedown:_onMouse,onmouseover:_onMouse,onmouseout:_onMouse,onclick:_onClick\"></div\n></div>\n",

	baseClass: "dojoxMultiSelectItem",

	// option: dojox.form.__SelectOption
	//		The option that is associated with this item
	option: null,
	parent: null,
	
	// disabled: boolean
	//		Whether or not this widget is disabled
	disabled: false,

	// readOnly: boolean
	//		Whether or not this widget is readOnly
	readOnly: false,

	postMixInProperties: function(){
		// summary:
		//		Set the appropriate _subClass value - based on if we are multi-
		//		or single-select
		if(this.parent._multiValue){
			this._type = {type: "checkbox", baseClass: "dijitCheckBox"};
		}else{
			this._type = {type: "radio", baseClass: "dijitRadio"};
		}
		this.disabled = this.option.disabled = this.option.disabled||false;
		this.inherited(arguments);
	},

	postCreate: function(){
		// summary:
		//		Set innerHTML here - since the template gets messed up sometimes
		//		with rich text
		this.inherited(arguments);
		this.labelNode.innerHTML = this.option.label;
	},

	_changeBox: function(){
		// summary:
		//		Called to force the select to match the state of the check box
		//		(only on click of the checkbox)  Radio-based calls _setValueAttr
		//		instead.
		if(this.attr("disabled") || this.attr("readOnly")){ return; }
		if(this.parent._multiValue){
			this.option.selected = this.checkBox.attr('value') && true;
		}else{
			this.parent.attr('value', this.option.value);
		}
		// fire the parent's change
		this.parent._updateSelection();
		
		// refocus the parent
		this.parent.focus();
	},

	_onMouse: function(e){
		// summary:
		//		Sets the hover state depending on mouse state (passes through
		//		to the check box)
		if(this.attr("disabled") || this.attr("readOnly")){
			dojo.stopEvent(e);
		}else{
			this.checkBox._onMouse(e);
		}
	},
	
	_onClick: function(e){
		// summary:
		//		Sets the click state (passes through to the check box)
		if(this.attr("disabled") || this.attr("readOnly")){
			dojo.stopEvent(e);
		}else{
			this.checkBox._onClick(e);
		}
	},
	
	_updateBox: function(){
		// summary:
		//		Called to force the box to match the state of the select
		this.checkBox.attr('value', this.option.selected);
	},
	
	_setDisabledAttr: function(value){
		// summary:
		//		Disables (or enables) all the children as well
		this.disabled = value||this.option.disabled;
		this.checkBox.attr("disabled", this.disabled);
		dojo.toggleClass(this.domNode, "dojoxMultiSelectDisabled", this.disabled);
	},
	
	_setReadOnlyAttr: function(value){
		// summary:
		//		Sets read only (or unsets) all the children as well
		this.checkBox.attr("readOnly", value);
		this.checkBox._setStateClass();
		this.readOnly = value;
	}
});

dojo.declare("dojox.form.CheckedMultiSelect", dojox.form._FormSelectWidget, {
	// summary:
	//		Extends the core dijit MultiSelect to provide a "checkbox" selector

	templateString: "",
	templateString:"<div class=\"dijit dijitReset dijitInline\" dojoAttachEvent=\"onmousedown:_mouseDown,onclick:focus\"\n\t><select class=\"${baseClass}Select\" multiple=\"true\" dojoAttachPoint=\"containerNode,focusNode\"></select\n\t><div dojoAttachPoint=\"wrapperDiv\"></div\n></div>\n",

	baseClass: "dojoxMultiSelect",

	_mouseDown: function(e){
		// summary:
		//		Cancels the mousedown event to prevent others from stealing
		//		focus
		dojo.stopEvent(e);
	},
	
	_addOptionItem: function(/* dojox.form.__SelectOption */ option){
		this.wrapperDiv.appendChild(new dojox.form._CheckedMultiSelectItem({
			option: option,
			parent: this
		}).domNode);
	},
	
	_updateSelection: function(){
		this.inherited(arguments);
		dojo.forEach(this._getChildren(), function(c){ c._updateBox(); });
	},
	
	_getChildren: function(){
		return dojo.map(this.wrapperDiv.childNodes, function(n){
			return dijit.byNode(n);
		});
	},

	invertSelection: function(onChange){
		// summary: Invert the selection
		// onChange: Boolean
		//		If null, onChange is not fired.
		dojo.forEach(this.options, function(i){
			i.selected = !i.selected;
		});
		this._updateSelection();
	},

	_setDisabledAttr: function(value){
		// summary:
		//		Disable (or enable) all the children as well
		this.inherited(arguments);
		dojo.forEach(this._getChildren(), function(node){
			if(node && node.attr){
				node.attr("disabled", value);
			}
		});
	},
	
	_setReadOnlyAttr: function(value){
		// summary:
		//		Sets read only (or unsets) all the children as well
		if("readOnly" in this.attributeMap){
			this._attrToDom("readOnly", value);
		}
		this.readOnly = value;
		dojo.forEach(this._getChildren(), function(node){
			if(node && node.attr){
				node.attr("readOnly", value);
			}
		});
		this._setStateClass();
	},

	uninitialize: function(){
		// Make sure these children are destroyed
		dojo.forEach(this._getChildren(), function(child){
			child.destroyRecursive();
		});
	}
});

}
