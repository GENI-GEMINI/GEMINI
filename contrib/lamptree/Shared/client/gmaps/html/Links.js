/* ****************************************************************
      LINKS
   **************************************************************** */

Links = {
  gLinks: undefined,
  init: function () {
      
      //Markers
      Links.gLinks = new Array();
      
  },
  getId: function ( src, dst ) {
      return src + ' to ' + dst;
  },
  splitId: function ( id ) {
      var array = new Array();
      if ( array = /^(.*) to (.*)$/.exec(id) ) {
          array.shift();
          return array;
      }
      return new Array();
  },
  isLink: function( id ) {
      var array = Links.splitId( id );
      if( array.length == 2 ) {
          return 1;
      }
      return 0;
  },
  add: function ( src_id, dst_id ) {

    var this_id = Links.getId( src_id, dst_id );
    if( debug )
        GLog.write( "adding link id: '" + this_id + "', from '" + src_id + "' to '" + dst_id  + "'" );

    // check to make sure the marker doesn't already exist
    if ( typeof Links.gLinks[this_id] == "undefined" ) {

        // update type and service of marker
        var src = Markers.get( src_id );
        var dst = Markers.get( dst_id );

        var polyOptions = {geodesic:true};
        var polyline = new GPolyline([
          src.getLatLng(),
          dst.getLatLng()
        ], "#ff0000", 3, 1, polyOptions);

        Links.gLinks[this_id] = polyline;

        // make single clicks the info box
        GEvent.addListener( Links.gLinks[this_id], "click", function() {
            Links.initInfoWindow( this_id );
            ExtInfoWindowView.focus( this_id );
        });
        GEvent.addListener( Links.gLinks[this_id], "mouseover", function() {
            Help.link( this_id );
        });

        // intiaially hide the links until the source is clicked on
        Links.hide( this_id );
    }

    return Links.gLinks[this_id];
  },
  get: function( id ) {
    return Links.gLinks[id];  
  },
  initInfoWindow: function( id ) {

    GEvent.clearListeners( Links.gLinks[id], 'click' );
    GEvent.addListener( Links.gLinks[id], 'click', function(point) { 
    if( debug )
        GLog.write( "Showing infoWindow for link '" + id + "'");
      // create a new invisible marker for popup
      // FIxME: add blank icon for show, hide prevents infowindow from showing
      var icon = new GIcon(G_DEFAULT_ICON);
      icon.image = 'image/blank.png';
      var opts = { icon:icon };
      var thisMarker = new GMarker( new GLatLng( point.lat(), point.lng() ), opts );
      
      if ( map.getExtInfoWindow() ) {
          map.closeExtInfoWindow();
      }
        thisMarker.openExtInfoWindow(
            map,
            ExtInfoWindowView.div,
            '<p>loading</p>',
            {beakOffset: 0}
          );
          map.addOverlay( thisMarker );
          //thisMarker.hide();
          ExtInfoWindowView.focus( id );
          map.removeOverlay( thisMarker );
    } );
    
  },
  show: function( id ) {
      Links.initInfoWindow( id );
      map.addOverlay(Links.gLinks[id]);
      Links.get(id).show();
  },
  hide: function( id ) {
      Links.get(id).hide();
  },
  setVisibility: function( id, state ) {
      if( debug )
        GLog.write( "setVisibilty of " + id + " to " + state );
      if ( state == false ) {
          Links.show( id );
      } else {
          Links.hide( id );
      }
  },
  setDomainVisibility: function( domain, state ) {
    if( debug )
    GLog.write("Links.setDomainVisibilty of " + domain + " to " + state );

    var link_ids = MetaData.getLinkDataIds();
    for( var i = 0; i < link_ids.length; i++ ) {
    
        var this_id = link_ids[i];
        var nodes = Links.splitId( this_id );
    
        var this_srcDomain = MetaData.getNodeDomain( nodes[0] );
    
        // if this src_id matches, then show the link
        if ( this_srcDomain == domain ) {
        
            if ( state == true ) {
                Links.show( this_id );
            } else {
                Links.hide( this_id );
            }
        } // if domain
    } // for
  },
  setDomainVisibilityFromMarker: function( src_id, state ) {
    if( debug )
        GLog.write("Links.setDomainVisibiltyFromMarker of " + src_id + " to " + state );

    var link_ids = MetaData.getLinkDataIds();
    for( var i = 0; i < link_ids.length; i++ ) {

        var this_id = link_ids[i];
        var link = Links.splitId( this_id );
        var this_src = link[0];
        var this_dst = link[1];
            
        // if this src_id matches, then show the link
        if ( this_src == src_id ) {
            var checkBoxId = this_id + ":Link";
            if ( state == true ) {
                Sidebar.setCheckBox( checkBoxId, true );
                Links.show( this_id );
            } else {
                Sidebar.setCheckBox( checkBoxId, false );
                Links.hide( this_id );
            }
        }
    } // for all links

  },
  hideAllLinks: function( ) {
    if( debug )
        GLog.write( "hideAllLinks");

    var link_ids = MetaData.getLinkDataIds();
    for( var i=0; i<link_ids.length; i++ ) {
        var this_id = link_ids[i];
        Links.hide( this_id );
    }
    
  },
  focus: function( id ) {
      if( debug )
        GLog.write( "Focus on link '" + id + "'");
      Links.show( id );
      Sidebar.setCheckBox( 'check-' + id + ":Link" );
      // TODO: popup infowindow
      GEvent( Links.gLink[id], "click", new GLatLng( 40,-100 ) );
  }
}

