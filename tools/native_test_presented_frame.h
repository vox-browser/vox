#pragma once
#import <Cocoa/Cocoa.h>
#import <IOSurface/IOSurface.h>
#include <stdint.h>
#include <string.h>

// Injected browser checks accept both immutable-image and shared-surface
// presentation. Inspect on the main thread, between browser paint callbacks.
static CGSize native_test_presented_size(id contents) {
    if (!contents) return CGSizeZero;
    CFTypeID type = CFGetTypeID((__bridge CFTypeRef)contents);
    if (type == CGImageGetTypeID()) {
        CGImageRef image = (__bridge CGImageRef)contents;
        return CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    }
    if (type == IOSurfaceGetTypeID()) {
        IOSurfaceRef surface = (__bridge IOSurfaceRef)contents;
        return CGSizeMake(IOSurfaceGetWidth(surface), IOSurfaceGetHeight(surface));
    }
    return CGSizeZero;
}

static NSData *native_test_presented_pixels(id contents) {
    CGSize size = native_test_presented_size(contents);
    size_t width = size.width, height = size.height;
    if (!width || !height || width > SIZE_MAX / 4 / height) return nil;
    const uint8_t *pixels = NULL;
    size_t pitch = 0;
    CFDataRef data = NULL;
    IOSurfaceRef surface = NULL;
    if (CFGetTypeID((__bridge CFTypeRef)contents) == CGImageGetTypeID()) {
        CGImageRef image = (__bridge CGImageRef)contents;
        pitch = CGImageGetBytesPerRow(image);
        if (CGImageGetBitsPerPixel(image) != 32 || pitch > SIZE_MAX / height) return nil;
        data = CGDataProviderCopyData(CGImageGetDataProvider(image));
        if (data && (size_t)CFDataGetLength(data) >= pitch * height) pixels = CFDataGetBytePtr(data);
    } else {
        surface = (__bridge IOSurfaceRef)contents;
        if (IOSurfaceGetPixelFormat(surface) != (uint32_t)'RGBA'
            || IOSurfaceLock(surface, kIOSurfaceLockReadOnly, NULL) != kIOReturnSuccess) return nil;
        pixels = (const uint8_t *)IOSurfaceGetBaseAddress(surface);
        pitch = IOSurfaceGetBytesPerRow(surface);
    }
    NSMutableData *result = nil;
    if (pixels && pitch >= width * 4) {
        result = [NSMutableData dataWithLength:width * 4 * height];
        for (size_t y = 0; y < height; ++y)
            memcpy((uint8_t *)result.mutableBytes + y * width * 4, pixels + y * pitch, width * 4);
    }
    if (surface) IOSurfaceUnlock(surface, kIOSurfaceLockReadOnly, NULL);
    if (data) CFRelease(data);
    return result;
}
