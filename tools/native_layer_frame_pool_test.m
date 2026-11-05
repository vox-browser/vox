// Frames paint into pooled bitmaps. A buffer is reused only after the image
// that owns it is released, starts as transparent as a new allocation, and a
// retained image never changes when later frames paint.
#define VOX_TEST_LAYER_FRAME_BUFFERS
#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include "native_layer_presentation_darwin.h"

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

int main(void)
{
    @autoreleasepool {
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
        printf("PASS layer frame buffers: %u maps, %u reuses, cleared starts, immutable images\n",
            native_test_frame_buffer_maps, native_test_frame_buffer_reuses);
    }
}
