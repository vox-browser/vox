#pragma once

#include <Cocoa/Cocoa.h>
#include <string.h>

// An explicit no-animation capture uses the original image's first frame.
// Ordinary screenshot tests retain their existing script-host checkpoint.
static bool vox_apply_image_capture_policy(NSBitmapImageRep *representation,
    const char *policy, bool screenshot_checkpoint) {
    if (!representation) return false;
    NSInteger frame_count = [[representation valueForProperty:NSImageFrameCount] integerValue];
    if (frame_count <= 1) return false;
    if (policy && strcmp(policy, "none") == 0) {
        [representation setProperty:NSImageCurrentFrame withValue:@0];
        return true;
    }
    if (screenshot_checkpoint) {
        [representation setProperty:NSImageCurrentFrame withValue:@(MIN(1, frame_count - 1))];
        return true;
    }
    return false;
}
