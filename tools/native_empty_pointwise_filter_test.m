#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include "native/include/native_layer_presentation_darwin.h"
#include "native/include/native_bitmap_snapshot_darwin.h"
typedef struct { uint8_t r, g, b, a; } gg__Color;
typedef struct { int unused; } gg__Image;
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
static CGFloat test_scale = 1;
static CGFloat native_svg_mask_backing_scale(void) { return test_scale; }
#define VOX_TEST_EMPTY_POINTWISE_FILTERS
#include "native_document_canvas_entry_points.inc"

static unsigned submissions;
static IMP original_create_image;
static CGImageRef count_image(id self, SEL selector, CIImage *image, CGRect rect,
    CIFormat format, CGColorSpaceRef color) {
    ++submissions;
    return ((CGImageRef (*)(id, SEL, CIImage *, CGRect, CIFormat, CGColorSpaceRef))original_create_image)(
        self, selector, image, rect, format, color);
}

static int clipped, content, operation;
static void paint(id view, SEL selector, NSRect rect) {
    CGContextRef frame = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(frame, .12, .4, .7, 1);
    CGContextFillRect(frame, rect);
    if (clipped) CGContextClipToRect(frame, CGRectMake(31.25, 20.5, 81.5, 65.25));
    native_begin_css_filter_layer(159, 127);
    CGContextRef input = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(input, .9, .2, .4, 1.0 / 255);
    if (content == 1) CGContextFillRect(input, CGRectMake(53, 43, 11, 13));
    if (content == 2) CGContextFillRect(input, CGRectMake(2, 2, 7, 7));
    // Outside the clip but inside its conservative two-device-pixel guard.
    if (content == 3) {
        CGContextSetRGBFillColor(input, .9, .2, .4, 1);
        CGContextFillRect(input, CGRectMake(31.25 - 1.0 / test_scale, 43, 1.0 / test_scale, 1));
    }
    native_add_css_filter_operation(operation == 7 ? 3 : operation == 8 ? 0 : 2,
        operation == 7 ? 73 : .65, operation, 0, (gg__Color){0});
    native_end_css_filter_layer();
    assert(NSGraphicsContext.currentContext.CGContext == frame);
    assert(native_css_filter_stack_depth == 0);
}

static NSData *packed(CGImageRef image) {
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    assert(data);
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    NSMutableData *output = [NSMutableData dataWithLength:width * height * 4];
    for (size_t y = 0; y < height; ++y)
        memcpy((uint8_t *)output.mutableBytes + y * width * 4,
            CFDataGetBytePtr(data) + y * CGImageGetBytesPerRow(image), width * 4);
    CFRelease(data);
    return output;
}

static void test_guards(void) {
    setenv("VOX_SKIP_EMPTY_POINTWISE_FILTERS", "1", 1);
    for (int bgra = 0; bgra < 2; ++bgra) {
        CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
        CGContextRef context = CGBitmapContextCreate(NULL, 79, 61, 8, 79 * 4 + 20,
            color, bgra ? kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little
            : kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(color); assert(context);
        NativeCSSFilterOperation op = {.kind = 2, .first = .5, .second = 2};
        NativeCSSFilterLayer layer = {.active = 1, .context = context,
            .destination = context, .canvas_width = 79, .canvas_height = 61,
            .scale = 1, .operations = &op, .operation_count = 1};
        assert(native_css_filter_visible_input_is_empty(&layer));
        uint8_t *pixels = CGBitmapContextGetData(context);
        pixels[3] = 1; assert(!native_css_filter_visible_input_is_empty(&layer));
        pixels[3] = 0;
        pixels[(60 * (79 * 4 + 20)) + 78 * 4 + 3] = 1;
        assert(!native_css_filter_visible_input_is_empty(&layer));
        pixels[(60 * (79 * 4 + 20)) + 78 * 4 + 3] = 0;
        op.kind = 0; assert(!native_css_filter_visible_input_is_empty(&layer)); op.kind = 2;
        op.first = NAN; assert(!native_css_filter_visible_input_is_empty(&layer)); op.first = .5;
        layer.graph_node_count = 1; assert(!native_css_filter_visible_input_is_empty(&layer));
        layer.graph_node_count = 0; layer.borrows_fresh_frame = 1;
        assert(!native_css_filter_visible_input_is_empty(&layer)); layer.borrows_fresh_frame = 0;
        layer.copies_to_fresh_frame = 1;
        assert(!native_css_filter_visible_input_is_empty(&layer)); layer.copies_to_fresh_frame = 0;
        layer.svg_filter_recording = 1;
        assert(!native_css_filter_visible_input_is_empty(&layer)); layer.svg_filter_recording = 0;
        CGContextTranslateCTM(context, .25, 0);
        assert(!native_css_filter_visible_input_is_empty(&layer));
        CGContextRelease(context);
    }
}

int main(void) { @autoreleasepool {
    test_guards();
    assert(!native_css_filter_ci_context && !native_css_filter_color_space);
    NSGraphicsContext *previous = NSGraphicsContext.currentContext;
    setenv("VOX_DISABLE_EARLY_CSS_FILTER_CONTEXT", "1", 1);
    native_prepare_css_filter_renderer();
    assert(!native_css_filter_ci_context && !native_css_filter_color_space);
    unsetenv("VOX_DISABLE_EARLY_CSS_FILTER_CONTEXT");
    native_prepare_css_filter_renderer();
    assert(native_css_filter_ci_context && native_css_filter_color_space);
    CIContext *renderer = native_css_filter_ci_context;
    CGColorSpaceRef color = native_css_filter_color_space;
    native_prepare_css_filter_renderer();
    native_initialize_css_filter_renderer();
    assert(renderer == native_css_filter_ci_context && color == native_css_filter_color_space);
    assert(NSGraphicsContext.currentContext == previous && native_css_filter_stack_depth == 0);
    Method method = class_getInstanceMethod(object_getClass(native_css_filter_ci_context),
        @selector(createCGImage:fromRect:format:colorSpace:));
    original_create_image = method_setImplementation(method, (IMP)count_image);
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 159, 127)];
    unsigned cases = 0, avoided = 0;
    for (int scale = 1; scale <= 2; ++scale)
    for (clipped = 0; clipped <= 1; ++clipped)
    for (content = 0; content < 4; ++content)
    for (operation = 0; operation < 9; ++operation) {
        @autoreleasepool {
            test_scale = scale;
            unsetenv("VOX_SKIP_EMPTY_POINTWISE_FILTERS");
            CGImageRef reference = native_layer_raster_frame(view, scale, (IMP)paint);
            assert(reference);
            unsigned before = native_test_empty_pointwise_filters, calls = submissions;
            setenv("VOX_SKIP_EMPTY_POINTWISE_FILTERS", "1", 1);
            CGImageRef actual = native_layer_raster_frame(view, scale, (IMP)paint);
            assert(actual && [packed(reference) isEqualToData:packed(actual)]);
            int expect_skip = operation != 8 && (!content || (content == 2 && clipped));
            if ((native_test_empty_pointwise_filters > before) != expect_skip)
                fprintf(stderr, "Empty filter admission scale=%d clipped=%d content=%d operation=%d actual=%d expected=%d\n",
                    scale, clipped, content, operation, native_test_empty_pointwise_filters > before, expect_skip);
            assert((native_test_empty_pointwise_filters > before) == expect_skip);
            assert(submissions - calls == (unsigned)!expect_skip);
            avoided += expect_skip;
            CGImageRelease(actual); CGImageRelease(reference);
            ++cases;
            if (cases % 8 == 0) [native_css_filter_ci_context clearCaches];
        }
    }
    method_setImplementation(method, original_create_image);
    printf("Empty pointwise filters: %u exact frames, %u avoided CI submissions; alpha-one edges, padding, BGRA, fractional clips, 1x/2x and non-pointwise fallback\n", cases, avoided);
} }
