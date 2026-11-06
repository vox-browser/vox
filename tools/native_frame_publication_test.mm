// A blocked GPU scheduling fence must not block input, publish unfinished
// pixels, grow a dispatch backlog, or overwrite a newer synchronous capture.
#include "../native_layer_presentation_darwin.h"
#include <atomic>
#include <cassert>
#include <map>
#include <vector>

@interface MyView2 : NSView
@end
@implementation MyView2
@end

struct Gate { int index; bool success, block; };
static std::atomic<int> scheduled[32], released[32];
static dispatch_semaphore_t entered, proceed;
static int paint_value, gate_index = -1;
static BOOL input_delivered;
static bool gate_success = true, gate_block;
static bool claim_submission;
static std::map<uint64_t,int> prepared_values;
static std::vector<int> installed, acknowledged;
static int pixel(CGImageRef image) {
    assert(image);
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    assert(data && CFDataGetLength(data) >= 4);
    int value = CFDataGetBytePtr(data)[0];
    CFRelease(data);
    return value;
}
static int schedule(void *pointer) {
    auto *gate = (Gate *)pointer;
    ++scheduled[gate->index];
    if (gate->block) {
        assert(!NSThread.isMainThread);
        dispatch_semaphore_signal(entered);
        assert(!dispatch_semaphore_wait(proceed, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)));
    }
    return gate->success;
}
static void release_gate(void *pointer) {
    auto *gate = (Gate *)pointer;
    ++released[gate->index];
    delete gate;
}
static void prepared(void *pointer, uint64_t token, double started) {
    assert(NSThread.isMainThread && pointer && token && started > 0);
    prepared_values[token] = paint_value;
}
static void published(void *pointer, uint64_t token) {
    assert(NSThread.isMainThread);
    auto view = (__bridge NSView *)pointer;
    int expected = prepared_values.at(token);
    assert(pixel(native_layer_frame_image(view)) == expected);
    installed.push_back(expected);
}
static void submitted(void *pointer, int64_t navigation, uint64_t installation, uint64_t token) {
    assert(NSThread.isMainThread && pointer && navigation==7 && installation==9);
    acknowledged.push_back(prepared_values.at(token));
}
static void draw(id self, SEL, NSRect bounds) {
    vox_browser_frame_prepared();
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context, paint_value/255., .25, .5, 1);
    CGContextFillRect(context, bounds);
    if (gate_index >= 0) {
        VoxScrollGpuFence *fence = [[VoxScrollGpuFence alloc] init];
        fence->completion = new Gate{gate_index,gate_success,gate_block};
        fence->schedule = schedule;
        fence->release_completion = release_gate;
        VoxScrollTileFrame *tiles = [[VoxScrollTileFrame alloc] init];
        tiles->images = CFArrayCreate(NULL,NULL,0,&kCFTypeArrayCallBacks);
        tiles->scale = 1;
        tiles->fence = CFRetain((__bridge CFTypeRef)fence);
        native_scroll_tile_pending = tiles;
#if !__has_feature(objc_arc)
        [fence release];
#endif
    }
    vox_browser_frame_completed();
    if (gate_index < 0 || native_layer_capture_scale || claim_submission)
        assert(vox_browser_stage_document_submission(submitted,(__bridge void *)self,7,9));
}
static void paint(NSView *view, int value, int gate=-1, bool block=false, bool success=true) {
    @autoreleasepool {
        paint_value=value; gate_index=gate; gate_block=block; gate_success=success;
        ++native_layer_redraw_generation;
        native_layer_present_frame(view,1,(IMP)draw);
    }
}
template<class Predicate> static void pump(Predicate done) {
    double deadline=CACurrentMediaTime()+5;
    while (!done() && CACurrentMediaTime()<deadline) {
        @autoreleasepool {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode,.002,true);
        }
    }
    assert(done());
}
static void start_blocked(NSView *view, int value, int gate) {
    entered=dispatch_semaphore_create(0); proceed=dispatch_semaphore_create(0);
    paint(view,value,gate,true);
    assert(!dispatch_semaphore_wait(entered,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC)));
}
static void idle(NSView *view) {
    pump([&]{ return !native_frame_publication_busy(view); });
}
int main() { @autoreleasepool {
    [NSApplication sharedApplication];
    setenv("VOX_GPU_FRAME_READINESS_QUEUE","1",1);
    native_set_opaque_browser_frames(1);
    [VoxNativeFramePublication observePrepared:prepared published:published];
    assert([VoxNativeFramePublication observerProtocol]==1);
    MyView2 *view=[[MyView2 alloc] initWithFrame:NSMakeRect(0,0,40,30)];
    view.wantsLayer=YES;
    paint(view,31);
    assert(installed==std::vector<int>{31} && acknowledged==installed);
    CGImageRef retained=CGImageRetain(native_layer_frame_image(view));

    // One in-flight frame plus the latest pending frame, despite 100 paints.
    start_blocked(view,45,0);
    assert(installed.size()==1 && pixel(native_layer_frame_image(view))==31);
    for(int n=0;n<100;++n) paint(view,70+n%50,1);
    paint(view,150,2);
    assert(scheduled[1]==0 && released[1]==100);
    assert(native_frame_publication_covers(view,native_layer_redraw_generation,1));
    dispatch_async(dispatch_get_main_queue(),^{ input_delivered=YES; });
    pump([&]{ return input_delivered; });
    assert(installed.size()==1);
    // A cooperative render can pump the run loop; completion still waits for
    // that preparation to exit before touching layers or calling back into V.
    native_layer_document_work_active=YES;
    dispatch_semaphore_signal(proceed);
    pump([&]{
        VoxNativeFramePublication *state=native_frame_publication_state(view,NO);
        @synchronized(state) { return released[2]==1 && !state->working; }
    });
    assert(installed.size()==1);
    native_layer_document_work_active=NO;
    idle(view);
    assert((installed==std::vector<int>{31,150}));
    assert(acknowledged==std::vector<int>{31} && scheduled[0]==1 && scheduled[2]==1);
    assert(pixel(retained)==31); CGImageRelease(retained);

    // A geometry change cancels an in-flight old-size result.
    start_blocked(view,160,3);
    native_layer_original_frame_size=(IMP)class_getMethodImplementation(NSView.class,@selector(setFrameSize:));
    native_layer_frame_size_changed(view,@selector(setFrameSize:),NSMakeSize(50,35));
    dispatch_semaphore_signal(proceed); idle(view);
    assert(installed.back()==150 && released[3]==1);
    paint(view,170);
    assert(installed.back()==170 && CGImageGetWidth(native_layer_frame_image(view))==50);

    // A synchronous capture replaces queued work; late completion cannot
    // restore an older scroll or scale. Capture may resolve its own fence.
    start_blocked(view,180,4);
    paint(view,190,5);
    native_layer_capture_scale=1;
    paint(view,200,6);
    native_layer_capture_scale=0;
    assert(installed.back()==200 && released[5]==1 && scheduled[5]==0);
    dispatch_semaphore_signal(proceed); idle(view);
    assert(installed.back()==200 && released[4]==1 && scheduled[6]==1);

    // Failure preserves the previous image and requests fresh CPU recovery.
    auto generation=native_layer_redraw_generation;
    size_t before=installed.size();
    native_layer_document_work_active=YES;
    paint(view,210,7,false,false);
    pump([&]{
        VoxNativeFramePublication *state=native_frame_publication_state(view,NO);
        @synchronized(state) { return state->failed && !state->working; }
    });
    paint(view,211,13);
    assert(released[13]==1 && scheduled[13]==0);
    native_layer_document_work_active=NO;
    idle(view);
    assert(installed.size()==before && acknowledged.back()==200);
    assert(pixel(native_layer_frame_image(view))==200);
    assert(native_scroll_gpu_tile_failed && native_layer_redraw_generation>generation+1);
    paint(view,220);
    assert(installed.back()==220 && acknowledged.back()==220);

    // Window/backing changes cancel independently of frame dimensions.
    start_blocked(view,230,8);
    native_layer_backing_changed(view,@selector(viewDidChangeBackingProperties));
    dispatch_semaphore_signal(proceed); idle(view);
    assert(installed.back()==220 && released[8]==1);
    start_blocked(view,240,9);
    native_layer_moved_to_window(view,@selector(viewDidMoveToWindow));
    dispatch_semaphore_signal(proceed); idle(view);
    assert(installed.back()==220 && released[9]==1);
    // A first-document claim borrows a V owner. It stays synchronous even with
    // the option on, cancels the old document's pending output, and is
    // acknowledged only after its image is installed.
    start_blocked(view,245,11);
    paint(view,246,12);
    claim_submission=true;
    paint(view,250,10);
    claim_submission=false;
    assert(installed.back()==250 && acknowledged.back()==250 && released[10]==1);
    assert(released[12]==1 && scheduled[12]==0);
    dispatch_semaphore_signal(proceed); idle(view);
    assert(installed.back()==250 && released[11]==1);
    [VoxNativeFramePublication observePrepared:NULL published:NULL];
#if !__has_feature(objc_arc)
    [view release];
#endif
    puts("GPU readiness queue: bounded latest frame, responsive main queue, immutable images, cooperative paint, resize, capture, failure recovery and window cancellation passed");
} }
