package edu.internet2.perfsonar;

import java.util.*;
import java.io.*;

import org.apache.log4j.*;

import org.jdom.*;
import org.jdom.input.SAXBuilder;

import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.methods.PostMethod;
import org.apache.commons.httpclient.methods.StringRequestEntity;

import java.lang.Exception;

public class PSBaseClient {
    protected String url;
    protected Logger log;
    protected PSNamespaces psNS;
    
    public PSBaseClient(String url) {
        this.url = url;
        this.log = Logger.getLogger(this.getClass());
        this.psNS = new PSNamespaces();
    }

    private String addSoapEnvelope(String request) {
        String ret_request =
            "<?xml version='1.0' encoding='UTF-8'?>" +
            "<SOAP-ENV:Envelope xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" " +
            "     xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" " +
            "     xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" " +
            "     xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"> " +
            "    <SOAP-ENV:Header/> "+
            "    <SOAP-ENV:Body> "+
            request +
            "</SOAP-ENV:Body>" +
            "</SOAP-ENV:Envelope>";

        return ret_request;
    }

    public void sendMessage_CB(String request, PSMessageEventHandler ev, Object arg) {
        Element message = null;

        message = this.sendMessage(request);
        if (message != null)
            this.parseMessage(message, ev, arg);
    }

    public Element sendMessage(String request) {
        Element message = null;

        this.log.debug("Sending request: "+request);

        if (request.indexOf("SOAP-ENV") == -1) {
            request = this.addSoapEnvelope(request);
        }

        //Generate and send response
        try {
            SAXBuilder xmlParser = new SAXBuilder();

            this.log.debug("Connecting to "+this.url);
            PostMethod postMethod = new PostMethod(this.url);
            StringRequestEntity entity = new StringRequestEntity(request, "text/xml",null);
            postMethod.setRequestEntity(entity);

            HttpClient client = new HttpClient();

            this.log.debug("Sending post");
            int statusCode = client.executeMethod(postMethod);
            this.log.debug("Post done");

            String response = postMethod.getResponseBodyAsString();
            ByteArrayInputStream in = new ByteArrayInputStream(response.getBytes());
            this.log.debug("Received response: "+response);
            this.log.debug("Parsing start");
            Document responseMessage = xmlParser.build(in);
            this.log.debug("Parsing done");

            this.log.debug("Looking for message");

	    Iterator messages = responseMessage.getRootElement().getDescendants(new org.jdom.filter.ElementFilter("message"));
	    while(messages.hasNext()) {
		    message = (Element) messages.next();
            }
        } catch (Exception e) {
            this.log.error("Error: " + e.getMessage());
        }

        if (message == null) {
            this.log.debug("No message in response");
        }

        return message;
    }
    
    public HashMap <String, Element> createMetaDataMap(List<Element> metadata_elms){
    	HashMap <String, Element> metadataMap = new HashMap<String, Element>();

        for (Element metadata : metadata_elms) {
            String md_id = metadata.getAttributeValue("id");
            if (md_id == null)
                continue;

            metadataMap.put(md_id, metadata);
        }
        
        return metadataMap;
    }
    
    public void parseMessage(Element message, PSMessageEventHandler ev, Object arg) {
        this.log.debug("Looking for metadata");

        String messageType = message.getAttributeValue("type");
        if (messageType == null) {
            messageType = "";
        }
        
        List<Element> metadata_elms = message.getChildren("metadata", psNS.NMWG);
        HashMap <String, Element> metadataMap = this.createMetaDataMap(metadata_elms);

        for (Element metadata : metadata_elms) {
            String md_id = metadata.getAttributeValue("id");
            if (md_id == null)
                continue;

            List<Element> data_elms = message.getChildren("data", psNS.NMWG);
            for (Element data : data_elms) {
                String md_idRef = data.getAttributeValue("metadataIdRef");

                if (md_idRef.equals(md_id) == false) {
                    this.log.debug("metadata: "+md_id+" data_mdIdref: "+md_idRef);
                    continue;
                }

                ev.handleMetadataDataPair(metadata, data, metadataMap, messageType, arg);
            }
        }
    }
    
    public Element parseDatum(Element message, Namespace ns) throws PSException{
        if(message == null){
            return null;
        }
    	Element data = message.getChild("data", psNS.NMWG);
    	if(data == null){
    		return null;
    	}
    	Element datum = data.getChild("datum", ns);
    	return datum;
     }
}
