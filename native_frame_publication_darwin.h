#ifndef VOX_NATIVE_FRAME_PUBLICATION_DARWIN_H
#define VOX_NATIVE_FRAME_PUBLICATION_DARWIN_H
#include "native_document_submission_darwin.h"
#include "native_scroll_tile_presentation_darwin.h"

// Owned output of one main-thread paint, with immutable pixels and identity.
// The worker records readiness; NSView, installation and V callbacks stay on-main.
@interface VoxNativePreparedFrame : NSObject {
@public
    CGImageRef image;
    CFTypeRef tiles;
    NativeDocumentSubmissionFrame submission;
    NSRect bounds;
    CGFloat scale;
    uint64_t generation, epoch;
    double preparation_started, readiness_wait;
    BOOL ready;
}
@end

typedef void (*VoxNativeFramePreparedObserver)(void *, uint64_t, double);
typedef void (*VoxNativeFramePublishedObserver)(void *, uint64_t);
VOX_NATIVE_STATE VoxNativeFramePreparedObserver native_frame_prepared_observer;
VOX_NATIVE_STATE VoxNativeFramePublishedObserver native_frame_published_observer;
VOX_NATIVE_STATE char native_frame_publication_notification_key;
VOX_NATIVE_STATE NSMutableArray *native_frame_publication_notifications;

// Revisions installed during a cooperative pump belong to the surrounding
// view paint. Report only its final contents, after that paint finishes; several
// nested layer writes must never manufacture several scrolling publications.
static void native_frame_publication_notify(NSView *view, uint64_t token, BOOL painting) {
    if (!native_frame_published_observer) return;
    if (painting) {
        if (!native_frame_publication_notifications)
            native_frame_publication_notifications = [[NSMutableArray alloc] init];
        if (!objc_getAssociatedObject(view,&native_frame_publication_notification_key))
            [native_frame_publication_notifications addObject:view];
        objc_setAssociatedObject(view,&native_frame_publication_notification_key,
            @(token),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        objc_setAssociatedObject(view,&native_frame_publication_notification_key,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        native_frame_published_observer((__bridge void *)view,token);
    }
}
static void native_frame_publication_flush_notifications(void) {
    NSArray *views = [native_frame_publication_notifications copy];
    [native_frame_publication_notifications removeAllObjects];
    for (NSView *view in views) {
        uint64_t token = [objc_getAssociatedObject(view,&native_frame_publication_notification_key) unsignedLongLongValue];
        objc_setAssociatedObject(view,&native_frame_publication_notification_key,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (token && native_frame_published_observer)
            native_frame_published_observer((__bridge void *)view,token);
    }
#if !__has_feature(objc_arc)
    [views release];
#endif
}

// Public runtime capability for observers. A queued frame is not a publication.
@interface VoxNativeFramePublication : NSObject {
@public
    VoxNativePreparedFrame *pending, *completed;
    BOOL working, delivery_scheduled, failed;
    uint64_t epoch, latest_generation, latest_token;
    NSRect latest_bounds;
    CGFloat latest_scale;
    double work_submitted;
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
+ (unsigned)observerProtocol { return 2; }
+ (void)observePrepared:(VoxNativeFramePreparedObserver)prepared
              published:(VoxNativeFramePublishedObserver)published {
    NSCAssert(NSThread.isMainThread, @"Frame observers belong to the main thread");
    for (NSView *view in native_frame_publication_notifications)
        objc_setAssociatedObject(view,&native_frame_publication_notification_key,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [native_frame_publication_notifications removeAllObjects];
    native_frame_prepared_observer = prepared;
    native_frame_published_observer = published;
}
- (void)dealloc {
#if !__has_feature(objc_arc)
    [pending release];
    [completed release];
    [super dealloc];
#endif
}
@end
#endif

VOX_NATIVE_STATE char native_frame_publication_key;
VOX_NATIVE_STATE dispatch_queue_t native_frame_readiness_queue;
VOX_NATIVE_STATE dispatch_once_t native_frame_readiness_once;
static dispatch_queue_t native_frame_publication_queue(void) {
    if (getenv("VOX_GPU_FRAME_GLOBAL_QUEUE"))
        return dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE,0);
    dispatch_once(&native_frame_readiness_once, ^{
        // Serial queues use an overcommit root rather than sharing the global
        // concurrent pool with unrelated jobs blocked on driver callbacks.
        native_frame_readiness_queue = dispatch_queue_create("org.vox.gpu-frame-readiness",
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_USER_INTERACTIVE,0));
    });
    return native_frame_readiness_queue;
}
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
// Every mailbox access uses this short monitor. GPU waits, layer operations,
// observer/V callbacks and run-loop delivery happen outside it.
static void native_frame_publication_set_pending(VoxNativeFramePublication *state,
    VoxNativePreparedFrame *frame) {
#if !__has_feature(objc_arc)
    [frame retain];
    [state->pending release];
#endif
    state->pending = frame;
}
static void native_frame_publication_set_completed(VoxNativeFramePublication *state,
    VoxNativePreparedFrame *frame) {
#if !__has_feature(objc_arc)
    [frame retain];
    [state->completed release];
#endif
    state->completed = frame;
}
static void native_frame_publication_cancel(NSView *view) {
    VoxNativeFramePublication *state = native_frame_publication_state(view, NO);
    if (state) @synchronized(state) {
        ++state->epoch;
        state->failed = NO;
        state->latest_token = 0;
        native_frame_publication_set_pending(state, nil);
        native_frame_publication_set_completed(state, nil);
    }
}
static BOOL native_frame_publication_busy(NSView *view) {
    VoxNativeFramePublication *state = native_frame_publication_state(view, NO);
    if (!state) return NO;
    @synchronized(state) {
        return state->working || state->pending || state->completed || state->delivery_scheduled;
    }
}
static BOOL native_frame_publication_covers(NSView *view, uint64_t generation, CGFloat scale) {
    VoxNativeFramePublication *state = native_frame_publication_state(view, NO);
    if (!state) return NO;
    NSRect bounds = view.bounds;
    @synchronized(state) {
        return (state->working || state->completed || state->delivery_scheduled) && state->latest_token
            && state->latest_generation == generation && state->latest_scale == scale
            && NSEqualRects(state->latest_bounds, bounds);
    }
}

typedef void (*VoxNativeFrameCompletion)(NSView *, VoxNativePreparedFrame *, BOOL);
typedef BOOL (*VoxNativeFrameCanComplete)(void);
static void native_frame_publication_deliver(NSView *view, VoxNativeFramePublication *state,
    VoxNativeFrameCompletion complete, VoxNativeFrameCanComplete can_complete) {
    if (!can_complete()) {
        @synchronized(state) {
            if (!state->completed) { state->delivery_scheduled = NO; return; }
        }
        // Keep a single notification while cooperative paint pumps the loop.
        // The worker can replace completed output with a newer ready frame.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            native_frame_publication_deliver(view,state,complete,can_complete);
        });
        return;
    }
    VoxNativePreparedFrame *frame = nil;
    BOOL current = NO;
    @synchronized(state) {
        frame = state->completed;
#if !__has_feature(objc_arc)
        [frame retain];
#endif
        native_frame_publication_set_completed(state, nil);
        state->delivery_scheduled = NO;
        current = frame && frame->epoch == state->epoch;
    }
    if (current) complete(view,frame,frame->ready);
    if (frame && getenv("VOX_GPU_FRAME_QUEUE_DIAGNOSTICS")) {
        double (*clock)(void) = (double (*)(void))dlsym(RTLD_DEFAULT,"vox_precise_scroll_diagnostic_time");
        fprintf(stderr,"VOX_GPU_FRAME_QUEUE token=%llu ready=%d current=%d wait_us=%.3f t_us=%.3f\n",
            (unsigned long long)frame->submission.token, frame->ready, current,
            frame->readiness_wait * 1e6, clock ? clock() : -1);
    }
#if !__has_feature(objc_arc)
    [frame release];
#endif
}
static void native_frame_publication_work(NSView *view, VoxNativeFramePublication *state,
    VoxNativeFrameCompletion complete, VoxNativeFrameCanComplete can_complete) {
    if (getenv("VOX_GPU_FRAME_QUEUE_DIAGNOSTICS")) {
        double submitted;
        @synchronized(state) { submitted = state->work_submitted; }
        double (*clock)(void) = (double (*)(void))dlsym(RTLD_DEFAULT,"vox_precise_scroll_diagnostic_time");
        fprintf(stderr,"VOX_GPU_WORKER_START global=%d dispatch_us=%.3f t_us=%.3f\n",
            getenv("VOX_GPU_FRAME_GLOBAL_QUEUE") != NULL,
            (CACurrentMediaTime()-submitted)*1e6, clock ? clock() : -1);
    }
    // Do not wait for main-queue installation to drain the next GPU fence.
    // The bounded mailbox holds one pending, one in-flight and one completed
    // frame; completed output is replaceable until the main queue takes it.
    for (;;) @autoreleasepool {
        VoxNativePreparedFrame *frame = nil;
        @synchronized(state) {
            frame = state->pending;
#if !__has_feature(objc_arc)
            [frame retain];
#endif
            native_frame_publication_set_pending(state, nil);
            if (!frame) { state->working = NO; return; }
        }
        double started = CACurrentMediaTime();
        frame->ready = native_scroll_tiles_ready((__bridge VoxScrollTileFrame *)frame->tiles,"readiness-worker");
        frame->readiness_wait = CACurrentMediaTime() - started;
        BOOL notify = NO;
        BOOL stop = NO;
        @synchronized(state) {
            if (frame->epoch == state->epoch) {
                native_frame_publication_set_completed(state,frame);
                if (!frame->ready) {
                    // A later successful wait cannot repair bytes lost by a
                    // failed producer. Preserve this rejection until main
                    // delivers CPU recovery; never replace it with newer GPU
                    // output which may depend on those missing pixels.
                    state->failed = stop = YES;
                    state->working = NO;
                    native_frame_publication_set_pending(state,nil);
                }
                if (!state->delivery_scheduled) state->delivery_scheduled = notify = YES;
            }
        }
        if (notify) dispatch_async(dispatch_get_main_queue(), ^{
            native_frame_publication_deliver(view,state,complete,can_complete);
        });
#if !__has_feature(objc_arc)
        [frame release];
#endif
        if (stop) return;
    }
}
static void native_frame_publication_enqueue(NSView *view, VoxNativePreparedFrame *frame,
    VoxNativeFrameCompletion complete, VoxNativeFrameCanComplete can_complete) {
    NSCAssert(NSThread.isMainThread, @"Only frame readiness leaves the main thread");
    NSCAssert(!frame->submission.callback, @"Borrowed document submissions publish synchronously");
    VoxNativeFramePublication *state = native_frame_publication_state(view, YES);
    BOOL start = NO;
    @synchronized(state) {
        if (state->failed) return;
        frame->epoch = state->epoch;
        state->latest_generation = frame->generation;
        state->latest_token = frame->submission.token;
        state->latest_bounds = frame->bounds;
        state->latest_scale = frame->scale;
        native_frame_publication_set_pending(state, frame);
        if (!state->working) {
            state->working = start = YES;
            state->work_submitted = getenv("VOX_GPU_FRAME_QUEUE_DIAGNOSTICS") ? CACurrentMediaTime() : 0;
        }
    }
    if (start) dispatch_async(native_frame_publication_queue(), ^{
        native_frame_publication_work(view,state,complete,can_complete);
    });
}
#endif
