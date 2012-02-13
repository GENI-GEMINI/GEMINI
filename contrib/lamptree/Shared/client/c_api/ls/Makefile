# Add the libxml2 cflags
CFLAGS += `xml2-config --cflags`

# Add the libsoap cflags
CFLAGS += -I../libsoap-1.1.0

all:
	gcc -c perfsonar_ls_client.c -o perfsonar_ls_client.o ${CFLAGS}
	gcc -c perfsonar_messages.c -o perfsonar_messages.o ${CFLAGS}
	gcc -c perfsonar_service.c -o perfsonar_service.o ${CFLAGS}
	ar rcs libperfsonar_ls_client.a   perfsonar_service.o perfsonar_ls_client.o perfsonar_messages.o ../libsoap-1.1.0/nanohttp/libnanohttp.a

clean:
	rm *.o *.a
