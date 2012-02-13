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


// constructor for list of checktrees
tree = {
  root: undefined,
  countAllLevels: undefined,
  checkFormat: '(%n% checked)',
  
  initChildren: function( ul ) {
  	
  	// check to make sure ul is of id tree
  	if( ul.id != 'tree' ) {
  		alert( "Not a valid ul tree" );
  		return;
  	}
  	
	alert( "looking at " + ul );
    ul.style.display='none';
    //ul.treeObj=this;
    ul.setBoxStates = tree.setBoxStates;
    var fn = new Function('e','tree.setBoxStates(e)');
    addEventSimple( ul, 'click', fn );
  	
  	
  	// find lis
	var li = ul.childNodes;
   	for( var i = 0; i < li.length; i++ ) {
		
		if ( li.tagName == 'LI' ) {
						
			var children = li[i].childNodes;
			for ( var j = 0; j < children.length; j++ ) {
				// deal with input and span
		        if( children[j].tagName == 'INPUT' 
		                && children[j].type == 'CHECKBOX' ) {
	        
		            var e = e || window.event;
		            var elm = e.srcElement||e.target;
		
		            // only check children if parent is clicked to be
		            // checked. otherwise do not change the children
		            // make this only valid when none of the children are checked
		            if( parBox && (parBox.checked == true)
		            	&& elm && elm.id && elm.id.match(/^check-/) 
		                && ( getNumberChecked( this ) == 0 ) )
		                    tree.checkAllChildren( this, true );
		
		            // if all of the child nodes are not checked, then
		            // uncheck the parent box
		            if ( getTotalChildren( this ) - getNumberChecked( this )
		                            == getTotalChildren( this ) )
		                if ( parBox && parBox.checked == true )
		                        parBox.checked = false;
		
	//                              if( this.treeObj.countAllLevels)
	//                                      setTreeCount( document.getElementById('count-'+thisLevel), getNumberChecked( this ) );  
	        
	        } // if childname			    
			
				// next ul - iterate
				if ( children[j].tagName == 'UL' ) {
					tree.initChildren( children[j] );					
				}
				
			}	
		}
   	
   	} 
  	
  },
  
  initElement: function( element ) {
  	
  	// find the li with id=element
  	var lis = document.getElementsByTagName( 'li' );
  	for ( var i = 0; i< lis.length; i++ ) {
		if( lis[i].id == element ) {
			alert( 'Found list ' + element );
			
			var children = lis[i].childNodes;
			
			for ( var j = 0; j < children.length; j++ ) {
				if ( children[j].tagName == 'UL' 
						&& children[j].id == 'tree' ) {					
					alert( "Found at tree @ " + children[j] );
					
					tree.initChildren( children[j] );

				}				
			}
		}
  	}
  },
  setBoxStates: function( e ) {
	
	if(!this.childNodes)
		return;
	                
	var thisLevel = e.id.match(/^tree-(.*)/)[1];
	var parBox = document.getElementById('check-'+thisLevel);
	
	// loop through all of the children
	for( var li=0; li < this.childNodes.length; li++ )
	{
	    for( var tag=0; tag<this.childNodes[li].childNodes.length; tag++)
	    {
	        var child = this.childNodes[li].childNodes[tag];        
	        
	        // don't bother if we dont' have any children here
	        if( !child )
	                continue;
	        
	        // make sure we have the correct input types
	        if( child.tagName && child.tagName.match(/^input/i)
	                && child.type && child.type.match(/^checkbox/i))
	        {
	        
	            e = e||window.event;
	            var elm = e.srcElement||e.target;
	
	            // only check children if parent is clicked to be
	            // checked. otherwise do not change the children
	            // make this only valid when none of the children are checked
	            if( parBox && (parBox.checked == true)
	                            && elm && elm.id && elm.id.match(/^check-/) 
	                            && ( getNumberChecked( this ) == 0 )
	                    )
	                    checkAllChildren( this, true );
	
	            // if all of the child nodes are not checked, then
	            // uncheck the parent box
	            if ( getTotalChildren( this ) - getNumberChecked( this )
	                            == getTotalChildren( this ) )
	                if ( parBox && parBox.checked == true )
	                        parBox.checked = false;
	
	//                              if( this.treeObj.countAllLevels)
	//                                      setTreeCount( document.getElementById('count-'+thisLevel), getNumberChecked( this ) );  
	        
	        } // if childname
	        
	        // iterate through children of this child
	        if( child.tagName && child.tagName.match(/^ul/i)  )
	                child.setBoxStates( e );
	                
	    } // tag
	
	} // li
	    return;
	 }
}
