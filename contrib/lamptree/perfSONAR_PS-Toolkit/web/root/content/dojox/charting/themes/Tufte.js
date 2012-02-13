/*
	Copyright (c) 2004-2009, The Dojo Foundation All Rights Reserved.
	Available via Academic Free License >= 2.1 OR the modified BSD license.
	see: http://dojotoolkit.org/license for details
*/


if(!dojo._hasResource["dojox.charting.themes.Tufte"]){ //_hasResource checks added by build. Do not use _hasResource directly in your code.
dojo._hasResource["dojox.charting.themes.Tufte"] = true;
dojo.provide("dojox.charting.themes.Tufte");
dojo.require("dojox.charting.Theme");

/*
	A charting theme based on the principles championed by
	Edward Tufte.  By Alex Russell, Dojo Project Lead.
*/
(function(){
	var dxc=dojox.charting;
	dxc.themes.Tufte = new dxc.Theme({
		antiAlias: false,
		chart: {
			stroke: null,
			fill: "inherit"
		},
		plotarea: {
			// stroke: { width: 0.2, color: "#666666" },
			stroke: null,
			fill: "transparent"
		},
		axis:{
			stroke:{ width:	0 },
			line:{ width:	0 },
			majorTick:{ 
				color:	"#666666", 
				width:	1,
				length: 5
			},
			minorTick: { 
				color:	"black", 
				width:	1, 
				length:	2
			},
			font:"normal normal normal 8pt Tahoma",
			fontColor:"#999999"
		},
		series:{
			outline:{ width: 0, color: "black" },
			stroke:	{ width: 1, color: "black" },
			// fill:	dojo.colorFromHex("#3b444b"),
			fill:new dojo.Color([0x3b, 0x44, 0x4b, 0.85]),
			font: "normal normal normal 7pt Tahoma",	//	label
			fontColor: "#717171"
		},
		marker:{	//	any markers on a series.
			stroke:{ width:1 },
			fill:"#333",
			font:"normal normal normal 7pt Tahoma",	//	label
			fontColor:"#000"
		},
		colors:[
			dojo.colorFromHex("#8a8c8f"), 
			dojo.colorFromHex("#4b4b4b"),
			dojo.colorFromHex("#3b444b"), 
			dojo.colorFromHex("#2e2d30"),
			dojo.colorFromHex("#000000") 
		]
	});
})();

}
