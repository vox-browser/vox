#ifndef VOX_NATIVE_FLOAT_IMAGE_H
#define VOX_NATIVE_FLOAT_IMAGE_H
#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#define VOX_FLOAT_RGBA_CHANNEL_MARKER 14
static int native_float_image_channel_marker(void) { return VOX_FLOAT_RGBA_CHANNEL_MARKER; }

// A small photographic paint variant retains fractional RGB through coverage.
// Its ordinary platform fallback must understand the same straight RGBA rows.
static CGImageRef native_copy_float_rgba_image(const float *pixels, int width, int height) {
    if (!pixels || width<=0 || height<=0 || width>32 || height>32 || width*height>256) return NULL;
    CGDataProviderRef provider=CGDataProviderCreateWithData(NULL,pixels,(size_t)width*height*16,NULL);
    if (!provider) return NULL;
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image=CGImageCreate(width,height,32,128,(size_t)width*16,space,
        kCGImageAlphaLast|kCGBitmapFloatComponents|kCGBitmapByteOrder32Host,
        provider,NULL,false,kCGRenderingIntentDefault);
    CGColorSpaceRelease(space);CGDataProviderRelease(provider);
    return image;
}
#endif
