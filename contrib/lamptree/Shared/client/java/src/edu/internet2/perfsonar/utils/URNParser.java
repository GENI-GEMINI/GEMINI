package edu.internet2.perfsonar.utils;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Hashtable;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class URNParser {
      /**
     * This method parses a topology identifier and returns useful information
     * in a hashtable. The hash keys are as follows:
     * type: one of "domain", "node", "port", "link", "ipv4address", "ipv6address", "unknown"
     *
     * domainId: the domain id component (if it exists)
     * nodeValue: the node id component (if it exists)
     * portValue: the port id component (if it exists)
     * linkValue: the link id component (if it exists)
     *
     * fqti: the fully qualified topology identifier (if applicable)
     *
     * @param topoIdent the topology identifier to parse
     * @return a Hashtable with the parse results
     */
    public static Hashtable<String, String> parseTopoIdent(String topoIdent) {


        topoIdent = topoIdent.trim();

        Hashtable<String, String> regexps = new Hashtable<String, String>();
        regexps.put("domainFull", "^urn:ogf:network:domain=([^:]+)$");
        regexps.put("domain", "^urn:ogf:network:([^:=]+)$");

        regexps.put("nodeFull", "^urn:ogf:network:domain=([^:]+):node=([^:]+)$");
        regexps.put("node", "^urn:ogf:network:([^:=]+):([^:=]+)$");

        regexps.put("portFull", "^urn:ogf:network:domain=([^:]+):node=([^:]+):port=([^:]+)$");
        regexps.put("port", "^urn:ogf:network:([^:=]+):([^:=]+):([^:=]+)$");

        regexps.put("linkFull", "^urn:ogf:network:domain=([^:]+):node=([^:]+):port=([^:]+):link=([^:]+)$");
        regexps.put("link", "^urn:ogf:network:([^:=]+):([^:=]+):([^:=]+):([^:=]+)$");

        String domainValue = "";
        String nodeValue = "";
        String portValue = "";
        String linkValue = "";

        String matched = null;

        Matcher matcher = null;


        for (String key: regexps.keySet()) {
            Pattern p = Pattern.compile(regexps.get(key));
            matcher = p.matcher(topoIdent);
            if (matcher.matches()) {
                if (key.equals("domain") || key.equals("domainFull")) {
                    matched = "domain";
                    domainValue = matcher.group(1);
                } else if (key.equals("node") || key.equals("nodeFull") ) {
                    matched = "node";
                    domainValue = matcher.group(1);
                    nodeValue = matcher.group(2);
                } else if (key.equals("port") || key.equals("portFull") ) {
                    matched = "port";
                    domainValue = matcher.group(1);
                    nodeValue = matcher.group(2);
                    portValue = matcher.group(3);
                } else if (key.equals("link") || key.equals("linkFull") ) {
                    matched = "link";
                    domainValue = matcher.group(1);
                    nodeValue = matcher.group(2);
                    portValue = matcher.group(3);
                    linkValue = matcher.group(4);
                }
            }
        }

//    	TODO: make a class for the results?
        Hashtable<String, String> result = new Hashtable<String, String>();

        if (topoIdent == null || topoIdent.equals("")) {
            result.put("type", "empty");
            return result;
        }

        String compactForm = null;
        String realCompactForm = null;
        String fqti = null;
        String addressType = "";
        
        if(matched == null){
            try {
                InetAddress[] addrs = InetAddress.getAllByName(topoIdent);
                 for (int i =0; i < addrs.length;i++){
                     addressType = addrs[i].getClass().getName();
                 }
    
                 if (addressType.equals("java.net.Inet6Address")) {
                     addressType = "ipv6address";
                 } else if (addressType.equals("java.net.Inet4Address")) {
                     addressType = "ipv4address";
                 } else {
                     addressType = "unknown";
                 }
                 result.put("type", addressType);
                 matched = "address";
             } catch(UnknownHostException e){
                 if (matched == null) {
                    result.put("type", "unknown");
                    return result;
                 }
             }
        }else if (matched.equals("domain")) {
            String domainFqti = "urn:ogf:network:domain="+domainValue;
            compactForm = "urn:ogf:network:"+domainValue;
            realCompactForm = domainValue;
            result.put("realcompact", realCompactForm);
            result.put("compact", compactForm);
            result.put("type", "domain");
            result.put("fqti", domainFqti);
            result.put("domainValue", domainValue);
            result.put("domainFQID", domainFqti);
        } else if (matched.equals("node")) {
            String domainFqti = "urn:ogf:network:domain="+domainValue;
            String nodeFqti = domainFqti+":node="+nodeValue;
            compactForm = "urn:ogf:network:"+domainValue+":"+nodeValue;
            realCompactForm = domainValue+":"+nodeValue;
            result.put("realcompact", realCompactForm);
            result.put("compact", compactForm);
            result.put("type", "node");
            result.put("fqti", nodeFqti);
            result.put("domainValue", domainValue);
            result.put("nodeValue", nodeValue);
            result.put("nodeFQID", nodeFqti);
            result.put("domainFQID", domainFqti);
        } else if (matched.equals("port")) {
            String domainFqti = "urn:ogf:network:domain="+domainValue;
            String nodeFqti = domainFqti+":node="+nodeValue;
            String portFqti = nodeFqti+":port="+portValue;
            compactForm = "urn:ogf:network:"+domainValue+":"+nodeValue+":"+portValue;
            realCompactForm = domainValue+":"+nodeValue+":"+portValue;
            result.put("realcompact", realCompactForm);
            result.put("compact", compactForm);
            result.put("type", "port");
            result.put("fqti", portFqti);
            result.put("domainValue", domainValue);
            result.put("nodeValue", nodeValue);
            result.put("portValue", portValue);
            result.put("portFQID", portFqti);
            result.put("nodeFQID", nodeFqti);
            result.put("domainFQID", domainFqti);
        } else if (matched.equals("link")) {
            String domainFqti = "urn:ogf:network:domain="+domainValue;
            String nodeFqti = domainFqti+":node="+nodeValue;
            String portFqti = nodeFqti+":port="+portValue;
            String linkFqti = portFqti+":link="+linkValue;
            fqti = "urn:ogf:network:domain="+domainValue+":node="+nodeValue+":port="+portValue+":link="+linkValue;
            compactForm = "urn:ogf:network:"+domainValue+":"+nodeValue+":"+portValue+":"+linkValue;
            realCompactForm = domainValue+":"+nodeValue+":"+portValue+":"+linkValue;
            result.put("realcompact", realCompactForm);
            result.put("compact", compactForm);
            result.put("type", "link");
            result.put("fqti", linkFqti);
            result.put("domainValue", domainValue);
            result.put("nodeValue", nodeValue);
            result.put("portValue", portValue);
            result.put("linkValue", linkValue);
            result.put("linkFQID", linkFqti);
            result.put("portFQID", portFqti);
            result.put("nodeFQID", nodeFqti);
            result.put("domainFQID", domainFqti);
	}
         return result;
    }
}
