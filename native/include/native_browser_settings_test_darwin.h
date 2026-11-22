#pragma once
#include "native_address_bar_test_darwin.h"
static int native_test_settings_address_state(void *control, int editable) {
    NSTextField *field = (__bridge NSTextField *)control;
    return field.isEditable == (editable != 0) && field.isSelectable;
}

static int native_test_settings_select_tab(void *control) {
    return [(__bridge NSView *)control accessibilityPerformPress];
}

static int native_test_settings_cycle_tab(void *control, int reverse) {
    NSWindow *window = [(__bridge NSView *)control window];
    NSEventModifierFlags modifiers = NSEventModifierFlagControl;
    if (reverse) modifiers |= NSEventModifierFlagShift;
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:modifiers timestamp:0 windowNumber:window.windowNumber context:nil
        characters:@"\t" charactersIgnoringModifiers:@"\t" isARepeat:NO keyCode:48];
    return ui2_embedded_key_event((__bridge void *)event) != 0;
}
