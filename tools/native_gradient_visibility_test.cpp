#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <initializer_list>
#include <limits>
#include <cstdio>

int main()
{
    float stops[] {1, 0, 0, 0, 0, 0, 1, 0, -0.0f, .5f, 0, 0, 1, 0, 1};
    assert(vox_gradient_stops_are_transparent(stops, 1));
    assert(vox_gradient_stops_are_transparent(stops, 3));
    for (int index = 0; index < 3; ++index) {
        for (float alpha : {1.0f, 1.0f / 255, 1.0e-20f, -1.0f,
                std::numeric_limits<float>::infinity(), std::numeric_limits<float>::quiet_NaN()}) {
            stops[index * 5 + 3] = alpha;
            assert(!vox_gradient_stops_are_transparent(stops, 3));
        }
        stops[index * 5 + 3] = 0;
    }
    for (int offset = 0; offset < 15; ++offset) {
        float original = stops[offset];
        stops[offset] = std::numeric_limits<float>::quiet_NaN();
        assert(!vox_gradient_stops_are_transparent(stops, 3));
        stops[offset] = original;
    }
    assert(!vox_gradient_stops_are_transparent(nullptr, 2));
    assert(!vox_gradient_stops_are_transparent(stops, 0));
    assert(!vox_gradient_stops_are_transparent(stops, -1));
    assert(!vox_gradient_stops_are_transparent(stops, 65537));

    // Exercise the actual bridge with a shader factory that rejects its
    // input. Transparent CSS draws succeed without invoking that factory or
    // changing the backdrop, clip, or current transformation.
    constexpr int size = 32;
    std::vector<uint8_t> pixels(size * size * 4, 123);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), size, size, 8, size * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    CGContextClipToRect(context, CGRectMake(3, 4, 17, 19));
    auto before = pixels;
    auto bounds = CGContextGetClipBoundingBox(context);
    auto matrix = CGContextGetCTM(context);
    float path[] {0, 1, 1, 0,0,0,0,0,0,0,0,0,
                  1, 20, 1, 0,0,0,0,0,0,0,0,0,
                  1, 20, 20, 0,0,0,0,0,0,0,0,0,
                  1, 1, 20, 0,0,0,0,0,0,0,0,0,
                  5, 0, 0, 0,0,0,0,0,0,0,0,0};
    float points[] {0,0,20,20,0,0};
    int shader_calls = 0;
    auto draw = [&](int spread) {
        return draw_svg_gradient_path(context, path, 5, 0,
            1,0,0,1,0,0,0,0,0,size,size,0,0,0,0,4,1,0,0,1,0,0,
            spread,0,stops,3,1,1,points,1,nullptr,nullptr,
            [&](auto const&, auto const&, auto, auto const&) -> sk_sp<SkShader> {
                ++shader_calls;
                return nullptr;
            });
    };
    for (int spread : {3, 4}) {
        assert(draw(spread) == 1 && shader_calls == 0);
        assert(pixels == before);
        assert(CGRectEqualToRect(bounds, CGContextGetClipBoundingBox(context)));
        assert(CGAffineTransformEqualToTransform(matrix, CGContextGetCTM(context)));
    }
    // SVG modes and even a tiny nonzero CSS alpha retain ordinary handling.
    assert(draw(0) == 0 && shader_calls == 1);
    stops[8] = 1.0e-20f;
    assert(draw(4) == 0 && shader_calls == 2);
    CGContextRelease(context);
    std::puts("PASS transparent stops, tiny/visible/invalid alpha and invalid stop data");
}
