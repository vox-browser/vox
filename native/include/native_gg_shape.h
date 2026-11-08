// Optional gg.canvas shape renderer. With VOX_GG_SHAPES=1 the browser
// registers gg.canvas' port of the Graphite shape backend here, and every
// libVoxGraphite shape entry point first offers its descriptors to it.
// Descriptors it cannot reproduce exactly return 0, and the original backend
// draws them instead; a batch falls back as a whole.
#pragma once

#include "native_graphite_bridge.h"
#include "native_graphite_raster_cache.h"

#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <dlfcn.h>
#include <pthread.h>
#include <vector>

using VoxGGShapeDraw = int (*)(uint8_t* pixels, int width, int height, int pitch,
    int has_background, VoxGraphiteShape const* shape);

static VoxGGShapeDraw s_gg_shape_draw = nullptr;
static VoxGraphiteRasterCache s_gg_shape_raster_cache(16 * 1024 * 1024, 512, true);
static uint64_t s_gg_shape_cache_generation;
static uint64_t s_gg_shape_cache_hits;

static void clear_gg_shape_raster_cache()
{
    ++s_gg_shape_cache_generation;
    s_gg_shape_raster_cache.clear();
}

static bool gg_shape_cache_enabled()
{
    auto* disabled = std::getenv("VOX_DISABLE_GG_SHAPE_RASTER_CACHE");
    return !disabled || !*disabled;
}

static bool gg_shape_main_thread()
{
#if defined(__APPLE__)
    return pthread_main_np() != 0;
#else
    return true;
#endif
}

static void gg_shape_cache_diagnostic(int width, int height, int views, size_t bytes, bool hit)
{
    if (!std::getenv("VOX_GG_SHAPE_CACHE_DIAGNOSTICS")) return;
    using Clock = double (*)();
    static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
    double time = clock ? clock() : -1;
    if (clock && time < 0) return;
    static unsigned logged;
    if (logged++ >= 4096) return;
    std::fprintf(stderr, "VOX_GG_SHAPE_CACHE size=%dx%d views=%d bytes=%zu hit=%d hits=%llu t_us=%.3f\n",
        width, height, views, bytes, int(hit), (unsigned long long)s_gg_shape_cache_hits, time);
}

// Region callers publish only these views. Cache their packed pixels and
// original surface coordinates, avoiding a full GPU target on a hit. Keep
// results separate until every member of a region batch succeeds.
struct GGShapeRaster {
    std::vector<uint8_t> pixels;
    bool packed = false;
};

extern "C" void ladybird_v_skia_set_gg_shape_draw(VoxGGShapeDraw draw)
{
    if (s_gg_shape_draw != draw) clear_gg_shape_raster_cache();
    s_gg_shape_draw = draw;
}

// The region entry points draw on a whole surface_width x surface_height
// surface that is transparent outside their CPU views. Renders that surface
// into `surface` with gg.canvas, the views' pixels as its only backdrop.
static bool gg_draw_shape_views(VoxGraphitePixelRegion const* views, int count,
    int surface_width, int surface_height, int has_background, VoxGraphiteShape const& shape,
    GGShapeRaster& output)
{
    if (!s_gg_shape_draw || !gg_shape_main_thread() || !views || count <= 0 || surface_width <= 0 || surface_height <= 0
        || size_t(surface_width) * surface_height > 64u * 1024 * 1024)
        return false;
    size_t bytes = 0;
    for (int i = 0; i < count; ++i) {
        auto const& view = views[i];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > surface_width - view.x || view.height > surface_height - view.y
            || view.pitch < view.width * 4)
            return false;
        bytes += size_t(view.width) * view.height * 4;
    }
    auto renderer = s_gg_shape_draw;
    auto generation = s_gg_shape_cache_generation;
    VoxGraphiteRasterCache::Request cached;
    output.packed = gg_shape_cache_enabled() && bytes <= 64 * 1024 && count <= 64
        && shape.clip_out_count >= 0 && shape.clip_out_count <= 256;
    if (output.packed) {
        output.pixels.resize(bytes);
        size_t offset = 0;
        std::vector<int> rectangles;
        for (int i = 0; i < count; ++i) {
            auto const& view = views[i];
            rectangles.insert(rectangles.end(), {view.x, view.y, view.width, view.height});
            if (has_background)
                for (int y = 0; y < view.height; ++y)
                    std::memcpy(output.pixels.data() + offset + size_t(y) * view.width * 4,
                        view.pixels + size_t(y) * view.pitch, size_t(view.width) * 4);
            offset += size_t(view.width) * view.height * 4;
        }
        cached = s_gg_shape_raster_cache.prepare_patches(shape, surface_width, surface_height,
            int(bytes / 4), has_background != 0, output.pixels.data(), rectangles);
        if (cached.hit) {
            ++s_gg_shape_cache_hits;
            gg_shape_cache_diagnostic(surface_width, surface_height, count, bytes, true);
            return true;
        }
    }
    size_t const pitch = size_t(surface_width) * 4;
    std::vector<uint8_t> temporary;
    auto& surface = output.packed ? temporary : output.pixels;
    surface.assign(pitch * surface_height, 0);
    if (has_background)
        for (int i = 0; i < count; ++i)
            for (int y = 0; y < views[i].height; ++y)
                std::memcpy(surface.data() + (views[i].y + y) * pitch + views[i].x * 4,
                    views[i].pixels + size_t(y) * views[i].pitch, size_t(views[i].width) * 4);
    if (!renderer(surface.data(), surface_width, surface_height, int(pitch), has_background, &shape)) return false;
    if (output.packed) {
        size_t offset = 0;
        for (int i = 0; i < count; ++i) {
            auto const& view = views[i];
            for (int y = 0; y < view.height; ++y)
                std::memcpy(output.pixels.data() + offset + size_t(y) * view.width * 4,
                    surface.data() + (view.y + y) * pitch + view.x * 4, size_t(view.width) * 4);
            offset += size_t(view.width) * view.height * 4;
        }
        if (generation == s_gg_shape_cache_generation)
            s_gg_shape_raster_cache.finish(std::move(cached), output.pixels.data(), int(bytes));
    }
    gg_shape_cache_diagnostic(surface_width, surface_height, count, bytes, false);
    return true;
}

static void gg_copy_shape_views(VoxGraphitePixelRegion const* views, int count,
    int surface_width, GGShapeRaster const& raster)
{
    size_t const pitch = size_t(surface_width) * 4;
    size_t offset = 0;
    for (int i = 0; i < count; ++i) {
        for (int y = 0; y < views[i].height; ++y)
            std::memcpy(views[i].pixels + size_t(y) * views[i].pitch,
                raster.pixels.data() + (raster.packed ? offset + size_t(y) * views[i].width * 4
                    : (views[i].y + y) * pitch + views[i].x * 4),
                size_t(views[i].width) * 4);
        offset += size_t(views[i].width) * views[i].height * 4;
    }
}

static int gg_draw_shape_pixels(uint8_t* pixels, int width, int height, int pitch,
    int has_background, VoxGraphiteShape const* shape)
{
    if (!s_gg_shape_draw || !shape || !gg_shape_main_thread()) return 0;
    auto renderer = s_gg_shape_draw;
    if (!gg_shape_cache_enabled() || !pixels || width <= 0 || height <= 0 || pitch <= 0
        || size_t(pitch) < size_t(width) * 4 || size_t(width) * height > 16384
        || shape->clip_out_count < 0 || shape->clip_out_count > 256)
        return renderer(pixels, width, height, pitch, has_background, shape);
    auto generation = s_gg_shape_cache_generation;
    auto cached = s_gg_shape_raster_cache.prepare(*shape, width, height, pitch, has_background != 0, pixels);
    if (cached.hit) {
        ++s_gg_shape_cache_hits;
        gg_shape_cache_diagnostic(width, height, 1, size_t(width) * height * 4, true);
        return 1;
    }
    int result = renderer(pixels, width, height, pitch, has_background, shape);
    if (result && generation == s_gg_shape_cache_generation)
        s_gg_shape_raster_cache.finish(std::move(cached), pixels, pitch);
    gg_shape_cache_diagnostic(width, height, 1, size_t(width) * height * 4, false);
    return result;
}

static int gg_draw_shape_region_pixels(VoxGraphitePixelRegion const* region,
    int surface_width, int surface_height, int has_background, VoxGraphiteShape const* shape)
{
    GGShapeRaster surface;
    if (!shape || !gg_draw_shape_views(region, 1, surface_width, surface_height,
            has_background, *shape, surface))
        return 0;
    gg_copy_shape_views(region, 1, surface_width, surface);
    return 1;
}

static int gg_draw_rounded_parts_pixels(VoxGraphitePixelRegion const* regions, int count,
    int width, int height, int has_background, VoxGraphiteShape const* shape)
{
    GGShapeRaster surface;
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
    std::vector<GGShapeRaster> surfaces(static_cast<size_t>(count));
    for (int i = 0; i < count; ++i)
        if (!gg_draw_shape_views(&regions[i], 1, surface_width, surface_height,
                has_background, shapes[i], surfaces[size_t(i)]))
            return 0;
    for (int i = 0; i < count; ++i)
        gg_copy_shape_views(&regions[i], 1, surface_width, surfaces[size_t(i)]);
    return 1;
}
