#ifndef VOX_NATIVE_PNG_COLOR_DARWIN_H
#define VOX_NATIVE_PNG_COLOR_DARWIN_H

#import <Foundation/Foundation.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include "native_png_icc_darwin.h"

// Skia's PNG codec, which Chromium uses, tags an image with a color profile
// built from its gAMA and cHRM chunks; the GPU raster converts it to the
// destination while drawing. stb_image returns the encoded values unchanged.
// A profile is: [0] inverse gamma, [1] whether primaries follow, [2..9] the
// red, green, blue and white x/y chromaticities.
typedef struct {
    float values[10];
} VoxPngColorProfile;

static uint32_t native_png_read_u32(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16)
        | ((uint32_t)bytes[2] << 8) | bytes[3];
}

// Mirrors SkPngRustCodec's CreateColorProfile(): cICP, iCCP and sRGB chunks
// take precedence and are not handled here; gAMA is required, and gAMA alone
// within 5% of 1/2.2 is treated as untagged.
static int native_png_color_profile(const uint8_t *bytes, size_t length, VoxPngColorProfile *profile)
{
    static const uint8_t signature[8] = { 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n' };
    if (!bytes || length < 8 || memcmp(bytes, signature, 8)) return 0;
    float gamma = 0;
    int has_gamma = 0, has_chrm = 0;
    float chrm[8];
    size_t offset = 8;
    while (offset + 12 <= length) {
        uint32_t chunk_length = native_png_read_u32(bytes + offset);
        const uint8_t *type = bytes + offset + 4;
        const uint8_t *data = bytes + offset + 8;
        if (chunk_length > length - offset - 12) break;
        if (!memcmp(type, "IDAT", 4) || !memcmp(type, "IEND", 4)) break;
        if (!memcmp(type, "cICP", 4) || !memcmp(type, "iCCP", 4) || !memcmp(type, "sRGB", 4))
            return 0;
        if (!memcmp(type, "gAMA", 4) && chunk_length == 4) {
            gamma = native_png_read_u32(data) / 100000.0f;
            has_gamma = 1;
        }
        if (!memcmp(type, "cHRM", 4) && chunk_length == 32) {
            // The chunk orders white, red, green and blue.
            for (int index = 0; index < 8; ++index)
                chrm[index] = native_png_read_u32(data + 4 * index) / 100000.0f;
            has_chrm = 1;
        }
        offset += 12 + chunk_length;
    }
    if (!has_gamma || !(gamma > 0)) return 0;
    if (!has_chrm) {
        float neutral = gamma * 2.2f;
        if (neutral > 0.95f && neutral < 1.05f) return 0;
    }
    memset(profile, 0, sizeof(*profile));
    profile->values[0] = 1.0f / gamma;
    profile->values[1] = has_chrm;
    if (has_chrm) {
        // Red, green, blue, then white.
        for (int index = 0; index < 6; ++index) profile->values[2 + index] = chrm[2 + index];
        profile->values[8] = chrm[0];
        profile->values[9] = chrm[1];
    }
    return 1;
}

static int native_png_has_color_profile(const uint8_t *bytes, size_t length)
{
    VoxPngColorProfile profile;
    return native_png_icc_data(bytes, length) != nil
        || native_png_color_profile(bytes, length, &profile);
}

typedef struct {
    int width, height;
    VoxPngColorProfile profile;
} VoxTaggedImageColorProfile;

static NSMutableDictionary<NSValue *, NSData *> *native_png_color_profiles;

// Associate a decoded raster with the color profile of its encoded PNG, or
// clear a stale association for a reused buffer when the image is untagged or
// tagging is disabled. Lookups also match the dimensions, so a buffer later
// reused by an unrelated image of another size is never converted.
void native_tag_image_color_profile(const void *pixels, int width, int height,
    const uint8_t *bytes, size_t length, int enabled)
{
    if (!pixels) return;
    native_tag_png_icc_profile(pixels, width, height,
        enabled ? native_png_icc_data(bytes, length) : nil);
    VoxTaggedImageColorProfile tagged = { width, height };
    int has_profile = enabled && native_png_color_profile(bytes, length, &tagged.profile);
    @synchronized ([NSValue class]) {
        NSValue *key = [NSValue valueWithPointer:pixels];
        if (!has_profile) {
            [native_png_color_profiles removeObjectForKey:key];
            return;
        }
        if (!native_png_color_profiles) native_png_color_profiles = [NSMutableDictionary dictionary];
        native_png_color_profiles[key] = [NSData dataWithBytes:&tagged length:sizeof(tagged)];
    }
}

static int native_image_color_profile(const void *pixels, int width, int height,
    VoxPngColorProfile *profile)
{
    if (!pixels) return 0;
    @synchronized ([NSValue class]) {
        NSData *data = native_png_color_profiles[[NSValue valueWithPointer:pixels]];
        if (!data) return 0;
        VoxTaggedImageColorProfile const *tagged = data.bytes;
        if (tagged->width != width || tagged->height != height) return 0;
        *profile = tagged->profile;
        return 1;
    }
}

#endif
