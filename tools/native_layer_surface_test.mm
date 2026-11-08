// Exercise the real frame allocator and Core Animation's IOSurface renderer.
#import <Metal/Metal.h>
#include "../native/include/native_layer_presentation_darwin.h"
#include "../native/include/native_presented_capture_darwin.h"
#include "native_test_presented_frame.h"
#include <cassert>
#include <cstdio>
#include <vector>

@interface MyView2 : NSView { BOOL dirty; }
@end
@implementation MyView2
- (BOOL)needsDisplay { return dirty; }
- (void)setNeedsDisplay:(BOOL)value { dirty = value; }
@end

static int frame_value = 70;
static CGImageRef selected;
static void partial_paint(id self, SEL command, NSRect rect)
{
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    auto* pixels = static_cast<uint8_t const*>(CGBitmapContextGetData(context));
    size_t pitch = CGBitmapContextGetBytesPerRow(context);
    for (size_t y = 0; y < CGBitmapContextGetHeight(context); ++y)
        for (size_t x = 0; x < CGBitmapContextGetWidth(context) * 4; ++x)
            assert(pixels[y * pitch + x] == 0);
    CGContextSetRGBFillColor(context, 1, 0, 0, .5);
    CGContextFillRect(context, CGRectMake(4, 4, 8, 8));
}
static void paint(id self, SEL command, NSRect rect)
{
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    vox_browser_frame_prepared();
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, rect);
    CGContextSetRGBFillColor(context, frame_value / 255.0, .25, .8, 1);
    CGContextFillRect(context, CGRectMake(0, 0, rect.size.width / 2, rect.size.height));
    CGContextSetRGBFillColor(context, .8, .6, .1, .5);
    CGContextFillEllipseInRect(context, CGRectInset(rect, 2.25, 3.5));
    vox_browser_frame_completed();
}
static void select_frame(id self, SEL command, NSRect rect)
{
    assert(vox_frame_snapshot_select(NSGraphicsContext.currentContext.CGContext, selected));
    vox_browser_frame_completed();
}
static NSData* bytes(CGImageRef image)
{
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    assert(data);
    NSData* result = [NSData dataWithBytes:CFDataGetBytePtr(data) length:CFDataGetLength(data)];
    CFRelease(data);
    return result;
}
static std::vector<uint8_t> render(id contents, int width, int height)
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        assert(device);
        auto* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
            width:width height:height mipmapped:NO];
        descriptor.storageMode = MTLStorageModeShared;
        descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
        id<MTLCommandQueue> queue = [device newCommandQueue];
        assert(texture && queue);
        CALayer* root = [CALayer layer];
        root.frame = CGRectMake(0, 0, width, height);
        CALayer* child = [CALayer layer];
        child.frame = root.bounds;
        child.contents = contents;
        child.opaque = YES;
        [root addSublayer:child];
        CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CARenderer* renderer = [CARenderer rendererWithMTLTexture:texture options:@{
            kCARendererColorSpace: (__bridge id)color, kCARendererMetalCommandQueue: queue }];
        renderer.layer = root;
        renderer.bounds = root.bounds;
        [CATransaction flush];
        [renderer beginFrameAtTime:CACurrentMediaTime() timeStamp:nullptr];
        [renderer addUpdateRect:root.bounds];
        [renderer render];
        [renderer endFrame];
        id<MTLCommandBuffer> completed = [queue commandBuffer];
        [completed commit];
        [completed waitUntilCompleted];
        std::vector<uint8_t> pixels(size_t(width) * height * 4);
        [texture getBytes:pixels.data() bytesPerRow:width * 4
            fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];
        CGColorSpaceRelease(color);
        return pixels;
    }
}
int main()
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        unsetenv("VOX_DISABLE_IOSURFACE_FRAMES");
        native_set_opaque_browser_frames(1);
        MyView2* view = [[MyView2 alloc] initWithFrame:NSMakeRect(0, 0, 65, 49)];
        view.wantsLayer = YES;
        native_set_opaque_browser_frames(0);
        native_layer_present_frame(view, 1, (IMP)partial_paint);
        NSData* partial = bytes(native_layer_frame_image(view));
        assert(((uint8_t const*)partial.bytes)[3] == 0);
        auto partial_reference = render((__bridge id)native_layer_frame_image(view), 65, 49);
        auto partial_surface = render(view.layer.contents, 65, 49);
        assert(partial_reference == partial_surface);
        native_set_opaque_browser_frames(1);
        // Exercise exhaustion with the historical three-slot pool; the default
        // grows on demand (checked after this loop).
        setenv("VOX_SHARED_FRAME_BUFFERS", "3", 1);
        for (int scale : {1, 2}) {
            native_layer_present_frame(view, scale, (IMP)paint);
            CGImageRef first = CGImageRetain(native_layer_frame_image(view));
            assert(first && native_layer_frame_matches_input(view, scale));
            IOSurfaceRef surface = native_layer_surface_for_image(first);
            assert(surface && (__bridge id)surface == view.layer.contents);
            assert(CGImageGetBytesPerRow(first) == IOSurfaceGetBytesPerRow(surface));
            assert(CGSizeEqualToSize(native_test_presented_size(view.layer.contents),
                CGSizeMake(65 * scale, 49 * scale)));
            assert([native_test_presented_pixels(view.layer.contents)
                isEqualToData:native_test_presented_pixels((__bridge id)first)]);
            auto reference = render((__bridge id)first, 65 * scale, 49 * scale);
            auto actual = render((__bridge id)surface, 65 * scale, 49 * scale);
            size_t nonzero = 0;
            for (auto value : actual) nonzero += value != 0;
            assert(nonzero > actual.size() / 2 && actual == reference);
            NSData* original = bytes(first);
            view.needsDisplay = NO; // Acknowledge this offscreen display pass.
            NSBitmapImageRep* capture = native_presented_capture_bitmap(view, view.bounds,
                65 * scale, 49 * scale);
            NativePresentedPixels captured;
            assert(capture && native_presented_pixels_for(capture, &captured));
            size_t first_pitch = CGImageGetBytesPerRow(first);
            for (size_t y = 0; y < captured.height; ++y)
                assert(!memcmp(captured.pixels + y * captured.pitch,
                    (uint8_t const*)original.bytes + y * first_pitch, captured.width * 4));
            ++frame_value;
            native_layer_present_frame(view, scale, (IMP)paint);
            CGImageRef second = CGImageRetain(native_layer_frame_image(view));
            assert(native_layer_surface_for_image(second) != surface);
            ++frame_value;
            native_layer_present_frame(view, scale, (IMP)paint);
            CGImageRef third = CGImageRetain(native_layer_frame_image(view));
            ++frame_value;
            native_layer_present_frame(view, scale, (IMP)paint);
            CGImageRef fourth = nullptr;
            if (getenv("VOX_EXTRA_FRAME_BUFFER")) {
                fourth = CGImageRetain(native_layer_frame_image(view));
                assert(native_layer_surface_for_image(fourth));
                ++frame_value;
                native_layer_present_frame(view, scale, (IMP)paint);
            }
            assert(!native_layer_surface_for_image(native_layer_frame_image(view)));
            assert(CFGetTypeID((__bridge CFTypeRef)view.layer.contents) == CGImageGetTypeID());
            assert([bytes(first) isEqualToData:original]);
            CGImageRelease(second);
            CGImageRelease(third);
            if (fourth) CGImageRelease(fourth);
            selected = first;
            native_layer_present_frame(view, scale, (IMP)select_frame);
            assert(native_layer_frame_image(view) == first && view.layer.contents == (__bridge id)surface);
            assert([bytes(first) isEqualToData:original]);
            selected = nullptr;
            // The window server can retain a surface after its CGImage has
            // gone away. A use count must protect those bytes independently.
            bool checked_server_hold = false;
            for (auto& buffer : native_layer_frame_buffers) {
                if (!buffer.surface || __atomic_load_n(&buffer.busy, __ATOMIC_ACQUIRE)) continue;
                IOSurfaceIncrementUseCount(buffer.surface);
                NSData* held = [NSData dataWithBytes:buffer.pixels length:buffer.bytes];
                for (int i = 0; i < 6; ++i) {
                    ++frame_value;
                    native_layer_present_frame(view, scale, (IMP)paint);
                    assert([held isEqualToData:[NSData dataWithBytes:buffer.pixels length:buffer.bytes]]);
                }
                IOSurfaceDecrementUseCount(buffer.surface);
                checked_server_hold = true;
                break;
            }
            assert(checked_server_hold);
            CGImageRelease(first);
            // Do not retain the selected snapshot across a size/scale change.
            objc_setAssociatedObject(view, &native_layer_frame_image_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            view.layer.contents = nil;
            for (size_t y = 0; y < captured.height; ++y)
                assert(!memcmp(captured.pixels + y * captured.pitch,
                    (uint8_t const*)original.bytes + y * first_pitch, captured.width * 4));
        }
        // By default the shared pool maps another surface while three
        // published frames are still held, as at 120 Hz.
        unsetenv("VOX_SHARED_FRAME_BUFFERS");
        CGImageRef held[3];
        for (auto& image : held) {
            ++frame_value;
            native_layer_present_frame(view, 2, (IMP)paint);
            image = CGImageRetain(native_layer_frame_image(view));
            assert(native_layer_surface_for_image(image));
        }
        ++frame_value;
        native_layer_present_frame(view, 2, (IMP)paint);
        assert(native_layer_surface_for_image(native_layer_frame_image(view)));
        assert(CFGetTypeID((__bridge CFTypeRef)view.layer.contents) == IOSurfaceGetTypeID());
        for (auto image : held) CGImageRelease(image);
        objc_setAssociatedObject(view, &native_layer_frame_image_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        view.layer.contents = nil;
        [view setFrameSize:NSMakeSize(80, 40)];
        native_layer_present_frame(view, 2, (IMP)paint);
        CGImageRef resized = native_layer_frame_image(view);
        assert(resized && CGImageGetWidth(resized) == 160 && CGImageGetHeight(resized) == 80);
        assert(native_layer_frame_matches_input(view, 2));
        // Unrelated layer contents cannot reuse the associated snapshot.
        view.layer.contents = [CALayer layer];
        assert(!native_layer_frame_image(view) && !native_layer_frame_matches_input(view, 2));
        setenv("VOX_DISABLE_IOSURFACE_FRAMES", "1", 1);
        native_layer_present_frame(view, 2, (IMP)paint);
        assert(!native_layer_surface_for_image(native_layer_frame_image(view)));
        assert(native_layer_frame_matches_input(view, 2));
        std::puts("IOSurface and CGImage Core Animation pixels match; images, fallback, snapshots and resizing remain valid");
    }
}
