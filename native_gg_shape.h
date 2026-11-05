// Optional gg.canvas shape renderer. With VOX_GG_SHAPES=1 the browser
// registers gg.canvas' port of the Graphite shape backend here, and every
// libVoxGraphite shape entry point first offers its descriptors to it.
// Descriptors it cannot reproduce exactly return 0, and the original backend
// draws them instead; a batch falls back as a whole.
#pragma once

#include "native_graphite_bridge.h"

#include <cstdint>
#include <cstring>
#include <vector>

using VoxGGShapeDraw = int (*)(uint8_t* pixels, int width, int height, int pitch,
    int has_background, VoxGraphiteShape const* shape);

static VoxGGShapeDraw s_gg_shape_draw = nullptr;

extern "C" void ladybird_v_skia_set_gg_shape_draw(VoxGGShapeDraw draw)
{
    s_gg_shape_draw = draw;
}

// The region entry points draw on a whole surface_width x surface_height
// surface that is transparent outside their CPU views. Renders that surface
// into `surface` with gg.canvas, the views' pixels as its only backdrop.
static bool gg_draw_shape_views(VoxGraphitePixelRegion const* views, int count,
    int surface_width, int surface_height, int has_background, VoxGraphiteShape const& shape,
    std::vector<uint8_t>& surface)
{
    if (!s_gg_shape_draw || !views || count <= 0 || surface_width <= 0 || surface_height <= 0
        || size_t(surface_width) * surface_height > 64u * 1024 * 1024)
        return false;
    for (int i = 0; i < count; ++i) {
        auto const& view = views[i];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > surface_width - view.x || view.height > surface_height - view.y
            || view.pitch < view.width * 4)
            return false;
    }
    size_t const pitch = size_t(surface_width) * 4;
    surface.assign(pitch * surface_height, 0);
    if (has_background)
        for (int i = 0; i < count; ++i)
            for (int y = 0; y < views[i].height; ++y)
                std::memcpy(surface.data() + (views[i].y + y) * pitch + views[i].x * 4,
                    views[i].pixels + size_t(y) * views[i].pitch, size_t(views[i].width) * 4);
    return s_gg_shape_draw(surface.data(), surface_width, surface_height, int(pitch),
        has_background, &shape) != 0;
}

static void gg_copy_shape_views(VoxGraphitePixelRegion const* views, int count,
    int surface_width, std::vector<uint8_t> const& surface)
{
    size_t const pitch = size_t(surface_width) * 4;
    for (int i = 0; i < count; ++i)
        for (int y = 0; y < views[i].height; ++y)
            std::memcpy(views[i].pixels + size_t(y) * views[i].pitch,
                surface.data() + (views[i].y + y) * pitch + views[i].x * 4,
                size_t(views[i].width) * 4);
}

static int gg_draw_shape_pixels(uint8_t* pixels, int width, int height, int pitch,
    int has_background, VoxGraphiteShape const* shape)
{
    return s_gg_shape_draw && shape
        && s_gg_shape_draw(pixels, width, height, pitch, has_background, shape);
}

static int gg_draw_shape_region_pixels(VoxGraphitePixelRegion const* region,
    int surface_width, int surface_height, int has_background, VoxGraphiteShape const* shape)
{
    std::vector<uint8_t> surface;
    if (!shape || !gg_draw_shape_views(region, 1, surface_width, surface_height,
            has_background, *shape, surface))
        return 0;
    gg_copy_shape_views(region, 1, surface_width, surface);
    return 1;
}

static int gg_draw_rounded_parts_pixels(VoxGraphitePixelRegion const* regions, int count,
    int width, int height, int has_background, VoxGraphiteShape const* shape)
{
    std::vector<uint8_t> surface;
    if (!shape || !gg_draw_shape_views(regions, count, width, height, has_background,
            *shape, surface))
        return 0;
    gg_copy_shape_views(regions, count, width, surface);
    return 1;
}

static int gg_draw_shape_regions_pixels(VoxGraphitePixelRegion const* regions,
    VoxGraphiteShape const* shapes, int count, int surface_width, int surface_height,
    int has_background)
{
    if (!regions || !shapes || count <= 0) return 0;
    std::vector<std::vector<uint8_t>> surfaces(static_cast<size_t>(count));
    for (int i = 0; i < count; ++i)
        if (!gg_draw_shape_views(&regions[i], 1, surface_width, surface_height,
                has_background, shapes[i], surfaces[size_t(i)]))
            return 0;
    for (int i = 0; i < count; ++i)
        gg_copy_shape_views(&regions[i], 1, surface_width, surfaces[size_t(i)]);
    return 1;
}
