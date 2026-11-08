#ifndef VOX_NATIVE_FRAME_SNAPSHOT_DARWIN_H
#define VOX_NATIVE_FRAME_SNAPSHOT_DARWIN_H
#import <Cocoa/Cocoa.h>

// A renderer may finish a frame with an existing immutable image when its
// caller guarantees that no later drawing targets this frame's bitmap.
// Nested native captures keep their own target and retained image.
typedef struct {
    CGContextRef context;
    CGImageRef image;
} VoxFrameSnapshot;
static VoxFrameSnapshot vox_frame_snapshot;

static VoxFrameSnapshot vox_frame_snapshot_begin(CGContextRef context) {
    VoxFrameSnapshot previous = vox_frame_snapshot;
    vox_frame_snapshot = (VoxFrameSnapshot){.context = context};
    return previous;
}

static int vox_frame_snapshot_select(CGContextRef context, CGImageRef image) {
    if (!context || !image || context != vox_frame_snapshot.context
        || vox_frame_snapshot.image
        || CGImageGetWidth(image) != CGBitmapContextGetWidth(context)
        || CGImageGetHeight(image) != CGBitmapContextGetHeight(context)) return 0;
    vox_frame_snapshot.image = CGImageRetain(image);
    return 1;
}

static CGImageRef vox_frame_snapshot_copy(CGContextRef context) {
    if (context == vox_frame_snapshot.context && vox_frame_snapshot.image)
        return CGImageRetain(vox_frame_snapshot.image);
    return CGBitmapContextCreateImage(context);
}

static void vox_frame_snapshot_restore(VoxFrameSnapshot previous) {
    if (vox_frame_snapshot.image) CGImageRelease(vox_frame_snapshot.image);
    vox_frame_snapshot = previous;
}
#endif
