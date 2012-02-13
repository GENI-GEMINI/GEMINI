#include "perfsonar_messages.h"
#include "perfsonar_misc.h"

int perfsonar_message_start(char *buf, int buflen, int id, const char *type, int *ret_id) {
	int i;

	if (id == 0) {
		id = rand() % 1000000;
	}

	*ret_id = id;

	strlfcat(buf, buflen, "<nmwg:message type=\"%s\" id=\"%d\" xmlns:nmwg=\"http://ggf.org/ns/nmwg/base/2.0/\">", type, id);

	return 0;
}

int perfsonar_message_end(char *buf, int buflen) {
	strlfcat(buf, buflen, "</nmwg:message>");

	return 0;
}

int perfsonar_event_type_create(char *buf, int buflen, const char *event_type) {

	strlfcat(buf, buflen, "<nmwg:eventType>%s</nmwg:eventType>", event_type);

	return 0;
}

int perfsonar_metadata_start(char *buf, int buflen, int id, int *ret_id) {
	int i;

	if (id == 0) {
		id = rand() % 1000000;
	}

	*ret_id = id;

	strlfcat(buf, buflen, "<nmwg:metadata id=\"%d\">", id);

	return 0;
}

int perfsonar_metadata_end(char *buf, int buflen) {
	strlfcat(buf, buflen, "</nmwg:metadata>");

	return 0;
}

int perfsonar_data_start(char *buf, int buflen, int metadataIdRef, int id, int *ret_id) {
	int i;

	if (id == 0) {
		id = rand() % 1000000;
	}

	*ret_id = id;

	strlfcat(buf, buflen, "<nmwg:data metadataIdRef=\"%d\" id=\"%d\">", metadataIdRef, id);

	return 0;
}

int perfsonar_data_end(char *buf, int buflen) {
	strlfcat(buf, buflen, "</nmwg:data>");

	return 0;
}
