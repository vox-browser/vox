// Inject precise Cocoa input and timestamp changed layer publications in-process.
// Keep samples in memory: pipe/log delivery must not become the clock endpoint.
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

@interface VoxPositionedWheel : NSProxy
@property(strong) NSEvent *backing;
@property NSPoint point;
@property NSInteger windowNumber;
@end
@implementation VoxPositionedWheel
- (NSPoint)locationInWindow { return self.point; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.backing methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.backing];
}
@end

static double rendered_scroll;
extern void ladybird_v_skia_set_root_raster_scroll_y(double);
static void track_scroll(double y) {
    rendered_scroll = y;
    ladybird_v_skia_set_root_raster_scroll_y(y);
}
__attribute__((used)) static struct { const void *replacement, *original; } scroll_interpose
    __attribute__((section("__DATA,__interpose"))) = {
        (const void *)track_scroll, (const void *)ladybird_v_skia_set_root_raster_scroll_y };

typedef struct { double time, elapsed; } Input;
typedef struct { double time, elapsed, age, scroll; unsigned inputs; } Frame;
static Input *input_samples;
static Frame *frame_samples;
static NSView *input_view, *page_view;
static IMP update;
static dispatch_source_t timer;
static double started, last_input, input_hz, delta;
static unsigned inputs, publications, input_limit, reverse_every, frame_capacity;
static BOOL active;

static NSView *find(NSView *root, NSString *name) {
    if ([root isKindOfClass:NSClassFromString(name)]) return root;
    for (NSView *child in root.subviews) {
        NSView *result = find(child, name);
        if (result) return result;
    }
    return nil;
}

static void published(id self, SEL selector) {
    // Retain the previous contents while comparing identities; releasing it
    // first would allow an allocator to recycle its address for the new image.
    __attribute__((objc_precise_lifetime)) id previous = page_view.layer.contents;
    double before = CACurrentMediaTime();
    ((void (*)(id, SEL))update)(self, selector);
    double now = CACurrentMediaTime();
    if (!active || self != page_view || previous == page_view.layer.contents) return;
    if (publications >= frame_capacity) {
        fprintf(stderr, "SCROLL_ERROR publication capacity exceeded\n");
        exit(2);
    }
    frame_samples[publications++] = (Frame){
        now-started, now-before, now-last_input, rendered_scroll, inputs };
}

static void finish(void) {
    active = NO;
    double finished = CACurrentMediaTime();
    for (unsigned i = 0; i < inputs; ++i)
        fprintf(stderr, "SCROLL_INPUT %u t_us=%.3f wheel_us=%.3f\n", i,
            input_samples[i].time*1e6, input_samples[i].elapsed*1e6);
    for (unsigned i = 0; i < publications; ++i) {
        Frame f = frame_samples[i];
        fprintf(stderr, "SCROLL_PUBLISH %u t_us=%.3f frame_us=%.3f input_age_us=%.3f inputs=%u scroll_y=%.9f\n",
            i, f.time*1e6, f.elapsed*1e6, f.age*1e6, f.inputs, f.scroll);
    }
    fprintf(stderr, "SCROLL_DONE inputs=%u publications=%u duration_us=%.3f\n",
        inputs, publications, (finished-started)*1e6);
    fflush(stderr);
    exit(0);
}

static void tick(void) {
    CGEventRef cg = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel,
        1, (inputs / reverse_every) % 2 ? (int32_t)delta : -(int32_t)delta);
    if (!cg) { fprintf(stderr, "SCROLL_ERROR cannot create input\n"); exit(2); }
    CGEventSetIntegerValueField(cg, kCGMouseEventWindowUnderMousePointer,
        input_view.window.windowNumber);
    NSPoint center = NSMakePoint(NSMidX(input_view.bounds), NSMidY(input_view.bounds));
    NSPoint screen = [input_view.window convertPointToScreen:
        [input_view convertPoint:center toView:nil]];
    CGEventSetLocation(cg, CGPointMake(screen.x, NSMaxY(NSScreen.screens[0].frame)-screen.y));
    VoxPositionedWheel *positioned = [VoxPositionedWheel alloc];
    positioned.backing = [NSEvent eventWithCGEvent:cg];
    positioned.point = [input_view convertPoint:center toView:nil];
    positioned.windowNumber = input_view.window.windowNumber;
    CFRelease(cg);
    if (!inputs) {
        NSEvent *event = (NSEvent *)positioned;
        fprintf(stderr, "SCROLL_START precise=%d delta_y=%g view_width=%g view_height=%g scale=%g input_hz=%g title=%s\n",
            event.hasPreciseScrollingDeltas, event.scrollingDeltaY,
            page_view.bounds.size.width, page_view.bounds.size.height,
            page_view.window.backingScaleFactor, input_hz, page_view.window.title.UTF8String);
        fprintf(stderr, "SCROLL_POSITION window=%ld event_window=%ld x=%g y=%g\n",
            (long)input_view.window.windowNumber, (long)event.windowNumber,
            event.locationInWindow.x, event.locationInWindow.y);
        started = CACurrentMediaTime();
        active = YES;
    }
    unsigned index = inputs++;
    last_input = CACurrentMediaTime();
    input_samples[index].time = last_input-started;
    [input_view scrollWheel:(NSEvent *)positioned];
    input_samples[index].elapsed = CACurrentMediaTime()-last_input;
    if (inputs == input_limit) {
        dispatch_source_cancel(timer);
        // Allow the last input's requested publication to complete. Tail frames
        // are retained in raw evidence but excluded from the timed input window.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC/4),
            dispatch_get_main_queue(), ^{ finish(); });
    }
}

static void begin(void) {
    for (NSWindow *window in NSApp.windows) {
        input_view = find(window.contentView, @"_sapp_macos_view");
        page_view = find(window.contentView, @"MyView2");
        if (input_view && page_view && page_view.layer.contents) break;
    }
    if (!input_view || !page_view || !page_view.layer.contents) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
            dispatch_get_main_queue(), ^{ begin(); });
        return;
    }
    Method method = class_getInstanceMethod(page_view.class, @selector(updateLayer));
    if (!method) { fprintf(stderr, "SCROLL_ERROR no publication hook\n"); exit(2); }
    update = method_setImplementation(method, (IMP)published);
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), NSEC_PER_SEC/input_hz, 0);
    dispatch_source_set_event_handler(timer, ^{ tick(); });
    dispatch_resume(timer);
}

__attribute__((constructor)) static void boot(void) {
    const char *names[] = {"VOX_PRECISE_INPUTS", "VOX_PRECISE_REVERSE",
        "VOX_PRECISE_HZ", "VOX_PRECISE_DELTA", "VOX_PRECISE_SETTLE"};
    double values[5];
    for (unsigned i = 0; i < 5; ++i) {
        const char *value = getenv(names[i]);
        char *end = NULL;
        values[i] = value ? strtod(value, &end) : NAN;
        if (!isfinite(values[i]) || !end || end == value || *end) {
            fprintf(stderr, "SCROLL_ERROR invalid %s\n", names[i]); exit(2);
        }
    }
    if (values[0] < 10 || values[0] > 100000 || values[0] != floor(values[0])
        || values[1] < 1 || values[1] > 100000 || values[1] != floor(values[1])
        || values[2] <= 0 || values[2] > 1000 || values[3] < 1 || values[3] > 100
        || values[3] != floor(values[3]) || values[4] < 0 || values[4] > 3600) {
        fprintf(stderr, "SCROLL_ERROR invalid input schedule\n"); exit(2);
    }
    input_limit = (unsigned)values[0];
    reverse_every = (unsigned)values[1];
    input_hz = values[2];
    delta = values[3];
    frame_capacity = input_limit*8+1024;
    input_samples = calloc(input_limit, sizeof(Input));
    frame_samples = calloc(frame_capacity, sizeof(Frame));
    if (!input_samples || !frame_samples) {
        fprintf(stderr, "SCROLL_ERROR sample allocation failed\n"); exit(2);
    }
    double settle = values[4];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, settle*NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{ begin(); });
}
