#include "../native_layer_presentation_darwin.h"
#include <assert.h>

@interface VoxRedrawProbe : NSView { BOOL dirty_; }
@end
@implementation VoxRedrawProbe
- (BOOL)needsDisplay { return dirty_; }
- (void)setNeedsDisplay:(BOOL)value { dirty_ = value; }
@end

int main(void) {
    @autoreleasepool {
        assert(!NSClassFromString(@"MyView2"));
        Class canvas_class = objc_allocateClassPair(VoxRedrawProbe.class, "MyView2", 0);
        assert(canvas_class); objc_registerClassPair(canvas_class);
        NSView *root = [[VoxRedrawProbe alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
        NSView *host = [[VoxRedrawProbe alloc] initWithFrame:root.bounds];
        NSView *canvas = [[canvas_class alloc] initWithFrame:root.bounds];
        NSView *chrome = [[VoxRedrawProbe alloc] initWithFrame:NSMakeRect(0, 0, 800, 88)];
        NSView *control = [[VoxRedrawProbe alloc] initWithFrame:NSMakeRect(0, 0, 40, 20)];
        [root addSubview:host]; [host addSubview:canvas]; [host addSubview:chrome]; [chrome addSubview:control];
        for (NSView *view in @[root, host, canvas, chrome, control]) view.needsDisplay = NO;
        assert(native_layer_request_canvas_frames(root) == 1);
        assert(canvas.needsDisplay && host.needsDisplay);
        assert(!root.needsDisplay && !chrome.needsDisplay && !control.needsDisplay);
        // Existing UI2 dirtiness must survive a canvas wake.
        chrome.needsDisplay = YES; control.needsDisplay = YES;
        canvas.needsDisplay = NO; host.needsDisplay = NO;
        assert(native_layer_request_canvas_frames(root) == 1);
        assert(canvas.needsDisplay && host.needsDisplay && chrome.needsDisplay && control.needsDisplay);
        NSView *second = [[canvas_class alloc] initWithFrame:root.bounds]; [host addSubview:second];
        second.needsDisplay = NO;
        assert(native_layer_request_canvas_frames(root) == 2 && second.needsDisplay);
        [second removeFromSuperview]; [canvas addSubview:second]; second.needsDisplay = NO;
        assert(native_layer_request_canvas_frames(root) == 2 && second.needsDisplay);
        [canvas removeFromSuperview]; [second removeFromSuperview];
        root.needsDisplay = NO; host.needsDisplay = NO;
        assert(native_layer_request_canvas_frames(root) == 0 && root.needsDisplay && !host.needsDisplay);
        [second release]; [control release]; [chrome release]; [canvas release]; [host release]; [root release];
    }
    puts("Document redraw scope: canvas/host invalidation, UI2 dirty-state preservation, multiple canvases and startup fallback passed");
}
