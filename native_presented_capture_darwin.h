#pragma once
#include "native_rgba_is_opaque.h"

// Export an unchanged, opaque document region directly from its immutable
// presented sRGB frame. Overlays, scaling, clipping or unsupported formats keep
// AppKit's normal subtree capture and color conversion.
static NSBitmapImageRep *native_presented_capture_bitmap(NSView *root, NSRect bounds,
    NSInteger width, NSInteger height) {
    if (getenv("VOX_DISABLE_PRESENTED_CAPTURE") || !root || width <= 0 || height <= 0
        || width > 16384 || height > 16384 || (size_t)width * height > 16 * 1024 * 1024
        || !NSContainsRect(root.bounds, bounds)) return nil;
    CGFloat scale = width / bounds.size.width;
    if (!isfinite(scale) || scale <= 0 || height != bounds.size.height * scale) return nil;
    CGFloat previous_scale = native_layer_capture_scale;
    native_layer_capture_scale = scale;
    @try {
        native_layer_prepare_capture(root, YES);
        NSMutableArray<NSView *> *pending = [NSMutableArray arrayWithObject:root];
        NSView *canvas = nil;
        while (pending.count) {
            NSView *view = pending.lastObject; [pending removeLastObject];
            if (view.hidden || view.alphaValue == 0) continue;
            NSRect region = [view convertRect:bounds fromView:root];
            if (!NSIntersectsRect(view.bounds, region)) continue;
            if (native_layer_is_browser_view(view)) {
                if (canvas) return nil;
                canvas = view;
            }
            [pending addObjectsFromArray:view.subviews];
        }
        if (!canvas || canvas.alphaValue != 1 || !native_layer_frame_is_current(canvas, scale)) return nil;
        NSView *branch = nil;
        for (NSView *view = canvas; view; branch = view, view = view.superview) {
            NSRect region = [view convertRect:bounds fromView:root];
            if (view.hidden || view.alphaValue != 1 || !NSContainsRect(view.bounds, region)
                || (view.layer && (!CATransform3DIsIdentity(view.layer.transform)
                    || !CATransform3DIsIdentity(view.layer.sublayerTransform)
                    || view.layer.filters.count || view.layer.backgroundFilters.count
                    || view.layer.compositingFilter || view.layer.animationKeys.count
                    || view.layer.mask || view.layer.opacity != 1
                    || (view.layer.masksToBounds && view.layer.cornerRadius != 0)))) return nil;
            for (CALayer *sublayer in view.layer.sublayers) {
                BOOL child_layer = NO;
                for (NSView *child in view.subviews) child_layer |= child.layer == sublayer;
                if (!child_layer) return nil;
            }
            for (NSView *child in view.subviews) {
                if (child == branch || child.hidden || child.alphaValue == 0) continue;
                if (NSIntersectsRect(child.bounds, [child convertRect:bounds fromView:root])) return nil;
            }
            if (view == root) break;
        }
        CALayer *layer = canvas.layer;
        if (!CGRectEqualToRect(layer.contentsRect, CGRectMake(0,0,1,1))) return nil;
        NSPoint zero = [canvas convertPoint:NSMakePoint(0,0) toView:root];
        NSPoint unit = [canvas convertPoint:NSMakePoint(1,1) toView:root];
        if (unit.x - zero.x != 1 || fabs(unit.y - zero.y) != 1) return nil;
        CGImageRef image = (__bridge CGImageRef)layer.contents;
        if (CGImageGetBitsPerComponent(image) != 8 || CGImageGetBitsPerPixel(image) != 32
            || CGImageGetBitmapInfo(image) != (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)) return nil;
        CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        BOOL same_space = srgb && CGImageGetColorSpace(image) && CFEqual(srgb, CGImageGetColorSpace(image));
        if (srgb) CGColorSpaceRelease(srgb);
        if (!same_space) return nil;
        NSRect region = [canvas convertRect:bounds fromView:root];
        double left = (NSMinX(region) - NSMinX(canvas.bounds)) * scale;
        double top = (canvas.isFlipped ? NSMinY(region) - NSMinY(canvas.bounds)
            : NSMaxY(canvas.bounds) - NSMaxY(region)) * scale;
        if (!isfinite(left) || !isfinite(top) || left < 0 || top < 0
            || left != floor(left) || top != floor(top)
            || left + width > CGImageGetWidth(image) || top + height > CGImageGetHeight(image)) return nil;
        size_t pitch = CGImageGetBytesPerRow(image), rows = CGImageGetHeight(image);
        if (pitch < CGImageGetWidth(image) * 4 || !rows || pitch > SIZE_MAX / rows
            || pitch * rows > 64 * 1024 * 1024) return nil;
        CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
        if (!data) return nil;
        NSBitmapImageRep *result = nil;
        @try {
            if ((size_t)CFDataGetLength(data) < pitch * rows) return nil;
            const uint8_t *pixels = CFDataGetBytePtr(data) + (size_t)top * pitch + (size_t)left * 4;
            if (!vox_rgba8_is_opaque(pixels, width, height, pitch)) return nil;
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4
                hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
                bytesPerRow:width * 4 bitsPerPixel:32];
            if (!bitmap || !bitmap.bitmapData) return nil;
            for (NSInteger y = 0; y < height; ++y)
                memcpy(bitmap.bitmapData + y * bitmap.bytesPerRow, pixels + y * pitch, width * 4);
            // The ordinary sRGB conversion creates a pixel-sized image rep,
            // discarding the input's logical size. Preserve that existing PNG
            // density/Exif contract when omitting the conversion.
            bitmap.size = NSMakeSize(width, height);
            // Retag bytes whose source is already sRGB; converting them from
            // the display's device space would introduce an unnecessary pass.
            result = [bitmap bitmapImageRepByRetaggingWithColorSpace:NSColorSpace.sRGBColorSpace];
#if !__has_feature(objc_arc)
            [bitmap release];
#endif
            if (result && getenv("VOX_PRESENTED_CAPTURE_DIAGNOSTICS"))
                fprintf(stderr, "VOX_PRESENTED_CAPTURE %ldx%ld scale=%g\n", (long)width, (long)height, (double)scale);
        } @finally { CFRelease(data); }
        return result;
    } @finally {
        native_layer_capture_scale = previous_scale;
        native_layer_prepare_capture(root, NO);
    }
}
