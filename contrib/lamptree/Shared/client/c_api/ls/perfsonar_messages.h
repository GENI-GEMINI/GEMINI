#ifndef PERFSONAR_MESSAGES_H
#define PERFSONAR_MESSAGES_H

int perfsonar_message_start(char *buf, int buflen, int id, const char *type, int *ret_id);
int perfsonar_message_end(char *buf, int buflen);
int perfsonar_event_type_create(char *buf, int buflen, const char *event_type);
int perfsonar_metadata_start(char *buf, int buflen, int id, int *ret_id);
int perfsonar_metadata_end(char *buf, int buflen);
int perfsonar_data_start(char *buf, int buflen, int metadataIdRef, int id, int *ret_id);
int perfsonar_data_end(char *buf, int buflen);

#endif
