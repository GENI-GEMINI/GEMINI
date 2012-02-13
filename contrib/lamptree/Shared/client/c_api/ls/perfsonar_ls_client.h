#ifndef PERFSONAR_LS_CLIENT_H
#define PERFSONAR_LS_CLIENT_H

#include "perfsonar_service.h"

int perfsonar_ls_register(const char *url, perfSONARService *service, char **metadata, int metadata_count, char **ls_key);
int perfsonar_ls_keepalive(const char *url, const char *ls_key);

#endif
