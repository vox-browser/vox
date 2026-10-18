#ifndef VOX_NATIVE_GRAPHITE_RASTER_CACHE_H
#define VOX_NATIVE_GRAPHITE_RASTER_CACHE_H

#include "native_graphite_bridge.h"
#include <algorithm>
#include <cstring>
#include <list>
#include <memory>
#include <vector>

// Memoize complete GPU image and shape draws, including their input backdrop.
// Sources can be canvas/video buffers, animated frames or recycled allocations: addresses
// are never an identity or a promise of immutability. Every hit compares the
// actual source bytes and every parameter before copying owned output pixels.
// The caller serializes access with the renderer's existing mutex.
class VoxGraphiteRasterCache {
    struct Entry {
        VoxGraphiteImage image {};
        VoxGraphiteShape shape {};
        bool is_shape = false;
        int width = 0, height = 0;
        bool has_background = false;
        std::vector<uint8_t> source, background, output;
        size_t bytes() const { return source.size() + background.size() + output.size(); }
    };
    struct Rows {
        uint8_t const* pixels;
        size_t bytes, pitch, height;
        bool equal(std::vector<uint8_t> const& copy) const
        {
            if (copy.size() != bytes * height) return false;
            if (!bytes) return true;
            for (size_t y = 0; y < height; ++y)
                if (std::memcmp(pixels + y * pitch, copy.data() + y * bytes, bytes)) return false;
            return true;
        }
        std::vector<uint8_t> copy() const
        {
            std::vector<uint8_t> result(bytes * height);
            if (!bytes) return result;
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
            && (!a.has_color_profile || !std::memcmp(a.color_profile, b.color_profile,
                sizeof(a.color_profile)));
    }
    static bool same_shape(VoxGraphiteShape const& a, VoxGraphiteShape const& b)
    {
        return !std::memcmp(a.matrix, b.matrix, sizeof(a.matrix))
            && !std::memcmp(a.rect, b.rect, sizeof(a.rect))
            && !std::memcmp(&a.thickness, &b.thickness, sizeof(a.thickness))
            && a.red == b.red && a.green == b.green && a.blue == b.blue && a.alpha == b.alpha
            && a.fill == b.fill && a.anti_alias == b.anti_alias && a.force_msaa == b.force_msaa
            && a.clip_out_count == b.clip_out_count && a.has_underlay == b.has_underlay
            && (!a.has_underlay || (!std::memcmp(a.underlay_rect, b.underlay_rect, sizeof(a.underlay_rect))
                && !std::memcmp(a.underlay_rgba, b.underlay_rgba, sizeof(a.underlay_rgba))));
    }
    std::list<std::unique_ptr<Entry>> entries;
    size_t retained_bytes = 0;
    size_t byte_limit, entry_limit;
    static constexpr size_t max_entry_bytes = 8 * 1024 * 1024;

public:
    explicit VoxGraphiteRasterCache(size_t bytes = 32 * 1024 * 1024, size_t count = 512)
        : byte_limit(bytes), entry_limit(count) { }
    struct Request {
        bool hit = false;
        std::unique_ptr<Entry> pending;
    };
    Request prepare(VoxGraphiteImage const& image, int width, int height,
        int pitch, bool has_background, uint8_t* pixels)
    {
        Request request;
        if (!pixels || !image.pixels || width <= 0 || height <= 0 || pitch <= 0
            || image.width <= 0 || image.height <= 0 || image.pitch <= 0
            || size_t(pitch) < size_t(width) * 4 || !entry_limit) return request;
        // Bound dimensions before multiplication, allocations and source reads.
        // This also bypasses large one-off photos/video frames.
        size_t limit = std::min(byte_limit, max_entry_bytes);
        Rows source {image.pixels, size_t(image.width) * 4, size_t(image.pitch), size_t(image.height)};
        if (image.flags & 4) {
            size_t w = image.width, h = image.height;
            size_t uv_w = image.flags & 16 ? w : (w + 1) / 2;
            size_t uv_h = image.flags & 16 ? h : (h + 1) / 2;
            if (w > limit / h || uv_w > limit / uv_h) return request;
            source = {image.pixels, w * h + 2 * uv_w * uv_h, 0, 1};
        } else if (source.bytes > source.pitch) return request;
        Entry parameters;
        parameters.image = image;
        return prepare_entry(parameters, source, width, height, pitch, has_background, pixels);
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
private:
    Request prepare_entry(Entry const& parameters, Rows source, int width, int height,
        int pitch, bool has_background, uint8_t* pixels)
    {
        Request request;
        if (!pixels || width <= 0 || height <= 0 || pitch <= 0
            || size_t(pitch) < size_t(width) * 4 || !entry_limit) return request;
        // Large shapes often cover changing page content. Copying those input
        // backdrops would consume the small-control cache without useful hits.
        size_t limit = std::min(byte_limit, parameters.is_shape ? size_t(128 * 1024) : max_entry_bytes);
        Rows backdrop {pixels, size_t(width) * 4, size_t(pitch), size_t(height)};
        if (source.bytes > limit / source.height || backdrop.bytes > limit / backdrop.height)
            return request;
        size_t cost = source.bytes * source.height
            + backdrop.bytes * backdrop.height * (has_background ? 2 : 1);
        if (cost > limit) return request;
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            auto const& entry = **it;
            if (entry.width != width || entry.height != height
                || entry.has_background != has_background || entry.is_shape != parameters.is_shape
                || (entry.is_shape ? !same_shape(entry.shape, parameters.shape)
                                   : !same_image(entry.image, parameters.image))
                || !source.equal(entry.source)
                || (has_background && !backdrop.equal(entry.background))) continue;
            for (size_t y = 0; y < backdrop.height; ++y)
                std::memcpy(pixels + y * backdrop.pitch,
                    entry.output.data() + y * backdrop.bytes, backdrop.bytes);
            entries.splice(entries.begin(), entries, it);
            request.hit = true;
            return request;
        }
        while (!entries.empty() && (retained_bytes + cost > byte_limit
                || entries.size() >= entry_limit)) {
            retained_bytes -= entries.back()->bytes();
            entries.pop_back();
        }
        auto entry = std::make_unique<Entry>(parameters);
        entry->shape.clip_outs = nullptr;
        entry->image.pixels = nullptr;
        entry->width = width;
        entry->height = height;
        entry->has_background = has_background;
        entry->source = source.copy();
        if (has_background) entry->background = backdrop.copy();
        request.pending = std::move(entry);
        return request;
    }
public:
    void finish(Request&& request, uint8_t const* pixels, int pitch)
    {
        if (!request.pending) return;
        auto& entry = *request.pending;
        entry.output = Rows {pixels, size_t(entry.width) * 4, size_t(pitch), size_t(entry.height)}.copy();
        retained_bytes += entry.bytes();
        entries.push_front(std::move(request.pending));
    }
    void clear()
    {
        entries.clear();
        retained_bytes = 0;
    }
};

#endif
