package edu.internet2.perfsonar.dcn;

import java.io.IOException;
import java.io.StringWriter;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.List;

import org.apache.commons.httpclient.HttpException;
import org.apache.log4j.Logger;
import org.jdom.Element;
import org.jdom.JDOMException;
import org.jdom.Namespace;
import org.jdom.output.XMLOutputter;
import org.jdom.xpath.XPath;

import edu.internet2.perfsonar.NodeRegistration;
import edu.internet2.perfsonar.PSException;
import edu.internet2.perfsonar.PSLookupClient;
import edu.internet2.perfsonar.PSNamespaces;
import edu.internet2.perfsonar.ServiceRegistration;

/**
 * Performs lookup operations useful for dynamic circuits networking (DCN)
 * applications.
 *
 */
public class DCNLookupClient{
    private Logger log;
    private String[] gLSList;
    private String[] hLSList;
    private boolean tryAllGlobal;
    private boolean useGlobalLS;
    private PSNamespaces psNS;
    private Map<String, DCNHostCacheElement> hostCache;
    private Map<String, DCNDomainCacheElement> domainCache;
    private boolean disableCaching;

    private long HOST_CACHE_LENGTH = 86400; // One day
    private long DOMAIN_CACHE_LENGTH = 86400; // One day

    private boolean retryOnKeyNotFound;

    static final public String IDC_SERVICE_TYPE = "IDC";
    static final public String PROTO_OSCARS = "http://oscars.es.net/OSCARS";
    static final public String PROTO_WSN = "http://docs.oasis-open.org/wsn/b-2";
    static final public String PROTO_WSNB = "http://docs.oasis-open.org/wsn/br-2";
    static final public String PARAM_SUPPORTED_MSG = "keyword:supportedMessage";
    static final public String PARAM_TOPIC = "keyword:topic";

    private String DISC_XQUERY =
        "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n" +
        "declare namespace summary=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/summarization/2.0/\";\n" +
        "declare namespace perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\";\n" +
        "declare namespace psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\";\n" +
        "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n" +
        "for $metadata in /nmwg:store[@type=\"LSStore\"]/nmwg:metadata\n" +
        "    let $metadata_id := $metadata/@id  \n" +
        "    let $data := /nmwg:store[@type=\"LSStore\"]/nmwg:data[@metadataIdRef=$metadata_id]\n" +
        "    where $data/nmwg:metadata/nmwg:eventType[text()=\"http://oscars.es.net/OSCARS\"] and $data/nmwg:metadata/summary:subject/<!--addrPath-->[@type=\"<!--type-->\" and text()=\"<!--domain-->\"]\n" +
        "    return $metadata/perfsonar:subject/psservice:service/psservice:accessPoint\n";

    private String HOST_XQUERY =
        "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n" +
        "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n" +
        "/nmwg:store[@type=\"LSStore\"]/nmwg:data/nmwg:metadata/*[local-name()=\"subject\"]/nmtb:node/nmtb:relation/nmtb:linkIdRef/text()[../../../nmtb:address[text()=\"<!--hostname-->\"]]\n";

    private String NODE_XQUERY =
        "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n" +
        "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n" +
        "declare namespace nmtl3=\"http://ogf.org/schema/network/topology/l3/20070828/\";\n" +
        "/nmwg:store[@type=\"LSStore\"]/nmwg:metadata/*[local-name()=\"subject\"]/nmtb:node[./<!--type-->[text()=\"<!--addr-->\"]]\n";

    private String SERV_REL_XQUERY =
        "declare namespace nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\";\n" +
        "declare namespace nmtb=\"http://ogf.org/schema/network/topology/base/20070828/\";\n" +
        "declare namespace dcn=\"http://ggf.org/ns/nmwg/tools/org/dcn/1.0/\";\n" +
        "for $metadata in /nmwg:store[@type=\"LSStore\"]/nmwg:metadata\n" +
        "    where ($metadata/*[local-name()=\"subject\"]/nmtb:service/nmtb:type[text()=\"<!--type-->\"] and $metadata/*[local-name()=\"subject\"]/nmtb:service/nmtb:relation[@type=\"<!--relation-->\"]/nmtb:<!--idType-->[text()=\"<!--id-->\"])<!--where-->\n" +
        "    return $metadata/*[local-name()=\"subject\"]/nmtb:service<!--xpath-->\n";

    private String SUPP_MSG_WHERE = " or \\$metadata/*[local-name()=\"subject\"]/" +
            "nmtb:service[nmtb:type[text()=\"IDC\"]]/nmtb:port[nmtb:address[text()=\"<!--addr-->\"]]" +
            "/nmtb:protocol/nmtb:parameters/nmtb:parameter[@name=\"keyword:supportedMessage\" and " +
            "text()=\"http://docs.oasis-open.org/wsn/b-2#Subscribe\"]";

    /**
     * Creates a new client with the list of Global lookup services to
     * contact determined by reading the hints file at the provided URL.
     * The result returned by the list file will be randomly re-ordered.
     *
     * @param hintsFile the URL of the hints file to use to populate the list of global lookup services
     * @throws HttpException
     * @throws IOException
     */
    public DCNLookupClient(String hintsFile) throws HttpException, IOException {
        this.log = Logger.getLogger(this.getClass());
        String[] gLSList = PSLookupClient.getGlobalHints(hintsFile, true);
        this.gLSList = gLSList;
        this.hLSList = null;
        this.tryAllGlobal = false;
        this.useGlobalLS = true;
        this.retryOnKeyNotFound = false;
        this.psNS = new PSNamespaces();
        this.hostCache = new HashMap<String, DCNHostCacheElement>();
        this.domainCache = new HashMap<String, DCNDomainCacheElement>();
        this.disableCaching = false;
    }

    /**
     * Creates a new client with the list of Global lookup services to
     * contact determined by reading the hints file at the provided URL.
     * The result returned by the list file will be randomly re-ordered.
     * All registration requests will use the home lookup services listed
     * in the second parameter
     *
     * @param hintsFile the URL of the hints file to use to populate the list of global lookup services
     * @param hLSList the list of home lookup services to which to send register requests
     * @throws HttpException
     * @throws IOException
     */
    public DCNLookupClient(String hintsFile, String[] hLSList) throws HttpException, IOException {
        this.log = Logger.getLogger(this.getClass());
        String[] gLSList = PSLookupClient.getGlobalHints(hintsFile, true);
        this.gLSList = gLSList;
        this.hLSList = hLSList;
        this.tryAllGlobal = false;
        this.useGlobalLS = true;
        this.retryOnKeyNotFound = false;
        this.psNS = new PSNamespaces();
        this.hostCache = new HashMap<String, DCNHostCacheElement>();
        this.domainCache = new HashMap<String, DCNDomainCacheElement>();
        this.disableCaching = false;
    }

    /**
     * Creates a new client that uses the explicitly set list of global lookup
     * services.
     *
     * @param gLSList
     */
    public DCNLookupClient(String[] gLSList){
        this.log = Logger.getLogger(this.getClass());
        this.gLSList = gLSList;
        this.hLSList = null;
        this.useGlobalLS = true;
        this.tryAllGlobal = false;
        this.retryOnKeyNotFound = false;
        this.psNS = new PSNamespaces();
        this.hostCache = new HashMap<String, DCNHostCacheElement>();
        this.domainCache = new HashMap<String, DCNDomainCacheElement>();
        this.disableCaching = false;
    }

    /**
     * Creates a new client with an explicitly set list of global and/or
     * home lookup services. One of the parameters may be null. If the first
     * parameter is null then no global lookup services will be contacted
     * only the given home lookup services will be used. If the second parameter is
     * null the given set of global lookup services will be used to find the home
     * lookup service.
     *
     * @param gLSList the list of global lookup services to use
     * @param hLSList the list of home lookup services to use
     */
    public DCNLookupClient(String[] gLSList, String[] hLSList){
        this.log = Logger.getLogger(this.getClass());
        this.gLSList = gLSList;
        this.hLSList = hLSList;
        this.useGlobalLS = true;
        this.tryAllGlobal = false;
        this.retryOnKeyNotFound = false;
        this.psNS = new PSNamespaces();
        this.hostCache = new HashMap<String, DCNHostCacheElement>();
        this.domainCache = new HashMap<String, DCNDomainCacheElement>();
        this.disableCaching = false;
    }

    /**
     * Finds the URN of a host with the given name.
     *
     * @param name the name of the host o lookup
     * @return the URN of the host with the given name
     * @throws PSException
     */
    public String lookupHost(String name) throws PSException{
        long currentTime = System.currentTimeMillis();
        DCNHostCacheElement hostCacheElement = this.getHostCache(name);
        if (hostCacheElement != null) {
            if (currentTime <= (hostCacheElement.retrieveTime + this.HOST_CACHE_LENGTH * 1000)) {
                this.log.debug("Using name cache for " + name);
                return hostCacheElement.urn;
            }
        }

        String domain = name.replaceFirst(".+?\\.", "");

        String[] hLSMatches = null;

        DCNDomainCacheElement domainCacheElement = this.getDomainCache(domain);
        if (domainCacheElement != null && currentTime <= (domainCacheElement.retrieveTime + this.DOMAIN_CACHE_LENGTH * 1000)) {
            this.log.debug("Using domain cache for " + domain);
            hLSMatches = domainCacheElement.hLSs;
        } else {
            List<String> hlsMatchList = new ArrayList<String>();
            String[] glsResults = new String[0];
            if (this.usesGlobalLS()){
                String discoveryXQuery = DISC_XQUERY;
                discoveryXQuery = discoveryXQuery.replaceAll("<!--addrPath-->", "nmtb:domain/nmtb:name");
                discoveryXQuery = discoveryXQuery.replaceAll("<!--domain-->", domain);
                discoveryXQuery = discoveryXQuery.replaceAll("<!--type-->", "dns");
                Element discReqElem = this.createQueryMetaData(discoveryXQuery);
                try{
                    glsResults = this.discover(this.requestString(discReqElem, null));
                }catch(Exception e){
                    this.log.debug(e.getMessage());
                }
            }
            
            hLSMatches = this.getHLSMatches(glsResults);
        }

        if (hLSMatches != null) {
            for(String hLS : hLSMatches){
                String urn = this.lookupHostQueryHLS(hLS, name);
                if (urn != null) {
                    this.addHostCache(name, currentTime, hLS, urn);
                    return urn;
                }
            }
        }

        throw new PSException("Couldn't find a mapping for "+domain);
    }

    private String lookupHostQueryHLS(String hLS, String name) throws PSException{
        this.log.debug("hLS: " + hLS);

        String xquery = HOST_XQUERY;
        xquery = xquery.replaceAll("<!--hostname-->", name);
        Element reqElem = this.createQueryMetaData(xquery);
        String request = this.requestString(reqElem, null);

        PSLookupClient lsClient = new PSLookupClient(hLS);
        Element response = lsClient.query(request);
        Element datum = lsClient.parseDatum(response, psNS.PS_SERVICE);
        if(datum != null && datum.getText() != null && datum.getText().equals("") == false){
            return datum.getText();
        }

        return null;
    }

    /**
     * Finds the URN of a host with the given name.
     *
     * @param name the name of the host o lookup
     * @return the nmtb:node element
     * @throws PSException
     */
    public Element lookupNode(String addr) throws PSException{
        Element node = null;
        String[] hLSMatches = new String[0];

        String addrPath = "nmtl3:network/nmtl3:subnet/nmtl3:address";
        String type = "nmtl3:port/nmtl3:address";
        String typeAttr = "ipv4";
        String domain = addr;
        if(addr.matches(".*\\.[a-zA-Z]+.*")){
            type = "nmtb:name";
            addrPath = "nmtb:domain/nmtb:name";
            typeAttr = "dns";
            domain = domain.replaceFirst(".+?\\.", "");
        }
        
        String[] glsResults = new String[0];
        if (this.usesGlobalLS()){
            String discoveryXQuery = DISC_XQUERY;
            discoveryXQuery = discoveryXQuery.replaceAll("<!--addrPath-->", addrPath);
            discoveryXQuery = discoveryXQuery.replaceAll("<!--domain-->", domain);
            discoveryXQuery = discoveryXQuery.replaceAll("<!--type-->", typeAttr);
            Element discReqElem = this.createQueryMetaData(discoveryXQuery);
            try{
                glsResults = this.discover(this.requestString(discReqElem, null));
            }catch(Exception e){
                this.log.debug(e.getMessage());
            }
        }
        hLSMatches = this.getHLSMatches(glsResults);
        
        String xquery = NODE_XQUERY;

        xquery = xquery.replaceAll("<!--addr-->", addr);
        xquery = xquery.replaceAll("<!--type-->", type);
        Element reqElem = this.createQueryMetaData(xquery);
        String request = this.requestString(reqElem, null);
        for(String hLS : hLSMatches){
            this.log.debug("hLS: " + hLS);
            PSLookupClient lsClient = new PSLookupClient(hLS);
            Element response = lsClient.query(request);
            Element datum = lsClient.parseDatum(response, psNS.PS_SERVICE);
            if(datum != null && datum.getChild("node", this.psNS.TOPO) != null){
                node = datum.getChild("node", this.psNS.TOPO);
                break;
            }
        }

        return node;
    }

    /**
     * Retrieve a service element describing an IDC given a domain it controls
     *
     * @param domain the domain as a URN or DNS name that the IDC controls
     * @return the &lt;service&gt; as a JDOM Element, null if not found
     * @throws PSException
     */
    public Element lookupIDC(String domain) throws PSException{
        Element datum = this.lookupService("IDC", domain, "controls", "", "");
        if(datum == null){ return null; }
        Element idc = datum.getChild("service", this.psNS.TOPO);
        return idc;
    }

    /**
     * Retrieves a list of URLs associated with an IDC given the domain
     * @param domain the domain as a URN or DNS name
     * @return a list of URLs associated with the IDC, null if none found
     * @throws PSException
     */
    public String[] lookupIDCUrl(String domain) throws PSException{
        HashMap<String,Boolean> urls = new HashMap<String,Boolean>();
        Element datum = this.lookupService("IDC", domain, "controls", "", "/nmtb:port/nmtb:address[@type=\"url\"]");
        if(datum == null){ return null; }
        List<Element> addrElems = datum.getChildren("address", this.psNS.TOPO);
        if(addrElems == null){ return null; }
        for(Element addrElem : addrElems){
            String key = addrElem.getText();
            if(key == null){ continue; }
            urls.put(key.trim(), true);
        }
        if(urls.size() == 0){ return null; }

        return urls.keySet().toArray(new String[urls.size()]);
    }

    /**
     * Retrieve a service element describing an NB given its URL
     *
     * @param idcUrl the URL of a publishing IDC
     * @return the &lt;service&gt; as a JDOM Element, null if not found
     * @throws PSException
     */
    public Element lookupNB(String idcUrl) throws PSException{
        String where = SUPP_MSG_WHERE.replaceAll("<!--addr-->", idcUrl);
        Element datum = this.lookupService("NB", idcUrl, "subscriber", where, "");
        if(datum == null){ return null; }
        Element idc = datum.getChild("service", this.psNS.TOPO);
        return idc;
    }

    /**
     * Retrieve a list of URLs that accept notification subscriptions for the IDC at
     * the given URL
     *
     * @param idcUrl the URL of a publishing IDC
     * @return an array of the URLs where clients can subscribe to notifications
     * @throws PSException
     */
    public String[] lookupNBUrl(String idcUrl) throws PSException{
        HashMap<String,Boolean> urls = new HashMap<String,Boolean>();
        String where = SUPP_MSG_WHERE.replaceAll("<!--addr-->", idcUrl);
        Element datum = this.lookupService("NB", idcUrl, "subscriber", where, "/nmtb:port/nmtb:address[@type=\"url\"]");
        if(datum == null){ return null; }
        List<Element> addrElems = datum.getChildren("address", this.psNS.TOPO);
        if(addrElems == null){ return null; }
        for(Element addrElem : addrElems){
            String key = addrElem.getText();
            if(key == null){ continue; }
            urls.put(key.trim(), true);
        }
        if(urls.size() == 0){ return null; }

        return urls.keySet().toArray(new String[urls.size()]);
    }

    /**
     * General method used to find a service such as an IDC or NotificationBroker
     *
     * @param type the type of service to find
     * @param domain the domain of the service of interest
     * @param relation the relation of the service to that domain
     * @param xpath an xpath expression rooted at service that control what is returned
     * @return the element found (if any)
     * @throws PSException
     */
    public Element lookupService(String type, String id, String relation, String where, String xpath) throws PSException{
        this.log.debug("lookupIDC.id=" + id);
        String[] hLSMatches = new String[0];
        Element datum = null;
        String[] glsResults =new String[0];
        if(this.usesGlobalLS()){
            String discoveryXQuery = DISC_XQUERY;
            String lookupId = id.replaceAll("urn:ogf:network:domain=", "");
            try{
                URL url = new URL(lookupId);
                if(!lookupId.matches("\\d?\\d?\\d\\.\\d?\\d?\\d\\.\\d?\\d?\\d\\.\\d?\\d?\\d")){
                    lookupId = url.getHost().replaceFirst(".+?\\.", "");
                }
            }catch(Exception e){}
            discoveryXQuery = discoveryXQuery.replaceAll("<!--domain-->", lookupId);
            discoveryXQuery = discoveryXQuery.replaceAll("<!--addrPath-->", "nmtb:domain/nmtb:name");
            discoveryXQuery = discoveryXQuery.replaceAll("<!--type-->", "dns");
            Element discReqElem = this.createQueryMetaData(discoveryXQuery);
            try{
                glsResults = this.discover(this.requestString(discReqElem, null));
            }catch(Exception e){
                this.log.debug(e.getMessage());
            }
        }
        hLSMatches = this.getHLSMatches(glsResults);
        
        String idType = "address";
        if(id.startsWith("urn:ogf:network")){
            idType = "idRef";
        }
        String xquery = SERV_REL_XQUERY;
        xquery = xquery.replaceAll("<!--id-->", id);
        xquery = xquery.replaceAll("<!--type-->", type);
        xquery = xquery.replaceAll("<!--relation-->", relation);
        xquery = xquery.replaceAll("<!--idType-->", idType);
        xquery = xquery.replaceAll("<!--where-->", where);
        xquery = xquery.replaceAll("<!--xpath-->", xpath);

        Element reqElem = this.createQueryMetaData(xquery);
        String request = this.requestString(reqElem, null);
        for(String hLS : hLSMatches){
            this.log.debug("hLS: " + hLS);
            PSLookupClient lsClient = new PSLookupClient(hLS);
            Element response = lsClient.query(request);
            if(response == null){
                this.log.debug("No response returned from "+ hLS);
                continue;
            }
            datum = lsClient.parseDatum(response, psNS.PS_SERVICE);
            Element metaData = response.getChild("metadata", psNS.NMWG);
            if(metaData == null){
                throw new PSException("No metadata element in registration response");
            }
            Element eventType = metaData.getChild("eventType", psNS.NMWG);
            if(eventType == null){
                continue;
            }else if(eventType.getText().startsWith("error.ls")){
                continue;
            }else if(!"success.ls.query".equals(eventType.getText())){
                continue;
            }else if(datum != null){ break; }
        }

        return datum;
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
    public String[] discover(String request) throws PSException{
        String[] accessPoints = null;
        HashMap<String, Boolean> apMap = new HashMap<String, Boolean>();

        String [] gLSs = this.getGLSList();
        if (gLSs == null) {
            throw new PSException("No global lookup services defined");
        }

        int attempts = gLSs.length;
        String errLog = "";
        for(int a = 0; a < attempts; a++){
            try{
                PSLookupClient lsClient = new PSLookupClient(gLSs[a]);
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
                if(this.isTryAllGlobal() == false){
                    break;
                }
            }catch(PSException e){
                errLog += gLSs[a] + ": " + e.getMessage() + "\n\n";
            }catch(Exception e){
                errLog += gLSs[a] + ": " + e.getMessage() + "\n\n";
            }
        }

        if(apMap.isEmpty()){
            throw new PSException("No home lookup services found after trying" +
                    " multiple global services:\n" + errLog);
        }

        accessPoints = new String[apMap.size()];
        apMap.keySet().toArray(accessPoints);

        return accessPoints;
    }

    /**
     * Registers a "Node" element with the lookup service
     *
     * @param reg a NodeRegistration object with the information to register
     * @return a HashMap indexed by each home LS contacted and containing the key returned by each
     * @throws PSException
     */
    public HashMap<String,String> registerNode(NodeRegistration reg) throws PSException{
        return this.registerNode(reg, null);
    }

    /**
     * Registers a "Node" element with the lookup service using the given set of keys
     *
     * @param reg a NodeRegistration object with the information to register
     * @param keys a HashMap indexed by URL of the keys to use when registering data
     * @return a HashMap indexed by each home LS contacted and containing the key returned by each
     * @throws PSException
     */
    public HashMap<String,String> registerNode(NodeRegistration reg, HashMap<String, String> keys) throws PSException{
        Element subjElem = new Element("subject", this.psNS.DCN);
        subjElem.setAttribute("id", "subj"+System.currentTimeMillis());
        subjElem.addContent(reg.getNodeElem());
        return this.register(subjElem, keys);
    }

    /**
     * Registers a service such as an IDC or NotificationBroker with the lookup service
     *
     * @param reg a ServiceRegistration object with the details to register
     * @return a HashMap indexed by each home LS contacted and containing the key returned by each
     * @throws PSException
     */
    public HashMap<String,String> registerService(ServiceRegistration reg) throws PSException{
        return this.registerService(reg, null);
    }

    /**
     * Registers a service such as an IDC or NotificationBroker with the lookup service
     *
     * @param reg a ServiceRegistration object with the details to register
     * @param keys a HashMap indexed by URL of the keys to use when registering data
     * @return a HashMap indexed by each home LS contacted and containing the key returned by each
     * @throws PSException
     */
    public HashMap<String,String> registerService(ServiceRegistration reg, HashMap<String, String> keys) throws PSException{
        Element subjElem = new Element("subject", this.psNS.DCN);
        subjElem.setAttribute("id", "subj"+System.currentTimeMillis());
        subjElem.addContent(reg.getServiceElem());
        if(reg.getOptionalParamsElem() != null){
            subjElem.addContent(reg.getOptionalParamsElem());
        }

        return this.register(subjElem, keys);
    }

    /**
     * General registration method that handles creating the top-level metadata and data
     * and inserts the given metadata to register and an empty data element into the
     * top-level structure.
     *
     * @param metaDataElem the metaData to register
     * @return a HashMap indexed by each home LS contacted and containing the key returned by each
     * @throws PSException
     */
    private HashMap<String, String> register(Element subjElem, HashMap<String, String> keys) throws PSException{
        String [] hLSs = this.getHLSList();

        if(hLSs == null){
            throw new PSException("No home lookup services specified!");
        }
        if(keys == null){
            keys = new HashMap<String,String>();
        }

        for(String hLS : hLSs){
            PSLookupClient lsClient = new PSLookupClient(hLS);
            Element metaDataElem = this.createMetaData(null);
            metaDataElem.addContent(subjElem);
            if(keys.containsKey(hLS)){
                metaDataElem.addContent(0, lsClient.createKeyElem(keys.get(hLS)));
            }
            String request = this.requestString(metaDataElem, null);
            Element response = lsClient.register(request, null);
            Element metaData = response.getChild("metadata", psNS.NMWG);
            if(metaData == null){
                throw new PSException("No metadata element in registration response");
            }
            Element eventType = metaData.getChild("eventType", psNS.NMWG);
            if(eventType == null){
                throw new PSException("No eventType returned");
            }

            //Try again without the key
            if((eventType.getText().equals("error.ls.register.key_not_found")) &&
                    this.retryOnKeyNotFound){
                metaDataElem.removeContent(0);
                request = this.requestString(metaDataElem, null);
                response = lsClient.register(request, null);
                metaData = response.getChild("metadata", psNS.NMWG);
                if(metaData == null){
                    throw new PSException("No metadata element in registration response");
                }
               eventType = metaData.getChild("eventType", psNS.NMWG);
                if(eventType == null){
                    throw new PSException("No eventType returned");
                }
            }
            if(eventType.getText().startsWith("error.ls")){
                Element errDatum = lsClient.parseDatum(response, psNS.NMWG_RESULT);
                String errMsg = (errDatum == null ? "An unknown error occurred" : errDatum.getText());
                this.log.error(eventType.getText() + ": " + errMsg);
                throw new PSException("Registration error: " + errMsg);
            }else if(!"success.ls.register".equals(eventType.getText())){
                throw new PSException("Registration returned an unrecognized status");
            }

            //Get keys
            XPath xpath;
            try {
                xpath = XPath.newInstance("nmwg:metadata/nmwg:key/nmwg:parameters/nmwg:parameter[@name='lsKey']");
                xpath.addNamespace(psNS.NMWG);
                Element keyParam = (Element) xpath.selectSingleNode(response);
                if(keyParam == null){
                    throw new PSException("No key in the response");
                }
                keys.put(hLS, keyParam.getText());
                this.log.debug(hLS +"="+keyParam.getText());
            } catch (JDOMException e) {
                this.log.error(e);
                throw new PSException(e);
            }
        }

        return keys;
    }

    public void deregister(String key) throws PSException{
        String [] hLSs = this.getHLSList();

        if(hLSs == null){
            throw new PSException("No home lookup services specified!");
        }

        Element metaDataElem = this.createMetaData(null);
        Element keyElem = new Element("key", this.psNS.NMWG);
        Element paramsElem = new Element("parameters", this.psNS.NMWG);
        Element paramElem = new Element("parameter", this.psNS.NMWG);

        keyElem.setAttribute("id", "k"+key.hashCode());
        paramsElem.setAttribute("id", "p"+key.hashCode());
        paramElem.setAttribute("name", "lsKey");
        paramElem.setText(key);
        paramsElem.addContent(paramElem);
        keyElem.addContent(paramsElem);
        metaDataElem.addContent(keyElem);
        for(String hLS : hLSs){
            String request = this.requestString(metaDataElem, null);
            PSLookupClient lsClient = new PSLookupClient(hLS);
            Element response = lsClient.deregister(request, null);
            Element metaData = response.getChild("metadata", psNS.NMWG);
            if(metaData == null){
                throw new PSException("No metadata element in deregistration response");
            }
            Element eventType = metaData.getChild("eventType", psNS.NMWG);
            if(eventType == null){
                throw new PSException("No eventType returned");
            }else if(eventType.getText().startsWith("error.ls")){
                Element errDatum = lsClient.parseDatum(response, psNS.NMWG_RESULT);
                String errMsg = (errDatum == null ? "An unknown error occurred" : errDatum.getText());
                this.log.error(eventType.getText() + ": " + errMsg);
                throw new PSException("Deregistration error: " + errMsg);
            }else if(!"success.ls.deregister".equals(eventType.getText())){
                throw new PSException("Registration returned an unrecognized status");
            }
        }
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

    /**
     * @return true if uses global LS to discover hLS for queries
     */
    public synchronized boolean usesGlobalLS() {
        return useGlobalLS;
    }

    /**
     * @param useGlobalLS true if uses global LS to discover hLS for queries
     */
    public synchronized void setUseGlobalLS(boolean useGlobalLS) {
        this.useGlobalLS = useGlobalLS;
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
            subjElem.setAttribute("id", "subj"+System.currentTimeMillis());
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

    /**
     * @return boolean value indicating if register requests using keys will retry without a key after 'error.ls.register.key_not_found' event
     */
    public synchronized boolean getRetryOnKeyNotFound() {
        return retryOnKeyNotFound;
    }

    /**
     * @param retryOnKeyNotFound value indicating if register requests using keys will retry without a key after 'error.ls.register.key_not_found' event
     */
    public synchronized void setRetryOnKeyNotFound(boolean retryOnKeyNotFound) {
        this.retryOnKeyNotFound = retryOnKeyNotFound;
    }

    /**
     * @return the psNS
     */
    public PSNamespaces getPsNS() {
        return psNS;
    }

    /**
     * @param psNS the psNS to set
     */
    public void setPsNS(PSNamespaces psNS) {
        this.psNS = psNS;
    }

    public void setDisableCaching(boolean disabled) {
        this.disableCaching = disabled;
    }

    private synchronized DCNHostCacheElement getHostCache(String id) {
        if (this.disableCaching)
            return null;

        return this.hostCache.get(id);
    }

    private String[] getHLSMatches(String[] glsResults){
        String[] hLSMatches = new String[0];
        List<String> hlsMatchList = new ArrayList<String>();
        for(String gLSResult : glsResults){
            this.log.debug("adding " + gLSResult);
            hlsMatchList.add(gLSResult);
        }
        //add all home LSs as backup
        if(this.hLSList != null){
            for(String hLS : this.hLSList){
                this.log.debug("adding " + hLS);
                if(!hlsMatchList.contains(hLS)){
                    hlsMatchList.add(hLS);
                }
            }
        }
        if(!hlsMatchList.isEmpty()){
            hLSMatches = hlsMatchList.toArray(new String[hlsMatchList.size()]);
        }
        
        return hLSMatches;
    }
    private synchronized void addHostCache(String name, long retrieveTime, String hLS, String urn) {
        if (this.disableCaching)
            return;

        DCNHostCacheElement cacheElement = cacheElement = new DCNHostCacheElement(); 

        cacheElement.name = name;
        cacheElement.retrieveTime = retrieveTime;
        cacheElement.urn = urn;
        cacheElement.hLS = hLS;

        this.hostCache.put(name, cacheElement);
    }

    private class DCNHostCacheElement {
        public String name;
        public String hLS;
        public Long retrieveTime;
        public String urn;
    }

    private synchronized DCNDomainCacheElement getDomainCache(String id) {
        if (this.disableCaching)
            return null;

        return this.domainCache.get(id);
    }

    private synchronized void addDomainCache(String name, long retrieveTime, String [] hLSs) {
        if (this.disableCaching)
            return;

        DCNDomainCacheElement cacheElement = new DCNDomainCacheElement(); 

        cacheElement.name = name;
        cacheElement.retrieveTime = retrieveTime;
        cacheElement.hLSs = hLSs;

        this.domainCache.put(name, cacheElement);
    }

    private class DCNDomainCacheElement {
        public String name;
        public String [] hLSs;
        public Long retrieveTime;
    }
}
