#include "../native_frame_metal_queue.h"
#include <cassert>
#include <cstdio>

static int created, destroyed, factory_destroyed, commands;
static id last_queue;

// A CPU-only factory exposes queue ownership without depending on GPU timing.
@interface VoxTestMetalQueue : NSObject {
    NSString* label_;
    NSMutableSet* residency_;
}
@property(copy) NSString* label;
@property(readonly) NSUInteger residencyCount;
@end
@implementation VoxTestMetalQueue
- (instancetype)init {
    if ((self = [super init])) { ++created; last_queue = self; residency_ = [[NSMutableSet alloc] init]; }
    return self;
}
- (void)dealloc {
    ++destroyed;
    if (last_queue == self) last_queue = nil;
    [label_ release]; [residency_ release]; [super dealloc];
}
- (NSString*)label { return label_; }
- (void)setLabel:(NSString*)label { NSString* owned = [label copy]; [label_ release]; label_ = owned; }
- (id)commandBuffer { ++commands; return nil; }
- (id)commandBufferWithUnretainedReferences { ++commands; return nil; }
- (id)commandBufferWithDescriptor:(MTLCommandBufferDescriptor*)descriptor {
    (void)descriptor; ++commands; return nil;
}
- (void)insertDebugCaptureBoundary {}
- (void)addResidencySet:(id)set { [residency_ addObject:set]; }
- (void)removeResidencySet:(id)set { [residency_ removeObject:set]; }
- (NSUInteger)residencyCount { return residency_.count; }
@end

@interface VoxTestMetalQueueFactory : NSObject
- (id<MTLCommandQueue>)newCommandQueue;
@end
@implementation VoxTestMetalQueueFactory
- (id<MTLCommandQueue>)newCommandQueue { return (id<MTLCommandQueue>)[[VoxTestMetalQueue alloc] init]; }
- (void)dealloc { ++factory_destroyed; [super dealloc]; }
@end

int main()
{
    @autoreleasepool {
        auto* factory = [[VoxTestMetalQueueFactory alloc] init];
        auto* queue = [[VoxFrameMetalQueue alloc] initWithDevice:(id<MTLDevice>)factory];
        [factory release];
        assert(!factory_destroyed && queue.device == (id<MTLDevice>)factory);
        auto* label = [[NSMutableString alloc] initWithString:@"owned label"];
        queue.label = label;
        [label appendString:@" changed"];
        [label release];
        assert([queue.label isEqualToString:@"owned label"] && created == 0);
        assert(![queue retireCompletedQueue] && created == 0);
        [queue commandBuffer];
        assert(created == 1 && commands == 1);
        assert([[last_queue label] isEqualToString:@"owned label"]);
        [queue commandBufferWithUnretainedReferences];
        [queue commandBufferWithDescriptor:[[MTLCommandBufferDescriptor new] autorelease]];
        assert(created == 1 && commands == 3);
        assert([queue retireCompletedQueue] && destroyed == 1 && !last_queue);
        assert(![queue retireCompletedQueue] && created == 1);
        // Self-assignment must copy before releasing the preceding label.
        queue.label = queue.label;
        [queue commandBuffer];
        assert(created == 2 && [[last_queue label] isEqualToString:@"owned label"]);
        assert([queue retireCompletedQueue] && destroyed == 2);
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 150000
        if (@available(macOS 15.0, *)) {
            id<MTLResidencySet> sets[] {(id<MTLResidencySet>)[NSObject new], (id<MTLResidencySet>)[NSObject new]};
            [queue addResidencySets:sets count:2];
            [queue addResidencySet:sets[0]];
            assert(created == 2); // Registering resources need not create a queue.
            [queue commandBuffer];
            assert(created == 3 && [last_queue residencyCount] == 2);
            [queue removeResidencySet:sets[0]];
            assert([last_queue residencyCount] == 1);
            assert([queue retireCompletedQueue] && destroyed == 3);
            [queue commandBuffer];
            assert(created == 4 && [last_queue residencyCount] == 1);
            [queue removeResidencySets:sets count:2];
            assert([last_queue residencyCount] == 0);
            assert([queue retireCompletedQueue]);
            [queue commandBuffer];
            assert(created == 5 && [last_queue residencyCount] == 0);
            [sets[0] release]; [sets[1] release];
        }
#endif
        [queue release];
        assert(destroyed == created && factory_destroyed == 1 && !last_queue);
    }
    std::puts("Metal frame queue: lazy creation, immediate ownership release, labels and residency sets passed");
}
