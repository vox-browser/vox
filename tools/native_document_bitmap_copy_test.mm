#import "../native_layer_presentation_darwin.h"
#include "../native_bitmap_snapshot_darwin.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

static bool fused, snapshots, accepted;
static int alpha, padding, source_kind, placement;
static CGFloat scale;
static CFStringRef color_name;
static int comparisons, rejections;

static void paint_document(id view, SEL selector, NSRect rect)
{
    (void)view; (void)selector;
    auto destination = NSGraphicsContext.currentContext.CGContext;
    assert(!native_layer_copy_document_bitmap(nullptr, destination, rect.size.width, rect.size.height));
    size_t width = CGBitmapContextGetWidth(destination), height = CGBitmapContextGetHeight(destination);
    auto color = CGColorSpaceCreateWithName(source_kind == 2 ? kCGColorSpaceDisplayP3 : color_name);
    auto format = source_kind == 1
        ? kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
        : kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    size_t pitch = width * 4 + padding;
    auto source = CGBitmapContextCreate(nullptr, width, height, 8, pitch, color, format);
    CGColorSpaceRelease(color);
    assert(source);
    assert(!native_layer_copy_document_bitmap(source, destination, rect.size.width, rect.size.height));
    assert(native_layer_claim_document_bitmap(destination));
    assert(!native_layer_copy_document_bitmap(source, destination, INFINITY, rect.size.height));
    assert(!native_layer_copy_document_bitmap(source, destination, rect.size.width, NAN));
    auto *data = static_cast<uint8_t *>(CGBitmapContextGetData(source));
    std::memset(data, 0x17, pitch * height);
    for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < width; ++x) {
        uint8_t a = alpha < 0 ? (x * 37 + y * 19) % 256 : alpha;
        auto *p = data + y * pitch + x * 4;
        p[0] = a / 2; p[1] = a / 3; p[2] = a / 5; p[3] = a;
    }
    CGContextScaleCTM(source, scale, scale);
    CGContextSetRGBFillColor(source, .375, .625, .875, .7);
    CGContextFillEllipseInRect(source, CGRectMake(.375, .75, 13.5, 7.25));
    CGImageRef source_snapshot = snapshots ? CGBitmapContextCreateImage(source) : nullptr;
    CGImageRef destination_snapshot = snapshots ? CGBitmapContextCreateImage(destination) : nullptr;
    auto copy_bytes = [](CGImageRef image) {
        auto bytes = CGDataProviderCopyData(CGImageGetDataProvider(image));
        assert(bytes);
        std::vector<uint8_t> saved(CFDataGetBytePtr(bytes), CFDataGetBytePtr(bytes) + CFDataGetLength(bytes));
        CFRelease(bytes);
        return saved;
    };
    std::vector<uint8_t> source_before, destination_before;
    if (snapshots) {
        source_before = copy_bytes(source_snapshot);
        destination_before = copy_bytes(destination_snapshot);
    }
    if (placement == 1) CGContextTranslateCTM(destination, .25, .5);
    if (placement == 2) CGContextRotateCTM(destination, .125);
    if (placement == 3) CGContextClipToRect(destination, CGRectMake(0, 0, rect.size.width / 2, rect.size.height));
    CGFloat canvas_width = rect.size.width, canvas_height = rect.size.height;
    if (placement == 4) canvas_width -= .25;
    if (placement == 5) canvas_height -= .25;
    bool copied = fused && native_layer_copy_document_bitmap(source, destination, canvas_width, canvas_height);
    if (fused) {
        assert(copied == accepted);
        if (!copied) ++rejections;
    }
    if (copied) {
        // Publication reads the producer; it must not rewrite its format/data.
        assert(CGBitmapContextGetBitmapInfo(source) == format);
        CGContextRelease(source);
    } else {
        auto image = native_take_bitmap_image_for_destination(source, destination);
        assert(image);
        native_layer_draw_document_image(destination, CGRectMake(0, 0, canvas_width, canvas_height), image, 1);
        CGImageRelease(image);
    }
    if (snapshots) {
        assert(source_before == copy_bytes(source_snapshot));
        assert(destination_before == copy_bytes(destination_snapshot));
        CGImageRelease(source_snapshot); CGImageRelease(destination_snapshot);
    }
    // Subsequent chrome drawing must retain normal blending and the parent CTM.
    CGContextSetRGBFillColor(destination, .7, .2, .3, .35);
    CGContextFillRect(destination, CGRectMake(1.25, 2.5, 7.5, 3.25));
}

static std::vector<uint8_t> render(NSView *view)
{
    // Keep exercising the RGBA-to-BGRA compatibility path even though normal
    // frame allocation now uses RGBA and borrows that canvas directly.
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    size_t width = ceil(view.bounds.size.width * scale);
    size_t height = ceil(view.bounds.size.height * scale);
    auto context = CGBitmapContextCreate(nullptr, width, height, 8, width * 4, color,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    native_layer_document_bitmap = context;
    native_layer_document_bitmap_claimed = NO;
    paint_document(view, @selector(drawRect:), view.bounds);
    auto image = CGBitmapContextCreateImage(context);
    native_layer_document_bitmap = nullptr;
    native_layer_document_bitmap_claimed = NO;
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(context);
    assert(image);
    auto bytes = CGDataProviderCopyData(CGImageGetDataProvider(image));
    assert(bytes);
    std::vector<uint8_t> result(CFDataGetBytePtr(bytes), CFDataGetBytePtr(bytes) + CFDataGetLength(bytes));
    CFRelease(bytes); CGImageRelease(image);
    assert(native_layer_document_bitmap == nullptr && !native_layer_document_bitmap_claimed);
    return result;
}

static void compare(NSView *view)
{
    fused = false; auto expected = render(view);
    fused = true; auto actual = render(view);
    assert(expected == actual);
    ++comparisons;
}

int main()
{
    @autoreleasepool {
        // Row tails on both vector boundaries, padded rows, all alpha states,
        // fractional backing densities, and immutable snapshots of both sides.
        for (int width : {1, 3, 4, 5, 15, 16, 17, 31, 32, 33, 67}) for (int height : {19, 20})
        for (CGFloat density : {1., 1.25, 2.}) for (int a : {0, -1, 255})
        for (int pad : {0, 16}) for (bool snapshot : {false, true}) {
            scale = density; alpha = a; padding = pad; snapshots = snapshot;
            color_name = kCGColorSpaceSRGB; source_kind = placement = 0;
            accepted = width * scale == ceil(width * scale) && height * scale == ceil(height * scale);
            auto view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
            compare(view);
            [view release];
        }
        for (auto space : {kCGColorSpaceSRGB, kCGColorSpaceDisplayP3, kCGColorSpaceGenericRGBLinear})
        for (int kind : {0, 1, 2}) for (int mode = 0; mode < 6; ++mode) {
            // The frame allocator is sRGB; non-sRGB sources and other formats
            // must retain Quartz's color and placement handling.
            color_name = space; source_kind = kind; placement = mode;
            scale = 2; alpha = -1; padding = 16; snapshots = true;
            accepted = space == kCGColorSpaceSRGB && kind == 0 && mode == 0;
            auto view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 67, 43)];
            compare(view);
            [view release];
        }
        // A foreign context cannot receive direct publication outside a frame.
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto foreign = CGBitmapContextCreate(nullptr, 4, 4, 8, 16, color,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        auto source = CGBitmapContextCreate(nullptr, 4, 4, 8, 16, color,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(color);
        assert(foreign && source);
        assert(!native_layer_copy_document_bitmap(foreign, foreign, 4, 4));
        assert(!native_layer_copy_document_bitmap(source, foreign, 4, 4));
        CGContextRelease(source); CGContextRelease(foreign);
        std::printf("Fused document publication: %d exact comparisons, %d guarded fallbacks, immutable snapshots and later painting passed\n", comparisons, rejections);
    }
}
