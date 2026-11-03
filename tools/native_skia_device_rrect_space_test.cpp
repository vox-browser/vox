// Device-layout and CSS-layout representations of one layer-local rounded box
// must produce identical native GPU pixels, including translated underlays.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

template<class Function> static Function selected(char const* name, Function fallback)
{
    static void* library = []() -> void* {
        auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY");
        if (!path) return nullptr;
        auto handle = dlopen(path, RTLD_NOW | RTLD_LOCAL); assert(handle); return handle;
    }();
    if (!library) return fallback;
    auto symbol = dlsym(library, name); assert(symbol); return reinterpret_cast<Function>(symbol);
}

static std::vector<uint8_t> render(float layout_scale, int mode, bool translated)
{
    constexpr int width = 1024, height = 768, density = 2;
    std::vector<uint8_t> pixels(size_t(width) * height * density * density * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width * density, height * density,
        8, width * density * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); assert(context);
    CGContextScaleCTM(context, density, density);
    selected("ladybird_v_skia_set_chromium_painting", &ladybird_v_skia_set_chromium_painting)(1);
    selected("ladybird_v_skia_set_raster_layer", &ladybird_v_skia_set_raster_layer)(144, 230, 0);
    selected("ladybird_v_skia_set_raster_layer_size", &ladybird_v_skia_set_raster_layer_size)(880, 400);
    int cell = 0;
    selected("ladybird_v_skia_set_msaa_grid", &ladybird_v_skia_set_msaa_grid)(&cell, 1, 1760, 512, 1);
    selected("ladybird_v_skia_set_layer_shared_recording", &ladybird_v_skia_set_layer_shared_recording)(1);
    float offset_y = translated ? -102 : 0;
    float x = 568.5f * layout_scale, y = (418.5f - offset_y) * layout_scale;
    float radius = 21.5f * layout_scale;
    if (mode == 7) {
        float background[] {x - layout_scale / 2, y - layout_scale / 2,
            148 * layout_scale, 44 * layout_scale,
            22 * layout_scale, 22 * layout_scale, 22 * layout_scale, 22 * layout_scale,
            22 * layout_scale, 22 * layout_scale, 22 * layout_scale, 22 * layout_scale};
        selected("ladybird_v_skia_set_rounded_rect_underlay", &ladybird_v_skia_set_rounded_rect_underlay)(background, 255, 255, 255, 255);
    }
    float widths[] {layout_scale, layout_scale, layout_scale, layout_scale};
    selected("ladybird_v_skia_set_rounded_border_widths", &ladybird_v_skia_set_rounded_border_widths)(widths);
    assert(selected("ladybird_v_skia_draw_rounded_rect", &ladybird_v_skia_draw_rounded_rect)(context,
        x, y, 147 * layout_scale, 43 * layout_scale,
        radius, radius, radius, radius, radius, radius, radius, radius,
        1 / layout_scale, 0, 0, 1 / layout_scale, 0, offset_y,
        0, 0, 0, width, height, 0, 0, 0, 51, mode, layout_scale, 1, 0));
    selected("ladybird_v_skia_finish_shared_recording", &ladybird_v_skia_finish_shared_recording)();
    CGContextFlush(context); CGContextRelease(context);
    selected("ladybird_v_skia_set_layer_shared_recording", &ladybird_v_skia_set_layer_shared_recording)(0);
    selected("ladybird_v_skia_set_msaa_grid", &ladybird_v_skia_set_msaa_grid)(nullptr, 0, 0, 0, 0);
    selected("ladybird_v_skia_set_raster_layer", &ladybird_v_skia_set_raster_layer)(0, 0, 1);
    return pixels;
}

int main()
{
    assert(shared_picture_draw());
    int failures = 0;
    for (int mode : {0, 1, 6, 7}) for (bool translated : {false, true}) {
        auto css = render(1, mode, translated), device = render(2, mode, translated);
        int differing = 0;
        for (size_t i = 0; i < css.size(); i += 4)
            if (!std::equal(css.begin() + i, css.begin() + i + 4, device.begin() + i)) ++differing;
        std::printf("mode=%d translated=%d: %d differing pixels\n", mode, translated, differing);
        failures += differing;
    }
    return failures ? 1 : 0;
}
