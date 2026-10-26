#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include "native_snapshot_png_darwin.h"

int main(int argc, const char *argv[])
{
    assert(argc == 2);
    @autoreleasepool {
        NSString *output = [NSString stringWithUTF8String:argv[1]];
        NSArray<NSColorSpace *> *spaces = @[[NSColorSpace sRGBColorSpace],
            [NSColorSpace displayP3ColorSpace], [NSColorSpace genericRGBColorSpace]];
        NSSize sizes[] = { {19, 13}, {9.5, 6.5}, {13.25, 4.125} };
        unsigned cases = 0;
        for (NSColorSpace *space in spaces) for (unsigned alpha = 0; alpha < 3; ++alpha)
            for (unsigned scale = 0; scale < 3; ++scale) {
                @autoreleasepool {
                    BOOL has_alpha = alpha != 0;
                    NSInteger samples = has_alpha ? 4 : 3;
                    NSBitmapFormat format = alpha == 2 ? NSBitmapFormatAlphaNonpremultiplied : 0;
                    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
                        initWithBitmapDataPlanes:NULL pixelsWide:19 pixelsHigh:13
                        bitsPerSample:8 samplesPerPixel:samples hasAlpha:has_alpha isPlanar:NO
                        colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:format
                        bytesPerRow:19 * samples + 7 bitsPerPixel:samples * 8];
                    assert(bitmap);
                    // Include opaque pixels, alpha=0, and several fractional alphas;
                    // different rows and padded strides expose orientation/row mistakes.
                    for (NSInteger y = 0; y < 13; ++y) for (NSInteger x = 0; x < 19; ++x) {
                        CGFloat opacity = has_alpha ? ((x + y * 3) % 5) / 4.0 : 1.0;
                        [bitmap setColor:[NSColor colorWithSRGBRed:((x * 17) % 256) / 255.0
                            green:((y * 23) % 256) / 255.0 blue:((x * 7 + y * 11) % 256) / 255.0
                            alpha:opacity] atX:x y:y];
                    }
                    NSBitmapImageRep *converted = [bitmap bitmapImageRepByConvertingToColorSpace:space
                        renderingIntent:NSColorRenderingIntentRelativeColorimetric];
                    assert(converted);
                    converted.size = sizes[scale];
                    NSData *reference = [converted representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    NSData *actual = native_encode_snapshot_png(converted);
                    assert(reference && actual);
                    NSString *stem = [NSString stringWithFormat:@"case-%u", cases];
                    assert([reference writeToFile:[output stringByAppendingPathComponent:
                        [stem stringByAppendingString:@"-reference.png"]] atomically:YES]);
                    assert([actual writeToFile:[output stringByAppendingPathComponent:
                        [stem stringByAppendingString:@"-actual.png"]] atomically:YES]);
                    printf("{\"case\":%u,\"alpha\":%u,\"scale\":%u,\"width\":19,\"height\":13}\n",
                        cases, alpha, scale);
                    ++cases;
#if !__has_feature(objc_arc)
                    [bitmap release];
#endif
                }
            }
        assert(cases == 27);
        printf("PASS 27 snapshot PNG pixel/profile/density cases\n");
    }
}
