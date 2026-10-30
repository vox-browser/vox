#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static void render_group(int scale, int alpha, bool unsupported)
{
    int width = 128 * scale, height = 96 * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa5);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[0] = 37 + x % 89; p[1] = 51 + y % 73; p[2] = 83; p[3] = 255;
    }
    auto before = pixels;
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    CGContextClipToRect(context, CGRectMake(8, 8, 112, 80));
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(128, 96);
    int tile = 0;
    ladybird_v_skia_set_msaa_grid(&tile, 1, 128 * scale, 256, 1);
    ladybird_v_skia_set_shared_recording(0, 128, 96);
    assert(ladybird_v_skia_begin_inset_decorations(context,
        2, 2, 124, 92, 128, 96, 0, 0));
    assert(!ladybird_v_skia_begin_inset_decorations(context,
        2, 2, 124, 92, 128, 96, 0, 0));
    for (float dy : {-1.f, -5.f}) {
        assert(ladybird_v_skia_draw_outer_box_shadow(context,
            24, 24 + dy, 80, 48, 12, 8, 12, 8, 12, 8, 12, 8,
            24, 24, 80, 48, 12, 8, 12, 8, 12, 8, 12, 8,
            1, 0, 0, 1, 0, 0, 0, 0, 0, 128, 96,
            dy == -1 ? 0 : 12, 121, 168, 243, alpha, 1));
    }
    auto fallback = pixels;
    if (unsupported) ladybird_v_skia_block_shared_recording(context);
    assert(ladybird_v_skia_end_inset_decorations(context) == !unsupported);
    if (unsupported) assert(pixels == fallback);
    assert(!s_isolated_input_recordings.count(context));
    assert(!ladybird_v_skia_end_inset_decorations(context));
    CGContextFlush(context);
    bool changed = false;
    for (int y = 0; y < height; ++y) for (int x = 0; x < pitch; ++x) {
        auto offset = size_t(y) * pitch + x;
        if (pixels[offset] == before[offset]) continue;
        changed = true;
        assert(alpha);
        assert(x < width * 4);
        assert(x / 4 >= 8 * scale && x / 4 < 120 * scale);
        assert(y >= 8 * scale && y < 88 * scale);
    }
    assert(changed == (alpha != 0));
    CGContextRelease(context);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    ladybird_v_skia_set_shared_recording(0, 0, 0);
}

int main()
{
    for (int scale : {1, 2})
        for (int alpha : {0, 26, 173})
            for (bool unsupported : {false, true}) render_group(scale, alpha, unsupported);
    std::cout << "Outer shadow groups: retained ink, native clips, stride, alpha, scale and fallback passed\n";
}
