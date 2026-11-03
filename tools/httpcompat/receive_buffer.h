#ifndef VOX_HTTP_RECEIVE_BUFFER_H
#define VOX_HTTP_RECEIVE_BUFFER_H
#include <stdint.h>
#include <stdlib.h>

// Only the receive loop's byte accumulator uses this storage. V owns the
// published response, request callbacks, pooled connections and TLS objects.
static void *vox_http_receive_buffer_resize(void *bytes, uint64_t size) {
    if (size > SIZE_MAX) return NULL;
    return realloc(bytes, (size_t)size);
}

static void vox_http_receive_buffer_free(void *bytes) {
    free(bytes);
}
#endif
