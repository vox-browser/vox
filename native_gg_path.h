// Optional gg.canvas path renderer. With VOX_GG_PATHS=1 the browser registers
// gg.canvas' port of the Graphite path backend here, and the libVoxGraphite
// path and SVG image entry points first offer their descriptors to it. Descriptors it
// cannot reproduce exactly return 0, and the original backend draws them.
#pragma once

#include "native_graphite_bridge.h"
#include "native_svg_path_cache.h"

#include <cstdint>
#include <cstring>
#include <vector>

using VoxGGPathDraw = int (*)(uint8_t* pixels, int width, int height, int pitch,
    int has_background, VoxGraphitePath const* path);

static VoxGGPathDraw s_gg_path_draw = nullptr;
static VoxSmallSvgPathCache s_small_svg_path_cache;

extern "C" int ladybird_v_skia_set_small_svg_path_cache(int enabled)
{
    int previous = s_small_svg_path_cache.enabled;
    s_small_svg_path_cache.enabled = enabled != 0;
    return previous;
}

extern "C" uint64_t ladybird_v_skia_small_svg_path_cache_hits()
{
    return s_small_svg_path_cache.hits;
}

extern "C" void ladybird_v_skia_set_gg_path_draw(VoxGGPathDraw draw)
{
    if (s_gg_path_draw != draw) s_small_svg_path_cache.clear();
    s_gg_path_draw = draw;
}

// The SVG image entry points draw a batch of descriptors after a parent
// matrix, clipped to the image's viewport.
using VoxGGSvgImageDraw = int (*)(uint8_t* pixels, int width, int height, int pitch, int flags,
    VoxGraphitePath const* paths, int count, float const* parent, float const* viewport,
    float const* rounded_clip);

static VoxGGSvgImageDraw s_gg_svg_image_draw = nullptr;

extern "C" void ladybird_v_skia_set_gg_svg_image_draw(VoxGGSvgImageDraw draw)
{
    s_gg_svg_image_draw = draw;
}

// The region entry points draw on a whole surface_width x surface_height
// surface that is transparent outside their CPU views. Renders that surface
// into `surface` with gg.canvas, the views' pixels as its only backdrop.
static bool gg_draw_path_views(VoxGraphitePixelRegion const* views, int count,
    int surface_width, int surface_height, int has_background, VoxGraphitePath const& path,
    std::vector<uint8_t>& surface)
{
    if (!s_gg_path_draw || !views || count <= 0 || surface_width <= 0 || surface_height <= 0
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
    return s_gg_path_draw(surface.data(), surface_width, surface_height, int(pitch),
        has_background, &path) != 0;
}

static void gg_copy_path_views(VoxGraphitePixelRegion const* views, int count,
    int surface_width, std::vector<uint8_t> const& surface)
{
    size_t const pitch = size_t(surface_width) * 4;
    for (int i = 0; i < count; ++i)
        for (int y = 0; y < views[i].height; ++y)
            std::memcpy(views[i].pixels + size_t(y) * views[i].pitch,
                surface.data() + (views[i].y + y) * pitch + views[i].x * 4,
                size_t(views[i].width) * 4);
}

static int gg_draw_path_pixels(uint8_t* pixels, int width, int height, int pitch,
    int has_background, VoxGraphitePath const* path)
{
    return s_small_svg_path_cache.draw(s_gg_path_draw, pixels, width, height,
        pitch, has_background, path);
}

static int gg_draw_path_region_pixels(VoxGraphitePixelRegion const* region,
    int surface_width, int surface_height, int has_background, VoxGraphitePath const* path)
{
    std::vector<uint8_t> surface;
    if (!path || !gg_draw_path_views(region, 1, surface_width, surface_height,
            has_background, *path, surface))
        return 0;
    gg_copy_path_views(region, 1, surface_width, surface);
    return 1;
}

static int gg_draw_svg_image_pixels(uint8_t* pixels, int width, int height, int pitch,
    int flags, VoxGraphitePath const* paths, int count, float const* parent,
    float const* viewport, float const* rounded_clip)
{
    return s_gg_svg_image_draw
        && s_gg_svg_image_draw(pixels, width, height, pitch, flags, paths, count, parent,
            viewport, rounded_clip);
}

// Like vox_graphite_draw_svg_image_region_pixels(): the image is drawn on a
// whole width x height surface that is transparent outside the region (or
// holds the region's pixels with VOX_GRAPHITE_SVG_BACKDROP), and the region
// is copied back.
static int gg_draw_svg_image_region_pixels(VoxGraphitePixelRegion const* region, int width,
    int height, int flags, VoxGraphitePath const* paths, int count, float const* parent,
    float const* viewport, float const* rounded_clip)
{
    if (!s_gg_svg_image_draw || !region || !region->pixels || width <= 0 || height <= 0
        || size_t(width) * height > 64u * 1024 * 1024 || region->x < 0 || region->y < 0
        || region->width <= 0 || region->height <= 0 || region->width > width - region->x
        || region->height > height - region->y || region->pitch < region->width * 4)
        return 0;
    size_t const pitch = size_t(width) * 4;
    std::vector<uint8_t> surface(pitch * height, 0);
    if (flags & VOX_GRAPHITE_SVG_BACKDROP)
        for (int y = 0; y < region->height; ++y)
            std::memcpy(surface.data() + (region->y + y) * pitch + region->x * 4,
                region->pixels + size_t(y) * region->pitch, size_t(region->width) * 4);
    if (!s_gg_svg_image_draw(surface.data(), width, height, int(pitch), flags, paths, count,
            parent, viewport, rounded_clip))
        return 0;
    for (int y = 0; y < region->height; ++y)
        std::memcpy(region->pixels + size_t(y) * region->pitch,
            surface.data() + (region->y + y) * pitch + region->x * 4, size_t(region->width) * 4);
    return 1;
}

static int gg_draw_path_parts_pixels(VoxGraphitePixelRegion const* regions, int count,
    int width, int height, int has_background, VoxGraphitePath const* path)
{
    std::vector<uint8_t> surface;
    if (!path || !gg_draw_path_views(regions, count, width, height, has_background,
            *path, surface))
        return 0;
    gg_copy_path_views(regions, count, width, surface);
    return 1;
}
