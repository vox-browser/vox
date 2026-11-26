#import <Cocoa/Cocoa.h>
#include <stdint.h>

extern void native_begin_font_compositing_layer(float, float);
extern void native_end_font_compositing_layer(void);
extern void native_set_chromium_opaque_layer_continuation(int);
extern void native_begin_css_effect_layer(float, int);
extern void native_end_css_effect_layer(void);

// Exercise the real native scope boundary, including its bitmap ownership.
static int vox_test_opaque_continuation(void) { @autoreleasepool {
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef destination = CGBitmapContextCreate(NULL, 16, 16, 8, 64, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    if (!destination) return -1;
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext
        graphicsContextWithCGContext:destination flipped:NO]];
    native_begin_font_compositing_layer(16,16);
    CGContextRef parent = NSGraphicsContext.currentContext.CGContext;
    int error = 0, scopes = 0;
    uint8_t *bytes = NULL;
    NSGraphicsContext *current = nil;
#define REQUIRE(condition) do { if (!(condition)) { error = __LINE__; goto done; } } while (0)
    CGContextSetRGBFillColor(parent,1,1,1,1);
    CGContextFillRect(parent,CGRectMake(0,0,16,16));
    CGContextFlush(parent);

    native_set_chromium_opaque_layer_continuation(1);
    native_begin_css_effect_layer(1,0); ++scopes;
    REQUIRE(NSGraphicsContext.currentContext.CGContext == parent);
    bytes = CGBitmapContextGetData(parent);
    REQUIRE(bytes && bytes[3] == 255 && bytes[0] == 255);
    CGContextClipToRect(parent,CGRectMake(0,0,8,16));
    CGContextSetRGBFillColor(parent,1,0,0,1);
    CGContextFillRect(parent,CGRectMake(0,0,16,16));
    CGContextFlush(parent);
    REQUIRE(bytes[1] == 0 && bytes[12*4+1] == 255);
    native_end_css_effect_layer(); --scopes;
    REQUIRE(CGRectEqualToRect(CGContextGetClipBoundingBox(parent),CGRectMake(0,0,16,16)));

    // The request is consumed once; ordinary and non-identity effects still
    // begin with a separate transparent bitmap and restore the parent.
    for (int variant=0; variant<4; ++variant) {
        native_set_chromium_opaque_layer_continuation(variant != 0);
        if (variant==3) native_set_chromium_opaque_layer_continuation(0);
        native_begin_css_effect_layer(variant==1 ? .5f : 1.0f,variant==2 ? 3 : 0); ++scopes;
        CGContextRef child=NSGraphicsContext.currentContext.CGContext;
        REQUIRE(child != parent);
        uint8_t *child_bytes=CGBitmapContextGetData(child);
        REQUIRE(child_bytes && child_bytes[3] == 0);
        native_end_css_effect_layer(); --scopes;
        REQUIRE(NSGraphicsContext.currentContext.CGContext == parent);
    }
    // A failed begin must not leak its one-shot request to a later scope.
    current=NSGraphicsContext.currentContext;
    [NSGraphicsContext setCurrentContext:nil];
    native_set_chromium_opaque_layer_continuation(1);
    native_begin_css_effect_layer(1,0);
    [NSGraphicsContext setCurrentContext:current];
    native_begin_css_effect_layer(1,0); ++scopes;
    REQUIRE(NSGraphicsContext.currentContext.CGContext != parent);
    native_end_css_effect_layer(); --scopes;

done:
    while (scopes-- > 0) native_end_css_effect_layer();
    native_set_chromium_opaque_layer_continuation(0);
    native_end_font_compositing_layer();
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(destination);
#undef REQUIRE
    return error;
} }
