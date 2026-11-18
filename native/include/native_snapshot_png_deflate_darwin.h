#ifndef VOX_NATIVE_SNAPSHOT_PNG_DEFLATE_DARWIN_H
#define VOX_NATIVE_SNAPSHOT_PNG_DEFLATE_DARWIN_H

#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>
#include "native_crc32.h"

static void native_png_write_u32(uint8_t *bytes, uint32_t value)
{
    bytes[0] = value >> 24; bytes[1] = value >> 16;
    bytes[2] = value >> 8; bytes[3] = value;
}

typedef struct {
    int (*initialize)(z_streamp, int, int, int, int, int, const char *, int);
    int (*compress)(z_streamp, int);
    int (*release)(z_streamp);
    uLong (*bound)(z_streamp, uLong);
    uLong (*combine)(uLong, uLong, z_off_t);
} VoxSnapshotZlib;

static void native_snapshot_load_zlib(void *context)
{
    VoxSnapshotZlib *api = (VoxSnapshotZlib *)context;
    void *library = dlopen("/usr/lib/libz.1.dylib", RTLD_LAZY | RTLD_LOCAL);
    if (!library) return;
    VoxSnapshotZlib found = {
        dlsym(library, "deflateInit2_"), dlsym(library, "deflate"), dlsym(library, "deflateEnd"),
        dlsym(library, "deflateBound"), dlsym(library, "adler32_combine")
    };
    if (!(found.initialize && found.compress && found.release && found.bound && found.combine)) {
        dlclose(library);
        return;
    }
    // Keep the library loaded for the lifetime of these function pointers.
    *api = found;
}

typedef struct {
    uint8_t *bytes;
    size_t size;
} VoxSnapshotIDAT;

typedef struct {
    const uint8_t *pixels;
    const VoxSnapshotZlib *api;
    size_t row_bytes, pitch, rows;
    VoxSnapshotIDAT chunk;
    uLong checksum;
    uint32_t crc;
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
    int status = api->initialize(&stream, Z_BEST_SPEED, Z_DEFLATED, 15, 8,
        Z_DEFAULT_STRATEGY, ZLIB_VERSION, sizeof stream);
    if (status == Z_OK) {
        // Allow for the byte-alignment block at the end of each nonfinal band.
        stream.avail_out = (uInt)api->bound(&stream, (uLong)size) + 8;
        uint8_t *bytes = malloc((size_t)stream.avail_out + 12);
        band->chunk.bytes = bytes;
        if (bytes) {
            // Reserve the length and IDAT tag. From the second band onward,
            // let zlib write its header into the space reserved for the tag.
            size_t skip = lane ? 2 : 0;
            stream.next_in = input;
            stream.avail_in = (uInt)size;
            stream.next_out = bytes + 8 - skip;
            status = api->compress(&stream, band->last ? Z_FINISH : Z_SYNC_FLUSH);
            if (status == (band->last ? Z_STREAM_END : Z_OK) && !stream.avail_in && stream.avail_out) {
                size_t payload = stream.total_out - skip;
                native_png_write_u32(bytes, (uint32_t)payload);
                memcpy(bytes + 4, "IDAT", 4);
                // The last four payload bytes will become the Adler-32 for
                // the whole stream. Leave that part of the final CRC open.
                band->crc = vox_crc32(0, bytes + 4, 4 + payload - (band->last ? 4 : 0));
                if (!band->last) native_png_write_u32(bytes + 8 + payload, band->crc);
                band->checksum = stream.adler;
                band->chunk.size = payload + 12;
            }
        }
        api->release(&stream);
    }
    free(input);
}

// PNG feeds consecutive IDAT payloads to one inflater. Each nonfinal band
// ends at a sync-flush boundary. Only the first supplies a zlib header and
// only the last finishes DEFLATE and supplies the combined Adler-32.
// On success the caller owns the returned chunks' bytes.
static size_t native_snapshot_deflate_rows(const uint8_t *pixels, size_t row_bytes,
    size_t height, size_t pitch, VoxSnapshotIDAT chunks[4])
{
    const size_t max_bytes = 64u * 1024u * 1024u;
    if (!pixels || !row_bytes || !height || row_bytes >= max_bytes
        || height > max_bytes / (row_bytes + 1) || pitch < row_bytes || pitch > SIZE_MAX / height)
        return 0;
    size_t stride = row_bytes + 1;
    size_t lanes = stride * height / (2u * 1024u * 1024u);
    if (lanes > 4) lanes = 4;
    if (lanes > height) lanes = height;
    if (lanes < 2 || getenv("VOX_SERIAL_SNAPSHOT_PNG")) return 0;

    static dispatch_once_t once;
    static VoxSnapshotZlib api;
    dispatch_once_f(&once, &api, native_snapshot_load_zlib);
    if (!api.initialize) return 0;
    VoxSnapshotDeflateBand bands[4] = {0};
    for (size_t lane = 0; lane < lanes; ++lane) {
        size_t first = height * lane / lanes, last = height * (lane + 1) / lanes;
        bands[lane] = (VoxSnapshotDeflateBand){.pixels = pixels + first * pitch, .api = &api,
            .row_bytes = row_bytes, .pitch = pitch, .rows = last - first, .last = lane + 1 == lanes};
    }
    dispatch_apply_f(lanes, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0),
        bands, native_snapshot_deflate_band);

    uLong adler = 1;
    for (size_t lane = 0; lane < lanes; ++lane) {
        if (!bands[lane].chunk.size) {
            for (size_t index = 0; index < lanes; ++index) free(bands[index].chunk.bytes);
            return 0;
        }
        adler = api.combine(adler, bands[lane].checksum, (z_off_t)(stride * bands[lane].rows));
    }
    const VoxSnapshotDeflateBand *last = &bands[lanes - 1];
    uint8_t *trailer = last->chunk.bytes + last->chunk.size - 8;
    native_png_write_u32(trailer, (uint32_t)adler);
    native_png_write_u32(trailer + 4, vox_crc32(last->crc, trailer, 4));
    for (size_t lane = 0; lane < lanes; ++lane) chunks[lane] = bands[lane].chunk;
    return lanes;
}

#endif
