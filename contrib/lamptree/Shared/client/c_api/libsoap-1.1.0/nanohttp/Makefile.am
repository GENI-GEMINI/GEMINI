noinst_LIBRARIES=libnanohttp.a

libnanohttp_adir=$(includedir)/nanohttp-@nanohttp_release@/nanohttp

libnanohttp_a_SOURCES=nanohttp-common.c nanohttp-socket.c nanohttp-client.c     \
                           nanohttp-server.c nanohttp-stream.c nanohttp-mime.c   \
                           nanohttp-request.c nanohttp-response.c                \
                           nanohttp-base64.c nanohttp-ssl.c nanohttp-logging.c

libnanohttp_a_HEADERS=nanohttp-common.h nanohttp-socket.h nanohttp-client.h     \
                           nanohttp-server.h nanohttp-stream.h nanohttp-mime.h   \
                           nanohttp-request.h nanohttp-response.h                \
                           nanohttp-base64.h nanohttp-ssl.h nanohttp-logging.h

libnanohttp_a_CFLAGS=-I${top_srcdir}
