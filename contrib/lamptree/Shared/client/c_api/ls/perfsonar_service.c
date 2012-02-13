#include <stdlib.h>

#include "perfsonar_service.h"

int perfsonar_service_set_namespace(perfSONARService *service, const char *namespace) {
	char *new_namespace;

	if (namespace == NULL) {
		if (service->namespace != NULL)
			free(service->namespace);
		service->namespace = NULL;

		return;
	}

	new_namespace = strdup(namespace);
	if (!new_namespace)
		goto error_exit;

	if (service->namespace)
		free(service->namespace);

	service->namespace = new_namespace;

	return 0;

error_exit:
	return -1;
}

int perfsonar_service_set_prefix(perfSONARService *service, const char *prefix) {
	char *new_prefix;

	if (prefix == NULL) {
		if (service->prefix!= NULL)
			free(service->prefix);
		service->prefix = NULL;

		return;
	}

	new_prefix = strdup(prefix);
	if (!new_prefix)
		goto error_exit;

	if (service->prefix)
		free(service->prefix);

	service->prefix = new_prefix;

	return 0;

error_exit:
	return -1;
}

int perfsonar_service_set_accesspoint(perfSONARService *service, const char *accesspoint) {
	char *new_accesspoint;

	if (accesspoint == NULL) {
		if (service->accesspoint != NULL)
			free(service->accesspoint);
		service->accesspoint = NULL;

		return;
	}

	new_accesspoint = strdup(accesspoint);
	if (!new_accesspoint)
		goto error_exit;

	if (service->accesspoint)
		free(service->accesspoint);

	service->accesspoint = new_accesspoint;

	return 0;

error_exit:
	return -1;
}

int perfsonar_service_set_description(perfSONARService *service, const char *description) {
	char *new_description;

	if (description == NULL) {
		if (service->description != NULL)
			free(service->description);
		service->description = NULL;

		return;
	}

	new_description = strdup(description);
	if (!new_description)
		goto error_exit;

	if (service->description)
		free(service->description);

	service->description = new_description;

	return 0;

error_exit:
	return -1;
}

int perfsonar_service_set_name(perfSONARService *service, const char *name) {
	char *new_name;

	if (name == NULL) {
		if (service->name != NULL)
			free(service->name);
		service->name = NULL;

		return;
	}

	new_name = strdup(name);
	if (!new_name)
		goto error_exit;

	if (service->name)
		free(service->name);

	service->name = new_name;

	return 0;

error_exit:
	return -1;
}

int perfsonar_service_set_type(perfSONARService *service, const char *type) {
	char *new_type;

	if (type == NULL) {
		if (service->type != NULL)
			free(service->type);
		service->type = NULL;

		return;
	}

	new_type = strdup(type);
	if (!new_type)
		goto error_exit;

	if (service->type)
		free(service->type);

	service->type = new_type;

	return 0;

error_exit:
	return -1;
}

int perfsonar_service_add_address(perfSONARService *service, const char *type, const char *address) {
	perfSONARAddress *new_addrlist;

	new_addrlist = realloc(service->addresses, sizeof(perfSONARAddress) * (service->address_count + 1));
	if (!new_addrlist)
		goto error_exit;

	new_addrlist[service->address_count].type = strdup(type);
	new_addrlist[service->address_count].address = strdup(address);

	service->addresses = new_addrlist;
	service->address_count++;

	return 0;

error_exit:
	return -1;
}

perfSONARService *perfsonar_service_alloc(enum perfsonar_service_type type) {
	perfSONARService *service;

	service = malloc(sizeof(*service));
	if (!service)
		goto error_exit;

	bzero(service, sizeof(*service));

	service->service_type = type;

	return service;

error_exit_service:
	perfsonar_service_free(service);
error_exit:
	return NULL;
}

void perfsonar_service_free(perfSONARService *service) {
	if (service->namespace)
		free(service->namespace);
	if (service->prefix)
		free(service->prefix);
	if (service->name)
		free(service->name);
	if (service->type)
		free(service->type);
	if (service->description)
		free(service->description);
	if (service->accesspoint)
		free(service->accesspoint);
	if (service->addresses)
		free(service->addresses);

	free(service);
}
