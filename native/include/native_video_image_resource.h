#ifndef VOX_NATIVE_VIDEO_IMAGE_RESOURCE_H
#define VOX_NATIVE_VIDEO_IMAGE_RESOURCE_H
#include <stddef.h>
#include <stdint.h>
#include "../../platform/native_state.h"

typedef struct {
    uint64_t source, revision, generation, key;
} VoxVideoImageResource;
VOX_NATIVE_STATE VoxVideoImageResource native_video_image_resources[128];
VOX_NATIVE_STATE unsigned native_video_image_resource_cursor;
VOX_NATIVE_STATE uint64_t native_video_image_resource_clock;
VOX_NATIVE_STATE uint64_t native_video_image_resource_key;

// The high bit separates video keys from immutable ICC conversions. Retain
// only the most recently seen content generation of each bounded source entry.
// Eviction, revision changes and exhaustion never recycle an upload key.
static uint64_t native_video_image_resource_identity(uint64_t source, uint64_t revision, uint64_t generation) {
    if (!source || !revision) return 0;
    VoxVideoImageResource *entry = NULL;
    for (unsigned index=0; index<128; ++index) {
        if (native_video_image_resources[index].source != source) continue;
        entry = &native_video_image_resources[index];
        if (entry->revision == revision && entry->generation == generation) return entry->key;
        break;
    }
    if (native_video_image_resource_clock == (UINT64_MAX >> 1)) return 0;
    if (!entry) entry = &native_video_image_resources[native_video_image_resource_cursor++ % 128];
    uint64_t key = (UINT64_C(1) << 63) | ++native_video_image_resource_clock;
    *entry = (VoxVideoImageResource){source,revision,generation,key};
    return key;
}
#endif
