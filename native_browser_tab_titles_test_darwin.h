#pragma once
#include "native_address_bar_test_darwin.h"
#include "browserui/tab_visual_test_darwin.h"

static int native_test_tab_rename(void *handle) {
    NSMenu *menu = [(__bridge NSView *)handle menu];
    for (NSInteger index = 0; index < menu.numberOfItems; ++index) {
        if ([[menu itemAtIndex:index].title isEqualToString:@"Rename Tab…"]) {
            [menu performActionForItemAtIndex:index];
            return 1;
        }
    }
    return 0;
}
