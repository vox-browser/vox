#import "../native_history_swipe_darwin.h"
#include <assert.h>
#include <stdio.h>

// AppKit supplies gesture progress asynchronously. Keep that boundary explicit
// so cancellation, reversal and callbacks after teardown are deterministic.
@interface VoxHistorySwipeTestEvent : NSObject
@property NSWindow *window;
@property NSEventType type;
@property NSEventPhase phase;
@property NSEventPhase momentumPhase;
@property BOOL hasPreciseScrollingDeltas;
@property NSEventModifierFlags modifierFlags;
@property CGFloat scrollingDeltaX;
@property CGFloat scrollingDeltaY;
@property NSPoint locationInWindow;
@property(copy) void (^handler)(CGFloat, NSEventPhase, BOOL, BOOL *);
@property NSEventSwipeTrackingOptions options;
@property CGFloat minimum;
@property CGFloat maximum;
@end
@implementation VoxHistorySwipeTestEvent
- (void)trackSwipeEventWithOptions:(NSEventSwipeTrackingOptions)options
    dampenAmountThresholdMin:(CGFloat)minimum max:(CGFloat)maximum
    usingHandler:(void (^)(CGFloat, NSEventPhase, BOOL, BOOL *))handler {
    self.options = options;
    self.minimum = minimum;
    self.maximum = maximum;
    self.handler = handler;
}
@end

typedef struct { int begins, commits, result, decision, phases, delta; double x, y; uint64_t generation; } Observation;
static int document;
static int32_t begin(void *owner, int32_t delta, double x, double y, double dx, double dy, void **token) {
    Observation *observation=owner;
    assert(dx==12 && dy==0);
    observation->begins++; observation->delta=delta; observation->x=x; observation->y=y;
    *token=&document; return observation->result;
}
static int32_t classify(void *owner, int32_t phase, int32_t momentum, int32_t precise, int32_t enabled,
    uint32_t modifiers, double x, double y) {
    Observation *observation=owner;
    assert(phase==1 && !momentum && precise && enabled && modifiers==0 && x==12 && y==0);
    observation->phases++; return observation->decision;
}
static uint64_t capture(void *owner, uint64_t expected) { assert(expected==0 || expected==42); return ((Observation *)owner)->generation; }
static int32_t complete(void *owner, void *token, uint64_t generation, double amount, int32_t phase, int32_t done, int32_t delta) {
    Observation *observation=owner;
    assert(token==&document && generation==42 && amount==1 && phase==3 && done && delta==-1);
    observation->commits++; return 1;
}
static VoxHistorySwipeTestEvent *wheel(NSWindow *window, CGFloat dx, CGFloat dy,
    NSEventPhase phase) {
    VoxHistorySwipeTestEvent *event = [VoxHistorySwipeTestEvent new];
    event.window = window;
    event.type = NSEventTypeScrollWheel;
    event.phase = phase;
    event.hasPreciseScrollingDeltas = YES;
    event.scrollingDeltaX = dx;
    event.scrollingDeltaY = dy;
    event.locationInWindow = NSMakePoint(100, 350);
    return event;
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600)
        styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;
    Observation observation={.result=2,.decision=-2,.generation=42};
    native_history_swipe_install((__bridge void *)window,&observation,begin,classify,capture,complete);
    VoxHistorySwipe *state=vox_history_swipe;
    assert(state.installed && state.monitor);
    VoxHistorySwipeTestEvent *event=wheel(window,12,0,NSEventPhaseBegan);
    assert(native_history_swipe_deliver(state,(NSEvent *)event,YES,begin,classify,capture,complete)==nil);
    assert(observation.begins==1 && observation.phases==1 && observation.delta==-1);
    assert(observation.x==100 && observation.y==250 && event.handler);
    BOOL stop=NO;
    event.handler(1,NSEventPhaseEnded,YES,&stop);
    assert(stop && observation.commits==1);
    native_history_swipe_remove();
    assert(!state.installed && !state.monitor && !vox_history_swipe);
    stop=NO; event.handler(1,NSEventPhaseEnded,YES,&stop);
    assert(stop && observation.commits==1);
    assert(native_history_swipe_deliver(state,(NSEvent *)event,YES,begin,classify,capture,complete)==(NSEvent *)event);
    native_history_swipe_remove();
    [window close];
    puts("PASS native gesture normalization, callback routing and teardown; V policy tested in browserui");
} return 0; }
