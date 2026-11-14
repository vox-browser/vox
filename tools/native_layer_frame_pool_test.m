// Frames paint into pooled bitmaps. A buffer is reused only after the image
// that owns it is released, starts as transparent as a new allocation, and a
// retained image never changes when later frames paint.
#define VOX_TEST_LAYER_FRAME_BUFFERS
#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include "native/include/native_layer_presentation_darwin.h"

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

@interface PoolSkippedFrameView : MyView2
@property(nonatomic) NSUInteger redraws;
@end
@implementation PoolSkippedFrameView
- (BOOL)needsDisplay { return NO; }
- (void)setNeedsDisplay:(BOOL)value { if (value) ++self.redraws; }
@end

static unsigned prepared_frames, published_frames;
static void count_prepared_frame(void *view, uint64_t token, double started) {
    (void)view; (void)token; (void)started;
    ++prepared_frames;
}
static void count_published_frame(void *view, uint64_t token) {
    (void)view; (void)token;
    ++published_frames;
}

static void pool_test_partial_draw(id self, SEL command, NSRect rect)
{
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectInset(rect, 2, 2));
    pool_test_incomplete_draw(self, command, rect);
}

static void test_skipped_frame_publication(void)
{
    PoolSkippedFrameView *view = [[PoolSkippedFrameView alloc] initWithFrame:NSMakeRect(0, 0, 80, 40)];
    view.wantsLayer = YES;
    native_set_opaque_browser_frames(1);
    native_layer_original_draw = (IMP)pool_test_incomplete_draw;
    [VoxNativeFramePublication observePrepared:count_prepared_frame published:count_published_frame];
    native_layer_update(view, @selector(updateLayer));
    // A skipped initial frame has no pixels to publish or acknowledge.
    assert(!view.layer.contents && !prepared_frames && !published_frames);
    frame_value = 100;
    native_layer_original_draw = (IMP)pool_test_opaque_draw;
    native_layer_update(view, @selector(updateLayer));
    assert(prepared_frames == 1 && published_frames == 1);
    id contents = view.layer.contents;
    CGImageRef image = CGImageRetain(native_layer_frame_image(view));
    NSData *pixels = image_bytes(image);
    NSNumber *generation = objc_getAssociatedObject(view, &native_layer_frame_generation_key);
    NSUInteger redraws = view.redraws;
    native_layer_original_draw = (IMP)pool_test_partial_draw;
    NSView *child = [[MyView2 alloc] initWithFrame:NSMakeRect(0, 0, 80, 40)];
    nested_view = child;
    for (unsigned i = 0; i < 8; ++i) {
        ++native_layer_redraw_generation;
        native_layer_update(view, @selector(updateLayer));
        // A nested completed canvas cannot complete its skipped parent.
        assert(view.layer.contents == contents);
        assert(native_layer_frame_image(view) == image);
        assert([image_bytes(image) isEqualToData:pixels]);
        assert(objc_getAssociatedObject(view, &native_layer_frame_generation_key) == generation);
        assert(prepared_frames == 1 && published_frames == 1);
        assert(!native_layer_presenting && !native_layer_opaque_frame_context);
    }
    nested_view = nil;
    // The throttle's timer owns the next attempt. A stale retained generation
    // must not spin a main-queue redraw loop before that deadline.
    __block BOOL drained = NO;
    dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
    double deadline = CACurrentMediaTime() + 1;
    while (!drained && CACurrentMediaTime() < deadline)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
    assert(drained && view.redraws == redraws);
    frame_value = 200;
    native_layer_original_draw = (IMP)pool_test_opaque_draw;
    native_layer_update(view, @selector(updateLayer));
    assert(prepared_frames == 2 && published_frames == 2);
    assert(![image_bytes(native_layer_frame_image(view)) isEqualToData:pixels]);
    assert([image_bytes(image) isEqualToData:pixels]);
    NSNumber *resumed = objc_getAssociatedObject(view, &native_layer_frame_generation_key);
    assert(resumed.unsignedLongLongValue == native_layer_redraw_generation);
    CGImageRelease(image);
    [VoxNativeFramePublication observePrepared:NULL published:NULL];
    native_layer_original_draw = NULL;
    native_set_opaque_browser_frames(0);
#if !__has_feature(objc_arc)
    [child release];
    [view release];
#endif
    puts("Skipped frames: retained pixels and generation, no publication or redraw loop, resumed paint passed");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc == 2 && !strcmp(argv[1], "--skipped")) {
            test_skipped_frame_publication();
            return 0;
        }
        if(argc==2 && (!strcmp(argv[1],"--spare") || !strcmp(argv[1],"--readiness"))) {
            const char *option=!strcmp(argv[1],"--spare")
                ? "VOX_EXTRA_FRAME_BUFFER" : "VOX_GPU_FRAME_READINESS_QUEUE";
            // Both options raise the historical three-slot pool to four.
            setenv("VOX_SHARED_FRAME_BUFFERS","3",1);
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
        if(argc==2 && !strcmp(argv[1],"--grow")) {
            // Shared frames map further surfaces while earlier ones are held,
            // up to the pool capacity, then fall back to a CGImage.
            MyView2* view=[[MyView2 alloc] initWithFrame:NSMakeRect(0,0,64,48)];
            CGImageRef held[VOX_LAYER_FRAME_BUFFER_CAPACITY];
            for(int index=0;index<VOX_LAYER_FRAME_BUFFER_CAPACITY;++index) {
                held[index]=frame(view,60+index);
                assert(native_layer_surface_for_image(held[index]));
            }
            assert(native_test_frame_buffer_maps==VOX_LAYER_FRAME_BUFFER_CAPACITY);
            CGImageRef exhausted=frame(view,9);
            assert(!native_layer_surface_for_image(exhausted));
            CGImageRelease(exhausted);
            CGImageRelease(held[4]);
            CGImageRef reused=frame(view,10);
            assert(native_layer_surface_for_image(reused));
            assert(native_test_frame_buffer_maps==VOX_LAYER_FRAME_BUFFER_CAPACITY
                && native_test_frame_buffer_reuses==1);
            CGImageRelease(reused);
            // An explicit cap below the held frames keeps the CGImage fallback.
            setenv("VOX_SHARED_FRAME_BUFFERS","3",1);
            CGImageRef capped=frame(view,11);
            assert(!native_layer_surface_for_image(capped));
            CGImageRelease(capped);
            unsetenv("VOX_SHARED_FRAME_BUFFERS");
            for(int index=0;index<VOX_LAYER_FRAME_BUFFER_CAPACITY;++index)
                if(index!=4) CGImageRelease(held[index]);
            puts("Growing IOSurface pool: maps on demand to capacity, bounded fallback, reuse and explicit cap passed");
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
        assert(!incomplete);
        nested_view = [[MyView2 alloc] initWithFrame:NSMakeRect(0, 0, 80, 40)];
        CGImageRef parent = native_layer_raster_frame(opaque_view, 2, (IMP)pool_test_incomplete_draw);
        assert(!parent);
        nested_view = nil;
        // Opt-in affects only browser callbacks; generic partial painting still
        // receives a cleared bitmap and retains its transparent background.
        CGImageRef generic = frame(view, 12);
        CGImageRelease(generic);
        generic = native_layer_raster_frame(view, 2, (IMP)pool_test_incomplete_draw);
        assert_transparent(generic);
        CGImageRelease(generic);
        native_set_opaque_browser_frames(0);
        assert(!native_layer_opaque_frame_context && !native_layer_opaque_frame_complete);
        printf("PASS layer frame buffers: %u maps, %u reuses, cleared starts, immutable images\n",
            native_test_frame_buffer_maps, native_test_frame_buffer_reuses);
    }
}
