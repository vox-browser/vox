#ifndef VOX_NATIVE_SNAPSHOT_PNG_DARWIN_H
#define VOX_NATIVE_SNAPSHOT_PNG_DARWIN_H

#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>

// Capture remains synchronous through the complete PNG encode. A fixed SUB
// filter avoids evaluating all five lossless filters for every screenshot row.
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
                @((long)IMAGEIO_PNG_FILTER_SUB)
        }
    }];
    // CGImage has pixel dimensions but no logical size. Preserve Cocoa's PNG
    // density metadata, including Retina and fractional logical dimensions.
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
