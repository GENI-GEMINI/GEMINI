package edu.internet2.perfsonar.servlets;

import java.io.IOException;
import java.io.PrintWriter;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jdom.Element;
import org.jdom.output.XMLOutputter;

import edu.internet2.perfsonar.PSException;
import edu.internet2.perfsonar.TSLookupClient;

public class XMLTopologyServlet extends HttpServlet{
    public static String[] hls = {"http://dcn-ls.internet2.edu:8005/perfSONAR_PS/services/hLS"};
    public static String[] ts = {"http://dcn-ts.internet2.edu:8012/perfSONAR_PS/services/topology"};
    
    public void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException, ServletException {
        PrintWriter out = response.getWriter();
        String hlsStr = request.getParameter("hls");
        String[] hls = null;
        if(hlsStr == null){
            hls = XMLTopologyServlet.hls;
        }else{
            hls = hlsStr.split(",");
        }
        
        String tsStr = request.getParameter("ts");
        String[] ts = null;
        if(tsStr == null){
            ts = XMLTopologyServlet.ts;
        }else{
            ts = tsStr.split(",");
        }
        
        String domain = request.getParameter("domain");
        if(domain == null){
            response.setContentType("text/html");
            this.printForm(out);
            return;
        }
        
        TSLookupClient tsClient = new TSLookupClient(null, hls, ts);
        Element topoElem = null;
        try {
            topoElem = tsClient.getDomain("urn:ogf:network:domain=" + domain);
        } catch (PSException e) {
            response.setContentType("text/html");
            this.printError(e.getMessage(), out);
            this.printForm(out);
            return;
        }
        if(topoElem == null){
            response.setContentType("text/html");
            this.printError("'" + domain + "' topology not found", out);
            this.printForm(out);
            return;
        }
        response.setContentType("text/xml");
        XMLOutputter outputter = new XMLOutputter();
        outputter.output(topoElem, out);
    }

    private void printForm(PrintWriter out) {
        out.println("<form id=\"domainQueryForm\" method=\"GET\">");
        out.println("<font face=\"arial,helvetica,sans-serif\" size=\"3\">");
        out.println("<b>Enter Domain ID: </b><br>");
        out.println("urn:ogf:network:domain=<input type=\"text\" id=\"domain\" name=\"domain\" />");
        out.println("<input type=\"submit\" value=\"Query Topology\" />");
        out.println("</font>");
        out.println("</form>");
    }
    
    private void printError(String msg, PrintWriter out) {
        out.println("<font face=\"arial,helvetica,sans-serif\" size=\"3\" color=\"#BB0000\">");
        out.println("ERROR: " + msg);
        out.println("</font><br><br>");
    }
}
