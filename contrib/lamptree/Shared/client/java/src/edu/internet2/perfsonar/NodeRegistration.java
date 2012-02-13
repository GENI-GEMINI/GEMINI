package edu.internet2.perfsonar;

import java.io.IOException;
import java.io.StringWriter;
import java.util.HashMap;

import org.jdom.Element;
import org.jdom.output.XMLOutputter;

/**
 * Store the details for registering a Node with lookup service
 */
public class NodeRegistration {
	private Element nodeElem;
	private PSNamespaces psNS;
	
	static public final String[] LOCATION_FIELDS = {"country", "zipcode", "state", "institution", 
													"city", "streetAddress", "floor", "room","cage", 
													"rack", "shelf", "latitude", "longitude", 
													"continent"};
	/**
	 * Create a new node registration for a node with the given ID
	 * @param id the ID of the node to register
	 */
	public NodeRegistration(String id){
		this.psNS = new PSNamespaces();
		this.nodeElem = new Element("node", this.psNS.TOPO);
		this.nodeElem.setAttribute("id", id);
	}
	
	/**
	 * Sets the hostname of the node
	 * 
	 * @param name the name to set
	 * @param type the type of name (i.e. 'dns')
	 */
	public void setName(String name, String type){
		Element nameElem = new Element("name", this.psNS.TOPO);
		nameElem.setAttribute("type", type);
		nameElem.setText(name);
		this.nodeElem.addContent(nameElem);
	}
	
	/**
	 * @return the node hostname
	 */
	public String getName(){
		return this.nodeElem.getChildText("name", this.psNS.TOPO);
	}
	
	/**
	 * @return the type of the name
	 */
	public String getNameType(){
		Element nameElem = this.nodeElem.getChild("name", this.psNS.TOPO);
		if(nameElem == null){ return null; }
		return nameElem.getAttributeValue("type");
	}
	
	/** 
	 * Adds a Layer 3 (IP) address in a port to node definition
	 * @param address the address to add
	 * @param ipv6 true if address is IPv6, false otherwise
	 */
	public void setL3Address(String address, boolean ipv6){
		Element portElem = new Element("port", this.psNS.TOPO_L3);
		Element addrElem = new Element("address", this.psNS.TOPO_L3);
		addrElem.setAttribute("type", (ipv6?"ipv6":"ipv4"));
		addrElem.setText(address);
		portElem.addContent(addrElem);	
		this.nodeElem.addContent(portElem);
	}
	
	/** 
	 * Adds location information to the node
	 * 
	 * @param locationInfo a HashMap keyed by field name and value
	 * @return true if location set, false otherwise
	 */
	public boolean setLocation(HashMap<String,String> locationInfo){
		Element locationElem = new Element("location",this.psNS.TOPO);
		boolean result = false;
		for(String key : NodeRegistration.LOCATION_FIELDS){
			if(locationInfo.containsKey(key)){
				Element elem = new Element(key, this.psNS.TOPO);
				elem.setText(locationInfo.get(key));
				locationElem.addContent(elem);
			}
		}
		if(!locationElem.getContent().isEmpty()){
			this.nodeElem.addContent(locationElem);
			result = true;
		}
		
		return result;
	}
	
	/**
	 * @return the JDOM representation of a node registration
	 */
	public Element getNodeElem() {
		return nodeElem;
	}

	/**
	 * @param nodeElem the JDOM representation of this node registration
	 */
	public void setNodeElem(Element nodeElem) {
		this.nodeElem = nodeElem;
	}
	
	/**
	 * Returns the XML representation of this Node registration
	 */
	public String toString(){
		XMLOutputter xmlOut = new XMLOutputter();
		StringWriter sw = new StringWriter();
		String result = "";
		
		try {
			xmlOut.output(this.nodeElem, sw);
			result = sw.toString();
		} catch (IOException e) {}
		
		return result;
	}
}
