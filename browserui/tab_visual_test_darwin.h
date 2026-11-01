#pragma once
#include "../native_browser_tabs_test_darwin.h"

static NSBitmapImageRep *ui2_test_tabs_bitmap(void *handle) {
    NSView *view=(__bridge NSView *)handle;
    [view.window displayIfNeeded]; [view displayIfNeeded]; [CATransaction flush];
    NSBitmapImageRep *image=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:image];
    return image;
}
static int ui2_test_tabs_capture(void *handle, const char *path) {
    NSBitmapImageRep *image=ui2_test_tabs_bitmap(handle);
    return [[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@(path) atomically:YES];
}
static uint32_t ui2_test_tabs_pixel(void *handle, double x, double y) {
    NSView *view=(__bridge NSView *)handle;
    NSBitmapImageRep *image=ui2_test_tabs_bitmap(handle);
    double scale=image.pixelsWide/view.bounds.size.width;
    // Inspect the encoded bitmap samples. colorAtX: returns calibrated colors
    // and converting those again would apply a second profile transform.
    NSUInteger samples[5]={0};
    [image getPixel:samples atX:(NSInteger)(x*scale) y:(NSInteger)(y*scale)];
    return ((uint32_t)samples[0]<<16)|((uint32_t)samples[1]<<8)|(uint32_t)samples[2];
}
