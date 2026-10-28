#pragma once
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

static BOOL vox_tab_window_hidden;
static IMP vox_tab_original_terminate_after_last_window;

static BOOL vox_tab_terminate_after_last_window(id delegate, SEL selector, NSApplication *app) {
    // AppKit also checks this policy after orderOut:. A background tab still
    // owns a live document and must not shut down its whole process group.
    if (vox_tab_window_hidden) return NO;
    return vox_tab_original_terminate_after_last_window
        ? ((BOOL (*)(id, SEL, NSApplication *))vox_tab_original_terminate_after_last_window)(delegate, selector, app)
        : NO;
}

static void vox_tab_window_install_lifetime_policy(NSWindow *window) {
    static BOOL installed;
    if (installed || !NSApp.delegate) return;
    installed = YES;
    Class cls = [NSApp.delegate class];
    SEL selector = @selector(applicationShouldTerminateAfterLastWindowClosed:);
    Method method = class_getInstanceMethod(cls, selector);
    vox_tab_original_terminate_after_last_window = method ? method_getImplementation(method) : NULL;
    if (!class_addMethod(cls, selector, (IMP)vox_tab_terminate_after_last_window, "B@:@"))
        method_setImplementation(class_getInstanceMethod(cls, selector), (IMP)vox_tab_terminate_after_last_window);
    // An explicit close (including sapp_quit()) must retain the normal policy,
    // even when the document's window was previously ordered out.
    [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification
        object:window queue:nil usingBlock:^(NSNotification *notification) {
            (void)notification;
            BOOL wasHidden = vox_tab_window_hidden;
            vox_tab_window_hidden = NO;
            // A window already ordered out cannot trigger another last-visible-
            // window transition. Finish an explicit background-tab close too.
            if (wasHidden) dispatch_async(dispatch_get_main_queue(), ^{ [NSApp terminate:nil]; });
        }];
}

static void vox_tab_window_prepare(void *handle) {
    NSWindow *window = (__bridge NSWindow *)handle;
    vox_tab_window_install_lifetime_policy(window);
    window.alphaValue = 0;
    window.ignoresMouseEvents = YES;
}
static void vox_tab_window_frame(void *handle, double *values) {
    NSRect frame = [(__bridge NSWindow *)handle frame];
    values[0] = frame.origin.x; values[1] = frame.origin.y;
    values[2] = frame.size.width; values[3] = frame.size.height;
}
static void vox_tab_window_show(void *handle, int visible, double x, double y, double w, double h) {
    NSWindow *window = (__bridge NSWindow *)handle;
    vox_tab_window_install_lifetime_policy(window);
    vox_tab_window_hidden = !visible;
    if (!visible) { [window orderOut:nil]; window.alphaValue = 1; window.ignoresMouseEvents = NO; return; }
    window.alphaValue = 1; window.ignoresMouseEvents = NO;
    if (w > 0 && h > 0) [window setFrame:NSMakeRect(x,y,w,h) display:YES];
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
