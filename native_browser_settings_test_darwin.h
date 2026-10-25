#pragma once
#include "native_address_bar_test_darwin.h"
#include "native_browser_settings_darwin.h"

static int native_test_settings_shortcut(void) {
    if (!NSApp.mainMenu) {
        NSMenu *menu = [NSMenu new];
        NSMenuItem *application = [NSMenuItem new];
        application.submenu = [NSMenu new];
        [menu addItem:application];
        NSApp.mainMenu = menu;
    }
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:0 context:nil
        characters:@"," charactersIgnoringModifiers:@"," isARepeat:NO keyCode:43];
    return [NSApp.mainMenu performKeyEquivalent:event];
}

static int native_test_settings_controls(void *host, void *port, void *sites, void *checkbox, void *apply) {
    NSView *field = (__bridge NSView *)host;
    return [field isKindOfClass:NSTextField.class]
        && [(__bridge id)port isKindOfClass:NSTextField.class]
        && [(__bridge id)sites isKindOfClass:NSTextField.class]
        && [(__bridge id)checkbox isKindOfClass:NSButton.class]
        && [(__bridge id)apply isKindOfClass:NSButton.class]
        && field.window == vox_settings_window
        && NSEqualSizes(vox_settings_window.contentView.bounds.size, NSMakeSize(500, 380));
}

static int native_test_settings_close_shortcut(void) {
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:NSEventModifierFlagCommand timestamp:0
        windowNumber:vox_settings_window.windowNumber context:nil
        characters:@"w" charactersIgnoringModifiers:@"w" isARepeat:NO keyCode:13];
    return [vox_settings_window performKeyEquivalent:event];
}

static int native_test_settings_submit(void *control) {
    NSTextField *field = (__bridge NSTextField *)control;
    if (![field.window makeFirstResponder:field] || !field.target || !field.action) return 0;
    [field.currentEditor doCommandBySelector:@selector(insertNewline:)];
    return 1;
}

static void native_test_settings_edit(void *control, const char *value) {
    NSTextField *field = (__bridge NSTextField *)control;
    [field.window makeFirstResponder:field];
    [field.currentEditor selectAll:nil];
    [field.currentEditor insertText:[NSString stringWithUTF8String:value]];
}

static void native_test_settings_capture(void) {
    const char *path = getenv("VOX_SETTINGS_SCREENSHOT");
    if (!path || !*path) return;
    NSView *view = vox_settings_window.contentView;
    [view layoutSubtreeIfNeeded];
    NSBitmapImageRep *image = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:image];
    [[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
        writeToFile:[NSString stringWithUTF8String:path] atomically:YES];
}
