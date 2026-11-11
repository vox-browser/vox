#include "native/include/native_png_color_darwin.h"
#include <assert.h>
#include <zlib.h>
#include <stdio.h>

// This seam checks ICC extraction, metadata routing, immutable source rows and
// tag ownership. The browser fixture separately exercises color rendering.

// Vox registers vlib's V inflater; this standalone test uses zlib instead.
static uint8_t *zlib_inflate_profile(const uint8_t *input, size_t length, size_t limit,
    size_t *output_length)
{
    uLongf size = (uLongf)limit;
    uint8_t *output = malloc(limit);
    if (!output || uncompress(output, &size, input, (uLong)length) != Z_OK) { free(output); return NULL; }
    *output_length = size;
    return output;
}

int main(int argc, char **argv) {
    native_png_icc_set_inflater(zlib_inflate_profile);
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
        assert(native_png_has_icc_profile(png.bytes, png.length));
        assert(!native_png_has_icc_profile(plain.bytes, plain.length));
        NSData *expected = native_png_icc_data(png.bytes, png.length);
        assert(expected.length >= 128 && !memcmp((const uint8_t *)expected.bytes + 36, "acsp", 4));
        VoxPngColorProfile profile;
        uint8_t pixels[16] = {0};
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        NSData *tagged = native_image_icc_profile(pixels, 2, 2);
        assert([tagged isEqualToData:expected]);
        assert(native_image_icc_profile(pixels, 2, 2) == tagged);
        assert(!native_image_icc_profile(pixels, 4, 1));
        assert(!native_image_color_profile(pixels, 4, 1, &profile));
        for (int index = 0; index < 16; ++index) assert(pixels[index] == 0);
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 0);
        assert(!native_image_icc_profile(pixels, 2, 2));
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        native_tag_image_color_profile(pixels, 2, 2, plain.bytes, plain.length, 1);
        assert(!native_image_icc_profile(pixels, 2, 2));
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        assert(native_png_icc_cached_bytes == 0);
        assert(native_png_icc_channel_marker() == 11);
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        assert(native_image_icc_profile(pixels, 2, 2));
        native_tag_image_color_profile(pixels, 2, 2, NULL, 0, 0);
        assert(!native_image_icc_profile(pixels, 2, 2));
        // A decoded WebP tag replaces PNG ICC metadata, and dimensions and
        // retagging keep reused pixel addresses independent.
        VoxImageColorProfile decoded = {{0}};
        decoded.values[0] = -1;
        decoded.values[16] = 0.75f;
        native_tag_image_color_profile(pixels, 2, 2, png.bytes, png.length, 1);
        native_tag_decoded_image_color_profile(pixels, 2, 2, decoded.values);
        assert(!native_image_icc_profile(pixels, 2, 2));
        assert(native_png_icc_cached_bytes == 0 && native_png_icc_lru.count == 0);
        assert(native_image_color_profile(pixels, 2, 2, &profile));
        assert(profile.values[0] == -1 && profile.values[16] == 0.75f);
        assert(!native_image_color_profile(pixels, 4, 1, &profile));
        native_tag_decoded_image_color_profile(pixels, 2, 2, NULL);
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        native_tag_decoded_image_color_profile(pixels, 2, 2, decoded.values);
        native_tag_image_color_profile(pixels, 2, 2, NULL, 0, 0);
        assert(!native_image_color_profile(pixels, 2, 2, &profile));
        // Every tagged buffer keeps its own profile until it is retagged.
        uint8_t many[129][16] = {{0}};
        for (int index = 0; index < 129; ++index) {
            native_tag_image_color_profile(many[index], 2, 2, png.bytes, png.length, 1);
            assert([native_image_icc_profile(many[index], 2, 2) isEqualToData:expected]);
        }
        assert(native_png_icc_tags.count == 129);
        for (int index = 0; index < 129; ++index)
            native_tag_image_color_profile(many[index], 2, 2, NULL, 0, 0);
        assert(native_png_icc_tags.count == 0);
        assert(native_png_icc_cached_bytes == 0 && native_png_icc_lru.count == 0);
        puts("ICC metadata routing and retagging passed");
        return 0;
    }
}
