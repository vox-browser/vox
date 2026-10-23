#pragma once
#import <Cocoa/Cocoa.h>
#include <stdlib.h>

// Exercise the real Cocoa drawing path without a window or Sokol setup.
static CGContextRef vox_tabs_test_context;
static unsigned char *vox_tabs_test_pixels;
static int vox_tabs_test_width;
static int vox_tabs_test_height;

static int native_test_portable_tabs_begin(int width, int height) {
	vox_tabs_test_pixels = calloc((size_t)width * height, 4);
	CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	vox_tabs_test_context = CGBitmapContextCreate(vox_tabs_test_pixels, width,
		height, 8, (size_t)width * 4, space,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(space);
	if (!vox_tabs_test_context) {
		free(vox_tabs_test_pixels);
		vox_tabs_test_pixels = NULL;
		return 0;
	}
	vox_tabs_test_width = width;
	vox_tabs_test_height = height;
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:
		[NSGraphicsContext graphicsContextWithCGContext:vox_tabs_test_context flipped:NO]];
	return 1;
}

static unsigned int native_test_portable_tabs_pixel(int x, int y) {
	CGContextFlush(vox_tabs_test_context);
	// CoreGraphics bitmap storage already has the top document row first.
	const unsigned char *p = vox_tabs_test_pixels
		+ ((size_t)y * vox_tabs_test_width + x) * 4;
	return ((unsigned int)p[0] << 24) | ((unsigned int)p[1] << 16)
		| ((unsigned int)p[2] << 8) | p[3];
}

static void native_test_portable_tabs_end(void) {
	[NSGraphicsContext restoreGraphicsState];
	CGContextRelease(vox_tabs_test_context);
	vox_tabs_test_context = NULL;
	free(vox_tabs_test_pixels);
	vox_tabs_test_pixels = NULL;
}
