#ifndef VOX_NATIVE_FRAME_METAL_QUEUE_H
#define VOX_NATIVE_FRAME_METAL_QUEUE_H
#import <Metal/Metal.h>

// Graphite keeps this queue identity with its Context and compiled pipelines.
// Its real Metal queue is needed only while encoding/submitting a frame. The
// owner must complete all work before retiring it; command buffers retain their
// real queue independently. No GPU resources cross the CPU readback bridge.
@interface VoxFrameMetalQueue : NSObject <MTLCommandQueue> {
    id<MTLDevice> device_;
    id<MTLCommandQueue> queue_;
    NSString* label_;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
    NSMutableSet* residency_sets_;
#endif
}
- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (BOOL)retireCompletedQueue;
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
// autorelease here would extend it beyond the completed frame boundary.
- (id<MTLCommandQueue>)currentQueue {
    if (!queue_) {
        queue_ = [device_ newCommandQueue];
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
    @synchronized(self) { return [[self currentQueue] commandBuffer]; }
}
- (id<MTLCommandBuffer>)commandBufferWithUnretainedReferences {
    @synchronized(self) { return [[self currentQueue] commandBufferWithUnretainedReferences]; }
}
- (id<MTLCommandBuffer>)commandBufferWithDescriptor:(MTLCommandBufferDescriptor*)descriptor {
    @synchronized(self) { return [[self currentQueue] commandBufferWithDescriptor:descriptor]; }
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
- (BOOL)retireCompletedQueue {
    @synchronized(self) {
        BOOL existed = queue_ != nil;
        [queue_ release];
        queue_ = nil;
        return existed;
    }
}
@end
#endif
