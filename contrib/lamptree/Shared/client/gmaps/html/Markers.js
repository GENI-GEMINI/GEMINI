/* ****************************************************************
      MARKERS
   **************************************************************** */

Markers = {
  gMarkers: undefined,
  icons: undefined,
  pType: undefined,  // assoc. array (index id), indicating whether marker is a source or dest (or both)
  init: function () {
      
      //Markers
      Markers.gMarkers = new Array();
      Markers.pType = new Array();

  },
  getType: function( id ) {
      if ( typeof Markers.pType[id] == "undefined" ) {
          return undefined;
      }
      return Markers.pType[id];
  },
  register: function( id, type, serviceTotal ) {
      Markers.registerType( id, type );
      Markers.registerService( id, serviceTotal );
  },
  registerType: function( id, type ) { // src, dst, both
      if ( typeof Markers.pType[id] == "undefined" ) {
          if( debug )
            GLog.write( "setType: " + id + " to " + type );
          Markers.pType[id] = type;
      }
      // check not already set to something else
      if ( Markers.pType[id] == type ) {
          // fine
      } else {
          Markers.pType[id] = 'both';
      }
  },
  getId: function ( srcDomain, dstDomain, item ) {
      return srcDomain + '__' + dstDomain + '__' + item;
  },
  splitId: function ( id ) {
      var array = undefined;
      if ( array = /^(.*)__(.*)__(.*)$/.exec(id) ) {
          array.shift();
          return array;
      } else {
          if( debug )
            GLog.write( "EPIC FAIL! " + array);
      }
      return ( undefined, undefined, undefined );
  },
  isMarker: function( id ) {
      if ( Links.isLink( id ) ) {
          return 0;
      }
      return 1;
  },
  create: function( id, point, image ) {
      
      var icon = new GIcon(G_DEFAULT_ICON);
      if ( typeof image == "undefined" ) {
          icon.image = "images/blue.png";            
      } else {
          icon.image = image;
      }
      var markerOptions = { title:id, icon:icon };
      
      Markers.gMarkers[id] = new GMarker( point, markerOptions );
      
      GEvent.addListener( Markers.gMarkers[id], "click", function() {

          Markers.activeMarker = id;
          if ( map.getExtInfoWindow() ) {
              map.closeExtInfoWindow();
          }
          Markers.gMarkers[id].openExtInfoWindow(
              map,
              ExtInfoWindowView.div,
              '<p>loading</p>'
            );

        ExtInfoWindowView.focus( id );

        // show only links for this marker
        Links.hideAllLinks();
        Links.setDomainVisibilityFromMarker( id, true );
          
        tooltip.style.display = "none";
                    
      });

      // add tooltip
      GEvent.addListener( Markers.gMarkers[id], "mouseover", function() {
          Markers.showTooltip( id );
          Help.marker( id );
      })
      GEvent.addListener( Markers.gMarkers[id], "mouseout", function() {
          tooltip.style.display = "none";
      });

      
      return Markers.gMarkers[id];
  },
  add: function ( lat, lng, this_id ) {

//      if( debug )
//        GLog.write( "adding marker '" + this_id + "' at (" + lat + "," + lng + ")" );
    // return if the marker is invalid
    if ( lat == "undefined" || lng == "undefined" ) {
        if( debug )
            GLog.write( "Error parsing marker '" + this_id + "' at (" + lat + "," + lng + ")" );
      return undefined;
    }
    
    // check to make sure the marker doesn't already exist
    if ( typeof Markers.gMarkers[this_id] == "undefined" ) {

        Markers.create( this_id, new GLatLng( lat,lng ) );

    } 
    
/*    else {
     TODO: if the long lats are different, then move them
      if( debug )
        GLog.write( "FIXME: geo change on marker " + this_id );
    }
*/    
    return Markers.gMarkers[this_id];    
  },
  get: function( id ) {
      if ( typeof( Markers.gMarkers[id] ) == "undefined" ) {
          if( debug )
            GLog.write( "Could not find marker with id " + id );
          return undefined;
      }
      return Markers.gMarkers[id];
  },
  invert: function( e ) {
    for( var id in Markers.gMarkers ) {
      if( Markers.get(id).isHidden() ) {
        Markers.get(id).show();
        sidebar.toggleItem( id, true );
      } else {
        Markers.get(id).hide();
        sidebar.toggleItem( id, false );
      }
    }
    return false;
  },
  show: function( id ) { // overload to determine the type of the marker
      // copy info from marker
//      if( debug )
//        GLog.write( "showing marker " + id + ", type=" + Markers.getType( id ) );
      var this_marker = Markers.get(id);
      
      // colour the marker depending on the type
      var colour = "red";
      if ( Markers.getType( id ) == "src" ) {
          colour = "green";
      } else if ( Markers.getType( id ) == "dst" ) {
          colour = "grey";
      } else if ( Markers.getType( id ) == "both" ) {
          colour = "blue";
      }
      
      // place a numeral if there are services on the marker
      var marker_services = MetaData.getNodeServiceTypes( id ).length;
      if ( marker_services > 0 ) {
          colour = colour + marker_services;
      }
      icon = "images/" + colour + ".png";
      
//      if( debug )
//        GLog.write( "    colour=" + colour );
      this_marker.hide();
      Markers.gMarkers[id] = Markers.create( id, this_marker.getLatLng(), icon );

      map.addOverlay( Markers.gMarkers[id] );
      Markers.gMarkers[id].show();

  },
  hide: function( id ) {
      if ( Markers.get(id) != undefined ) {
          Markers.get(id).hide();
        }
  },
  setVisibility: function( id, state ) {
      if ( state ) {
          Markers.show(id);
      } else {
          Markers.hide(id);
      }
  },
  setDomainVisibility_: function( list, domain, state ) {
      for( var i = 0; i < list.length; i++ ) {
          var this_id = list[i];
          var this_domain = MetaData.getNodeDomain( this_id );
          if ( domain == this_domain ) {
              if ( state == true ) {
                  Markers.show( this_id );
              } else {
                  Markers.hide( this_id );
              }
          }
      }
  },
  setDomainVisibility: function( domain, state ) {  // sets all the nodes in the domain to visibility state
      if( debug )
        GLog.write( "Marker.setDomainVisibility of domain " + domain + " to " + state );

    // hide data ndoes
    var data_ids = MetaData.getNodeDataIds();
    Markers.setDomainVisibility_( data_ids, domain, state );
    
    //hide service nodes
    var service_ids = MetaData.getNodeServiceIds();
    Markers.setDomainVisibility_( service_ids, domain, state );
    
  },
  bounce: function( id ) {
      Markers.get(id).setPoint(center, {draggable: true});
  },
  selectAll: function( e ) {
    for( var urn in gMarkers ) {
      Markers.get(id).show();
      sidebar.toggleItem( id, true );
    }
  },
  selectNoneMarkers: function() {
    for( var urn in gMarkers ) {
      Markers.get(id).hide();
      sidebar.toggleItem( id, false );
    }
  },
  showTooltip: function(id) { // Display tooltips

   tooltip.innerHTML = id;
   tooltip.style.display = "block";

   // Tooltip transparency specially for IE
   if( typeof(tooltip.style.filter) == "string" ) {
       tooltip.style.filter = "alpha(opacity:70)";
   }

   var currtype = map.getCurrentMapType().getProjection();
   var point = currtype.fromLatLngToPixel( map.fromDivPixelToLatLng( new GPoint(0,0), true ), map.getZoom());
   var offset = currtype.fromLatLngToPixel( Markers.get(id).getLatLng(), map.getZoom() );
   var anchor = Markers.get(id).getIcon().iconAnchor;
   var width = Markers.get(id).getIcon().iconSize.width + 6;
  // var height = tooltip.clientHeight +18;
   var height = 10;
   var pos = new GControlPosition(G_ANCHOR_TOP_LEFT, new GSize(offset.x - point.x - anchor.x + width, offset.y - point.y -anchor.y - height)); 
   pos.apply(tooltip);
  },
  focus: function( id ) {
      if( debug )
        GLog.write( "Focus on marker '" + id + "'");
      GEvent.trigger( Markers.get(id), 'click' );
  }
}

