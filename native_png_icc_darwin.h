#ifndef VOX_NATIVE_PNG_ICC_DARWIN_H
#define VOX_NATIVE_PNG_ICC_DARWIN_H
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
#include <limits.h>
#include <zlib.h>
#include "native_image_color_profile.h"

// Packed, top-down, straight RGBA with a separately retained PNG ICC profile.
// Ordinary RGBA and planar YUV buffers must never consult the ICC pointer map.
#define VOX_PNG_ICC_CHANNEL_MARKER 11
static int native_png_icc_channel_marker(void) { return VOX_PNG_ICC_CHANNEL_MARKER; }

static uint32_t native_png_icc_u32(const uint8_t *p)
{
    return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3];
}

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
    NSMutableData *output = [NSMutableData dataWithLength:4096];
    z_stream stream = { 0 };
    stream.next_in = (Bytef *)compressed;
    stream.avail_in = compressed_length;
    if (inflateInit(&stream) != Z_OK) return nil;
    int status = Z_OK;
    while (status == Z_OK) {
        if (stream.total_out == output.length) {
            if (output.length == maximum_size) { status = Z_MEM_ERROR; break; }
            output.length = MIN(output.length * 2, maximum_size);
        }
        stream.next_out = (Bytef *)output.mutableBytes + stream.total_out;
        stream.avail_out = (uInt)(output.length - stream.total_out);
        status = inflate(&stream, Z_NO_FLUSH);
    }
    size_t decoded_length = stream.total_out;
    inflateEnd(&stream);
    if (status != Z_STREAM_END || decoded_length < 128) return nil;
    const uint8_t *icc = output.bytes;
    uint32_t declared_size = native_png_icc_u32(icc);
    if (declared_size < 128 || declared_size > decoded_length || memcmp(icc + 36, "acsp", 4)) return nil;
    output.length = declared_size;
    return output;
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
@end
@implementation VoxPNGICCTag
@end

static NSMutableDictionary<NSValue *, VoxPNGICCTag *> *native_png_icc_tags;
static NSMutableArray<VoxPNGICCTag *> *native_png_icc_lru;
static size_t native_png_icc_cached_bytes;
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
#endif
#endif
