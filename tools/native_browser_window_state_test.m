#include <assert.h>
#include "../native_browser_window_state_darwin.h"
// Geometry/transition policy lives in browserui/window_test.v. This verifies
// native snapshot, notification lifetime and legacy plist conversion only.
@interface UI2WindowOperationTest : NSWindow
@property int zoomCalls;
@property int fullscreenCalls;
@end
@implementation UI2WindowOperationTest
- (void)zoom:(id)sender { (void)sender; self.zoomCalls++; }
- (void)toggleFullScreen:(id)sender { (void)sender; self.fullscreenCalls++; }
@end
static int events;
static void changed(void *owner, int32_t kind, double *values, int32_t *flags) {
    assert(owner == &events && kind >= 0 && kind <= 5);
    assert(values[2] > 0 && values[3] > 0);
    assert(flags[0] == 0 || flags[0] == 1);
    ++events;
}
int main(int argc, char **argv) { @autoreleasepool {
    assert(argc == 2);
    [NSApplication sharedApplication];
    UI2WindowOperationTest *window=[[UI2WindowOperationTest alloc] initWithContentRect:NSMakeRect(0,0,800,600)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;
    void *handle=(__bridge void *)window;
    double values[6]; int32_t flags[3];
    double screens[64];
    assert(native_window_screens(screens,16)>0);
    assert(native_window_screen_index(handle)>=0);
    native_window_action(handle,0); native_window_action(handle,1);
    assert(window.zoomCalls==1 && window.fullscreenCalls==1);
    native_window_set_frame(handle,100,100,820,640);
    native_window_snapshot(handle,values,flags);
    assert(values[0]==100 && values[1]==100 && values[2]==820 && values[3]==640);
    native_window_observe(handle,&events,changed);
    [NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidMoveNotification object:window];
    assert(events==1);
    native_window_stop_observing();
    [NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidMoveNotification object:window];
    assert(events==1);
    const char *json="{\"version\":1,\"normalFrame\":\"{{100, 100}, {820, 640}}\",\"maximized\":false,\"fullscreen\":false}";
    assert(native_host_write_plist(argv[1],(const unsigned char *)json,(int32_t)strlen(json)));
    char *loaded=native_host_read_plist(argv[1]);
    assert(loaded && strstr(loaded,"normalFrame")); free(loaded);
    [@"invalid plist" writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    assert(native_host_read_plist(argv[1])==NULL);
    [window close];
} return 0; }
