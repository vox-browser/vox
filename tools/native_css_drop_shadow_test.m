#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#include <assert.h>
#include <string.h>
#include "native/include/native_css_drop_shadow_darwin.h"

int main(void) {
    @autoreleasepool {
        CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CIContext *context = [CIContext contextWithOptions:@{
            kCIContextWorkingColorSpace: (__bridge id)space,
            kCIContextOutputColorSpace: (__bridge id)space,
        }];
        uint8_t source[256 * 4] = {0}, output[256 * 4];
        for (int i = 0; i < 256; ++i) source[i * 4 + 3] = i;
        CIImage *mask = [CIImage imageWithBitmapData:[NSData dataWithBytes:source length:sizeof(source)]
            bytesPerRow:sizeof(source) size:CGSizeMake(256, 1) format:kCIFormatRGBA8 colorSpace:space];
        int comparisons = 0;
        for (int color = 0; color < 4; ++color) {
            // White, red, blue and black cover all/one/no nonzero RGB channels.
            CGFloat r = color < 2, g = color == 0, b = color == 0 || color == 2;
            for (int opacity = 0; opacity < 3; ++opacity) {
                CGFloat alpha = opacity == 0 ? 0 : opacity == 1 ? .6 : 1;
                CGFloat m[20]; native_css_drop_shadow_color_matrix(m, r, g, b, alpha);
                CIFilter *filter = [CIFilter filterWithName:@"CIColorMatrix"];
                [filter setValue:mask forKey:kCIInputImageKey];
                [filter setValue:[CIVector vectorWithValues:m count:4] forKey:@"inputRVector"];
                [filter setValue:[CIVector vectorWithValues:m + 5 count:4] forKey:@"inputGVector"];
                [filter setValue:[CIVector vectorWithValues:m + 10 count:4] forKey:@"inputBVector"];
                [filter setValue:[CIVector vectorWithValues:m + 15 count:4] forKey:@"inputAVector"];
                [filter setValue:[CIVector vectorWithX:m[4] Y:m[9] Z:m[14] W:m[19]] forKey:@"inputBiasVector"];
                [context render:filter.outputImage toBitmap:output rowBytes:sizeof(output)
                    bounds:CGRectMake(0, 0, 256, 1) format:kCIFormatRGBA8 colorSpace:space];
                for (int i = 0; i < 256; ++i) {
                    uint8_t *p = output + i * 4;
                    // Alpha may quantize by one at half values; RGB must keep
                    // the chosen hue through the complete blurred-alpha ramp.
                    assert(abs((int)p[3] - (int)lround(i * alpha)) <= 1);
                    assert(p[0] == (r ? p[3] : 0));
                    assert(p[1] == (g ? p[3] : 0));
                    assert(p[2] == (b ? p[3] : 0));
                    comparisons++;
                }
            }
        }
        CGColorSpaceRelease(space);
        printf("drop-shadow alpha/color comparisons: %d\n", comparisons);
    }
}
