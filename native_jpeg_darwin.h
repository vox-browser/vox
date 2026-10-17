#ifndef VOX_NATIVE_JPEG_DARWIN_H
#define VOX_NATIVE_JPEG_DARWIN_H

#include <dlfcn.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

// Chromium decodes JPEG through libjpeg-turbo with its default islow IDCT and
// fancy chroma upsampling. TurboJPEG's default decompression uses the same
// settings, so Chromium-policy documents decode JPEG pixels with it instead of
// stb_image, whose integer IDCT and upsampling differ by a few levels.
typedef void *(*VoxTjInitDecompress)(void);
typedef int (*VoxTjDecompressHeader3)(void *, const unsigned char *, unsigned long,
    int *, int *, int *, int *);
typedef int (*VoxTjDecompress2)(void *, const unsigned char *, unsigned long,
    unsigned char *, int, int, int, int, int);
typedef int (*VoxTjDestroy)(void *);

static VoxTjInitDecompress tj_init_decompress;
static VoxTjDecompressHeader3 tj_decompress_header;
static VoxTjDecompress2 tj_decompress;
static VoxTjDestroy tj_destroy;

static void native_load_jpeg_decoder(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const char *names[] = { "@rpath/libturbojpeg.0.dylib", "libturbojpeg.0.dylib",
            "/opt/homebrew/opt/jpeg-turbo/lib/libturbojpeg.0.dylib",
            "/usr/local/opt/jpeg-turbo/lib/libturbojpeg.0.dylib" };
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
            void *library = dlopen(names[i], RTLD_LAZY | RTLD_LOCAL);
            if (!library) continue;
            tj_init_decompress = (VoxTjInitDecompress)dlsym(library, "tjInitDecompress");
            tj_decompress_header = (VoxTjDecompressHeader3)dlsym(library, "tjDecompressHeader3");
            tj_decompress = (VoxTjDecompress2)dlsym(library, "tjDecompress2");
            tj_destroy = (VoxTjDestroy)dlsym(library, "tjDestroy");
            if (tj_init_decompress && tj_decompress_header && tj_decompress && tj_destroy) break;
            dlclose(library);
            tj_init_decompress = NULL;
            tj_decompress_header = NULL;
            tj_decompress = NULL;
            tj_destroy = NULL;
        }
    });
}

// An embedded ICC profile needs the existing color-managed decoder.
static int native_jpeg_has_color_profile(const uint8_t *bytes, size_t length)
{
    size_t offset = 2;
    while (offset + 4 <= length && bytes[offset] == 0xFF) {
        uint8_t marker = bytes[offset + 1];
        if (marker == 0xDA || marker == 0xD9) break;
        size_t segment = ((size_t)bytes[offset + 2] << 8) | bytes[offset + 3];
        if (segment < 2 || offset + 2 + segment > length) break;
        if (marker == 0xE2 && segment >= 14 && !memcmp(bytes + offset + 4, "ICC_PROFILE", 12))
            return 1;
        offset += 2 + segment;
    }
    return 0;
}

// Returns tightly packed, top-down, opaque RGBA rows, or NULL when the stream
// is not a JPEG this decoder handles.
static uint8_t *native_decode_jpeg_rgba(const uint8_t *bytes, size_t length,
    int *width, int *height, int *pitch)
{
    *width = *height = *pitch = 0;
    if (!bytes || length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF
        || length > ULONG_MAX || native_jpeg_has_color_profile(bytes, length)) return NULL;
    native_load_jpeg_decoder();
    if (!tj_init_decompress) return NULL;
    void *handle = tj_init_decompress();
    if (!handle) return NULL;
    int w = 0, h = 0, subsampling = 0, colorspace = 0;
    uint8_t *pixels = NULL;
    // TJCS_RGB = 0, TJCS_YCbCr = 1, TJCS_GRAY = 2; CMYK and YCCK stay native.
    if (!tj_decompress_header(handle, bytes, (unsigned long)length, &w, &h, &subsampling,
            &colorspace) && w > 0 && h > 0 && colorspace <= 2 && w <= INT_MAX / 4
        && (size_t)w * h <= INT_MAX / 4) {
        pixels = malloc((size_t)w * h * 4);
        // TJPF_RGBA = 7 with default flags: no fast upsampling or fast IDCT.
        if (pixels && tj_decompress(handle, bytes, (unsigned long)length, pixels, w, w * 4, h,
                7, 0)) {
            free(pixels);
            pixels = NULL;
        }
    }
    tj_destroy(handle);
    if (!pixels) return NULL;
    *width = w; *height = h; *pitch = w * 4;
    return pixels;
}

static void native_free_jpeg_pixels(uint8_t *pixels) { free(pixels); }

#endif
