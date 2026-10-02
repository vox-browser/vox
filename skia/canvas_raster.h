#pragma once
#include <stdbool.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
struct VoxCanvasPath {
    float const* segments;
    int count;
    int even_odd;
};
struct VoxCanvasStyle {
    int kind;
    uint32_t color;
    float x0, y0, r0, x1, y1, r1, angle;
    float const* stops;
    int stop_count;
    uint8_t const* pattern;
    int pattern_width, pattern_height, pattern_pitch, pattern_alpha, pattern_color_space, repetition;
    float pattern_transform[6];
};
struct VoxCanvasFilter {
    int kind;
    float radius, offset_x, offset_y;
    uint32_t color;
    float matrix[20];
    int clamp;
};
struct VoxCanvasCommand {
    struct VoxCanvasPath path;
    struct VoxCanvasStyle style;
    float transform[6];
    struct VoxCanvasPath const* clips;
    int clip_count;
    int stroke, cap, join, composite;
    float width, miter, global_alpha, blur;
    float const* dashes;
    int dash_count;
    float dash_offset;
    struct VoxCanvasFilter const* filters;
    int filter_count;
};
bool vox_skia_canvas_path(uint8_t* pixels, int width, int height, int pitch, int alpha_type, struct VoxCanvasCommand const* command);
#ifdef __cplusplus
}
#endif
