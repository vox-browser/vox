#ifndef VOX_NATIVE_GRAPHITE_IMAGE_UPLOAD_CACHE_H
#define VOX_NATIVE_GRAPHITE_IMAGE_UPLOAD_CACHE_H

#include "native_graphite_bridge.h"
#include <algorithm>
#include <cstring>
#include <list>
#include <memory>
#include <vector>

// A texture upload depends on decoded pixels, their interpretation and the
// selected upload/mipmap sizes. Destination geometry and the backdrop belong
// to the later draw. Texture owns the backend resource (sk_sp in production).
template<typename Texture> class VoxGraphiteImageUploadCache {
    struct Entry {
        VoxGraphiteImage image {};
        int upload_width, upload_height;
        bool mipmapped;
        size_t cost;
        std::vector<uint8_t> source;
        Texture texture;
    };
    std::list<std::unique_ptr<Entry>> entries;
    size_t bytes = 0;
    size_t byte_limit, entry_limit;
public:
    explicit VoxGraphiteImageUploadCache(size_t limit = 32 * 1024 * 1024, size_t count = 128)
        : byte_limit(limit), entry_limit(count) { }
    struct Request {
        Texture texture;
        std::unique_ptr<Entry> pending;
    };
    Request prepare(VoxGraphiteImage const& image, int upload_width, int upload_height, bool mipmapped)
    {
        size_t limit = std::min(byte_limit, size_t(8 * 1024 * 1024));
        if (!entry_limit || !image.pixels || image.width <= 0 || image.height <= 0
            || upload_width <= 0 || upload_height <= 0 || image.pitch <= 0) return {};
        size_t row_bytes = size_t(image.width) * 4, rows = image.height, pitch = image.pitch;
        if (image.flags & 4) {
            size_t w = image.width, h = image.height;
            size_t uv_w = image.flags & 16 ? w : (w + 1) / 2;
            size_t uv_h = image.flags & 16 ? h : (h + 1) / 2;
            if (w > limit / h || uv_w > limit / uv_h) return {};
            row_bytes = w * h + 2 * uv_w * uv_h; rows = 1; pitch = row_bytes;
        }
        if (row_bytes > pitch || row_bytes > limit / rows
            || size_t(upload_width) > limit / size_t(upload_height) / 4) return {};
        size_t texture_bytes = size_t(upload_width) * upload_height * 4;
        if (mipmapped) texture_bytes += texture_bytes / 3 + 64;
        size_t cost = row_bytes * rows + texture_bytes;
        if (cost > limit) return {};
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            auto const& entry = **it;
            auto const& prior = entry.image;
            if (entry.upload_width != upload_width || entry.upload_height != upload_height
                || entry.mipmapped != mipmapped || prior.width != image.width || prior.height != image.height
                || prior.flags != image.flags || prior.has_color_profile != image.has_color_profile
                || (image.has_color_profile && std::memcmp(prior.color_profile, image.color_profile, sizeof(image.color_profile)))) continue;
            bool equal = true;
            for (size_t y = 0; equal && y < rows; ++y)
                equal = !std::memcmp(entry.source.data() + y * row_bytes, image.pixels + y * pitch, row_bytes);
            if (!equal) continue;
            auto texture = entry.texture;
            entries.splice(entries.begin(), entries, it);
            return {std::move(texture), nullptr};
        }
        auto entry = std::make_unique<Entry>();
        entry->image = image; entry->image.pixels = nullptr;
        entry->upload_width = upload_width; entry->upload_height = upload_height;
        entry->mipmapped = mipmapped; entry->cost = cost;
        entry->source.resize(row_bytes * rows);
        for (size_t y = 0; y < rows; ++y)
            std::memcpy(entry->source.data() + y * row_bytes, image.pixels + y * pitch, row_bytes);
        return {Texture {}, std::move(entry)};
    }
    void finish(Request&& request, Texture texture)
    {
        if (!texture || !request.pending) return;
        auto& entry = *request.pending;
        while (!entries.empty() && (bytes + entry.cost > byte_limit || entries.size() >= entry_limit)) {
            bytes -= entries.back()->cost; entries.pop_back();
        }
        entry.texture = std::move(texture); bytes += entry.cost;
        entries.push_front(std::move(request.pending));
    }
    void clear() { entries.clear(); bytes = 0; }
};

#endif
