#ifndef VOX_NATIVE_FRAME_PUBLICATION_DARWIN_H
#define VOX_NATIVE_FRAME_PUBLICATION_DARWIN_H
#include "native_document_submission_darwin.h"
#include "native_scroll_tile_presentation_darwin.h"

// Immutable output of one main-thread paint. Only the scheduling fence is
// consumed off-main; NSView, layer installation and V callbacks stay on-main.
@interface VoxNativePreparedFrame : NSObject {
@public
    CGImageRef image;
    CFTypeRef tiles;
    NativeDocumentSubmissionFrame submission;
    NSRect bounds;
    CGFloat scale;
    uint64_t generation, epoch;
    double preparation_started;
}
@end

typedef void (*VoxNativeFramePreparedObserver)(void *, uint64_t, double);
typedef void (*VoxNativeFramePublishedObserver)(void *, uint64_t);
VOX_NATIVE_STATE VoxNativeFramePreparedObserver native_frame_prepared_observer;
VOX_NATIVE_STATE VoxNativeFramePublishedObserver native_frame_published_observer;

// Public runtime capability for observers. A queued frame is not a publication.
@interface VoxNativeFramePublication : NSObject {
@public
    VoxNativePreparedFrame *pending;
    BOOL working;
    uint64_t epoch, latest_generation, latest_token;
    NSRect latest_bounds;
    CGFloat latest_scale;
}
+ (unsigned)observerProtocol;
+ (void)observePrepared:(VoxNativeFramePreparedObserver)prepared
              published:(VoxNativeFramePublishedObserver)published;
@end

#if !defined(V_PARALLEL_CC) || defined(V_PARALLEL_CC_OUT_0)
@implementation VoxNativePreparedFrame
- (void)dealloc {
    if (image) CGImageRelease(image);
    if (tiles) CFRelease(tiles);
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}
@end
@implementation VoxNativeFramePublication
+ (unsigned)observerProtocol { return 1; }
+ (void)observePrepared:(VoxNativeFramePreparedObserver)prepared
              published:(VoxNativeFramePublishedObserver)published {
    NSCAssert(NSThread.isMainThread, @"Frame observers belong to the main thread");
    native_frame_prepared_observer = prepared;
    native_frame_published_observer = published;
}
- (void)dealloc {
#if !__has_feature(objc_arc)
    [pending release];
    [super dealloc];
#endif
}
@end
#endif

VOX_NATIVE_STATE char native_frame_publication_key;
static VoxNativeFramePublication *native_frame_publication_state(NSView *view, BOOL create) {
    VoxNativeFramePublication *state = objc_getAssociatedObject(view, &native_frame_publication_key);
    if (!state && create) {
        state = [[VoxNativeFramePublication alloc] init];
        objc_setAssociatedObject(view, &native_frame_publication_key, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#if !__has_feature(objc_arc)
        [state release];
#endif
    }
    return state;
}
static void native_frame_publication_set_pending(VoxNativeFramePublication *state,
    VoxNativePreparedFrame *frame) {
#if !__has_feature(objc_arc)
    [frame retain];
    [state->pending release];
#endif
    state->pending = frame;
}
// Resize, capture and a synchronous replacement invalidate both queued and
// in-flight work. Its immutable resources live until the fence consumer exits.
static void native_frame_publication_cancel(NSView *view) {
    VoxNativeFramePublication *state = native_frame_publication_state(view, NO);
    if (state) {
        ++state->epoch;
        state->latest_token = 0;
        native_frame_publication_set_pending(state, nil);
    }
}
static BOOL native_frame_publication_covers(NSView *view, uint64_t generation, CGFloat scale) {
    VoxNativeFramePublication *state = native_frame_publication_state(view, NO);
    return state && state->working && state->latest_token
        && state->latest_generation == generation && state->latest_scale == scale
        && NSEqualRects(state->latest_bounds, view.bounds);
}

typedef void (*VoxNativeFrameCompletion)(NSView *, VoxNativePreparedFrame *, BOOL);
typedef BOOL (*VoxNativeFrameCanComplete)(void);
static void native_frame_publication_drain(NSView *, VoxNativeFramePublication *,
    VoxNativeFrameCompletion, VoxNativeFrameCanComplete);
static void native_frame_publication_finish(NSView *view, VoxNativeFramePublication *state,
    VoxNativePreparedFrame *frame, BOOL ready, double wait,
    VoxNativeFrameCompletion complete, VoxNativeFrameCanComplete can_complete) {
    if (frame->epoch == state->epoch && !can_complete()) {
        // Cooperative document work may pump the main run loop during paint.
        // Do not publish or invoke a V callback from inside that preparation.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            native_frame_publication_finish(view,state,frame,ready,wait,complete,can_complete);
        });
        return;
    }
    if (frame->epoch == state->epoch) complete(view, frame, ready);
    if (getenv("VOX_GPU_FRAME_QUEUE_DIAGNOSTICS")) {
        double (*clock)(void) = (double (*)(void))dlsym(RTLD_DEFAULT,"vox_precise_scroll_diagnostic_time");
        fprintf(stderr,"VOX_GPU_FRAME_QUEUE token=%llu ready=%d current=%d wait_us=%.3f t_us=%.3f\n",
            (unsigned long long)frame->submission.token, ready,
            frame->epoch == state->epoch, wait * 1e6, clock ? clock() : -1);
    }
    state->working = NO;
    native_frame_publication_drain(view, state, complete, can_complete);
}
static void native_frame_publication_drain(NSView *view, VoxNativeFramePublication *state,
    VoxNativeFrameCompletion complete, VoxNativeFrameCanComplete can_complete) {
    if (state->working || !state->pending) return;
    VoxNativePreparedFrame *frame = state->pending;
#if !__has_feature(objc_arc)
    [frame retain];
#endif
    native_frame_publication_set_pending(state, nil);
    state->working = YES;
    // Each view has at most one in-flight wait and one replaceable pending
    // frame. No unbounded dispatch backlog or lock held across a GPU wait.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        @autoreleasepool {
            double started = CACurrentMediaTime();
            BOOL ready = native_scroll_tiles_ready((__bridge VoxScrollTileFrame *)frame->tiles, "readiness-worker");
            double wait = CACurrentMediaTime() - started;
            dispatch_async(dispatch_get_main_queue(), ^{
                native_frame_publication_finish(view,state,frame,ready,wait,complete,can_complete);
            });
        }
    });
#if !__has_feature(objc_arc)
    [frame release];
#endif
}
static void native_frame_publication_enqueue(NSView *view, VoxNativePreparedFrame *frame,
    VoxNativeFrameCompletion complete, VoxNativeFrameCanComplete can_complete) {
    NSCAssert(NSThread.isMainThread, @"Only frame readiness leaves the main thread");
    VoxNativeFramePublication *state = native_frame_publication_state(view, YES);
    frame->epoch = state->epoch;
    state->latest_generation = frame->generation;
    state->latest_token = frame->submission.token;
    state->latest_bounds = frame->bounds;
    state->latest_scale = frame->scale;
    native_frame_publication_set_pending(state, frame);
    native_frame_publication_drain(view, state, complete, can_complete);
}
#endif
