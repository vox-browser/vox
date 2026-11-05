#define VOX_TEST_SPARSE_BITMAP_CONTEXT
#include "../native_sparse_bitmap_context_darwin.h"
#include "../native_sparse_opacity_ink_darwin.h"
#include "../native_bitmap_snapshot_darwin.h"
#include <cassert>
#include <cstdio>
#include <thread>

static void check_storage(size_t width, size_t height) {
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = native_create_sparse_bitmap_context(width, height, color);
    CGColorSpaceRelease(color); assert(context);
    auto pixels = static_cast<uint8_t *>(CGBitmapContextGetData(context));
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    assert(pixels && pitch == width * 4 && native_test_sparse_bitmap_live_bytes == pitch * height);
    int actual[4], expected[4];
    assert(!native_opacity_canvas_ink_bounds({context, pixels}, pitch, 0, 0, width, height,
        &actual[0], &actual[1], &actual[2], &actual[3]));
    for (int pass = 0; pass < 3; ++pass) {
        size_t x = pass == 0 ? 0 : pass == 1 ? width - 1 : width / 2;
        size_t y = pass == 0 ? height - 1 : pass == 1 ? 0 : height / 2;
        pixels[y * pitch + x * 4 + 3] = 1;
        for (int crop = 0; crop < 2; ++crop) {
            int left = crop ? width / 4 : 0, top = crop ? height / 4 : 0;
            int right = crop ? width * 3 / 4 : width, bottom = crop ? height * 3 / 4 : height;
            int a = native_opacity_canvas_ink_bounds({context, pixels}, pitch, left, top, right, bottom,
                &actual[0], &actual[1], &actual[2], &actual[3]);
            int e = native_opacity_layer_ink_bounds(pixels, pitch, left, top, right, bottom,
                &expected[0], &expected[1], &expected[2], &expected[3]);
            assert(a == e && (!a || !memcmp(actual, expected, sizeof(actual))));
        }
    }
    // A consumed context stays alive through its image and data consumer.
    auto image = native_take_bitmap_image(context); assert(image);
    auto bytes = CGDataProviderCopyData(CGImageGetDataProvider(image)); assert(bytes);
    assert(CFDataGetBytePtr(bytes) == pixels);
    CGImageRelease(image);
    assert(native_test_sparse_bitmap_live_bytes == pitch * height);
    // Last data ownership can retire on a worker without the producer stack.
    std::thread release([bytes] { CFRelease(bytes); }); release.join();
    assert(native_test_sparse_bitmap_live_bytes == 0);
}

int main() {
    check_storage(65, 4097);
    check_storage(257, 1031);
    check_storage(521, 527);
    check_storage(1024, 257);
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    assert(!native_create_sparse_bitmap_context(0, 512, color));
    assert(!native_create_sparse_bitmap_context(SIZE_MAX, 512, color));
    assert(!native_create_sparse_bitmap_context(16384, 16384, color));
    assert(!native_create_sparse_bitmap_context(32, 32, color));
    CGColorSpaceRelease(color);
    // Exercise CoreGraphics failure cleanup after the mapping was acquired.
    color = CGColorSpaceCreateWithName(kCGColorSpaceGenericGrayGamma2_2);
    assert(!native_create_sparse_bitmap_context(1024, 257, color));
    CGColorSpaceRelease(color);
    assert(native_test_sparse_bitmap_live_bytes == 0 && native_test_sparse_bitmap_releases == 5);
    puts("Sparse bitmap contexts: exact ink bounds, one-level alpha, row tails, image/data/worker lifetime and allocation failure");
}
