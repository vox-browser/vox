#pragma once
#include <stdbool.h>
#include <stdint.h>
#include "canvas_raster.h"
struct VoxShadowRect { float rect[4], radii[8]; };
struct VoxShadowClip {
    struct VoxShadowRect shape;
    float transform[6];
    struct VoxCanvasPath path;
    int is_path;
};
struct VoxShadowCommand {
    int kind;
    uint32_t color;
    float blur, transform[6];
    struct VoxShadowRect content, outer, inner;
    struct VoxShadowClip const* clips;
    int clip_count;
    char const* font_path;
    int face_index, glyph_count, font_smoothing;
    float font_size, translation[2];
    uint16_t const* glyphs;
    float const* positions;
};
#ifdef __cplusplus
extern "C"
#endif
bool vox_skia_shadow(uint8_t* pixels, int width, int height, int pitch, struct VoxShadowCommand const* command);
