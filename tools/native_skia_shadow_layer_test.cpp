// Independent shadow layers must not inherit the opaque root backdrop.
// Exercise the actual bridge on patterned pixels, including retained clips
// and Retina scale. An optional old bridge checks unchanged root rendering.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

using DrawShadow = decltype(&ladybird_v_skia_draw_outer_box_shadow);
using SetLayer = decltype(&ladybird_v_skia_set_raster_layer);

static std::vector<uint8_t> render(DrawShadow draw, SetLayer layer,
    int root, int opaque, int scale, int clip, int alpha)
{
    int width = 128 * scale, height = 96 * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa5);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto offset = size_t(y) * pitch + x * 4;
        pixels[offset] = uint8_t(73 + x % 149);
        pixels[offset + 1] = uint8_t(51 + y % 163);
        pixels[offset + 2] = uint8_t(89 + (x + y) % 137);
        pixels[offset + 3] = 255;
    }
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    if (clip == 1) CGContextClipToRect(context, CGRectMake(13.25, 11.5, 67.5, 53.25));
    if (clip == 2) {
        CGContextAddEllipseInRect(context, CGRectMake(13.25, 11.5, 67.5, 53.25));
        CGContextClip(context);
    }
    layer(root ? 0 : 7.25, root ? 0 : 3.5, root);
    assert(draw(context,
        17.375, 18.25, 75, 49, 8, 6, 8, 6, 8, 6, 8, 6,
        17.375, 16.25, 75, 49, 8, 6, 8, 6, 8, 6, 8, 6,
        1, 0, 0, 1, 0, 0, 0, 0, 0, 128, 96, 6, 31, 67, 103, alpha, opaque));
    CGContextFlush(context);
    CGContextRelease(context);
    return pixels;
}

int main()
{
    DrawShadow reference = nullptr;
    SetLayer reference_layer = nullptr;
    decltype(&ladybird_v_skia_set_chromium_painting) reference_mode = nullptr;
    if (auto path = std::getenv("VOX_SKIA_SHADOW_REFERENCE_LIBRARY")) {
        auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        assert(library);
        reference = reinterpret_cast<DrawShadow>(dlsym(library, "ladybird_v_skia_draw_outer_box_shadow"));
        reference_layer = reinterpret_cast<SetLayer>(dlsym(library, "ladybird_v_skia_set_raster_layer"));
        reference_mode = reinterpret_cast<decltype(reference_mode)>(dlsym(library, "ladybird_v_skia_set_chromium_painting"));
        assert(reference && reference_layer && reference_mode);
    }
    int cases = 0;
    for (int mode : {0, 1}) for (int scale : {1, 2})
    for (int clip : {0, 1, 2}) for (int alpha : {26, 51, 173}) {
        if (reference_mode) reference_mode(mode);
        ladybird_v_skia_set_chromium_painting(mode);
        auto expected = render(&ladybird_v_skia_draw_outer_box_shadow,
            &ladybird_v_skia_set_raster_layer, 0, 0, scale, clip, alpha);
        auto actual = render(&ladybird_v_skia_draw_outer_box_shadow,
            &ladybird_v_skia_set_raster_layer, 0, 1, scale, clip, alpha);
        if (expected != actual) {
            std::cerr << "Independent shadow backdrop mismatch mode=" << mode
                << " scale=" << scale << " clip=" << clip << " alpha=" << alpha << '\n';
            return 1;
        }
        ++cases;
        if (reference) {
            expected = render(reference, reference_layer, 1, 1, scale, clip, alpha);
            actual = render(&ladybird_v_skia_draw_outer_box_shadow,
                &ladybird_v_skia_set_raster_layer, 1, 1, scale, clip, alpha);
            if (expected != actual) {
                std::cerr << "Root shadow changed mode=" << mode << " scale=" << scale
                    << " clip=" << clip << " alpha=" << alpha << '\n';
                return 1;
            }
            ++cases;
        }
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_chromium_painting(0);
        if (reference_mode) reference_mode(0);
    }
    std::cout << "Native shadow layers: " << cases << " exact pixel comparisons passed\n";
}
