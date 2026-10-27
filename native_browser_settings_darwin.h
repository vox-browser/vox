#pragma once
#import <Cocoa/Cocoa.h>

static NSWindow *vox_settings_window;
static NSMenuItem *vox_settings_menu_item;
static void (*vox_settings_open_callback)(void);

@interface VoxSettingsActions : NSObject
- (void)openSettings:(id)sender;
@end
@implementation VoxSettingsActions
- (void)openSettings:(id)sender {
    (void)sender;
    if (vox_settings_open_callback) vox_settings_open_callback();
}
@end
static VoxSettingsActions *vox_settings_actions;

@interface VoxSettingsWindow : NSWindow
@end
@implementation VoxSettingsWindow
- (void)close {
    // Release the shared field editor before a later open restores saved values.
    [self endEditingFor:nil];
    [super close];
}
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if (flags == NSEventModifierFlagCommand && [event.charactersIgnoringModifiers isEqualToString:@"w"]) {
        [self performClose:nil];
        return YES;
    }
    // Sokol supplies no Edit menu. Preserve native text editing in this window.
    if ((flags & NSEventModifierFlagCommand)
        && !(flags & (NSEventModifierFlagControl | NSEventModifierFlagOption))) {
        SEL action = NULL;
        switch (event.keyCode) {
        case 0: action = @selector(selectAll:); break;
        case 6: action = (flags & NSEventModifierFlagShift) ? @selector(redo:) : @selector(undo:); break;
        case 7: action = @selector(cut:); break;
        case 8: action = @selector(copy:); break;
        case 9: action = @selector(paste:); break;
        }
        if (action && [self.firstResponder tryToPerform:action with:nil]) return YES;
    }
    return [super performKeyEquivalent:event];
}
- (void)cancelOperation:(id)sender { [self performClose:sender]; }
@end

static void native_browser_settings_install(void (*callback)(void)) {
    vox_settings_open_callback = callback;
    if (vox_settings_menu_item) return;
    NSMenu *applicationMenu = NSApp.mainMenu.itemArray.firstObject.submenu;
    if (!applicationMenu) return;
    vox_settings_actions = [VoxSettingsActions new];
    vox_settings_menu_item = [[NSMenuItem alloc] initWithTitle:@"Settings…"
        action:@selector(openSettings:) keyEquivalent:@","];
    vox_settings_menu_item.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    vox_settings_menu_item.target = vox_settings_actions;
    [applicationMenu insertItem:vox_settings_menu_item atIndex:MIN(2, applicationMenu.numberOfItems)];
}

static void *native_browser_settings_content(void) {
    if (!vox_settings_window) {
        vox_settings_window = [[VoxSettingsWindow alloc] initWithContentRect:NSMakeRect(0, 0, 500, 380)
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
            backing:NSBackingStoreBuffered defer:NO];
        vox_settings_window.title = @"Vox Settings";
        vox_settings_window.releasedWhenClosed = NO;
        vox_settings_window.contentView.autoresizesSubviews = YES;
        // Use the browser's display, including the display selected for tests.
        NSWindow *browser = NSApp.mainWindow;
        NSScreen *screen = browser.screen ?: NSScreen.mainScreen;
        if (getenv("VOX_TEST_WINDOW")) {
            NSPoint pointer = NSEvent.mouseLocation;
            for (NSScreen *candidate in NSScreen.screens) {
                if (!NSPointInRect(pointer, candidate.frame)) { screen = candidate; break; }
            }
        }
        NSRect area = screen.visibleFrame;
        NSRect frame = vox_settings_window.frame;
        [vox_settings_window setFrameOrigin:NSMakePoint(NSMidX(area) - NSWidth(frame) / 2,
            NSMidY(area) - NSHeight(frame) / 2)];
    }
    return (__bridge void *)vox_settings_window.contentView;
}

static int native_browser_settings_visible(void) { return vox_settings_window.visible; }
static void native_browser_settings_show(void) { [vox_settings_window makeKeyAndOrderFront:nil]; }
static void native_browser_settings_hide(void) { [vox_settings_window close]; }
static void native_browser_settings_enabled(void *field, int enabled) {
    [(__bridge NSControl *)field setEnabled:enabled != 0];
}
static void native_browser_settings_style_control(void *control, int role) {
    NSView *view = (__bridge NSView *)control;
    if ([view isKindOfClass:NSTextField.class]) {
        NSTextField *field = (NSTextField *)view;
        field.textColor = role == 1 ? NSColor.secondaryLabelColor
            : role == 2 ? NSColor.systemRedColor : NSColor.labelColor;
        if (field.isEditable) {
            field.drawsBackground = YES;
            field.backgroundColor = NSColor.textBackgroundColor;
        }
    } else {
        for (NSView *child in view.subviews)
            native_browser_settings_style_control((__bridge void *)child, role);
    }
}
static void native_browser_settings_buttons(void *apply, void *cancel) {
    vox_settings_window.defaultButtonCell = [(__bridge NSButton *)apply cell];
    [(__bridge NSButton *)cancel setKeyEquivalent:@"\033"];
}
static void native_browser_settings_remove(void) {
    [vox_settings_window close];
    vox_settings_window = nil;
    [vox_settings_menu_item.menu removeItem:vox_settings_menu_item];
    vox_settings_menu_item = nil;
    vox_settings_actions = nil;
    vox_settings_open_callback = NULL;
}
