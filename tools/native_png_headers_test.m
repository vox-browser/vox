#include "native_snapshot_png_darwin.h"
#include "native_png_color_darwin.h"
#include <assert.h>
#include <stdio.h>

// These headers share the browser's capture translation unit. Exercise both
// APIs together so private helper names cannot break that integration again.
int main(void)
{
    @autoreleasepool {
        const uint8_t gamma_png[] = {
            0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n',
            0, 0, 0, 4, 'g', 'A', 'M', 'A', 0, 1, 0x86, 0xa0,
            0, 0, 0, 0,
        };
        VoxPngColorProfile profile;
        assert(native_png_color_profile(gamma_png, sizeof gamma_png, &profile));
        assert(profile.values[0] == 1.0f && profile.values[1] == 0.0f);
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:2 pixelsHigh:1
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
            colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:8 bitsPerPixel:32];
        assert(bitmap);
        memset(bitmap.bitmapData, 255, 8);
        NSData *encoded = native_encode_snapshot_png(bitmap);
        assert(encoded.length > 8);
        NSBitmapImageRep *decoded = [[NSBitmapImageRep alloc] initWithData:encoded];
        assert(decoded && decoded.pixelsWide == 2 && decoded.pixelsHigh == 1);
        NSUInteger channels[4] = {0};
        [decoded getPixel:channels atX:1 y:0];
        assert(channels[0] == 255 && channels[1] == 255 && channels[2] == 255);
        puts("Combined PNG encoder and color-profile headers passed");
    }
    return 0;
}
