// Frames paint into pooled bitmaps. A buffer is reused only after the image
// that owns it is released, starts as transparent as a new allocation, and a
// retained image never changes when later frames paint.
#define VOX_TEST_LAYER_FRAME_BUFFERS
#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include "native_layer_presentation_darwin.h"

// Use the same backend frame contract as the V browser, without a window.
@interface MyView2 : NSView
@end
@implementation MyView2
@end

static int frame_value;
static BOOL frame_started_clear;

static void pool_test_draw(id self, SEL command, NSRect rect)
{
    (void)self; (void)command; (void)rect;
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    uint8_t const* pixels = CGBitmapContextGetData(context);
    frame_started_clear = YES;
    for (size_t y = 0; y < height; ++y)
        for (size_t x = 0; x < width * 4; ++x)
            if (pixels[y * pitch + x]) frame_started_clear = NO;
    CGContextSetRGBFillColor(context, frame_value / 255.0, 0.25, 0.5, 1);
    CGContextFillRect(context, CGRectMake(1, 1, 20, 10));
}

static void pool_test_throw(id self, SEL command, NSRect rect)
{
    pool_test_draw(self, command, rect);
    @throw [NSException exceptionWithName:@"pool" reason:@"draw failed" userInfo:nil];
}

// Copy the pixels out: Quartz's data for a direct provider can reference the
// provider, which keeps the frame's buffer published until it is released.
static NSData* image_bytes(CGImageRef image)
{
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    NSData* bytes = [NSData dataWithBytes:CFDataGetBytePtr(data) length:CFDataGetLength(data)];
    CFRelease(data);
    return bytes;
}

static CGImageRef frame(NSView* view, int value)
{
    frame_value = value;
    CGImageRef image = native_layer_raster_frame(view, 2, (IMP)pool_test_draw);
    assert(image && frame_started_clear);
    return image;
}

static void pool_test_opaque_draw(id self, SEL command, NSRect rect)
{
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, rect);
    CGContextSetRGBFillColor(context, frame_value / 255.0, 0.25, 0.5, 0.5);
    CGContextFillRect(context, CGRectMake(1.25, 1.5, 20.5, 10.25));
    vox_browser_frame_completed();
}

static NSView* nested_view;
static void pool_test_incomplete_draw(id self, SEL command, NSRect rect)
{
    if (nested_view) {
        CGImageRef child = native_layer_raster_frame(nested_view, 2, (IMP)pool_test_opaque_draw);
        assert(child);
        CGImageRelease(child);
    }
    // A completed nested frame must not complete this unpainted callback.
}

static void pool_test_opaque_throw(id self, SEL command, NSRect rect)
{
    pool_test_opaque_draw(self, command, rect);
    @throw [NSException exceptionWithName:@"pool" reason:@"opaque draw failed" userInfo:nil];
}

static void assert_transparent(CGImageRef image)
{
    assert(image);
    NSData* data = image_bytes(image);
    const uint8_t* bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; ++i) assert(bytes[i] == 0);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if(argc==2 && (!strcmp(argv[1],"--spare") || !strcmp(argv[1],"--readiness"))) {
            const char *option=!strcmp(argv[1],"--spare")
                ? "VOX_EXTRA_FRAME_BUFFER" : "VOX_GPU_FRAME_READINESS_QUEUE";
            setenv(option,"1",1);
            MyView2* view=[[MyView2 alloc] initWithFrame:NSMakeRect(0,0,64,48)];
            CGImageRef held[4];
            for(int index=0;index<4;++index) {
                held[index]=frame(view,40+index);
                assert(native_layer_surface_for_image(held[index]));
            }
            assert(native_test_frame_buffer_maps==4);
            NSData* first_pixels=image_bytes(held[0]);
            CGImageRef exhausted=frame(view,5);
            assert(!native_layer_surface_for_image(exhausted));
            assert([image_bytes(held[0]) isEqualToData:first_pixels]);
            CGImageRelease(exhausted);
            CGImageRelease(held[3]);
            // The same process can disable the spare while the first three
            // remain published. Its idle fourth slot must not bypass control.
            unsetenv(option);
            CGImageRef control=frame(view,6);
            assert(!native_layer_surface_for_image(control));CGImageRelease(control);
            setenv(option,"1",1);
            CGImageRef reused=frame(view,7);
            assert(native_layer_surface_for_image(reused));
            assert(native_test_frame_buffer_maps==4 && native_test_frame_buffer_reuses==1);
            assert([image_bytes(held[0]) isEqualToData:first_pixels]);
            CGImageRelease(reused);
            for(int index=0;index<3;++index)CGImageRelease(held[index]);
            puts("Spare IOSurface: four retained frames, bounded fallback, immutable images, explicit three-slot control and cleared reuse passed");
            return 0;
        }
        NSView* view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 64, 48)];
        CGImageRef first = frame(view, 200);
        NSData* first_pixels = image_bytes(first);
        assert(native_test_frame_buffer_maps == 1 && native_test_frame_buffer_reuses == 0);
        // The first frame's image is still published: a second buffer paints.
        CGImageRef second = frame(view, 100);
        assert(native_test_frame_buffer_maps == 2 && native_test_frame_buffer_reuses == 0);
        assert([image_bytes(first) isEqualToData:first_pixels]);
        assert(![image_bytes(second) isEqualToData:first_pixels]);
        // Releasing the first image returns its buffer, cleared before reuse.
        CGImageRelease(first);
        CGImageRef third = frame(view, 50);
        assert(native_test_frame_buffer_maps == 2 && native_test_frame_buffer_reuses == 1);
        NSData* second_pixels = image_bytes(second);
        CGImageRef fourth = frame(view, 25);
        assert(native_test_frame_buffer_maps == 3);
        // Every buffer is published: the frame falls back to a new bitmap.
        CGImageRef fifth = frame(view, 10);
        assert(native_test_frame_buffer_maps == 3 && native_test_frame_buffer_reuses == 1);
        assert([image_bytes(second) isEqualToData:second_pixels]);
        CGImageRelease(second);
        CGImageRelease(third);
        CGImageRelease(fourth);
        CGImageRelease(fifth);
        // A failed frame returns its buffer.
        frame_value = 5;
        @try { native_layer_raster_frame(view, 2, (IMP)pool_test_throw); assert(0); }
        @catch (NSException* exception) { }
        unsigned reuses = native_test_frame_buffer_reuses;
        CGImageRef after_throw = frame(view, 7);
        assert(native_test_frame_buffer_reuses == reuses + 1);
        CGImageRelease(after_throw);
        // A new size remaps a released buffer.
        [view setFrameSize:NSMakeSize(80, 40)];
        CGImageRef resized = frame(view, 9);
        assert(CGImageGetWidth(resized) == 160 && native_test_frame_buffer_maps == 4);
        CGImageRelease(resized);
        NSView* opaque_view = [[MyView2 alloc] initWithFrame:NSMakeRect(0, 0, 80, 40)];
        frame_value = 100;
        CGImageRef expected = native_layer_raster_frame(opaque_view, 2, (IMP)pool_test_opaque_draw);
        NSData* expected_pixels = image_bytes(expected);
        CGImageRelease(expected);
        native_set_opaque_browser_frames(1);
        CGImageRef opaque = native_layer_raster_frame(opaque_view, 2, (IMP)pool_test_opaque_draw);
        assert([image_bytes(opaque) isEqualToData:expected_pixels]);
        frame_value = 200;
        CGImageRef next = native_layer_raster_frame(opaque_view, 2, (IMP)pool_test_opaque_draw);
        assert([image_bytes(opaque) isEqualToData:expected_pixels]);
        CGImageRelease(next);
        CGImageRelease(opaque);
        const char *force_clear = getenv("VOX_CLEAR_OPAQUE_FRAME_BUFFERS");
        assert((native_test_frame_buffer_deferred_clears > 0) == !(force_clear && *force_clear));
        @try { native_layer_raster_frame(opaque_view, 2, (IMP)pool_test_opaque_throw); assert(0); }
        @catch (NSException* exception) { }
        CGImageRef incomplete = native_layer_raster_frame(opaque_view, 2, (IMP)pool_test_incomplete_draw);
        assert_transparent(incomplete);
        CGImageRelease(incomplete);
        nested_view = [[MyView2 alloc] initWithFrame:NSMakeRect(0, 0, 80, 40)];
        CGImageRef parent = native_layer_raster_frame(opaque_view, 2, (IMP)pool_test_incomplete_draw);
        assert_transparent(parent);
        CGImageRelease(parent);
        nested_view = nil;
        // Opt-in affects only browser callbacks; generic partial painting still
        // receives a cleared bitmap and retains its transparent background.
        CGImageRef generic = frame(view, 12);
        CGImageRelease(generic);
        native_set_opaque_browser_frames(0);
        assert(!native_layer_opaque_frame_context && !native_layer_opaque_frame_complete);
        printf("PASS layer frame buffers: %u maps, %u reuses, cleared starts, immutable images\n",
            native_test_frame_buffer_maps, native_test_frame_buffer_reuses);
    }
}
