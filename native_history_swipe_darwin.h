#pragma once
#include <Cocoa/Cocoa.h>
#include <stdint.h>
// Native event/gesture operations only; classification and navigation are V.
typedef int32_t (*VoxHistorySwipeBegin)(void *, int32_t, double, double, double, double, void **);
typedef int32_t (*VoxHistorySwipeFilter)(void *, int32_t, int32_t, int32_t, int32_t, uint32_t, double, double);
typedef uint64_t (*VoxHistorySwipeCapture)(void *, uint64_t);
typedef int32_t (*VoxHistorySwipeProgress)(void *, void *, uint64_t, double, int32_t, int32_t, int32_t);
@interface VoxHistorySwipe : NSObject
@property(nonatomic,weak) NSWindow *window;
@property(nonatomic) void *owner;
@property(nonatomic,strong) id monitor;
@property(nonatomic) BOOL installed;
@end
@implementation VoxHistorySwipe
@end
static VoxHistorySwipe *vox_history_swipe;
static int32_t native_swipe_phase(NSEventPhase phase) {
    if (phase & NSEventPhaseBegan) return 1;
    if (phase & NSEventPhaseChanged) return 2;
    if (phase & NSEventPhaseEnded) return 3;
    if (phase & NSEventPhaseCancelled) return 4;
    return phase==NSEventPhaseNone ? 0 : 5;
}
static void native_history_swipe_remove(void) {
    vox_history_swipe.installed=NO;
    if (vox_history_swipe.monitor) [NSEvent removeMonitor:vox_history_swipe.monitor];
    vox_history_swipe.monitor=nil;
    vox_history_swipe=nil;
}
static NSEvent *native_history_swipe_deliver(VoxHistorySwipe *state, NSEvent *event, BOOL enabled,
    VoxHistorySwipeBegin begin, VoxHistorySwipeFilter filter, VoxHistorySwipeCapture capture, VoxHistorySwipeProgress progress) {
        if (!state.installed || event.type!=NSEventTypeScrollWheel || event.window!=state.window || !state.window) return event;
        NSEventModifierFlags flags=event.modifierFlags;
        uint32_t modifiers=((flags & NSEventModifierFlagShift)?1:0)|((flags & NSEventModifierFlagControl)?2:0)
            |((flags & NSEventModifierFlagOption)?4:0)|((flags & NSEventModifierFlagCommand)?8:0);
        int32_t decision=filter(state.owner,native_swipe_phase(event.phase),event.momentumPhase!=NSEventPhaseNone,
            event.hasPreciseScrollingDeltas,enabled,modifiers,event.scrollingDeltaX,event.scrollingDeltaY);
        if (decision==0) return event;
        if (decision==1) return nil;
        NSView *content=state.window.contentView;
        NSPoint point=[content convertPoint:event.locationInWindow fromView:nil];
        double x=point.x-NSMinX(content.bounds), y=content.isFlipped ? point.y-NSMinY(content.bounds) : NSMaxY(content.bounds)-point.y;
        int32_t delta=decision<0 ? -1 : 1;
        void *document=NULL;
        uint64_t candidate=capture(state.owner,0);
        int32_t result=begin(state.owner,delta,x,y,event.scrollingDeltaX,event.scrollingDeltaY,&document);
        if (result==0) return event;
        if (result!=2 || !document || !state.installed) return nil;
        uint64_t generation=capture(state.owner,candidate);
        if (!generation) return nil;
        [event trackSwipeEventWithOptions:NSEventSwipeTrackingLockDirection|NSEventSwipeTrackingClampGestureAmount
            dampenAmountThresholdMin:delta>0 ? -1 : 0 max:delta<0 ? 1 : 0
            usingHandler:^(CGFloat amount,NSEventPhase phase,BOOL complete,BOOL *stop) {
                if (!state.installed || !state.window) { *stop=YES; return; }
                *stop=progress(state.owner,document,generation,amount,native_swipe_phase(phase),complete,delta)!=0;
            }];
        return nil;
}
static void native_history_swipe_install(void *window, void *owner, VoxHistorySwipeBegin begin,
    VoxHistorySwipeFilter filter, VoxHistorySwipeCapture capture, VoxHistorySwipeProgress progress) {
    native_history_swipe_remove();
    if (!window || !owner) return;
    VoxHistorySwipe *state=[VoxHistorySwipe new];
    state.window=(__bridge NSWindow *)window; state.owner=owner; state.installed=YES;
    state.monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel handler:^NSEvent *(NSEvent *event) {
        return native_history_swipe_deliver(state,event,[NSEvent isSwipeTrackingFromScrollEventsEnabled],begin,filter,capture,progress);
    }];
    vox_history_swipe=state;
}
