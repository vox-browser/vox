// SPDX-License-Identifier: BSD-2-Clause
#ifndef VOX_COMPRESSION_NATIVE_DECODER_H
#define VOX_COMPRESSION_NATIVE_DECODER_H
#include <stdlib.h>
#include <zlib.h>

// Brotli is decoded and encoded in V (compression/brotli.v); this context only
// streams the zlib-family formats.
typedef struct {
    z_stream z;
} VoxDecompressionContext;

// format: 1 deflate, 2 deflate-raw, 3 gzip.
static void *vox_decompression_create(int format) {
    VoxDecompressionContext *s = calloc(1, sizeof(*s));
    if (!s) return NULL;
    if (inflateInit2(&s->z, format == 1 ? 15 : format == 2 ? -15 : 31) != Z_OK) {
        free(s);
        return NULL;
    }
    return s;
}

static void vox_decompression_destroy(void *context) {
    VoxDecompressionContext *s = context;
    if (!s) return;
    inflateEnd(&s->z);
    free(s);
}

// 0: needs input, 1: end, 2: needs output, -1: invalid input.
// Preserve produced bytes even when this call also detects invalid input.
static int vox_decompression_step(void *context, const unsigned char *input,
        size_t length, size_t *consumed, unsigned char *output,
        size_t capacity, size_t *produced) {
    VoxDecompressionContext *s = context;
    s->z.next_in = (Bytef *)input;
    s->z.avail_in = (uInt)length;
    s->z.next_out = output;
    s->z.avail_out = (uInt)capacity;
    int result = inflate(&s->z, Z_NO_FLUSH);
    *consumed = length - s->z.avail_in;
    *produced = capacity - s->z.avail_out;
    // Never retain a pointer into the caller's temporary V or JS buffers.
    s->z.next_in = NULL;
    s->z.next_out = NULL;
    if (result == Z_STREAM_END) return 1;
    if (result != Z_OK && result != Z_BUF_ERROR) return -1;
    return *produced == capacity ? 2 : 0;
}
#endif
