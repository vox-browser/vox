#include <CoreGraphics/CoreGraphics.h>
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>
#include "../native/include/native_glyph_flags.h"

static_assert((VOX_GLYPH_PRIVATE_BITMAP & 0xff) == 0,
    "private bitmap capability must not enable synthetic italics or change smoothing");

static bool rgba_bitmap(CGContextRef context)
{
    return CGBitmapContextGetBitsPerPixel(context) == 32
        && CGBitmapContextGetAlphaInfo(context) == kCGImageAlphaPremultipliedLast
        && (CGBitmapContextGetBitmapInfo(context) & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big;
}
static void swap_red_blue_pixels(uint8_t* destination, uint8_t const* source, size_t count)
{
    for (size_t i = 0; i < count; ++i) {
        destination[i*4] = source[i*4+2]; destination[i*4+1] = source[i*4+1];
        destination[i*4+2] = source[i*4]; destination[i*4+3] = source[i*4+3];
    }
}
#include "../native/include/native_glyph_bitmap_copy.h"

static CGContextRef frame(double scale)
{
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(nullptr, 96, 80, 8, 400, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(context);
    auto* data = static_cast<uint8_t*>(CGBitmapContextGetData(context));
    for (size_t i = 0; i < 80*400; ++i) data[i] = uint8_t(i * 17);
    for (size_t y = 0; y < 80; ++y)
        for (size_t x = 0; x < 96; ++x) data[y*400+x*4+3] = 255;
    CGContextScaleCTM(context, scale, scale);
    return context;
}

static void replay_image(CGContextRef context, std::vector<uint32_t> const& pixels, CGRect rectangle)
{
    std::vector<uint8_t> rgba(pixels.size()*4);
    swap_red_blue_pixels(rgba.data(), reinterpret_cast<uint8_t const*>(pixels.data()), pixels.size());
    auto provider = CGDataProviderCreateWithData(nullptr, rgba.data(), rgba.size(), nullptr);
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto image = CGImageCreate(20, 10, 8, 32, 80, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
        provider, nullptr, false, kCGRenderingIntentDefault);
    assert(image);
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, rectangle, image);
    CGContextRestoreGState(context); CGContextFlush(context);
    CGImageRelease(image); CGColorSpaceRelease(color); CGDataProviderRelease(provider);
}

int main()
{
    unsigned cases = 0;
    for (double scale : {1.0, 1.25, 2.0}) {
        for (int left : {0, 5, 20, 75}) {
            for (uint32_t alpha : {0u, 127u, 255u}) {
                auto actual = frame(scale), expected = frame(scale);
                auto* initial = static_cast<uint8_t*>(CGBitmapContextGetData(actual));
                std::vector<uint8_t> before(initial, initial + 80*400);
                auto previous = CGBitmapContextCreateImage(actual); assert(previous);
                std::vector<uint32_t> tile(200);
                for (size_t i = 0; i < tile.size(); ++i) {
                    auto a = alpha, r = uint32_t(i%256)*a/255;
                    auto g = uint32_t((i*3)%256)*a/255, b = uint32_t((i*7)%256)*a/255;
                    tile[i] = (a<<24) | (r<<16) | (g<<8) | b;
                }
                auto rectangle = CGRectMake(left/scale, 55/scale, 20/scale, 10/scale);
                assert(copy_glyph_bitmap(actual, tile.data(), 20, 10, rectangle));
                replay_image(expected, tile, rectangle);
                assert(!std::memcmp(CGBitmapContextGetData(actual), CGBitmapContextGetData(expected), before.size()));
                auto snapshot = CGDataProviderCopyData(CGImageGetDataProvider(previous));
                auto snapshot_pitch = CGImageGetBytesPerRow(previous);
                assert(CFDataGetLength(snapshot) >= static_cast<CFIndex>(snapshot_pitch*79 + 96*4));
                for (size_t row = 0; row < 80; ++row)
                    assert(!std::memcmp(CFDataGetBytePtr(snapshot) + row*snapshot_pitch,
                        before.data() + row*400, 96*4));
                CFRelease(snapshot); CGImageRelease(previous);
                CGContextRelease(actual); CGContextRelease(expected); ++cases;
            }
        }
    }
    auto context = frame(1);
    std::vector<uint32_t> tile(200, 0xff112233);
    auto rectangle = CGRectMake(20, 55, 20, 10);
    assert(!copy_glyph_bitmap(context, nullptr, 20, 10, rectangle));
    assert(!copy_glyph_bitmap(context, tile.data(), 0, 10, rectangle));
    assert(!copy_glyph_bitmap(context, tile.data(), 20, 10, CGRectMake(20.5,55,20,10)));
    assert(!copy_glyph_bitmap(context, tile.data(), 20, 10, CGRectMake(90,55,20,10)));
    CGContextSaveGState(context); CGContextTranslateCTM(context, 1, 0);
    assert(!copy_glyph_bitmap(context, tile.data(), 20, 10, rectangle));
    CGContextRestoreGState(context);
    CGContextClipToRect(context, CGRectMake(0,0,5,5));
    assert(!copy_glyph_bitmap(context, tile.data(), 20, 10, rectangle));
    CGContextRelease(context);
    std::printf("PASS %u exact tile publications, retained snapshots and rejected contexts\n",cases);
}
