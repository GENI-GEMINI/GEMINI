package edu.internet2.perfsonar;

import java.io.IOException;
import java.io.StringWriter;
import java.net.InetAddress;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Hashtable;
import java.util.List;
import java.util.Iterator;

import org.apache.commons.httpclient.HttpException;
import org.apache.log4j.Logger;
import org.jdom.Element;
import org.jdom.JDOMException;
import org.jdom.Namespace;
import org.jdom.output.XMLOutputter;
import org.jdom.xpath.XPath;

import edu.internet2.perfsonar.PSBaseClient;
import edu.internet2.perfsonar.PSMessageEventHandler;
import edu.internet2.perfsonar.PSException;
import edu.internet2.perfsonar.PSLookupClient;
import edu.internet2.perfsonar.PSNamespaces;

import edu.internet2.perfsonar.utils.*;

/**
 * Performs lookup operations useful for dynamic circuits netwoking (TS)
 * applications.
 *
 */
public class TSLookupClient {
    protected Logger log;
    protected String[] gLSList;
    protected String[] hLSList;
    protected String[] TSList;
    protected boolean tryAllGlobal;
    protected PSNamespaces psNS;
    protected List <TSCacheElement> cache;
    protected boolean disableCaching;

    protected long TOPOLOGY_CACHE_LENGTH = 3600; // One hour
    protected long FAILURE_TOPOLOGY_CACHE_LENGTH = 300; // Five minutes
    protected long DOMAIN_CACHE_LENGTH = 86400; // One hour
    protected long FAILURE_DOMAIN_CACHE_LENGTH = 300; // Five minutes

    protected boolean cacheTopologes = true;
    protected boolean cacheFailures = true;

    static final protected String TOPOLOGY_EVENT_TYPE = "http://ggf.org/ns/nmwg/topology/20070809";

    protected String GLS_XQUERY =
        "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n" +
        "declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n" +
        "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n" +
        "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n" +
        "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n" +
        "for $metadata in /nmwg:store[@type=\"LSStore\"]/nmwg:metadata\n" +
        "    let $metadata_id := $metadata/@id  \n" +
        "    let $data := /nmwg:store[@type=\"LSStore\"]/nmwg:data[@metadataIdRef=$metadata_id]\n" +
        "    where $data/nmwg:metadata/nmwg:eventType[text()=\""+TOPOLOGY_EVENT_TYPE+"\"] and $data/nmwg:metadata/summary:subject/nmtb:domain/nmtb:name[@type=\"dns\" and text()=\"<!--domain_name-->\"]\n" +
        "    return $metadata/perfsonar:subject/psservice:service/psservice:accessPoint\n";

    protected String HLS_XQUERY =
            "   declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n" +
            "   declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n" +
            "   declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n" +
            "   declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n" +
            "   declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n" +
            "   for $metadata in /nmwg:store[@type=\"LSStore\"]/nmwg:metadata\n" +
            "       let $metadata_id := $metadata/@id  \n" +
            "       let $data := /nmwg:store[@type=\"LSStore\"]/nmwg:data[@metadataIdRef=$metadata_id]\n" +
            "       where $data/nmwg:metadata/nmwg:eventType[text()=\""+TOPOLOGY_EVENT_TYPE+"\"] and $data/nmwg:metadata/*[local-name()=\"subject\"]/*[local-name()=\"domain\" and @id=\"<!--domain_id-->\"]\n" +
            "       return $metadata/perfsonar:subject/psservice:service/psservice:accessPoint\n";

    protected String TS_QUERY =
            "<nmwg:message type=\"QueryRequest\" "+
            "   xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"> "+
            "    <nmwg:metadata id=\"meta1\">" +
            "      <xquery:subject id=\"sub1\" xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/xquery/1.0/\">" +
            "        //*[@id=\"<!--domain_id-->\"]" +
            "      </xquery:subject>" +
            "      <nmwg:eventType>"+TOPOLOGY_EVENT_TYPE+"</nmwg:eventType>" +
            "   </nmwg:metadata>" +
            "   <nmwg:data id=\"data1\" metadataIdRef=\"meta1\"/> "+
            "</nmwg:message>";
    /**
     * Creates a new client with the list of Global lookup services to
     * contact determined by reading the hints file at the provided URL.
     * The result returned by the list file will be randomly re-ordered.
     *
     * @param hintsFile the URL of the hints file to use to populate the list of global lookup services
     * @throws HttpException
     * @throws IOException
     */
    public TSLookupClient() throws HttpException, IOException {
        this.log = Logger.getLogger(this.getClass());
        String[] gLSList = PSLookupClient.getGlobalHints("http://www.perfsonar.net/gls.root.hints", true);
        this.gLSList = gLSList;
        this.hLSList = null;
        this.TSList = null;
        this.tryAllGlobal = false;
        this.psNS = new PSNamespaces();
        this.cache = new ArrayList<TSCacheElement>();
        this.disableCaching = false;
    }

    /**
     * Creates a new client with the list of Global lookup services to
     * contact determined by reading the hints file at the provided URL.
     * The result returned by the list file will be randomly re-ordered.
     *
     * @param hintsFile the URL of the hints file to use to populate the list of global lookup services
     * @throws HttpException
     * @throws IOException
     */
    public TSLookupClient(String hintsFile) throws HttpException, IOException {
        this.log = Logger.getLogger(this.getClass());
        String[] gLSList = PSLookupClient.getGlobalHints(hintsFile, true);
        this.gLSList = gLSList;
        this.hLSList = null;
        this.TSList = null;
        this.tryAllGlobal = false;
        this.psNS = new PSNamespaces();
        this.cache = new ArrayList<TSCacheElement>();
        this.disableCaching = false;
    }

    /**
     * Creates a new client with an explicitly set list of global and/or
     * home lookup services. One of the parameters may be null. If the first
     * parameter is null then no global lookup servioces will be contacted
     * only the given home lookup services will be used. If the second paramter is
     * null the given set of global lookup services will be used to find the home
     * lookup service.
     *
     * @param gLSList the list of global lookup services to use
     * @param hLSList the list of home lookup services to use
     */
    public TSLookupClient(String[] gLSList, String[] hLSList, String[] TSList){
        this.log = Logger.getLogger(this.getClass());
        this.gLSList = gLSList;
        this.hLSList = hLSList;
        this.TSList = TSList;
        this.tryAllGlobal = false;
        this.psNS = new PSNamespaces();
        this.cache = new ArrayList<TSCacheElement>();
        this.disableCaching = false;
    }

    /**
     * Finds the URN of a host with the given name.
     *
     * @param name the name of the host o lookup
     * @return the Topology of the domain given by the specified domain identifier
     * @throws PSException
     */
    public Element getDomain(String domainId) throws PSException{
        return this.getDomain(domainId, null);
    }

    public Element getDomain(String domainId, String namespace) throws PSException{
        Hashtable<String, String> urnInfo = URNParser.parseTopoIdent(domainId);

        if (urnInfo.get("type").equals("domain") == false) {
            return null;
        }

        String domainName = urnInfo.get("domainValue");

        long currentTime = System.currentTimeMillis();

        TSCacheElement cacheElement = this.getCache(domainId, namespace);
        if (cacheElement != null) {
            this.log.debug("Got cached instance of "+domainId);

            if (cacheElement.topology == null) {
                if (currentTime < (cacheElement.retrieveTime + this.FAILURE_TOPOLOGY_CACHE_LENGTH * 1000)) {
                    return cacheElement.topology;
                }
            } else {
                if (currentTime < (cacheElement.retrieveTime + this.TOPOLOGY_CACHE_LENGTH * 1000)) {
                    return cacheElement.topology;
                }
            }

            if (cacheElement.TS != null && currentTime < (cacheElement.retrieveTime + this.DOMAIN_CACHE_LENGTH * 1000)) {
                Element topology = this.getDomainQueryTS(cacheElement.TS, domainId, namespace);
                if (topology != null) {
                    String currNamespace = null;

                    if (namespace != null) {
                        currNamespace = namespace;
                    } else {
                        List<Element> children = this.getElementChildren(topology, "domain");
                        for (Element child : children) {
                            currNamespace = child.getNamespace().getURI();
                            break;
                        }
                    }

                    if (currNamespace != null)
                        this.addCache(domainId, currNamespace, currentTime, cacheElement.TS, topology);

                    return topology;
                }
            }
        } else {
            this.log.debug("Got cached instance of "+domainId);
        }

        String [] TSMatches = this.getTSList();
        if (TSMatches == null) {
            String[] hLSMatches = this.getHLSList();
            if(hLSMatches == null){
                try {
                    String discoveryXQuery = GLS_XQUERY;
                    discoveryXQuery = discoveryXQuery.replaceAll("<!--domain_name-->", domainName);
                    Element discReqElem = this.createQueryMetaData(discoveryXQuery);
                    String [] gLSs = this.getGLSList();
                    hLSMatches = this.findServices(gLSs, this.isTryAllGlobal(), this.requestString(discReqElem, null));
                } catch (PSException e) {}
            }

            if (hLSMatches != null) {
                try {
                    String xquery = HLS_XQUERY;
                    xquery = xquery.replaceAll("<!--domain_id-->", domainId);
                    Element reqElem = this.createQueryMetaData(xquery);
                    TSMatches = this.findServices(hLSMatches, true, this.requestString(reqElem, null));
                } catch (PSException e) {}
            }
        }

        if (TSMatches != null) {
            for(String ts_url : TSMatches) {
                Element topology = getDomainQueryTS(ts_url, domainId, namespace);
                if (topology != null) {
                    String currNamespace = null;

                    if (namespace != null) {
                        currNamespace = namespace;
                    } else {
                        List<Element> children = this.getElementChildren(topology, "domain");
                        for (Element child : children) {
                            currNamespace = child.getNamespace().getURI();
                            break;
                        }
                    }

                    if (currNamespace != null)
                        this.addCache(domainId, currNamespace, currentTime, ts_url, topology);

                    return topology;
                }
            }
        }

        if (this.cacheFailures) {
            if (namespace != null) {
                this.addCache(domainId, namespace, currentTime, null, null);
            }
        }

        return null;
    }

    private Element getDomainQueryTS(String TSUrl, String domainId, String namespace) throws PSException {
        Element retTopology = null;

        PSBaseClient pSClient = new PSBaseClient(TSUrl);

        String xquery = TS_QUERY;
        xquery = xquery.replaceAll("<!--domain_id-->", domainId);

        TSClientCallback cb = new TSClientCallback();
        pSClient.sendMessage_CB(xquery, cb, null);
        Element topo = cb.getRetrievedTopology();
        if (topo != null) {
            List<Element> children = this.getElementChildren(topo, "domain");
            for (Element child : children) {
                // construct the domain topology identifier
                String newDomainId = child.getAttributeValue("id");

                if (domainId.equals(newDomainId) == false || (namespace != null && child.getNamespace().getURI().equals(namespace) == false)) {
                    topo.removeContent(child);
                } else if (namespace == null || child.getNamespace().getURI().equals(namespace) == true) {
                    retTopology = topo;
                }
            }
        }

        return retTopology;
    }

    /**
     * Contacts a global lookup service(s) to get the list of home lookup
     * services possible containing desired data. If the "tryAllGlobals"
     * property is set to true then it will contact every global to build
     * its list of home lookup services.
     *
     * @param request the discovery request
     * @return the list of matching home lookup services
     * @throws PSException
     */
    public String[] findServices(String [] lookupServices, boolean tryAll, String request) throws PSException{
        String[] accessPoints = null;
        HashMap<String, Boolean> apMap = new HashMap<String, Boolean>();

        String errLog = "";
        for (String ls : lookupServices) {
            try{
                PSLookupClient lsClient = new PSLookupClient(ls);
                Element response = lsClient.query(request);
                Element metaData = response.getChild("metadata", psNS.NMWG);

                if(metaData == null){
                    throw new PSException("No metadata element in discovery response");
                }
                Element eventType = metaData.getChild("eventType", psNS.NMWG);
                if(eventType == null){
                    throw new PSException("No eventType returned");
                }else if(eventType.getText().startsWith("error.ls")){
                    Element errDatum = lsClient.parseDatum(response, psNS.NMWG_RESULT);
                    String errMsg = (errDatum == null ? "An unknown error occurred" : errDatum.getText());
                    this.log.error(eventType.getText() + ": " + errMsg);
                    throw new PSException("Global discovery error: " + errMsg);
                }else if(!"success.ls.query".equals(eventType.getText())){
                    throw new PSException("Hostname not found because lookup " +
                                          "returned an unrecognized status");
                }

                Element datum = lsClient.parseDatum(response, psNS.PS_SERVICE);
                if(datum == null){
                    throw new PSException("No service datum returned from discovery request");
                }
                List<Element> accessPointElems = datum.getChildren("accessPoint", psNS.PS_SERVICE);
                for(int i = 0; i < accessPointElems.size(); i++){
                    apMap.put(accessPointElems.get(i).getTextTrim(), true);
                }
                if(!tryAll){
                    break;
                }
            }catch(PSException e){
                errLog += ls + ": " + e.getMessage() + "\n\n";
            }catch(Exception e){
                errLog += ls + ": " + e.getMessage() + "\n\n";
            }
        }

        if(apMap.isEmpty()){
            throw new PSException("No services found after trying lookup services:\n" + errLog);
        }

        accessPoints = new String[apMap.size()];
        apMap.keySet().toArray(accessPoints);

        return accessPoints;
    }

    /**
     * @return the list of global lookup services
     */
    public synchronized String[] getGLSList() {
        return gLSList;
    }

    /**
     * @param list the list of global lookup services to set
     */
    public synchronized void setGLSList(String[] list) {
        gLSList = list;
    }

    /**
     * @return the list of home lookup services
     */
    public synchronized String[] getHLSList() {
        return hLSList;
    }

    /**
     * @param list the list of home lookup services to set
     */
    public synchronized void setHLSList(String[] list) {
        hLSList = list;
    }

    /**
     * @return the list of home lookup services
     */
    public synchronized String[] getTSList() {
        return TSList;
    }

    /**
     * @param list the list of home lookup services to set
     */
    public synchronized void setTSList(String[] list) {
        TSList = list;
    }


    /**
     * @return if true then every global lookup services will be used to
     *  find the home LS, otherwise just the first entry will be used
     */
    public synchronized boolean isTryAllGlobal() {
        return tryAllGlobal;
    }

    /**
     * @param tryAllGlobal if true then every global lookup services will be used to
     *  find the home LS, otherwise just the first entry will be used
     */
    public synchronized void setTryAllGlobal(boolean tryAllGlobal) {
        this.tryAllGlobal = tryAllGlobal;
    }

    public void setDisableCaching(boolean disabled) {
        this.disableCaching = disabled;
    }

    /**
     * Generates a new metadata element
     *
     * @param ns the namespace of the subject. if null then no subject
     * @return the generated metadata
     */
    private Element createMetaData(Namespace ns){
        Element metaDataElem = new Element("metadata", this.psNS.NMWG);
        metaDataElem.setAttribute("id", "meta" + metaDataElem.hashCode());
        if(ns != null){
            Element subjElem = new Element("subject", ns);
            subjElem.setAttribute("id", "subj"+subjElem.hashCode());
            metaDataElem.addContent(subjElem);
        }
        return metaDataElem;
    }

    /**
     * Generates a new query metadata element
     *
     * @param query the XQuery to send
     * @return the generated metadata
     */
    private Element createQueryMetaData(String query){
        Element metaDataElem = this.createMetaData(this.psNS.XQUERY);
        metaDataElem.getChild("subject", this.psNS.XQUERY).setText(query);
        Element eventType = new Element("eventType", this.psNS.NMWG);
        eventType.setText("http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0");
        metaDataElem.addContent(eventType);
        Element paramsElem = new Element("parameters", this.psNS.XQUERY);
        paramsElem.setAttribute("id", "params"+paramsElem.hashCode());
        Element paramElem = new Element("parameter", this.psNS.NMWG);
        paramElem.setAttribute("name", "lsOutput");
        paramElem.setText("native");
        paramsElem.addContent(paramElem);
        metaDataElem.addContent(paramsElem);
        return metaDataElem;
    }

    /**
     * Converts a metadata element to a String
     *
     * @param elem the metadata element to convert to a string
     * @param addData if true then add empty data element
     * @return the metadata and data as a string
     */
    private String requestString(Element metaData, List<Element> data) {
        XMLOutputter xmlOut = new XMLOutputter();
        StringWriter sw = new StringWriter();
        String result = "";

        try {
            xmlOut.output(metaData, sw);
            Element dataElem = new Element("data", this.psNS.NMWG);
            dataElem.setAttribute("metadataIdRef", metaData.getAttributeValue("id"));
            dataElem.setAttribute("id", "data"+dataElem.hashCode());
            if(data != null){
                dataElem.addContent(data);
            }
            xmlOut.output(dataElem, sw);
            result = sw.toString();
        } catch (IOException e) {}

        return result;
    }


    private List<Element> getElementChildren(Element e, String name) {
        ArrayList<Element> filteredChildren = new ArrayList<Element>();

        List<Element> children = e.getChildren();

        for (Element child : children) {
            if (child.getName().equals(name)) {
                filteredChildren.add(child);
            }
        }

        return filteredChildren;
    }

    private class TSClientCallback implements PSMessageEventHandler {
        private Logger log;
        private Element retrievedTopology;
    	private PSNamespaces psNS;

        public TSClientCallback() {
            this.log = Logger.getLogger(this.getClass());
            this.psNS = new PSNamespaces();
        }

        public Element getRetrievedTopology() {
            return this.retrievedTopology;
        }

        public void handleMetadataDataPair(Element metadata, Element data, HashMap <String, Element> metadataMap, String messageType, Object arg) {
            if (messageType.equals("QueryResponse")) {
                Element eventType_elm = metadata.getChild("eventType", this.psNS.NMWG);
                if (eventType_elm == null) {
                    this.log.error("The metadata/data pair doesn't have an event type");
                    return;
                }

                if (!eventType_elm.getValue().equals("http://ggf.org/ns/nmwg/topology/20070809")) {
                    this.log.error("The metadata/data pair has an unknown event type: "+eventType_elm.getValue());
                    return;
                }

                Element topo = data.getChild("topology", this.psNS.TOPO);

                if (topo == null) {
                    this.log.error("No topology located in data");
                    return;
                }

                this.retrievedTopology = topo;
            } else {
                this.log.error("Received a metadata/data pair from an unknown message type: "+messageType);
            }
        }
    }

    private synchronized TSCacheElement getCache(String id, String namespace) {
        if (this.disableCaching == true) {
            this.log.debug("Caching is disabled");
            return null;
        }

        long currentTime = System.currentTimeMillis();

        // clean out the old versions
        Iterator<TSCacheElement> iter = this.cache.iterator();
        while(iter.hasNext()) {
            TSCacheElement elm = iter.next();

            if (currentTime > elm.retrieveTime + this.DOMAIN_CACHE_LENGTH * 1000) {
                this.log.debug("Removing "+elm.id+" from cache");
                iter.remove();
            }
        }
 
        for(TSCacheElement elm : this.cache) {

            if (elm.id.equals(id) == false) {
                continue;
            }

            if (namespace != null && elm.namespace.equals(namespace) == false) {
                continue;
            }

            return elm;
        }

        return null;
    }

    private synchronized void addCache(String id, String namespace, long retrieveTime, String TS, Element topology) {
        if (this.disableCaching == true) {
            this.log.debug("Caching is disabled");
            return;
        }

        this.log.debug("Adding "+id+" to the cache");

        if (namespace == null) {
            // XXX: error
            return;
        }

        TSCacheElement cacheElement = getCache(id, namespace);
        if (cacheElement != null) {
            this.cache.remove(cacheElement);
        }

        cacheElement = new TSCacheElement();
        cacheElement.id = id;
        cacheElement.namespace = namespace;
        cacheElement.retrieveTime = retrieveTime;
        cacheElement.topology = topology;
        cacheElement.TS = TS;

        this.cache.add(cacheElement);
    }

    private class TSCacheElement {
        public String namespace;
        public String id;
        public Element topology;
        public String TS;
        public long retrieveTime;
    }
}
