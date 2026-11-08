#import "../native/include/native_layer_presentation_darwin.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

static CGImageRef make_document(CGColorSpaceRef color, bool rgba, int alpha, int scale)
{
    size_t width = 67 * scale, height = 43 * scale, pitch = width * 4 + 16;
    auto format = rgba ? kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
                       : kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little;
    auto context = CGBitmapContextCreate(nullptr, width, height, 8, pitch, color, format);
    assert(context);
    auto *pixels = static_cast<uint8_t *>(CGBitmapContextGetData(context));
    std::memset(pixels, 0x17, pitch * height);
    for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < width; ++x) {
        uint8_t a = alpha < 0 ? (x * 37 + y * 19) % 256 : alpha;
        auto *p = pixels + y * pitch + x * 4;
        p[0] = a / 2; p[1] = a / 3; p[2] = a / 5; p[3] = a;
    }
    auto image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    assert(image);
    return image;
}

static int test_publication_pixels()
{
    int comparisons = 0;
    for (auto source_space : {kCGColorSpaceSRGB, kCGColorSpaceDisplayP3, kCGColorSpaceGenericRGBLinear})
    for (bool rgba : {false, true}) for (int alpha : {0, -1, 255}) for (int scale : {1, 2}) {
        auto color = CGColorSpaceCreateWithName(source_space);
        auto image = make_document(color, rgba, alpha, scale);
        CGColorSpaceRelease(color);
        for (auto target_space : {kCGColorSpaceSRGB, kCGColorSpaceDisplayP3, kCGColorSpaceGenericRGBLinear})
        for (bool fresh : {false, true}) for (int clip = 0; clip < 4; ++clip)
        for (bool fractional : {false, true}) {
            const size_t width = 96 * scale, height = 72 * scale, pitch = width * 4 + 16;
            std::vector<uint8_t> expected(pitch * height), actual(expected.size());
            if (!fresh) for (size_t i = 0; i < expected.size(); ++i)
                expected[i] = i % 4 == 3 ? 128 : (i * 17 % 256) / 2;
            actual = expected;
            color = CGColorSpaceCreateWithName(target_space);
            auto create = [&](std::vector<uint8_t>& pixels) {
                auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
                    kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
                assert(context);
                CGContextScaleCTM(context, scale, scale);
                if (!fresh) CGContextSetAlpha(context, .65);
                if (clip == 1) CGContextClipToRect(context, CGRectMake(17.25, 19.5, 53.75, 31.25));
                if (clip == 2) {
                    CGContextAddEllipseInRect(context, CGRectMake(12.5, 8.25, 61.75, 47.5));
                    CGContextClip(context);
                }
                if (clip == 3) {
                    CGContextTranslateCTM(context, 7.25, 3.5);
                    CGContextRotateCTM(context, .125);
                }
                return context;
            };
            auto before = create(expected), after = create(actual);
            CGColorSpaceRelease(color);
            CGRect rect = fractional ? CGRectMake(9.375, 11.25, 67.5, 43.25)
                                     : CGRectMake(9, 11, 67, 43);
            CGContextDrawImage(before, rect, image);
            native_layer_draw_document_image(after, rect, image, fresh);
            // This later translucent paint detects a leaked copy blend mode.
            for (auto context : {before, after}) {
                CGContextSetRGBFillColor(context, .7, .2, .3, .35);
                CGContextFillRect(context, CGRectMake(11, 13, 29, 23));
                CGContextFlush(context);
            }
            assert(expected == actual);
            CGContextRelease(before); CGContextRelease(after);
            ++comparisons;
        }
        CGImageRelease(image);
    }
    return comparisons;
}

static int probe_depth, probe_claims;
static bool nested_before_claim;
static void probe_frame(id view, SEL command, NSRect rect)
{
    (void)command;
    auto context = NSGraphicsContext.currentContext.CGContext;
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto foreign = CGBitmapContextCreate(nullptr, 4, 4, 8, 16, color,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(color);
    assert(foreign && !native_layer_claim_document_bitmap(foreign));
    assert(!native_layer_claim_document_bitmap(nullptr));
    CGContextRelease(foreign);
    auto nested = [&] {
        ++probe_depth;
        auto image = native_layer_raster_frame(view, 2, (IMP)probe_frame);
        assert(image);
        CGImageRelease(image);
        --probe_depth;
        assert(NSGraphicsContext.currentContext.CGContext == context);
    };
    if (!probe_depth && nested_before_claim) nested();
    assert(native_layer_claim_document_bitmap(context));
    ++probe_claims;
    assert(!native_layer_claim_document_bitmap(context));
    if (!probe_depth && !nested_before_claim) nested();
    assert(!native_layer_claim_document_bitmap(context));
    CGContextSetRGBFillColor(context, 1, 0, 0, .5);
    CGContextFillRect(context, rect);
}

static void throwing_frame(id view, SEL command, NSRect rect)
{
    (void)view; (void)command; (void)rect;
    assert(native_layer_claim_document_bitmap(NSGraphicsContext.currentContext.CGContext));
    [NSException raise:@"DocumentPublicationTest" format:@"unwind the frame scope"];
}

static void test_frame_scope()
{
    auto view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 67, 43)];
    NSGraphicsContext *previous = NSGraphicsContext.currentContext;
    for (bool before : {false, true}) {
        nested_before_claim = before;
        auto image = native_layer_raster_frame(view, 1, (IMP)probe_frame);
        assert(image);
        CGImageRelease(image);
        assert(NSGraphicsContext.currentContext == previous);
        assert(native_layer_document_bitmap == nullptr && !native_layer_document_bitmap_claimed);
    }
    assert(probe_claims == 4);
    bool caught = false;
    @try { native_layer_raster_frame(view, 1, (IMP)throwing_frame); }
    @catch (NSException *exception) {
        assert([exception.name isEqualToString:@"DocumentPublicationTest"]);
        caught = true;
    }
    assert(caught && NSGraphicsContext.currentContext == previous);
    assert(native_layer_document_bitmap == nullptr && !native_layer_document_bitmap_claimed);
#if !__has_feature(objc_arc)
    [view release];
#endif
}

int main()
{
    @autoreleasepool {
        int comparisons = test_publication_pixels();
        test_frame_scope();
        std::printf("Document publication: %d exact comparisons, blend-state restoration, one claim per frame, nested scopes and exception cleanup passed\n", comparisons);
    }
}
