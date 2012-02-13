/* ****************************************************************
      INFOWINDOW
   **************************************************************** */

InfoWindow = {
    activeId: undefined,
    init: function () {
        Markers.gMarkers = new Array();
    },
    // add a infowindowtab to the marker id of servcice type
    add: function ( id, serviceType ) {
        if( debug )
            GLog.write( "adding InfoWindow '" + id + "'" );
    },
    
    get: function( id ) {
        if( debug )
            GLog.write( "Creating tabs for '" + id + "'" );
      // determine what tabs to create for this urn
      var tabs = new Array();
      // always have an info tab
      
      var type = undefined;
      var info = undefined;
      if ( Markers.isMarker( id ) ) {
          type = 'Host';
          var point = Markers.get(id).getLatLng()
          info = '(' + point.lat() + ', ' + point.lng() + ')'
      } else {
          var nodes = Links.splitId( id );
          type = 'Link';
          var srcPoint = Markers.get(nodes[0]).getLatLng();
          var dstPoint = Markers.get(nodes[1]).getLatLng();
          info = "From '<a href=\"#\" onclick=\"Markers.focus( '" + nodes[0] + "' );\">" + nodes[0] + "</a>' (" + srcPoint.lat() + ', ' + dstPoint.lng() + ") to '<a href=\"#\" onclick=\"Markers.focus( '" + nodes[1] + "' );\">" + nodes[1] + "</a>' (" + dstPoint.lat() + ', ' + dstPoint.lng() + ")";
      }
      var html = '<table class="infoWindow"><tr><td>' + type + '</td><td>' + id + '</td></tr><tr><td>Coordinates</td><td>' + info + '</td></tr></table>';
      tabs.push( new GInfoWindowTab( "Info", html ) );
      // how add all the other tabs - iterate through the xml and add on all the with same src/dst/description

      for ( xmlUrl in nodesDOM )
      {
          if( debug )
            GLog.write( "  searching through '" + xmlUrl + "'");
          
          if( Markers.isMarker( id ) ) {
              
              var nodes = nodesDOM[xmlUrl].documentElement.getElementsByTagName("node");
              for( var i = 0; i < nodes.length; i++ )
              {	        
                  if ( nodes[i].getAttribute("id") == id ) {

                      if( debug )
                        GLog.write( "    found marker id '" + id + "' in uri '" + xmlUrl + "'" );

                      // now go through the ma definitions and build an info tab for it
                      var els = nodes[i].getElementsByTagName("service");
                      // updaate marker service
                      for( var j = 0; j < els.length; j++ ) {
                      
                          var serviceType = els[j].getAttribute("serviceType");
                          var eventType = els[j].getAttribute("eventType");
                          var accessPoint = els[j].getAttribute("accessPoint");
                      
                          if( debug )
                            GLog.write( "  found service=" + serviceType + ", eventType=" + eventType + ", accessPoint='" + accessPoint );
                          // fetch the page template from the service	
                          var src = '&eventType=' + eventType;
                          src = src + '&accessPoint=' + accessPoint;

                          var html = '<table class="infoWindow"><tr><td>Access Point</td><td>' + accessPoint + '</td></tr><tr><td>EventType</td><td>' + eventType + '</td></tr></table><p><center>__CONTENT__</center></p><div id="infoMetaData"></div>';

                          src = '?mode=discover' + src;
                          html = html.replace( /__CONTENT__/g, "<p><input type=\"submit\" value=\"Query Service\" onclick=\"IO.discover('" + src + "'); MetaDataView.register( '" + id + "', " + serviceType + ", " + src + "' )\"/></p>" );
                          if( debug )
                            GLog.write( '  building marker tab: ' + html ); 
                          tabs.push( new GInfoWindowTab( serviceType, html ) );
                      }
                  }
              }
          } else {
              
              var node = Links.splitId( id );
              var src_id = node[0];
              var dst_id = node[1];

              var links = nodesDOM[xmlUrl].documentElement.getElementsByTagName("link");
              for( var i = 0; i < links.length; i++ ) {
                  
                  var this_src = links[i].getAttribute("src");
                  var this_dst = links[i].getAttribute("dst");
                  
                  if ( this_src  == src_id 
                        && this_dst  == dst_id ) {
                   
                    var els = links[i].getElementsByTagName("urn");
                    for( var j = 0; j < els.length; j++ ) {
                        
                        var serviceType = els[j].getAttribute("serviceType");
                        var eventType = els[j].getAttribute("eventType");
                        var accessPoint = els[j].getAttribute("accessPoint");
                        var urn = els[j].firstChild.nodeValue;
                        
                        if( debug )
                            GLog.write( "    found link urn=" + urn + ", service=" + serviceType + ", eventType=" + eventType + ", accessPoint='" + accessPoint );
 
                        var src = '&eventType=' + eventType;
                        src = src + '&accessPoint=' + accessPoint;
                        
                        // use the key if we have one
                        var a = urn.match( /key=((\w|\,)+):?/ );
                        if ( a.length > 0 ){
                            src = src + '&key=' + a[1];
                        } else {
                            src = src + '&urn=' + urn;
                        }
                        
                        var html = '<table class="infoWindow"><tr><td>Access Point</td><td>' + accessPoint + '</td></tr><tr><td>EventType</td><td>' + eventType + '</td></tr><tr><td>URN</td><td>' + urn + '</td></tr></table><p><center>__CONTENT__</center></p>'
                        
                        src = '?mode=graph' + src;
                        html = html.replace( /__CONTENT__/g, "<p><img width=\"497\" height=\"168px\" src=\"" + src + "\"/></p>" );

                        if( debug )
                            GLog.write( '  building link tab: ' + html ); 
                        tabs.push( new GInfoWindowTab( serviceType, html ) );
                    }
                            
                  }
              }
              
          }
      }
      return tabs;
    },
    show: function() {
      if( ! map.getInfoWindow().isHidden() )
        InfoWindow.showTab( InfoWindow.activeId );
        
    },
    showTab: function( id ) {
        if( debug )
            GLog.write( 'showTab: ' + id );
        if ( id == undefined ) {
            id = InfoWindow.activeId;
        } else {
            InfoWindow.activeId = id;
        }
        if ( Markers.isMarker( id ) ) {
            var tabs = InfoWindow.get( id );
            var number = map.getInfoWindow().getSelectedTab();
            Markers.get(id).openInfoWindowTabsHtml( tabs, {selectedTab:number} );
            
            // force update of the metadata view if available
            //MetaDataView.show( id, serviceType );
            
        } else {
            // not need to force the tab open as gevent should have already hooked in for click
            // Links.openInfoWindowTabHtml( id );
            // refresh tab window
            //map.updateCurrentTab();
        }
        if ( Markers.isMarker( id ) ) {
            Help.markerInfo( id );
        } else {
            Help.linkInfo( id );
        }
    },
    focus: function( id ) {
        if( debug )
            GLog.write( 'focus: ' + id );
        Markers.activeMarker = id;
        InfoWindow.showTab( id );
        map.getInfoWindow().hide();
        map.updateInfoWindow();
        map.getInfoWindow().show();
    }

}

