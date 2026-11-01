#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint8_t> render(int scale, bool msaa, int transform, int alpha,
    float scroll, bool bounded)
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
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    CGContextClipToRect(context, CGRectMake(9.25, 6.5, 230, 171));
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(256, 1024);
    ladybird_v_skia_set_root_raster_scroll_y(scroll);
    int cells[] {0, 1, 2, 3, 4};
    ladybird_v_skia_set_msaa_grid(cells, msaa ? 5 : 0, width, 256, 1);
    ladybird_v_skia_set_shared_recording(0, 256, 192);
    if (bounded) {
        unsetenv("VOX_DISABLE_INSET_DECORATION_BOUNDS");
        unsetenv("VOX_DISABLE_INSET_PICTURE_REGIONS");
    } else {
        setenv("VOX_DISABLE_INSET_DECORATION_BOUNDS", "1", 1);
        setenv("VOX_DISABLE_INSET_PICTURE_REGIONS", "1", 1);
    }
    assert(ladybird_v_skia_begin_inset_decorations(context,
        2, 16, 252, 174, 256, 192, 14, 0));
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
    if (bounded) {
        auto copy = *s_inset_decoration_recording;
        size_t original = copy.backdrop.size();
        trim_inset_decoration_backdrop(copy, input.bounds);
        assert(copy.backdrop.size() < original / 2);
    }
    assert(ladybird_v_skia_end_inset_decorations(context));
    assert(!s_isolated_input_recordings.count(context));
    CGContextFlush(context);
    CGContextRelease(context);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
        assert(pixels[size_t(y) * pitch + x] == 0xa5);
    return pixels;
}

int main()
{
    unsigned cases = 0;
    for (int scale : {1, 2}) for (bool msaa : {false, true})
    for (int transform : {0, 1, 2, 3}) for (int alpha : {128, 255})
    for (float scroll : {0.f, 37.5f}) {
        auto expected = render(scale, msaa, transform, alpha, scroll, false);
        auto actual = render(scale, msaa, transform, alpha, scroll, true);
        if (expected != actual) {
            std::cerr << "Inset bounds mismatch: scale=" << scale << " msaa=" << msaa
                << " transform=" << transform << " alpha=" << alpha
                << " scroll=" << scroll << '\n';
            return 1;
        }
        ++cases;
    }
    unsetenv("VOX_DISABLE_INSET_DECORATION_BOUNDS");
    unsetenv("VOX_DISABLE_INSET_PICTURE_REGIONS");
    std::cout << cases << " bounded decoration scenes match full-viewport replay exactly\n";
}
