#pragma once

#include "../../cpuraster/scan_workers.h"
#include "native_chromium_screen_blend.h"
#include "native_opacity_group_darwin.h"

typedef struct {
    const uint8_t *layer, *backdrop;
    uint8_t *result;
    size_t layer_pitch, backdrop_pitch, result_pitch, width;
    float opacity;
    void (*blend)(const uint8_t *, const uint8_t *, uint8_t *, size_t, float);
} VoxOpacityComposite;

static void native_composite_opacity_row_range(void *context, int32_t first, int32_t end)
{
    const VoxOpacityComposite *composite = (const VoxOpacityComposite *)context;
    for (int32_t row = first; row < end; ++row) {
        composite->blend(composite->layer + (size_t)row * composite->layer_pitch,
            composite->backdrop + (size_t)row * composite->backdrop_pitch,
            composite->result + (size_t)row * composite->result_pitch,
            composite->width, composite->opacity);
    }
}

// The caller owns all three bitmaps until the workers join. Keep complete
// rows together so every span uses the same SIMD blocks and scalar tail.
static void native_composite_opacity_rows(const uint8_t *layer, size_t layer_pitch,
    const uint8_t *backdrop, size_t backdrop_pitch, uint8_t *result, size_t result_pitch,
    size_t width, int32_t rows, float opacity, int screen)
{
    if (!width || rows <= 0) return;
    VoxOpacityComposite composite = {layer, backdrop, result, layer_pitch, backdrop_pitch,
        result_pitch, width, opacity,
        screen ? native_composite_screen_pixels : native_composite_opacity_pixels};
    const size_t pixels_per_lane = 64 * 1024;
    size_t lanes = width * (size_t)rows / pixels_per_lane;
    if (lanes > VOX_SCAN_WORKERS_MAX) lanes = VOX_SCAN_WORKERS_MAX;
    if (lanes > (size_t)rows) lanes = (size_t)rows;
    if (lanes > 1 && !vox_scan_workers_disabled())
        vox_scan_workers_run(&composite, rows, (int32_t)lanes, native_composite_opacity_row_range);
    else
        native_composite_opacity_row_range(&composite, 0, rows);
}
