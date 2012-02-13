/* ****************************************************************
  XML Polling
 **************************************************************** */

IO = {
    // retrieves a list of all the gls and plots them on the map
    fetchInitial: function() {
        IO.discover( );

/*
        IO.discover( 'http://ndb1.internet2.edu:8005/perfSONAR_PS/services/hLS',
                        'http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0',
                        'ndb1.internet2.edu', 
                        'Lookup' );
*/

        //IO.discover( '?mode=discover&accessPoint=http://tukki.fnal.gov:9990/perfSONAR_PS/services/gLS');

/*
         IO.discover(   'http://nptoolkit.grnoc.iu.edu:8095/perfSONAR_PS/services/hLS',
                        'http://ogf.org/ns/nmwg/tools/org/perfsonar/service/lookup/discovery/summary/2.0',
                        'nptoolkit.grnoc.iu.edu', 
                        'Lookup' );
*/
/*
        IO.discover( 'http://nptoolkit.grnoc.iu.edu:8075/perfSONAR_PS/services/pinger/ma',
                        'http://ggf.org/ns/nmwg/tools/pinger/2.0/',
                        'nptoolkit.grnoc.iu.edu',
                        'PingER' );
*/
},


    // retrieves the nodes for the uri
    discover: function( access_point, eventType, service_node, serviceType ) {

        var uri = "";
        if ( typeof access_point == "undefined" ) {
            uri = IO.getGlsUrl();
        } else {
            uri = IO.getDiscoverUrl( access_point, eventType );
        }
        Help.discover( uri );

        if( debug )
            GLog.write( "Discovering services from '" + uri + "'");

        // add the calling node info if supplied
        if ( typeof service_node != "undefined" ) {
            //GLog.write( "Registering calling service: " + service_node + ", serviceType=" + serviceType + ", eventType=" + eventType + ", accessPoint=" + access_point );
            MetaData.registerNodeService( service_node, serviceType, eventType, access_point );
        }


        // deal with timeouts etc
        GDownloadUrl( uri, function(doc,response) {

          // downloaded okay
          if ( response == 200 ) {

            Sidebar.clear();
            Sidebar.setContent('<p align="center">Please wait.<br>Fetching perfSONAR information: <br>This could take some time...<br><img src="spinner.gif"/></p>' );
            Sidebar.refresh();
                        
            var dom = GXml.parse(doc);

            if( debug )
                GLog.write( "Adding Nodes..." );
            var nodes = dom.documentElement.getElementsByTagName("node");
            if( debug )
                GLog.write( "  got " + nodes.length + " markers from '" + uri + "'");
            var markerCount = 0;
            var serviceCount = 0;
            var linkCount = 0;

            for (var i = 0; i < nodes.length; i++) {

              var lat = nodes[i].getAttribute("lat");
              var lng = nodes[i].getAttribute("lng");

              var domain = nodes[i].getAttribute("domain");
              var id = nodes[i].getAttribute("id");

              // if there is no determinable long/lat, place it in the bermuda triagle
              if ( ( lat == "" || lat == 'NULL' ) || ( lng == "" || lng == 'NULL' ) ) {
                lat = '26.511129';
                lng = '-71.48186';
                if( debug )
                    GLog.write( "Marker '" + id + "' does not contain valid coordinates, placing in Bermuda Triangle" );
              }

              // add marker
              Markers.add( lat, lng, id );
              MetaData.registerNodeDomain( id, domain );
              
              // if there are service element defined, then assume services on this node
              var els = nodes[i].getElementsByTagName("service");
              //GLog.write( "  adding " + els.length + " services for node '" + id + "'");
              var n = 0;
              for ( var j=0; j<els.length; j++ ) {
                var this_serviceType = els[j].getAttribute( 'serviceType' );
                var this_eventType = els[j].getAttribute( 'eventType' );
                var this_access_point = els[j].getAttribute( 'accessPoint' );
                
                Sidebar.add( domain, id, this_serviceType + ' Service');
                serviceCount++;
                
                MetaData.registerNodeService( id, this_serviceType, this_eventType, this_access_point );
                
                // add info about what this node has info for
                MetaData.registerNodeServiceMetaData( service_node, eventType, access_point, this_serviceType + ' Service', id );
                
              }

              // add urn's for nodes (like utilisaiton etc)

              els = nodes[i].getElementsByTagName("urn");
              //GLog.write( "  adding " + els.length + " data for node '" + id + "'");
              var m = 0;
              for( var j=0; j<els.length; j++ ) {
                  var this_serviceType = els[j].getAttribute( 'serviceType' );
                  var this_eventType = els[j].getAttribute( 'eventType' );
                  var this_access_point = els[j].getAttribute( 'accessPoint' );
                  var this_urn_id = els[j].getAttribute( 'id' );              
                  var this_urn = els[j].firstChild.nodeValue;
                  
                  MetaData.registerNodeData( id, this_serviceType, this_eventType, this_access_point, this_urn_id, this_urn );
                  
                  // register the fact that this data was found on service
                  MetaData.registerNodeServiceMetaData( service_node, eventType, access_point, id, this_urn_id );
                  
                  Sidebar.add( domain, id, this_serviceType );
              }

              markerCount++;

            } // for
            
/*            if( debug ) {
                MetaData.dumpNodeServices();
                MetaData.dumpNodeData();
            }*/

            if( debug )
                GLog.write( "Adding Links..." );
            var links = dom.documentElement.getElementsByTagName("link");
            if( debug )
                GLog.write( "  completed fetching " + links.length + " links from '" + uri + "'");
            for ( var i = 0; i < links.length; i++ ) {

              var src_id = links[i].getAttribute("src");
              var dst_id = links[i].getAttribute("dst");
              var src_domain = links[i].getAttribute("srcDomain");
              var dst_domain = links[i].getAttribute("dstDomain");

              Links.add( src_id, dst_id );
              var link_id = Links.getId( src_id, dst_id );
              var domain_path = Links.getId( src_domain, dst_domain );
              Sidebar.add( src_domain, domain_path, link_id );

              Markers.registerType( src_id, 'src' );
              MetaData.registerNodeDomain( src_id, src_domain );
              Markers.registerType( dst_id, 'dst' );
              MetaData.registerNodeDomain( dst_id, dst_domain );
                            
              var els = links[i].getElementsByTagName( 'urn' );
              for ( var j=0; j<els.length; j++ ) {
                  var this_serviceType = els[j].getAttribute('serviceType');
                  var this_eventType = els[j].getAttribute('eventType');
                  var this_access_point = els[j].getAttribute('accessPoint');
                  var this_urn_id = els[j].getAttribute('id');
                  var this_urn = els[j].firstChild.nodeValue;
                  
                  MetaData.registerLinkData( link_id, this_serviceType, this_eventType, this_access_point, this_urn_id, this_urn );

                  MetaData.registerNodeServiceMetaData( service_node, eventType, access_point, src_id, dst_id );

              }

              Links.show( link_id );
              linkCount++;

            }
/*            if( debug )
                MetaData.dumpLinkData();*/

            Sidebar.show();

            // can only update/how the markers here as we need to process links and services to determine
            // the appropriate type fo the marker first
            for (var i = 0; i < nodes.length; i++) {
              var id = nodes[i].getAttribute("id");
              Markers.show( id );
            }

            // refresh window
            // FIXME?
            ExtInfoWindowView.focus();

            Help.discovered( uri, markerCount, linkCount, serviceCount );

            // timeout
          } else if ( response == -1 ) {
            if( debug )
                GLog.write( "Request for '" + uri + "' timed out" );
            Help.timeOut( uri );
          } else {
            if( debug )
              GLog.write( "unknown response code returned " + response );
            Help.unknownResponse( uri, response );
          }
        });
    },
    getKeyFromUrn: function( urn ) {
        //GLog.write( "matching urn '" + urn + "' for key");
        var a = new Array();
        a = urn.match( /key=((\w|\,)+):?/ );
        if ( a == null ) {
            return undefined;
        } else if ( a.length > 0 ){
            return a[1];
        }
    },
    
    getUrl: function( access_point, eventType, urn ) {
        var uri = 'accessPoint=' + access_point;
        if ( typeof eventType != "undefined" ) {
            uri += '&eventType=' + eventType;
        }
        if( typeof urn != "undefined" ) {
            // use the key if we have one
            var key = IO.getKeyFromUrn( urn );
            if ( typeof key == "undefined" ){
                uri += '&urn=' + urn;
            } else {
                uri += '&key=' + key;
            }
        }
        return uri;
    },
    getGraphUrl: function( access_point, eventType, urn ) {
        var src = '?mode=graph&' + IO.getUrl( access_point, eventType, urn );
        return src;
    },
    getDiscoverUrl: function( access_point, eventType ) {
        var src = '?mode=discover&' + IO.getUrl( access_point, eventType );
        return src;
    },
    getGlsUrl: function() {
        var src = '?mode=getGLS';
        return src;
    }
    
}

