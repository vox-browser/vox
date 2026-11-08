#include "../native/include/native_scroll_tile_presentation_darwin.h"
#include <cassert>
#include <cstdio>
#include <initializer_list>
static unsigned waits,releases;
static bool succeeds=true, submit_error;
static int schedule(void*) { ++waits; return succeeds; }
static void release_ticket(void* ticket) { ++releases; free(ticket); }
static int submit(CGContextRef,const VoxGraphiteCanvasSurfaceRegion* regions,int count,void** ticket) {
    for(int i=0;i<count;++i) {
        auto surface=(IOSurfaceRef)regions[i].surface;
        assert(!IOSurfaceLock(surface,0,nullptr));
        auto bytes=(uint8_t*)IOSurfaceGetBaseAddress(surface);
        for(size_t y=0;y<IOSurfaceGetHeight(surface);++y) for(size_t x=0;x<IOSurfaceGetWidth(surface);++x) {
            auto p=bytes+y*IOSurfaceGetBytesPerRow(surface)+x*4;
            p[0]=17;p[1]=31;p[2]=53;p[3]=255;
        }
        IOSurfaceUnlock(surface,0,nullptr);
    }
    *ticket=malloc(1); return submit_error ? -1 : int(*ticket!=nullptr);
}
static CGContextRef context() {
    auto color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto result=CGBitmapContextCreate(nullptr,32,16,8,32*4,color,
        kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(result);return result;
}
static VoxScrollTileFrame* frame(CGContextRef context) {
    BOOL dirty[]={YES};
    native_scroll_tile_destination=context;
    assert(native_scroll_tiles_export_with_schedule(context,32,16,0,0,1,dirty,submit,release_ticket,schedule));
    auto result=native_scroll_tile_pending;
    assert(result && result->fence && waits==0 && releases==0);
    result->base=CGBitmapContextCreateImage(context);result->width=32;result->height=16;
    return result;
}
static void read_pixels(CGImageRef image) {
    auto bytes=CGDataProviderCopyData(CGImageGetDataProvider(image));assert(bytes);
    auto data=CFDataGetBytePtr(bytes);assert(data[0]==17 && data[1]==31 && data[2]==53 && data[3]==255);
    CFRelease(bytes);
}
int main() { @autoreleasepool {
    auto bitmap=context();native_scroll_gpu_tile_capability=YES;native_scroll_tile_compositor_enabled(1);
    setenv("VOX_GPU_TILE_COMPOSITOR","1",1);
    // Publication and repeated capture share one non-consuming scheduling wait.
    @autoreleasepool {
    auto first=frame(bitmap);
    assert(native_scroll_tiles_ready(first,"publication"));assert(waits==1 && releases==1);
    assert(native_scroll_tiles_ready(first,"publication"));
    assert(native_scroll_tiles_flatten(first));read_pixels(native_scroll_tile_images[0]);assert(waits==1);
    native_scroll_tiles_clear();
    }
    assert(releases==1);
    // A zero-damage frame has no new export ticket. Its retained tile still
    // depends on the earlier producer, including that producer's failure.
    for (bool ready : {true,false}) {
        waits=releases=0;succeeds=ready;
        @autoreleasepool {
            frame(bitmap);
            BOOL dirty[]={NO};
            assert(native_scroll_tiles_export_with_schedule(bitmap,32,16,0,0,1,dirty,
                submit,release_ticket,schedule));
            auto cached=native_scroll_tile_pending;
            assert(cached && !cached->fence && !waits && !releases);
            assert(native_scroll_tiles_have_fences(cached));
            cached->base=CGBitmapContextCreateImage(bitmap);cached->width=32;cached->height=16;
            assert(native_scroll_tiles_ready(cached,"cached-publication")==ready);
            assert(waits==1 && releases==1);
            assert((native_scroll_tiles_flatten(cached)!=nullptr)==ready);
            native_scroll_tiles_clear();
        }
        assert(releases==1);
    }
    succeeds=true;
    // A provider remains safe even when retained independently of its frame.
    waits=releases=0;CGImageRef retained=nullptr;
    @autoreleasepool { frame(bitmap);
    retained=CGImageRetain(native_scroll_tile_images[0]);native_scroll_tiles_clear(); }
    assert(!waits && !releases);read_pixels(retained);assert(waits==1 && releases==1);
    @autoreleasepool { CGImageRelease(retained); }
    assert(releases==1);
    // Dropping an unpublished frame never waits, and releases its ticket once.
    waits=releases=0;
    @autoreleasepool { frame(bitmap);native_scroll_tiles_clear(); }
    assert(!waits && releases==1);
    // A producer can reject after returning an owned ticket (verification
    // failure). The export drops that ticket and never attaches a provider.
    waits=releases=0;submit_error=true;
    @autoreleasepool {
        BOOL dirty[]={YES};native_scroll_tile_destination=bitmap;
        assert(!native_scroll_tiles_export_with_schedule(bitmap,32,16,0,0,1,dirty,submit,release_ticket,schedule));
        assert(!native_scroll_tile_pending && !waits && releases==1);
    }
    submit_error=false;
    // Failed scheduling cannot expose captured pixels or a new CA frame.
    waits=releases=0;succeeds=false;
    @autoreleasepool { auto failed=frame(bitmap);
    assert(!native_scroll_tiles_ready(failed,"publication"));assert(!native_scroll_tiles_flatten(failed));
    auto unreadable=CGDataProviderCopyData(CGImageGetDataProvider(native_scroll_tile_images[0]));
    assert(!unreadable || CFDataGetLength(unreadable)==0);
    if (unreadable) CFRelease(unreadable);
    assert(waits==1);native_scroll_tiles_clear(); }
    assert(releases==1);succeeds=true;
    // Independent consumers resolve the same token safely.
    waits=releases=0;
    @autoreleasepool { auto shared=frame(bitmap);
    dispatch_apply(16,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^(size_t) {
        assert(native_scroll_tiles_ready(shared,"concurrent"));
    });
    assert(waits==1 && releases==1);native_scroll_tiles_clear(); }
    assert(releases==1);
    CGContextRelease(bitmap);
    std::puts("Deferred GPU fences: publication, capture, independent provider, dropped frame, failure and concurrent consumers passed");
} }
