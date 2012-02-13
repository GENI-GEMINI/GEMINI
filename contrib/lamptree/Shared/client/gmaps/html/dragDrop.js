function addEventSimple(obj,evt,fn) {
	if (obj.addEventListener)
		obj.addEventListener(evt,fn,false);
	else if (obj.attachEvent)
		obj.attachEvent('on'+evt,fn);
}

function removeEventSimple(obj,evt,fn) {
	if (obj.removeEventListener)
		obj.removeEventListener(evt,fn,false);
	else if (obj.detachEvent)
		obj.detachEvent('on'+evt,fn);
}

dragDrop = {
	initialMouseX: undefined,
	initialMouseY: undefined,
	startX: undefined,
	startY: undefined,
	dXKeys: undefined,
	dYKeys: undefined,
	draggedObject: undefined,
	dragHandle: undefined,
	
	initElement: function (element, dragElement) {
		if (typeof element == 'string')
			element = document.getElementById(element);
		// determine if we want to drag by the id dragElement which sohul dbe 
		// underneath the element object in dom heirachy
		if ( dragElement ) {
		  var children = element.childNodes;
		  for ( i=0; i<children.length; i++ ) {
		    if ( children[i].nodeType == 1 ) {
        	var attr = children[i].getAttribute( 'id' );
			if ( attr == dragElement ) {
				children[i].onmousedown = dragDrop.startDragMouse;
			  	dragDrop.dragHandle = dragElement;
			}
		  }
			}
		}
		if( dragDrop.dragHandle == undefined ) {
		  element.onmousedown = dragDrop.startDragMouse;
		  google.maps.Log.write( "Dragging by entire div" );
		}
	},
	startDragMouse: function (e) {
	  var dragObj = this;
	  if ( dragDrop.dragHandle != undefined ) 
	    dragObj = this.parentNode;
	  dragDrop.startDrag(dragObj);
		var evt = e || window.event;
		dragDrop.initialMouseX = evt.clientX;
		dragDrop.initialMouseY = evt.clientY;
		addEventSimple(document,'mousemove',dragDrop.dragMouse);
		addEventSimple(document,'mouseup',dragDrop.releaseElement);
		return false;
	},
	startDrag: function (obj) {
		if (dragDrop.draggedObject)
			dragDrop.releaseElement();
		dragDrop.startX = obj.offsetLeft;
		dragDrop.startY = obj.offsetTop;
		dragDrop.draggedObject = obj;
		obj.className += ' dragged';
	},
	dragMouse: function (e) {
		var evt = e || window.event;
		var dX = evt.clientX - dragDrop.initialMouseX;
		var dY = evt.clientY - dragDrop.initialMouseY;
		dragDrop.setPosition(dX,dY);
		return false;
	},
	setPosition: function (dx,dy) {
		dragDrop.draggedObject.style.left = dragDrop.startX + dx + 'px';
		dragDrop.draggedObject.style.top = dragDrop.startY + dy + 'px';
	},
	releaseElement: function() {
		removeEventSimple(document,'mousemove',dragDrop.dragMouse);
		removeEventSimple(document,'mouseup',dragDrop.releaseElement);
		dragDrop.draggedObject.className = dragDrop.draggedObject.className.replace(/dragged/,'');
		dragDrop.draggedObject = null;
	}
}
