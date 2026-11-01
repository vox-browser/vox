#define VOX_TEST_DEFERRED_DECORATIONS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint8_t> render(int scale, bool msaa, int transform, int alpha,
    float scroll, bool deferred, bool fail = false, bool unsupported = false, bool clipped = false)
{
    constexpr int logical_width = 256, logical_height = 192;
    int width = logical_width * scale, height = logical_height * scale;
    int pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa5);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[0] = 37 + x % 89; p[1] = 51 + y % 73; p[2] = 83; p[3] = 255;
    }
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    if (clipped) CGContextClipToRect(context, CGRectMake(9.25, 6.5, 230, 171));
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(256, 1024);
    ladybird_v_skia_set_root_raster_scroll_y(scroll);
    int cells[] {0, 1, 2, 3, 4};
    ladybird_v_skia_set_msaa_grid(cells, msaa ? 5 : 0, width, 256, 1);
    ladybird_v_skia_set_shared_recording(0, 256, 192);
    if (true) {
        unsetenv("VOX_DISABLE_INSET_DECORATION_BOUNDS");
        unsetenv("VOX_DISABLE_INSET_PICTURE_REGIONS");
        setenv("VOX_DISABLE_INSET_PICTURE_BATCH", "0", 1);
    } else {
        setenv("VOX_DISABLE_INSET_DECORATION_BOUNDS", "1", 1);
        setenv("VOX_DISABLE_INSET_PICTURE_REGIONS", "1", 1);
        setenv("VOX_DISABLE_INSET_PICTURE_BATCH", "1", 1);
    }
    auto original = pixels;
    auto begin = deferred ? ladybird_v_skia_begin_deferred_inset_decorations
        : ladybird_v_skia_begin_inset_decorations;
    assert(begin(context, 2, 16, 252, 174, 256, 192, 14, 0));
    for (int fill : {1, 0}) {
        float b = transform == 1 ? .125f : 0;
        float c = transform == 2 ? -.25f : 0;
        assert(ladybird_v_skia_draw_rounded_rect(context,
            35.375, 112.25, 111.5, 37.75,
            10, 10, 0, 0, 4, 4, 14, 14,
            1, b, c, 1, 0, -scroll, 0, 14, 0, 256, 192,
            fill ? 70 : 82, fill ? 127 : 143, fill ? 194 : 212,
            alpha, fill, transform == 3 ? 12 : 1.5f, 1, 1));
    }
    auto& input = *s_isolated_input_recordings.at(context);
    assert(!input.bounds.isEmpty());
    if (deferred && !clipped) {
        CGContextFlush(context);
        assert(pixels == original); // No speculative leaf publication.
    }
    s_test_fail_deferred_decorations = fail;
    input.unsupported = unsupported;
    if (deferred && (fail || unsupported)) {
        // An unsupported native draw can already have touched the canvas.
        std::fill(pixels.begin() + 40 * pitch + 40 * 4,
            pixels.begin() + 40 * pitch + width * 4, 0x3b);
        assert(!ladybird_v_skia_end_deferred_inset_decorations(context));
        assert(pixels == original); // Rollback includes those partial pixels.
        s_test_fail_deferred_decorations = false;
        // The V owner now replays ordinary commands against this exact prefix.
        for (int fill : {1, 0}) {
            float b = transform == 1 ? .125f : 0;
            float c = transform == 2 ? -.25f : 0;
            assert(ladybird_v_skia_draw_rounded_rect(context,
                35.375, 112.25, 111.5, 37.75, 10, 10, 0, 0, 4, 4, 14, 14,
                1, b, c, 1, 0, -scroll, 0, 14, 0, 256, 192,
                fill ? 70 : 82, fill ? 127 : 143, fill ? 194 : 212,
                alpha, fill, transform == 3 ? 12 : 1.5f, 1, 1));
        }
    } else assert(ladybird_v_skia_end_deferred_inset_decorations(context));
    assert(!s_isolated_input_recordings.count(context));
    CGContextFlush(context);
    CGContextRelease(context);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
        assert(pixels[size_t(y) * pitch + x] == 0xa5);
    return pixels;
}

static std::vector<uint8_t> shadow_group(int scale, bool msaa, float scroll,
    int alpha, bool clipped, bool deferred)
{
    constexpr int w = 256, h = 192;
    int width = w * scale, height = h * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa5);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[0] = 17; p[1] = 29; p[2] = 43; p[3] = 255;
    }
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(context); CGContextScaleCTM(context, scale, scale);
    if (clipped) CGContextClipToRect(context, CGRectMake(9.25, 6.5, 230, 171));
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, w, h);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(w, 1024);
    ladybird_v_skia_set_root_raster_scroll_y(scroll);
    int cells[] {0, 1, 2, 3, 4};
    ladybird_v_skia_set_msaa_grid(cells, msaa ? 5 : 0, width, 256, 1);
    auto before = pixels;
    auto begin = deferred ? ladybird_v_skia_begin_deferred_inset_decorations
        : ladybird_v_skia_begin_inset_decorations;
    assert(begin(context, 0, 0, w, h, w, h, 0, 0));
    for (float blur : {0.f, 12.f}) {
        assert(ladybird_v_skia_draw_outer_box_shadow(context,
            32.5, 53.25, 133.5, 81.25, 12, 8, 4, 4, 9, 9, 7, 5,
            37.5, 58.25, 123.5, 71.25, 12, 8, 4, 4, 9, 9, 7, 5,
            1, 0, 0, 1, 0, -scroll, 0, 0, 0, w, h,
            blur, 121, 168, 243, alpha, 1));
    }
    float outer[] {10, 8, 190, 150, 12, 8, 12, 8, 12, 8, 12, 8};
    float inner[] {28, 49, 116, 65, 8, 6, 8, 6, 8, 6, 8, 6};
    float content[] {26, 44, 120, 70, 12, 8, 12, 8, 12, 8, 12, 8};
    float transform[] {1, 0, 0, 1, 0, -scroll};
    assert(ladybird_v_skia_draw_inner_box_shadow(context, outer, inner, content,
        content, transform, 0, 0, 0, w, h, 6, 31, 67, 103, alpha, 1));
    if (deferred && !clipped) {
        CGContextFlush(context); assert(pixels == before);
    }
    assert(ladybird_v_skia_end_deferred_inset_decorations(context));
    CGContextFlush(context); CGContextRelease(context);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
        assert(pixels[size_t(y) * pitch + x] == 0xa5);
    return pixels;
}

int main()
{
    unsetenv("VOX_DISABLE_DEFERRED_DECORATIONS");
    unsigned cases = 0;
    for (int scale : {1, 2}) for (bool msaa : {false, true})
    for (int transform : {0, 1, 2, 3}) for (int alpha : {128, 255})
    for (float scroll : {0.f, 37.5f}) for (bool clipped : {false, true}) {
        auto expected = render(scale, msaa, transform, alpha, scroll, false, false, false, clipped);
        auto actual = render(scale, msaa, transform, alpha, scroll, true, false, false, clipped);
        if (expected != actual) {
            std::cerr << "Different: scale=" << scale << " msaa=" << msaa << " transform=" << transform << " alpha=" << alpha << " scroll=" << scroll << '\n';
            for (size_t i=0,n=0;i<expected.size() && n<8;++i) if(expected[i]!=actual[i]) {std::cerr << i << ":" << unsigned(expected[i]) << "/" << unsigned(actual[i]) << " ";++n;}
            std::cerr << '\n';return 1;
        }
        ++cases;
    }
    for (int scale : {1, 2}) for (bool msaa : {false, true}) {
        auto forced_failure = render(scale, msaa, 1, 128, 37.5f, true, true);
        auto unsupported = render(scale, msaa, 1, 128, 37.5f, true, false, true);
        assert(forced_failure == unsupported);
        cases += 2;
    }
    for (int scale : {1, 2}) for (bool msaa : {false, true})
    for (float scroll : {0.f, 37.5f}) for (int alpha : {0, 26, 173})
    for (bool clipped : {false, true}) {
        assert(shadow_group(scale, msaa, scroll, alpha, clipped, false)
            == shadow_group(scale, msaa, scroll, alpha, clipped, true));
        ++cases;
    }
    unsetenv("VOX_DISABLE_INSET_DECORATION_BOUNDS");
    unsetenv("VOX_DISABLE_INSET_PICTURE_REGIONS");
    unsetenv("VOX_DISABLE_INSET_PICTURE_BATCH");
    std::cout << cases << " deferred decoration scenes preserve pixels and rollback before retry\n";
}
