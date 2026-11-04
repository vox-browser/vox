#ifndef VOX_NATIVE_CHROMIUM_IMAGE_DECODE_CACHE_H
#define VOX_NATIVE_CHROMIUM_IMAGE_DECODE_CACHE_H

#include "native_graphite_bridge.h"
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <iterator>
#include <list>
#include <string>
#include <utility>
#include <unordered_map>
#include <vector>

// Carry one decode choice through leaf and complete-picture replay without
// changing the plain image ABI. Raster coverage flags occupy the low bits.
constexpr int vox_image_decode_hint = 1 << 29;
constexpr int vox_image_decode_level_mask = 31 << 24;

inline int vox_image_decode_level(int flags)
{
    if (!(flags & vox_image_decode_hint)) return -1;
    int level = (flags & vox_image_decode_level_mask) >> 24;
    return level <= 30 ? level : -1;
}

inline int vox_image_with_decode_level(int flags, int level)
{
    flags &= ~(vox_image_decode_hint | vox_image_decode_level_mask);
    return level >= 0 && level <= 30
        ? flags | vox_image_decode_hint | (level << 24) : flags;
}

inline int vox_image_decode_axis(int size, int level)
{
    if (size <= 0 || level < 0 || level > 30) return 0;
    int64_t divisor = int64_t(1) << level;
    return std::max(1, int((int64_t(size) + divisor - 1) / divisor));
}

// TileManager gathers decode modes before rasterizing any image. A sync use
// wins over async uses of the same resource, regardless of their paint order.
class VoxChromiumImageDecodingHints {
    std::unordered_map<std::string, bool> asynchronous;
public:
    void clear() { asynchronous.clear(); }
    void add(std::string const& identity, bool async)
    {
        if (identity.empty() || identity.size() > 16384) return;
        auto [it, inserted] = asynchronous.emplace(identity, async);
        if (!inserted) it->second &= async;
    }

    bool requires_source_decode(std::string const& identity, VoxGraphiteImage const& image) const
    {
        auto mode = asynchronous.find(identity);
        if (mode == asynchronous.end() || image.width <= 0 || image.height <= 0) return false;
        for (float value : image.source) if (!std::isfinite(value)) return false;
        if (image.source[2] <= 0 || image.source[3] <= 0) return false;
        // DiscardableImageMap rounds the source out before asking the decode
        // cache for its task. A fractional trim can still cover the full image.
        double left = std::floor(image.source[0]), top = std::floor(image.source[1]);
        double right = std::ceil(image.source[0] + image.source[2]);
        double bottom = std::ceil(image.source[1] + image.source[3]);
        if (left == 0 && top == 0 && right == image.width && bottom == image.height) return false;
        // GpuImageDecodeCache disables clipped-image scaling for these sync
        // tasks. Async checkering asks for complete bounds instead, but is
        // vetoed below LayerTreeSettings' default 1 MiB source-area threshold.
        return !mode->second || (right - left) * (bottom - top) * 4 < 1024 * 1024;
    }
};

// Chromium retains a compatible larger decode for subsequent smaller draws.
// Resource identity matters: equal pixels from two URLs are separate decodes.
// Store the source too so mutations, recycled storage and changed profiles
// cannot inherit the preceding image's chosen size.
class VoxChromiumImageDecodeCache {
    struct Request {
        uint64_t scope;
        int requested, selected;
    };
    static constexpr size_t request_limit = 64;
    struct Entry {
        std::string identity;
        VoxGraphiteImage image {};
        std::vector<uint8_t> source;
        std::vector<Request> requests;
        int completed_level = 31;
        size_t cost = 0;
    };
    std::list<Entry> entries;
    size_t bytes = 0;
    size_t byte_limit, entry_limit;

    void erase(std::list<Entry>::iterator it)
    {
        bytes -= it->cost;
        entries.erase(it);
    }

    void forget(std::string const& identity)
    {
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            if (it->identity == identity) { erase(it); return; }
        }
    }

public:
    explicit VoxChromiumImageDecodeCache(size_t limit = 32 * 1024 * 1024,
        size_t count = 128) : byte_limit(limit), entry_limit(count) { }

    int select(std::string const& identity, VoxGraphiteImage const& image, int level,
        uint64_t scope = 0)
    {
        size_t limit = std::min(byte_limit, size_t(8 * 1024 * 1024));
        if (identity.empty() || identity.size() > 16384 || !entry_limit
            || !image.pixels || image.width <= 0 || image.height <= 0
            || image.pitch <= 0 || level < 0 || level > 30
            || (image.flags & (64 | 128))
            || size_t(image.width) > limit / size_t(image.height) / 4) {
            forget(identity);
            return -1;
        }
        size_t row_bytes = size_t(image.width) * 4;
        size_t rows = image.height, pitch = image.pitch;
        if (image.flags & 4) {
            size_t w = image.width, h = image.height;
            size_t uv_w = image.flags & 16 ? w : (w + 1) / 2;
            size_t uv_h = image.flags & (16 | VOX_GRAPHITE_IMAGE_YUV422) ? h : (h + 1) / 2;
            row_bytes = w * h + 2 * uv_w * uv_h;
            rows = 1; pitch = row_bytes;
        }
        size_t source_bytes = row_bytes * rows;
        size_t cost = source_bytes + identity.size() + sizeof(Entry)
            + request_limit * sizeof(Request);
        if (row_bytes > pitch || cost > limit) {
            forget(identity);
            return -1;
        }
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            if (it->identity != identity) continue;
            auto const& prior = it->image;
            bool same = prior.width == image.width && prior.height == image.height
                && (prior.flags & (1 | 4 | 8 | 16 | VOX_GRAPHITE_IMAGE_YUV422))
                    == (image.flags & (1 | 4 | 8 | 16 | VOX_GRAPHITE_IMAGE_YUV422))
                && prior.has_color_profile == image.has_color_profile
                && (!image.has_color_profile || !std::memcmp(prior.color_profile,
                    image.color_profile, sizeof(image.color_profile)));
            for (size_t y = 0; same && y < rows; ++y)
                same = !std::memcmp(it->source.data() + size_t(y) * row_bytes,
                    image.pixels + size_t(y) * pitch, row_bytes);
            if (!same) { erase(it); break; }
            int selected = std::min(level, it->completed_level);
            // A complete source is compatible with every filter. A scaled
            // planar decode retains the CPU filter used to prepare its planes.
            if ((image.flags & 4) && image.nearest && !prior.nearest) {
                bool original = it->completed_level == 0;
                for (auto const& request : it->requests)
                    original |= request.scope == scope && request.selected == 0;
                if (!original) { erase(it); break; }
            }
            for (auto const& request : it->requests) {
                // A retained picture keeps its in-use result even if another
                // picture subsequently decodes the resource at a larger size.
                if (request.scope == scope && request.requested == level) {
                    selected = request.selected;
                    entries.splice(entries.begin(), entries, it);
                    return selected;
                }
                if (request.scope == scope && request.selected <= level)
                    selected = std::min(selected, request.selected);
            }
            if (it->requests.size() == request_limit)
                it->requests.erase(it->requests.begin());
            it->requests.push_back({scope, level, selected});
            entries.splice(entries.begin(), entries, it);
            return selected;
        }
        while (!entries.empty() && (bytes + cost > byte_limit || entries.size() >= entry_limit))
            erase(std::prev(entries.end()));
        Entry entry;
        entry.identity = identity;
        entry.image = image;
        entry.image.pixels = nullptr;
        entry.requests.reserve(request_limit);
        entry.requests.push_back({scope, level, level});
        entry.cost = cost;
        entry.source.resize(source_bytes);
        for (size_t y = 0; y < rows; ++y)
            std::memcpy(entry.source.data() + size_t(y) * row_bytes,
                image.pixels + size_t(y) * pitch, row_bytes);
        bytes += cost;
        entries.push_front(std::move(entry));
        return level;
    }

    void complete_frame()
    {
        for (auto& entry : entries)
            for (auto const& request : entry.requests)
                entry.completed_level = std::min(entry.completed_level, request.selected);
    }

    void reset_requests()
    {
        for (auto& entry : entries) entry.requests.clear();
    }

    void clear() { entries.clear(); bytes = 0; }
};

#endif
