#pragma once
#import <Cocoa/Cocoa.h>
#include <stdint.h>
#include <stdio.h>

#ifndef VOX_DOCUMENT_COLOR_BRIDGE
// Standalone native-header consumers retain their existing sRGB contract.
static CGColorSpaceRef native_copy_document_render_space(void) CF_RETURNS_RETAINED {
    return CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
}
#else

// Document rendering policy and numerical color conversion belong to V.
extern int vox_document_display_p3_enabled(void);
extern uint8_t *vox_document_display_p3_profile(int *);
extern void vox_document_srgb_to_p3(float *);
extern void vox_document_p3_to_srgb_pixels(uint8_t *, int, int, int);

VOX_NATIVE_STATE CGColorSpaceRef native_document_render_space;
VOX_NATIVE_STATE dispatch_once_t native_document_render_space_once;
VOX_NATIVE_STATE int native_document_render_space_is_p3;

static CGColorSpaceRef native_copy_document_render_space(void) CF_RETURNS_RETAINED {
    dispatch_once(&native_document_render_space_once, ^{
        int length = 0;
        uint8_t *bytes = vox_document_display_p3_profile(&length);
        if (bytes && length > 0) {
            CFDataRef data = CFDataCreate(NULL, bytes, length);
            if (data) {
                native_document_render_space = CGColorSpaceCreateWithICCData(data);
                native_document_render_space_is_p3 = native_document_render_space != NULL;
                CFRelease(data);
            }
        }
        if (!native_document_render_space)
            native_document_render_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        if (vox_document_display_p3_enabled())
            fprintf(stderr, "VOX_DOCUMENT_P3_PROFILE bytes=%d active=%d\n", length,
                native_document_render_space_is_p3);
    });
    return native_document_render_space ? CGColorSpaceRetain(native_document_render_space) : NULL;
}

int native_document_raster_uses_p3(void) {
    if (!vox_document_display_p3_enabled()) return 0;
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGColorSpaceRef current = context ? CGBitmapContextGetColorSpace(context) : NULL;
    CGColorSpaceRef expected = native_copy_document_render_space();
    int matches = native_document_render_space_is_p3 && current && expected && CFEqual(current, expected);
    if (expected) CGColorSpaceRelease(expected);
    return matches;
}

static CGColorRef native_document_srgb_components(const CGFloat *components) CF_RETURNS_RETAINED {
    if (!native_document_raster_uses_p3()) {
        CGColorSpaceRef space = vox_document_display_p3_enabled()
            ? CGColorSpaceCreateWithName(kCGColorSpaceSRGB) : native_copy_document_render_space();
        CGColorRef color = space ? CGColorCreate(space, components) : NULL;
        if (space) CGColorSpaceRelease(space);
        return color;
    }
    float rgba[4] = {components[0], components[1], components[2], components[3]};
    vox_document_srgb_to_p3(rgba);
    CGColorSpaceRef space = native_copy_document_render_space();
    CGFloat converted[4] = {rgba[0], rgba[1], rgba[2], rgba[3]};
    CGColorRef color = space ? CGColorCreate(space, converted) : NULL;
    if (space) CGColorSpaceRelease(space);
    return color;
}
#endif
