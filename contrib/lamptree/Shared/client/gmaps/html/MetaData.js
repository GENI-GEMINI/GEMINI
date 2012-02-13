/* ****************************************************************
  MetaData 
 **************************************************************** */

MetaData = {
    nodeServices: undefined,        // what services are on the node
    nodeServiceMetaData: undefined, // for keeping tabs on what metadata was found on the node's service
    nodeData: undefined,            // what data urn's where found on the node
    linkData: undefined,            // what link urn's where found on the node
    nodeDomain: undefined,
    mergeServiceTypeEventType: function( serviceType, eventType ) {
        return serviceType + "___" + eventType;
    },
    splitServiceTypeEventType: function( str ) {
        var a = str.split( '___' );
        return a;
    },
    registerNodeDomain: function( node_id, domain ) {
        if ( typeof MetaData.nodeDomain == "undefined" ) {
            MetaData.nodeDomain = new Array();
        }
        MetaData.nodeDomain[node_id] = domain;
    },
    getNodeDomain: function( node_id ) {
        return MetaData.nodeDomain[node_id];
    },
    registerNodeService: function( node_id, serviceType, eventType, access_point ) {
        var type = MetaData.mergeServiceTypeEventType( serviceType, eventType );
        if ( typeof MetaData.nodeServices == "undefined" ) {
            MetaData.nodeServices = new Array();
        }
        if ( typeof MetaData.nodeServices[node_id] == "undefined" ) {
            MetaData.nodeServices[node_id] = new Array();
        }
        if ( typeof MetaData.nodeServices[node_id][type] == "undefined" ) {
            MetaData.nodeServices[node_id][type] = new Array();
        }
        //GLog.write( "MetaData.registerNodeService id=" + node_id + ', type=' + type + ", with accessPoint=" + access_point );
        MetaData.nodeServices[node_id][type] = access_point;
    },
    getNodeServiceIds: function( ) {
        var a = new Array();
        for( var i in MetaData.nodeServices ) {
            a.push( i );
        }
        return a;
    },
    getNodeServiceTypes: function( node_id ) {
        var a = new Array();
        if ( typeof MetaData.nodeServices == "undefined" ) {
            return a;
        }
        for( var i in MetaData.nodeServices[node_id] ) {
            a.push( i );
        }
        return a;
    },
    getNodeServiceAccessPoint: function( node_id, type ) {
        return MetaData.nodeServices[node_id][type];
    },
    dumpNodeServices: function() {
        var node_ids = MetaData.getNodeServiceIds();
        for( var i=0; i<node_ids.length; i++ ) {
            var node_id = node_ids[i];
            //GLog.write( "Services on node '" + node_id + "'");
            var types = MetaData.getNodeServiceTypes( node_id );
            for( var j=0; j<types.length; j++ ) {
                var type = types[j];
                var type_array = MetaData.splitServiceTypeEventType( type );
                //GLog.write( "  " + type_array[1] + " (" + type_array[0] + ") at access Point=" + MetaData.getNodeServiceAccessPoint( node_id, type ) );
            }
        }
    },
    
    
    registerNodeServiceMetaData: function( service_node, eventType, access_point, root, first_branch, second_branch ) {
        if ( typeof MetaData.nodeServiceMetaData == "undefined" ) {
            MetaData.nodeServiceMetaData = new Array();
        }
        if ( typeof MetaData.nodeServiceMetaData[service_node] == "undefined" ) {
            MetaData.nodeServiceMetaData[service_node] = new Array();
        }
        if ( typeof MetaData.nodeServiceMetaData[service_node][eventType] == "undefined" ) {
            MetaData.nodeServiceMetaData[service_node][eventType] = new Array();
        }
        if ( typeof MetaData.nodeServiceMetaData[service_node][eventType][access_point] == "undefined" ) {
            MetaData.nodeServiceMetaData[service_node][eventType][access_point] = new Array();
        }
        if ( typeof MetaData.nodeServiceMetaData[service_node][eventType][access_point][root] == "undefined" ) {
            MetaData.nodeServiceMetaData[service_node][eventType][access_point][root] = new Array();
        }
        if ( typeof MetaData.nodeServiceMetaData[service_node][eventType][access_point][root][first_branch] == "undefined" ) {
            MetaData.nodeServiceMetaData[service_node][eventType][access_point][root][first_branch] = new Array();
        }
        if ( typeof MetaData.nodeServiceMetaData[service_node][eventType][access_point][root][first_branch][second_branch] == "undefined" ) {
            MetaData.nodeServiceMetaData[service_node][eventType][access_point][root][first_branch][second_branch] = new Array();
        }        
        //GLog.write( "MetaData.registerNodeServiceMetaData id=" + service_node + ', eventType=' + eventType + ', ap=' + access_point + ', root=' + root + ', first_branch=' + first_branch + ', second_branch=' + second_branch );
        MetaData.nodeServiceMetaData[service_node][eventType][access_point][root][first_branch][second_branch] = 1;
    },
    getNodeServiceMetaDataRoot: function( service_node, eventType, access_point ) {
        var a = new Array();
        if ( typeof MetaData.nodeServiceMetaData == "undefined" 
            || typeof MetaData.nodeServiceMetaData[service_node] == "undefined" 
            || typeof MetaData.nodeServiceMetaData[service_node][eventType] == "undefined" 
            || typeof MetaData.nodeServiceMetaData[service_node][eventType][access_point] == "undefined"  ) {
            return a;
        }
        for( var i in MetaData.nodeServiceMetaData[service_node][eventType][access_point] ) {
            a.push( i );
        }
        return a;
    },
    getNodeServiceMetaDataFirstBranch: function( service_node, eventType, access_point, root ) {
        var a = new Array();
        for( var i in MetaData.nodeServiceMetaData[service_node][eventType][access_point][root] ) {
            a.push( i );
        }
        return a;
    },
    getNodeServiceMetaDataSecondBranch: function( service_node, eventType, access_point, root, first_branch ) {
        var a = new Array();
        for( var i in MetaData.nodeServiceMetaData[service_node][eventType][access_point][root][first_branch] ) {
            a.push( i );
        }
        return a;
    },
    
    
    registerNodeData: function( node_id, serviceType, eventType, accessPoint, urn_id, urn ) {
        var type = MetaData.mergeServiceTypeEventType( serviceType, eventType );
        if ( typeof MetaData.nodeData == "undefined" ) {
            MetaData.nodeData = new Array();
        }
        if ( typeof MetaData.nodeData[node_id] == "undefined" ) {
            MetaData.nodeData[node_id] = new Array();
        }
        if ( typeof MetaData.nodeData[node_id][type] == "undefined" ) {
            MetaData.nodeData[node_id][type] = new Array();
        }
        if ( typeof MetaData.nodeData[node_id][type][accessPoint] == "undefined" ) {
            MetaData.nodeData[node_id][type][accessPoint] = new Array();
        }
        if ( typeof MetaData.nodeData[node_id][type][accessPoint][urn_id] == "undefined" ) {
            MetaData.nodeData[node_id][type][accessPoint][urn_id] = new Array();
        }
        
        //GLog.write( "MetaData.registerNodeData id=" + node_id + ', type=' + type + ', ap=' + accessPoint + ', urn_id=' + urn_id + ', urn=' + urn );
        MetaData.nodeData[node_id][type][accessPoint][urn_id] = urn;
    },

    getNodeDataIds: function( ) {
        var a = new Array();
        if ( typeof MetaData.nodeData == "undefined" ) {
            MetaData.nodeData = new Array();
        }
        for( var i in MetaData.nodeData ) {
            a.push( i );
        }
        return a;
    },
    getNodeDataTypes: function( node_id ) {
        var a = new Array();
        if ( typeof MetaData.nodeData == "undefined" ) {
            return a;
        }
        for( var i in MetaData.nodeData[node_id] ) {
            a.push( i );
        }
        return a;
    },
    getNodeDataAccessPoints: function( node_id, type ) {
        var a = new Array();
        for ( var i in MetaData.nodeData[node_id][type] ) {
            a.push( i );
        }
        return a;
    },
    getNodeDataUrnIds: function( node_id, type, access_point ) {
        var a = new Array();
        //GLog.write( "node: " + node_id + ", type " + type + ", ap=" + access_point );
        for ( var i in MetaData.nodeData[node_id][type][access_point] ) {
            a.push( i );
        }
        return a;
    },
    getNodeDataUrn: function( node_id, type, access_point, urn_id ) {
        return MetaData.nodeData[node_id][type][access_point][urn_id];
    },
    dumpNodeData: function() {
        var node_ids = MetaData.getNodeDataIds();
        for ( var i=0; i<node_ids.length; i++ ) {
            var node_id = node_ids[i];
            //GLog.write( "Node id " + node_id + " contains serviceTypes:" );
            var types = MetaData.getNodeDataTypes( node_id );
            for ( var j=0; j<types.length; j++ ) {
                var type = types[j];
                var type_array = MetaData.splitServiceTypeEventType( type );
                //GLog.write( "  " + type_array[1] + "(" + type_array[0] + ") has accessPoints:");
                var access_points = MetaData.getNodeDataAccessPoints( node_id, type );
                for ( var k=0; k<access_points.length; k++) {
                    var access_point = access_points[k];
                    //GLog.write( "    " + access_point + " has urn:");
                    var urns = MetaData.getLinkDataUrnIds( node_id, type, access_point );
                    for( var l=0; l<urns.length; l++ ) {
                        var urn = urns[k];
                        //GLog.write( "      id=" + urn + " " + MetaData.getNodeDataUrn( node_id, type, access_point, urn ) );
                    }
                }
            }
        }
    },
    
    
    registerLinkData: function( link_id, serviceType, eventType, access_point, urn_id, urn ) {
        var type = MetaData.mergeServiceTypeEventType( serviceType, eventType );
        if ( typeof MetaData.linkData == "undefined" ) {
            MetaData.linkData = new Array();
        }
        if ( typeof MetaData.linkData[link_id] == "undefined" ) {
            MetaData.linkData[link_id] = new Array();
        }
        if ( typeof MetaData.linkData[link_id][type] == "undefined" ) {
            MetaData.linkData[link_id][type] = new Array();
        }
        if ( typeof MetaData.linkData[link_id][type][access_point] == "undefined" ) {
            MetaData.linkData[link_id][type][access_point] = new Array();
        }
        if ( typeof MetaData.linkData[link_id][type][access_point][urn_id] == "undefined" ) {
            MetaData.linkData[link_id][type][access_point][urn_id] = new Array();
        }
        //GLog.write( "MetaData.registerLinkData id=" + link_id + ', type=' + type + ', ap=' + access_point + ', urn_id=' + urn_id + ', urn=' + urn );
        MetaData.linkData[link_id][type][access_point][urn_id] = urn;
    },
    getLinkDataIds: function() {
        var a = new Array();
        for ( var i in MetaData.linkData ) {
            a.push( i );
        }
        return a;
    },
    getLinkDataTypes: function( link_id ) {
        var a = new Array();
        if ( typeof MetaData.linkData == "undefined" ) {
            return a;
        }
        for( var i in MetaData.linkData[link_id] ) {
            a.push( i );
        }
        return a;
    },
    getLinkDataAccessPoints: function( link_id, type ) {
        var a = new Array();
        for( var i in MetaData.linkData[link_id][type] ) {
            a.push( i );
        }
        return a;
    },
    getLinkDataUrnIds: function( link_id, type, access_point ) {
        var a = new Array();
        for ( var i in MetaData.linkData[link_id][type][access_point] ) {
            a.push( i );
        }
        return a;
    },
    getLinkDataUrn: function( link_id, type, access_point, urn_id ) {
        return MetaData.linkData[link_id][type][access_point][urn_id];
    },
    dumpLinkData: function() {
        var link_ids = MetaData.getLinkDataIds();
        for ( var i=0; i<link_ids.length; i++ ) {
            var link_id = link_ids[i];
            //GLog.write( "Link id " + link_id + " contains types:" );
            var types = MetaData.getLinkDataTypes( link_id );
            for ( var j=0; j<types.length; j++ ) {
                var type = types[j];
                var type_array = MetaData.splitServiceTypeEventType( type );
                //GLog.write( "|-" + type_array[1] + " (" + type_array[0] + ") has accessPoints:");
                var access_points = MetaData.getLinkDataAccessPoints( link_id, type );
                for ( var k=0; k<access_points.length; k++ ) {
                    var access_point = access_points[k];
                    //GLog.write( "||-" + access_point + " has urns:");
                    var urns = MetaData.getLinkDataUrnIds( link_id, type, access_point );
                    for( var l=0; l<urns.length; l++ ) {
                        var urn_id = urns[l];
                        //GLog.write( "|||- id=" + urn_id + ", " + MetaData.getLinkDataUrn( link_id, type, access_point, urn_id ) );
                    }
                }
            }
        }
    }
}