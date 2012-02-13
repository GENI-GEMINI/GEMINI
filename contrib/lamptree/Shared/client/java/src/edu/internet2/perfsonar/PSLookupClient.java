package edu.internet2.perfsonar;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Random;
import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpException;
import org.apache.commons.httpclient.methods.PostMethod;
import org.jdom.Element;

/**
 * A generic client for sending requests to the Lookup Service.
 */
public class PSLookupClient extends PSBaseClient{
	protected PSNamespaces psNs;
	
	private final String REGISTER_REQ = 
		"<nmwg:message xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"" +
		" xmlns:perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\"" +
		" xmlns:psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\""+
		"<!--namespaces-->" +
		" type=\"<!--type-->\" id=\"<!--msgId-->\">" +
		"<!--body--></nmwg:message>";
	private final String QUERY_REQ = 
		"<nmwg:message xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\"" +
		" xmlns:xquery=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/\"" +
		" type=\"LSQueryRequest\" id=\"<!--msgId-->\">" +
		"<!--body--></nmwg:message>";
	private final String REGISTER_TYPE = "LSRegisterRequest";
	private final String KEEPALIVE_TYPE = "LSKeepaliveRequest";
	private final String DEREGISTER_TYPE = "LSDeregisterRequest";
	
	/**
	 * @param url the URL of the Lookup Service to contact
	 */
	public PSLookupClient(String url) {
		super(url);
		this.psNS = new PSNamespaces();
	}
	
	/**
	 * Sends an LSRegisterRequest to the Lookup Service
	 * 
	 * @param msgBody the metadata and data to send
	 * @param namespaces a map of the namespacs whose keys are the prefix used in msgBody and the value is the namespace location
	 * @return the result of the request as a JDOM element
	 */
	public Element register(String msgBody, HashMap<String, String> namespaces){
		return this.manageRegistration(REGISTER_TYPE, msgBody, namespaces);
	}
	
	/**
	 * Sends an LSKeepaliveRequest to the Lookup Service
	 * 
	 * @param msgBody the metadata and data to send
	 * @param namespaces a map of the namespacs whose keys are the prefix used in msgBody and the value is the namespace location
	 * @return the result of the request as a JDOM element
	 */
	public Element keepAlive(String msgBody, HashMap<String, String> namespaces){
		return this.manageRegistration(KEEPALIVE_TYPE, msgBody, namespaces);
	}
	
	/**
	 * Sends an LSDeregisterRequest to the Lookup Service
	 * 
	 * @param msgBody the metadata and data to send
	 * @param namespaces a map of the namespacs whose keys are the prefix used in msgBody and the value is the namespace location
	 * @return the result of the request as a JDOM element
	 */
	public Element deregister(String msgBody, HashMap<String, String> namespaces){
		return this.manageRegistration(DEREGISTER_TYPE, msgBody, namespaces);
	}
	
	/**
	 * Sends an LSQueryRequest to the lookup service
	 * @param msgBody the query(ies) to send as properly formatted XML
	 * @return the response as a JDOM element
	 */
	public Element query(String msgBody){
		String request = QUERY_REQ;
		String msgId = "message" + msgBody.hashCode() + "-" + System.currentTimeMillis();
		request = request.replaceAll("<!--msgId-->", msgId);
		request = request.replaceAll("<!--body-->", msgBody.replaceAll("[\\$]", "\\\\\\$"));
		return this.sendMessage(request);
	}
	
	private Element manageRegistration(String type, String msgBody, HashMap<String, String> namespaces){
		String request = REGISTER_REQ;
		String msgId = "message" + msgBody.hashCode() + "-" + System.currentTimeMillis();
		request = request.replaceAll("<!--type-->", type);
		
		//Set namespaces
		if(namespaces == null){
			request = request.replaceAll("<!--namespaces-->", "");
		}else{
			String nsStr = "";
			for(String prefix : namespaces.keySet()){
				nsStr += " xmlns:" + prefix + "=\"" + namespaces.get(prefix) + "\"";
			}
			request = request.replaceAll("<!--namespaces-->", nsStr);
		}
		
		//Set message ID and body
		request = request.replaceAll("<!--msgId-->", msgId);
		request = request.replaceAll("<!--body-->", msgBody);
		
		return this.sendMessage(request);
	}
	
	/**
	 * Returns a list of Global Lookup Service instances from a hints file 
	 * at the gievn URL. The hosts are returned in the same order they were 
	 * given in the hints file.
	 * 
	 * @param url the location of the hints file
	 * @return the list of gLS instances in the same order as listed in the hints file
	 * @throws IOException 
	 * @throws HttpException 
	 */
	public static String[] getGlobalHints(String url) throws HttpException, IOException{
		return PSLookupClient.getGlobalHints(url, false);
	}
	
	/**
	 * Returns a list of Global Lookup Service instances from a hints file 
	 * at the given URL. The hosts may be randomly re-ordered depending on
	 * the value of randomOrder.
	 * 
	 * @param url the location of the hints file
	 * @param randomOrder if true then will randomly re-order gLS in hints file, if false then they are returned in the same order as listed in the file
	 * @return the list of gLS instances
	 * @throws IOException 
	 * @throws HttpException 
	 */
	public static String[] getGlobalHints(String url, boolean randomOrder) throws HttpException, IOException{
		String[] glsList = new String[0];
		HttpClient client = new HttpClient();
		PostMethod postMethod = new PostMethod(url);
		
		int status = client.executeMethod(postMethod);
		if(status != 200){
			throw new HttpException("Bad status returned: " + status);
		}
		String response = postMethod.getResponseBodyAsString();
		glsList = response.split("\n");
	
		if(randomOrder){
			ArrayList<String> tmp = new ArrayList<String>();
			Random rand = new Random();
			for(String gls : glsList){ tmp.add(gls); }
			for(int i = glsList.length; i > 0; i--){
				glsList[glsList.length - i] = tmp.remove(rand.nextInt(i));
			}
		}
		return glsList;
	}

	public Element createKeyElem(String key) {
		Element keyElem = new Element("key", this.psNS.NMWG);
		Element params =  new Element("parameters", this.psNS.NMWG);
		Element param =  new Element("parameter", this.psNS.NMWG);
		params.setAttribute("id", "keyParams1");
		param.setAttribute("name", "lsKey");
		param.setText(key);
		params.addContent(param);
		keyElem.addContent(params);
		
		return keyElem;
	}
}
