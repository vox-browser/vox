#ifndef VOX_NATIVE_SVG_MASK_CACHE_KEY_H
#define VOX_NATIVE_SVG_MASK_CACHE_KEY_H

#include <stdint.h>
#include <string.h>

static uint64_t native_svg_clip_hash_float(uint64_t hash, float value)
{
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    return (hash ^ bits) * UINT64_C(1099511628211);
}

static uint64_t native_svg_mask_cache_key(uint64_t input_key, int content_mask,
    float canvas_width, float canvas_height, float page_x, float page_y,
    float scroll_y, double scale)
{
    uint64_t key = input_key;
    key ^= content_mask ? UINT64_C(0x6d61736b636f6e74)
                        : UINT64_C(0x636c6970616c7068);
    key *= UINT64_C(1099511628211);
    key = native_svg_clip_hash_float(key, canvas_width);
    key = native_svg_clip_hash_float(key, canvas_height);
    key = native_svg_clip_hash_float(key, page_x);
    key = native_svg_clip_hash_float(key, page_y);
    key = native_svg_clip_hash_float(key, scroll_y);
    uint64_t scale_bits;
    memcpy(&scale_bits, &scale, sizeof(scale_bits));
    return (key ^ scale_bits) * UINT64_C(1099511628211);
}

#endif
