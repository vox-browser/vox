#ifndef VOX_NATIVE_FRAME_METAL_QUEUE_H
#define VOX_NATIVE_FRAME_METAL_QUEUE_H
#import <Metal/Metal.h>
#include <time.h>
#include <mach/mach_time.h>
#ifndef VOX_METAL_QUEUE_FRAME_LIMIT
#define VOX_METAL_QUEUE_FRAME_LIMIT 256
#endif

static id<MTLCommandBuffer> vox_metal_time_command(id<MTLCommandBuffer> command) {
    static bool const enabled=getenv("VOX_METAL_COMMAND_TIMES")!=NULL;
    if (!enabled || !command) return command;
    mach_timebase_info_data_t clock;
    mach_timebase_info(&clock);
    double created=(double)mach_absolute_time()*clock.numer/clock.denom/1e9;
    [command addCompletedHandler:^(id<MTLCommandBuffer> completed) {
        @autoreleasepool {
            double end=(double)mach_absolute_time()*clock.numer/clock.denom/1e9;
            double start=completed.GPUStartTime,finish=completed.GPUEndTime;
            // Creation-to-GPU includes CPU encoding and submission; it is not
            // an isolated queue wait. Retain the raw host-clock endpoints.
            fprintf(stderr,"Vox Metal command: created=%.9f gpu_start=%.9f gpu_end=%.9f completed=%.9f execution_us=%.3f before_gpu_us=%.3f after_gpu_us=%.3f status=%ld\n",
                created,start,finish,end,(finish-start)*1e6,(start-created)*1e6,(end-finish)*1e6,(long)completed.status);
        }
    }];
    return command;
}

// Graphite keeps this queue identity with its Context and compiled pipelines.
// Reuse its real Metal queue for a bounded window of completed frames, amortizing
// driver setup while bounding retained per-queue storage. The owner must finish
// all work before counting or retiring a frame. Command buffers retain their
// real queue independently; only owned CPU pixels cross the readback bridge.
@interface VoxFrameMetalQueue : NSObject <MTLCommandQueue> {
    id<MTLDevice> device_;
    id<MTLCommandQueue> queue_;
    NSString* label_;
    unsigned completed_frames_;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
    NSMutableSet* residency_sets_;
#endif
}
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (BOOL)retireCompletedQueue;
- (BOOL)finishCompletedFrame;
- (BOOL)willRetireAfterFrame;
@end

@implementation VoxFrameMetalQueue
- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if ((self = [super init])) device_ = [device retain];
    return self;
}
- (void)dealloc {
    [queue_ release];
    [label_ release];
    [device_ release];
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
    [residency_sets_ release];
#endif
    [super dealloc];
}
- (id<MTLDevice>)device { return device_; }
- (NSString*)label {
    @synchronized(self) { return [[label_ retain] autorelease]; }
}
- (void)setLabel:(NSString*)label {
    NSString* owned = [label copy];
    @synchronized(self) {
        [label_ release];
        label_ = owned;
        queue_.label = label_;
    }
}
// Called under the receiver lock. Return a borrowed queue: adding an
// autorelease here would extend it beyond the queue retirement boundary.
- (id<MTLCommandQueue>)currentQueue {
    if (!queue_) {
#ifdef VOX_METAL_QUEUE_DIAGNOSTICS
        uint64_t before = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        queue_ = [device_ newCommandQueue];
#ifdef VOX_METAL_QUEUE_DIAGNOSTICS
        fprintf(stderr, "VOX_METAL_QUEUE_CREATE us=%g\n", (clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - before) / 1000.0);
#endif
        queue_.label = label_;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
        if (@available(macOS 15.0, *)) {
            for (id<MTLResidencySet> set in residency_sets_) [queue_ addResidencySet:set];
        }
#endif
    }
    return queue_;
}
- (id<MTLCommandBuffer>)commandBuffer {
    @synchronized(self) { return vox_metal_time_command([[self currentQueue] commandBuffer]); }
}
- (id<MTLCommandBuffer>)commandBufferWithUnretainedReferences {
    @synchronized(self) { return vox_metal_time_command([[self currentQueue] commandBufferWithUnretainedReferences]); }
}
- (id<MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor*)descriptor {
    @synchronized(self) { return vox_metal_time_command([[self currentQueue] commandBufferWithDescriptor:descriptor]); }
}
- (void)insertDebugCaptureBoundary {
    @synchronized(self) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [queue_ insertDebugCaptureBoundary];
#pragma clang diagnostic pop
    }
}
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
- (void)addResidencySet:(id<MTLResidencySet>)set API_AVAILABLE(macos(15.0)) {
    @synchronized(self) {
        if (!residency_sets_) residency_sets_ = [[NSMutableSet alloc] init];
        if (![residency_sets_ containsObject:set]) {
            [residency_sets_ addObject:set];
            [queue_ addResidencySet:set];
        }
    }
}
- (void)addResidencySets:(const id<MTLResidencySet>[])sets count:(NSUInteger)count API_AVAILABLE(macos(15.0)) {
    @synchronized(self) {
        for (NSUInteger i = 0; i < count; ++i) [self addResidencySet:sets[i]];
    }
}
- (void)removeResidencySet:(id<MTLResidencySet>)set API_AVAILABLE(macos(15.0)) {
    @synchronized(self) {
        [residency_sets_ removeObject:set];
        [queue_ removeResidencySet:set];
    }
}
- (void)removeResidencySets:(const id<MTLResidencySet>[])sets count:(NSUInteger)count API_AVAILABLE(macos(15.0)) {
    @synchronized(self) {
        for (NSUInteger i = 0; i < count; ++i) [self removeResidencySet:sets[i]];
    }
}
#endif
- (BOOL)willRetireAfterFrame {
    @synchronized(self) { return queue_ && completed_frames_ + 1 >= VOX_METAL_QUEUE_FRAME_LIMIT; }
}
// Keep a bounded number of completed frames on one real queue. Explicit
// retirement and destruction still release it immediately, including on idle.
- (BOOL)finishCompletedFrame {
    @synchronized(self) {
        if (!queue_) return NO;
        if (++completed_frames_ < VOX_METAL_QUEUE_FRAME_LIMIT) return NO;
        return [self retireCompletedQueue];
    }
}
- (BOOL)retireCompletedQueue {
    @synchronized(self) {
        BOOL existed = queue_ != nil;
#ifdef VOX_METAL_QUEUE_DIAGNOSTICS
        uint64_t before = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
#endif
        [queue_ release];
#ifdef VOX_METAL_QUEUE_DIAGNOSTICS
        fprintf(stderr, "VOX_METAL_QUEUE_RETIRE us=%g frames=%u\n", (clock_gettime_nsec_np(CLOCK_UPTIME_RAW) - before) / 1000.0, completed_frames_);
#endif
        queue_ = nil;
        completed_frames_ = 0;
        return existed;
    }
}
@end
#endif
