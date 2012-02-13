#ifndef PERFSONAR_SERVICE_H
#define PERFSONAR_SERVICE_H

typedef struct perfsonar_address_t {
	char *address;
	char *type;
} perfSONARAddress;

enum perfsonar_service_type { SERVICE_NONPERFSONAR, SERVICE_PERFSONAR };

typedef struct perfsonar_service_t {
	enum perfsonar_service_type service_type;

	char *prefix;
	char *namespace;

	char *name;
	char *type;
	char *description;
	char *accesspoint;

	char *eventType;

	perfSONARAddress *addresses;
	int address_count;
} perfSONARService;

perfSONARService *perfsonar_service_alloc(enum perfsonar_service_type type);
void perfsonar_service_free(perfSONARService *service);

int perfsonar_service_set_prefix(perfSONARService *service, const char *prefix);
int perfsonar_service_set_namespace(perfSONARService *service, const char *namespace);
int perfsonar_service_set_accesspoint(perfSONARService *service, const char *accesspoint);
int perfsonar_service_set_description(perfSONARService *service, const char *description);
int perfsonar_service_set_name(perfSONARService *service, const char *name);
int perfsonar_service_set_type(perfSONARService *service, const char *type);
int perfsonar_service_add_address(perfSONARService *service, const char *type, const char *address);

#endif
