#ifndef VOX_NATIVE_SNAPSHOT_PNG_DEFLATE_DARWIN_H
#define VOX_NATIVE_SNAPSHOT_PNG_DEFLATE_DARWIN_H

#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

typedef struct {
    int (*initialize)(z_streamp, int, int, int, int, int, const char *, int);
    int (*compress)(z_streamp, int);
    int (*release)(z_streamp);
    uLong (*bound)(z_streamp, uLong);
    uLong (*checksum)(uLong, const Bytef *, uInt);
    uLong (*combine)(uLong, uLong, z_off_t);
} VoxSnapshotZlib;

static void native_snapshot_load_zlib(void *context)
{
    VoxSnapshotZlib *api = (VoxSnapshotZlib *)context;
    void *library = dlopen("/usr/lib/libz.1.dylib", RTLD_LAZY | RTLD_LOCAL);
    if (!library) return;
    VoxSnapshotZlib found = {
        dlsym(library, "deflateInit2_"), dlsym(library, "deflate"), dlsym(library, "deflateEnd"),
        dlsym(library, "deflateBound"), dlsym(library, "adler32"), dlsym(library, "adler32_combine")
    };
    if (!(found.initialize && found.compress && found.release && found.bound
          && found.checksum && found.combine)) {
        dlclose(library);
        return;
    }
    // Keep the library loaded for the lifetime of these function pointers.
    *api = found;
}

typedef struct {
    const uint8_t *pixels;
    const VoxSnapshotZlib *api;
    size_t row_bytes, pitch, rows;
    uint8_t *compressed;
    size_t written;
    uLong checksum;
    int last;
} VoxSnapshotDeflateBand;

static void native_snapshot_deflate_band(void *context, size_t lane)
{
    VoxSnapshotDeflateBand *band = (VoxSnapshotDeflateBand *)context + lane;
    const VoxSnapshotZlib *api = band->api;
    size_t stride = band->row_bytes + 1;
    size_t size = stride * band->rows;
    uint8_t *input = malloc(size);
    if (!input) return;
    for (size_t row = 0; row < band->rows; ++row) {
        uint8_t *scanline = input + row * stride;
        scanline[0] = 0;
        memcpy(scanline + 1, band->pixels + row * band->pitch, band->row_bytes);
    }

    z_stream stream = {0};
    int status = api->initialize(&stream, Z_BEST_SPEED, Z_DEFLATED, -15, 8,
        Z_DEFAULT_STRATEGY, ZLIB_VERSION, sizeof stream);
    if (status == Z_OK) {
        // Allow for the byte-alignment block at the end of each nonfinal band.
        stream.avail_out = (uInt)api->bound(&stream, (uLong)size) + 8;
        band->compressed = malloc(stream.avail_out);
        if (band->compressed) {
            stream.next_in = input;
            stream.avail_in = (uInt)size;
            stream.next_out = band->compressed;
            status = api->compress(&stream, band->last ? Z_FINISH : Z_SYNC_FLUSH);
            if (status == (band->last ? Z_STREAM_END : Z_OK) && !stream.avail_in && stream.avail_out) {
                band->written = stream.total_out;
                band->checksum = api->checksum(1, input, (uInt)size);
            }
        }
        api->release(&stream);
    }
    free(input);
}

// Each band writes independent raw DEFLATE blocks. Sync flush leaves every
// nonfinal band at a byte boundary. The last band sets BFINAL, and the joined
// stream gets one zlib header and one Adler-32 over all filtered scanlines.
static uint8_t *native_snapshot_deflate_rows(const uint8_t *pixels, size_t row_bytes,
    size_t height, size_t pitch, size_t *written)
{
    *written = 0;
    const size_t max_bytes = 64u * 1024u * 1024u;
    if (!pixels || !row_bytes || !height || row_bytes >= max_bytes
        || height > max_bytes / (row_bytes + 1) || pitch < row_bytes || pitch > SIZE_MAX / height)
        return NULL;
    size_t stride = row_bytes + 1;
    size_t lanes = stride * height / (2u * 1024u * 1024u);
    if (lanes > 4) lanes = 4;
    if (lanes > height) lanes = height;
    if (lanes < 2 || getenv("VOX_SERIAL_SNAPSHOT_PNG")) return NULL;

    static dispatch_once_t once;
    static VoxSnapshotZlib api;
    dispatch_once_f(&once, &api, native_snapshot_load_zlib);
    if (!api.initialize) return NULL;
    VoxSnapshotDeflateBand bands[4] = {0};
    for (size_t lane = 0; lane < lanes; ++lane) {
        size_t first = height * lane / lanes, last = height * (lane + 1) / lanes;
        bands[lane] = (VoxSnapshotDeflateBand){.pixels = pixels + first * pitch, .api = &api,
            .row_bytes = row_bytes, .pitch = pitch, .rows = last - first, .last = lane + 1 == lanes};
    }
    dispatch_apply_f(lanes, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),
        bands, native_snapshot_deflate_band);

    size_t size = 6; // zlib header and Adler-32 trailer
    for (size_t lane = 0; lane < lanes; ++lane) {
        if (!bands[lane].written) {
            size = 0;
            break;
        }
        size += bands[lane].written;
    }
    uint8_t *result = size ? malloc(size) : NULL;
    if (result) {
        result[0] = 0x78; result[1] = 0x01;
        size_t offset = 2;
        uLong adler = 1;
        for (size_t lane = 0; lane < lanes; ++lane) {
            const VoxSnapshotDeflateBand *band = &bands[lane];
            memcpy(result + offset, band->compressed, band->written);
            offset += band->written;
            adler = api.combine(adler, band->checksum, (z_off_t)(stride * band->rows));
        }
        result[offset] = (uint8_t)(adler >> 24);
        result[offset + 1] = (uint8_t)(adler >> 16);
        result[offset + 2] = (uint8_t)(adler >> 8);
        result[offset + 3] = (uint8_t)adler;
        *written = size;
    }
    for (size_t lane = 0; lane < lanes; ++lane) free(bands[lane].compressed);
    return result;
}

#endif
