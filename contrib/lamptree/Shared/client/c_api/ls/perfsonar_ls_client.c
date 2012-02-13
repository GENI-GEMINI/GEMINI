#include <stdlib.h>
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xpath.h>

#include "nanohttp/nanohttp-client.h"
#include "perfsonar_ls_client.h"
#include "perfsonar_service.h"


static int perfsonar_construct_ls_key(char *buf, int buflen, const char *key);
static int perfsonar_construct_ls_message(char *buf, int buflen, const char *type, const char *metadata, const char *data);
static int perfsonar_construct_service(char *buf, int buflen, perfSONARService *service);
static int perfsonar_construct_perfsonar_service(char *buf, int buflen, perfSONARService *service);
static int perfsonar_construct_nonperfsonar_service(char *buf, int buflen, perfSONARService *service);

static int perfsonar_send_request(const char *url, const char *message, xmlNodePtr *ret_msg);
static int perfsonar_xpath_findvalue(xmlNodePtr node, const char *xpath, xmlXPathContextPtr *state_ptr, char **ret_value);
static xmlXPathObjectPtr perfsonar_xpath_find(xmlNodePtr node, const char *xpath, xmlXPathContextPtr *state_ptr);
static void perfsonar_register_namespaces(xmlNodePtr node, xmlXPathContextPtr context);








int perfsonar_ls_register(const char *url, perfSONARService *service, char **metadata, int metadata_count, char **ls_key) {
	char buf[16384];
	char service_metadata[2048];
	char service_data[2048];
	int i;
	xmlNodePtr resp_msg;
	char *eventType;

	printf("Constructing service\n");
	service_metadata[0] = '\0';
	perfsonar_construct_service(service_metadata, sizeof(service_metadata), service);
	printf("Constructing service - done\n");

	printf("Constructing data segment\n");
	service_data[0] = '\0';
	for(i = 0; i < metadata_count; i++) {
		strlcat(service_data, metadata[i], sizeof(service_data));
	}
	printf("Constructing data segment - done\n");

	printf("Constructing LS message\n");
	buf[0] = '\0';
	perfsonar_construct_ls_message(buf, sizeof(buf), "LSRegisterRequest", service_metadata, service_data);	
	printf("Constructing LS message - done\n");

	printf("Sending message\n");
	if (perfsonar_send_request(url, buf, &resp_msg) != 0) {
		goto error_exit;
	}

	if (perfsonar_xpath_findvalue(resp_msg, "./nmwg:metadata/nmwg:eventType", NULL, &eventType) != 0) {
		goto error_exit_doc;
	}

	if (strncmp(eventType, "success", 7) != 0) {
		printf("Event type != success: %s\n", eventType);
		goto error_exit_ev;
	}

	if (perfsonar_xpath_findvalue(resp_msg, "./nmwg:metadata/nmwg:key/nmwg:parameters/nmwg:parameter[@name=\"lsKey\"]", NULL, ls_key) != 0) {
		goto error_exit_ev;
	}

	free(eventType);
	xmlFreeDoc(resp_msg->doc);

	return 0;
	
error_exit_ev:
	free(eventType);
error_exit_doc:
	xmlFreeDoc(resp_msg->doc);
error_exit:
	return -1;
}

int perfsonar_ls_keepalive(const char *url, const char *ls_key) {
	char buf[16384];
	char metadata[2048];
	xmlNodePtr resp_msg;
	xmlChar* xpath;
        xmlXPathContextPtr context;
        xmlXPathObjectPtr result;
	char *eventType;

	metadata[0] = '\0';
	perfsonar_construct_ls_key(metadata, sizeof(metadata), ls_key);

	buf[0] = '\0';
	perfsonar_construct_ls_message(buf, sizeof(buf), "LSKeepaliveRequest", metadata, NULL);	

	if (perfsonar_send_request(url, buf, &resp_msg) != 0) {
		goto error_exit;
	}

	if (perfsonar_xpath_findvalue(resp_msg, "./nmwg:metadata/nmwg:eventType", NULL, &eventType) != 0) {
		goto error_exit_doc;
	}

	if (strncmp(eventType, "success", 7) != 0) {
		printf("Event type != success: %s\n", eventType);
		goto error_exit_ev;
	}

	free(eventType);
	xmlFreeDoc(resp_msg->doc);

	return 0;
	
error_exit_ev:
	free(eventType);
error_exit_doc:
	xmlFreeDoc(resp_msg->doc);
error_exit:
	return -1;
}

int perfsonar_construct_ls_key(char *buf, int buflen, const char *key) {
    strlcat(buf, "<nmwg:key id=\"key1\">", buflen);
    strlcat(buf, "<nmwg:parameters id=\"parameters.1\">", buflen);
    strlfcat(buf, buflen, "<nmwg:parameter name=\"lsKey\">%s</nmwg:parameter>", key);
    strlcat(buf, "</nmwg:parameters>", buflen);
    strlcat(buf, "</nmwg:key>", buflen);
}

int perfsonar_construct_ls_message(char *buf, int buflen, const char *type, const char *metadata, const char *data) {
	int d_id;
	int md_id;
	int msg_id;

	perfsonar_message_start(buf, buflen, 0, type, &msg_id);
	perfsonar_metadata_start(buf, buflen, 0, &md_id);
	if (metadata) {
	strlcat(buf, metadata, buflen);
	}
	perfsonar_metadata_end(buf, buflen);
	perfsonar_data_start(buf, buflen, md_id, 0, &d_id);
	if (data) {
	strlcat(buf, data, buflen);
	}
	perfsonar_data_end(buf, buflen);
	perfsonar_message_end(buf, buflen);

	return 0;
}

int perfsonar_ls_query(const char *url, int *ids, char **xqueries, int xquery_count) {
	char buf[16384];
	int msg_id;
	int i;
	xmlNodePtr resp_msg;

	int buflen = sizeof(buf);

	perfsonar_message_start(buf, buflen, 0, "LSQueryRequest", &msg_id);
	for(i = 0; i < xquery_count; i++) {
		int md_id;

		perfsonar_metadata_start(buf, buflen, ids[i], &md_id);
		strlcat(buf, "<xquery:subject id=\"sub1\">\n", buflen);
		strlcat(buf, xqueries[i], buflen);
		strlcat(buf, "</xquery:subject>\n", buflen);
		strlcat(buf, "<xquery:parameters id=\"params.1\">\n", buflen);
		strlcat(buf, " <nmwg:parameter name=\"lsOutput\">native</nmwg:parameter>\n", buflen);
		strlcat(buf, "</xquery:parameters>\n", buflen);
		perfsonar_event_type_create(buf, buflen, "http://ggf.org/ns/nmwg/tools/org/perfsonar/service/lookup/xquery/1.0</nmwg:eventType>");
		perfsonar_metadata_end(buf, buflen);
		perfsonar_data_start(buf, buflen, ids[i], 0, NULL);
		perfsonar_data_end(buf, buflen);
	}
	perfsonar_message_end(buf, buflen);

	if (perfsonar_send_request(url, buf, &resp_msg) != 0) {
		goto error_exit;
	}

	return 0;

error_exit_resp:
	xmlFreeDoc(resp_msg->doc);
error_exit:
	return -1;
}

static int perfsonar_construct_service(char *buf, int buflen, perfSONARService *service) {
	if (service->service_type == SERVICE_PERFSONAR) {
		return perfsonar_construct_perfsonar_service(buf, buflen, service);
	} else {
		return perfsonar_construct_nonperfsonar_service(buf, buflen, service);
	}
}

static int perfsonar_construct_perfsonar_service(char *buf, int buflen, perfSONARService *service) {
	strlfcat(buf, buflen, "<perfsonar:subject xmlns:perfsonar=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/1.0/\">");
	strlfcat(buf, buflen, "<psservice:service xmlns:psservice=\"http://ggf.org/ns/nmwg/tools/org/perfsonar/service/1.0/\">");
	if (service->name) {
	strlfcat(buf, buflen, "<psservice:serviceName>%s</psservice:serviceName>", service->name);
	}
	if (service->type) {
	strlfcat(buf, buflen, "<psservice:serviceType>%s</psservice:serviceType>", service->type);
	}
	if (service->description) {
	strlfcat(buf, buflen, "<psservice:description>%s</psservice:description>", service->description);
	}
	if (service->accesspoint) {
	strlfcat(buf, buflen, "<psservice:accessPoint>%s</psservice:accessPoint>", service->accesspoint);
	}
	strlfcat(buf, buflen, "</psservice:service>");
	strlfcat(buf, buflen, "</perfsonar:subject>");

	return 0;
}

static int perfsonar_construct_nonperfsonar_service(char *buf, int buflen, perfSONARService *service) {
	int i;
	char *prefix;
	char *ns;

	if (service->namespace == NULL || service->prefix == NULL)
		return -1;

	strlfcat(buf, buflen, "<nmwg:subject>");
	strlfcat(buf, buflen, "<%s:service xmlns:%s=\"%s\">", service->prefix, service->prefix, service->namespace);
	if (service->name) {
	strlfcat(buf, buflen, "<%s:name>%s</%s:name>", service->prefix, service->name, service->prefix);
	}
	if (service->type) {
	strlfcat(buf, buflen, "<%s:type>%s</%s:type>", service->prefix, service->type, service->prefix);
	}
	if (service->name) {
	strlfcat(buf, buflen, "<%s:description>%s</%s:description>", service->prefix, service->description, service->prefix);
	}

	printf("Address count: %d\n", service->address_count);

	for(i = 0; i < service->address_count; i++) {
		strlfcat(buf, buflen, "<%s:address type=\"%s\">%s</%s:address>", service->prefix, service->addresses[i].type, service->addresses[i].address, service->prefix);
	}

	strlfcat(buf, buflen, "</%s:service>", service->prefix);
	strlfcat(buf, buflen, "</nmwg:subject>");

	return 0;
}

static int perfsonar_send_request(const char *url, const char *message, xmlNodePtr *ret_msg) {
	char stuff[16384];
	herror_t status;
	size_t len;
	httpc_conn_t *conn;
	hresponse_t *res;
	int read;
	xmlDocPtr doc;
	xmlChar* xpath;
	xmlXPathContextPtr context;
	xmlXPathObjectPtr result;
	const char *soap_header = " \
 <SOAP-ENV:Envelope xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" \
                   xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" \
                   xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" \
                   xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\"> \
  <SOAP-ENV:Header/> \
  <SOAP-ENV:Body>";

	const char *soap_footer = " \
  </SOAP-ENV:Body> \
 </SOAP-ENV:Envelope>";


	conn = httpc_new();
	if (!conn) {
		goto error_exit;
	}

	httpc_set_header(conn, HEADER_TRANSFER_ENCODING, TRANSFER_ENCODING_CHUNKED);

	printf("httpc_post_begin\n");
	status = httpc_post_begin(conn, url);
	if (status) {
		goto error_exit_conn;
	}
	printf("httpc_post_begin - done\n");

	printf("Sending: \n");
	printf("%s\n", soap_header);
	status = http_output_stream_write(conn->out, soap_header, strlen(soap_header));
	if (status) {
		goto error_exit_conn;
	}

	printf("%s\n", message);
	status = http_output_stream_write(conn->out, message, strlen(message));
	if (status) {
		goto error_exit_conn;
	}

	printf("%s\n", soap_footer);
	status = http_output_stream_write(conn->out, soap_footer, strlen(soap_footer));
	if (status) {
		goto error_exit_conn;
	}

	status = httpc_post_end(conn, &res);

	stuff[0] = '\0';
	read = 0;
	while (http_input_stream_is_ready(res->in)) {
		int n;
		n = http_input_stream_read(res->in, stuff + read, sizeof(stuff) - read);
		read += n;
		stuff[read] = '\0';
	}

	fprintf(stderr, "Response: %s\n", stuff);
	doc = xmlReadMemory(stuff, strlen(stuff), url, NULL, 0);
	if (doc == NULL) {
		goto error_exit_res;
	}

	// find the nmwg:message
	xpath = "//*[local-name()='message' and namespace-uri()='http://ggf.org/ns/nmwg/base/2.0/']";
	context = xmlXPathNewContext(doc);
	result = xmlXPathEvalExpression(xpath, context);

	if (xmlXPathNodeSetIsEmpty(result->nodesetval)) {
		goto error_exit_doc;
	}

	if (xmlXPathNodeSetGetLength(result->nodesetval) != 1) {
		goto error_exit_ctx;
	}

	*ret_msg = xmlXPathNodeSetItem(result->nodesetval, 0);

	xmlXPathFreeContext(context);
	xmlXPathFreeObject(result);
	hresponse_free(res);
	httpc_free(conn);

	return 0;

error_exit_ctx:
	xmlXPathFreeContext(context);
	xmlXPathFreeObject(result);
error_exit_doc:
	xmlFreeDoc(doc);
error_exit_res:
	hresponse_free(res);
error_exit_conn:
	httpc_free(conn);
	herror_release(status);
error_exit:
	return -1;
}

static int perfsonar_xpath_findvalue(xmlNodePtr node, const char *xpath, xmlXPathContextPtr *state_ptr, char **ret_value) {
	xmlXPathObjectPtr result;
	xmlNodePtr curr;

	result = perfsonar_xpath_find(node, xpath, state_ptr);
	if (!result)
		goto error_exit;

	if (xmlXPathNodeSetIsEmpty(result->nodesetval)) {
		printf("node set is empty\n");
		goto error_exit_result;
	}

	if (xmlXPathNodeSetGetLength(result->nodesetval) != 1) {
		printf("node set length: %d\n", xmlXPathNodeSetGetLength(result->nodesetval));
		goto error_exit_result;
	}

	node = xmlXPathNodeSetItem(result->nodesetval, 0);

	for(curr = node->children; curr != NULL; curr = curr->next) {
		if (xmlNodeIsText(curr)) {
			*ret_value = strdup(XML_GET_CONTENT(curr));
			break;
		}
	}

	if (!*ret_value) {
		goto error_exit_result;
	}

	xmlXPathFreeObject(result);

	return 0;

error_exit_result:
	xmlXPathFreeObject(result);
error_exit:
	return -1;
}

static xmlXPathObjectPtr perfsonar_xpath_find(xmlNodePtr node, const char *xpath, xmlXPathContextPtr *state_ptr) {
	xmlXPathContextPtr context;
	xmlXPathObjectPtr result;

	if (state_ptr == NULL || *state_ptr == NULL) {
		context = xmlXPathNewContext(node->doc);
		if (!context) {
			goto error_exit;
		}

		perfsonar_register_namespaces(node, context);
	} else {
		context = *state_ptr;
	}

	context->node = node;
	result = xmlXPathEvalExpression(xpath, context);
	if (!result) {
		goto error_exit;
	}

	if (state_ptr) {
		*state_ptr = context;
	} else {
		xmlXPathFreeContext(context);
	}

	return result;

error_exit:
	return NULL;
}

static void perfsonar_register_namespaces(xmlNodePtr node, xmlXPathContextPtr context) {
	xmlNsPtr ns;
	xmlNodePtr curr;

	for(ns = node->nsDef; ns != NULL; ns = ns->next) {
		xmlXPathRegisterNs(context, ns->prefix, ns->href);
	}

	for(curr = node->children; curr != NULL; curr = curr->next) {
		perfsonar_register_namespaces(curr, context);
	}
}
