package edu.internet2.perfsonar;

import org.jdom.Namespace;

public class PSNamespaces {
	public Namespace NMWG;
	public Namespace PS;
	public Namespace PS_SERVICE;
	public Namespace XQUERY;
	public Namespace NMWG_RESULT;
	public Namespace TOPO;
	public Namespace TOPO_L3;
	public Namespace DCN;
	
	public PSNamespaces(){
		this.NMWG = Namespace.getNamespace("nmwg", "http://ggf.org/ns/nmwg/base/2.0/");
		this.NMWG_RESULT = Namespace.getNamespace("nmwgr", "http://ggf.org/ns/nmwg/result/2.0/");
		this.PS = Namespace.getNamespace("perfsonar", "http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/");
		this.PS_SERVICE = Namespace.getNamespace("psservice", "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/");
		this.XQUERY = Namespace.getNamespace("xquery", "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0/");
		this.TOPO = Namespace.getNamespace("nmtopo", "http://ogf.org/schema/network/topology/base/20070828/");
		this.TOPO_L3 = Namespace.getNamespace("nmtl3", "http://ogf.org/schema/network/topology/l3/20070828/");
		this.DCN =  Namespace.getNamespace("dcn", "http://ggf.org/ns/nmwg/tools/org/dcn/1.0/");
	}
}
