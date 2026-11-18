#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "native/include/native_snapshot_png_darwin.h"
// Link zlib directly to decode the encoder's output independently.
#include <zlib.h>

static void test_opacity_scan(void)
{
    unsigned char storage[3 * (65 * 4 + 7) + 7];
    assert(!vox_rgba8_is_opaque(NULL, 1, 1, 4));
    assert(!vox_rgba8_is_opaque(storage, 0, 1, 4));
    assert(!vox_rgba8_is_opaque(storage, 1, 0, 4));
    assert(!vox_rgba8_is_opaque(storage, SIZE_MAX / 4 + 1, 1, SIZE_MAX));
    assert(!vox_rgba8_is_opaque(storage, 2, 1, 7));
    assert(!vox_rgba8_is_opaque(storage, 1, 2, SIZE_MAX));
    for (size_t width = 1; width <= 65; ++width)
        for (size_t height = 1; height <= 3; ++height)
            for (size_t padding = 0; padding <= 7; ++padding)
                for (size_t alignment = 0; alignment <= 7; ++alignment) {
                    size_t pitch = width * 4 + padding;
                    unsigned char *pixels = storage + alignment;
                    memset(storage, 0, sizeof storage);
                    for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < width; ++x) {
                        unsigned char *pixel = pixels + y * pitch + x * 4;
                        pixel[0] = (unsigned char)(x * 37 + y);
                        pixel[1] = (unsigned char)(x + y * 17);
                        pixel[2] = (unsigned char)(x * 11 + y * 43);
                        pixel[3] = 255;
                    }
                    assert(vox_rgba8_is_opaque(pixels, width, height, pitch));
                    // Every alpha position, including the first/last byte of
                    // each vector block and its scalar tail, must reject.
                    for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < width; ++x) {
                        unsigned char *alpha = pixels + y * pitch + x * 4 + 3;
                        *alpha = (unsigned char)((x * 31 + y * 13) % 255);
                        assert(!vox_rgba8_is_opaque(pixels, width, height, pitch));
                        *alpha = 255;
                    }
                }
    puts("PASS padded/unaligned opacity scans and every alpha position at widths 1..65");
}

static void test_large_opacity_scan(void)
{
    const size_t width = 2051, height = 1541, pitch = width * 4 + 19;
    unsigned char *storage = calloc(1, pitch * height + 1);
    assert(storage);
    unsigned char *pixels = storage + 1;
    for (size_t y = 0; y < height; ++y)
        memset(pixels + y * pitch, 255, width * 4);

    // Include the prefix, each worker's first row, the vector tail, and the
    // last row. Zeroes in unaligned row padding must never affect the scan.
    const size_t rows[] = {0, 1, 1 + (height - 1) / 4, 1 + (height - 1) / 2,
        1 + 3 * (height - 1) / 4, height - 1};
    assert(vox_rgba8_is_opaque(pixels, width, height, pitch));
    for (size_t index = 0; index < sizeof rows / sizeof rows[0]; ++index) {
        unsigned char *alpha = pixels + rows[index] * pitch + (width - 1) * 4 + 3;
        *alpha = 254;
        assert(!vox_rgba8_is_opaque(pixels, width, height, pitch));
        *alpha = 255;
    }
    free(storage);
    puts("PASS large opacity scan with padded rows and translucent worker boundaries");
}

static void test_parallel_deflate(void)
{
    const size_t row_bytes = 2051 * 4, pitch = row_bytes + 9, max_height = 1541;
    uint8_t *input = malloc(pitch * max_height);
    uint8_t *decoded = malloc((row_bytes + 1) * max_height);
    assert(input && decoded);
    for (size_t y = 0; y < max_height; ++y)
        for (size_t x = 0; x < pitch; ++x)
            input[y * pitch + x] = (uint8_t)(x * 17 + y * 31 + (y >> 8));
    // Two, three and four bands, with nonempty row tails and changing pixels
    // across every band boundary. The detached padding never enters zlib.
    const size_t heights[] = {641, 941, max_height};
    unsetenv("VOX_SERIAL_SNAPSHOT_PNG");
    for (size_t i = 0; i < sizeof heights / sizeof heights[0]; ++i) {
        size_t size = 0, height = heights[i];
        if (height == max_height) {
            uint32_t noise = 0x61798c45;
            for (size_t n = 0; n < pitch * height; ++n) {
                noise ^= noise << 13;
                noise ^= noise >> 17;
                noise ^= noise << 5;
                input[n] = (uint8_t)noise;
            }
        }
        uint8_t *compressed = native_snapshot_deflate_rows(input, row_bytes, height, pitch, &size);
        assert(compressed && size);
        uLongf length = (row_bytes + 1) * height;
        assert(uncompress(decoded, &length, compressed, size) == Z_OK);
        assert(length == (row_bytes + 1) * height);
        for (size_t y = 0; y < height; ++y) {
            const uint8_t *row = decoded + (row_bytes + 1) * y;
            assert(row[0] == 0 && !memcmp(row + 1, input + y * pitch, row_bytes));
        }
        free(compressed);
    }
    size_t size = 7;
    assert(!native_snapshot_deflate_rows(input, row_bytes, 1, pitch, &size) && !size);
    assert(!native_snapshot_deflate_rows(input, row_bytes, max_height, row_bytes - 1, &size) && !size);
    assert(setenv("VOX_SERIAL_SNAPSHOT_PNG", "1", 1) == 0);
    assert(!native_snapshot_deflate_rows(input, row_bytes, max_height, pitch, &size) && !size);
    assert(unsetenv("VOX_SERIAL_SNAPSHOT_PNG") == 0);
    free(decoded);
    free(input);
    puts("PASS two to four PNG deflate bands, filter bytes, padded rows and serial fallback");
}

static void test_large_snapshot_png(const char *directory)
{
    @autoreleasepool {
        const size_t width = 1027, height = 1033, pitch = width * 4 + 12;
        NSMutableData *pixels = [NSMutableData dataWithLength:pitch * height];
        for (size_t y = 0; y < height; ++y) {
            uint8_t *row = (uint8_t *)pixels.mutableBytes + y * pitch;
            for (size_t x = 0; x < width; ++x) {
                row[x * 4] = (uint8_t)(x + y);
                row[x * 4 + 1] = (uint8_t)(y / 2);
                row[x * 4 + 2] = (uint8_t)(x ^ y);
                row[x * 4 + 3] = 255;
            }
        }
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
        CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGImageRef image = CGImageCreate(width, height, 8, 32, pitch, srgb,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big,
            provider, NULL, true, kCGRenderingIntentDefault);
        assert(image);
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
        assert(bitmap);
        bitmap.size = NSMakeSize(width / 2.0, height / 2.0);
        native_presented_pixels_attach(bitmap, (NativePresentedPixels){pixels.bytes, width, height, pitch});
        NSString *output = [NSString stringWithUTF8String:directory];
        // Run before loading the optional compressor to exercise ImageIO and
        // the parallel encoder through the actual native capture function.
        assert(setenv("VOX_SERIAL_SNAPSHOT_PNG", "1", 1) == 0);
        NSData *reference = native_encode_snapshot_png(bitmap);
        assert(unsetenv("VOX_SERIAL_SNAPSHOT_PNG") == 0);
        NSData *candidate = native_encode_snapshot_png(bitmap);
        assert(reference && candidate && ![reference isEqualToData:candidate]);
        assert([reference writeToFile:[output stringByAppendingPathComponent:@"large-reference.png"] atomically:YES]);
        assert([candidate writeToFile:[output stringByAppendingPathComponent:@"large-candidate.png"] atomically:YES]);
#if !__has_feature(objc_arc)
        [bitmap release];
#endif
        CGImageRelease(image);
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(srgb);
    }
}

int main(int argc, const char *argv[])
{
    assert(argc == 2 || argc == 3);
    test_opacity_scan();
    test_large_opacity_scan();
    test_parallel_deflate();
    test_large_snapshot_png(argv[1]);
    if (argc == 3) {
        assert(dlopen(argv[2], RTLD_NOW | RTLD_GLOBAL));
        typedef size_t (*Compressor)(const void *, size_t, void *, size_t);
        Compressor compress = (Compressor)dlsym(RTLD_DEFAULT, "ladybird_v_snapshot_compress_zlib");
        assert(compress);
        const char input[] = "snapshot compression";
        unsigned char compressed[128], decoded[128];
        size_t count = compress(input, sizeof(input), compressed, sizeof(compressed));
        assert(count > 0);
        uLongf size = sizeof(decoded);
        assert(uncompress(decoded, &size, compressed, count) == Z_OK);
        assert(size == sizeof(input) && !memcmp(input, decoded, size));
        assert(!compress(input, sizeof(input), compressed, 1));
        assert(!compress(NULL, sizeof(input), compressed, sizeof(compressed)));
        assert(!compress(input, sizeof(input), NULL, sizeof(compressed)));
        assert(!compress(input, 0, compressed, sizeof(compressed)));
        assert(!compress(input, 64 * 1024 * 1024 + 1, compressed, sizeof(compressed)));
        assert(!compress(input, sizeof(input), compressed, 0));
        assert(setenv("VOX_LIBDEFLATE_PNG_DIAGNOSTICS", "1", 1) == 0);
    }
    @autoreleasepool {
        NSString *output = [NSString stringWithUTF8String:argv[1]];
        NSArray<NSColorSpace *> *spaces = @[[NSColorSpace sRGBColorSpace],
            [NSColorSpace displayP3ColorSpace], [NSColorSpace genericRGBColorSpace]];
        NSSize sizes[] = { {19, 13}, {9.5, 6.5}, {13.25, 4.125} };
        unsigned cases = 0, optimized_cases = 0;
        for (NSColorSpace *space in spaces) for (unsigned alpha = 0; alpha < 5; ++alpha)
            for (unsigned scale = 0; scale < 3; ++scale) {
                @autoreleasepool {
                    BOOL has_alpha = alpha != 0;
                    NSInteger samples = has_alpha ? 4 : 3;
                    NSBitmapFormat format = alpha == 2 || alpha == 4 ? NSBitmapFormatAlphaNonpremultiplied : 0;
                    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
                        initWithBitmapDataPlanes:NULL pixelsWide:19 pixelsHigh:13
                        bitsPerSample:8 samplesPerPixel:samples hasAlpha:has_alpha isPlanar:NO
                        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:format
                        bytesPerRow:19 * samples + 7 bitsPerPixel:samples * 8];
                    assert(bitmap);
                    // Include opaque pixels, alpha=0, and several fractional alphas;
                    // different rows and padded strides expose orientation/row mistakes.
                    memset(bitmap.bitmapData, 0xa5, bitmap.bytesPerRow * 13);
                    for (NSInteger y = 0; y < 13; ++y) for (NSInteger x = 0; x < 19; ++x) {
                        unsigned opacity = has_alpha && alpha < 3
                            ? (unsigned)(((x + y * 3) % 5) * 255 + 2) / 4 : 255;
                        unsigned channels[] = {(unsigned)(x * 17) % 256,
                            (unsigned)(y * 23) % 256, (unsigned)(x * 7 + y * 11) % 256};
                        unsigned char *pixel = bitmap.bitmapData + y * bitmap.bytesPerRow + x * samples;
                        for (unsigned channel = 0; channel < 3; ++channel)
                            pixel[channel] = has_alpha && !(format & NSBitmapFormatAlphaNonpremultiplied)
                                ? (channels[channel] * opacity + 127) / 255 : channels[channel];
                        if (has_alpha) pixel[3] = opacity;
                    }
                    NSBitmapImageRep *converted = [bitmap bitmapImageRepByConvertingToColorSpace:space
                        renderingIntent:NSColorRenderingIntentRelativeColorimetric];
                    assert(converted);
                    converted.size = sizes[scale];
                    NSData *reference = [converted representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    NSData *actual = native_encode_snapshot_png(converted);
                    assert(reference && actual);
                    NSMutableDictionary *density = [NSMutableDictionary dictionary];
                    if (converted.size.width != converted.pixelsWide || converted.size.height != converted.pixelsHigh) {
                        density[(__bridge NSString *)kCGImagePropertyDPIWidth] = @(72.0 * converted.pixelsWide / converted.size.width);
                        density[(__bridge NSString *)kCGImagePropertyDPIHeight] = @(72.0 * converted.pixelsHigh / converted.size.height);
                    }
                    NSData *fast = native_encode_opaque_snapshot_png(converted, converted.CGImage, density);
                    if (fast) { assert([fast isEqualToData:actual]); ++optimized_cases; }
                    // Disabling libdeflate selects the ordinary encoder.
                    assert(setenv("VOX_DISABLE_LIBDEFLATE_PNG", "1", 1) == 0);
                    assert(native_encode_opaque_snapshot_png(converted, converted.CGImage, density) == nil);
                    NSData *zlib = native_encode_snapshot_png(converted);
                    assert(unsetenv("VOX_DISABLE_LIBDEFLATE_PNG") == 0);
                    assert(zlib);
                    assert(setenv("VOX_DISABLE_OPAQUE_SNAPSHOT_PNG", "1", 1) == 0);
                    assert(native_encode_opaque_snapshot_png(converted, converted.CGImage, density) == nil);
                    NSData *fallback = native_encode_snapshot_png(converted);
                    assert(unsetenv("VOX_DISABLE_OPAQUE_SNAPSHOT_PNG") == 0);
                    assert(fallback);
                    NSString *stem = [NSString stringWithFormat:@"case-%u", cases];
                    assert([reference writeToFile:[output stringByAppendingPathComponent:
                        [stem stringByAppendingString:@"-reference.png"]] atomically:YES]);
                    assert([actual writeToFile:[output stringByAppendingPathComponent:
                        [stem stringByAppendingString:@"-actual.png"]] atomically:YES]);
                    assert([fallback writeToFile:[output stringByAppendingPathComponent:
                        [stem stringByAppendingString:@"-fallback.png"]] atomically:YES]);
                    assert([zlib writeToFile:[output stringByAppendingPathComponent:
                        [stem stringByAppendingString:@"-zlib.png"]] atomically:YES]);
                    printf("{\"case\":%u,\"alpha\":%u,\"scale\":%u,\"width\":19,\"height\":13}\n",
                        cases, alpha, scale);
                    ++cases;
#if !__has_feature(objc_arc)
                    [bitmap release];
#endif
                }
            }
        assert(cases == 45);
        // Without the optional libdeflate backend every snapshot takes the
        // ordinary ImageIO encoder: Vox links no zlib for this fast path.
        if (argc == 3) assert(optimized_cases > 0 && optimized_cases < cases);
        else assert(optimized_cases == 0);
        printf("PASS 45 snapshot PNG pixel/profile/density cases\n");
    }
}
