package edu.internet2.perfsonar;

import java.util.*;

import org.apache.log4j.*;

import org.jdom.*;

public class PSTopologyClient implements PSMessageEventHandler {
    String url;
    Element topology;
    PSBaseClient ps_client;
    boolean addReplaceSuccess;
    PSNamespaces psNS;
    
    private Logger log;
    private String topo_get_all_str =
            "<nmwg:message type=\"QueryRequest\" "+
            "   xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"> "+
            "    <nmwg:metadata id=\"meta1\">" +
            "      <nmwg:eventType>http://ggf.org/ns/nmwg/topology/20070809</nmwg:eventType>" +
            "   </nmwg:metadata>" +
            "   <nmwg:data id=\"data1\" metadataIdRef=\"meta1\"/> "+
            "</nmwg:message>";

    private String topo_replace_str =
            "<nmwg:message type=\"TSReplaceRequest\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">" +
            "  <nmwg:metadata id=\"meta0\">" +
            "    <nmwg:eventType>http://ggf.org/ns/nmwg/topology/20070809</nmwg:eventType>" +
            "  </nmwg:metadata>" +
            "  <nmwg:data id=\"data0\" metadataIdRef=\"meta0\">" +
            "     <!--topology-->" +
            "  </nmwg:data>" +
            "</nmwg:message>";

    public PSTopologyClient(String url) {
        this.ps_client = new PSBaseClient(url);
        this.log = Logger.getLogger(this.getClass());
        this.psNS = new PSNamespaces();
    }

    public Element getTopology() {
        if (this.topology == null) {
            lookupTopology();
        }

        return this.topology;
    }

    public boolean addReplaceDomain(String domStr) {
        String topoStr =
            "<"+this.psNS.TOPO.getPrefix()+":topology xmlns:"+this.psNS.TOPO.getPrefix()+"=\""+this.psNS.TOPO.getURI()+"\">\n" +
            domStr +
            "</"+this.psNS.TOPO.getPrefix()+":topology>";
        String request = new String(topo_replace_str).replaceAll("<!--topology-->", topoStr);

        this.log.debug("Request post replaceAll: "+request);

        this.addReplaceSuccess = false;

        this.ps_client.sendMessage_CB(request, this, null);

        return this.addReplaceSuccess;
    }

    private void lookupTopology() {
        this.ps_client.sendMessage_CB(topo_get_all_str, this, null);
    }

    public void handleMetadataDataPair(Element metadata, Element data, HashMap <String, Element> metadataMap, String messageType, Object arg) {

        if (messageType.equals("QueryResponse")) {
            Element eventType_elm = metadata.getChild("eventType", this.psNS.NMWG);
            if (eventType_elm == null) {
                this.log.debug("The metadata/data pair doesn't have an event type");
                return;
            }

            if (!eventType_elm.getValue().equals("http://ggf.org/ns/nmwg/topology/20070809")) {
                this.log.debug("The metadata/data pair has an unknown event type: "+eventType_elm.getValue());
                return;
            }

            Element topo = data.getChild("topology", this.psNS.TOPO);

            if (topo == null) {
                this.log.debug("No topology located in data");
                return;
            }

            this.topology = topo;
        } else if (messageType.equals("TSReplaceResponse")) {
            Element eventType_elm = metadata.getChild("eventType", this.psNS.NMWG);
            if (eventType_elm == null) {
                this.log.error("Received a metadata/data pair without an event type");
            }

            String eventType = eventType_elm.getValue();
            if (eventType.matches("^success\\..*") == true) {
                this.addReplaceSuccess = true;
            } else if (eventType.matches("^error\\..*") == true) {
                this.addReplaceSuccess = false;
            } else {
                this.log.error("Received a metadata/data pair with an unknown event type: "+eventType);
            }
        } else {
            this.log.error("Received a metadata/data pair from an unknown message type: "+messageType);
        }
    }
}
