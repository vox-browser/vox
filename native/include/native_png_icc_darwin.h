#ifndef VOX_NATIVE_PNG_ICC_DARWIN_H
#define VOX_NATIVE_PNG_ICC_DARWIN_H
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
#include <limits.h>
#include <stdlib.h>
#include "native_image_color_profile.h"
#include "../../platform/native_state.h"

// Packed, top-down, straight RGBA with a separately retained PNG ICC profile.
// Ordinary RGBA and planar YUV buffers must never consult the ICC pointer map.
#define VOX_PNG_ICC_CHANNEL_MARKER 11
static int native_png_icc_channel_marker(void) { return VOX_PNG_ICC_CHANNEL_MARKER; }

static uint32_t native_png_icc_u32(const uint8_t *p)
{
    return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3];
}

// Inflates a zlib stream of at most `limit` decoded bytes into malloc'd
// storage the caller frees, or returns NULL. Vox links no zlib: the browser
// registers vlib's V inflater at startup (images/png_icc.v).
typedef uint8_t *(*VoxPngIccInflate)(const uint8_t *input, size_t length, size_t limit,
    size_t *output_length);
VOX_NATIVE_STATE VoxPngIccInflate native_png_icc_inflate;
static void native_png_icc_set_inflater(VoxPngIccInflate inflate) { native_png_icc_inflate = inflate; }

static NSData *native_png_icc_data(const uint8_t *bytes, size_t length)
{
    static const uint8_t signature[8] = { 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n' };
    if (!bytes || length < 20 || memcmp(bytes, signature, 8)) return nil;
    const uint8_t *compressed = NULL;
    uint32_t compressed_length = 0;
    for (size_t offset = 8; offset <= length - 12;) {
        uint32_t size = native_png_icc_u32(bytes + offset);
        if (size > length - offset - 12) return nil;
        const uint8_t *type = bytes + offset + 4;
        const uint8_t *data = bytes + offset + 8;
        if (!memcmp(type, "IDAT", 4) || !memcmp(type, "IEND", 4)) break;
        // Keep the existing higher-priority cICP path separate.
        if (!memcmp(type, "cICP", 4)) return nil;
        if (!memcmp(type, "iCCP", 4) && !compressed) {
            size_t name = 0;
            while (name < size && data[name]) ++name;
            if (!name || name > 79 || name + 2 >= size || data[name + 1] != 0) return nil;
            compressed = data + name + 2;
            compressed_length = size - (uint32_t)name - 2;
        }
        offset += 12 + size;
    }
    if (!compressed) return nil;
    const size_t maximum_size = 16 * 1024 * 1024;
    if (!native_png_icc_inflate) return nil;
    size_t decoded_length = 0;
    uint8_t *icc = native_png_icc_inflate(compressed, compressed_length, maximum_size, &decoded_length);
    if (!icc) return nil;
    uint32_t declared_size = decoded_length < 128 ? 0 : native_png_icc_u32(icc);
    if (declared_size < 128 || declared_size > decoded_length || memcmp(icc + 36, "acsp", 4)) {
        free(icc);
        return nil;
    }
    return [NSData dataWithBytesNoCopy:icc length:declared_size freeWhenDone:YES];
}

static int native_png_has_icc_profile(const uint8_t *bytes, size_t length)
{
    return native_png_icc_data(bytes, length) != nil;
}

@interface VoxPNGICCTag : NSObject
@property(nonatomic) int width;
@property(nonatomic) int height;
@property(nonatomic, strong) NSData *profile;
@property(nonatomic, strong) NSData *converted;
@property(nonatomic) VoxImageColorProfile color_profile;
@property(nonatomic) BOOL conversion_failed;
@property(nonatomic) uint64_t source_identity;
@end
@implementation VoxPNGICCTag
@end

static NSMutableDictionary<NSValue *, VoxPNGICCTag *> *native_png_icc_tags;
static NSMutableArray<VoxPNGICCTag *> *native_png_icc_lru;
static size_t native_png_icc_cached_bytes;
VOX_NATIVE_STATE uint64_t native_png_icc_source_clock;
VOX_NATIVE_STATE BOOL native_png_icc_source_clock_exhausted;
// A conversion larger than the budget is redone on every draw: vlang.io's
// 3993x2317 tagged mascot converts 37 MB, which took 40-120 ms per scroll
// frame while it was visible under the former 32 MB budget.
static const size_t native_png_icc_cache_limit = 96 * 1024 * 1024;

// Decoded PNG buffers are immutable until retagged. Retagging clears both
// metadata and converted pixels; the conversion cache itself has a byte cap.
static void native_tag_png_icc_profile(const void *pixels, int width, int height, NSData *profile)
{
    if (!pixels) return;
    @synchronized ([NSValue class]) {
        NSValue *key = [NSValue valueWithPointer:pixels];
        VoxPNGICCTag *previous = native_png_icc_tags[key];
        if (previous.converted) {
            native_png_icc_cached_bytes -= previous.converted.length;
            previous.converted = nil;
            [native_png_icc_lru removeObjectIdenticalTo:previous];
        }
        if (!profile || width <= 0 || height <= 0) {
            [native_png_icc_tags removeObjectForKey:key];
            return;
        }
        if (!native_png_icc_tags) native_png_icc_tags = [NSMutableDictionary dictionary];
        VoxPNGICCTag *tag = [VoxPNGICCTag new];
        tag.width = width;
        tag.height = height;
        tag.profile = profile;
        native_png_icc_tags[key] = tag;
    }
}

static NSData *native_image_icc_profile(const void *pixels, int width, int height)
{
    if (!pixels) return nil;
    @synchronized ([NSValue class]) {
        VoxPNGICCTag *tag = native_png_icc_tags[[NSValue valueWithPointer:pixels]];
        return tag && tag.width == width && tag.height == height ? tag.profile : nil;
    }
}

#ifdef LADYBIRD_V_HAS_SKIA_TEXT
extern int ladybird_v_skia_convert_icc_rgba(const void *, size_t, const uint8_t *,
    int, int, uint8_t *, float *);

static NSData *native_image_icc_source(const void *pixels, int width, int height,
    VoxImageColorProfile *color_profile)
{
    if (color_profile) memset(color_profile, 0, sizeof(*color_profile));
    if (!pixels || width <= 0 || height <= 0 || width > INT_MAX / 4
        || (size_t)height > SIZE_MAX / ((size_t)width * 4)) return nil;
    NSValue *key = [NSValue valueWithPointer:pixels];
    VoxPNGICCTag *tag;
    @synchronized ([NSValue class]) {
        tag = native_png_icc_tags[key];
        if (!tag || tag.width != width || tag.height != height) return nil;
        if (tag.conversion_failed) return nil;
        if (tag.converted) {
            [native_png_icc_lru removeObjectIdenticalTo:tag];
            [native_png_icc_lru addObject:tag];
            if (color_profile) *color_profile = tag.color_profile;
            return tag.converted;
        }
    }
    size_t size = (size_t)width * height * 4;
    NSMutableData *converted = [NSMutableData dataWithLength:size];
    VoxImageColorProfile prepared_profile = { 0 };
    if (!ladybird_v_skia_convert_icc_rgba(tag.profile.bytes, tag.profile.length,
            pixels, width, height, converted.mutableBytes, prepared_profile.values)) {
        @synchronized ([NSValue class]) {
            if (native_png_icc_tags[key] == tag) tag.conversion_failed = YES;
        }
        return nil;
    }
    if (color_profile) *color_profile = prepared_profile;
    @synchronized ([NSValue class]) {
        // A request can retag a reused buffer while conversion is running.
        if (native_png_icc_tags[key] != tag) return converted;
        if (tag.converted) {
            if (color_profile) *color_profile = tag.color_profile;
            return tag.converted;
        }
        if (size <= native_png_icc_cache_limit) {
            if (!native_png_icc_lru) native_png_icc_lru = [NSMutableArray array];
            while (native_png_icc_cached_bytes + size > native_png_icc_cache_limit
                || native_png_icc_lru.count >= 128) {
                VoxPNGICCTag *oldest = native_png_icc_lru.firstObject;
                native_png_icc_cached_bytes -= oldest.converted.length;
                oldest.converted = nil;
                [native_png_icc_lru removeObjectAtIndex:0];
            }
            tag.converted = converted;
            tag.source_identity = 0;
            if (!native_png_icc_source_clock_exhausted) {
                tag.source_identity = ++native_png_icc_source_clock;
                if (!tag.source_identity || (tag.source_identity & (UINT64_C(1) << 63))) {
                    tag.source_identity = 0;
                    native_png_icc_source_clock_exhausted = YES;
                }
            }
            tag.color_profile = prepared_profile;
            native_png_icc_cached_bytes += size;
            [native_png_icc_lru addObject:tag];
        }
    }
    return converted;
}

static NSData *native_image_icc_pixels(const void *pixels, int width, int height)
{
    return native_image_icc_source(pixels, width, height, NULL);
}

// The retained conversion owns immutable bytes. A monotonically allocated key
// identifies this conversion, never its recyclable address or URL. Retagging,
// eviction/reconversion, dimensions and a concurrent retag all reject old keys.
static uint64_t native_image_icc_source_identity(const void *pixels, int width, int height, NSData *converted)
{
    if (!pixels || !converted) return 0;
    @synchronized ([NSValue class]) {
        VoxPNGICCTag *tag = native_png_icc_tags[[NSValue valueWithPointer:pixels]];
        return tag && tag.width == width && tag.height == height && tag.converted == converted
            ? tag.source_identity : 0;
    }
}
#endif
#endif
