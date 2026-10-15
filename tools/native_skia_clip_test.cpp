// Standalone macOS pixel regressions for the actual native Skia bridge.
// Compile with tools/test_native_skia_clip.sh. No browser or window is created.
#include "../native_skia_text_darwin.cpp"

#include <cassert>
#include <cstdio>
#include <dlfcn.h>

namespace {

using DrawPath = decltype(&ladybird_v_skia_draw_svg_path);
using DrawLinear = decltype(&ladybird_v_skia_draw_svg_linear_gradient_path);
using DrawRadial = decltype(&ladybird_v_skia_draw_svg_radial_gradient_path);

struct Surface {
    std::vector<uint8_t> pixels;
    CGContextRef context;
    explicit Surface(int scale = 1) : pixels(128 * 96 * scale * scale * 4)
    {
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        context = CGBitmapContextCreate(pixels.data(), 128 * scale, 96 * scale,
            8, 128 * scale * 4, color,
            static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
        CGColorSpaceRelease(color);
        assert(context);
        CGContextScaleCTM(context, scale, scale);
        CGContextSetShouldAntialias(context, true);
    }
    ~Surface() { CGContextRelease(context); }
};

uint64_t hash_pixels(std::vector<uint8_t> const& pixels)
{
    uint64_t hash = 14695981039346656037ull;
    for (auto value : pixels)
        hash = (hash ^ value) * 1099511628211ull;
    return hash;
}

// A cubic shape crosses the clip on all sides; a second contour covers the
// even-odd hole and clipped antialiasing, stroke joins and dash boundaries.
constexpr float path[] {
    0, 3.25, 4.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    3, 118.5, 27.25, 29.5, -12.5, 103.25, -4.25, 0, 0, 0, 0, 0,
    3, 94.25, 90.5, 145.25, 47.25, 90.5, 103.25, 0, 0, 0, 0, 0,
    1, 6.5, 81.25, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 36.25, 32.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 64.5, 35.25, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 59.5, 61.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};
constexpr float stops[] { 0.9, 0.1, 0.3, 0.8, 0, 0.1, 0.7, 0.4, 0.65, 1 };

uint64_t render_case(int index, DrawPath draw, DrawLinear linear, DrawRadial radial)
{
    Surface surface(index == 7 ? 2 : 1);
    auto context = surface.context;
    if (index == 6) {
        CGContextTranslateCTM(context, 8.5, 7.25);
        CGContextRotateCTM(context, 0.12);
    }
    if (index == 8)
        CGContextScaleCTM(context, 1.25, 1.25);
    auto clip = CGRectMake(23.25, 17.5, 35.75, 42.25);
    if (index == 1 || index == 6) {
        CGContextAddEllipseInRect(context, clip);
        CGContextClip(context);
    } else if (index == 13) {
        uint8_t mask_pixels[16 * 16];
        for (size_t offset = 0; offset < sizeof(mask_pixels); ++offset)
            mask_pixels[offset] = static_cast<uint8_t>((offset * 13) % 256);
        auto data = CFDataCreate(nullptr, mask_pixels, sizeof(mask_pixels));
        auto provider = CGDataProviderCreateWithCFData(data);
        auto mask = CGImageMaskCreate(16, 16, 8, 8, 16, provider, nullptr, false);
        assert(mask);
        CGContextClipToMask(context, clip, mask);
        CGImageRelease(mask);
        CGDataProviderRelease(provider);
        CFRelease(data);
    } else if (index == 9) {
        CGContextClipToRect(context, CGRectZero);
    } else if (index == 10) {
        CGContextClipToRect(context, CGRectMake(120, 90, 4, 4));
    } else {
        CGContextClipToRect(context, clip);
    }
    float a = 1, b = 0, c = 0, d = 1, e = 0, f = 0;
    if (index == 2) {
        a = 1.15; b = 0.2; c = -0.16; d = 0.85; e = 7.25; f = -3.5;
    }
    int result;
    if (index == 14) {
        // Shadow raster inputs keep their complete bounds even with a narrow
        // destination clip, so blurred pixels can reach the visible area.
        result = ladybird_v_skia_draw_outer_box_shadow(context,
            8, 15, 95, 62, 8, 8, 8, 8, 8, 8, 8, 8,
            18, 25, 75, 42, 8, 8, 8, 8, 8, 8, 8, 8,
            1, 0, 0, 1, 0, 0, 0, 0, 0, 128, 96, 8, 40, 70, 120, 200);
    } else if (index == 11) {
        result = linear(context, path, 9, 1, a, b, c, d, e, f, 0, 0, 0,
            128, 96, 0, 0, 0, 0, 4, 0, 0, 110, 70, 1, 0, 0, 1, 0, 0,
            0, 0, stops, 2, 0.8);
    } else if (index == 12) {
        result = radial(context, path, 9, 1, a, b, c, d, e, f, 0, 0, 0,
            128, 96, 0, 0, 0, 0, 4, 32, 40, 3, 60, 45, 55,
            1, 0, 0, 1, 0, 0, 0, 0, stops, 2, 0.8);
    } else {
        double dash[] { 5.5, 3.25 };
        result = draw(context, path, 9, index == 4, a, b, c, d, e, f, 0, 0, 0,
            128, 96, 190, 37, 83, 201, 1, 23, 149, 215, 187,
            index == 3 || index == 5, 6.25, 1, 0, 4, index == 3,
            dash, index == 5 ? 2 : 0, 1.25);
    }
    assert(result == 1);
    CGContextFlush(context);
    return hash_pixels(surface.pixels);
}

void check_clip_regions()
{
    Surface surface;
    CGContextClipToRect(surface.context, CGRectMake(20.25, 10.5, 15.5, 30.25));
    RasterRegion region { 0, 0, 128, 96 };
    assert(leaf_raster_region_intersects_destination_clip(surface.context, 96, region));
    assert(region.left == 0 && region.right == 128);
    assert(region.top == 0 && region.bottom == 96);
    RasterRegion antialias_fringe { 17, 52, 19, 54 };
    assert(leaf_raster_region_intersects_destination_clip(surface.context, 96, antialias_fringe));
    RasterRegion outside { 70, 10, 90, 20 };
    assert(!leaf_raster_region_intersects_destination_clip(surface.context, 96, outside));
    CGContextClipToRect(surface.context, CGRectZero);
    RasterRegion empty { 0, 0, 128, 96 };
    assert(!leaf_raster_region_intersects_destination_clip(surface.context, 96, empty));
}

} // namespace

int main()
{
    DrawPath draw = ladybird_v_skia_draw_svg_path;
    DrawLinear linear = ladybird_v_skia_draw_svg_linear_gradient_path;
    DrawRadial radial = ladybird_v_skia_draw_svg_radial_gradient_path;
    // The optional library is used only to record old-renderer goldens. Normal
    // test runs exercise this translation unit's actual implementation.
    auto reference = std::getenv("VOX_SKIA_CLIP_REFERENCE_LIBRARY");
    if (reference) {
        auto handle = dlopen(reference, RTLD_NOW | RTLD_LOCAL);
        assert(handle);
        draw = reinterpret_cast<DrawPath>(dlsym(handle, "ladybird_v_skia_draw_svg_path"));
        linear = reinterpret_cast<DrawLinear>(dlsym(handle, "ladybird_v_skia_draw_svg_linear_gradient_path"));
        radial = reinterpret_cast<DrawRadial>(dlsym(handle, "ladybird_v_skia_draw_svg_radial_gradient_path"));
        assert(draw && linear && radial);
    } else {
        check_clip_regions();
    }
    // Recorded from the production bridge before destination-clip culling.
    constexpr uint64_t expected[] {
        13326648589223656204ull, 10818112546675469282ull, 18050218838604254806ull,
        3176168178948245612ull, 13251525271534620924ull, 5986896132057339539ull,
        10032593970623556589ull, 5679000062845796926ull, 7795328847596361146ull,
        7548049075649717029ull, 7548049075649717029ull, 4905182733670742812ull,
        1680864086619649475ull, 1494876829700354683ull, 15882196364075007761ull,
    };
    bool passed = true;
    for (int index = 0; index < 15; ++index) {
        auto hash = render_case(index, draw, linear, radial);
        std::printf("case %d: %llu%s\n", index, static_cast<unsigned long long>(hash),
            reference || hash == expected[index] ? " PASS" : " FAIL");
        if (!reference && hash != expected[index])
            passed = false;
    }
    return passed ? 0 : 1;
}
