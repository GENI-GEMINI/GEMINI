/* ****************************************************************
  Help Maps
 **************************************************************** */

Help = {
    element: undefined,
    init: function( this_element ) {
        Help.element = document.getElementById( this_element );
    },
    set: function( text ) {
       Help.element.innerHTML = text;
    },
    splitURI: function( src ) {
        var a = src.split( '&' );
        var out = new Array();
        for ( var i in a ) {
            var j = a[i].split( '=' );
            out[j[0]] = j[1];
        }
        return out;
    },
    discover: function( src ) {
        Help.set( '<table><tr><td><img src="images/spinner.gif"/></td><td>Querying perfSONAR service at \'' + Help.splitURI(src)['accessPoint'] + '\'.</p><p>Please wait.</tr></table>' );
    },
    discovered: function( src, nodes, links, services ) {
        
        Help.set( '<p>Finished querying perfSONAR service metadata at \'' + Help.splitURI(src)['accessPoint'] + '\'.</p>'
            + '<p>Found:<p>'
            + '<table>'
            + '<tr><td>Nodes</td><td>' + nodes + '</td></tr>'
            + '<tr><td>Links</td><td>' + links + '</td></tr>'
            + '<tr><td>Services</td><td>' + services + '</td></tr>'
            + '</table>' );
    },
    timeOut: function( uri ) {
        Help.set( '<table><tr><td><img src="images/warning.png" /></td><td>Service \'' + Help.splitURI(uri)['accessPoint'] + '\' timed out.</td></tr></table>' );
    },
    unknownResponse: function( uri, response ) {
        Help.set( '<table><tr><td><img src="images/warning.png" /></td><td>Service \'' + Help.splitURI(uri)['accessPoint'] + '\' returned unknown response \'' + response + '\'.</td></tr></table>' );
    },    
    markerInfo: function( id ) {
        Help.set( '<p>The popup window shows all the available perfSONAR services that are available at \'' + id + '\'. These services are presented on the tabs at the top of the window.</p>'
        + '<p>Each service provide information on the details of the available data (metadata). We can query the service through its\' associated Access Point with the eventType of the data we are interested.</p>'
        + '<p>Click on a tab to discover information about the perfSONAR services and data available.</p>' );
    },
    linkInfo: function( id ) {
      Help.set( '<p>The popup window shows the real time performance using perfSONAR for \'' + id + '\'. Each available performance metric is displayed on each tab on the window.'
      + '<p>Clicking on the tab will query the perfSONAR service for raw performance information which will then be presented inthe form of a graph.<p>'
      + '<p>An unique identifier (URN) is used to query the perfSONAR service for the specified information representing the eventType, endpoint pair, and specific metadata pertaining to the measurement.</p>' );  
    },
    marker: function( id ) {
        var type = Markers.pType[id];
        var service = MetaData.getNodeServiceTypes(id);
        var str = '<p>The marker \'' + id + '\' contains ' + service.length + ' discovered service(s). Click on Marker to show available list of services.</p>';
        if ( type == undefined ) {
            str = str + '<p>There are no data sources at this host.</p>';
        } else if ( type == 'src' ) {
            str = str + '<p>There are performance data sources available at this host. Click on marker to see paths for end-to-end performance to various domains.<p>';
        } else if ( type == 'dst' ) {
            str = str + '<p>This marker only contains performnace data to this host.</p>';
        } else {
            str = str + '<p>This marker contains both source and destination performance information.<p>';
        }
        Help.set( str );
    },
    link: function( id ) {
        Help.set( "<p>There is performance data available at this link '" + id + "'.</p>"
            + '<p>Click on link to determine the types of performance metrics found.</p>' );
    },
    infoWindowService: function( type  ) {
        var help = "";
        var service = 1;

        if ( type == 'Lookup Service' ) {
            help = "<p>A Lookup Service provides a central location to find available perfSONAR services.</p>";
        } else if ( type == "Info" ) {
        
        } else if ( type == 'hLS Service' ) {
            help = "<p>A hLS provides a localised lookup services for a domain or area</p>";
        } else if ( type == 'PingER Service' ) {
            help = "<p>PingER Services provide ping measurements between sites; offering network performance metrics such as two-way latency and packet loss.</p>";
        } else if ( type == 'OWAMP Service' ) {
            help = "<p>OWAMP Services provide latency measurements between sites; offering network performance metrics such as one-way latency and packet loss.</p>";
        } else if ( type == 'BWCTL Service' ) {
            help = "<p>BWCTL Services provides throughput measurements between sites; offering network performance using UDP and TCP measurements.</p>";
        } else if ( type == "Utilisation Service" ) {
            help = "<p>Utilisation Services provide network utilisation metrics for router and switch interfaces.</p>";

        } else if ( type == "PingER" ) {
            help += "<p>PingER provides two-way latency and loss measurements for this link.</p>";
            service = 0;
        } else if ( type == "OWAMP" ) {
            help += "<p>OWAMP provides one-way latency and loss measurements for this link.</p>";
            service = 0;
        } else if ( type == "BWCTL" ) {
            service = 0;
            help += "<p>BWCTL provides throughput measurements for this link.</p>";
        }
        
        
        if ( service ) {
            help += "<p>Click on 'Query Service' to determine the registered metadata services on this " + type + ". This will send out a live request for 'metadata'.</p>";
            help += "<p>The discovered metadata found will then be displayed on the lists at the bottom of the infoWindow.</p>";            
        }
        
        Help.set( help );
    },
    map: function() {
        Help.set( '<p>Markers represent hosts that are participating with perfSONAR monitoring. A number on a marker represents the number of perfSONAR services available for query.</p>'
        + '<table>'
        + '<tr><td><img src="images/minired.png"/></td>Host has a perfSONAR service available.<td></td></tr>'
        + '<tr><td><img src="images/minigreen.png"/></td><td>Marker is has data available.</td></tr>' 
        + '<tr><td><img src="images/minigrey.png"/></td><td>Marker is a data endpoint (ie tests are being performed to this host).</td></tr>'
        + '</table>'
        + '<p>Click on a marker to bring up further options.</p>' );
    }
    
}

