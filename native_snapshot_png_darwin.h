#ifndef VOX_NATIVE_SNAPSHOT_PNG_DARWIN_H
#define VOX_NATIVE_SNAPSHOT_PNG_DARWIN_H

#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>

// Encode synchronously through the same capture checkpoint. Unfiltered rows
// avoid PNG's per-row filter search without changing pixels or color profiles.
static NSData *native_encode_snapshot_png(NSBitmapImageRep *bitmap)
{
    CGImageRef image = bitmap.CGImage;
    if (image == NULL) return nil;

    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(
        (__bridge CFMutableDataRef)data, CFSTR("public.png"), 1, NULL);
    if (destination == NULL) return nil;

    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithDictionary:@{
        (__bridge NSString *)kCGImagePropertyPNGDictionary: @{
            (__bridge NSString *)kCGImagePropertyPNGCompressionFilter:
                @((long)IMAGEIO_PNG_FILTER_NONE)
        }
    }];
    // A CGImage has no logical size. Carry Cocoa's Retina and fractional-size
    // density metadata explicitly into the lossless encoding.
    NSSize size = bitmap.size;
    if (size.width > 0 && size.height > 0
        && (size.width != bitmap.pixelsWide || size.height != bitmap.pixelsHigh)) {
        properties[(__bridge NSString *)kCGImagePropertyDPIWidth] =
            @(72.0 * bitmap.pixelsWide / size.width);
        properties[(__bridge NSString *)kCGImagePropertyDPIHeight] =
            @(72.0 * bitmap.pixelsHigh / size.height);
    }
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
    BOOL success = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return success ? data : nil;
}

#endif
