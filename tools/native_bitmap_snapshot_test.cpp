#include "../native/include/native_bitmap_snapshot_darwin.h"
#include "../native/include/native_opacity_group_darwin.h"
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <vector>

static CGImageRef make_image(bool owned, CFStringRef space, bool rgba, int scale, int padding, bool match_destination = false)
{
    size_t width = 67 * scale, height = 43 * scale, pitch = width * 4 + padding;
    auto color = CGColorSpaceCreateWithName(space);
    CGBitmapInfo info = rgba
        ? CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big
        : CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little;
    auto context = CGBitmapContextCreate(nullptr, width, height, 8, pitch, color, info);
    CGColorSpaceRelease(color);
    assert(context);
    auto *pixels = static_cast<uint8_t *>(CGBitmapContextGetData(context));
    for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < width; ++x) {
        uint8_t a = (x * 37 + y * 19) % 256;
        auto *p = pixels + y * pitch + x * 4;
        p[0] = a / 2; p[1] = a / 3; p[2] = a / 5; p[3] = a;
    }
    // Finish with actual CGContext drawing as well as direct bitmap writes.
    CGContextSetRGBFillColor(context, .375, .625, .875, .7);
    CGContextFillEllipseInRect(context, CGRectMake(13.5, 7.25, 37.5, 21.75));
    if (owned && match_destination) {
        // A live backdrop/filter snapshot must remain immutable when the
        // producer's final allocation is converted in place for publication.
        auto previous = CGBitmapContextCreateImage(context);
        assert(previous);
        auto saved = CGDataProviderCopyData(CGImageGetDataProvider(previous));
        assert(saved);
        std::vector<uint8_t> saved_bytes(CFDataGetBytePtr(saved), CFDataGetBytePtr(saved) + CFDataGetLength(saved));
        CFRelease(saved);
        color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto destination = CGBitmapContextCreate(nullptr, 4, 4, 8, 16, color,
            CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little);
        CGColorSpaceRelease(color);
        assert(destination);
        auto image = native_take_bitmap_image_for_destination(context, destination);
        saved = CGDataProviderCopyData(CGImageGetDataProvider(previous));
        assert(saved && size_t(CFDataGetLength(saved)) == saved_bytes.size());
        assert(!std::memcmp(CFDataGetBytePtr(saved), saved_bytes.data(), saved_bytes.size()));
        CFRelease(saved); CGImageRelease(previous);
        CGContextRelease(destination);
        return image;
    }
    if (owned) return native_take_bitmap_image(context);
    auto image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static void compare_metadata(CGImageRef before, CGImageRef after)
{
    assert(before && after);
    assert(CGImageGetWidth(before) == CGImageGetWidth(after));
    assert(CGImageGetHeight(before) == CGImageGetHeight(after));
    assert(CGImageGetBitsPerComponent(before) == CGImageGetBitsPerComponent(after));
    assert(CGImageGetBitsPerPixel(before) == CGImageGetBitsPerPixel(after));
    assert(CGImageGetBytesPerRow(before) == CGImageGetBytesPerRow(after));
    assert(CGImageGetBitmapInfo(before) == CGImageGetBitmapInfo(after));
    assert(CGImageGetShouldInterpolate(before) == CGImageGetShouldInterpolate(after));
    assert(CGImageGetRenderingIntent(before) == CGImageGetRenderingIntent(after));
    assert(CFEqual(CGImageGetColorSpace(before), CGImageGetColorSpace(after)));
}

static int test_opacity_results()
{
    int comparisons = 0;
    for (int width : {1, 7, 8, 17, 64, 257}) for (int height : {1, 3, 17})
    for (float opacity : {0.0f, .3f, .5f, .7f, .8f, 1.0f}) for (int alpha : {128, 255}) {
        size_t bytes = size_t(width) * height * 4;
        std::vector<uint8_t> layer(bytes), backdrop(bytes);
        for (size_t i = 0; i < bytes / 4; ++i) {
            uint8_t a = (i * 37 + 51) % 256;
            layer[i * 4] = a / 2; layer[i * 4 + 1] = a / 3;
            layer[i * 4 + 2] = a / 5; layer[i * 4 + 3] = a;
            backdrop[i * 4] = alpha / 2; backdrop[i * 4 + 1] = alpha / 3;
            backdrop[i * 4 + 2] = alpha / 5; backdrop[i * 4 + 3] = alpha;
        }
        int bounds[4];
        assert(native_opacity_layer_ink_bounds(layer.data(), width * 4, 0, 0, width, height,
            &bounds[0], &bounds[1], &bounds[2], &bounds[3]));
        assert(bounds[0] == 0 && bounds[1] == 0 && bounds[2] == width && bounds[3] == height);
        auto *legacy_pixels = static_cast<uint8_t *>(std::malloc(bytes));
        assert(legacy_pixels);
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto info = CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big;
        auto legacy_context = CGBitmapContextCreate(legacy_pixels, width, height, 8, width * 4, color, info);
        auto owned_context = CGBitmapContextCreate(nullptr, width, height, 8, width * 4, color, info);
        CGColorSpaceRelease(color);
        assert(legacy_context && owned_context);
        auto *owned_pixels = static_cast<uint8_t *>(CGBitmapContextGetData(owned_context));
        assert(owned_pixels);
        for (int y = 0; y < height; ++y) {
            size_t row = size_t(y) * width * 4;
            native_composite_opacity_pixels(layer.data() + row, backdrop.data() + row,
                legacy_pixels + row, width, opacity);
            native_composite_opacity_pixels(layer.data() + row, backdrop.data() + row,
                owned_pixels + row, width, opacity);
        }
        auto legacy = CGBitmapContextCreateImage(legacy_context);
        CGContextRelease(legacy_context);
        std::free(legacy_pixels);
        auto owned = native_take_bitmap_image(owned_context);
        compare_metadata(legacy, owned);
        auto before = CGDataProviderCopyData(CGImageGetDataProvider(legacy));
        auto after = CGDataProviderCopyData(CGImageGetDataProvider(owned));
        assert(before && after && CFDataGetLength(before) == CFDataGetLength(after));
        assert(!std::memcmp(CFDataGetBytePtr(before), CFDataGetBytePtr(after), CFDataGetLength(before)));
        CFRelease(before); CFRelease(after);
        CGImageRelease(legacy); CGImageRelease(owned);
        ++comparisons;
    }
    return comparisons;
}

int main()
{
    int comparisons = 0;
    for (auto source_space : {kCGColorSpaceSRGB, kCGColorSpaceDisplayP3, kCGColorSpaceGenericRGBLinear})
    for (bool source_rgba : {false, true}) for (int source_scale : {1, 2}) for (int padding : {0, 16}) {
        auto before_image = make_image(false, source_space, source_rgba, source_scale, padding);
        auto after_image = make_image(true, source_space, source_rgba, source_scale, padding);
        auto matched_image = make_image(true, source_space, source_rgba, source_scale, padding, true);
        compare_metadata(before_image, after_image);
        assert(matched_image && CGImageGetBitmapInfo(matched_image)
            == (CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little));
        for (auto destination_space : {kCGColorSpaceSRGB, kCGColorSpaceDisplayP3, kCGColorSpaceGenericRGBLinear})
        for (bool rgba : {false, true}) for (int scale : {1, 2}) for (int clip : {0, 1, 2, 3})
        for (auto blend : {kCGBlendModeNormal, kCGBlendModeCopy, kCGBlendModeMultiply})
        for (float alpha : {1.0f, .65f}) {
            int width = 96 * scale, height = 72 * scale, pitch = width * 4 + 16;
            std::vector<uint8_t> expected(size_t(pitch) * height), actual(expected.size()), matched(expected.size());
            for (size_t i = 0; i < expected.size(); ++i) expected[i] = i % 4 == 3 ? 255 : i * 17 % 256;
            actual = expected;
            matched = expected;
            auto color = CGColorSpaceCreateWithName(destination_space);
            CGBitmapInfo info = rgba
                ? CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big
                : CGBitmapInfo(kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little;
            auto make_context = [&](std::vector<uint8_t>& pixels) {
                auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color, info);
                assert(context);
                CGContextScaleCTM(context, scale, scale);
                if (clip == 1) CGContextClipToRect(context, CGRectMake(17.25, 19.5, 53.75, 31.25));
                if (clip == 2) {
                    CGContextAddEllipseInRect(context, CGRectMake(12.5, 8.25, 61.75, 47.5));
                    CGContextClip(context);
                }
                if (clip == 3) {
                    CGContextTranslateCTM(context, 7.25, 3.5);
                    CGContextRotateCTM(context, .125);
                }
                CGContextSetAlpha(context, alpha);
                CGContextSetBlendMode(context, blend);
                return context;
            };
            auto before = make_context(expected), after = make_context(actual), optimized = make_context(matched);
            CGColorSpaceRelease(color);
            CGRect destination = CGRectMake(9.375, 11.25, 67.5, 43.25);
            CGContextDrawImage(before, destination, before_image);
            CGContextDrawImage(after, destination, after_image);
            CGContextDrawImage(optimized, destination, matched_image);
            CGContextFlush(before); CGContextFlush(after); CGContextFlush(optimized);
            if (expected != actual || expected != matched) {
                std::cerr << "Snapshot mismatch source_rgba=" << source_rgba << " rgba=" << rgba
                    << " scale=" << scale << " clip=" << clip << " alpha=" << alpha << '\n';
                return 1;
            }
            CGContextRelease(before); CGContextRelease(after); CGContextRelease(optimized);
            comparisons += 2;
        }
        CGImageRelease(before_image); CGImageRelease(after_image); CGImageRelease(matched_image);
    }
    // The consumed context owns its pixels until the last image/provider owner
    // releases them, even after the producing scope has ended.
    int released = 0;
    auto *pixels = std::calloc(64, 1);
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreateWithData(pixels, 4, 4, 8, 16, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big,
        [](void *owner, void *data) { ++*static_cast<int *>(owner); std::free(data); }, &released);
    CGColorSpaceRelease(color);
    assert(context);
    auto image = native_take_bitmap_image(context);
    assert(image && released == 0);
    CGImageRetain(image);
    CGImageRelease(image);
    assert(released == 0);
    CGImageRelease(image);
    assert(released == 1);
    assert(!native_take_bitmap_image(nullptr));
    // A monochrome bitmap keeps the original snapshot fallback.
    color = CGColorSpaceCreateWithName(kCGColorSpaceGenericGrayGamma2_2);
    context = CGBitmapContextCreate(nullptr, 4, 4, 8, 4, color, kCGImageAlphaNone);
    CGColorSpaceRelease(color);
    assert(context);
    auto legacy = CGBitmapContextCreateImage(context);
    image = native_take_bitmap_image(context);
    compare_metadata(legacy, image);
    CGImageRelease(legacy); CGImageRelease(image);
    int opacity_comparisons = test_opacity_results();
    std::cout << "Bitmap handoff: " << comparisons << " exact comparisons, " << opacity_comparisons
        << " opacity results, metadata, ownership and fallback passed\n";
}
