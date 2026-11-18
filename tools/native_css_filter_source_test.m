#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include <mach/mach.h>
#include "native/include/native_layer_presentation_darwin.h"
#include "native/include/native_bitmap_snapshot_darwin.h"
typedef struct { uint8_t r, g, b, a; } gg__Color;
typedef struct { int unused; } gg__Image;
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
static CGFloat native_svg_mask_backing_scale(void) { return 2; }
#include "native_document_canvas_entry_points.inc"

static NSData *render_pixels(CIImage *input, CGRect bounds) {
    CIImage *blurred = native_apply_css_blur(input, 1.25);
    CGImageRef image = [native_css_filter_ci_context createCGImage:blurred
        fromRect:bounds format:kCIFormatRGBA8 colorSpace:native_css_filter_color_space];
    assert(image);
    CFDataRef bytes = CGDataProviderCopyData(CGImageGetDataProvider(image));
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    size_t pitch = CGImageGetBytesPerRow(image);
    NSMutableData *packed = [NSMutableData dataWithLength:width * height * 4];
    for (size_t y = 0; y < height; ++y)
        memcpy((uint8_t *)packed.mutableBytes + y * width * 4,
            CFDataGetBytePtr(bytes) + y * pitch, width * 4);
    CFRelease(bytes);
    CGImageRelease(image);
    return packed;
}

static void check_formats_and_ownership(void) {
    int comparisons = 0;
    for (int format = 0; format < 5; ++format) for (int wide = 0; wide < 2; ++wide) {
        CIImage *candidate;
        NSData *expected;
        CGRect bounds = CGRectMake(0, 0, 63 + wide, 49);
        @autoreleasepool {
            size_t width = bounds.size.width, height = bounds.size.height;
            size_t pitch = width * 4 + 16;
            NSMutableData *pixels = [NSMutableData dataWithLength:height * pitch];
            for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < width; ++x) {
                uint8_t *p = (uint8_t *)pixels.mutableBytes + y * pitch + x * 4;
                uint8_t alpha = (x * 13 + y * 19) % 256;
                p[0] = (x * 3 + y * 7) % (alpha + 1);
                p[1] = (x * 11 + y * 5) % (alpha + 1);
                p[2] = (x * 17 + y * 3) % (alpha + 1);
                p[3] = alpha;
                if (format == 1) { uint8_t r = p[0]; p[0] = p[2]; p[2] = r; }
            }
            CGColorSpaceRef color = CGColorSpaceCreateWithName(wide ? kCGColorSpaceDisplayP3 : kCGColorSpaceSRGB);
            CGBitmapInfo info = format == 1
                ? kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
                : (format == 2 ? kCGImageAlphaLast : format == 4 ? kCGImageAlphaNoneSkipLast
                    : kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big;
            CGFloat decode[] = {1, 0, 0, 1, 0, 1};
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
            CGImageRef image = CGImageCreate(width, height, 8, 32, pitch, color, info,
                provider, format == 3 ? decode : NULL, false, kCGRenderingIntentDefault);
            assert(image);
            expected = render_pixels([CIImage imageWithCGImage:image], bounds);
            candidate = native_css_filter_source_image(image);
            CGImageRelease(image);
            CGDataProviderRelease(provider);
            CGColorSpaceRelease(color);
        }
        // Only the new CIImage and expected output survive the source owners.
        @autoreleasepool {
            NSMutableData *churn = [NSMutableData dataWithLength:4 * 1024 * 1024];
            memset(churn.mutableBytes, 0xa7, churn.length);
            assert([expected isEqualToData:render_pixels(candidate, bounds)]);
        }
        ++comparisons;
    }
    [native_css_filter_ci_context clearCaches];
    fprintf(stderr, "PASS %d exact padded RGBA/BGRA, opaque, straight-alpha, decode-array and source-lifetime comparisons\n", comparisons);
}

static void check_backdrop_snapshot_ownership(void) {
    const size_t width = 64, height = 40, pitch = width * 4 + 32;
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, pitch, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    assert(context);
    CGContextSetRGBFillColor(context, 0.8, 0.31, 0.15, 0.76);
    CGContextFillEllipseInRect(context, CGRectMake(3, 2, 55, 31));
    CGImageRef reference = CGBitmapContextCreateImage(context);
    assert(reference);
    CGRect area = CGRectMake(0, 0, width, height);
    NSData *expected = render_pixels(native_css_filter_source_image(reference), area);
    CGImageRelease(reference);

    NativeCSSBackdropBitmap bitmap = native_copy_css_backdrop_bitmap(context);
    assert(bitmap.bytes && bitmap.width == width && bitmap.height == height && bitmap.pitch == pitch);
    CGContextClearRect(context, area);
    CGContextRelease(context);
    CGColorSpaceRelease(color);

    CIImage *input = [CIImage imageWithBitmapData:(__bridge NSData *)bitmap.bytes
        bytesPerRow:bitmap.pitch size:area.size format:bitmap.format colorSpace:bitmap.color_space];
    CFRelease(bitmap.bytes);
    CGColorSpaceRelease(bitmap.color_space);
    assert([expected isEqualToData:render_pixels(input, area)]);
}

static void check_svg_turbulence(void) {
    const size_t width = 317;
    const int32_t height = 257;
    const size_t bytes = width * height * 4;
    NSMutableData *serial = [NSMutableData dataWithLength:bytes];
    NSMutableData *parallel = [NSMutableData dataWithLength:bytes];
    int original_rounding = fegetround();

    for (int mode = 0; mode <= 1; ++mode) {
        assert(fesetround(mode == 0 ? FE_TONEAREST : FE_DOWNWARD) == 0);
        NativeSVGFilterNode node = {.first = .018, .second = .037, .third = 3,
            .fourth = -17, .mode = mode};
        setenv("VOX_SERIAL_CPU_RASTER", "1", 1);
        native_svg_render_turbulence_pixels(serial.mutableBytes, width, height,
            node.first, node.second, node.third, node.fourth, mode, 1.25);
        unsetenv("VOX_SERIAL_CPU_RASTER");
        memset(parallel.mutableBytes, 0xff, bytes);
        native_svg_render_turbulence_pixels(parallel.mutableBytes, width, height,
            node.first, node.second, node.third, node.fourth, mode, 1.25);
        assert([parallel isEqualToData:serial]);
        assert(fegetround() == (mode == 0 ? FE_TONEAREST : FE_DOWNWARD));
        assert(fesetround(original_rounding) == 0);

        CGRect bounds = CGRectMake(-5, 13, width, height);
        setenv("VOX_SERIAL_CPU_RASTER", "1", 1);
        CIImage *before = native_apply_svg_turbulence(bounds, &node, 1.25);
        unsetenv("VOX_SERIAL_CPU_RASTER");
        CIImage *after = native_apply_svg_turbulence(bounds, &node, 1.25);
        assert(before && after && CGRectEqualToRect(before.extent, bounds)
            && CGRectEqualToRect(after.extent, bounds));
        assert([render_pixels(before, bounds) isEqualToData:render_pixels(after, bounds)]);
    }
    fprintf(stderr, "PASS serial and parallel SVG turbulence pixels, rounding, and image extent\n");
}

static void paint_filtered_frame(id view, SEL selector, NSRect rect) {
    (void)view; (void)selector; (void)rect;
    native_begin_font_compositing_layer(1280, 900);
    BOOL independent = getenv("VOX_TEST_INDEPENDENT_FILTER_INPUT") != NULL;
    if (independent) native_begin_css_filter_layer(1280, 900);
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context, .2, .6, .3, .7);
    CGContextFillEllipseInRect(context, CGRectMake(20.25, 10.75, 1200, 850));
    native_begin_svg_filter_graph(0, 1, 0, 0, 1280, 900, 1, 0, 0, 1, 0, 0, 0, 0);
    native_add_svg_filter_node(0, 4, 1.25, .75, 0, 0, 0, 0, (gg__Color){0}, 0, 0, 0);
    if (independent) native_end_css_filter_layer();
    native_end_font_compositing_layer();
}

static uint64_t resident_bytes(void) {
    task_vm_info_data_t info = {0};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS);
    return info.resident_size;
}

int main(void) { @autoreleasepool {
    native_initialize_css_filter_renderer();
    check_formats_and_ownership();
    check_backdrop_snapshot_ownership();
    check_svg_turbulence();
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1280, 900)];
    uint64_t warm = 0, peak = 0;
    for (int frame = 0; frame < 200; ++frame) {
        @autoreleasepool {
            CGImageRef image = native_layer_raster_frame(view, 2, (IMP)paint_filtered_frame);
            assert(image);
            CGImageRelease(image);
        }
        uint64_t bytes = resident_bytes();
        if (bytes > peak) peak = bytes;
        if (frame == 60) warm = bytes;
        if (frame >= 60) assert(bytes <= warm + 64ull * 1024 * 1024);
    }
    assert(peak < 1024ull * 1024 * 1024);
    fprintf(stderr, "PASS 200 filtered Retina frames: warm=%llu peak=%llu final=%llu bytes RSS\n",
        (unsigned long long)warm, (unsigned long long)peak, (unsigned long long)resident_bytes());
    return 0;
} }
