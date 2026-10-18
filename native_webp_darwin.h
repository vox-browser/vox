#ifndef VOX_NATIVE_WEBP_DARWIN_H
#define VOX_NATIVE_WEBP_DARWIN_H

#include <dlfcn.h>
#include <limits.h>

typedef int (*VoxWebPGetInfo)(const uint8_t *, size_t, int *, int *);
typedef uint8_t *(*VoxWebPDecodeRGBAInto)(const uint8_t *, size_t, uint8_t *, size_t, int);

typedef uint8_t *(*VoxWebPDecodeYUVInto)(const uint8_t *, size_t,
    uint8_t *, size_t, int, uint8_t *, size_t, int, uint8_t *, size_t, int);
static VoxWebPGetInfo get_info;
static VoxWebPDecodeRGBAInto decode_rgba;
static VoxWebPDecodeYUVInto decode_yuv;

static int native_webp_yuv_paint_supported(void) {
#ifdef LADYBIRD_V_HAS_SKIA_TEXT
    return 1;
#else
    return 0;
#endif
}
static void native_load_webp_decoder(void)
{
    static void *library;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const char *names[] = { "@rpath/libwebpdecoder.dylib", "libwebpdecoder.dylib",
            "/opt/homebrew/lib/libwebpdecoder.dylib", "/usr/local/lib/libwebpdecoder.dylib" };
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
            library = dlopen(names[i], RTLD_LAZY | RTLD_LOCAL);
            if (!library) continue;
            get_info = (VoxWebPGetInfo)dlsym(library, "WebPGetInfo");
            decode_rgba = (VoxWebPDecodeRGBAInto)dlsym(library, "WebPDecodeRGBAInto");
            decode_yuv = (VoxWebPDecodeYUVInto)dlsym(library, "WebPDecodeYUVInto");
            if (get_info && decode_rgba) break;
            dlclose(library);
            library = NULL;
            get_info = NULL;
            decode_rgba = NULL;
        }
    });
}

static int native_webp_yuv_decoder_available(void) {
    native_load_webp_decoder();
    return get_info && decode_yuv;
}

static uint8_t *native_decode_webp_yuv(const uint8_t *bytes, size_t length,
    int *width, int *height, int *size)
{
    *width = *height = *size = 0;
    // Only simple lossy, opaque, untagged images can use the YUV path.
    if (!bytes || length < 20 || memcmp(bytes, "RIFF", 4)
        || memcmp(bytes + 8, "WEBPVP8 ", 8)) return NULL;
    native_load_webp_decoder();
    int w = 0, h = 0;
    if (!get_info || !decode_yuv || !get_info(bytes, length, &w, &h)
        || w <= 0 || h <= 0 || (size_t)w * h > INT_MAX / 4) return NULL;
    int uw = (w + 1) / 2, uh = (h + 1) / 2;
    size_t y_size = (size_t)w * h, uv_size = (size_t)uw * uh;
    uint8_t *planes = malloc(y_size + 2 * uv_size);
    if (!planes) return NULL;
    if (!decode_yuv(bytes, length, planes, y_size, w,
        planes + y_size, uv_size, uw, planes + y_size + uv_size, uv_size, uw)) {
        free(planes);
        return NULL;
    }
    *width = w; *height = h; *size = (int)(y_size + 2 * uv_size);
    return planes;
}

static uint8_t *native_decode_webp_rgba(const uint8_t *bytes, size_t length,
    int *width, int *height, int *pitch)
{
    native_load_webp_decoder();
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

static uint8_t *native_decode_chromium_webp_rgba(const uint8_t *bytes, size_t length,
    int *width, int *height, int *pitch)
{
    *width = *height = *pitch = 0;
    if (!bytes || length < 21 || memcmp(bytes, "RIFF", 4)
        || memcmp(bytes + 8, "WEBPVP8X", 8) || !(bytes[20] & 32) || (bytes[20] & 2))
        return NULL;
    const uint8_t *icc = NULL;
    size_t icc_size = 0;
    for (size_t offset = 12; offset + 8 <= length;) {
        uint32_t size = (uint32_t)bytes[offset + 4] | ((uint32_t)bytes[offset + 5] << 8)
            | ((uint32_t)bytes[offset + 6] << 16) | ((uint32_t)bytes[offset + 7] << 24);
        if (size > length - offset - 8) return NULL;
        if (!memcmp(bytes + offset, "ICCP", 4)) { icc = bytes + offset + 8; icc_size = size; break; }
        offset += 8 + (size_t)size + (size & 1);
    }
    if (!icc || !icc_size || icc_size > INT_MAX) return NULL;
    typedef int (*VoxConvertIcc)(uint8_t*, int, const uint8_t*, int);
    static VoxConvertIcc convert;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (library) convert = (VoxConvertIcc)dlsym(library, "vox_graphite_convert_icc_rgba");
    });
    native_load_webp_decoder();
    int w = 0, h = 0;
    if (!convert || !get_info || !decode_rgba || !get_info(bytes, length, &w, &h)
        || w <= 0 || h <= 0 || w > INT_MAX / 4 || (size_t)w * h > INT_MAX / 4) return NULL;
    size_t size = (size_t)w * h * 4;
    uint8_t *pixels = malloc(size);
    if (!pixels) return NULL;
    if (!decode_rgba(bytes, length, pixels, size, w * 4)
        || !convert(pixels, w * h, icc, (int)icc_size)) { free(pixels); return NULL; }
    *width = w; *height = h; *pitch = w * 4;
    return pixels;
}

#endif
