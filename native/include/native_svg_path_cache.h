#pragma once

#include "native_graphite_bridge.h"
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <deque>
#include <vector>

// Exact raster memoization for small solid fills and strokes. The caller owns eligibility
// policy; this service retains no document, path pointer or graphics context.
class VoxSmallSvgPathCache {
    struct Entry { std::vector<uint8_t> key, pixels; };
    std::deque<Entry> entries;
    size_t retained_bytes = 0;
    uint64_t generation = 0;
    static constexpr size_t byte_limit = 8u * 1024 * 1024;
public:
    bool enabled = false;
    uint64_t hits = 0;

    void clear() { ++generation; entries.clear(); retained_bytes = 0; }
    size_t size() const { return entries.size(); }
    size_t bytes() const { return retained_bytes; }

    template<typename Draw> int draw(Draw backend, uint8_t* pixels, int width,
        int height, int pitch, int has_background, VoxGraphitePath const* path)
    {
        if (!backend) return 0;
        if (!enabled || !pixels || !path || width <= 0 || height <= 0
            || width > 128 || height > 128 || pitch < width * 4
            || !path->segments || path->segment_count <= 0 || path->segment_count > 256
            || path->gradient || path->has_clip || path->has_ancestor_clip)
            return backend(pixels, width, height, pitch, has_background, path);

        std::vector<uint8_t> key;
        auto append = [&](void const* data, size_t count) {
            auto* begin = static_cast<uint8_t const*>(data);
            key.insert(key.end(), begin, begin + count);
        };
        // Encode semantic fields individually, excluding struct padding and
        // source addresses. Device scale and subpixel phase are in the matrix.
        append(&width, sizeof(width)); append(&height, sizeof(height));
        int background = has_background != 0;
        append(&background, sizeof(background));
        append(path->matrix, sizeof(path->matrix));
        append(&path->segment_count, sizeof(path->segment_count));
        append(&path->even_odd, sizeof(path->even_odd));
        append(&path->stroke, sizeof(path->stroke));
        append(&path->line_cap, sizeof(path->line_cap));
        append(&path->line_join, sizeof(path->line_join));
        append(&path->non_scaling_stroke, sizeof(path->non_scaling_stroke));
        append(&path->stroke_width, sizeof(path->stroke_width));
        append(&path->miter_limit, sizeof(path->miter_limit));
        append(&path->red, 1); append(&path->green, 1);
        append(&path->blue, 1); append(&path->alpha, 1);
        append(&path->has_float_color, sizeof(path->has_float_color));
        if (path->has_float_color) append(path->float_color, sizeof(path->float_color));
        append(&path->has_float_alpha, sizeof(path->has_float_alpha));
        if (path->has_float_alpha) append(&path->opacity, sizeof(path->opacity));
        append(path->segments, size_t(path->segment_count) * 12 * sizeof(float));
        if (background)
            for (int y = 0; y < height; ++y) append(pixels + size_t(y) * pitch, size_t(width) * 4);

        for (auto entry = entries.begin(); entry != entries.end(); ++entry) {
            if (entry->key != key) continue;
            for (int y = 0; y < height; ++y)
                std::memcpy(pixels + size_t(y) * pitch,
                    entry->pixels.data() + size_t(y) * width * 4, size_t(width) * 4);
            std::rotate(entries.begin(), entry, entry + 1);
            ++hits;
            return 1;
        }
        auto before_draw = generation;
        int result = backend(pixels, width, height, pitch, has_background, path);
        // The callback may purge graphics memory or replace its registered
        // renderer. Its output belongs to this call, but cannot repopulate
        // the invalidated cache after that operation returns.
        if (!result || generation != before_draw) return result;
        Entry entry {std::move(key), std::vector<uint8_t>(size_t(width) * height * 4)};
        for (int y = 0; y < height; ++y)
            std::memcpy(entry.pixels.data() + size_t(y) * width * 4,
                pixels + size_t(y) * pitch, size_t(width) * 4);
        size_t cost = entry.key.capacity() + entry.pixels.capacity();
        while (!entries.empty() && (entries.size() >= 64 || retained_bytes + cost > byte_limit)) {
            retained_bytes -= entries.back().key.capacity() + entries.back().pixels.capacity();
            entries.pop_back();
        }
        retained_bytes += cost;
        entries.push_front(std::move(entry));
        return result;
    }
};
