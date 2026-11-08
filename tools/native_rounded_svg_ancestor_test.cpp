#include "native/include/native_rounded_svg_ancestor_darwin.h"
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <string>
#include <vector>

template<class T> static T symbol(void *library, const char *name)
{
    auto value = reinterpret_cast<T>(dlsym(library, name));
    if (!value) { std::fprintf(stderr, "%s: %s\n", name, dlerror()); std::abort(); }
    return value;
}

static int calls, fail_on_call;
static int failing_batch(CGContextRef context, const VoxGraphitePath *, int,
    const float *, float, float, float, float, float, float, float, float, float,
    int, const float *)
{
    // Even a backend that paints before failing must not change the destination.
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 1024, 768));
    return ++calls != fail_on_call;
}

int main(int argc, char **argv)
{
    assert(argc == 4);
    auto library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) { std::fprintf(stderr, "%s\n", dlerror()); return 1; }
    auto batch = symbol<NativeSvgPathBatch>(library, "ladybird_v_skia_draw_svg_path_batch");
    auto mode = symbol<void (*)(int)>(library, "ladybird_v_skia_set_chromium_painting");
    auto layer = symbol<void (*)(double, double, int)>(library, "ladybird_v_skia_set_raster_layer");
    auto size = symbol<void (*)(double, double)>(library, "ladybird_v_skia_set_raster_layer_size");
    auto tiles = symbol<void (*)(const int *, int, int)>(library, "ladybird_v_skia_set_msaa_tiles");
    int scale = std::atoi(argv[3]);
    assert(scale == 1 || scale == 2);
    constexpr int width = 1024, height = 768;
    std::vector<unsigned char> pixels(width * height * 4 * scale * scale);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width * scale, height * scale,
        8, width * scale * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    CGContextSetRGBFillColor(context, 252. / 255, 253. / 255, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    mode(1);
    for (int diameter : {156, 20}) for (int mask = 0; mask < 4; ++mask) {
        float x = 24 + 164 * mask, y = diameter == 156 ? 24 : 224;
        float rounded[] {0, 0, float(diameter), float(diameter), diameter / 2.f, diameter / 2.f,
            diameter / 2.f, diameter / 2.f, diameter / 2.f, diameter / 2.f, diameter / 2.f, diameter / 2.f};
        float rect[60] {};
        rect[0] = 0; rect[12] = 1; rect[13] = diameter;
        rect[24] = 1; rect[25] = rect[26] = diameter;
        rect[36] = 1; rect[38] = diameter; rect[48] = 5;
        VoxGraphitePath paths[2] {};
        for (auto& path : paths) {
            path.matrix[0] = path.matrix[4] = path.matrix[8] = 1;
            path.segments = rect; path.segment_count = 5; path.alpha = 255;
        }
        paths[0].red = paths[0].green = paths[0].blue = 211;
        paths[1].red = 247; paths[1].green = 178; paths[1].blue = 89;
        float outer[] {1, 0, 0, 1, x, y};
        layer(mask ? x : 0, mask ? y : 0, !mask);
        size(mask ? diameter : width, mask ? diameter : height);
        int rows[] {0, 1, 2, 3, 4, 5, 6}; tiles(rows, 7, 256);
        if (mask) {
            assert(native_draw_rounded_svg_ancestor_in_context(context, batch, paths, 2,
                outer, 0, 0, diameter, diameter, 0, 0, 0, width, height, rounded));
        } else {
            assert(batch(context, paths, 2, outer, 0, 0, diameter, diameter,
                0, 0, 0, width, height, 1, rounded));
        }
        auto before = pixels;
        auto clip = CGContextGetClipBoundingBox(context);
        for (int fail : {1, 2}) {
            calls = 0; fail_on_call = fail;
            assert(!native_draw_rounded_svg_ancestor_in_context(context, failing_batch,
                paths, 2, outer, 0, 0, diameter, diameter, 0, 0, 0, width, height, rounded));
            assert(calls == fail && pixels == before);
            assert(CGRectEqualToRect(clip, CGContextGetClipBoundingBox(context)));
        }
        calls = 0;
        assert(!native_draw_rounded_svg_ancestor_in_context(context, failing_batch,
            paths, 2, outer, 0, 0, diameter, diameter, 0, 0, 0, 100000, 100000, rounded));
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, 1, 0);
        assert(!native_draw_rounded_svg_ancestor_in_context(context, failing_batch,
            paths, 2, outer, 0, 0, diameter, diameter, 0, 0, 0, width, height, rounded));
        CGContextRestoreGState(context);
        assert(calls == 0 && pixels == before);
    }
    CGContextFlush(context);
    auto *file = std::fopen(argv[2], "wb");
    assert(file && std::fwrite(pixels.data(), 1, pixels.size(), file) == pixels.size());
    std::fclose(file);
    CGContextRelease(context);
    std::puts("Rounded SVG ancestor: eight scenes, transactional failures, bounds and transforms passed");
}
