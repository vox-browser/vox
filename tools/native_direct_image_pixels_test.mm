// Preserve the original publisher bytes and the existing Brave photo pixels.
#import <Foundation/Foundation.h>
#include "../native/include/native_graphite_bridge.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

int main(int argc, char** argv) { @autoreleasepool {
    assert(argc == 5);
    auto fixture = [NSString stringWithContentsOfFile:@(argv[2])
        encoding:NSUTF8StringEncoding error:nil];
    NSRange start = [fixture rangeOfString:@"data:image/webp;base64,"];
    assert(start.location != NSNotFound);
    auto tail = [fixture substringFromIndex:NSMaxRange(start)];
    NSRange end = [tail rangeOfString:@"\""];
    assert(end.location != NSNotFound);
    auto encoded = [[NSData alloc] initWithBase64EncodedString:
        [tail substringToIndex:end.location] options:0];
    assert(encoded);
    auto reference_url = CFURLCreateFromFileSystemRepresentation(nullptr,
        reinterpret_cast<UInt8 const*>(argv[3]), strlen(argv[3]), false);
    auto source = CGImageSourceCreateWithURL(reference_url, nullptr);
    auto reference = CGImageSourceCreateImageAtIndex(source, 0, nullptr);
    assert(reference && CGImageGetWidth(reference) == 1024 && CGImageGetHeight(reference) == 768);
    std::vector<uint8_t> expected(1024 * 768 * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(expected.data(), 1024, 768, 8, 4096, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little);
    assert(context);
    CGContextDrawImage(context, CGRectMake(0, 0, 1024, 768), reference);
    CGContextRelease(context); CGColorSpaceRelease(space); CGImageRelease(reference);
    CFRelease(source); CFRelease(reference_url);

    auto codec = dlopen(argv[4], RTLD_NOW | RTLD_LOCAL); assert(codec);
    auto info = reinterpret_cast<int(*)(uint8_t const*, size_t, int*, int*)>(dlsym(codec, "WebPGetInfo"));
    auto decode = reinterpret_cast<uint8_t*(*)(uint8_t const*, size_t, uint8_t*, size_t, int,
        uint8_t*, size_t, int, uint8_t*, size_t, int)>(dlsym(codec, "WebPDecodeYUVInto"));
    int w, h; assert(info && decode && info(static_cast<uint8_t const*>(encoded.bytes), encoded.length, &w, &h));
    assert(w == 668 && h == 504);
    int uw = (w + 1) / 2, uh = (h + 1) / 2;
    size_t ys = size_t(w) * h, us = size_t(uw) * uh;
    std::vector<uint8_t> planes(ys + 2 * us);
    assert(decode(static_cast<uint8_t const*>(encoded.bytes), encoded.length,
        planes.data(), ys, w, planes.data() + ys, us, uw, planes.data() + ys + us, us, uw));
    auto library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL); assert(library);
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_direct_image_pixels)>(
        dlsym(library, "vox_graphite_draw_direct_image_pixels"));
    auto clear = reinterpret_cast<decltype(&vox_graphite_release_unused_graphics_memory)>(
        dlsym(library, "vox_graphite_release_unused_graphics_memory"));
    assert(draw && clear);
    int comparisons = 0;
    for (int explicit_clip : {0, int(VOX_GRAPHITE_IMAGE_EXPLICIT_RECT_CLIP)}) {
        clear();
        for (int repeat : {0, 1}) {
            VoxGraphiteImage image {};
            image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
            image.source[2] = image.width = w; image.source[3] = image.height = h;
            image.destination[0] = image.clip[0] = 125;
            image.destination[1] = image.clip[1] = 429;
            image.destination[2] = image.clip[2] = 578;
            image.destination[3] = image.clip[3] = 436;
            for (int k = 4; k < 12; ++k) image.clip[k] = 12;
            image.pitch = w * 4; image.pixels = planes.data(); image.opacity = 1;
            image.flags = 6 | explicit_clip;
            std::vector<uint8_t> actual(expected.size());
            for (size_t k = 0; k < actual.size(); k += 4) {
                actual[k] = 255; actual[k + 1] = 253; actual[k + 2] = 252; actual[k + 3] = 255;
            }
            assert(draw(actual.data(), 1024, 768, 4096, 1, &image));
            size_t different = 0;
            // Include every visible photo pixel and its rounded edge coverage.
            for (int y = 429; y < 768; ++y) for (int x = 125; x < 703; ++x) {
                size_t k = size_t(y * 1024 + x) * 4;
                different += std::memcmp(actual.data() + k, expected.data() + k, 4) != 0;
            }
            if (different) std::fprintf(stderr, "Direct image clip=%d repeat=%d: %zu differing pixels\n",
                explicit_clip != 0, repeat, different);
            assert(different == 0); ++comparisons;
        }
    }
    std::printf("Direct compositor images: %d exact cold/warm rounded photo comparisons passed\n", comparisons);
    [encoded release]; dlclose(library); dlclose(codec);
} }
