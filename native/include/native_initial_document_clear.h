#ifndef VOX_NATIVE_INITIAL_DOCUMENT_CLEAR_H
#define VOX_NATIVE_INITIAL_DOCUMENT_CLEAR_H
#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "native_frame_clear_darwin.h"

// A capability for the first paint of a fresh, privately owned document
// bitmap. The embedding adapter grants it only with default graphics state;
// clips/transparency and the first rectangle consume it. No published image
// or retained scrolling surface may grant this capability.
typedef struct {
    CGContextRef context;
    CGFloat width, height;
    bool completed;
} VoxInitialDocumentClear;

static void vox_initial_document_clear_disarm(VoxInitialDocumentClear *state, CGContextRef context) {
    if (state->context == context) state->context = NULL;
}

static bool vox_initial_document_clear_layout(const VoxInitialDocumentClear *state,
    CGContextRef context, CGRect rect, VoxFrameClear *clear) {
    if (!context || context != state->context) return false;
    static int disabled = -1;
    if (disabled < 0) { const char *value = getenv("VOX_DISABLE_INITIAL_DOCUMENT_CLEAR"); disabled = value && *value; }
    if (disabled
        || !CGRectEqualToRect(rect, CGRectMake(0, 0, state->width, state->height))
        || !CGRectEqualToRect(CGContextGetClipBoundingBox(context), rect)
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || CGBitmapContextGetBitmapInfo(context) !=
            ((CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)) return false;
    CGAffineTransform ctm = CGContextGetCTM(context);
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    if (ctm.b != 0 || ctm.c != 0 || ctm.tx != 0 || ctm.ty != 0
        || !(ctm.a > 0 && ctm.d > 0) || state->width * ctm.a != (CGFloat)width
        || state->height * ctm.d != (CGFloat)height
        || width > SIZE_MAX / 4 || pitch < width * 4 || (height && pitch > SIZE_MAX / height)) return false;
    *clear = (VoxFrameClear){NULL, width * 4, pitch, height, 1, 255};
    return true;
}

static int vox_initial_document_clear(VoxInitialDocumentClear *state, CGContextRef context,
    CGRect rect, uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha) {
    if (!context || context != state->context) return 0;
    VoxFrameClear clear;
    bool white = red == 255 && green == 255 && blue == 255 && alpha == 255;
    bool eligible = white && vox_initial_document_clear_layout(state, context, rect, &clear);
    state->context = NULL;
    if (!eligible) return 0;
    if (!state->completed) {
        CGContextFlush(context);
        clear.pixels = (uint8_t *)CGBitmapContextGetData(context);
        if (!clear.pixels) return 0;
        vox_clear_frame_rows(clear.pixels, clear.row_bytes, clear.pitch, clear.rows);
    }
    const char *diagnostics = getenv("VOX_INITIAL_DOCUMENT_CLEAR_DIAGNOSTICS");
    if (diagnostics && *diagnostics) fprintf(stderr, "VOX_INITIAL_DOCUMENT_CLEAR width=%zu height=%zu\n",
        clear.row_bytes / 4, clear.rows);
    return 1;
}

typedef struct {
    VoxFrameClear clear;
    CGContextRef context;
    void *group;
} VoxInitialDocumentClearWork;

// The caller reserves this private bitmap through the join and may only do
// setup that does not read or write its pixels while the ticket is running.
static VoxInitialDocumentClearWork *vox_start_initial_document_clear(
    const VoxInitialDocumentClear *state, CGContextRef context, CGRect rect) {
    VoxFrameClear clear;
    const char *serial = getenv("VOX_SERIAL_CPU_RASTER");
    if (state->completed || getenv("VOX_SERIAL_FRAME_CLEAR") || (serial && strcmp(serial, "1") == 0)
        || !vox_initial_document_clear_layout(state, context, rect, &clear))
        return NULL;
    clear.lanes = vox_frame_clear_lanes(clear.row_bytes, clear.rows);
    if (clear.lanes < 2) return NULL;
    CGContextFlush(context);
    clear.pixels = (uint8_t *)CGBitmapContextGetData(context);
    if (!clear.pixels) return NULL;
    VoxInitialDocumentClearWork *work = (VoxInitialDocumentClearWork *)malloc(sizeof *work);
    if (!work) return NULL;
    work->clear = clear;
    work->context = context;
    dispatch_group_t group = dispatch_group_create();
    if (!group) { free(work); return NULL; }
#if __has_feature(objc_arc)
    work->group = (__bridge_retained void *)group;
#else
    work->group = (void *)group;
#endif
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    for (size_t lane = 0; lane < clear.lanes; ++lane)
        dispatch_group_async(group, queue, ^{ vox_frame_clear_range(&work->clear, lane); });
    return work;
}

static void vox_finish_initial_document_clear(VoxInitialDocumentClear *state,
    VoxInitialDocumentClearWork *work) {
    if (!work) return;
#if __has_feature(objc_arc)
    dispatch_group_t group = (__bridge_transfer dispatch_group_t)work->group;
#else
    dispatch_group_t group = (dispatch_group_t)work->group;
#endif
    bool ready = dispatch_group_wait(group, DISPATCH_TIME_NOW) == 0;
    if (!ready) dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
#if !__has_feature(objc_arc)
    dispatch_release(group);
#endif
    if (state->context == work->context) state->completed = true;
    const char *diagnostics = getenv("VOX_INITIAL_DOCUMENT_CLEAR_DIAGNOSTICS");
    if (diagnostics && *diagnostics) fprintf(stderr,
        "VOX_INITIAL_DOCUMENT_CLEAR_OVERLAP bytes=%zu lanes=%zu ready_at_join=%d\n",
        work->clear.row_bytes * work->clear.rows, work->clear.lanes, (int)ready);
    free(work);
}
#endif
