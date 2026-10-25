#include <assert.h>
#include "../native_browser_window_state_darwin.h"
#include "../native_test_window_darwin.h"

@interface WindowStateTestScreen : NSObject
@property NSRect visibleFrame;
@end
@implementation WindowStateTestScreen
@end

// Exercise fullscreen notifications and restoration without changing Spaces
// or moving the user's foreground application to another desktop.
@interface WindowStateTestWindow : NSWindow
@property BOOL testFullscreen;
@property NSRect testNormalFrame;
@end
@implementation WindowStateTestWindow
- (void)toggleFullScreen:(id)sender {
    (void)sender;
    NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
    if (!self.testFullscreen) {
        self.testNormalFrame = self.frame;
        [notifications postNotificationName:NSWindowWillEnterFullScreenNotification object:self];
        [self setFrame:self.screen.frame display:NO];
        self.testFullscreen = YES;
        [notifications postNotificationName:NSWindowDidEnterFullScreenNotification object:self];
    } else {
        [notifications postNotificationName:NSWindowWillExitFullScreenNotification object:self];
        [self setFrame:self.testNormalFrame display:NO];
        self.testFullscreen = NO;
        [notifications postNotificationName:NSWindowDidExitFullScreenNotification object:self];
    }
}
@end

static NSDictionary *saved(NSString *path) {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:path];
    assert(state);
    return state;
}

static void geometry(void) {
    WindowStateTestScreen *left = [WindowStateTestScreen new];
    WindowStateTestScreen *right = [WindowStateTestScreen new];
    left.visibleFrame = NSMakeRect(-1440, 25, 1440, 875);
    right.visibleFrame = NSMakeRect(0, 25, 1920, 1055);
    NSArray *screens = @[left, right];
    NSSize minimum = NSMakeSize(640, 480);
    NSRect normal = NSMakeRect(-1300, 100, 800, 600);
    assert(NSEqualRects(native_browser_window_visible_frame(normal, screens,
        (NSScreen *)right, minimum, NO), normal));
    NSRect missing = native_browser_window_visible_frame(NSMakeRect(5000, 5000, 2400, 1500),
        screens, (NSScreen *)right, minimum, NO);
    assert(NSEqualRects(missing, right.visibleFrame));
    NSRect small = native_browser_window_visible_frame(NSMakeRect(10, 40, 200, 200),
        screens, (NSScreen *)right, minimum, NO);
    assert(small.size.width == 640 && small.size.height == 480);
    NSRect test = native_browser_window_visible_frame(normal, screens,
        (NSScreen *)right, minimum, YES);
    assert(test.size.width == 800 && test.size.height == 600);
    assert(NSMaxX(test) == NSMaxX(right.visibleFrame));
    assert(NSMaxY(test) == NSMaxY(right.visibleFrame));
    assert(!native_browser_window_frame_valid(NSMakeRect(NAN, 0, 800, 600)));
    assert(!native_browser_window_frame_valid(NSMakeRect(0, 0, INFINITY, 600)));
    assert(!native_browser_window_frame_valid(NSMakeRect(0, 0, -10, 600)));
    [left release];
    [right release];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        assert(argc == 3);
        geometry();
        NSString *mode = @(argv[1]), *path = @(argv[2]);
        native_prepare_test_window();
        WindowStateTestWindow *window = [[WindowStateTestWindow alloc]
            initWithContentRect:NSMakeRect(0, 0, 800, 680)
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
            backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed = NO;
        window.animationBehavior = NSWindowAnimationBehaviorNone;
        window.minSize = NSMakeSize(640, 480);
        [window makeKeyAndOrderFront:nil];
        native_finish_test_window();
        native_prepare_browser_window_state(path.fileSystemRepresentation);
        native_restore_browser_window_state((__bridge void *)window);
        if ([mode isEqual:@"normal-write"]) {
            assert(![NSFileManager.defaultManager fileExistsAtPath:path]);
            [window setContentSize:NSMakeSize(720, 520)];
            assert(!window.zoomed);
            assert(NSEqualRects(NSRectFromString(saved(path)[@"normalFrame"]), window.frame));
            assert(![saved(path)[@"maximized"] boolValue]);
        } else if ([mode isEqual:@"normal-read"]) {
            assert(window.contentView.frame.size.width == 720);
            assert(window.contentView.frame.size.height == 520);
            assert(!window.zoomed);
            // Moving the window and quitting also persist the final geometry.
            [window setFrameOrigin:NSMakePoint(window.frame.origin.x - 20, window.frame.origin.y - 20)];
            [NSNotificationCenter.defaultCenter postNotificationName:NSApplicationWillTerminateNotification object:NSApp];
            assert(NSEqualRects(NSRectFromString(saved(path)[@"normalFrame"]), window.frame));
        } else if ([mode isEqual:@"max-write"]) {
            NSRect normal = window.frame;
            [window zoom:nil];
            assert(window.zoomed);
            assert([saved(path)[@"maximized"] boolValue]);
            assert(NSEqualRects(normal, NSRectFromString(saved(path)[@"normalFrame"])));
        } else if ([mode isEqual:@"max-read"]) {
            assert(window.zoomed);
            [window zoom:nil];
            assert(!window.zoomed);
            assert(window.contentView.frame.size.width == 720);
            assert(window.contentView.frame.size.height == 520);
            assert(![saved(path)[@"maximized"] boolValue]);
        } else if ([mode isEqual:@"fullscreen-write"]) {
            NSRect normal = window.frame;
            [window toggleFullScreen:nil];
            assert([saved(path)[@"fullscreen"] boolValue]);
            assert(NSEqualRects(normal, NSRectFromString(saved(path)[@"normalFrame"])));
        } else if ([mode isEqual:@"fullscreen-read"]) {
            assert(window.testFullscreen);
            [window toggleFullScreen:nil];
            assert(![saved(path)[@"fullscreen"] boolValue]);
            assert(window.contentView.frame.size.width == 720);
            assert(window.contentView.frame.size.height == 520);
        } else if ([mode isEqual:@"malformed"]) {
            assert(window.contentView.frame.size.width == 800);
            assert(window.contentView.frame.size.height == 680);
        } else {
            assert(!"unknown test mode");
        }
        [window close];
        native_finish_browser_window_state();
        [window release];
        printf("PASS %s (fresh process %d)\n", argv[1], getpid());
    }
}
