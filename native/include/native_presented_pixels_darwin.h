#ifndef VOX_NATIVE_PRESENTED_PIXELS_DARWIN_H
#define VOX_NATIVE_PRESENTED_PIXELS_DARWIN_H

#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <stddef.h>
#include <stdint.h>

// A presented-frame capture verified its region as opaque, byte-ordered sRGB
// RGBA. The bitmap rep it returns only wraps those bytes; the PNG encoder reads
// them through this record instead of materializing the rep's own copy. The
// rep's CGImage keeps the bytes alive.
typedef struct {
    const uint8_t *pixels;
    size_t width, height, pitch;
} NativePresentedPixels;

static char native_presented_pixels_key;

static inline void native_presented_pixels_attach(id rep, NativePresentedPixels layout)
{
    objc_setAssociatedObject(rep, &native_presented_pixels_key,
        [NSData dataWithBytes:&layout length:sizeof layout], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static inline BOOL native_presented_pixels_for(id rep, NativePresentedPixels *layout)
{
    NSData *record = objc_getAssociatedObject(rep, &native_presented_pixels_key);
    if (record.length != sizeof *layout) return NO;
    memcpy(layout, record.bytes, sizeof *layout);
    return layout->pixels != NULL && layout->width && layout->height && layout->pitch >= layout->width * 4;
}

#endif
