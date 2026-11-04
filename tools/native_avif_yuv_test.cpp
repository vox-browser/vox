#include "../native_avif.h"
#include "../native_graphite_bridge.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>

int main(int argc, char** argv) {
    assert(argc == 4);
    auto* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    assert(library);
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_image_pixels)>(dlsym(library, "vox_graphite_draw_image_pixels"));
    auto supported = reinterpret_cast<int(*)()>(dlsym(library, "vox_graphite_supports_yuv422"));
    assert(draw && supported && supported());
    auto url = CFURLCreateFromFileSystemRepresentation(nullptr, reinterpret_cast<UInt8 const*>(argv[3]), strlen(argv[3]), false);
    auto source = CGImageSourceCreateWithURL(url, nullptr);
    auto reference = CGImageSourceCreateImageAtIndex(source, 0, nullptr);
    assert(reference && CGImageGetWidth(reference) == 1024 && CGImageGetHeight(reference) == 768);
    std::vector<uint8_t> expected(1024 * 768 * 4), actual(expected.size(), 255);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(expected.data(), 1024, 768, 8, 4096, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little);
    assert(context);
    CGContextDrawImage(context, CGRectMake(0, 0, 1024, 768), reference);
    CGContextRelease(context); CGColorSpaceRelease(space); CGImageRelease(reference); CFRelease(source); CFRelease(url);
    std::ifstream file(argv[2], std::ios::binary);
    std::vector<uint8_t> bytes{std::istreambuf_iterator<char>(file), {}};
    int32_t w, h, size, sub;
    auto* planes = vox_avif_decode_yuv(bytes.data(), bytes.size(), &w, &h, &size, &sub);
    assert(planes && sub == 1 && w == 585 && h == 390);
    int comparisons = 0;
    for (int nearest : {0, 1}) for (int msaa : {0, 32}) for (int repeat : {0, 1}) {
        std::fill(actual.begin(), actual.end(), 255);
        VoxGraphiteImage image {};
        image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
        image.source[2] = w; image.source[3] = h;
        image.destination[0] = image.clip[0] = 32; image.destination[1] = image.clip[1] = 64;
        image.destination[2] = image.clip[2] = w; image.destination[3] = image.clip[3] = h;
        image.opacity = 1; image.width = w; image.height = h; image.pitch = w * 4;
        image.flags = 12 | VOX_GRAPHITE_IMAGE_YUV422 | msaa;
        image.nearest = nearest; image.pixels = planes;
        assert(draw(actual.data(), 1024, 768, 4096, 1, &image));
        for (int y = 64; y < 454; ++y) for (int x = 32; x < 617; ++x)
            for (int c = 0; c < 4; ++c) assert(actual[(y * 1024 + x) * 4 + c] == expected[(y * 1024 + x) * 4 + c]);
        ++comparisons;
    }
    vox_avif_release(planes); dlclose(library);
    std::printf("AVIF YUV422: %d exact full-size Brave photo comparisons, nearest/linear, MSAA and warm caches passed\n", comparisons);
}
