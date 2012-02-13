#!/usr/bin/env python

import os
import sys
import getopt

import xml.dom.minidom as dom
from httplib import HTTPConnection, HTTPSConnection

cert_file = os.environ['HOME'] + "/.ssl/emulab.pem"
key_file = os.environ['HOME'] + "/.ssl/emulab.pem"

if "HTTPS_CERT_FILE" in os.environ:
    cert_file = os.environ["HTTPS_CERT_FILE"]

if "HTTPS_KEY_FILE" in os.environ:
    key_file = os.environ["HTTPS_KEY_FILE"]

class SimpleClient:
    """
    Very simple client to send SOAP requests to perfSONAR service
    """

    def __init__(self, host, port, uri, cert=None, key=None):
        self.host = host
        self.port = port
        self.uri  = uri
        self.cert = cert
        self.key = key
    
    def soapifyMessage(self, message):
        headerString = """<SOAP-ENV:Envelope 
 xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
 xmlns:xsd="http://www.w3.org/2001/XMLSchema"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
<SOAP-ENV:Header/>
<SOAP-ENV:Body>
%s
</SOAP-ENV:Body>
</SOAP-ENV:Envelope>
""" % message
        return headerString

    def send_request(self, message, useSSL=False, issoap=False):
        if useSSL:
            conn = HTTPSConnection(self.host, self.port, self.key, self.cert)
        else:
            conn = HTTPConnection(self.host, self.port)
            
        conn.connect()
        headers = {'SOAPAction':'', 'Content-Type': 'text/xml'}
        if issoap == False:
            message = self.soapifyMessage(message)
        conn.request('POST', self.uri, message, headers)
        resp = conn.getresponse()
        response = resp.read()
        conn.close() 
        return response


# pS Namespaces
UNIS_NS = "http://ogf.org/schema/network/topology/unis/20100528/"
PSCONFIG_NS = "http://ogf.org/schema/network/topology/psconfig/20100716/"
PROTOGENI_NS ="http://ogf.org/schema/network/topology/protogeni/20100716/"
TS_EVENTTYPE = "http://ggf.org/ns/nmwg/topology/20070809"
XQUERY_EVENTTYPE = "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0"

# RSpec Namespaces
RSPEC_NS = "http://www.protogeni.net/resources/rspec/2"
LAMP_NS = "http://protogeni.net/resources/rspec/0.2/ext/lamp/1"

host = "blackseal.damsl.cis.udel.edu"
port = 8012
uri = "/perfSONAR_PS/services/unis"

if "UNIS_ADDRESS" in os.environ:
    host = os.environ["UNIS_ADDRESS"]


class RSpecXMLParsingException(Exception):
    def __init__(self, msg):
        self.msg = msg
    
    def __str__(self):
        return self.msg

# TODO: This method needs refactoring.
def manifest_v2_to_unis(manifest, slice_id):
    unis_dom = dom.getDOMImplementation().createDocument(UNIS_NS, "topology", None)
    topology = unis_dom.documentElement
    topology.setAttribute('id', 'genitopo')

    slice_id = slice_id.replace("urn:publicid:IDN+", "")
    domain = unis_dom.createElementNS(UNIS_NS, "domain")
    domain.setAttribute('id', create_urn(domain=slice_id))
    topology.appendChild(domain)

    # map an interface to its node so we can look it up by client_id
    node_interfaces = dict()
    parsed = dict()
    rspec = manifest.documentElement
    rsnodes = rspec.getElementsByTagNameNS(RSPEC_NS, "node")

    for rsnode in rsnodes:
        node_virtual_id = rsnode.getAttribute('client_id')
        unis_id = create_urn(domain=slice_id, node=node_virtual_id)
        if unis_id in parsed:
            raise RSpecXMLParsingException, \
               "Two node elements found with same id (%s)" % node_virtual_id

        unis_node = unis_dom.createElementNS(UNIS_NS, "node")
        unis_node.setAttribute('id', unis_id)

        parsed[unis_id] = unis_node

        # Add node's hostname as a unis:address of type 'hostname'
        hostname = rsnode.getAttribute('hostname')
        unis_address = create_text_element(unis_dom, UNIS_NS, "address", hostname)
        unis_address.setAttribute('type', 'dns')
        unis_node.appendChild(unis_address)

        unis_node_properties_bag = unis_dom.createElementNS(UNIS_NS, "nodePropertiesBag")
        unis_node.appendChild(unis_node_properties_bag)

        unis_node_pgeni_properties = unis_dom.createElementNS(PROTOGENI_NS, "nodeProperties")
        unis_node_properties_bag.appendChild(unis_node_pgeni_properties)

        # Most RSpec node attributes become attributes of the pgeni properties
        # element, but we ignore a few because they're represented elsewhere
        NODE_IGNORED_ATTRS = ('client_id', 'hostname', 'sshdport')
        for i in range(rsnode.attributes.length):
            attr = rsnode.attributes.item(i)
            if attr.name in NODE_IGNORED_ATTRS:
                continue
            unis_node_pgeni_properties.setAttribute(attr.name, attr.value)

        # Now we process the child elements that we recognize
        rsinterfaces = rsnode.getElementsByTagNameNS(RSPEC_NS, "interface")
        for rsiface in rsinterfaces:
            iface_virtual_id = rsiface.getAttribute('client_id')
            unis_id = create_urn(domain=slice_id, node=node_virtual_id,
                                 port=iface_virtual_id)
            if unis_id in parsed:
                raise RSpecXMLParsingException, \
                   "Two interface elements found with same id (%s) in node %s" \
                        % iface_virtual_id, node_virtual_id
            
            unis_port = unis_dom.createElementNS(UNIS_NS, "port")
            unis_port.setAttribute('id', unis_id)

            node_interfaces[iface_virtual_id] = node_virtual_id
            parsed[unis_id] = unis_port
                        
            iface_component_id = rsiface.getAttribute('component_id')
            unis_port.appendChild(
                create_text_element(unis_dom, UNIS_NS, "name", iface_component_id))

            unis_port_properties_bag = unis_dom.createElementNS(UNIS_NS, "portPropertiesBag")
            unis_port.appendChild(unis_port_properties_bag)

            unis_port_pgeni_properties = unis_dom.createElementNS(PROTOGENI_NS, "portProperties")
            unis_port_properties_bag.appendChild(unis_port_pgeni_properties)

            INTERFACE_IGNORED_ATTRS = ('client_id',)
            for i in range(rsiface.attributes.length):
                attr = rsiface.attributes.item(i)
                if attr.name in INTERFACE_IGNORED_ATTRS:
                    continue
                unis_port_pgeni_properties.setAttribute(attr.name, attr.value)

            unis_node.appendChild(unis_port)

        # We expect a single lamp:config element and we basically just change
        # the namespace to psconfig and clone the root element as a nodeProperties
        rslamp_config = get_unique_xml_child(rsnode, LAMP_NS, 'config')
        if rslamp_config:
            unis_node_psconfig_properties = unis_dom.createElementNS(PSCONFIG_NS,
                                                                     "nodeProperties")
            unis_node_properties_bag.appendChild(unis_node_psconfig_properties)

            clone_children(rslamp_config, unis_node_psconfig_properties)

        # All the other child nodes of rspec node we clone into the pgeni extension
        NODE_IGNORED_CHILDREN = ((LAMP_NS, 'config'), (RSPEC_NS, 'interface'))
        clone_children(rsnode, unis_node_pgeni_properties, NODE_IGNORED_CHILDREN)

        domain.appendChild(unis_node)

    rslinks = rspec.getElementsByTagNameNS(RSPEC_NS, "link")
    for rslink in rslinks:
        link_virtual_id = rslink.getAttribute('client_id')
        unis_id = create_urn(domain=slice_id, link=link_virtual_id)
        if unis_id in parsed:
            raise RSpecXMLParsingException, \
               "Found two link elements with same id (%s)" % link_virtual_id

        # XXX: Note that if this RSpec link has more than two interface_refs
        # it should actually be a UNIS network element. But we don't deal
        # with this case yet (it will raise an error below).
        unis_link = unis_dom.createElementNS(UNIS_NS, "link")
        unis_link.setAttribute('id', unis_id)

        parsed[unis_id] = unis_link

        # XXX: We run away a little from the current NML consensus regarding
        #   links. We basically add an attribute 'directed' set to 'false'
        #   to identify the link as a bidirectional link, and make two
        #   relation elements of type 'endPoint'.
        unis_link.setAttribute('directed', 'false')

        # Add link's link_type element as unis:type'
        link_type = get_unique_xml_child(rslink, RSPEC_NS, 'link_type')
        if link_type:
            unis_link.appendChild(
                create_text_element(unis_dom, UNIS_NS, 'type',
                                    link_type.getAttribute('type_name')))

        unis_link_properties_bag = unis_dom.createElementNS(UNIS_NS, "linkPropertiesBag")
        unis_link.appendChild(unis_link_properties_bag)

        unis_link_pgeni_properties = unis_dom.createElementNS(PROTOGENI_NS, "linkProperties")
        unis_link_properties_bag.appendChild(unis_link_pgeni_properties)

        LINK_IGNORED_ATTRS = ('client_id',)
        for i in range(rslink.attributes.length):
            attr = rslink.attributes.item(i)
            if attr.name in LINK_IGNORED_ATTRS:
                continue
            unis_link_pgeni_properties.setAttribute(attr.name, attr.value)


        interface_refs = rslink.getElementsByTagNameNS(RSPEC_NS, "interface_ref")
        if len(interface_refs) != 2:
            raise RSpecXMLParsingException, \
                "Unsupported number of interface_refs in link %s" % link_virtual_id

        for iface_ref in interface_refs:
            iface_ref_id = iface_ref.getAttribute('client_id')
            port_id_ref = create_urn(domain=slice_id,
                                     node=node_interfaces[iface_ref_id],
                                     port=iface_ref_id)

            if port_id_ref not in parsed:
                raise RSpecXMLParsingException, \
                    "Link %s references nonexistent interface" % link_virtual_id

            # This part is bizarre. RSpec puts the sliver, component urn,
            # MAC and IP addresses of an iface as part of the interface_ref
            unis_port = parsed[port_id_ref]

            mac = iface_ref.getAttribute('MAC')
            if mac:
                unis_port.appendChild(
                    create_text_element(unis_dom, UNIS_NS, 'address', mac,
                                        attributes=(('type', 'mac'),) ))
                
            ip = iface_ref.getAttribute('IP')
            if ip:
                unis_port.appendChild(
                    create_text_element(unis_dom, UNIS_NS, 'address', ip,
                                        attributes=(('type', 'ipv4'),) ))

            unis_port_pgeni_properties = \
                unis_port.getElementsByTagNameNS(PROTOGENI_NS, "portProperties")
            assert len(unis_port_pgeni_properties) == 1
            unis_port_pgeni_properties = unis_port_pgeni_properties[0]

            IFACEREF_IGNORED_ATTRS = ('client_id', 'MAC', 'IP')
            for i in range(iface_ref.attributes.length):
                attr = iface_ref.attributes.item(i)
                if attr.name in IFACEREF_IGNORED_ATTRS:
                    continue
                unis_port_pgeni_properties.setAttribute(attr.name, attr.value)

            # Finally we can create the actual relation for this iface_ref
            unis_relation = unis_dom.createElementNS(UNIS_NS, "relation")
            unis_relation.setAttribute('type', 'endPoint')
            unis_relation.appendChild(
                create_text_element(unis_dom, UNIS_NS, 'portIdRef', port_id_ref))
            unis_link.appendChild(unis_relation)

        # We clone everything else that's left
        LINK_IGNORED_CHILDREN = ((RSPEC_NS, 'interface_ref'), (RSPEC_NS, 'link_type'))
        clone_children(rslink, unis_link_pgeni_properties, LINK_IGNORED_CHILDREN)

        domain.appendChild(unis_link)

    # Alright, seems like we're done. Now we change all the namespaces to the
    # appropriate UNIS based namespace and make sure tags are correct. This
    # could have been done while processing the elements, but it's simpler to
    # do here (we don't have to worry about the n levels of cloned children).
    for e in domain.getElementsByTagNameNS(PROTOGENI_NS, "*"):
        e.tagName = 'pgeni:' + e.localName

    for e in domain.getElementsByTagNameNS(RSPEC_NS, "*"):
        e.namespaceURI = PROTOGENI_NS
        e.tagName = 'pgeni:' + e.localName

    for e in domain.getElementsByTagNameNS(PSCONFIG_NS, "*"):
        e.tagName = 'psconfig:' + e.localName

    for e in domain.getElementsByTagNameNS(LAMP_NS, "*"):
        e.namespaceURI = PSCONFIG_NS
        e.tagName = 'psconfig:' + e.localName

    # Now set the namespace globally in the document, minidom doesn't
    # do this for us so we must do it manually. UNIS_NS is the default.
    topology.setAttribute("xmlns", UNIS_NS)
    topology.setAttribute("xmlns:pgeni", PROTOGENI_NS)
    topology.setAttribute("xmlns:psconfig", PSCONFIG_NS)

    return unis_dom
    
# TODO: This method needs refactoring.
def manifest_to_unis(manifest, slice_id):
    unis_dom = dom.getDOMImplementation().createDocument(UNIS_NS, "topology", None)
    topology = unis_dom.documentElement
    topology.setAttribute('id', 'genitopo')
    
    slice_id = slice_id.replace("urn:publicid:IDN+", "")
    domain = unis_dom.createElementNS(UNIS_NS, "domain")
    domain.setAttribute('id', create_urn(domain=slice_id))
    topology.appendChild(domain)
    
    parsed = dict()
    rspec = manifest.documentElement
    rsnodes = rspec.getElementsByTagNameNS(RSPEC_NS, "node")
    for rsnode in rsnodes:
        node_virtual_id = rsnode.getAttribute('virtual_id')
        unis_id = create_urn(domain=slice_id, node=node_virtual_id)
        if unis_id in parsed:
            raise RSpecXMLParsingException, \
               "Two node elements found with same id (%s)" % node_virtual_id
        
        unis_node = unis_dom.createElementNS(UNIS_NS, "node")
        unis_node.setAttribute('id', unis_id)
        
        parsed[unis_id] = unis_node
         
        # Add node's hostname as a unis:address of type 'hostname'
        hostname = rsnode.getAttribute('hostname')
        unis_address = create_text_element(unis_dom, UNIS_NS, "address", hostname)
        unis_address.setAttribute('type', 'dns')
        unis_node.appendChild(unis_address)
        
        unis_node_properties_bag = unis_dom.createElementNS(UNIS_NS, "nodePropertiesBag")
        unis_node.appendChild(unis_node_properties_bag)
        
        unis_node_pgeni_properties = unis_dom.createElementNS(PROTOGENI_NS, "nodeProperties")
        unis_node_properties_bag.appendChild(unis_node_pgeni_properties)
        
        # Most RSpec node attributes become attributes of the pgeni properties
        # element, but we ignore a few because they're represented elsewhere
        NODE_IGNORED_ATTRS = ('virtual_id', 'hostname', 'sshdport')
        for i in range(rsnode.attributes.length):
            attr = rsnode.attributes.item(i)
            if attr.name in NODE_IGNORED_ATTRS:
                continue
            unis_node_pgeni_properties.setAttribute(attr.name, attr.value)
        
        # Now we process the child elements that we recognize
        rsinterfaces = rsnode.getElementsByTagNameNS(RSPEC_NS, "interface")
        for rsiface in rsinterfaces:
            iface_virtual_id = rsiface.getAttribute('virtual_id')
            unis_id = create_urn(domain=slice_id, node=node_virtual_id, 
                                 port=iface_virtual_id)
            if unis_id in parsed:
                raise RSpecXMLParsingException, \
                   "Two interface elements found with same id (%s) in node %s" \
                        % iface_virtual_id, node_virtual_id
            
            unis_port = unis_dom.createElementNS(UNIS_NS, "port")
            unis_port.setAttribute('id', unis_id)
            
            parsed[unis_id] = unis_port
            
            iface_component_id = rsiface.getAttribute('component_id')
            unis_port.appendChild(
                create_text_element(unis_dom, UNIS_NS, "name", iface_component_id))
            
            unis_port_properties_bag = unis_dom.createElementNS(UNIS_NS, "portPropertiesBag")
            unis_port.appendChild(unis_port_properties_bag)
        
            unis_port_pgeni_properties = unis_dom.createElementNS(PROTOGENI_NS, "portProperties")
            unis_port_properties_bag.appendChild(unis_port_pgeni_properties)
            
            INTERFACE_IGNORED_ATTRS = ('virtual_id',)
            for i in range(rsiface.attributes.length):
                attr = rsiface.attributes.item(i)
                if attr.name in INTERFACE_IGNORED_ATTRS:
                    continue
                unis_port_pgeni_properties.setAttribute(attr.name, attr.value)
             
            unis_node.appendChild(unis_port)
            
        # We expect a single lamp:config element and we basically just change
        # the namespace to psconfig and clone the root element as a nodeProperties
        rslamp_config = get_unique_xml_child(rsnode, LAMP_NS, 'config')
        if rslamp_config:
            unis_node_psconfig_properties = unis_dom.createElementNS(PSCONFIG_NS, 
                                                                     "nodeProperties")
            unis_node_properties_bag.appendChild(unis_node_psconfig_properties)
            
            clone_children(rslamp_config, unis_node_psconfig_properties)
        
        # All the other child nodes of rspec node we clone into the pgeni extension
        NODE_IGNORED_CHILDREN = ((LAMP_NS, 'config'), (RSPEC_NS, 'interface'))
        clone_children(rsnode, unis_node_pgeni_properties, NODE_IGNORED_CHILDREN)
        
        domain.appendChild(unis_node)
    
    rslinks = rspec.getElementsByTagNameNS(RSPEC_NS, "link")
    for rslink in rslinks:
        link_virtual_id = rslink.getAttribute('virtual_id')
        unis_id = create_urn(domain=slice_id, link=link_virtual_id)
        if unis_id in parsed:
            raise RSpecXMLParsingException, \
               "Found two link elements with same id (%s)" % link_virtual_id
        
        # XXX: Note that if this RSpec link has more than two interface_refs
        # it should actually be a UNIS network element. But we don't deal
        # with this case yet (it will raise an error below).
        unis_link = unis_dom.createElementNS(UNIS_NS, "link")
        unis_link.setAttribute('id', unis_id)
        
        parsed[unis_id] = unis_link
         
        # XXX: We run away a little from the current NML consensus regarding
        #   links. We basically add an attribute 'directed' set to 'false'
        #   to identify the link as a bidirectional link, and make two
        #   relation elements of type 'endPoint'. 
        unis_link.setAttribute('directed', 'false')
        
        # Add link's link_type element as unis:type'
        link_type = get_unique_xml_child(rslink, RSPEC_NS, 'link_type')
        if link_type:
            unis_link.appendChild(
                create_text_element(unis_dom, UNIS_NS, 'type', 
                                    link_type.getAttribute('type_name')))
        
        unis_link_properties_bag = unis_dom.createElementNS(UNIS_NS, "linkPropertiesBag")
        unis_link.appendChild(unis_link_properties_bag)
        
        unis_link_pgeni_properties = unis_dom.createElementNS(PROTOGENI_NS, "linkProperties")
        unis_link_properties_bag.appendChild(unis_link_pgeni_properties)
        
        LINK_IGNORED_ATTRS = ('virtual_id',)
        for i in range(rslink.attributes.length):
            attr = rslink.attributes.item(i)
            if attr.name in LINK_IGNORED_ATTRS:
                continue
            unis_link_pgeni_properties.setAttribute(attr.name, attr.value)
        
        
        interface_refs = rslink.getElementsByTagNameNS(RSPEC_NS, "interface_ref")
        if len(interface_refs) != 2:
            raise RSpecXMLParsingException, \
                "Unsupported number of interface_refs in link %s" % link_virtual_id
        
        for iface_ref in interface_refs:
            port_id_ref = create_urn(domain=slice_id, 
                                     node=iface_ref.getAttribute('virtual_node_id'),
                                     port=iface_ref.getAttribute('virtual_interface_id'))
            
            if port_id_ref not in parsed:
                raise RSpecXMLParsingException, \
                    "Link %s references nonexistent interface" % link_virtual_id
            
            # This part is bizarre. RSpec puts the sliver, component urn,
            # MAC and IP addresses of an iface as part of the interface_ref
            unis_port = parsed[port_id_ref]
            
            mac = iface_ref.getAttribute('MAC')
            if mac:
                unis_port.appendChild(
                    create_text_element(unis_dom, UNIS_NS, 'address', mac,
                                        attributes=(('type', 'mac'),) ))
            
            ip = iface_ref.getAttribute('IP')
            if ip:
                unis_port.appendChild(
                    create_text_element(unis_dom, UNIS_NS, 'address', ip,
                                        attributes=(('type', 'ipv4'),) ))
            
            unis_port_pgeni_properties = \
                unis_port.getElementsByTagNameNS(PROTOGENI_NS, "portProperties")
            assert len(unis_port_pgeni_properties) == 1
            unis_port_pgeni_properties = unis_port_pgeni_properties[0]
            
            IFACEREF_IGNORED_ATTRS = ('virtual_node_id', 'MAC', 'IP',
                                      'virtual_interface_id')
            for i in range(iface_ref.attributes.length):
                attr = iface_ref.attributes.item(i)
                if attr.name in IFACEREF_IGNORED_ATTRS:
                    continue
                unis_port_pgeni_properties.setAttribute(attr.name, attr.value)
            
            # Finally we can create the actual relation for this iface_ref
            unis_relation = unis_dom.createElementNS(UNIS_NS, "relation")
            unis_relation.setAttribute('type', 'endPoint')
            unis_relation.appendChild(
                create_text_element(unis_dom, UNIS_NS, 'portIdRef', port_id_ref))
            unis_link.appendChild(unis_relation)
        
        # We clone everything else that's left
        LINK_IGNORED_CHILDREN = ((RSPEC_NS, 'interface_ref'), (RSPEC_NS, 'link_type'))
        clone_children(rslink, unis_link_pgeni_properties, LINK_IGNORED_CHILDREN)
        
        domain.appendChild(unis_link)
    
    # Alright, seems like we're done. Now we change all the namespaces to the
    # appropriate UNIS based namespace and make sure tags are correct. This
    # could have been done while processing the elements, but it's simpler to
    # do here (we don't have to worry about the n levels of cloned children).
    for e in domain.getElementsByTagNameNS(PROTOGENI_NS, "*"):
        e.tagName = 'pgeni:' + e.localName
    
    for e in domain.getElementsByTagNameNS(RSPEC_NS, "*"):
        e.namespaceURI = PROTOGENI_NS
        e.tagName = 'pgeni:' + e.localName
        
    for e in domain.getElementsByTagNameNS(PSCONFIG_NS, "*"):
        e.tagName = 'psconfig:' + e.localName
           
    for e in domain.getElementsByTagNameNS(LAMP_NS, "*"):
        e.namespaceURI = PSCONFIG_NS
        e.tagName = 'psconfig:' + e.localName
        
    # Now set the namespace globally in the document, minidom doesn't
    # do this for us so we must do it manually. UNIS_NS is the default.
    topology.setAttribute("xmlns", UNIS_NS)
    topology.setAttribute("xmlns:pgeni", PROTOGENI_NS)
    topology.setAttribute("xmlns:psconfig", PSCONFIG_NS)
    
    return unis_dom
    
    
class Usage(Exception):
    def __init__(self, msg):
        self.msg = msg

def main(argv=None):
    if argv is None:
        argv = sys.argv
    try:
        try:
            opts, args = getopt.getopt(argv[1:], "h", ["help"])
            if opts or (len(args) != 3 and len(args) != 4):
                raise Usage('Not enough arguments')
            
            version = args[0]
            manifest_xml = args[1]
            slice_id = args[2]

            try:
                open(manifest_xml, 'r')
            except IOError, msg:
                raise Usage('Cannot open manifest: ' + msg)
            
            if not slice_id.startswith("urn:publicid:IDN+"):
                raise Usage('Invalid slice urn')
            
            credential_xml = None
            if len(args) == 4:
                try:
                    open(args[3], 'r')
                    credential_xml = args[3]
                except IOError, msg:
                    raise Usage('Cannot open credential: ' + msg)

        except getopt.error, msg:
            raise Usage(msg)
        
        manifest_dom = dom.parse(manifest_xml)
        ns = manifest_dom.documentElement.getAttribute('xmlns')

        global RSPEC_NS
        if version == '0.1':
            RSPEC_NS = "http://protogeni.net/resources/rspec/0.1"
            if (ns == RSPEC_NS):
                unis_dom = manifest_to_unis(manifest_dom, slice_id)
            else:
                print "Manifest has unexpected default namespace"
                return
        if version == '0.2':
            RSPEC_NS = "http://protogeni.net/resources/rspec/0.2"
            if (ns == RSPEC_NS):
                unis_dom = manifest_to_unis(manifest_dom, slice_id)
            else:
                print "Manifest has unexpected default namespace"
                return
            unis_dom = manifest_to_unis(manifest_dom, slice_id)
        if version == '2':
            RSPEC_NS = "http://www.protogeni.net/resources/rspec/2"
            if (ns == RSPEC_NS):
                unis_dom = manifest_v2_to_unis(manifest_dom, slice_id)
            else:
                print "Manifest has unexpected default namespace"
                return

        print unis_dom.toprettyxml()
        return

        # Clean spurious empty lines in message (toprettyxml() abuses them)
        unis_str = ""
        for line in unis_dom.toprettyxml().split("\n"):
            if line.strip() != '' and not line.lstrip().startswith('<?xml '):
                unis_str += line + "\n"
        
        credential = None
        if credential_xml:
            credential = get_slice_cred(credential_xml)
        
        # Don't do the above on messages with credentials!
        message = make_UNISTSReplace_message(unis_str, credential)
        print message
        print "\n\n"
        try:
            client = SimpleClient(host=host, port=port, uri=uri, cert=cert_file, key=key_file)
            response = client.send_request(message, useSSL=True)
        except Exception, err:
            print "Error contacting UNIS: " + str(err)
            return
        
        print "Received:\n"
        print response
        
    except Usage, err:
        print >>sys.stderr, err.msg
        print >>sys.stderr, "Usage: <rspec_version [0.2, 2]> <manifest> <slice_urn> [credential]"
        return 2
    
##################################
# Utility methods
##################################

def get_slice_cred(fname):
    f = open(fname, 'r')
    return f.read()

def make_credential_metadata(cred, metadata_id, metadata_idref):
    return """
  <nmwg:metadata id="%s">
    <nmwg:subject metadataIdRef="%s">
%s
    </nmwg:subject>
    <nmwg:eventType>http://perfsonar.net/ns/protogeni/auth/credential/1</nmwg:eventType>
  </nmwg:metadata>
""" % (metadata_id, metadata_idref, cred) 


def make_UNIS_request(type, eventType, subject="", data_content="", cred=None):
    metadata_id = 'meta0'
    
    cred_metadata = ""
    if cred:
        cred_metadata = make_credential_metadata(cred, 'cred0', metadata_id)
        metadata_id = 'cred0'

    msg="""
<nmwg:message type="%s" xmlns:nmwg="http://ggf.org/ns/nmwg/base/2.0/">
  <nmwg:metadata id="meta0">
%s
    <nmwg:eventType>%s</nmwg:eventType>
  </nmwg:metadata>
%s
  <nmwg:data id="data0" metadataIdRef="%s">
%s
  </nmwg:data>
</nmwg:message>
"""
    return msg % (type, subject, eventType, cred_metadata, metadata_id, data_content)    
    
def make_UNISTSQueryAll_message(cred=None):
    return make_UNIS_request("TSQueryRequest", TS_EVENTTYPE, cred=cred)

def make_UNISTSAdd_message(topology, cred=None):
    return make_UNIS_request("TSAddRequest", TS_EVENTTYPE, 
                             data_content=topology, cred=cred)

def make_UNISTSReplace_message(topology, cred=None):
    return make_UNIS_request("TSReplaceRequest", TS_EVENTTYPE,
                             data_content=topology, cred=cred)

def make_UNISLSQuery_message(xquery=None, cred=None):
    if xquery is None:
        xquery = """
declare namespace nmwg="http://ggf.org/ns/nmwg/base/2.0/";
/nmwg:store[@type="LSStore"]
"""
    
    subject = """
    <xquery:subject id="sub1" xmlns:xquery="http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/">
%s
    </xquery:subject>
""" % xquery
    
    return make_UNIS_request("LSQueryRequest", XQUERY_EVENTTYPE, 
                             subject=subject, cred=cred)

def create_urn(domain, node=None, port=None, link=None, service=None):
    """
    Create UNIS URN.
    
    Example if domain is udel.edu then the URN is
    'urn:ogf:network:domain=udel.edu'
    And if domain is udel.edu and node is stout then the URN is
    'urn:ogf:network:domain=udel.edu:node=stout'
    """
    assert domain, "URN must be fully qualified; no domain provided"
    urn = "urn:ogf:network:domain=%s" % domain
    
    if node != None:
        urn = urn + ":node=%s" % node
       
    if port != None:
        assert node != None, "URN must be fully qualified; no node given for port"
        urn = urn + ":port=%s" % port
   
    if link != None:
        assert node == None, "URN must be fully qualified; invalid link urn"
        urn = urn + ":link=%s" % link
    
    if service != None:
        assert node != None and port == None, "URN must be fully qualified; invalid service urn"
        urn = urn + ":service=%s" % service
    
    return urn


# As bizarre as it sounds, (mini)DOM doesn't provide a 
# getElementsByTag that gets from only the immediate children.
def get_qualified_xml_children(element, ns, name):
    elements = []
    for child in element.childNodes:
        if isinstance(child, dom.Element):
            if child.namespaceURI == ns and child.localName == name:
                elements.append(child)
    return elements

def get_unique_xml_child(element, ns, name):
    # XXX: Maybe namespace could be None?
    assert element != None and ns != None and name != None
    
    children = get_qualified_xml_children(element, ns, name)
    if len(children) > 1:
        raise Exception, element.localName + ": has more than one " + \
                         name + " element!"
    
    if len(children) == 1:
        return children[0]
    return None

def create_text_element(dom, ns, name, data, attributes=()):
    if ns:
        e = dom.createElementNS(ns, name)
    else:
        e = dom.createElement(name)
    
    e.appendChild(dom.createTextNode(data))
    
    for (attr_name, attr_value) in attributes:
        e.setAttribute(attr_name, attr_value)
        
    return e

def clone_children(node_from, node_to, ignore_list=()):
    for child in node_from.childNodes:
        if (child.namespaceURI, child.localName) in ignore_list:
            continue
        node_to.appendChild( child.cloneNode(True) )


if __name__ == "__main__":
    sys.exit(main())
