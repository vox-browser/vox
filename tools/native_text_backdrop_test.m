#include "../native/include/native_text_backdrop_darwin.h"
#include <assert.h>

static void test_text_backdrops(void) {
    enum { width = 1100, rows = 151, pitch = 4416, copy_width = 1001, copy_rows = 46,
        copy_bytes = copy_width * copy_rows * 4 };
    uint8_t *source = malloc(pitch * rows);
    uint8_t *actual = malloc(copy_bytes + 2);
    uint8_t *expected = malloc(copy_bytes);
    assert(source && actual && expected);
    for (size_t i = 0; i < pitch * rows; ++i) source[i] = (uint8_t)(i ^ (i >> 8));
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    assert(color);
    CGContextRef context = CGBitmapContextCreate(source, width, rows, 8, pitch, color,
        (CGBitmapInfo)kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    VoxTextBackdrop backdrop;
    assert(vox_text_backdrop_source(context, 3, 5, copy_width, copy_rows, 1.5f, &backdrop));
    assert(backdrop.source == source + 8 * pitch + 5 * 4);
    for (size_t row = 0; row < copy_rows; ++row)
        memcpy(expected + row * copy_width * 4, source + (row + 8) * pitch + 5 * 4, copy_width * 4);
    vox_copy_text_backdrop(backdrop, actual + 1);
    assert(memcmp(actual + 1, expected, copy_bytes) == 0);

    setenv("VOX_GLYPH_BACKDROP_COPY_DIAGNOSTICS", "1", 1);
    unsetenv("VOX_SERIAL_CPU_RASTER");
    for (int attempt = 0; attempt < 4; ++attempt) {
        memset(actual, 0xb4, copy_bytes + 2);
        void *copy = native_document_start_text_backdrop_copy(actual + 1,
            3, 5, copy_width, copy_rows, 1.5f);
        assert(copy);
        native_document_finish_text_backdrop_copy(copy);
        assert(memcmp(actual + 1, expected, copy_bytes) == 0);
        assert(actual[0] == 0xb4 && actual[copy_bytes + 1] == 0xb4);
    }
    assert(!vox_start_text_backdrop_copy(context, actual, 0, 0, 4, 4, 1));
    assert(!vox_start_text_backdrop_copy(context, actual, 100, 0, copy_width, copy_rows, 1));
    assert(!vox_start_text_backdrop_copy(context, actual, 0, 120, copy_width, copy_rows, 1));
    assert(!vox_text_backdrop_source(context, -1, 0, copy_width, copy_rows, 1, &backdrop));
    assert(!vox_text_backdrop_source(context, 0, 0, copy_width, copy_rows, INFINITY, &backdrop));
    setenv("VOX_SERIAL_CPU_RASTER", "1", 1);
    assert(!vox_start_text_backdrop_copy(context, actual, 3, 5, copy_width, copy_rows, 1.5f));
    native_document_finish_text_backdrop_copy(NULL);
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(context);
    free(source);
    free(actual);
    free(expected);
    puts("PASS native text backdrop copies and fallback");
}

int main(void) {
    @autoreleasepool { test_text_backdrops(); }
    return 0;
}
