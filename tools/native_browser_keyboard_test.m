#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>
#include <stdlib.h>

// Injected by test_native_browser_keyboard.py. Send real AppKit events through
// Sokol: direct V shortcut tests do not exercise native key-code storage.
static NSWindow *test_window;
static NSView *input_view;
static NSView *page_view;
static NSTextField *address_field;
static NSString *original_address;
static NSString *original_title;
static NSData *original_pixels;
static unsigned step;
static unsigned attempts;

static NSView *find_view(NSView *view, NSString *class_name) {
    if ([view isKindOfClass:NSClassFromString(class_name)]) return view;
    for (NSView *child in view.subviews) {
        NSView *found = find_view(child, class_name);
        if (found) return found;
    }
    return nil;
}

static NSTextField *find_address(NSView *view) {
    if ([view isKindOfClass:NSTextField.class] && [(NSTextField *)view isEditable])
        return (NSTextField *)view;
    for (NSView *child in view.subviews) {
        NSTextField *found = find_address(child);
        if (found) return found;
    }
    return nil;
}

static void fail(const char *message) {
    fprintf(stderr, "FAIL keyboard step %u: %s\n", step, message);
    fflush(stderr);
    _Exit(1);
}

static NSData *page_pixels(void) {
    id contents = page_view.layer.contents;
    if (!contents || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID())
        return nil;
    CGImageRef image = (__bridge CGImageRef)contents;
    return CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(image)));
}

static void assert_page_preserved(void) {
    if (![address_field.stringValue isEqualToString:original_address])
        fail("a modifier press changed the URL");
    if (![test_window.title isEqualToString:original_title])
        fail("a modifier press changed the active tab");
    if (![page_pixels() isEqualToData:original_pixels])
        fail("a modifier press changed the rendered page");
}

static NSEvent *key_event(NSEventType type, unsigned short key_code,
    NSEventModifierFlags flags, NSString *characters) {
    return [NSEvent keyEventWithType:type location:NSZeroPoint modifierFlags:flags
        timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:test_window.windowNumber
        context:nil characters:characters charactersIgnoringModifiers:characters
        isARepeat:NO keyCode:key_code];
}

static void modifier(unsigned short key_code, NSEventModifierFlags flags) {
    [input_view flagsChanged:key_event(NSEventTypeFlagsChanged, key_code, flags, @"")];
}

static void command(unsigned short key_code, NSString *characters) {
    // Reach Sokol directly, including when the address field owns first responder.
    // This tests the same GG callback path that receives modifier events.
    modifier(55, NSEventModifierFlagCommand);
    [input_view keyDown:key_event(NSEventTypeKeyDown, key_code,
        NSEventModifierFlagCommand, characters)];
    [input_view keyUp:key_event(NSEventTypeKeyUp, key_code,
        NSEventModifierFlagCommand, characters)];
    modifier(55, 0);
}

static void advance(void);

static void poll(void) {
    if (++attempts > 200) fail("timed out waiting for the browser");
    if (!test_window) {
        for (NSWindow *window in NSApp.windows) {
            NSView *input = find_view(window.contentView, @"_sapp_macos_view");
            NSView *page = find_view(window.contentView, @"MyView2");
            NSTextField *address = find_address(window.contentView);
            if (!input || !page || !address
                || ![window.title hasPrefix:@"Keyboard regression"]
                || ![address.stringValue hasPrefix:@"file://"])
                continue;
            test_window = window;
            input_view = input;
            page_view = page;
            address_field = address;
            break;
        }
    }
    if (test_window && page_pixels()) {
        if (step == 0) {
            original_address = [address_field.stringValue copy];
            original_title = [test_window.title copy];
            original_pixels = page_pixels();
        }
        attempts = 0;
        advance();
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC),
        dispatch_get_main_queue(), ^{ poll(); });
}

static void advance(void) {
    if (step > 0 && step <= 9) assert_page_preserved();
    switch (++step) {
        // Left/right modifiers must keep their full key codes above 255.
        case 1: modifier(55, NSEventModifierFlagCommand); break;
        case 2: modifier(55, 0); modifier(54, NSEventModifierFlagCommand); break;
        case 3: modifier(54, 0); modifier(56, NSEventModifierFlagShift); break;
        case 4: modifier(56, 0); modifier(60, NSEventModifierFlagShift); break;
        case 5: modifier(60, 0); modifier(59, NSEventModifierFlagControl); break;
        case 6: modifier(59, 0); modifier(62, NSEventModifierFlagControl); break;
        case 7: modifier(62, 0); modifier(58, NSEventModifierFlagOption); break;
        case 8: modifier(58, 0); modifier(61, NSEventModifierFlagOption); break;
        case 9: modifier(61, 0); command(37, @"l"); break;
        case 10: {
            NSTextView *editor = (NSTextView *)address_field.currentEditor;
            if (!editor || test_window.firstResponder != editor
                || !NSEqualRanges(editor.selectedRange, NSMakeRange(0, original_address.length)))
                fail("Cmd+L did not select the address");
            modifier(55, NSEventModifierFlagCommand);
            break;
        }
        case 11:
            assert_page_preserved();
            modifier(55, 0);
            command(17, @"t");
            break;
        case 12:
            if ([test_window.title isEqualToString:original_title])
                fail("Cmd+T did not create a tab");
            command(13, @"w");
            break;
        default:
            assert_page_preserved();
            fprintf(stderr, "PASS native browser modifiers and Command shortcuts\n");
            fflush(stderr);
            _Exit(0);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC),
        dispatch_get_main_queue(), ^{ poll(); });
}

__attribute__((constructor)) static void start_keyboard_test(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{ poll(); });
}
