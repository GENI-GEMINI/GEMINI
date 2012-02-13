/* ****************************************************************
      EXTINFOWINDOW
   **************************************************************** */

ExtInfoWindowView = {
    div: undefined,
    activeId: undefined,
    activeType: undefined,
    activeTab: undefined,
    windowTabsTitle: undefined,
    windowTitle: undefined,
    windowContent: undefined,
    init: function ( divEl ) {
        ExtInfoWindowView.div = divEl;
    },
    // add a infowindowtab to the marker id of servcice type
    add: function ( id, serviceType ) {
        if( debug )
            GLog.write( "adding InfoWindow '" + id + "'" );
    },
    clearTabs: function( ) {
        ExtInfoWindowView.windowTabsTitle = new Array();
        ExtInfoWindowView.windowContent = new Array();
        ExtInfoWindowView.windowTitle = new Array();
    },
    addTab: function( tabTitle, windowTitle, content ) {
        
        //GLog.write( "addTab " + tabTitle );
        ExtInfoWindowView.windowTabsTitle[ExtInfoWindowView.windowTabsTitle.length] =  tabTitle;
        ExtInfoWindowView.windowTitle[ExtInfoWindowView.windowTitle.length] =  windowTitle;
        ExtInfoWindowView.windowContent[ExtInfoWindowView.windowContent.length] = content;
        
    },
    showEl: function(element){
      element.style.display = "block";
      element.style.position = "relative";
    },
    hideEl: function(element){
      element.style.display = "none";
      element.style.position = "absolute";
    },
    register: function(id) { // set up datastructures for presnting the infowindow for this
        
    },
    set: function( ) {
        
        var tabs = "";    
        tabs += '<div id="" class="tabs">';
        
        // header
        tabs += '<div class="tabs_header">';
        for( var i=0; i<ExtInfoWindowView.windowTabsTitle.length; i++ ) {
            var className = 'tab';
            if( i == 0 ) {
                className = 'tabSelected';
            }
            tabs += '<div id="tab' + i + '" class="' + className + '"><p class="contents">' + ExtInfoWindowView.windowTabsTitle[i] + '</p></div>';            
        }
        tabs += '</div>';
        
        // main contents
        tabs += '<div class="tab_contents">';
        for( var i=0; i<ExtInfoWindowView.windowContent.length; i++ ) {
            var className = 'tab_content';
            if ( i ==0 ) {
                className = 'tab_content_first';
            }
            tabs += '<div id="tab' + i + '_content" class="' + className + '">';
            tabs += '<div class="title">' + ExtInfoWindowView.windowTitle[i] + '</div>';
            tabs += ExtInfoWindowView.windowContent[i];
            tabs += '</div>';
        }
        tabs += '</div></div>';
        
//        if ( map.getExtInfoWindow() ) {
            var infoWindow = document.getElementById( map.getExtInfoWindow().infoWindowId_ + '_contents');
            infoWindow.innerHTML = tabs;
//        }
    },

    get: function( id ) {
        if( debug )
            GLog.write( "Creating tabs for '" + id + "'" );
        // determine what tabs to create for this urn
        ExtInfoWindowView.clearTabs();

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
        //GLog.write( "  building tab 'Info': " + html );
        ExtInfoWindowView.addTab( "Info", type + ' ' + id, html );

        if( Markers.isMarker( id ) ) {

            // now go through the service definitions and build an info tab for it
            var types = MetaData.getNodeServiceTypes( id );
            // updaate marker service
             for( var i=0; i < types.length; i++ ) {
     
                 var item = MetaData.splitServiceTypeEventType( types[i] );
                 var serviceType = item[0];
                 var eventType = item[1];

                 var access_point = MetaData.getNodeServiceAccessPoint( id, types[i] );

                 if( debug )
                    GLog.write( "  found service=" + serviceType + ", eventType=" + eventType + ", accessPoint='" + access_point );

                // fetch the page template from the service	
                var html = '<table class="infoWindow"><tr><td>Access Point</td><td id="accessPoint">' + access_point + '</td></tr><tr><td>EventType</td><td id="eventType">' + eventType + '</td></tr></table><p><center>__CONTENT__</center></p>';
                
                var onClick = "IO.discover('" + access_point + "', '" + eventType + "', '" + id + "', '" + serviceType + "');";
                onClick = onClick.replace( '"', '\"' );
                
                html = html.replace( /__CONTENT__/g, '<p><button type="button" onclick="' + onClick + '">Query Service</button></p>' );
                var tabName = serviceType + " Service";
                html += MetaDataView.getServices( tabName, id, eventType, access_point );
                
                ExtInfoWindowView.addTab( tabName, type + ' ' + id, html );

            } // for each service


            // data on id
            var types = MetaData.getNodeDataTypes( id );
            for( var i=0; i<types.length; i++ ) {

                var item = types[i];
                var type_array = MetaData.splitServiceTypeEventType( item );
                var serviceType = type_array[0];
                var eventType = type_array[1];
                var access_points = MetaData.getNodeDataAccessPoints( id, item );

                // TODO: more than one access point
                var access_point = access_points[0];

                if( debug )
                  GLog.write( "  found service=" + serviceType + ", eventType=" + eventType + ", accessPoint='" + access_point );

                var html = '<table class="infoWindow"><tr><td>Access Point</td><td id="accessPoint">' + access_point + '</td></tr><tr><td>EventType</td><td id="eventType">' + eventType + '</td></tr></table>';
                html += MetaDataView.getData( serviceType, id, item, access_point );


                ExtInfoWindowView.addTab( serviceType, type + ' ' + id, html );
            } // for each node data

              
              
          } else {
              
                // if a link
              
              var node = Links.splitId( id );
              var src_id = node[0];
              var dst_id = node[1];

              var types = MetaData.getLinkDataTypes( id );
              for( var i=0; i<types.length; i++ ) {

                var item = types[i];
                var type_array = MetaData.splitServiceTypeEventType( item );
                var serviceType = type_array[0];
                var eventType = type_array[1];
                
                var access_points = MetaData.getLinkDataAccessPoints( id, item );

                // TODO: more than one access point
                var access_point = access_points[0];
                var urns = MetaData.getLinkDataUrnIds( id, item, access_point );
                
                // TODO: more than one urn
                var urn = MetaData.getLinkDataUrn( id, item, access_point, urns[0] );

                if( debug )
                    GLog.write( "    found link urn=" + urn + ", service=" + serviceType + ", eventType=" + eventType + ", accessPoint='" + access_point );
 
                var html = '<table class="infoWindow"><tr><td>Access Point</td><td>' + access_point + '</td></tr><tr><td>EventType</td><td>' + eventType + '</td></tr><tr><td>URN</td><td>' + urn + '</td></tr></table><div id="#graph">__CONTENT__</div>';
                html = html.replace( /__CONTENT__/g, ExtInfoWindowView.getGraphDom( access_point, eventType, urn ) );

                if( debug )
                    GLog.write( '    link data: ' + html ); 

                ExtInfoWindowView.addTab( serviceType, type + ' ' + id, html );

            } // for types
              
        } // if marker

        return 1;
    },
    refresh: function( ) {
        
        // always info tab
        GEvent.clearListeners( map, 'extinfowindowupdate' );
        GEvent.addDomListener( map, 'extinfowindowupdate', function(){
            
            var tabs = new Array();
            
            var infoWindow = document.getElementById(ExtInfoWindowView.div);
            for( var j=0; j<ExtInfoWindowView.windowTabsTitle.length; j++ ) {
                tabs[j] = document.getElementById( 'tab' + j );
            }

            //GLog.write( "Refreshing tabs " + tabs.length );

            var tabContentsArray = new Array(tabs.length);
            for( var i=0; i<tabs.length; i++ ){
                
                var tabContentId = "tab"+i+"_content";
                //GLog.write( "  refreshing tab content id " + tabContentId);
                
                tabContentsArray[i] = document.getElementById(tabContentId);
                var tab_name = tabs[i].firstChild.firstChild.nodeValue ;
                tabs[i].setAttribute("name", tab_name );

                GEvent.clearInstanceListeners( tabs[i] );
                GEvent.addDomListener( tabs[i], "mouseover", function(){
                    Help.infoWindowService( tab_name );
                } );
                GEvent.addDomListener( tabs[i], "click", function(){
  
                    //var tabIndex = this.getAttribute("name");
                    var tabName = this.getAttribute('name');
                    Help.infoWindowService( tabName );

                    for( var tabContentIndex=0; tabContentIndex < tabs.length; tabContentIndex++){

                        this_tabName = tabs[tabContentIndex].firstChild.firstChild.nodeValue;
                        //GLog.write( "  looking at tabContentIndex " + tabContentIndex + ", name " + this_tabName + " for index " + tabName );
    
                      if( this_tabName == tabName ){
    
                        //GLog.write( "ExtInfoWindow.refresh() clicked on tab '" + tabName + "'");  
                        ExtInfoWindowView.showEl(tabContentsArray[tabContentIndex]);
    
                        ExtInfoWindowView.activeTab = tabName;
                        //GLog.write( "  active tab " + ExtInfoWindowView.activeTab );
    
                        // highlight current tab
                        tabs[tabContentIndex].className = 'tabSelected';
                            
                      } else{
      
                          tabs[tabContentIndex].className = 'tab';
                          //GLog.write( "  hiding tab '" + tabContentIndex + "'");
                          ExtInfoWindowView.hideEl(tabContentsArray[tabContentIndex]);
      
                      }
  
                    } //for
                                
                    map.getExtInfoWindow().resize();
                }); // dom listner
            } // for each tab
            
            var n = ExtInfoWindowView.getTabNumber( ExtInfoWindowView.activeTab );
            GEvent.trigger( tabs[n], 'click' );
            
        });

        GEvent.trigger( map, 'extinfowindowupdate');

    },
    getTabNumber: function( name ) {
        var t = new Array();
        for( var j=0; j<ExtInfoWindowView.windowTabsTitle.length; j++ ) {
            t[j] = document.getElementById( 'tab' + j );
            var this_tabname = t[j].firstChild.firstChild.nodeValue;
            if ( this_tabname == name ) {
                return j;
            }
        }
        return 0;
    },
    getGraphDom: function( access_point, eventType, urn ) {
        var src = IO.getGraphUrl( access_point, eventType, urn );
        return '<center><img id="#loading" src="images/spinner.gif"></img><img id="#graph" onload="document.getElementById(\'#loading\').style.display = \'none\'; map.getExtInfoWindow().resize()" src="' + src + '"/></center>';
    },
    focus: function( id, name ) {
        
        if ( typeof id == "undefined" ) {
            id = Markers.activeMarker;
        }
        if ( typeof name != "undefined" ) {
             ExtInfoWindowView.activeTab = name;
         }
         
        if( debug )
            GLog.write( 'focus infoWindow: ' + id  + ", " + ExtInfoWindowView.activeTab );

        if ( typeof id == "undefined") {
            return;
        }
        
        Markers.activeMarker = id;
        
        if ( ! map.getExtInfoWindow() ) {
            if ( Markers.isMarker( id ) ) {
                GEvent.trigger( Markers.get(id), 'click' );
                return;
            } else {
                GEvent.trigger( Links.get(id), 'click' );
                return;
            }
        }
        
        
        // populate datastructures for this id
        ExtInfoWindowView.get( id );
        ExtInfoWindowView.set( );

        //GEvent.trigger( Markers.get( id ), 'click' );

        ExtInfoWindowView.refresh( )

        if ( Markers.isMarker( id ) ) {
            Help.markerInfo( id );
        } else {
            Help.linkInfo( id );
        }
        
    }
};


MetaDataView = {
    
    setGraph: function( tab_name, access_point, eventType, urn ) {
        var src = ExtInfoWindowView.getGraphDom( access_point, eventType, urn );
        var graph = document.getElementById( '#' + tab_name + '_metadata_right' );
        graph.innerHTML = src;
    },
    getNodeDataList: function( tab_name, node_id, type, access_point ) {
        var list = '<select size="10">';
        var urn_ids = MetaData.getNodeDataUrnIds( node_id, type, access_point );
        for( var i=0; i<urn_ids.length; i++ ) {
            var urn = MetaData.getNodeDataUrn( node_id, type, access_point, urn_ids[i] );
            var eventType = MetaData.splitServiceTypeEventType( type )[1];
            list += '<option onclick="MetaDataView.setGraph( \'' + tab_name + '\', \'' + access_point + "', '" + eventType + "', '" + urn + '\' );">' + urn_ids[i]  + "</option>";
        }
        list += '</select>';
        return list;
    },
    getNodeServiceList: function( tab_name, node_id, eventType, access_point ) {
        var list = '<select size="10">';
        var root = MetaData.getNodeServiceMetaDataRoot( node_id, eventType, access_point );
        for( var i=0; i<root.length; i++ ) {
            var onClick = "MetaDataView.setNodeServiceListFirstBranch( '" + tab_name + "', '" + node_id + "', '" + eventType + "', '" + access_point + "', '" + root[i] + "' )";
            var onDblClick = "";
            if ( typeof Markers.get(root[i]) != "undefined" ) {
                onDblClick = "Markers.focus( '" + root[i] + "' );";
            }
            list += '<option onclick="' + onClick + '" ondblclick="' + onDblClick + '">' + root[i]  + "</option>";
        }
        list += '</select>';
        return list;
    },
    getNodeServiceListFirstBranch: function( tab_name, node_id, eventType, access_point, root_id ) {
        var list = '<select size="10">';
        var first_branch = MetaData.getNodeServiceMetaDataFirstBranch( node_id, eventType, access_point, root_id );
        for( var i=0; i<first_branch.length; i++ ) {
            var onDblClick = "ExtInfoWindowView.focus('" + first_branch[i] + "', '" + root_id + "' );";
            list += '<option ondblclick="' + onDblClick + '">' + first_branch[i] + "</option>";
        }
        list += '</select>';
        return list;
    },
    setNodeServiceListFirstBranch: function( tab_name, node_id, eventType, access_point, root_id ) {
        var list = MetaDataView.getNodeServiceListFirstBranch( tab_name, node_id, eventType, access_point, root_id );
        // make sure we get teh right tab contents
        var id = '#' + tab_name + '_metadata_middle';
        var meta_contents = document.getElementById( id );
        meta_contents.innerHTML = list;
    },
    getData: function( tab_name, id, type, access_point ) {
        var leftList = MetaDataView.getNodeDataList( tab_name, id, type, access_point )
        //GLog.write( "data metadata: " + leftList);
        return MetaDataView.getTable( tab_name, leftList );
    },
    getServices: function( tab_name, id, eventType, access_point ) {
        var leftList = MetaDataView.getNodeServiceList( tab_name, id, eventType, access_point );
        //GLog.write( "service metadata for " + tab_name + ": " + leftList);
        return MetaDataView.getTable( tab_name, leftList );
    },
    getTable: function( tabName, content ) {

        var metadata = '<div id="#' + tabName + '_metadata">'   
            + '<table>'
            + '<tr>'
            +   '<td><div id="#' + tabName + '_metadata_left">' + content + '</div></td>'
            +   '<td><div id="#' + tabName + '_metadata_middle"></div></td>'
            +   '<td><div id="#' + tabName + '_metadata_right"></div></td>'
            + '</tr>'
            + '</table>'
            + '</div>';
        return metadata;
    }
}

