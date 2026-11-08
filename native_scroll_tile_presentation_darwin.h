#ifndef VOX_NATIVE_SCROLL_TILE_PRESENTATION_DARWIN_H
#define VOX_NATIVE_SCROLL_TILE_PRESENTATION_DARWIN_H
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <IOSurface/IOSurface.h>
#import <objc/runtime.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <dlfcn.h>
#include "platform/native_state.h"
#include "native_graphite_bridge.h"

// The ring's physical rows are immutable compositor resources. Scrolling
// changes their placement; only tiles touched by raster damage are replaced.
// Raster may come from the CPU ring or a scheduled GPU export. Input and
// paint planning still run on the main thread.
#define VOX_SCROLL_TILE_ROWS 256
#define VOX_SCROLL_TILE_LIMIT 65
#define VOX_SCROLL_TILE_POOL_SLOTS 48
#define VOX_SCROLL_TILE_POOL_BYTES (128u * 1024u * 1024u)
// A submitted GPU export can finish CPU frame work before it registers its
// scheduling fences. Every consumer shares one readiness token; readers and
// CA publication resolve it once; resolving or dropping releases it once.
@interface VoxScrollGpuFence : NSObject {
@public
    void *completion;
    int (*schedule)(void *);
    void (*release_completion)(void *);
    BOOL resolved, ready;
}
- (BOOL)waitForConsumer:(const char *)consumer;
@end
#if !defined(V_PARALLEL_CC) || defined(V_PARALLEL_CC_OUT_0)
@implementation VoxScrollGpuFence
- (BOOL)waitForConsumer:(const char *)consumer {
    @synchronized(self) {
        if (!resolved) {
            BOOL diagnostic = getenv("VOX_GPU_TILE_SCHEDULE_DIAGNOSTICS") != NULL;
            double started = diagnostic ? CACurrentMediaTime() : 0;
            ready = completion && schedule && schedule(completion);
            resolved = YES;
            // Once registered, IOSurface carries the read fence. Do not keep
            // a completed command buffer's resources for a retained tile's life.
            if (completion && release_completion) release_completion(completion);
            completion = NULL;
            if (diagnostic) {
                double (*clock)(void) = (double (*)(void))dlsym(RTLD_DEFAULT,"vox_precise_scroll_diagnostic_time");
                fprintf(stderr,"VOX_GPU_TILE_SCHEDULE consumer=%s ready=%d wait_us=%.3f t_us=%.3f\n",
                    consumer,ready,(CACurrentMediaTime()-started)*1e6,clock ? clock() : -1);
            }
        }
        return ready;
    }
}
- (void)dealloc {
    if (completion && release_completion) release_completion(completion);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}
@end
#endif
typedef struct {
    IOSurfaceRef surface;
    CGDataProviderRef provider;
    size_t width, height, pitch, bytes;
    int busy;
    CFTypeRef fence;
} VoxScrollTileStorage;
VOX_NATIVE_STATE VoxScrollTileStorage native_scroll_tile_pool[VOX_SCROLL_TILE_POOL_SLOTS];
VOX_NATIVE_STATE size_t native_scroll_tile_pool_bytes;
VOX_NATIVE_STATE CGImageRef native_scroll_tile_images[VOX_SCROLL_TILE_LIMIT];
VOX_NATIVE_STATE CGContextRef native_scroll_tile_destination;
VOX_NATIVE_STATE BOOL native_scroll_tile_setting;
VOX_NATIVE_STATE BOOL native_scroll_tile_sparse;
VOX_NATIVE_STATE BOOL native_scroll_gpu_tile_capability;
VOX_NATIVE_STATE BOOL native_scroll_gpu_tile_failed;
VOX_NATIVE_STATE BOOL native_scroll_gpu_tile_frame_failed;
VOX_NATIVE_STATE char native_scroll_tile_frame_key;
VOX_NATIVE_STATE char native_scroll_tile_layer_key;
VOX_NATIVE_STATE char native_scroll_tile_container_key;

@interface VoxScrollTileFrame : NSObject {
@public
    CGImageRef base, flattened;
    CFArrayRef images;
    CGRect source[VOX_SCROLL_TILE_LIMIT + 1], target[VOX_SCROLL_TILE_LIMIT + 1];
    size_t count, width, height, top, document_width, document_height, overlay;
    CGFloat scale;
    CFTypeRef fence;
}
@end
#if !defined(V_PARALLEL_CC) || defined(V_PARALLEL_CC_OUT_0)
@implementation VoxScrollTileFrame
- (void)dealloc {
    if (base) CGImageRelease(base);
    if (flattened) CGImageRelease(flattened);
    if (images) CFRelease(images);
    if (fence) CFRelease(fence);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}
@end
#endif
VOX_NATIVE_STATE VoxScrollTileFrame *native_scroll_tile_pending;

static void native_scroll_tile_compositor_enabled(int enabled) {
    native_scroll_tile_setting = enabled != 0;
}
static BOOL native_scroll_gpu_tiles_enabled(void) {
    return native_scroll_tile_setting && native_scroll_gpu_tile_capability
        && !native_scroll_gpu_tile_failed && getenv("VOX_GPU_TILE_COMPOSITOR")
        && !getenv("VOX_DISABLE_SCROLL_TILE_COMPOSITOR");
}
static BOOL native_scroll_tiles_accept(CGContextRef context) {
    return native_scroll_tile_setting && context && context == native_scroll_tile_destination
        && (getenv("VOX_SCROLL_TILE_COMPOSITOR") || native_scroll_gpu_tiles_enabled())
        && !getenv("VOX_DISABLE_SCROLL_TILE_COMPOSITOR");
}
static void native_scroll_tiles_drop_pending(void) {
#if !__has_feature(objc_arc)
    [native_scroll_tile_pending release];
#endif
    native_scroll_tile_pending = nil;
}
static void native_scroll_tiles_clear(void) {
    for (size_t index = 0; index < VOX_SCROLL_TILE_LIMIT; ++index) {
        if (native_scroll_tile_images[index]) CGImageRelease(native_scroll_tile_images[index]);
        native_scroll_tile_images[index] = NULL;
    }
    native_scroll_tiles_drop_pending();
    for (size_t index = 0; index < VOX_SCROLL_TILE_POOL_SLOTS; ++index) {
        VoxScrollTileStorage *slot = &native_scroll_tile_pool[index];
        if (slot->surface && !__atomic_load_n(&slot->busy, __ATOMIC_ACQUIRE)
            && !IOSurfaceIsInUse(slot->surface)) {
            native_scroll_tile_pool_bytes -= slot->bytes;
            CFRelease(slot->surface);
            *slot = (VoxScrollTileStorage){0};
        }
    }
}
static void native_scroll_tile_release(void *info, const void *data, size_t size) {
    (void)data; (void)size;
    VoxScrollTileStorage *slot = (VoxScrollTileStorage *)info;
    __atomic_store_n(&slot->provider, NULL, __ATOMIC_RELEASE);
    if (slot->fence) { CFRelease(slot->fence); slot->fence = NULL; }
    __atomic_store_n(&slot->busy, 0, __ATOMIC_RELEASE);
}
#ifdef VOX_TEST_SCROLL_TILES
static BOOL native_scroll_tile_test_allocation_failure;
#endif
static VoxScrollTileStorage *native_scroll_tile_acquire(size_t width, size_t height) {
#ifdef VOX_TEST_SCROLL_TILES
    if (native_scroll_tile_test_allocation_failure) return NULL;
#endif
    VoxScrollTileStorage *slot = NULL;
    for (size_t index = 0; index < VOX_SCROLL_TILE_POOL_SLOTS; ++index) {
        VoxScrollTileStorage *candidate = &native_scroll_tile_pool[index];
        if (__atomic_load_n(&candidate->busy, __ATOMIC_ACQUIRE)) continue;
        if (candidate->surface && IOSurfaceIsInUse(candidate->surface)) continue;
        if (candidate->surface && candidate->width == width && candidate->height == height) {
            slot = candidate; break;
        }
        if (!slot) slot = candidate;
    }
    if (!slot) return NULL;
    if (slot->surface && (slot->width != width || slot->height != height)) {
        native_scroll_tile_pool_bytes -= slot->bytes;
        CFRelease(slot->surface); *slot = (VoxScrollTileStorage){0};
    }
    if (!slot->surface) {
        size_t pitch = IOSurfaceAlignProperty(kIOSurfaceBytesPerRow, width * 4);
        if (!pitch || height > VOX_SCROLL_TILE_POOL_BYTES / pitch
            || native_scroll_tile_pool_bytes > VOX_SCROLL_TILE_POOL_BYTES - pitch * height) return NULL;
        NSDictionary *properties = @{
            (__bridge NSString *)kIOSurfaceWidth: @(width),
            (__bridge NSString *)kIOSurfaceHeight: @(height),
            (__bridge NSString *)kIOSurfaceBytesPerElement: @4,
            (__bridge NSString *)kIOSurfaceBytesPerRow: @(pitch),
            (__bridge NSString *)kIOSurfacePixelFormat: @((uint32_t)0x52474241) };
        slot->surface = IOSurfaceCreate((__bridge CFDictionaryRef)properties);
        if (!slot->surface) return NULL;
        CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CFPropertyListRef profile = color ? CGColorSpaceCopyPropertyList(color) : NULL;
        if (color) CGColorSpaceRelease(color);
        if (!profile) { CFRelease(slot->surface); slot->surface = NULL; return NULL; }
        IOSurfaceSetValue(slot->surface, kIOSurfaceColorSpace, profile); CFRelease(profile);
        slot->width = width; slot->height = height; slot->pitch = pitch;
        slot->bytes = IOSurfaceGetAllocSize(slot->surface);
        if (slot->bytes > VOX_SCROLL_TILE_POOL_BYTES - native_scroll_tile_pool_bytes) {
            CFRelease(slot->surface); *slot = (VoxScrollTileStorage){0}; return NULL;
        }
        native_scroll_tile_pool_bytes += slot->bytes;
    }
    __atomic_store_n(&slot->busy, 1, __ATOMIC_RELEASE);
    return slot;
}
static CGImageRef native_scroll_tile_image(VoxScrollTileStorage *slot, BOOL gpu);
static CGImageRef native_scroll_tile_copy(const uint8_t *rows, size_t width, size_t height) {
    VoxScrollTileStorage *slot = native_scroll_tile_acquire(width, height);
    if (!slot) return NULL;
    if (IOSurfaceLock(slot->surface, 0, NULL) != kIOReturnSuccess) {
        __atomic_store_n(&slot->busy, 0, __ATOMIC_RELEASE); return NULL;
    }
    uint8_t *pixels = (uint8_t *)IOSurfaceGetBaseAddress(slot->surface);
    for (size_t y = 0; y < height; ++y)
        memcpy(pixels + y * slot->pitch, rows + y * width * 4, width * 4);
    IOSurfaceUnlock(slot->surface, 0, NULL);
    return native_scroll_tile_image(slot, NO);
}
// Core Animation consumes the scheduled IOSurface directly. CPU capture takes
// the kernel's read fence lazily, only when a provider actually reads bytes.
static const void *native_scroll_tile_get_bytes(void *info) {
    VoxScrollTileStorage *slot = (VoxScrollTileStorage *)info;
    if (slot->fence && ![(__bridge VoxScrollGpuFence *)slot->fence waitForConsumer:"pixels"]) return NULL;
    return IOSurfaceLock(slot->surface, kIOSurfaceLockReadOnly, NULL) == kIOReturnSuccess
        ? IOSurfaceGetBaseAddress(slot->surface) : NULL;
}
static void native_scroll_tile_put_bytes(void *info, const void *bytes) {
    if (bytes) IOSurfaceUnlock(((VoxScrollTileStorage *)info)->surface, kIOSurfaceLockReadOnly, NULL);
}
static size_t native_scroll_tile_read_bytes(void *info, void *buffer, off_t offset, size_t count) {
    VoxScrollTileStorage *slot = (VoxScrollTileStorage *)info;
    if (offset < 0 || (uint64_t)offset >= slot->bytes) return 0;
    if (count > slot->bytes - (size_t)offset) count = slot->bytes - (size_t)offset;
    const uint8_t *bytes = (const uint8_t *)native_scroll_tile_get_bytes(info);
    if (!bytes) return 0;
    memcpy(buffer, bytes + offset, count); native_scroll_tile_put_bytes(info, bytes);
    return count;
}
static void native_scroll_tile_release_direct(void *info) {
    native_scroll_tile_release(info, NULL, 0);
}
static CGImageRef native_scroll_tile_image(VoxScrollTileStorage *slot, BOOL gpu) {
    CGDataProviderDirectCallbacks callbacks = {0, native_scroll_tile_get_bytes,
        native_scroll_tile_put_bytes, native_scroll_tile_read_bytes, native_scroll_tile_release_direct};
    CGDataProviderRef provider = gpu ? CGDataProviderCreateDirect(slot, slot->bytes, &callbacks)
        : CGDataProviderCreateWithData(slot, IOSurfaceGetBaseAddress(slot->surface),
            slot->bytes, native_scroll_tile_release);
    if (!provider) { native_scroll_tile_release(slot,NULL,0); return NULL; }
    __atomic_store_n(&slot->provider, provider, __ATOMIC_RELEASE);
    __atomic_store_n(&slot->busy, 1, __ATOMIC_RELEASE);
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image = CGImageCreate(slot->width, slot->height, 8, 32, slot->pitch, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, provider, NULL, false,
        kCGRenderingIntentDefault);
    CGColorSpaceRelease(color); CGDataProviderRelease(provider);
    return image;
}
static IOSurfaceRef native_scroll_tile_surface(CGImageRef image) {
    CGDataProviderRef provider = CGImageGetDataProvider(image);
    for (size_t index = 0; index < VOX_SCROLL_TILE_POOL_SLOTS; ++index)
        if (__atomic_load_n(&native_scroll_tile_pool[index].provider, __ATOMIC_ACQUIRE) == provider)
            return native_scroll_tile_pool[index].surface;
    return NULL;
}
static CFTypeRef native_scroll_tile_image_fence(CGImageRef image) {
    CGDataProviderRef provider = image ? CGImageGetDataProvider(image) : NULL;
    if (!provider) return NULL;
    for (size_t index=0; index<VOX_SCROLL_TILE_POOL_SLOTS; ++index)
        if (__atomic_load_n(&native_scroll_tile_pool[index].provider,__ATOMIC_ACQUIRE)==provider)
            // The image retains this provider, so its busy slot and fence
            // cannot be recycled while a frame is inspecting them.
            return native_scroll_tile_pool[index].fence;
    return NULL;
}

static BOOL native_scroll_tiles_adopt(CGImageRef *, size_t, size_t, size_t, size_t,
    size_t, size_t, CGFloat, BOOL);
// Called after CPU/GPU raster finishes and before viewport overlays paint.
// dirty_rows are ring-storage row numbers, never viewport positions.
static BOOL native_scroll_tiles_commit_mode(const uint8_t *ring, size_t width, size_t height,
    size_t row_origin, size_t top, CGFloat scale, const BOOL *dirty, BOOL gpu) {
    if (!native_scroll_tiles_accept(native_scroll_tile_destination)) return NO;
    size_t tiles = (height + VOX_SCROLL_TILE_ROWS - 1) / VOX_SCROLL_TILE_ROWS;
    if (!tiles || tiles > VOX_SCROLL_TILE_LIMIT) return NO;
    CGImageRef next[VOX_SCROLL_TILE_LIMIT] = {0};
    size_t updated = 0;
    for (size_t index = 0; index < tiles; ++index) {
        size_t first = index * VOX_SCROLL_TILE_ROWS;
        size_t rows = height - first < VOX_SCROLL_TILE_ROWS ? height - first : VOX_SCROLL_TILE_ROWS;
        if (!dirty[index] && native_scroll_tile_images[index])
            next[index] = CGImageRetain(native_scroll_tile_images[index]);
        else {
            next[index] = native_scroll_tile_copy(ring + first * width * 4, width, rows);
            ++updated;
        }
        if (!next[index]) {
            for (size_t previous = 0; previous < index; ++previous) CGImageRelease(next[previous]);
            return NO;
        }
    }
    return native_scroll_tiles_adopt(next, tiles, updated, width, height, row_origin, top, scale, gpu);
}
static BOOL native_scroll_tiles_commit(const uint8_t *ring, size_t width, size_t height,
    size_t row_origin, size_t top, CGFloat scale, const BOOL *dirty) {
    return native_scroll_tiles_commit_mode(ring,width,height,row_origin,top,scale,dirty,NO);
}
static BOOL native_scroll_tiles_adopt(CGImageRef *next, size_t tiles, size_t updated,
    size_t width, size_t height, size_t row_origin, size_t top, CGFloat scale, BOOL gpu) {
    VoxScrollTileFrame *frame = [[VoxScrollTileFrame alloc] init];
    frame->top = top; frame->document_width = width; frame->document_height = height;
    frame->scale = scale; frame->overlay = gpu ? 0 : (size_t)ceil(32 * scale);
    NSMutableArray *images = [NSMutableArray array];
    for (size_t y = 0; y < height;) {
        size_t physical = (row_origin + y) % height;
        size_t index = physical / VOX_SCROLL_TILE_ROWS;
        size_t local = physical % VOX_SCROLL_TILE_ROWS;
        size_t rows = CGImageGetHeight(next[index]) - local;
        if (rows > height - y) rows = height - y;
        frame->source[frame->count] = CGRectMake(0, local, width, rows);
        frame->target[frame->count] = CGRectMake(0, top + y, width, rows);
        ++frame->count;
        [images addObject:(__bridge id)next[index]];
        y += rows;
    }
    frame->images = (CFArrayRef)CFRetain((__bridge CFArrayRef)images);
    for (size_t index = 0; index < VOX_SCROLL_TILE_LIMIT; ++index) {
        if (native_scroll_tile_images[index]) CGImageRelease(native_scroll_tile_images[index]);
        native_scroll_tile_images[index] = index < tiles ? next[index] : NULL;
    }
    native_scroll_tiles_drop_pending(); native_scroll_tile_pending = frame;
    if (getenv("VOX_SCROLL_TILE_DIAGNOSTICS"))
        fprintf(stderr, "VOX_SCROLL_TILES tiles=%zu updated=%zu quads=%zu pool_bytes=%zu sparse=%d\n",
            tiles, updated, frame->count, native_scroll_tile_pool_bytes, native_scroll_tile_sparse);
    return YES;
}

typedef int (*VoxScrollGpuPresent)(CGContextRef, const VoxGraphiteCanvasSurfaceRegion *, int, void **);
typedef void (*VoxScrollGpuRelease)(void *);
typedef int (*VoxScrollGpuSchedule)(void *);
static BOOL native_scroll_tiles_export_with_schedule(CGContextRef context, size_t width, size_t height,
    size_t row_origin, size_t top, CGFloat scale, const BOOL *dirty,
    VoxScrollGpuPresent present, VoxScrollGpuRelease release, VoxScrollGpuSchedule schedule) {
    size_t tiles = (height + VOX_SCROLL_TILE_ROWS - 1) / VOX_SCROLL_TILE_ROWS, updated = 0;
    if (!tiles || tiles > VOX_SCROLL_TILE_LIMIT) return NO;
    CGImageRef next[VOX_SCROLL_TILE_LIMIT] = {0};
    VoxScrollTileStorage *slots[VOX_SCROLL_TILE_LIMIT] = {0};
    VoxGraphiteCanvasSurfaceRegion regions[VOX_SCROLL_TILE_LIMIT + 1];
    int count = 0;
    CFTypeRef fence = NULL;
    for (size_t index = 0; index < tiles; ++index) {
        if (!dirty[index] && native_scroll_tile_images[index]) {
            next[index] = CGImageRetain(native_scroll_tile_images[index]); continue;
        }
        size_t first = index * VOX_SCROLL_TILE_ROWS;
        size_t rows = height - first < VOX_SCROLL_TILE_ROWS ? height - first : VOX_SCROLL_TILE_ROWS;
        slots[index] = native_scroll_tile_acquire(width, rows);
        if (!slots[index]) goto failed;
        ++updated;
    }
    for (size_t y = 0; y < height;) {
        size_t physical = (row_origin + y) % height, index = physical / VOX_SCROLL_TILE_ROWS;
        size_t local = physical % VOX_SCROLL_TILE_ROWS;
        size_t rows = (index * VOX_SCROLL_TILE_ROWS + VOX_SCROLL_TILE_ROWS < height
            ? VOX_SCROLL_TILE_ROWS : height - index * VOX_SCROLL_TILE_ROWS) - local;
        if (rows > height - y) rows = height - y;
        if (slots[index]) {
            regions[count++] = (VoxGraphiteCanvasSurfaceRegion){slots[index]->surface,
                native_scroll_tile_images[index] ? native_scroll_tile_surface(native_scroll_tile_images[index]) : NULL,
                0, (int)(top+y), 0, (int)local, (int)width, (int)rows};
        }
        y += rows;
    }
    if (count) {
        if (!present || !release) goto failed;
        void *completion = NULL;
        if (present(context, regions, count, &completion) != 1 || !completion) {
            if (completion) release(completion);
            goto failed;
        }
        if (schedule) {
            VoxScrollGpuFence *owned = [[VoxScrollGpuFence alloc] init];
            if (owned) {
                owned->completion = completion; owned->schedule = schedule; owned->release_completion = release;
                fence = CFRetain((__bridge CFTypeRef)owned);
#if !__has_feature(objc_arc)
                [owned release];
#endif
            } else {
                BOOL ready = schedule(completion); release(completion);
                if (!ready) goto failed;
            }
        } else release(completion);
    }
    for (size_t index = 0; index < tiles; ++index) if (slots[index]) {
        if (fence) slots[index]->fence = CFRetain(fence);
        next[index] = native_scroll_tile_image(slots[index], YES);
        slots[index] = NULL; // Provider now owns the reservation, including failure.
        if (!next[index]) goto failed;
    }
    if (!native_scroll_tiles_adopt(next, tiles, updated, width, height, row_origin, top, scale, YES)) goto failed;
    if (fence) { native_scroll_tile_pending->fence = CFRetain(fence); CFRelease(fence); }
    return YES;
failed:
    if (fence) CFRelease(fence);
    for (size_t index = 0; index < tiles; ++index) {
        if (next[index]) CGImageRelease(next[index]);
        if (slots[index]) __atomic_store_n(&slots[index]->busy, 0, __ATOMIC_RELEASE);
    }
    return NO;
}

static BOOL native_scroll_tiles_export(CGContextRef context, size_t width, size_t height,
    size_t row_origin, size_t top, CGFloat scale, const BOOL *dirty,
    VoxScrollGpuPresent present, VoxScrollGpuRelease release) {
    return native_scroll_tiles_export_with_schedule(context,width,height,row_origin,top,scale,dirty,present,release,NULL);
}

static BOOL native_scroll_tiles_have_fences(VoxScrollTileFrame *frame) {
    if (frame->fence) return YES;
    for (CFIndex index=0; frame->images && index<CFArrayGetCount(frame->images); ++index)
        if (native_scroll_tile_image_fence((CGImageRef)CFArrayGetValueAtIndex(frame->images,index))) return YES;
    return NO;
}
static BOOL native_scroll_tiles_ready(VoxScrollTileFrame *frame, const char *consumer) {
    if (frame->fence && ![(__bridge VoxScrollGpuFence *)frame->fence waitForConsumer:consumer]) return NO;
    // Zero-damage exports have no new ticket, but their cached surfaces still
    // belong to earlier producers. Direct CA IOSurface consumption bypasses
    // the pixel provider, so resolve those inherited fences here as well.
    for (CFIndex index=0; frame->images && index<CFArrayGetCount(frame->images); ++index) {
        CFTypeRef fence = native_scroll_tile_image_fence((CGImageRef)CFArrayGetValueAtIndex(frame->images,index));
        if (fence && ![(__bridge VoxScrollGpuFence *)fence waitForConsumer:consumer]) return NO;
    }
    return YES;
}

static CGImageRef native_scroll_tiles_flatten(VoxScrollTileFrame *frame) {
    if (!native_scroll_tiles_ready(frame,"capture")) return NULL;
    if (frame->flattened) return frame->flattened;
    CFDataRef input = CGDataProviderCopyData(CGImageGetDataProvider(frame->base));
    if (!input) return NULL;
    size_t pitch = CGImageGetBytesPerRow(frame->base);
    NSMutableData *output = [NSMutableData dataWithBytes:CFDataGetBytePtr(input)
        length:CFDataGetLength(input)];
    CFRelease(input);
    uint8_t *pixels = (uint8_t *)output.mutableBytes;
    size_t right = frame->overlay < frame->document_width
        ? frame->document_width - frame->overlay : 0;
    size_t bottom = frame->overlay < frame->document_height
        ? frame->document_height - frame->overlay : 0;
    for (size_t index = 0; index < frame->count; ++index) {
        CGImageRef tile = (CGImageRef)CFArrayGetValueAtIndex(frame->images, index);
        CFDataRef bytes = CGDataProviderCopyData(CGImageGetDataProvider(tile));
        if (!bytes) return NULL;
        size_t tile_pitch = CGImageGetBytesPerRow(tile);
        CGRect src = frame->source[index], dst = frame->target[index];
        for (size_t y = 0; y < (size_t)src.size.height; ++y) {
            size_t row = (size_t)dst.origin.y + y;
            if (row - frame->top >= bottom) continue;
            memcpy(pixels + row * pitch, CFDataGetBytePtr(bytes)
                + ((size_t)src.origin.y + y) * tile_pitch, right * 4);
        }
        CFRelease(bytes);
    }
    CFDataRef owned = CFDataCreateCopy(NULL, (__bridge CFDataRef)output);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(owned);
    CFRelease(owned);
    if (!provider) return NULL;
    frame->flattened = CGImageCreate(frame->width, frame->height, 8, 32, pitch,
        CGImageGetColorSpace(frame->base), CGImageGetBitmapInfo(frame->base), provider,
        NULL, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return frame->flattened;
}

static void native_scroll_tile_quad(CALayer *parent, size_t index, CGImageRef image, CGRect source,
    CGRect target, CGFloat scale, size_t frame_height, BOOL flipped) {
    CALayer *layer = index < parent.sublayers.count ? parent.sublayers[index] : nil;
    if (!layer) { layer = [CALayer layer]; [parent addSublayer:layer]; }
    target.origin.x /= scale; target.origin.y /= scale;
    target.size.width /= scale; target.size.height /= scale;
    if (!flipped) target.origin.y = frame_height / scale - CGRectGetMaxY(target);
    layer.frame = target;
    layer.contentsRect = CGRectMake(source.origin.x / CGImageGetWidth(image),
        (flipped ? source.origin.y : CGImageGetHeight(image) - CGRectGetMaxY(source)) / CGImageGetHeight(image),
        source.size.width / CGImageGetWidth(image),
        source.size.height / CGImageGetHeight(image));
    IOSurfaceRef surface = native_scroll_tile_surface(image);
    layer.contents = surface ? (__bridge id)surface : (__bridge id)image;
    layer.contentsScale = scale;
    layer.contentsGravity = kCAGravityResize;
    layer.minificationFilter = kCAFilterNearest; layer.magnificationFilter = kCAFilterNearest;
    layer.opaque = YES;
    objc_setAssociatedObject(layer, &native_scroll_tile_layer_key,
        (__bridge id)image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void native_scroll_tiles_present(NSView *view, VoxScrollTileFrame *frame) {
    if (!native_scroll_tiles_ready(frame,"publication")) return;
    CALayer *container = objc_getAssociatedObject(view, &native_scroll_tile_container_key);
    if (!container) {
        container = [CALayer layer];
        container.name = @"Vox retained document tiles";
        container.geometryFlipped = NO;
        objc_setAssociatedObject(view, &native_scroll_tile_container_key, container,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (container.superlayer != view.layer) [view.layer addSublayer:container];
    container.frame = view.layer.bounds;
    // A plain child container inherits the host layer's coordinate direction.
    // Keep image sampling bottom-left, and convert only quad placements.
    BOOL flipped = view.layer.geometryFlipped;
    for (size_t index = 0; index < frame->count; ++index)
        native_scroll_tile_quad(container, index, (CGImageRef)CFArrayGetValueAtIndex(frame->images, index),
            frame->source[index], frame->target[index], frame->scale, frame->height, flipped);
    // The existing V scrollbar painter owns these viewport overlay bands.
    // Their backdrop was restored before replay and never enters the ring.
    size_t w = frame->document_width, h = frame->document_height;
    size_t right = frame->overlay < w ? w - frame->overlay : 0;
    size_t bottom = frame->overlay < h ? h - frame->overlay : 0;
    CGRect vertical = CGRectMake(right, frame->top, w - right, h);
    CGRect horizontal = CGRectMake(0, frame->top + bottom, right, h - bottom);
    size_t count = frame->count;
    if (vertical.size.width && vertical.size.height)
        native_scroll_tile_quad(container, count++, frame->base, vertical, vertical,
            frame->scale, frame->height, flipped);
    if (horizontal.size.width && horizontal.size.height)
        native_scroll_tile_quad(container, count++, frame->base, horizontal, horizontal,
            frame->scale, frame->height, flipped);
    while (container.sublayers.count > count) [container.sublayers.lastObject removeFromSuperlayer];
    objc_setAssociatedObject(view, &native_scroll_tile_frame_key, frame, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (getenv("VOX_SCROLL_TILE_DIAGNOSTICS"))
        fprintf(stderr, "VOX_SCROLL_TILE_TREE flipped=%d quads=%zu\n", flipped, count);
}
static void native_scroll_tiles_unpresent(NSView *view) {
    CALayer *container = objc_getAssociatedObject(view, &native_scroll_tile_container_key);
    [container removeFromSuperlayer];
    objc_setAssociatedObject(view, &native_scroll_tile_container_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &native_scroll_tile_frame_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
#endif
