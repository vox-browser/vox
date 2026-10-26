#ifndef VOX_NATIVE_SNAPSHOT_PNG_DARWIN_H
#define VOX_NATIVE_SNAPSHOT_PNG_DARWIN_H

#import <Cocoa/Cocoa.h>

// Keep Cocoa's adaptive lossless encoding and metadata. A fixed SUB filter
// reduced work on a small bitmap but regressed all 30 complete-page trials.
// Encoding must still finish synchronously before the capture checkpoint.
static NSData *native_encode_snapshot_png(NSBitmapImageRep *bitmap)
{
    return [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

#endif
