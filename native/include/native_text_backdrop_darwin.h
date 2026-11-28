#ifndef VOX_NATIVE_TEXT_BACKDROP_DARWIN_H
#define VOX_NATIVE_TEXT_BACKDROP_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <math.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "../../cpuraster/scan_workers.h"

typedef struct {
    const uint8_t *source;
    size_t pitch, row_bytes;
    int rows;
} VoxTextBackdrop;

static bool vox_text_backdrop_source(CGContextRef context, int left, int top,
    int width, int height, float scale, VoxTextBackdrop *backdrop) {
    if (!context || left < 0 || top < 0 || width <= 0 || height <= 0
        || !(isfinite(scale) && scale > 0)) return false;
    size_t bitmap_width = CGBitmapContextGetWidth(context);
    size_t bitmap_height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    double x = roundf(left * scale), y = roundf(top * scale);
    if ((size_t)width > bitmap_width || (size_t)height > bitmap_height
        || !(x <= bitmap_width - (size_t)width && y <= bitmap_height - (size_t)height)
        || bitmap_width > pitch / 4 || pitch > SIZE_MAX / bitmap_height) return false;
    CGContextFlush(context);
    const uint8_t *data = (const uint8_t *)CGBitmapContextGetData(context);
    if (!data) return false;
    *backdrop = (VoxTextBackdrop){data + (size_t)y * pitch + (size_t)x * 4,
        pitch, (size_t)width * 4, height};
    return true;
}

static void vox_copy_text_backdrop(VoxTextBackdrop backdrop, uint8_t *destination) {
    for (size_t row = 0; row < (size_t)backdrop.rows; ++row)
        memcpy(destination + row * backdrop.row_bytes, backdrop.source + row * backdrop.pitch,
            backdrop.row_bytes);
}

typedef struct {
    VoxTextBackdrop backdrop;
    uint8_t *destination;
    void *ticket;
    uint64_t thread;
    uint64_t started;
    bool diagnostics;
} VoxTextBackdropCopy;

static void vox_text_backdrop_worker(void *context, int32_t first, int32_t end) {
    (void)first; (void)end;
    VoxTextBackdropCopy *copy = (VoxTextBackdropCopy *)context;
    if (copy->diagnostics) {
        pthread_threadid_np(NULL, &copy->thread);
        copy->started = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    }
    vox_copy_text_backdrop(copy->backdrop, copy->destination);
}

// The browser thread keeps both bitmaps alive and leaves their pixels alone
// until the join. The worker never accesses the CGContext or graphics state.
static VoxTextBackdropCopy *vox_start_text_backdrop_copy(CGContextRef context, uint8_t *destination,
    int left, int top, int width, int height, float scale) {
    if (!destination || width <= 0 || height <= 0 || (uint64_t)width * height * 4 < 128 * 1024
        || vox_scan_workers_disabled()) return NULL;
    VoxTextBackdrop backdrop;
    if (!vox_text_backdrop_source(context, left, top, width, height, scale, &backdrop)) return NULL;
    VoxTextBackdropCopy *copy = (VoxTextBackdropCopy *)malloc(sizeof *copy);
    if (!copy) return NULL;
    *copy = (VoxTextBackdropCopy){.backdrop = backdrop, .destination = destination,
        .diagnostics = getenv("VOX_GLYPH_BACKDROP_COPY_DIAGNOSTICS") != NULL};
    copy->ticket = vox_scan_worker_start(copy, 1, 1, false, false, vox_text_backdrop_worker);
    if (!copy->ticket) { free(copy); return NULL; }
    return copy;
}

static void vox_finish_text_backdrop_copy(VoxTextBackdropCopy *copy) {
    if (!copy) return;
    uint64_t joining = copy->diagnostics ? clock_gettime_nsec_np(CLOCK_UPTIME_RAW) : 0;
    bool ready = vox_scan_worker_join(copy->ticket);
    if (copy->diagnostics) {
        uint64_t waited = clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - joining;
        uint64_t caller = 0;
        pthread_threadid_np(NULL, &caller);
        fprintf(stderr, "VOX_GLYPH_BACKDROP_COPY bytes=%zu off_thread=%d ready_at_join=%d started_before_join=%d wait_ns=%llu\n",
            copy->backdrop.row_bytes * (size_t)copy->backdrop.rows,
            copy->thread != 0 && copy->thread != caller, ready, copy->started < joining,
            (unsigned long long)waited);
    }
    free(copy);
}

#ifdef __OBJC__
#import <AppKit/NSGraphicsContext.h>

static void *native_document_start_text_backdrop_copy(uint8_t *pixels, int left, int top,
    int width, int height, float scale) {
    return vox_start_text_backdrop_copy(NSGraphicsContext.currentContext.CGContext,
        pixels, left, top, width, height, scale);
}

static void native_document_finish_text_backdrop_copy(void *ticket) {
    vox_finish_text_backdrop_copy((VoxTextBackdropCopy *)ticket);
}
#endif

#endif
