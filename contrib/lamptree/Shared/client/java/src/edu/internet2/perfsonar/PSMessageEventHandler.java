package edu.internet2.perfsonar;

import org.jdom.*;
import java.util.HashMap;

public interface PSMessageEventHandler {
    public void handleMetadataDataPair(Element metadata, Element data, HashMap <String, Element> metadataMap, String messageType, Object arg);
}
