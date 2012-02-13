package edu.internet2.perfsonar;

import java.io.IOException;
import java.io.StringWriter;
import java.net.URL;
import java.util.HashMap;
import java.util.List;

import org.jdom.Element;
import org.jdom.JDOMException;
import org.jdom.Namespace;
import org.jdom.output.XMLOutputter;
import org.jdom.xpath.XPath;

/**
 * Stores the details required to register a nmtopo:service with the 
 * lookup service. Also contains convenience methods for retrieving JDOM
 * and String representations of the service element.
 */
public class ServiceRegistration {
	private Element serviceElem;
	private Element optionalParamsElem;
	private PSNamespaces psNS;
	
	final public static String IDC_TYPE = "IDC";
	final public static String NB_TYPE = "NB";
	
	/**
	 * Creates a new service element
	 * 
	 * @param id the urn of the service
	 * @param name the name of the service
	 * @param type the type of service
	 * @param description a description of the service instance
	 */
	public ServiceRegistration(String name, String type){
		this.psNS = new PSNamespaces();
		this.serviceElem = new Element("service", this.psNS.TOPO);
		this.serviceElem.addContent(this.txtNode("name", name, this.psNS.TOPO));
		this.serviceElem.addContent(this.txtNode("type", type, this.psNS.TOPO));
	}

	/**
	 * @return the URN of the service
	 */
	public String getId(){
		return this.serviceElem.getChildText("id", this.psNS.TOPO);
	}
	
	/**
	 * @return the name of the service
	 */
	public String getName(){
		return this.serviceElem.getChildText("name", this.psNS.TOPO);
	}
	
	/**
	 * @return the type of service
	 */
	public String getType(){
		return this.serviceElem.getChildText("type", this.psNS.TOPO);
	}
	
	/**
	 * @return a description of the service
	 */
	public String getDescription(){
		return this.serviceElem.getChildText("type", this.psNS.TOPO);
	}
	
	/**
	 * @param a description of the service
	 */
	public void setDescription(String description){
		this.serviceElem.addContent(this.txtNode("description", description, this.psNS.TOPO));
	}
	
	/**
	 * Sets the node that this service runs on given a URN
	 * @param urn the urn of the node that this services runs on
	 */
	public void setNode(String urn){
		HashMap<String, String> idRef = new HashMap<String, String>();
		idRef.put(urn, "node");
		this.serviceElem.addContent(this.relationNode("runsOn", idRef));
	}
	
	/**
	 * @return the URN of the node that this service runsOn
	 */
	public String getNode(){
		XPath xpath;
		String result = null;
		try {
			xpath = XPath.newInstance("nmtopo:relation[@type='runsOn']");
			xpath.addNamespace(this.psNS.TOPO);
	        Element relElem = (Element) xpath.selectSingleNode(this.serviceElem);
			if(relElem == null){
				return null;
			}
			Element idRef = relElem.getChild("idRef", this.psNS.TOPO);
			if(idRef == null){	
				return null;
			}
			result = idRef.getText();
		} catch (JDOMException e) {
			System.err.println(e.getMessage());
		}
        
		return result;
	}
	
	/**
	 * Sets the list of domains that this service controls
	 * 
	 * @param domains the list of domains this service controls
	 */
	public void setControls(String[] domains){
		HashMap<String, String> idRefs = new HashMap<String, String>();
		for(String domain : domains){
			idRefs.put(domain, "domain");
		}
		this.serviceElem.addContent(this.relationNode("controls", idRefs));
	}
	
	/**
	 * @return the list of domains this service controls
	 */
	public String[] getControls(){
		return this.getRelationRefs("controls");
	}
	
	/**
	 * Sets list of services that subscribe to this service's notifications
	 * @param subscribers the list of services that subscribe to this service's notifications
	 */
	public void setSubscriberRel(String[] subscribers){
		HashMap<String, String> idRefs = new HashMap<String, String>();
		for(String subscriber : subscribers){
			String type = "uri";
			try{
				new URL(subscriber);
				type = "url";
			}catch(Exception e){}
			idRefs.put(subscriber, type);
		}
		this.serviceElem.addContent(this.relationNode("subscriber", idRefs));
	}
	
	/**
	 * @return the list of services that subscribe to this service's notifications
	 */
	public String[] getSubscriberRel(){
		return this.getRelationRefs("subscriber");
	}
	
	/**
	 * Sets the list of services that send notifications to this service
	 * 
	 * @param publishers the list of services that send notifications to this service
	 */
	public void setPublisherRel(String[] publishers){
		HashMap<String, String> idRefs = new HashMap<String, String>();
		for(String publisher : publishers){
			String type = "uri";
			try{
				new URL(publisher);
				type = "url";
			}catch(Exception e){}
			idRefs.put(publisher, type);
		}
		this.serviceElem.addContent(this.relationNode("publisher", idRefs));
	}
	
	/**
	 * @return the list of services that send notifications to this service
	 */
	public String[] getPublisherRel(){
		return this.getRelationRefs("publisher");
	}
	
	/**
	 * Adds a port element to this service subscription
	 * 
	 * @param addrs a list of address on the port
	 * @param protocol the protocol spoken on the port
	 * @param params a map of params indexed by parameter type and containing an array of values that have that type
	 */
	public void setPort(String[] addrs, String protocol, HashMap<String, String[]> params){
		Element port = new Element("port", this.psNS.TOPO);
		for(String addr : addrs){
			Element addrElem = new Element("address", this.psNS.TOPO);
			addrElem.setAttribute("type", "url");
			addrElem.setText(addr);
			port.addContent(addrElem);
		}
		
		Element protoElem = new Element("protocol", this.psNS.TOPO);
		protoElem.addContent(this.txtNode("type", protocol, this.psNS.TOPO));
		if(params != null){
		    Element paramsElem = this.createParameters(params);
		    protoElem.addContent(paramsElem);
		}
		port.addContent(protoElem);
		this.serviceElem.addContent(port);
	}
	
	/**
	 * Returns a list of addresses running on a port that speaks a specific protocol
	 * 
	 * @param protocolType the protocol URI to macth
	 * @return the list of addresses running on the matching port
	 */
	public String[] getPortAddresses(String protocolType){
		Element port = this.getPortByProto(protocolType);
		List<Element> addrElems = port.getChildren("address", this.psNS.TOPO);
		if(addrElems == null){ return null; }
		String[] result = new String[addrElems.size()];
		for(int i = 0; i < addrElems.size(); i++){
			result[i] = addrElems.get(i).getText();
		}
		return result;
	}
	
	/**
	 * Returns the list of parameters for a protocol of the specified type
	 * @param protocolType the type of protocol to match
	 * @return the map of parameters indexed by type
	 */
	public HashMap<String,String[]> getProtocolParams(String protocolType){
		Element port = this.getPortByProto(protocolType);
		Element protoElem = port.getChild("protocol", this.psNS.TOPO);
		if(protoElem == null){ return null; }
		Element paramsElem = protoElem.getChild("parameters", this.psNS.TOPO);
		if(paramsElem == null){ return null; }
		HashMap<String,String[] >result = this.createParameterMap(paramsElem);
		return result;
	}
	
	/**
	 * Return the first port object running a specified protocol
	 * 
	 * @param protocolType the protocol type to match
	 * @return the matching port or null if no port matches
	 */
	public Element getPortByProto(String protocolType){
		try {
			XPath xpath = XPath.newInstance("nmtopo:port[nmtopo:protocol[nmtopo:type='" + 
					protocolType + "']]");
			xpath.addNamespace(this.psNS.TOPO);
	        return (Element) xpath.selectSingleNode(this.serviceElem);
		} catch (JDOMException e) {
			System.err.println(e.getMessage());
		}
		
		return null;
	}
	
	/**
	 * Returns a list of services that have a particular relation to this service
	 * @param type the relation type to find
	 * @return the list of services with the given relation. Null if none found.
	 */
	public String[] getRelationRefs(String type){
		String[] result = null;
		try {
			XPath xpath = XPath.newInstance("nmtopo:relation[@type='" + type + "']");
			xpath.addNamespace(this.psNS.TOPO);
	        Element relElem = (Element) xpath.selectSingleNode(this.serviceElem);
			if(relElem == null){
				return null;
			}
			List<Element> idRefs = relElem.getChildren("idRef", this.psNS.TOPO);
			if(idRefs == null || idRefs.size() == 0){	
				return null;
			}
			result = new String[idRefs.size()];
			for(int i = 0; i < result.length; i++){
				result[i] = idRefs.get(i).getText();
			}
		} catch (JDOMException e) {
			System.err.println(e.getMessage());
		}
        
		return result;
	}
	
	/**
	 * Creates a paramter element given a map of parameters
	 * 
	 * @param params the parameters to convert
	 * @return a JDOM element with all the parameters
	 */
	public Element createParameters(HashMap<String, String[]> params){
		Element paramsElem = new Element("parameters", this.psNS.TOPO);
		for(String type : params.keySet()){
			for(String val : params.get(type)){
				Element paramElem = new Element("parameter", this.psNS.TOPO);
				paramElem.setAttribute("name", type);
				paramElem.setText(val);
				paramsElem.addContent(paramElem);
			}
		}
		
		return paramsElem;
	}
	
	/**
	 * Creates a parameter map given a parameter element
	 * @param paramsElem the paramterMap to parse
	 * @return the converted parameter map
	 */
	private  HashMap<String,String[]> createParameterMap(Element paramsElem){
		List<Element> paramElems = paramsElem.getChildren("parameter", this.psNS.TOPO);
		if(paramElems == null){ return null; }
		HashMap<String,String[]> result = new HashMap<String,String[]>();
		for(int i = 0; i < paramElems.size(); i++){
			String type = paramElems.get(i).getAttributeValue("name");
			String[] arr = null;
			if(result.containsKey(type)){
				String[] arrOld = result.get(type);
				arr = new String[arrOld.length + 1];
				System.arraycopy(arrOld, 0, arr, 0, arrOld.length);
			}else{
				arr = new String[1];
			}
			arr[arr.length-1] = paramElems.get(i).getText();
			result.put(type, arr);
		}
		
		return result;
	}
	
	/** 
	 * Sets optional parameters that go after service description but at the end of the subject
	 * 
	 * @param params the parameters map to convert
	 */
	public void setOptionalParameters(HashMap<String, String[]> params){
		this.optionalParamsElem = this.createParameters(params);
	}
	
	/**
	 * @return the map of optional parameters for this service
	 */
	public HashMap<String, String[]> getOptionalParameters(){
		return this.createParameterMap(this.optionalParamsElem);
	}
	
	/** 
	 * Utility method for creating a simple text element
	 * @param name the name of the element
	 * @param value the element text value
	 * @param ns the namespace of the element
	 * @return the text element
	 */
	private Element txtNode(String name, String value, Namespace ns){
		Element elem = new Element(name, ns);
		elem.setText(value);
		return elem;
	}
	
	/**
	 * Adds a relation element
	 * 
	 * @param type the relation type
	 * @param refs a map of each service where the index is the service URL and the value is the type
	 */
	public void addRelation(String type, List<String> relatedTo){
	    HashMap<String, String> refs = new HashMap<String, String>();
	    for(String addr : relatedTo){
	        try{
	            new URL(addr);
	            refs.put(addr, "url");
	        }catch(Exception e){
	            refs.put(addr, "idRef");
	        }
	    }
	    this.serviceElem.addContent(this.relationNode(type, refs));
	}
	
	
	/**
	 * Creates a relation element
	 * 
	 * @param type the relation type
	 * @param refs a map of each service where the index is the service URL and the value is the type
	 * @return a relation element
	 */
	private Element relationNode(String type, HashMap<String, String> refs){
		Element relElem = new Element("relation", this.psNS.TOPO);
		relElem.setAttribute("type", type);
		for(String ref : refs.keySet()){
			Element idRefElem = null;
			if(refs.get(ref).equals("url")){
				idRefElem = new Element("address", this.psNS.TOPO);
			}else{
				idRefElem = new Element("idRef", this.psNS.TOPO);
			}
			idRefElem.setAttribute("type", refs.get(ref));
			idRefElem.setText(ref);
			relElem.addContent(idRefElem);
		}
		return relElem;
	}
	/**
	 * @return the JDOM element of the optional parameters that go at the end of the subject
	 */
	public Element getOptionalParamsElem() {
		return optionalParamsElem;
	}

	/**
	 * @param optionalParamsElem the JDOM element of the optional parameters that go at the end of the subject
	 */
	public void setOptionalParamsElem(Element optionalParamsElem) {
		this.optionalParamsElem = optionalParamsElem;
	}

	/**
	 * @return the JDOM element of the service
	 */
	public Element getServiceElem() {
		return serviceElem;
	}

	/**
	 * @param serviceElem the JDOM element of the service to set
	 */
	public void setServiceElem(Element serviceElem) {
		this.serviceElem = serviceElem;
	}
	
	/** 
	 * Converts service registration to an XML string
	 */
	public String toString(){
		XMLOutputter xmlOut = new XMLOutputter();
		StringWriter sw = new StringWriter();
		String result = "";
		
		try {
			xmlOut.output(this.serviceElem, sw);
			if(this.optionalParamsElem != null){
				xmlOut.output(this.optionalParamsElem, sw);
			}
			result = sw.toString();
		} catch (IOException e) {}
		
		return result;
	}
}
