#import <Cocoa/Cocoa.h>
#include "../native_layer_presentation_darwin.h"
#include <string.h>

static void *video_cull_test_owner;
static void (*video_cull_test_callback)(void *);
static void video_cull_test_paint(id view, SEL selector, NSRect rect) {
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context,.2,.3,.4,1);
    CGContextFillRect(context,rect);
    video_cull_test_callback(video_cull_test_owner);
}

static int native_video_cull_test_frame(void *owner, void (*callback)(void *),
    int scale, uint8_t *pixels, int length) { @autoreleasepool {
    if (!owner || !callback || !pixels || scale<1 || scale>2
        || length!=160*120*scale*scale*4) return 0;
    video_cull_test_owner=owner; video_cull_test_callback=callback;
    NSView *view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,160,120)];
    CGImageRef frame=native_layer_raster_frame(view,scale,(IMP)video_cull_test_paint);
    CFDataRef bytes=frame ? CGDataProviderCopyData(CGImageGetDataProvider(frame)) : NULL;
    int valid=bytes && CGImageGetWidth(frame)==160*scale && CGImageGetHeight(frame)==120*scale;
    if (valid) for (int y=0; y<120*scale; ++y)
        memcpy(pixels+(size_t)y*160*scale*4,
            CFDataGetBytePtr(bytes)+(size_t)y*CGImageGetBytesPerRow(frame),160*scale*4);
    if (bytes) CFRelease(bytes);
    if (frame) CGImageRelease(frame);
#if !__has_feature(objc_arc)
    [view release];
#endif
    video_cull_test_owner=NULL; video_cull_test_callback=NULL;
    return valid;
} }
