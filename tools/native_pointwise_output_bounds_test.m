#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include "native_layer_presentation_darwin.h"
#include "native_bitmap_snapshot_darwin.h"
typedef struct { uint8_t r,g,b,a; } gg__Color;
typedef struct { int unused; } gg__Image;
static CGContextRef native_font_compositing_context;
static int native_font_compositing_transparency_depth;
static CGFloat test_scale;
static CGFloat native_svg_mask_backing_scale(void) { return test_scale; }
#include "native_document_canvas_entry_points.inc"

static int clipped, fractional, operation, content, placement, admitted;
static void paint(id view, SEL selector, NSRect rect) {
    CGContextRef frame = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(frame, .17, .43, .71, 1);
    CGContextFillRect(frame, rect);
    if (clipped) CGContextClipToRect(frame, CGRectMake(49.5, 79.25, 73.5, 51.25));
    if (fractional) CGContextTranslateCTM(frame, .25, 0);
    native_begin_css_filter_layer(211, 173);
    CGContextRef input = NSGraphicsContext.currentContext.CGContext;
    CGRect ink = CGRectMake(43.25, 91.75 + placement * 80, 57.5, 37.5);
    CGContextSetRGBFillColor(input, .8, .3, .1, content == 3 ? 1.0 / 255 : .65);
    if (content == 1 || content == 3) CGContextFillRect(input, ink);
    if (content == 2) CGContextFillEllipseInRect(input, ink);
    if (operation == 7) native_add_css_filter_operation(3, 73, 0, 0, (gg__Color){0});
    else if (operation == 8) native_add_css_filter_operation(0, 2, 0, 0, (gg__Color){0});
    else native_add_css_filter_operation(2, .65, operation, 0, (gg__Color){0});
    native_bound_pointwise_filter_output(ink.origin.x, 173 - CGRectGetMaxY(ink),
        ink.size.width, ink.size.height);
    admitted = native_css_filter_stack[native_css_filter_stack_depth - 1].has_pointwise_output_bounds;
    native_end_css_filter_layer();
    assert(NSGraphicsContext.currentContext.CGContext == frame && !native_css_filter_stack_depth);
}

static NSData *packed(CGImageRef image) {
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image)); assert(data);
    size_t width=CGImageGetWidth(image), height=CGImageGetHeight(image);
    NSMutableData *result=[NSMutableData dataWithLength:width*height*4];
    for (size_t y=0; y<height; ++y) memcpy((uint8_t *)result.mutableBytes+y*width*4,
        CFDataGetBytePtr(data)+y*CGImageGetBytesPerRow(image), width*4);
    CFRelease(data); return result;
}

static void check_guards(void) {
    setenv("VOX_BOUND_POINTWISE_FILTER_OUTPUTS", "1", 1);
    native_bound_pointwise_filter_output(0, 0, 10, 10); // No active layer.
    native_begin_css_filter_layer(211, 173);
    native_add_css_filter_operation(2, .65, 2, 0, (gg__Color){0});
    NativeCSSFilterLayer *layer=&native_css_filter_stack[native_css_filter_stack_depth-1];
    // No destination makes integer device correspondence unprovable.
    native_bound_pointwise_filter_output(0, 0, 10, 10);
    assert(!layer->has_pointwise_output_bounds);
    native_end_css_filter_layer();
}

int main(void) { @autoreleasepool {
    test_scale=1; check_guards();
    NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,211,173)];
    unsigned cases=0, bounded=0;
    for (int scale=1; scale<=2; ++scale) for (clipped=0; clipped<2; ++clipped)
    for (fractional=0; fractional<2; ++fractional) for (placement=-2; placement<=2; ++placement)
    for (content=0; content<4; ++content) for (operation=0; operation<9; ++operation) {
        @autoreleasepool {
            test_scale=scale;
            unsetenv("VOX_BOUND_POINTWISE_FILTER_OUTPUTS");
            CGImageRef reference=native_layer_raster_frame(view,scale,(IMP)paint); assert(reference && !admitted);
            setenv("VOX_BOUND_POINTWISE_FILTER_OUTPUTS","1",1);
            CGImageRef candidate=native_layer_raster_frame(view,scale,(IMP)paint); assert(candidate);
            assert(admitted == (!fractional && operation != 8)); bounded += admitted;
            assert([packed(candidate) isEqualToData:packed(reference)]);
            CGImageRelease(reference); CGImageRelease(candidate); ++cases;
            if (cases%32==0) [native_css_filter_ci_context clearCaches];
        }
    }
    assert(bounded);
    printf("Bounded pointwise outputs: %u exact frames, %u admitted; alpha-one edges, fractional clips, placement, 1x/2x, blur and non-integral mapping fallback\n",cases,bounded);
} }
