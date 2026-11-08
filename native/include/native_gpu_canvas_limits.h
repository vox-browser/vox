#ifndef VOX_NATIVE_GPU_CANVAS_LIMITS_H
#define VOX_NATIVE_GPU_CANVAS_LIMITS_H

// The scroll ring publishes up to 48 damage rectangles plus its exposed strip.
// Keep that complete disjoint set batched, including in nested GPU layers.
#define VOX_GPU_CANVAS_MAX_RECTS 64

#endif
