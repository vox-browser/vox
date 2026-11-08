#ifndef VOX_NATIVE_INITIAL_DOCUMENT_CLEAR_H
#define VOX_NATIVE_INITIAL_DOCUMENT_CLEAR_H
#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// A capability for the first paint of a fresh, privately owned document
// bitmap. The embedding adapter grants it only with default graphics state;
// clips/transparency and the first rectangle consume it. No published image
// or retained scrolling surface may grant this capability.
typedef struct { CGContextRef context; CGFloat width, height; } VoxInitialDocumentClear;

static void vox_initial_document_clear_disarm(VoxInitialDocumentClear *state, CGContextRef context) {
    if (state->context == context) state->context = NULL;
}

static int vox_initial_document_clear(VoxInitialDocumentClear *state, CGContextRef context,
    CGRect rect, uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha) {
    if (!context || context != state->context) return 0;
    state->context = NULL;
    static int disabled = -1;
    if (disabled < 0) { const char *value = getenv("VOX_DISABLE_INITIAL_DOCUMENT_CLEAR"); disabled = value && *value; }
    if (disabled || red != 255 || green != 255 || blue != 255 || alpha != 255
        || !CGRectEqualToRect(rect, CGRectMake(0, 0, state->width, state->height))
        || !CGRectEqualToRect(CGContextGetClipBoundingBox(context), rect)
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || CGBitmapContextGetBitmapInfo(context) !=
            (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)) return 0;
    CGAffineTransform ctm = CGContextGetCTM(context);
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    if (ctm.b != 0 || ctm.c != 0 || ctm.tx != 0 || ctm.ty != 0
        || !(ctm.a > 0 && ctm.d > 0) || state->width * ctm.a != (CGFloat)width
        || state->height * ctm.d != (CGFloat)height
        || width > SIZE_MAX / 4 || pitch < width * 4 || (height && pitch > SIZE_MAX / height)) return 0;
    CGContextFlush(context);
    void *pixels = CGBitmapContextGetData(context);
    if (!pixels) return 0;
    if (pitch == width * 4) memset(pixels, 255, pitch * height);
    else for (size_t y = 0; y < height; ++y) memset((uint8_t *)pixels + y * pitch, 255, width * 4);
    const char *diagnostics = getenv("VOX_INITIAL_DOCUMENT_CLEAR_DIAGNOSTICS");
    if (diagnostics && *diagnostics) fprintf(stderr, "VOX_INITIAL_DOCUMENT_CLEAR width=%zu height=%zu\n", width, height);
    return 1;
}
#endif
