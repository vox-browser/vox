#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint8_t> render_inner(int root, int opaque, int scale, int alpha,
    bool enabled = true, bool invalid = false, bool grouped = false, bool unsupported = false)
{
    int width = 128 * scale, height = 96 * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa5);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[0] = 37 + x % 89; p[1] = 51 + y % 73; p[2] = 83; p[3] = 255;
    }
    auto before = pixels;
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    // Pixel replacement still obeys an existing native ancestor clip.
    CGContextClipToRect(context, CGRectMake(25, 20, 64, 48));
    float outer[] {10, 8, 100, 80, 12, 8, 12, 8, 12, 8, 12, 8};
    float inner[] {18, 19, 76, 55, 8, 6, 8, 6, 8, 6, 8, 6};
    float content[] {16, 14, 80, 60, 12, 8, 12, 8, 12, 8, 12, 8};
    float transform[] {1, 0, 0, 1, 0, 0};
    if (invalid) inner[0] = NAN;
    ladybird_v_skia_set_chromium_painting(enabled);
    ladybird_v_skia_set_raster_layer(0, 0, root);
    if (grouped) {
        int tile = 0;
        ladybird_v_skia_set_raster_layer_size(128, 96);
        ladybird_v_skia_set_msaa_grid(&tile, 1, 128 * scale, 256, 1);
        ladybird_v_skia_set_shared_recording(1, 128, 96);
        assert(!ladybird_v_skia_begin_inset_decorations(context,
            16, 14, 80, 60, 128, 96, 0, 0));
        ladybird_v_skia_set_shared_recording(0, 128, 96);
        assert(ladybird_v_skia_begin_inset_decorations(context,
            16, 14, 80, 60, 128, 96, 0, 0));
        assert(!ladybird_v_skia_begin_inset_decorations(context,
            16, 14, 80, 60, 128, 96, 0, 0));
    }
    int result = ladybird_v_skia_draw_inner_box_shadow(context, outer, inner,
        content, content, transform, 0, 0, 0, 128, 96, 6, 31, 67, 103, alpha, opaque);
    assert(result == (enabled && !invalid));
    if (grouped) {
        auto fallback = pixels;
        if (unsupported) ladybird_v_skia_block_shared_recording(context);
        assert(ladybird_v_skia_end_inset_decorations(context) == !unsupported);
        if (unsupported) assert(pixels == fallback);
        assert(!ladybird_v_skia_end_inset_decorations(context));
        assert(!s_isolated_input_recordings.count(context));
    }
    CGContextFlush(context);
    CGContextRelease(context);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    bool changed = false;
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < pitch; ++x) {
            auto i = size_t(y) * pitch + x;
            if (pixels[i] == before[i]) continue;
            changed = true;
            assert(enabled && !invalid && alpha);
            assert(x < width * 4); // Stride padding is not a render target.
            assert(x / 4 >= 25 * scale && x / 4 < 89 * scale);
            assert(y >= 28 * scale && y < 76 * scale); // CoreGraphics bottom-up clip.
        }
    }
    assert(changed == (enabled && !invalid && alpha != 0));
    return pixels;
}

int main()
{
    for (int scale : {1, 2}) {
        for (int alpha : {0, 26, 173}) {
            assert(render_inner(0, 0, scale, alpha) == render_inner(0, 1, scale, alpha));
            render_inner(1, 1, scale, alpha);
        }
        render_inner(1, 1, scale, 173, false);
        render_inner(1, 1, scale, 173, true, true);
        render_inner(1, 1, scale, 173, true, false, true);
        render_inner(1, 1, scale, 173, true, false, true, true);
    }
    std::cout << "Native inner shadows: clipping, stride, alpha, scale, layer isolation and fallback passed\n";
}
