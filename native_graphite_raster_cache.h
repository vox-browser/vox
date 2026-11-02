#ifndef VOX_NATIVE_GRAPHITE_RASTER_CACHE_H
#define VOX_NATIVE_GRAPHITE_RASTER_CACHE_H

#include "native_graphite_bridge.h"
#include "native_raster_snapshot.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <list>
#include <memory>
#include <vector>
#include <unordered_map>

// Keep canonical admission available for diagnostics. Its live vlang cohort
// regressed both pairs, so production retains the prior allocation policy.
static inline bool vox_canonical_path_admission_enabled()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_ENABLE_CANONICAL_PATH_ADMISSION");
        return value && !std::strcmp(value, "1")
            && !std::getenv("VOX_DISABLE_CANONICAL_PATH_ADMISSION");
    }();
    return enabled;
}

// Memoize complete GPU image, shape, shadow and path draws, including their input backdrop.
// Sources can be canvas/video buffers, animated frames or recycled allocations: addresses
// are never an identity or a promise of immutability. Every hit compares the
// actual source bytes and every parameter before copying owned output pixels.
// The caller serializes access with the renderer's existing mutex.
class VoxGraphiteRasterCache {
    struct Entry {
        VoxGraphiteImage image {};
        std::vector<VoxGraphiteImage> tiles;
        VoxGraphiteShape shape {};
        VoxGraphiteShadow shadow {};
        VoxGraphitePath path {};
        bool is_path = false;
        bool is_shape = false;
        bool is_shadow = false;
        int surface_width = 0, surface_height = 0;
        int region_x = 0, region_y = 0;
        int width = 0, height = 0;
        bool has_background = false;
        std::shared_ptr<std::vector<uint8_t> const> source;
        std::vector<uint8_t> extra;
        VoxRasterSnapshot background, output;
        size_t bytes() const { return tiles.size() * sizeof(VoxGraphiteImage) + extra.size() + background.size() + output.size(); }
    };
    struct Rows {
        uint8_t const* pixels;
        size_t bytes, pitch, height;
        bool equal(std::vector<uint8_t> const& copy) const
        {
            if (copy.size() != bytes * height) return false;
            if (!bytes) return true;
            if (pitch == bytes || height == 1)
                return !std::memcmp(pixels, copy.data(), copy.size());
            for (size_t y = 0; y < height; ++y)
                if (std::memcmp(pixels + y * pitch, copy.data() + y * bytes, bytes)) return false;
            return true;
        }
        bool equal(VoxRasterSnapshot const& copy) const
        {
            return copy.equal(pixels, bytes, pitch, height);
        }
        bool equal(VoxRasterSnapshot const& copy, VoxRasterSnapshot::Rect ignore) const
        {
            return copy.equal_outside_rectangle(pixels, bytes, pitch, height, ignore);
        }
        std::vector<uint8_t> copy() const
        {
            std::vector<uint8_t> result(bytes * height);
            if (!bytes) return result;
            if (pitch == bytes || height == 1) {
                std::memcpy(result.data(), pixels, result.size());
                return result;
            }
            for (size_t y = 0; y < height; ++y)
                std::memcpy(result.data() + y * bytes, pixels + y * pitch, bytes);
            return result;
        }
    };
    static bool same_image(VoxGraphiteImage const& a, VoxGraphiteImage const& b)
    {
        return !std::memcmp(a.matrix, b.matrix, sizeof(a.matrix))
            && !std::memcmp(a.source, b.source, sizeof(a.source))
            && !std::memcmp(a.destination, b.destination, sizeof(a.destination))
            && !std::memcmp(a.clip, b.clip, sizeof(a.clip))
            && !std::memcmp(&a.opacity, &b.opacity, sizeof(a.opacity))
            && a.width == b.width && a.height == b.height && a.flags == b.flags
            && a.nearest == b.nearest && a.has_color_profile == b.has_color_profile
            && a.has_background_color == b.has_background_color
            && (!a.has_background_color || !std::memcmp(a.background_rgba, b.background_rgba,
                sizeof(a.background_rgba)))
            && a.border_width == b.border_width
            && (a.border_width == 0 || (!std::memcmp(a.border_rect, b.border_rect, sizeof(a.border_rect))
                && !std::memcmp(a.border_rgba, b.border_rgba, sizeof(a.border_rgba))))
            && (!a.has_color_profile || !std::memcmp(a.color_profile, b.color_profile,
                sizeof(a.color_profile)));
    }
    static VoxRasterSnapshot::Rect opaque_image_interior(VoxGraphiteImage const& image,
        int width, int height)
    {
        // Planar YUV has no alpha plane. Restrict the proof to complete source
        // samples and axis-aligned positive transforms; all other images keep
        // exact backdrop comparisons. Leave two device pixels at every edge
        // for clipping/MSAA/filtering coverage, including fractional geometry.
        auto const* m = image.matrix;
        if (!(image.flags & 4) || image.opacity != 1 || image.has_color_profile
            || m[1] != 0 || m[3] != 0 || m[6] != 0 || m[7] != 0 || m[8] != 1
            || !(m[0] > 0) || !(m[4] > 0)) return {};
        for (int i = 0; i < 9; ++i) if (!std::isfinite(m[i])) return {};
        // The coverage guard also needs a bounded float error. Huge local
        // coordinates canceled by a translation can lose whole device pixels
        // in GPU arithmetic even when the final double-precision bounds fit.
        constexpr double coordinate_limit = 65536;
        if (m[0] < 1.0f / 1024 || m[0] > 1024 || m[4] < 1.0f / 1024 || m[4] > 1024
            || std::abs(m[2]) > coordinate_limit || std::abs(m[5]) > coordinate_limit) return {};
        for (int i = 0; i < 4; ++i)
            if (!std::isfinite(image.source[i]) || !std::isfinite(image.destination[i])
                || std::abs(image.destination[i]) > coordinate_limit) return {};
        for (float v : image.clip)
            if (!std::isfinite(v) || std::abs(v) > coordinate_limit) return {};
        if (image.source[0] < 0 || image.source[1] < 0
            || !(image.source[2] > 0) || !(image.source[3] > 0)
            || double(image.source[0]) + image.source[2] > image.width
            || double(image.source[1]) + image.source[3] > image.height
            || !(image.destination[2] > 0) || !(image.destination[3] > 0)
            || !(image.clip[2] > 0) || !(image.clip[3] > 0)) return {};
        for (int i = 4; i < 12; ++i) if (image.clip[i] < 0) return {};
        double left = std::max(double(image.destination[0]),
            double(image.clip[0]) + std::max(image.clip[4], image.clip[10]));
        double top = std::max(double(image.destination[1]),
            double(image.clip[1]) + std::max(image.clip[5], image.clip[7]));
        double right = std::min(double(image.destination[0]) + image.destination[2],
            double(image.clip[0]) + image.clip[2] - std::max(image.clip[6], image.clip[8]));
        double bottom = std::min(double(image.destination[1]) + image.destination[3],
            double(image.clip[1]) + image.clip[3] - std::max(image.clip[9], image.clip[11]));
        if (std::abs(left * m[0]) > coordinate_limit || std::abs(right * m[0]) > coordinate_limit
            || std::abs(top * m[4]) > coordinate_limit || std::abs(bottom * m[4]) > coordinate_limit) return {};
        auto bound = [](double value, int limit) { return size_t(std::clamp(value, 0.0, double(limit))); };
        VoxRasterSnapshot::Rect result {
            bound(std::ceil(left * m[0] + m[2] + 2), width),
            bound(std::ceil(top * m[4] + m[5] + 2), height),
            bound(std::floor(right * m[0] + m[2] - 2), width),
            bound(std::floor(bottom * m[4] + m[5] - 2), height)
        };
        if (result.left >= result.right || result.top >= result.bottom) return {};
        return result;
    }
    static bool same_shape(VoxGraphiteShape const& a, VoxGraphiteShape const& b)
    {
        return !std::memcmp(a.matrix, b.matrix, sizeof(a.matrix))
            && !std::memcmp(a.rect, b.rect, sizeof(a.rect))
            && !std::memcmp(&a.thickness, &b.thickness, sizeof(a.thickness))
            && a.red == b.red && a.green == b.green && a.blue == b.blue && a.alpha == b.alpha
            && (a.fill < 2 || !std::memcmp(a.border_widths, b.border_widths, sizeof(a.border_widths)))
            && a.fill == b.fill && a.anti_alias == b.anti_alias && a.force_msaa == b.force_msaa
            && a.clip_out_count == b.clip_out_count && a.has_float_color == b.has_float_color
            && (!a.has_float_color || !std::memcmp(a.float_color, b.float_color, sizeof(a.float_color)))
            && a.has_underlay == b.has_underlay
            && (!a.has_underlay || (!std::memcmp(a.underlay_rect, b.underlay_rect, sizeof(a.underlay_rect))
                && !std::memcmp(a.underlay_rgba, b.underlay_rgba, sizeof(a.underlay_rgba))
                && a.has_float_underlay_color == b.has_float_underlay_color
                && (!a.has_float_underlay_color || !std::memcmp(a.underlay_float_color,
                    b.underlay_float_color, sizeof(a.underlay_float_color)))));
    }
    static bool same_shadow(VoxGraphiteShadow const& a, VoxGraphiteShadow const& b)
    {
        return !std::memcmp(a.matrix, b.matrix, sizeof(a.matrix))
            && !std::memcmp(a.shadow, b.shadow, sizeof(a.shadow))
            && !std::memcmp(a.content, b.content, sizeof(a.content))
            && !std::memcmp(&a.blur, &b.blur, sizeof(a.blur))
            && a.red == b.red && a.green == b.green && a.blue == b.blue && a.alpha == b.alpha
            && a.has_float_color == b.has_float_color
            && (!a.has_float_color || !std::memcmp(a.float_color, b.float_color, sizeof(a.float_color)));
    }
    static bool same_path(VoxGraphitePath const& a, VoxGraphitePath const& b)
    {
        return !std::memcmp(a.matrix, b.matrix, sizeof(a.matrix))
            && a.segment_count == b.segment_count && a.even_odd == b.even_odd
            && a.red == b.red && a.green == b.green && a.blue == b.blue && a.alpha == b.alpha
            && a.stroke == b.stroke && a.line_cap == b.line_cap && a.line_join == b.line_join
            && a.non_scaling_stroke == b.non_scaling_stroke
            && a.has_float_alpha == b.has_float_alpha
            && a.has_float_color == b.has_float_color
            && (!a.has_float_color || !std::memcmp(a.float_color, b.float_color, sizeof(a.float_color)))
            && !std::memcmp(&a.stroke_width, &b.stroke_width, sizeof(a.stroke_width))
            && !std::memcmp(&a.miter_limit, &b.miter_limit, sizeof(a.miter_limit))
            && a.gradient == b.gradient && a.tile_mode == b.tile_mode
            && a.linear_color_space == b.linear_color_space && a.stop_count == b.stop_count
            && a.gradient_premul == b.gradient_premul
            && !std::memcmp(a.gradient_points, b.gradient_points, sizeof(a.gradient_points))
            && !std::memcmp(a.gradient_matrix, b.gradient_matrix, sizeof(a.gradient_matrix))
            && !std::memcmp(&a.opacity, &b.opacity, sizeof(a.opacity))
            && a.has_clip == b.has_clip
            && (!a.has_clip || !std::memcmp(a.clip, b.clip, sizeof(a.clip)))
            && a.has_ancestor_clip == b.has_ancestor_clip
            && (!a.has_ancestor_clip || !std::memcmp(a.ancestor_clip, b.ancestor_clip, sizeof(a.ancestor_clip)));
    }
    std::list<std::unique_ptr<Entry>> entries;
    // Small sprite draws share a large decoded sheet. Retain one immutable
    // source snapshot, rather than charging and copying the sheet per draw.
    // Pool membership is by value, never by the caller's address.
    std::vector<std::weak_ptr<std::vector<uint8_t> const>> sources;
    std::unordered_map<void const*, size_t> source_entries;
    std::shared_ptr<std::vector<uint8_t> const> intern_source(Rows rows)
    {
        for (auto it = sources.begin(); it != sources.end();) {
            auto source = it->lock();
            if (!source) { it = sources.erase(it); continue; }
            if (rows.equal(*source)) return source;
            ++it;
        }
        auto source = std::make_shared<std::vector<uint8_t> const>(rows.copy());
        sources.push_back(source);
        return source;
    }
    void evict_back()
    {
        auto const& entry = *entries.back();
        retained_bytes -= entry.bytes();
        auto it = source_entries.find(entry.source.get());
        if (--it->second == 0) {
            retained_bytes -= entry.source->size();
            source_entries.erase(it);
        }
        entries.pop_back();
    }
    size_t retained_bytes = 0;
    size_t byte_limit, entry_limit;
    bool repeat_large_draws;
    std::array<uint64_t, 256> recent_draws {};
    size_t recent_draw_count = 0, recent_draw_next = 0;

    // This fingerprint controls allocation only. Collisions can admit an
    // unnecessary entry, but never return cached pixels: every hit above
    // still compares complete parameters, source and backdrop values.
    bool admit_large_draw(Entry const& entry, Rows source, Rows backdrop, Rows extra)
    {
        uint64_t fingerprint = 14695981039346656037ull;
        auto bytes = [&](void const* data, size_t size) {
            auto* p = static_cast<uint8_t const*>(data);
            for (size_t i = 0; i < size; ++i)
                fingerprint = (fingerprint ^ p[i]) * 1099511628211ull;
        };
        auto rows = [&](Rows input) {
            bytes(&input.bytes, sizeof(input.bytes));
            bytes(&input.height, sizeof(input.height));
            size_t size = input.bytes * input.height;
            // Sample logical pixels, excluding row padding and addresses.
            for (size_t i = 0; i < std::min(size, size_t(64)); ++i) {
                size_t at = size <= 64 ? i : i * ((size - 1) / 63);
                bytes(input.pixels + (at / input.bytes) * input.pitch + at % input.bytes, 1);
            }
        };
        int dimensions[] {entry.width, entry.height, entry.surface_width, entry.surface_height,
            entry.region_x, entry.region_y, int(entry.has_background)};
        bytes(dimensions, sizeof(dimensions));
        if (entry.is_shape) {
            auto shape = entry.shape;
            shape.clip_outs = nullptr;
            bytes(&shape, sizeof(shape));
        } else if (entry.is_path) {
            bool const canonical = vox_canonical_path_admission_enabled();
            auto const& path = entry.path;
            if (!canonical) {
                auto old_key = path;
                old_key.segments = nullptr;
                old_key.stops = nullptr;
                bytes(&old_key, sizeof(old_key));
            } else {
                // Match same_path(): padding, addresses and disabled payloads
                // are not identity. Hashing their object representation can
                // prevent an equal second draw from ever entering the cache.
                auto field = [&](auto const& value) { bytes(&value, sizeof(value)); };
                field(path.matrix); field(path.segment_count); field(path.even_odd);
                field(path.red); field(path.green); field(path.blue); field(path.alpha);
                field(path.stroke); field(path.line_cap); field(path.line_join);
                field(path.non_scaling_stroke); field(path.has_float_alpha);
                field(path.has_float_color);
                if (path.has_float_color) field(path.float_color);
                field(path.stroke_width); field(path.miter_limit);
                field(path.gradient); field(path.tile_mode); field(path.linear_color_space);
                field(path.stop_count); field(path.gradient_premul);
                field(path.gradient_points); field(path.gradient_matrix); field(path.opacity);
                field(path.has_clip);
                if (path.has_clip) field(path.clip);
                field(path.has_ancestor_clip);
                if (path.has_ancestor_clip) field(path.ancestor_clip);
            }
        } else {
            bytes(&entry.shadow, sizeof(entry.shadow));
        }
        rows(source);
        rows(extra);
        if (entry.has_background) rows(backdrop);
        bool found = std::find(recent_draws.begin(), recent_draws.begin() + recent_draw_count,
            fingerprint) != recent_draws.begin() + recent_draw_count;
        if (!found) {
            recent_draws[recent_draw_next] = fingerprint;
            recent_draw_next = (recent_draw_next + 1) % recent_draws.size();
            recent_draw_count = std::min(recent_draw_count + 1, recent_draws.size());
        }
        if (std::getenv("VOX_RASTER_ADMISSION_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_RASTER_ADMISSION admit=%d kind=%s\n", found,
                entry.is_shape ? "shape" : entry.is_path ? "path" : "shadow");
        return found;
    }
    static constexpr size_t max_entry_bytes = 8 * 1024 * 1024;
    // Retina photo draws include their decoded source and both raster rows.
    // Keep the total cache budget unchanged, but admit these larger image
    // entries so an unchanged visible photo need not submit GPU work again.
    static constexpr size_t max_image_entry_bytes = 16 * 1024 * 1024;

public:
    explicit VoxGraphiteRasterCache(size_t bytes = 32 * 1024 * 1024, size_t count = 512,
        bool repeat_large = false)
        : byte_limit(bytes), entry_limit(count), repeat_large_draws(repeat_large) { }
    struct Request {
        bool hit = false;
        std::unique_ptr<Entry> pending;
    };
    Request prepare(VoxGraphiteImage const& image, int width, int height,
        int pitch, bool has_background, uint8_t* pixels)
    {
        Entry parameters;
        parameters.image = image;
        return prepare_image(parameters, width, height, pitch, has_background, pixels);
    }
    // A separate hit destination leaves the input view immutable during a
    // transactional batch. Misses still snapshot the actual input backdrop.
    Request prepare_region(VoxGraphiteImage const& image, int surface_width,
        int surface_height, VoxGraphitePixelRegion const& region, bool has_background,
        uint8_t* cached_output = nullptr, int output_pitch = 0)
    {
        if (surface_width <= 0 || surface_height <= 0 || region.x < 0 || region.y < 0
            || region.width <= 0 || region.height <= 0
            || region.width > surface_width || region.height > surface_height
            || region.x > surface_width - region.width
            || region.y > surface_height - region.height) return {};
        Entry parameters;
        parameters.image = image;
        parameters.surface_width = surface_width;
        parameters.surface_height = surface_height;
        parameters.region_x = region.x;
        parameters.region_y = region.y;
        return prepare_image(parameters, region.width, region.height, region.pitch,
            has_background, region.pixels, cached_output, output_pitch);
    }
    // Background placements share one source during a call. Across calls the
    // cache still owns and compares its bytes, including animated/reused data.
    Request prepare_tiles(VoxGraphiteImage const* images, int count, int width,
        int height, int pitch, bool has_background, uint8_t* pixels)
    {
        if (!images || count <= 0 || !entry_limit
            || size_t(count) > std::min(byte_limit, max_entry_bytes) / sizeof(VoxGraphiteImage)) return {};
        auto const& first = images[0];
        for (int i = 1; i < count; ++i) {
            auto const& image = images[i];
            if (image.pixels != first.pixels || image.width != first.width
                || image.height != first.height || image.pitch != first.pitch
                || (image.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
                    != (first.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)) return {};
        }
        Entry parameters;
        parameters.image = first;
        parameters.tiles.assign(images, images + count);
        return prepare_image(parameters, width, height, pitch, has_background, pixels);
    }
private:
    Request prepare_image(Entry const& parameters, int width, int height,
        int pitch, bool has_background, uint8_t* pixels,
        uint8_t* cached_output = nullptr, int output_pitch = 0)
    {
        auto const& image = parameters.image;
        Request request;
        if (!pixels || !image.pixels || width <= 0 || height <= 0 || pitch <= 0
            || image.width <= 0 || image.height <= 0 || image.pitch <= 0
            || size_t(pitch) < size_t(width) * 4 || !entry_limit) return request;
        // Bound dimensions before multiplication, allocations and source reads.
        // This still bypasses oversized one-off photos/video frames.
        size_t limit = std::min(byte_limit, max_image_entry_bytes);
        Rows source {image.pixels, size_t(image.width) * 4, size_t(image.pitch), size_t(image.height)};
        if (image.flags & 4) {
            size_t w = image.width, h = image.height;
            size_t uv_w = image.flags & 16 ? w : (w + 1) / 2;
            size_t uv_h = image.flags & 16 ? h : (h + 1) / 2;
            if (w > limit / h || uv_w > limit / uv_h) return request;
            source = {image.pixels, w * h + 2 * uv_w * uv_h, 0, 1};
        } else if (source.bytes > source.pitch) return request;
        return prepare_entry(parameters, source, width, height, pitch, has_background, pixels,
            {nullptr, 0, 0, 1}, cached_output, output_pitch);
    }
public:
    Request prepare(VoxGraphiteShadow const& shadow, int width, int height,
        int pitch, bool has_background, uint8_t* pixels)
    {
        Entry parameters;
        parameters.is_shadow = true;
        parameters.shadow = shadow;
        return prepare_entry(parameters, Rows {nullptr, 0, 0, 1}, width, height,
            pitch, has_background, pixels);
    }
    Request prepare(VoxGraphiteShape const& shape, int width, int height,
        int pitch, bool has_background, uint8_t* pixels)
    {
        if (shape.clip_out_count < 0 || (shape.clip_out_count && !shape.clip_outs)) return {};
        Entry parameters;
        parameters.is_shape = true;
        parameters.shape = shape;
        return prepare_entry(parameters,
            Rows {reinterpret_cast<uint8_t const*>(shape.clip_outs), size_t(shape.clip_out_count) * 4 * sizeof(float), 0, 1},
            width, height, pitch, has_background, pixels);
    }
    Request prepare(VoxGraphitePath const& path, int width, int height,
        int pitch, bool has_background, uint8_t* pixels)
    {
        if (!path.segments || path.segment_count <= 0 || path.stop_count < 0
            || (path.stop_count && !path.stops)) return {};
        Entry parameters;
        parameters.is_path = true;
        parameters.path = path;
        return prepare_entry(parameters,
            Rows {reinterpret_cast<uint8_t const*>(path.segments), size_t(path.segment_count) * 12 * sizeof(float), 0, 1},
            width, height, pitch, has_background, pixels,
            Rows {reinterpret_cast<uint8_t const*>(path.stops), size_t(path.stop_count) * 5 * sizeof(float), 0, 1});
    }
    Request prepare_path_patches(VoxGraphitePath const& path, int surface_width,
        int surface_height, int pixel_count, bool has_background, uint8_t* pixels,
        std::vector<int> const& rectangles)
    {
        if (!path.segments || path.segment_count <= 0 || path.gradient || path.stop_count
            || surface_width <= 0 || surface_height <= 0 || pixel_count <= 0
            || size_t(pixel_count) > max_entry_bytes / 4) return {};
        Entry parameters;
        parameters.is_path = true;
        parameters.path = path;
        parameters.surface_width = surface_width;
        parameters.surface_height = surface_height;
        return prepare_entry(parameters,
            Rows {reinterpret_cast<uint8_t const*>(path.segments), size_t(path.segment_count) * 12 * sizeof(float), 0, 1},
            pixel_count, 1, pixel_count * 4, has_background, pixels,
            Rows {reinterpret_cast<uint8_t const*>(rectangles.data()), rectangles.size() * sizeof(int), 0, 1});
    }
    // Packed patches still depend on the original surface dimensions: GPU
    // clipping and coverage arithmetic must retain the same raster coordinates.
    Request prepare_patches(VoxGraphiteShape const& shape, int surface_width,
        int surface_height, int pixel_count, bool has_background, uint8_t* pixels)
    {
        if (shape.clip_out_count < 0 || (shape.clip_out_count && !shape.clip_outs)
            || surface_width <= 0 || surface_height <= 0
            || pixel_count <= 0 || size_t(pixel_count) > max_entry_bytes / 4) return {};
        Entry parameters;
        parameters.is_shape = true;
        parameters.shape = shape;
        parameters.surface_width = surface_width;
        parameters.surface_height = surface_height;
        return prepare_entry(parameters,
            Rows {reinterpret_cast<uint8_t const*>(shape.clip_outs), size_t(shape.clip_out_count) * 4 * sizeof(float), 0, 1}, pixel_count, 1,
            pixel_count * 4, has_background, pixels);
    }
private:
    Request prepare_entry(Entry const& parameters, Rows source, int width, int height,
        int pitch, bool has_background, uint8_t* pixels, Rows extra = {nullptr, 0, 0, 1},
        uint8_t* cached_output = nullptr, int output_pitch = 0)
    {
        Request request;
        if (!pixels || width <= 0 || height <= 0 || pitch <= 0
            || size_t(pitch) < size_t(width) * 4 || !entry_limit) return request;
        if (cached_output ? output_pitch <= 0 || size_t(output_pitch) < size_t(width) * 4
                          : output_pitch != 0) return request;
        auto* output = cached_output ? cached_output : pixels;
        int copy_pitch = cached_output ? output_pitch : pitch;
        // Small controls in the root layer use complete 544x256 Chromium
        // tiles, including their backdrop. Admit that raw pair even when the
        // control itself occupies only a few pixels. Retained entries still
        // obey the unchanged byte/entry budgets after lossless compression.
        constexpr size_t shape_limit = 2 * 1024 * 1024;
        bool is_image = !parameters.is_shape && !parameters.is_shadow && !parameters.is_path;
        // Flat SVG surfaces can shrink greatly in the row codec. Bound their
        // temporary raw pair separately, then enforce the retained budget on
        // the actual compressed result before admitting it.
        size_t limit = parameters.is_path ? std::min(byte_limit, max_entry_bytes) * 2
            : std::min(byte_limit, parameters.is_shape ? shape_limit
                : is_image ? max_image_entry_bytes : max_entry_bytes);
        Rows backdrop {pixels, size_t(width) * 4, size_t(pitch), size_t(height)};
        if (source.bytes > limit / source.height || extra.bytes > limit / extra.height
            || backdrop.bytes > limit / backdrop.height)
            return request;
        size_t immutable_cost = source.bytes * source.height + extra.bytes * extra.height
            + parameters.tiles.size() * sizeof(VoxGraphiteImage);
        if (immutable_cost > byte_limit) return request;
        size_t cost = immutable_cost + backdrop.bytes * backdrop.height * (has_background ? 2 : 1);
        if (cost > limit) return request;
        auto opaque = is_image && parameters.tiles.empty() && !parameters.surface_width
            ? opaque_image_interior(parameters.image, width, height) : VoxRasterSnapshot::Rect{};
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            auto const& entry = **it;
            bool exact_region = entry.width == width && entry.height == height
                && entry.region_x == parameters.region_x && entry.region_y == parameters.region_y;
            bool contained_region = false;
#ifndef VOX_DISABLE_IMAGE_REGION_SUBVIEWS
            // An image draw blends each destination pixel independently. A
            // smaller view may reuse those exact pixels from a larger cached
            // view of the same original GPU surface; no geometry is rebased.
            contained_region = is_image && parameters.surface_width > 0
                && parameters.tiles.empty() && entry.region_x <= parameters.region_x
                && entry.region_y <= parameters.region_y
                && parameters.region_x - entry.region_x <= entry.width
                && parameters.region_y - entry.region_y <= entry.height
                && width <= entry.width - (parameters.region_x - entry.region_x)
                && height <= entry.height - (parameters.region_y - entry.region_y);
#endif
            if ((!exact_region && !contained_region)
                || entry.has_background != has_background || entry.is_shape != parameters.is_shape
                || entry.is_path != parameters.is_path
                || entry.is_shadow != parameters.is_shadow
                || entry.surface_width != parameters.surface_width || entry.surface_height != parameters.surface_height
                || entry.tiles.size() != parameters.tiles.size()
                || !std::equal(entry.tiles.begin(), entry.tiles.end(), parameters.tiles.begin(), same_image)
                || (entry.is_shape ? !same_shape(entry.shape, parameters.shape)
                    : entry.is_path ? !same_path(entry.path, parameters.path)
                    : entry.is_shadow ? !same_shadow(entry.shadow, parameters.shadow)
                                    : !same_image(entry.image, parameters.image))
                || !extra.equal(entry.extra)) continue;
            if (exact_region) {
                if ((has_background && !backdrop.equal(entry.background, opaque))
                    || !source.equal(*entry.source)) continue;
                entry.output.copy_to(output, backdrop.bytes, copy_pitch, backdrop.height);
            } else {
                size_t x = parameters.region_x - entry.region_x, y = parameters.region_y - entry.region_y;
                VoxRasterSnapshot::Rect region {x, y, x + size_t(width), y + size_t(height)};
                if ((has_background && !entry.background.equal_region(pixels,
                        entry.width, entry.height, pitch, region))
                    || !source.equal(*entry.source)) continue;
                if (!entry.output.copy_region_to(output, entry.width, entry.height, copy_pitch, region)) continue;
#ifdef VOX_IMAGE_REGION_KEY_DIAGNOSTICS
                std::fprintf(stderr, "VOX_IMAGE_SUBVIEW_HIT width=%d height=%d from=%dx%d\n",
                    width, height, entry.width, entry.height);
#endif
            }
            entries.splice(entries.begin(), entries, it);
            request.hit = true;
            return request;
        }
        static bool admission_enabled = !std::getenv("VOX_DISABLE_RASTER_CACHE_ADMISSION");
        if (repeat_large_draws && admission_enabled && !is_image && cost >= 64 * 1024) {
            auto candidate = parameters;
            candidate.width = width;
            candidate.height = height;
            candidate.has_background = has_background;
            if (!admit_large_draw(candidate, source, backdrop, extra)) return request;
        }
        auto entry = std::make_unique<Entry>(parameters);
        entry->shape.clip_outs = nullptr;
        entry->image.pixels = nullptr;
        entry->path.segments = nullptr;
        entry->path.stops = nullptr;
        entry->width = width;
        entry->height = height;
        entry->has_background = has_background;
        entry->source = intern_source(source);
        entry->extra = extra.copy();
        if (has_background) entry->background = VoxRasterSnapshot(backdrop.pixels, backdrop.bytes, backdrop.pitch, backdrop.height);
        request.pending = std::move(entry);
        return request;
    }
public:
    void finish(Request&& request, uint8_t const* pixels, int pitch)
    {
        if (!request.pending) return;
        auto& entry = *request.pending;
        entry.output = VoxRasterSnapshot(pixels, size_t(entry.width) * 4, size_t(pitch), size_t(entry.height));
        if (entry.source->size() > byte_limit
            || entry.bytes() > byte_limit - entry.source->size()) return;
        // A source may have lost its final retained entry while this request
        // was rendering. Charge it once again if necessary, including when
        // multiple pending requests finish after a clear or eviction.
        auto cost = [&] { return entry.bytes() + (source_entries.count(entry.source.get()) ? 0 : entry.source->size()); };
        while (!entries.empty() && (retained_bytes + cost() > byte_limit || entries.size() >= entry_limit))
            evict_back();
        retained_bytes += entry.bytes();
        if (++source_entries[entry.source.get()] == 1) retained_bytes += entry.source->size();
        entries.push_front(std::move(request.pending));
    }
    void clear()
    {
        entries.clear();
        source_entries.clear();
        sources.clear();
        retained_bytes = 0;
        recent_draw_count = recent_draw_next = 0;
    }
};

#endif
