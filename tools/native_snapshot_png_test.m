#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "native_snapshot_png_darwin.h"

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

int main(int argc, const char *argv[])
{
    assert(argc == 2 || argc == 3);
    test_opacity_scan();
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
                    assert(setenv("VOX_DISABLE_LIBDEFLATE_PNG", "1", 1) == 0);
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
        assert(optimized_cases > 0 && optimized_cases < cases);
        printf("PASS 45 snapshot PNG pixel/profile/density cases\n");
    }
}
