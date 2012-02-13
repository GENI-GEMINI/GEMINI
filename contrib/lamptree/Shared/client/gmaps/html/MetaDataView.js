/* ****************************************************************
  MetaDataView 
 **************************************************************** */

MetaDataView = {
    currentView: undefined,
    uriMapping: undefined,
    accessPoint: undefined,
    eventType: undefined,
    type: undefined,
    id: undefined,
    register: function( id, serviceType, uri ) {  // provide facility to lookup correct uri
        //GLog.write( "metadata.register() id=" + id + ", serviceType=" + serviceType + ", uri=" + uri);
        if ( typeof MetaDataView.uriMapping == "undefined" ) {
            MetaDataView.uriMapping = new Array();
        }
        if ( typeof MetaDataView.uriMapping[id] == "undefined" ) {
            MetaDataView.uriMapping[id] = new Array();
        }
        if ( typeof MetaDataView.uriMapping[id][serviceType] == "undefined" ) {
            MetaDataView.uriMapping[id][serviceType] = new Array();
        }
        // FIXME: array needed here?
        MetaDataView.uriMapping[id][serviceType][uri] = 1;
    },
    get: function( id, serviceType ) {   // get metadata for the id
        
        GLog.write( "MetaDataView.get id=" + id + ", serviceType=" + serviceType );
        
        // build datastructure of meta data collected from this source
        var uris = new Array()
        if ( typeof MetaDataView.uriMapping != "undefined"
            && typeof MetaDataView.uriMapping[id] != "undefined"
            && typeof MetaDataView.uriMapping[id][serviceType] != "undefined" ) {
                
            for ( var uri in MetaDataView.uriMapping[id][serviceType] ) {
                uris[uris.length] = uri;
            }
            GLog.write( '  determined metadataview as (count=' + uris.length + '):' + uris );
        }
        
        MetaDataView.currentView = new Array();
        for( var i=0; i<uris.length; i++ ) {
                    
            // find all services listed in uri
            var services = nodesDOM[uris[i]].documentElement.getElementsByTagName("service");
            GLog.write( "  found " + services.length + " services");
            for( var j=0; j<services.length; j++ )
            {
                var this_serviceType = services[j].getAttribute("serviceType"); 
                    
                var serviceId = services[j].getAttribute('id');
                var markerId = serviceId.split(':');

                if ( typeof MetaDataView.currentView[this_serviceType] ==  "undefined" ) {
                  MetaDataView.currentView[this_serviceType] = new Array();
                }

                MetaDataView.currentView[this_serviceType][markerId[0]] = "javascript: GEvent.trigger( Markers.get('" + markerId[0] + "'), 'click' );";
                GLog.write( "    added item for serviceType=" + this_serviceType + ", text=" + markerId[0] );

            }
            
            // find all paths's for node
            var links = nodesDOM[uris[i]].documentElement.getElementsByTagName("link")
            GLog.write( "  found " + links.length + " links");
            for( var j=0; j<links.length; j++ ) {
                
                var urns = links[j].getElementsByTagName('urn');
                for( var k=0; k<urns.length; k++) {
                    
                    var urnId = urns[k].getAttribute('id');
                    var linkId = urnId.split(':');
                    var urn = urns[k].firstChild.nodeValue;
                
                    if ( typeof MetaDataView.currentView[this_serviceType] ==  "undefined" ) {
                      MetaDataView.currentView[linkId[0]] = new Array();
                    }

                    MetaDataView.currentView[linkId[0]][urn] = "javascript: Sidebar.setLink('" + linkId[0] + ":Link', true );";
                    //GLog.write( "    added item for link=" + linkId[0] + ", text=" + urn );


                }
            } // link
            
            
            // fina all node urn's
            var nodes = nodesDOM[uris[i]].documentElement.getElementsByTagName("node")
            GLog.write( "  found " + nodes.length + " nodes");
            for( var j=0; j<nodes.length; j++ ) {
                
                var this_id = nodes[j].getAttribute('id');
                
                if ( this_id == id ) {
                 
                    var urns = nodes[j].getElementsByTagName('urn');
                
                    for( var k=0; k<urns.length; k++) {
                    
                        var urnId = urns[k].getAttribute('id');
                        var urn = urns[k].firstChild.nodeValue;
                    
                        if ( typeof MetaDataView.currentView[this_serviceType] ==  "undefined" ) {
                          MetaDataView.currentView[urnId] = new Array();
                        }
                    
                        MetaDataView.currentView[urnId][urn] = "#";
                    
                    } // urns
                }
            } // nodes
                
                
            
        } // if uri
    },
    set: function( element, html ) {
        var el = document.getElementById( element );
        el.innerHTML = html;
    },
    createList: function( dictionary ) { // dictionary[column][item_name] = what to do when clicked
         var nodeList = '<select name="service_list" size="10">';
        for( var i in dictionary ) {
            nodeList += '<option onclick="MetaDataView.populateInnerView( \'' + i + '\' );">' + i;
        }
        nodeList += '</select>';
        return nodeList;
    },
    populateInnerView: function( id ) {
        var inner = document.getElementById( 'metadata_info' );
        
        var content = "";
        
        // if only single item and, then show the graph for item
        var count = 0;
        var urn = "";
        for( var i in MetaDataView.currentView[id] ) {
            count++;
            urn = i;
        }
        
        if ( count == 1 ) {
            // FIXME: add if no key found!
            var key = IO.getKeyFromUrn(urn);
            var img = '?mode=graph&accessPoint=' + MetaDataView.accessPoint + '&eventType=' + MetaDataView.eventType + '&key=' + key;
            
            content = '<div id="#image"><img style="visibility: none" src="' + img + '"></img></div>';
/*            content += '<script>function show_image() { '
                    +   ' GLog.write("finished loading!");'
                    +   ' document.getElementById("#preloader").style.visibility = "none";'
                    +   ' document.getElementById("#image").style.visibility = "visible";'
                    +   ' }; ' 
                    + ' document.getElementById( "#image" ).addEventListener("load", show_image, false); </script>';
            content += '<div id="#preloader"><img src="images/spinner.gif"></img></div>';*/
            
        } else {
        
            content = '<select name="item_list" size="10">';

            // TODO: sort list
            for( var i in MetaDataView.currentView[id] ) {
            
                content += '<option onclick="' + MetaDataView.currentView[id][i] + '">' + i;
            }
            
        }

        inner.innerHTML = content;
        
    },
    show: function( id, serviceType ) {
        
        GLog.write( "metadata.show id=" + id + ", serviceType=" + serviceType );

        // ignore info serviceType
        if (  serviceType != 'Info' ) {
            
            // map the id to a uri for the xml update
            MetaDataView.get( id, serviceType );

            var table = '<table class="metadata_table">'
            + '<tr>'
            +   '<td>' + MetaDataView.createList( MetaDataView.currentView ) + '</td>'
            +   '<td><div id="metadata_info">' + 'No MetaData' + '</div></td>'
            + '</tr>'
            + '</table><br/>';

            MetaDataView.set( 'infoMetaData', table );

            ExtInfoWindowView.show();
        }
    }
}

