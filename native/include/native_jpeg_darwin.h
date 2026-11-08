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
typedef int (*VoxTjDecompressToYUVPlanes)(void *, const unsigned char *, unsigned long,
    unsigned char **, int, int *, int, int);

static VoxTjInitDecompress tj_init_decompress;
static VoxTjDecompressHeader3 tj_decompress_header;
static VoxTjDecompress2 tj_decompress;
static VoxTjDestroy tj_destroy;
static VoxTjDecompressToYUVPlanes tj_decompress_to_yuv_planes;

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
            tj_decompress_to_yuv_planes = (VoxTjDecompressToYUVPlanes)dlsym(library,
                "tjDecompressToYUVPlanes");
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

// Chromium hands YCbCr JPEGs, baseline or progressive, to the GPU as Y, Cb
// and Cr planes and converts them with full-range BT.601 while sampling the
// chroma planes bilinearly. Supports 4:2:0 (chroma_subsampling 2) and 4:4:4
// (chroma_subsampling 0). Returns the packed planes, or NULL for any other
// stream.
static uint8_t *native_decode_jpeg_yuv(const uint8_t *bytes, size_t length,
    int *width, int *height, int *size, int *chroma_subsampling)
{
    *width = *height = *size = *chroma_subsampling = 0;
    if (!bytes || length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF
        || length > ULONG_MAX || native_jpeg_has_color_profile(bytes, length)) return NULL;
    native_load_jpeg_decoder();
    if (!tj_init_decompress || !tj_decompress_to_yuv_planes) return NULL;
    void *handle = tj_init_decompress();
    if (!handle) return NULL;
    int w = 0, h = 0, subsampling = 0, colorspace = 0;
    uint8_t *planes = NULL;
    size_t y_size = 0, uv_size = 0;
    // TJSAMP_444 = 0, TJSAMP_420 = 2, TJCS_YCbCr = 1.
    if (!tj_decompress_header(handle, bytes, (unsigned long)length, &w, &h, &subsampling,
            &colorspace) && w > 0 && h > 0 && (subsampling == 0 || subsampling == 2)
        && colorspace == 1 && (size_t)w * h <= INT_MAX / 4) {
        int halved = subsampling == 2;
        int uv_width = halved ? (w + 1) / 2 : w, uv_height = halved ? (h + 1) / 2 : h;
        // TurboJPEG pads the luma plane to the even 4:2:0 dimensions.
        int padded_width = halved ? uv_width * 2 : w, padded_height = halved ? uv_height * 2 : h;
        size_t padded_y_size = (size_t)padded_width * padded_height;
        y_size = (size_t)w * h;
        uv_size = (size_t)uv_width * uv_height;
        planes = malloc(padded_y_size + 2 * uv_size);
        unsigned char *destinations[3] = { planes, planes + padded_y_size,
            planes + padded_y_size + uv_size };
        int strides[3] = { padded_width, uv_width, uv_width };
        if (planes && tj_decompress_to_yuv_planes(handle, bytes, (unsigned long)length,
                destinations, w, strides, h, 0)) {
            free(planes);
            planes = NULL;
        }
        if (planes && padded_y_size != y_size) {
            // Pack the luma rows and both chroma planes for the painter.
            for (int row = 1; row < h; ++row)
                memmove(planes + (size_t)row * w, planes + (size_t)row * padded_width, (size_t)w);
            memmove(planes + y_size, planes + padded_y_size, 2 * uv_size);
        }
    }
    tj_destroy(handle);
    if (!planes) return NULL;
    *width = w; *height = h; *size = (int)(y_size + 2 * uv_size);
    *chroma_subsampling = subsampling;
    return planes;
}

static void native_free_jpeg_pixels(uint8_t *pixels) { free(pixels); }

#endif
