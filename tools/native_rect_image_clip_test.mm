// A real publisher image, frozen Brave pixels and the native image adapter.
#import <Cocoa/Cocoa.h>
#include "../native/include/native_graphite_bridge.h"
#include <cassert>
#include <cstdio>
#include <dlfcn.h>
#include <fstream>
#include <vector>

static std::vector<uint8_t> read_bytes(char const* path)
{
    std::ifstream file(path, std::ios::binary);
    assert(file);
    return {std::istreambuf_iterator<char>(file), {}};
}

using DrawImage = int (*)(CGContextRef, uint8_t const*, int, int, int,
    float, float, float, float, float, float, float, float,
    float, float, float, float, float, float, float, float, float, float,
    float, float, float, float, float, float, int, int, float const*);

int main(int argc, char** argv)
{
    @autoreleasepool {
        assert(argc == 6);
        // The adapter lazily opens this helper by @rpath. Standalone tests have
        // no app executable rpath, so load the pinned bundle's helper first.
        auto gpu = dlopen(argv[5], RTLD_NOW | RTLD_LOCAL);
        assert(gpu && dlsym(gpu, "vox_graphite_draw_image_pixels"));
        auto encoded = read_bytes(argv[1]);
        auto reference = [NSBitmapImageRep imageRepWithData:
            [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]]];
        assert(reference && reference.pixelsWide == 1024 && reference.pixelsHigh == 768);
        assert(reference.bitsPerSample == 8 && !reference.isPlanar);
        assert(reference.samplesPerPixel == 3 || reference.samplesPerPixel == 4);
        bool alpha_first = reference.bitmapFormat & NSBitmapFormatAlphaFirst;
        std::vector<uint8_t> expected(242 * 242 * 4);
        for (int y = 0; y < 242; ++y) for (int x = 0; x < 242; ++x) {
            NSUInteger values[5] {};
            [reference getPixel:values atX:4 + x y:229 + y];
            auto* pixel = expected.data() + (y * 242 + x) * 4;
            int rgb = reference.hasAlpha && alpha_first ? 1 : 0;
            for (int channel = 0; channel < 3; ++channel) pixel[channel] = values[rgb + channel];
            pixel[3] = reference.hasAlpha ? values[alpha_first ? 0 : 3] : 255;
            assert(pixel[3] == 255);
        }
        auto decoder = dlopen(argv[4], RTLD_NOW | RTLD_LOCAL);
        assert(decoder);
        auto info = reinterpret_cast<int (*)(uint8_t const*, size_t, int*, int*)>(
            dlsym(decoder, "WebPGetInfo"));
        auto decode = reinterpret_cast<uint8_t* (*)(uint8_t const*, size_t,
            uint8_t*, size_t, int, uint8_t*, size_t, int, uint8_t*, size_t, int)>(
            dlsym(decoder, "WebPDecodeYUVInto"));
        int width = 0, height = 0;
        assert(info && decode && info(encoded.data(), encoded.size(), &width, &height));
        assert(width == 668 && height == 445);
        size_t y_size = size_t(width) * height, uv_size = size_t((width + 1) / 2) * ((height + 1) / 2);
        std::vector<uint8_t> planes(y_size + 2 * uv_size);
        assert(decode(encoded.data(), encoded.size(), planes.data(), y_size, width,
            planes.data() + y_size, uv_size, (width + 1) / 2,
            planes.data() + y_size + uv_size, uv_size, (width + 1) / 2));
        auto bridge = dlopen(argv[3], RTLD_NOW | RTLD_LOCAL);
        assert(bridge);
        auto draw = reinterpret_cast<DrawImage>(dlsym(bridge, "ladybird_v_skia_draw_rgba_image"));
        auto painting = reinterpret_cast<void (*)(int)>(dlsym(bridge, "ladybird_v_skia_set_chromium_painting"));
        auto recording = reinterpret_cast<void (*)(int, int, int)>(dlsym(bridge, "ladybird_v_skia_set_shared_recording"));
        auto layer = reinterpret_cast<void (*)(double, double, int)>(dlsym(bridge, "ladybird_v_skia_set_raster_layer"));
        auto layer_size = reinterpret_cast<void (*)(double, double)>(dlsym(bridge, "ladybird_v_skia_set_raster_layer_size"));
        auto grid = reinterpret_cast<void (*)(int const*, int, int, int, int)>(dlsym(bridge, "ladybird_v_skia_set_msaa_grid"));
        auto rows = reinterpret_cast<void (*)(int const*, int, int)>(dlsym(bridge, "ladybird_v_skia_set_msaa_tiles"));
        assert(draw && painting && recording && layer && layer_size && grid && rows);
        int exact = 0;
        for (int page_y : {0, 60}) for (int raster_grid : {0, 1}) for (bool gpu_crop : {false, true}) {
            int canvas_height = page_y ? 852 : 768;
            std::vector<uint8_t> frame(size_t(1024) * canvas_height * 4, 255);
            auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            auto context = CGBitmapContextCreate(frame.data(), 1024, canvas_height, 8, 4096,
                space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context);
            CGColorSpaceRelease(space);
            auto card = CGRectMake(4, canvas_height - page_y - 471, 242, 242);
            CGContextSetRGBFillColor(context, 10.0 / 255, 137.0 / 255, 53.0 / 255, 1);
            CGContextFillRect(context, card);
            CGContextClipToRect(context, card);
            painting(1); recording(0, 1024, 768); layer(0, 0, 1);
            layer_size(1024, 2000); rows(nullptr, 0, 256); grid(nullptr, 0, 1024, 256, raster_grid);
            float clip[12] {4, -13, 484, 484};
            if (gpu_crop) { clip[1] = 229; clip[2] = clip[3] = 242; }
            // gfx::MapRect maps the snapped 484px object-fit crop from the
            // complete 726px destination into the original 668px image.
            assert(draw(context, planes.data(), width, height, width * 4,
                4, -13, 484, 484, 121.f * (668.f / 726.f), 0, 484.f * (668.f / 726.f), 445,
                clip[0], clip[1], clip[2], clip[3], 1, 0, 0, 1, 0, 0,
                0, page_y, 0, 1024, canvas_height, 1, 0, 6, clip + 4));
            CGContextFlush(context);
            int differences = 0;
            for (int y = 0; y < 242; ++y) for (int x = 0; x < 242; ++x) {
                auto* pixel = frame.data() + ((page_y + 229 + y) * 1024 + 4 + x) * 4;
                auto* wanted = expected.data() + (y * 242 + x) * 4;
                bool changed = false;
                for (int channel = 0; channel < 4; ++channel) changed |= pixel[channel] != wanted[channel];
                if (gpu_crop && changed && differences < 3)
                    std::fprintf(stderr, "pixel %d,%d actual=%u,%u,%u,%u expected=%u,%u,%u,%u\n",
                        x + 4, y + 229, pixel[0], pixel[1], pixel[2], pixel[3],
                        wanted[0], wanted[1], wanted[2], wanted[3]);
                differences += changed;
            }
            std::printf("page_y=%d grid=%d gpu_crop=%d different_pixels=%d\n",
                page_y, raster_grid, gpu_crop, differences);
            if (gpu_crop) { assert(differences == 0); ++exact; }
            CGContextRelease(context);
        }
        std::printf("%d exact Brave photo crops; four unmodified native controls retained\n", exact);
    }
}
