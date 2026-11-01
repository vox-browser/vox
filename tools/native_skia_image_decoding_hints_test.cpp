// Compare decode-mode selection through the public image bridge with explicit,
// independently chosen upload levels. All other drawing inputs are identical.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    std::vector<uint8_t> source(1000 * 1000 * 4);
    for (size_t i = 0; i < source.size(); i += 4) {
        source[i] = uint8_t(i * 37 + i / 11);
        source[i + 1] = uint8_t(i / 19);
        source[i + 2] = uint8_t(i * 17 + i / 23);
        source[i + 3] = 255;
    }
    int cases = 0;
    size_t mismatches = 0;
    for (int scale : {1, 2}) for (int mode : {0, 1, 2, 3, 4})
    for (int source_height : {1000, 500, 200}) {
        int width = 240 * scale, height = 240 * scale;
        std::vector<uint32_t> actual(size_t(width) * height, 0xff15191f);
        auto expected = actual;
        bool cropped = source_height != 1000;
        bool source_decode = cropped && (mode == 0 || mode >= 3
            || (mode == 1 && source_height == 200));
        int level = source_decode ? 0 : (scale == 1 ? 2 : 1);
        s_image_decode_cache.clear();
        ladybird_v_skia_begin_image_decode_frame(&source, cases, 1);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_msaa_grid(nullptr, 0, 256, 256, 0);
        ladybird_v_skia_set_msaa_tiles(nullptr, 0, 256);
#ifndef VOX_IMAGE_HINT_NEGATIVE_CONTROL
        if (mode != 2) ladybird_v_skia_add_image_decoding_hint("image", 5, mode == 1 || mode == 3);
        if (mode >= 3) ladybird_v_skia_add_image_decoding_hint("image", 5, mode == 4);
#endif
        for (bool oracle : {false, true}) {
            auto& pixels = oracle ? expected : actual;
            auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context);
            CGColorSpaceRelease(space);
            CGContextScaleCTM(context, scale, scale);
            ladybird_v_skia_set_image_resource_identity(oracle ? nullptr : "image", oracle ? 0 : 5);
            float radii[] {5, 5, 5, 5, 5, 5, 5, 5};
            int flags = oracle ? vox_image_with_decode_level(2, level) : 2;
            assert(ladybird_v_skia_draw_rgba_image(context, source.data(), 1000, 1000, 4000,
                10, 12, 200, source_height / 5, 0, 0, 1000, source_height,
                10, 12, 200, source_height / 5, 1, 0, 0, 1, 0, 0, 0, 0, 0,
                240, 240, 1, 0, flags, radii));
            CGContextFlush(context);
            CGContextRelease(context);
        }
        for (size_t i = 0; i < actual.size(); ++i) mismatches += actual[i] != expected[i];
        ++cases;
    }
    ladybird_v_skia_set_chromium_painting(0);
    std::printf("Image decoding hints: %d scenes, %zu differing pixels\n", cases, mismatches);
    return mismatches ? 1 : 0;
}
