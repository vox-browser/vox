#pragma once
#include <Cocoa/Cocoa.h>
#include <math.h>

typedef int (*VoxHistorySwipeBegin)(void *, int, double, double, double, double, void **);
typedef void (*VoxHistorySwipeCommit)(void *, void *, int);

@interface VoxHistorySwipe : NSObject
@property(nonatomic, weak) NSWindow *window;
@property(nonatomic) void *owner;
@property(nonatomic) VoxHistorySwipeBegin begin;
@property(nonatomic) VoxHistorySwipeCommit commit;
@property(nonatomic, strong) id monitor;
@property(nonatomic) BOOL installed;
@property(nonatomic) BOOL undecided;
@property(nonatomic) BOOL captured;
@property(nonatomic) BOOL tracking;
@property(nonatomic) NSUInteger generation;
@end
@implementation VoxHistorySwipe
@end

static VoxHistorySwipe *vox_history_swipe;

static NSEvent *native_history_swipe_filter(VoxHistorySwipe *state, NSEvent *event,
    BOOL enabled) {
    if (!state.installed || event.type != NSEventTypeScrollWheel
        || !state.window || event.window != state.window) return event;

    if (event.phase & NSEventPhaseBegan) {
        state.generation++;
        state.undecided = YES;
        state.captured = NO;
        state.tracking = NO;
    }
    if (event.phase == NSEventPhaseNone && event.momentumPhase == NSEventPhaseNone) {
        state.generation++;
        state.undecided = NO;
        state.captured = NO;
        state.tracking = NO;
        return event; // A mouse wheel after a swipe remains ordinary scrolling.
    }
    // Momentum belongs to the gesture that produced it, never a new swipe.
    if (state.captured) {
        // AppKit must see subsequent events while its asynchronous tracker is
        // active. Once complete, swallow the captured gesture's momentum tail.
        return state.tracking ? event : nil;
    }
    if (event.momentumPhase != NSEventPhaseNone) {
        state.undecided = NO;
        return event;
    }
    if (!enabled || !event.hasPreciseScrollingDeltas
        || (event.modifierFlags & (NSEventModifierFlagShift | NSEventModifierFlagControl
            | NSEventModifierFlagOption | NSEventModifierFlagCommand))
        || !(event.phase & (NSEventPhaseBegan | NSEventPhaseChanged))) {
        state.undecided = NO;
        return event;
    }
    if (!state.undecided) return event;
    CGFloat dx = event.scrollingDeltaX, dy = event.scrollingDeltaY;
    if (dx == 0 && dy == 0) return event;
    state.undecided = NO;
    // Lock ordinary vertical/diagonal scrolling for the rest of this gesture.
    if (fabs(dx) <= 2 * fabs(dy)) return event;

    NSView *content = state.window.contentView;
    NSPoint point = [content convertPoint:event.locationInWindow fromView:nil];
    double x = point.x - NSMinX(content.bounds);
    double y = content.isFlipped ? point.y - NSMinY(content.bounds)
        : NSMaxY(content.bounds) - point.y;
    int delta = dx > 0 ? -1 : 1;
    void *document = NULL;
    NSUInteger generation = state.generation;
    int result = state.begin(state.owner, delta, x, y, dx, dy, &document);
    if (result == 0) return event;
    if (result != 2 || !document || !state.installed || state.generation != generation)
        return nil;

    state.captured = YES;
    state.tracking = YES;
    [event trackSwipeEventWithOptions:NSEventSwipeTrackingLockDirection
            | NSEventSwipeTrackingClampGestureAmount
        dampenAmountThresholdMin:delta > 0 ? -1 : 0
        max:delta < 0 ? 1 : 0
        usingHandler:^(CGFloat amount, NSEventPhase phase, BOOL complete, BOOL *stop) {
            if (!state.installed || state.generation != generation || !state.tracking
                || !state.window) {
                *stop = YES;
                return;
            }
            if (phase & NSEventPhaseCancelled) {
                state.tracking = NO;
                *stop = YES;
                return;
            }
            if (!complete) return;
            state.tracking = NO;
            if ((delta < 0 && amount > 0.5) || (delta > 0 && amount < -0.5))
                state.commit(state.owner, document, delta);
        }];
    return nil;
}

static void native_history_swipe_remove(void) {
    VoxHistorySwipe *state = vox_history_swipe;
    state.installed = NO;
    if (state.monitor) [NSEvent removeMonitor:state.monitor];
    state.monitor = nil;
    vox_history_swipe = nil;
}

static void native_history_swipe_install(void *window, void *owner,
    VoxHistorySwipeBegin begin, VoxHistorySwipeCommit commit) {
    native_history_swipe_remove();
    if (!window || !owner || !begin || !commit) return;
    VoxHistorySwipe *state = [VoxHistorySwipe new];
    state.window = (__bridge NSWindow *)window;
    state.owner = owner;
    state.begin = begin;
    state.commit = commit;
    state.installed = YES;
    state.monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel
        handler:^NSEvent *(NSEvent *event) {
            return native_history_swipe_filter(state, event,
                [NSEvent isSwipeTrackingFromScrollEventsEnabled]);
        }];
    vox_history_swipe = state;
}
