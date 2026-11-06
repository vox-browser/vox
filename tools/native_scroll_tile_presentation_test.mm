// Real ring reuse, immutable captures, and Metal Core Animation composition.
#define VOX_TEST_SCROLL_TILES
#import <Metal/Metal.h>
#include "../native_layer_presentation_darwin.h"
#include "../native_scroll_raster_darwin.h"
#include <cassert>
#include <cstdio>
#include <vector>

@interface MyView2 : NSView
@end
@implementation MyView2
@end
static double test_scroll, previous_scroll, test_scale;
static int content_revision, test_damage;
static bool tiled_frame, resident_frame;
static bool fail_export;
static unsigned exports;

static int cpu_present(CGContextRef context, const VoxGraphiteCanvasSurfaceRegion *regions, int count, void **completion) {
    if (fail_export) return 0;
    ++exports;
    CGContextFlush(context);
    auto pixels=(const uint8_t*)CGBitmapContextGetData(context);
    size_t pitch=CGBitmapContextGetBytesPerRow(context);
    std::vector<IOSurfaceRef> initialized;
    for (int i=0; i<count; ++i) {
        auto &r=regions[i]; auto surface=(IOSurfaceRef)r.surface; auto previous=(IOSurfaceRef)r.previous;
        assert(!IOSurfaceLock(surface,0,nullptr));
        auto output=(uint8_t*)IOSurfaceGetBaseAddress(surface);
        size_t output_pitch=IOSurfaceGetBytesPerRow(surface);
        if (std::find(initialized.begin(),initialized.end(),surface)==initialized.end()) {
            if (previous) {
                assert(!IOSurfaceLock(previous,kIOSurfaceLockReadOnly,nullptr));
                for (size_t y=0; y<IOSurfaceGetHeight(surface); ++y)
                    memcpy(output+y*output_pitch,(uint8_t*)IOSurfaceGetBaseAddress(previous)
                        +y*IOSurfaceGetBytesPerRow(previous),IOSurfaceGetWidth(surface)*4);
                IOSurfaceUnlock(previous,kIOSurfaceLockReadOnly,nullptr);
            } else memset(output,0,IOSurfaceGetAllocSize(surface));
            initialized.push_back(surface);
        }
        for (int y=0; y<r.height; ++y) for (int x=0; x<r.width; ++x) {
            bool damaged=!native_scroll_raster.reused;
            for (int n=0; n<native_scroll_repainted_count; ++n) {
                auto rect=native_scroll_repainted[n];
                int cy=r.canvas_y+y-int(native_scroll_raster.top), cx=r.canvas_x+x;
                damaged |= cx>=rect[0] && cx<rect[2] && cy>=rect[1] && cy<rect[3];
            }
            if (damaged) memcpy(output+(r.surface_y+y)*output_pitch+(r.surface_x+x)*4,
                pixels+(r.canvas_y+y)*pitch+(r.canvas_x+x)*4,4);
        }
        IOSurfaceUnlock(surface,0,nullptr);
    }
    *completion=malloc(1); return 1;
}

static int gpu_enabled = 1;
static void document(CGContextRef context, NSRect bounds) {
    double height = bounds.size.height;
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, bounds);
    for (int y = 0; y < 5000; y += 17) {
        CGContextSetRGBFillColor(context, (y % 131) / 131.0, (y % 97) / 97.0, .4, 1);
        CGContextFillRect(context, CGRectMake(0, height - 7 - (y - test_scroll) - 17,
            bounds.size.width, 17));
    }
    // A fixed translucent object changes independently of scroll; its damage
    // includes fractional clip edges and the complete source rectangle.
    CGContextSetRGBFillColor(context, content_revision % 2 ? .8 : .2, .3, .7, .65);
    CGContextFillEllipseInRect(context, CGRectMake(9.25, height - 7 - 120.25 - 91.5, 41.5, 91.5));
}
static void draw(id self, SEL selector, NSRect bounds) {
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    vox_browser_frame_prepared();
    native_scroll_tile_compositor_enabled(gpu_enabled);
    if (tiled_frame) {
        double movement = test_scroll - previous_scroll;
        double first = std::min(118.5, 118.5 - movement);
        double last = std::max(214.5, 214.5 - movement);
        if (resident_frame) { first=floor(first); last=ceil(last); }
        double delta = 0, damage[] = {resident_frame ? 7. : 7.5, first,
            resident_frame ? 47. : 46., last - first};
        double damages[12]; memcpy(damages,damage,sizeof(damage));
        double bar_top=bounds.size.height-7-23.25-73.5;
        double bar_first=floor(std::min(bar_top,bar_top-movement));
        double bar_last=ceil(std::max(bar_top+73.5,bar_top+73.5-movement));
        double bar[]={bounds.size.width-12,bar_first,12,bar_last-bar_first};
        memcpy(damages+4,bar,sizeof(bar));
        native_begin_scroll_raster(7, content_revision, test_scroll, 7,
            bounds.size.width, bounds.size.height - 12, 1, &delta,
            damages, test_damage ? (resident_frame ? 2 : 1) : 0, 1, 1);
    }
    document(context, bounds);
    if (resident_frame) {
        CGContextSetRGBFillColor(context, .1, .2, .3, .5);
        CGContextFillRect(context, CGRectMake(bounds.size.width - 10.5, 23.25, 7.25, 73.5));
    }
    if (tiled_frame) {
        if (resident_frame && native_scroll_raster.gpu_tiled)
            native_scroll_raster_export(cpu_present, free);
        native_end_scroll_raster();
    }
    // V-owned viewport scrollbar and native-host chrome paint after the ring.
    if (!resident_frame) {
        CGContextSetRGBFillColor(context, .1, .2, .3, .5);
        CGContextFillRect(context, CGRectMake(bounds.size.width - 10.5, 23.25, 7.25, 73.5));
    }
    CGContextSetRGBFillColor(context, .7, .2, .3, 1);
    CGContextFillRect(context, CGRectMake(0, bounds.size.height - 7, bounds.size.width, 7));
    CGContextSetRGBFillColor(context, .2, .6, .3, 1);
    CGContextFillRect(context, CGRectMake(0, 0, bounds.size.width, 5));
    vox_browser_frame_completed();
}
static std::vector<uint8_t> packed(CGImageRef image) {
    assert(image);
    auto data = CGDataProviderCopyData(CGImageGetDataProvider(image)); assert(data);
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    std::vector<uint8_t> result(width * height * 4);
    for (size_t y = 0; y < height; ++y)
        memcpy(result.data() + y * width * 4, CFDataGetBytePtr(data)
            + y * CGImageGetBytesPerRow(image), width * 4);
    CFRelease(data); return result;
}
static std::vector<uint8_t> render_layer(CALayer *content, int width, int height)
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
        [root addSublayer:content];
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
int main() { @autoreleasepool {
    [NSApplication sharedApplication];
    setenv("VOX_SCROLL_TILE_COMPOSITOR", "1", 1);

    native_set_opaque_browser_frames(1);
    for (BOOL flipped : {NO, YES})
    for (int scale : {1, 2}) {
        test_scale = scale;
        MyView2 *view = [[MyView2 alloc] initWithFrame:NSMakeRect(0, 0, 97, 629)];
        view.wantsLayer = YES; view.layer.geometryFlipped = flipped;
        native_discard_scroll_raster();
        VoxScrollRaster caches[2] = {};
        std::vector<double> scrolls {0, 17, 34, 251, 512, 529, 512, 251, 0, .5, 17.5, 0};
        CGImageRef retained = NULL, held_tile = NULL;
        std::vector<uint8_t> retained_pixels, held_pixels;
        unsigned composited = 0, recoveries = 0;
        for (size_t trial = 0; trial < scrolls.size(); ++trial) { @autoreleasepool {
            previous_scroll = trial ? scrolls[trial-1] : 0;
            test_scroll = scrolls[trial]; content_revision = trial;
            test_damage = 1; tiled_frame = true;
            native_scroll_raster = caches[0];
            auto reference = native_layer_raster_frame(view, scale, (IMP)draw);
            auto expected = packed(reference);
            caches[0] = native_scroll_raster;
            native_scroll_raster = caches[1];
            native_scroll_tile_test_allocation_failure = trial == 5;
            native_layer_present_frame(view, scale, (IMP)draw);
            native_scroll_tile_test_allocation_failure = NO;
            caches[1] = native_scroll_raster;
            auto frame = (VoxScrollTileFrame *)objc_getAssociatedObject(view, &native_scroll_tile_frame_key);
            if (!frame) {
                // A retained CA reader may temporarily exhaust the frame pool.
                // The ordinary full bitmap must be exact and the next frame
                // must rebuild tiles rather than reuse stale resources.
                assert(packed(native_layer_frame_image(view)) == expected);
                ++recoveries;
                CGImageRelease(reference); [CATransaction flush];
                continue;
            }
            ++composited;
            assert(!frame->flattened);
            assert(native_layer_frame_matches_input(view, scale));
            assert(!frame->flattened); // Identity checks never materialize a frame.
            auto actual = packed(native_layer_frame_image(view));
            if (actual != expected) {
                size_t differing = 0; int error = 0;
                for (size_t n = 0; n < actual.size(); ++n) {
                    differing += actual[n] != expected[n];
                    error = std::max(error, std::abs(int(actual[n]) - int(expected[n])));
                }
                int shown = 0;
                for (size_t n = 0; n < actual.size(); ++n) if (actual[n] != expected[n] && shown++ < 12)
                    fprintf(stderr,"diff x=%zu y=%zu channel=%zu expected=%u actual=%u\n",(n/4)%(97*scale),(n/4)/(97*scale),n%4,expected[n],actual[n]);
                fprintf(stderr,"capture scale=%d trial=%zu scroll=%g differing=%zu max=%d\n",scale,trial,test_scroll,differing,error);
                return 1;
            }
            if (trial == 0) {
                retained = CGImageRetain(native_layer_frame_image(view)); retained_pixels = actual;
                held_tile = CGImageRetain((CGImageRef)CFArrayGetValueAtIndex(frame->images, 0));
                held_pixels = packed(held_tile);
            }
            assert(packed(held_tile) == held_pixels);
            assert(native_scroll_tile_pool_bytes <= VOX_SCROLL_TILE_POOL_BYTES);
            assert(packed(retained) == retained_pixels);
            if (trial < 4) {
                // Compare actual GPU composition against the same reference
                // passed through Core Animation, preserving color semantics.
                CALayer *flat = [CALayer layer]; flat.frame = CGRectMake(0,0,97*scale,629*scale);
                flat.contents = (__bridge id)reference;
                flat.opaque = YES;
                auto rendered_reference = render_layer(flat,97*scale,629*scale);
                CALayer *composite = [CALayer layer];
                composite.frame = flat.frame;
                composite.contents = view.layer.contents;
                composite.geometryFlipped = view.layer.geometryFlipped;
                CALayer *tiles = view.layer.sublayers.lastObject;
                [CATransaction begin]; [CATransaction setDisableActions:YES];
                [tiles removeFromSuperlayer];
                // Child quads use logical points; render at the backing scale.
                tiles.bounds = CGRectMake(0,0,97,629);
                tiles.affineTransform = CGAffineTransformMakeScale(scale,scale);
                tiles.position = CGPointMake(97*scale/2.0,629*scale/2.0);
                [composite addSublayer:tiles];
                [CATransaction commit];
                auto rendered_actual = render_layer(composite,97*scale,629*scale);
                int max_error = 0;
                for (size_t n=0;n<rendered_actual.size();++n)
                    max_error=std::max(max_error,std::abs(int(rendered_actual[n])-int(rendered_reference[n])));
                fprintf(stderr,"CA scale=%d trial=%zu max_error=%d\n",scale,trial,max_error);
                if (max_error) {
                    for (int y : {0,4,6,7,8,21,255,256,261,263,500,620,628}) {
                        size_t n = size_t(y*scale)*97*scale*4+4;
                        fprintf(stderr,"row %d expected=%u,%u,%u actual=%u,%u,%u\n",y,
                            rendered_reference[n],rendered_reference[n+1],rendered_reference[n+2],
                            rendered_actual[n],rendered_actual[n+1],rendered_actual[n+2]);
                    }
                }
                assert(max_error == 0);
                [CATransaction begin]; [CATransaction setDisableActions:YES];
                [tiles removeFromSuperlayer];
                tiles.affineTransform = CGAffineTransformIdentity;
                tiles.bounds = view.layer.bounds;
                tiles.frame = view.layer.bounds;
                [view.layer addSublayer:tiles];
                [CATransaction commit];
            }
            CGImageRelease(reference);
            [CATransaction flush];
        } }
        assert(composited >= 10 && recoveries == 1);
        CGImageRelease(retained);
        id contents = view.layer.contents;
        view.layer.contents = nil;
        assert(!native_layer_frame_image(view) && !native_layer_frame_matches_input(view,scale));
        view.layer.contents = contents;
        gpu_enabled = 0;
        tiled_frame = true;
        native_layer_present_frame(view, scale, (IMP)draw);
        assert(!objc_getAssociatedObject(view, &native_scroll_tile_frame_key));
        gpu_enabled = 1;
        // An explicit kill switch must also preserve ordinary composition.
        setenv("VOX_DISABLE_SCROLL_TILE_COMPOSITOR", "1", 1);
        native_layer_present_frame(view, scale, (IMP)draw);
        assert(!objc_getAssociatedObject(view, &native_scroll_tile_frame_key));
        unsetenv("VOX_DISABLE_SCROLL_TILE_COMPOSITOR");
        native_discard_scroll_raster();
        native_scroll_raster = caches[0];
        native_discard_scroll_raster();
        assert(packed(held_tile) == held_pixels);
        CGImageRelease(held_tile);
    }
    unsetenv("VOX_SCROLL_TILE_COMPOSITOR");
    setenv("VOX_GPU_TILE_COMPOSITOR","1",1);
    native_scroll_gpu_tile_capability=YES;
    native_discard_scroll_raster();
    resident_frame=true; test_damage=1;
    for (int scale : {1,2}) {
        MyView2 *view=[[MyView2 alloc] initWithFrame:NSMakeRect(0,0,97,629)];
        view.wantsLayer=YES;
        native_discard_scroll_raster();
        native_scroll_gpu_tile_failed=native_scroll_gpu_tile_frame_failed=NO;
        CGImageRef held=NULL; std::vector<uint8_t> old;
        for (double scroll : {0.,17.,251.,512.,529.,512.,251.,0.,0.,.5,17.5,0.}) { @autoreleasepool {
            previous_scroll=test_scroll; test_scroll=scroll; content_revision=0;
            tiled_frame=false;
            auto reference=native_layer_raster_frame(view,scale,(IMP)draw);
            auto expected=packed(reference); CGImageRelease(reference);
            tiled_frame=true;
            native_layer_present_frame(view,scale,(IMP)draw);
            auto frame=(VoxScrollTileFrame*)objc_getAssociatedObject(view,&native_scroll_tile_frame_key);
            if (!frame || frame->overlay || frame->flattened)
                fprintf(stderr,"resident scale=%d scroll=%g frame=%d mode=%d reused=%d valid=%d current=%d failed=%d/%d exports=%u pending=%d\n",
                    scale,scroll,frame!=nil,native_scroll_raster.gpu_tiled,native_scroll_raster.reused,
                    native_scroll_raster.valid,native_scroll_raster.tiles_current,
                    native_scroll_gpu_tile_failed,native_scroll_gpu_tile_frame_failed,exports,native_scroll_tile_pending!=nil);
            assert(frame && frame->overlay==0 && !frame->flattened);
            assert(packed(native_layer_frame_image(view))==expected);
            if (!held) { held=CGImageRetain((CGImageRef)CFArrayGetValueAtIndex(frame->images,0)); old=packed(held); }
            assert(packed(held)==old);
        } }
        fail_export=true;
        test_scroll=42;
        native_layer_present_frame(view,scale,(IMP)draw);
        assert(native_scroll_gpu_tile_failed && native_scroll_gpu_tile_frame_failed);
        assert(!native_scroll_raster.valid && !native_scroll_raster.tiles_current);
        fail_export=false; native_scroll_gpu_tile_frame_failed=NO;
        // Failure retries in ordinary mode and rebuilds the stale CPU ring.
        native_layer_present_frame(view,scale,(IMP)draw);
        assert(!native_scroll_raster.gpu_tiled && !native_scroll_raster.reused);
        tiled_frame=false;
        auto reference=native_layer_raster_frame(view,scale,(IMP)draw);
        assert(packed(reference)==packed(native_layer_frame_image(view)));
        CGImageRelease(reference); CGImageRelease(held);
        native_scroll_gpu_tile_failed=NO;
        native_discard_scroll_raster();
    }
    assert(exports>=20);
    puts("Resident tile mapping: exact wraps/reversals, lazy captures, immutable providers, allocation failure and mode recovery passed");
    puts("Retained scroll tiles: exact captures, wrap/reversal, fractional damage, resource lifetime and Core Animation pixels passed");
} }
