#define LADYBIRD_V_HAS_SKIA_TEXT 1
#include "native_png_color_darwin.h"
#include <assert.h>
#include <stdio.h>

// This seam checks metadata routing, immutable source rows and cache ownership.
// The browser fixture separately exercises the real skcms color conversion.
static int conversions;
static int fail_conversion;
int ladybird_v_skia_convert_icc_rgba(const void *bytes, size_t length,
    const uint8_t *source, int width, int height, uint8_t *destination)
{
    if (length < 128 || memcmp((const uint8_t *)bytes + 36, "acsp", 4)) return 0;
    ++conversions;
    if (fail_conversion) return 0;
    memset(destination, 0x55, (size_t)width * height * 4);
    return 1;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc == 4 && !strcmp(argv[1], "--extract")) {
            NSData *png = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];
            NSData *icc = native_png_icc_data(png.bytes, png.length);
            if (!icc) return 1;
            return [icc writeToFile:[NSString stringWithUTF8String:argv[3]] atomically:YES] ? 0 : 2;
        }
        if (argc != 3) return 2;
        NSData *png = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        NSData *plain = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];
        assert(png && plain);
        assert(native_png_has_color_profile(png.bytes, png.length));
        assert(!native_png_has_color_profile(plain.bytes, plain.length));
        VoxPngColorProfile profile;
        uint8_t pixels[16] = {0};
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        NSData *converted = native_image_icc_pixels(pixels, 2, 2);
        assert(converted.length == 16 && conversions == 1);
        for (int index = 0; index < 16; ++index) {
            assert(((const uint8_t *)converted.bytes)[index] == 0x55);
            assert(pixels[index] == 0);
        }
        assert(native_image_icc_pixels(pixels, 2, 2) == converted && conversions == 1);
        assert(!native_image_color_profile(pixels, 4, 1, &profile));
        assert(!native_image_icc_pixels(pixels, 4, 1));
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 0);
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        assert(!native_image_icc_pixels(pixels, 2, 2));
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        native_tag_image_color_profile(pixels, 2, 2, plain.bytes, plain.length, 1);
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        assert(!native_image_icc_pixels(pixels, 2, 2));
        assert(native_png_icc_cached_bytes == 0);
        assert(native_png_icc_channel_marker() == 11);
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        assert(native_image_icc_profile(pixels, 2, 2));
        assert(!native_image_icc_profile(pixels, 4, 1));
        fail_conversion = 1;
        int before_failure = conversions;
        assert(!native_image_icc_pixels(pixels, 2, 2));
        assert(!native_image_icc_pixels(pixels, 2, 2));
        assert(conversions == before_failure + 1);
        assert(native_image_icc_profile(pixels, 2, 2));
        fail_conversion = 0;
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        assert(native_image_icc_pixels(pixels, 2, 2));
        assert(conversions == before_failure + 2);
        native_tag_image_color_profile(pixels, 2, 2, NULL, 0, 0);
        assert(!native_image_icc_profile(pixels, 2, 2));
        uint8_t many[129][16] = {{0}};
        for (int index = 0; index < 129; ++index) {
            native_tag_image_color_profile(many[index], 2, 2, png.bytes, png.length, 1);
            assert(native_image_icc_pixels(many[index], 2, 2));
        }
        assert(native_png_icc_lru.count == 128);
        assert(!native_png_icc_tags[[NSValue valueWithPointer:many[0]]].converted);
        int prior = conversions;
        assert(native_image_icc_pixels(many[0], 2, 2) && conversions == prior + 1);
        for (int index = 0; index < 129; ++index)
            native_tag_image_color_profile(many[index], 2, 2, NULL, 0, 0);
        assert(native_png_icc_cached_bytes == 0 && native_png_icc_lru.count == 0);
        uint8_t *large[9];
        for (int index = 0; index < 9; ++index) {
            large[index] = calloc(1000 * 1000, 4);
            assert(large[index]);
            native_tag_image_color_profile(large[index], 1000, 1000, png.bytes, png.length, 1);
            assert(native_image_icc_pixels(large[index], 1000, 1000));
            assert(native_png_icc_cached_bytes <= native_png_icc_cache_limit);
        }
        assert(!native_png_icc_tags[[NSValue valueWithPointer:large[0]]].converted);
        for (int index = 0; index < 9; ++index) {
            native_tag_image_color_profile(large[index], 1000, 1000, NULL, 0, 0);
            free(large[index]);
        }
        assert(native_png_icc_cached_bytes == 0 && native_png_icc_lru.count == 0);
        puts("ICC metadata routing and retagging passed");
        return 0;
    }
}
