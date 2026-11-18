#ifndef VOX_NATIVE_SVG_MASK_IMAGE_DARWIN_H
#define VOX_NATIVE_SVG_MASK_IMAGE_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include "native_svg_mask_pixels.h"

static inline CGImageRef native_snapshot_svg_rgba_mask_bitmap(CGContextRef context, int is_luminance)
{
	CGContextFlush(context);
	uint8_t *pixels = CGBitmapContextGetData(context);
	if (pixels == NULL) {
		return NULL;
	}
	size_t pitch = CGBitmapContextGetBytesPerRow(context);
	native_convert_rgba_svg_mask_pixels(pixels, pitch, pixels, pitch,
		CGBitmapContextGetWidth(context), CGBitmapContextGetHeight(context), is_luminance);
	// Both mask compositing paths consume alpha from premultiplied white.
	return CGBitmapContextCreateImage(context);
}

static inline CGImageRef native_copy_svg_mask_bitmap(CGContextRef context, int is_color,
	int is_luminance)
{
	size_t width = CGBitmapContextGetWidth(context);
	size_t height = CGBitmapContextGetHeight(context);
	size_t source_stride = CGBitmapContextGetBytesPerRow(context);
	CGContextFlush(context);
	const uint8_t *source = CGBitmapContextGetData(context);
	if (source == NULL) {
		return NULL;
	}
	CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
	CGContextRef mask_context = CGBitmapContextCreate(NULL, width, height, 8,
		width * 4, color_space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(color_space);
	if (mask_context == NULL) {
		return NULL;
	}
	CGImageRef image = NULL;
	uint8_t *mask = CGBitmapContextGetData(mask_context);
	if (mask != NULL) {
		native_convert_svg_mask_pixels(source, source_stride, mask,
			CGBitmapContextGetBytesPerRow(mask_context), width, height, is_color, is_luminance);
		image = CGBitmapContextCreateImage(mask_context);
	}
	CGContextRelease(mask_context);
	return image;
}

#endif
