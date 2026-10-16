#ifndef VOX_NATIVE_WEBP_DARWIN_H
#define VOX_NATIVE_WEBP_DARWIN_H

#include <dlfcn.h>
#include <limits.h>

typedef int (*VoxWebPGetInfo)(const uint8_t *, size_t, int *, int *);
typedef uint8_t *(*VoxWebPDecodeRGBAInto)(const uint8_t *, size_t, uint8_t *, size_t, int);

static uint8_t *native_decode_webp_rgba(const uint8_t *bytes, size_t length,
    int *width, int *height, int *pitch)
{
    static void *library;
    static VoxWebPGetInfo get_info;
    static VoxWebPDecodeRGBAInto decode_rgba;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const char *names[] = { "@rpath/libwebpdecoder.dylib", "libwebpdecoder.dylib",
            "/opt/homebrew/lib/libwebpdecoder.dylib", "/usr/local/lib/libwebpdecoder.dylib" };
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
            library = dlopen(names[i], RTLD_LAZY | RTLD_LOCAL);
            if (!library) continue;
            get_info = (VoxWebPGetInfo)dlsym(library, "WebPGetInfo");
            decode_rgba = (VoxWebPDecodeRGBAInto)dlsym(library, "WebPDecodeRGBAInto");
            if (get_info && decode_rgba) break;
            dlclose(library);
            library = NULL;
            get_info = NULL;
            decode_rgba = NULL;
        }
    });
    *width = *height = *pitch = 0;
    if (!bytes || !length) return NULL;
    bool extended = length >= 21 && !memcmp(bytes + 12, "VP8X", 4);
    // Animated streams retain the native image provider's existing playback
    // path. ICC-tagged streams need its color conversion before reaching sRGB.
    if (extended && (bytes[20] & 2)) return NULL;
    bool has_color_profile = extended && (bytes[20] & 32);
    if (get_info && decode_rgba && !has_color_profile) {
        int w = 0, h = 0;
        if (!get_info(bytes, length, &w, &h) || w <= 0 || h <= 0
            || w > INT_MAX / 4 || (size_t)w * h > INT_MAX / 4) return NULL;
        size_t size = (size_t)w * h * 4;
        uint8_t *pixels = malloc(size);
        if (!pixels) return NULL;
        if (!decode_rgba(bytes, length, pixels, size, w * 4)) {
            free(pixels);
            return NULL;
        }
        *width = w; *height = h; *pitch = w * 4;
        return pixels;
    }
    // Keep the existing native image provider available without an optional
    // libwebp installation. The encoded stream retains its color profile.
    @autoreleasepool {
        NSBitmapImageRep *image = [NSBitmapImageRep imageRepWithData:
            [NSData dataWithBytes:bytes length:length]];
        CGImageRef source = image.CGImage;
        if (!source) return NULL;
        size_t w = CGImageGetWidth(source), h = CGImageGetHeight(source);
        if (!w || !h || w > INT_MAX / 4 || w * h > INT_MAX / 4) return NULL;
        uint8_t *pixels = calloc(h, w * 4);
        if (!pixels) return NULL;
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context = CGBitmapContextCreate(pixels, w, h, 8, w * 4,
            space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space);
        if (!context) { free(pixels); return NULL; }
        CGContextDrawImage(context, CGRectMake(0, 0, w, h), source);
        CGContextRelease(context);
        for (size_t offset = 0; offset < w * h * 4; offset += 4) {
            unsigned alpha = pixels[offset + 3];
            if (alpha && alpha != 255) {
                for (int channel = 0; channel < 3; ++channel)
                    pixels[offset + channel] = MIN(255, (pixels[offset + channel] * 255 + alpha / 2) / alpha);
            }
        }
        *width = (int)w; *height = (int)h; *pitch = (int)w * 4;
        return pixels;
    }
}

static void native_free_webp_pixels(uint8_t *pixels) { free(pixels); }

#endif
