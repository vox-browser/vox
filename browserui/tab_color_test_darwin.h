#pragma once
#include "tab_visual_test_darwin.h"

static int ui2_test_tab_color_menu(void *handle) {
    NSMenu *menu = [(__bridge NSView *)handle menu];
    if (menu.numberOfItems != 1 || ![[menu itemAtIndex:0].title isEqualToString:@"Tab Color…"]) return 0;
    [menu performActionForItemAtIndex:0];
    return 1;
}
static int ui2_test_tab_menu_count(void *handle) {
    return (int)[(__bridge NSView *)handle menu].numberOfItems;
}
static uint32_t ui2_test_tab_color_pixel(void *handle, double x, double y) {
    NSView *view = (__bridge NSView *)handle;
    // Window snapshots inherit the display profile. Compare palette colors in
    // their declared sRGB space, including on wide-gamut test displays.
    NSBitmapImageRep *bitmap = [ui2_test_tabs_bitmap(handle)
        bitmapImageRepByConvertingToColorSpace:NSColorSpace.sRGBColorSpace
        renderingIntent:NSColorRenderingIntentDefault];
    double scale = bitmap.pixelsWide / view.bounds.size.width;
    NSUInteger samples[5] = {0};
    [bitmap getPixel:samples atX:(NSInteger)(x * scale) y:(NSInteger)(y * scale)];
    return ((uint32_t)samples[0] << 16) | ((uint32_t)samples[1] << 8) | (uint32_t)samples[2];
}
