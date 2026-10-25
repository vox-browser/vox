#pragma once
#import <Cocoa/Cocoa.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

// Keep this separate from proxy settings: resizing must not turn an inherited
// proxy configuration into an explicit direct-connection preference.
static NSString *native_browser_window_state_path;

static BOOL native_browser_window_frame_valid(NSRect frame) {
    return isfinite(frame.origin.x) && isfinite(frame.origin.y)
        && isfinite(frame.size.width) && isfinite(frame.size.height)
        && frame.size.width >= 100 && frame.size.height >= 100
        && frame.size.width <= 100000 && frame.size.height <= 100000;
}

static NSRect native_browser_window_visible_frame(NSRect frame, NSArray<NSScreen *> *screens,
    NSScreen *fallback, NSSize minimum, BOOL test_window) {
    NSScreen *selected = fallback;
    CGFloat largest = 0;
    if (!test_window) {
        for (NSScreen *screen in screens) {
            NSRect overlap = NSIntersectionRect(frame, screen.visibleFrame);
            CGFloat area = overlap.size.width * overlap.size.height;
            if (area > largest) { largest = area; selected = screen; }
        }
    }
    if (!selected) return frame;
    NSRect visible = selected.visibleFrame;
    frame.size.width = MIN(MAX(frame.size.width, minimum.width), visible.size.width);
    frame.size.height = MIN(MAX(frame.size.height, minimum.height), visible.size.height);
    frame.origin.x = test_window ? NSMaxX(visible) - frame.size.width
        : MAX(NSMinX(visible), MIN(frame.origin.x, NSMaxX(visible) - frame.size.width));
    frame.origin.y = test_window ? NSMaxY(visible) - frame.size.height
        : MAX(NSMinY(visible), MIN(frame.origin.y, NSMaxY(visible) - frame.size.height));
    return frame;
}

@interface VoxBrowserWindowState : NSObject
@property(nonatomic, assign) NSWindow *window;
@property(nonatomic, copy) NSString *path;
@property(nonatomic) NSRect normalFrame;
@property(nonatomic) BOOL maximized;
@property(nonatomic) BOOL fullscreen;
@property(nonatomic) BOOL transitioning;
@property(nonatomic) BOOL restoring;
- (void)save;
@end

@implementation VoxBrowserWindowState
- (void)save {
    if (self.restoring || self.transitioning || !self.window) return;
    // Miniaturization is deliberately transient; retain the last usable frame.
    if (!self.window.miniaturized && !self.fullscreen) {
        self.maximized = self.window.zoomed;
        if (!self.maximized) self.normalFrame = self.window.frame;
    }
    if (!native_browser_window_frame_valid(self.normalFrame)) return;
    NSDictionary *state = @{@"version": @1, @"normalFrame": NSStringFromRect(self.normalFrame),
        @"maximized": @(self.maximized), @"fullscreen": @(self.fullscreen)};
    NSError *error = nil;
    NSFileManager *files = NSFileManager.defaultManager;
    if (![files createDirectoryAtPath:self.path.stringByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:&error]
        || ![state writeToFile:self.path atomically:YES]) {
        NSLog(@"Vox: could not save window state to %@%@", self.path,
            error ? [@": " stringByAppendingString:error.localizedDescription] : @"");
    }
}
- (void)changed:(NSNotification *)notification {
    (void)notification;
    [self save];
}
- (void)willEnterFullscreen:(NSNotification *)notification {
    (void)notification;
    [self save];
    self.transitioning = YES;
}
- (void)didEnterFullscreen:(NSNotification *)notification {
    (void)notification;
    self.fullscreen = YES;
    self.transitioning = NO;
    [self save];
}
- (void)willExitFullscreen:(NSNotification *)notification {
    (void)notification;
    self.transitioning = YES;
}
- (void)didExitFullscreen:(NSNotification *)notification {
    (void)notification;
    self.fullscreen = NO;
    self.transitioning = NO;
    [self save];
}
- (void)closed:(NSNotification *)notification {
    (void)notification;
    [self save];
    self.window = nil;
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
#if !__has_feature(objc_arc)
    [_path release];
    [super dealloc];
#endif
}
@end

static VoxBrowserWindowState *native_browser_window_state;

static void native_finish_browser_window_state(void) {
    [native_browser_window_state save];
    if (native_browser_window_state)
        [NSNotificationCenter.defaultCenter removeObserver:native_browser_window_state];
#if !__has_feature(objc_arc)
    [native_browser_window_state release];
    [native_browser_window_state_path release];
#endif
    native_browser_window_state = nil;
    native_browser_window_state_path = nil;
}

static void native_prepare_browser_window_state(const char *path) {
    native_finish_browser_window_state();
    if (path && path[0]) native_browser_window_state_path = [[NSString alloc] initWithUTF8String:path];
}

static void native_restore_browser_window_state(void *handle) {
    NSWindow *window = (__bridge NSWindow *)handle;
    if (!window || !native_browser_window_state_path || native_browser_window_state) return;
    VoxBrowserWindowState *state = [VoxBrowserWindowState new];
    native_browser_window_state = state;
    state.path = native_browser_window_state_path;
    state.window = window;
    state.normalFrame = window.frame;
    state.restoring = YES;
    NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:state.path];
    id version = saved[@"version"], frame = saved[@"normalFrame"];
    id maximized = saved[@"maximized"], fullscreen = saved[@"fullscreen"];
    BOOL valid = [version isKindOfClass:NSNumber.class] && [version integerValue] == 1
        && [frame isKindOfClass:NSString.class]
        && [maximized isKindOfClass:NSNumber.class] && [fullscreen isKindOfClass:NSNumber.class];
    NSRect normal = valid ? NSRectFromString(frame) : NSZeroRect;
    if (valid && native_browser_window_frame_valid(normal)) {
        BOOL test_window = getenv("VOX_TEST_WINDOW") && strcmp(getenv("VOX_TEST_WINDOW"), "1") == 0;
        normal = native_browser_window_visible_frame(normal, NSScreen.screens,
            window.screen ?: NSScreen.mainScreen, window.minSize, test_window);
        [window setFrame:normal display:NO];
        state.normalFrame = window.frame;
        if ([maximized boolValue]) [window zoom:nil];
        state.maximized = window.zoomed;
    } else {
        valid = NO;
    }
    NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[NSWindowDidResizeNotification, NSWindowDidMoveNotification,
        NSWindowDidEndLiveResizeNotification, NSWindowDidDeminiaturizeNotification]) {
        [notifications addObserver:state selector:@selector(changed:) name:name object:window];
    }
    [notifications addObserver:state selector:@selector(closed:) name:NSWindowWillCloseNotification object:window];
    [notifications addObserver:state selector:@selector(changed:) name:NSApplicationWillTerminateNotification object:NSApp];
    [notifications addObserver:state selector:@selector(willEnterFullscreen:) name:NSWindowWillEnterFullScreenNotification object:window];
    [notifications addObserver:state selector:@selector(didEnterFullscreen:) name:NSWindowDidEnterFullScreenNotification object:window];
    [notifications addObserver:state selector:@selector(willExitFullscreen:) name:NSWindowWillExitFullScreenNotification object:window];
    [notifications addObserver:state selector:@selector(didExitFullscreen:) name:NSWindowDidExitFullScreenNotification object:window];
    state.restoring = NO;
    if (valid && [fullscreen boolValue]) [window toggleFullScreen:nil];
}
