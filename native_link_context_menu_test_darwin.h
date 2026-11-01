#pragma once
#include "native_address_bar_test_darwin.h"
static NSArray<NSPasteboardItem *> *vox_link_test_saved_clipboard;
static void *vox_link_test_begin(void) {
    NSPasteboard *board = NSPasteboard.generalPasteboard;
    NSMutableArray *saved = [NSMutableArray new];
    for (NSPasteboardItem *item in board.pasteboardItems) {
        NSPasteboardItem *copy = [NSPasteboardItem new];
        for (NSString *type in item.types) if ([item dataForType:type]) [copy setData:[item dataForType:type] forType:type];
        [saved addObject:copy];
    }
    vox_link_test_saved_clipboard = saved;
    return native_test_address_window();
}
static void vox_link_test_end(void *window) {
    NSPasteboard *board = NSPasteboard.generalPasteboard;
    [board clearContents];
    if (vox_link_test_saved_clipboard.count) [board writeObjects:vox_link_test_saved_clipboard];
    vox_link_test_saved_clipboard = nil;
    native_test_address_close(window);
}
static int vox_link_test_clipboard_matches(const unsigned char *bytes, int length) {
    NSString *expected = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
    return [[NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] isEqualToString:expected];
}
