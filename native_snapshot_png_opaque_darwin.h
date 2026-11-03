#ifndef VOX_NATIVE_SNAPSHOT_PNG_OPAQUE_DARWIN_H
#define VOX_NATIVE_SNAPSHOT_PNG_OPAQUE_DARWIN_H

#include <stdint.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <zlib.h>
#include <dlfcn.h>
#include <stdio.h>
#include "native_rgba_is_opaque.h"
#include "native_crc32.h"

static void native_png_write_u32(unsigned char *bytes, uint32_t value)
{
    bytes[0] = value >> 24; bytes[1] = value >> 16;
    bytes[2] = value >> 8; bytes[3] = value;
}

static void native_png_append_chunk(NSMutableData *output, const char *type,
    const unsigned char *bytes, uint32_t length)
{
    unsigned char word[4];
    native_png_write_u32(word, length);
    [output appendBytes:word length:4];
    [output appendBytes:type length:4];
    if (length) [output appendBytes:bytes length:length];
    uLong crc = vox_crc32(0, (const Bytef *)type, 4);
    if (length) crc = vox_crc32(crc, bytes, length);
    native_png_write_u32(word, (uint32_t)crc);
    [output appendBytes:word length:4];
}

static void native_png_write_u16(unsigned char *bytes, unsigned value)
{
    bytes[0] = value >> 8; bytes[1] = value;
}

static void native_png_exif_entry(unsigned char *entry, unsigned tag, unsigned type, uint32_t value)
{
    native_png_write_u16(entry, tag);
    native_png_write_u16(entry + 2, type);
    native_png_write_u32(entry + 4, 1);
    native_png_write_u32(entry + 8, value);
}

// Only opaque, byte-ordered RGBA in the named sRGB space is eligible. The
// standard sRGB, Exif dimension and integer-density chunks retain the ordinary
// encoder's metadata without initializing ImageIO's pixel encoder. Other spaces,
// fractional densities and alpha/sample conversions keep the ordinary path.
static NSData *native_encode_opaque_snapshot_png(NSBitmapImageRep *bitmap,
    CGImageRef image, NSDictionary *properties)
{
    if (getenv("VOX_DISABLE_OPAQUE_SNAPSHOT_PNG")) return nil;
    if (bitmap.isPlanar || !bitmap.hasAlpha || bitmap.bitsPerSample != 8
        || bitmap.samplesPerPixel != 4 || bitmap.bitsPerPixel != 32
        || (bitmap.bitmapFormat != 0 && bitmap.bitmapFormat != NSBitmapFormatAlphaNonpremultiplied))
        return nil;
    NSInteger width = bitmap.pixelsWide, height = bitmap.pixelsHigh;
    if (width <= 0 || height <= 0 || width > UINT32_MAX || height > UINT32_MAX
        || width > (64 * 1024 * 1024 - 1) / 4) return nil;
    size_t row_bytes = (size_t)width * 4, filtered_pitch = row_bytes + 1;
    NSInteger row_pitch = bitmap.bytesPerRow;
    if ((size_t)height > 64 * 1024 * 1024 / filtered_pitch
        || row_pitch < (NSInteger)row_bytes || (size_t)row_pitch > SIZE_MAX / (size_t)height)
        return nil;
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    BOOL same_space = srgb && CGImageGetColorSpace(image)
        && CFEqual(srgb, CGImageGetColorSpace(image));
    if (srgb) CGColorSpaceRelease(srgb);
    if (!same_space || bitmap.bitmapData == NULL) return nil;
    NSNumber *horizontal = properties[(__bridge NSString *)kCGImagePropertyDPIWidth];
    NSNumber *vertical = properties[(__bridge NSString *)kCGImagePropertyDPIHeight];
    BOOL density = horizontal != nil || vertical != nil;
    double dpi_x = horizontal.doubleValue, dpi_y = vertical.doubleValue;
    double meter_x = round(dpi_x * 10000 / 254), meter_y = round(dpi_y * 10000 / 254);
    if (density && (!horizontal || !vertical || !isfinite(dpi_x) || !isfinite(dpi_y)
        || dpi_x <= 0 || dpi_y <= 0 || floor(dpi_x) != dpi_x || floor(dpi_y) != dpi_y
        || dpi_x > UINT32_MAX || dpi_y > UINT32_MAX || meter_x > UINT32_MAX || meter_y > UINT32_MAX))
        return nil;
    const unsigned char *source = bitmap.bitmapData;
    if (!vox_rgba8_is_opaque(source, (size_t)width, (size_t)height, (size_t)row_pitch)) return nil;

    NSMutableData *rows = [NSMutableData dataWithLength:filtered_pitch * height];
    unsigned char *filtered = rows.mutableBytes;
    for (NSInteger y = 0; y < height; ++y) {
        unsigned char *output = filtered + (size_t)y * filtered_pitch;
        output[0] = 0;
        memcpy(output + 1, source + (size_t)y * row_pitch, row_bytes);
    }
    size_t size = rows.length;
    NSMutableData *compressed = [NSMutableData dataWithLength:compressBound((uLong)size)];
    typedef size_t (*SnapshotCompressor)(const void *, size_t, void *, size_t);
    SnapshotCompressor compressor = (SnapshotCompressor)dlsym(RTLD_DEFAULT,
        "ladybird_v_snapshot_compress_zlib");
    size_t written = !getenv("VOX_DISABLE_LIBDEFLATE_PNG") && compressor
        ? compressor(rows.bytes, size, compressed.mutableBytes, compressed.length) : 0;
    if (written && getenv("VOX_LIBDEFLATE_PNG_DIAGNOSTICS"))
        fprintf(stderr, "VOX_LIBDEFLATE_PNG input=%zu output=%zu\n", size, written);
    if (!written) {
        z_stream stream = {0};
        // Retain the original lossless encoder if the optional backend is
        // absent, cannot allocate, or cannot fit its output in this buffer.
        if (deflateInit2(&stream, Z_BEST_SPEED, Z_DEFLATED, MAX_WBITS, 5, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
        stream.next_in = rows.mutableBytes; stream.avail_in = (uInt)size;
        stream.next_out = compressed.mutableBytes; stream.avail_out = (uInt)compressed.length;
        int status = deflate(&stream, Z_FINISH);
        written = stream.total_out;
        deflateEnd(&stream);
        if (status != Z_STREAM_END) return nil;
    }
    compressed.length = written;

    const unsigned char signature[] = {137,80,78,71,13,10,26,10};
    NSMutableData *result = [NSMutableData dataWithCapacity:compressed.length + 256];
    [result appendBytes:signature length:sizeof signature];
    unsigned char header[13] = {0};
    native_png_write_u32(header, (uint32_t)width);
    native_png_write_u32(header + 4, (uint32_t)height);
    header[8] = 8; header[9] = 6;
    native_png_append_chunk(result, "IHDR", header, sizeof header);
    unsigned char intent = 0;
    native_png_append_chunk(result, "sRGB", &intent, 1);

    unsigned char exif[120] = {0};
    exif[0] = exif[1] = 'M'; exif[3] = 42;
    native_png_write_u32(exif + 4, 8);
    native_png_write_u16(exif + 8, density ? 4 : 1);
    size_t directory = density ? 78 : 26;
    if (density) {
        native_png_exif_entry(exif + 10, 0x11a, 5, 62);
        native_png_exif_entry(exif + 22, 0x11b, 5, 70);
        native_png_exif_entry(exif + 34, 0x128, 3, 0x20000);
        native_png_exif_entry(exif + 46, 0x8769, 4, (uint32_t)directory);
        native_png_write_u32(exif + 62, (uint32_t)dpi_x);
        native_png_write_u32(exif + 66, 1);
        native_png_write_u32(exif + 70, (uint32_t)dpi_y);
        native_png_write_u32(exif + 74, 1);
    } else native_png_exif_entry(exif + 10, 0x8769, 4, (uint32_t)directory);
    native_png_write_u16(exif + directory, 3);
    native_png_exif_entry(exif + directory + 2, 0xa001, 3, 0x10000);
    native_png_exif_entry(exif + directory + 14, 0xa002, 4, (uint32_t)width);
    native_png_exif_entry(exif + directory + 26, 0xa003, 4, (uint32_t)height);
    native_png_append_chunk(result, "eXIf", exif, density ? 120 : 68);
    if (density) {
        unsigned char physical[9] = {0};
        native_png_write_u32(physical, (uint32_t)meter_x);
        native_png_write_u32(physical + 4, (uint32_t)meter_y);
        physical[8] = 1;
        native_png_append_chunk(result, "pHYs", physical, sizeof physical);
    }
    native_png_append_chunk(result, "IDAT", compressed.bytes, (uint32_t)compressed.length);
    native_png_append_chunk(result, "IEND", NULL, 0);
    return result;
}

#endif
