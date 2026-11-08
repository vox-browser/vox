#pragma once
#include "native_address_bar_test_darwin.h"
static int native_test_tabs_count(void *handle) {
    int count = 0;
    for (NSView *view in [(__bridge NSView *)handle subviews]) if (![view isKindOfClass:NSButton.class]) ++count;
    return count;
}
static void native_test_tabs_click(void *control) { [(__bridge NSButton *)control performClick:nil]; }
static int native_test_tabs_geometry(void *handle) {
    NSView *strip = (__bridge NSView *)handle;
    if (!strip || strip.bounds.size.height != 29) return 0;
    for (NSView *view in strip.subviews) if (NSMinX(view.frame) < 0 || NSMaxX(view.frame) > strip.bounds.size.width) return 0;
    return 1;
}
static int native_test_tabs_has_icon(void *handle) {
    for (NSView *view in [(__bridge NSView *)handle subviews]) if ([view isKindOfClass:NSImageView.class] && [(NSImageView *)view image]) return 1;
    return 0;
}
static unsigned int native_test_tabs_icon_pixel(void *handle, int x, int y) {
    NSView *view = (__bridge NSView *)handle;
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    CGFloat scale = bitmap.pixelsWide / view.bounds.size.width;
    NSColor *color = [[bitmap colorAtX:x * scale y:y * scale] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    return ((unsigned int)round(color.redComponent * 255) << 24) | ((unsigned int)round(color.greenComponent * 255) << 16)
        | ((unsigned int)round(color.blueComponent * 255) << 8) | (unsigned int)round(color.alphaComponent * 255);
}
static void native_test_tabs_drag(void *handle, double dx, double dy) {
    NSView *view = (__bridge NSView *)handle;
    NSPoint start = [view convertPoint:NSMakePoint(35, 10) toView:nil];
    NSPoint end = NSMakePoint(start.x + dx, start.y - dy);
    NSEvent *(^event)(NSEventType, NSPoint) = ^NSEvent *(NSEventType type, NSPoint point) {
        return [NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:0
            windowNumber:view.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
    };
    [view mouseDown:event(NSEventTypeLeftMouseDown, start)];
    [view mouseDragged:event(NSEventTypeLeftMouseDragged, end)];
    [view mouseUp:event(NSEventTypeLeftMouseUp, end)];
}
@interface UI2TestMiddleEvent : NSObject
@property NSPoint locationInWindow;
@property(nonatomic, strong) NSWindow *window;
@end
@implementation UI2TestMiddleEvent
- (NSInteger)buttonNumber { return 2; }
@end
static void native_test_tabs_middle(void *handle) {
    NSView *view=(__bridge NSView *)handle;
    NSPoint point=[view convertPoint:NSMakePoint(35,10) toView:nil];
    UI2TestMiddleEvent *event=[UI2TestMiddleEvent new];
    event.locationInWindow=point; event.window=view.window;
    [view otherMouseDown:(NSEvent *)event];
}
static void native_test_tabs_snapshot(void *handle) {
    NSView *toolbar = [(__bridge NSView *)handle superview];
    NSBitmapImageRep *bitmap = [toolbar bitmapImageRepForCachingDisplayInRect:toolbar.bounds];
    [toolbar cacheDisplayInRect:toolbar.bounds toBitmapImageRep:bitmap];
    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@"/tmp/vox-tabs-chrome.png" atomically:YES];
}

static int native_test_tabs_accessibility(void *handle) {
    NSView *view=(__bridge NSView *)handle;
    return [view.accessibilityRole isEqualToString:NSAccessibilityRadioButtonRole]
        && [view.accessibilityLabel isEqualToString:@"Saved"];
}
