/******************************************************************
*  $Id: httppost.c,v 1.3 2004/08/26 17:02:24 rans Exp $
*
* CSOAP Project:  A http client/server library in C (example)
* Copyright (C) 2003  Ferhat Ayaz
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Library General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Library General Public License for more details.
*
* You should have received a copy of the GNU Library General Public
* License along with this library; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA  02111-1307, USA.
* 
* Email: ayaz@jprogrammer.net
******************************************************************/
#include <nanohttp/nanohttp-client.h>

#ifdef WIN32
#include <stdafx.h>
#include <malloc.h>
#else
#include <stdio.h>
#endif

#ifdef WIN32
int _tmain(int argc, _TCHAR* argv[])
#else
int main(int argc, char *argv[])
#endif
{
	httpc_conn_t *conn;
	hresponse_t *res;
	hpair_t *pair;
	char postdata[1054];

	if (argc < 2) {
		fprintf(stderr, "usage %s <url> \n", argv[0]);
		exit(1);
	}

	log_set_level(HLOG_VERBOSE);

	printf("\nEnter post data (max 1054): ");
	gets(postdata);
	printf("\nSending data to '%s'. Please wait ...\n ", argv[1]);

	log_debug2("you entered: '%s'", postdata);
	log_debug2("content-length: %d", strlen(postdata));

	conn = httpc_new();
	res = httpc_post(conn, argv[1], strlen(postdata), postdata);

	if (res != NULL) {
		log_info2("Spec  : '%s'", res->spec);
		log_info2("Status: %d", res->errcode);
		log_info2("Desc  : '%s'", res->desc);

		if (res->body) {
			pair = res->header;
			while (pair != NULL) {
				log_debug3("%s: %s", pair->key, pair->value);
				pair = pair->next;
			}
			puts(res->body);
		}
		else
			log_error1("body is null");

		hresponse_free(res);
	} else {
		log_error1("response object is null");
	}

	httpc_free(conn);
	return 0;
}
