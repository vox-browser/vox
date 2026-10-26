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

typedef struct { int begins, commits, result, delta; double x, y; } Observation;
static int document;
static int begin(void *owner, int delta, double x, double y, double dx, double dy,
    void **token) {
    Observation *observation = owner;
    observation->begins++;
    observation->delta = delta;
    observation->x = x;
    observation->y = y;
    assert(dx != 0 && fabs(dx) > 2 * fabs(dy));
    *token = &document;
    return observation->result;
}
static void commit(void *owner, void *token, int delta) {
    Observation *observation = owner;
    assert(token == &document && delta == observation->delta);
    observation->commits++;
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
static NSEvent *filter(VoxHistorySwipe *state, VoxHistorySwipeTestEvent *event) {
    return native_history_swipe_filter(state, (NSEvent *)event, YES);
}
static BOOL progress(VoxHistorySwipeTestEvent *event, CGFloat amount,
    NSEventPhase phase, BOOL complete) {
    assert(event.handler);
    BOOL stop = NO;
    event.handler(amount, phase, complete, &stop);
    return stop;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        // The test window is never ordered on screen.
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        Observation observation = {.result = 2};
        native_history_swipe_install((__bridge void *)window, &observation, begin, commit);
        VoxHistorySwipe *state = vox_history_swipe;
        assert(state.installed && state.monitor);

        VoxHistorySwipeTestEvent *back = wheel(window, 12, 1, NSEventPhaseBegan);
        assert(filter(state, back) == nil && observation.begins == 1);
        assert(observation.delta == -1 && observation.x == 100 && observation.y == 250);
        assert(back.minimum == 0 && back.maximum == 1);
        assert(back.options & NSEventSwipeTrackingLockDirection);
        assert(back.options & NSEventSwipeTrackingClampGestureAmount);
        VoxHistorySwipeTestEvent *changed = wheel(window, 20, 0, NSEventPhaseChanged);
        assert(filter(state, changed) == (NSEvent *)changed); // AppKit keeps tracking.
        progress(back, 0.3, NSEventPhaseChanged, NO);
        progress(back, 0.8, NSEventPhaseEnded, NO);
        assert(observation.commits == 0);
        progress(back, 1, NSEventPhaseNone, YES);
        assert(observation.commits == 1);
        assert(progress(back, 1, NSEventPhaseNone, YES));
        changed.momentumPhase = NSEventPhaseChanged;
        assert(filter(state, changed) == nil && observation.begins == 1);
        VoxHistorySwipeTestEvent *mouse = wheel(window, 0, 12, NSEventPhaseNone);
        mouse.hasPreciseScrollingDeltas = NO;
        assert(filter(state, mouse) == (NSEvent *)mouse);

        VoxHistorySwipeTestEvent *forward = wheel(window, -12, 0, NSEventPhaseBegan);
        assert(filter(state, forward) == nil && observation.delta == 1);
        assert(forward.minimum == -1 && forward.maximum == 0);
        progress(forward, -1, NSEventPhaseNone, YES);
        assert(observation.commits == 2);

        VoxHistorySwipeTestEvent *cancelled = wheel(window, 12, 0, NSEventPhaseBegan);
        filter(state, cancelled);
        assert(progress(cancelled, 0.8, NSEventPhaseCancelled, NO));
        progress(cancelled, 1, NSEventPhaseNone, YES);
        VoxHistorySwipeTestEvent *short_swipe = wheel(window, 12, 0, NSEventPhaseBegan);
        filter(state, short_swipe);
        progress(short_swipe, 0, NSEventPhaseNone, YES);
        VoxHistorySwipeTestEvent *reversed = wheel(window, 12, 0, NSEventPhaseBegan);
        filter(state, reversed);
        progress(reversed, -1, NSEventPhaseNone, YES);
        assert(observation.commits == 2);

        int begins = observation.begins;
        for (int kind = 0; kind < 7; ++kind) {
            VoxHistorySwipeTestEvent *ordinary = wheel(window, 12, 0, NSEventPhaseBegan);
            if (kind == 0) ordinary.hasPreciseScrollingDeltas = NO;
            if (kind == 1) ordinary.phase = NSEventPhaseNone;
            if (kind == 2) ordinary.momentumPhase = NSEventPhaseChanged;
            if (kind == 3) ordinary.modifierFlags = NSEventModifierFlagShift;
            if (kind == 4) ordinary.window = nil;
            if (kind == 5) ordinary.type = NSEventTypeMouseMoved;
            NSEvent *result = native_history_swipe_filter(state, (NSEvent *)ordinary, kind != 6);
            assert(result == (NSEvent *)ordinary);
        }
        assert(observation.begins == begins);
        VoxHistorySwipeTestEvent *vertical = wheel(window, 1, 12, NSEventPhaseBegan);
        assert(filter(state, vertical) == (NSEvent *)vertical);
        changed.momentumPhase = NSEventPhaseNone;
        assert(filter(state, changed) == (NSEvent *)changed && observation.begins == begins);
        VoxHistorySwipeTestEvent *diagonal = wheel(window, 12, 10, NSEventPhaseBegan);
        assert(filter(state, diagonal) == (NSEvent *)diagonal);

        // A zero-delta begin is normal on a real trackpad.
        VoxHistorySwipeTestEvent *zero = wheel(window, 0, 0, NSEventPhaseBegan);
        assert(filter(state, zero) == (NSEvent *)zero);
        assert(filter(state, changed) == nil && changed.handler);
        VoxHistorySwipeTestEvent *next = wheel(window, -12, 0, NSEventPhaseBegan);
        filter(state, next);
        assert(progress(changed, 1, NSEventPhaseNone, YES)); // Superseded tracker.
        assert(observation.commits == 2);
        progress(next, -1, NSEventPhaseNone, YES);
        assert(observation.commits == 3);

        observation.result = 1; // Wheel cancelled or consumed by page content.
        VoxHistorySwipeTestEvent *handled = wheel(window, 12, 0, NSEventPhaseBegan);
        assert(filter(state, handled) == nil && !handled.handler);
        changed.handler = nil;
        assert(filter(state, changed) == (NSEvent *)changed);
        observation.result = 0; // No history, chrome, or a busy browser.
        VoxHistorySwipeTestEvent *unavailable = wheel(window, 12, 0, NSEventPhaseBegan);
        assert(filter(state, unavailable) == (NSEvent *)unavailable && !unavailable.handler);

        observation.result = 2;
        VoxHistorySwipeTestEvent *closing = wheel(window, 12, 0, NSEventPhaseBegan);
        filter(state, closing);
        native_history_swipe_remove();
        assert(!vox_history_swipe && !state.installed && !state.monitor);
        assert(progress(closing, 1, NSEventPhaseNone, YES));
        assert(observation.commits == 3);
        assert(filter(state, closing) == (NSEvent *)closing);
        native_history_swipe_remove();
        puts("PASS native two-finger history swipes, cancellation, scrolling and teardown");
    }
    return 0;
}
