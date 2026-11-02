#ifndef VOX_NATIVE_GRAPHITE_IMAGE_UPLOAD_CACHE_H
#define VOX_NATIVE_GRAPHITE_IMAGE_UPLOAD_CACHE_H

#include "native_graphite_bridge.h"
#include "native_raster_snapshot.h"
#include <algorithm>
#include <cstring>
#include <list>
#include <memory>
#include <vector>

inline bool vox_compressed_image_uploads_enabled()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_ENABLE_COMPRESSED_IMAGE_UPLOADS");
        return value && !std::strcmp(value, "1")
            && !std::getenv("VOX_DISABLE_COMPRESSED_IMAGE_UPLOADS");
    }();
    return enabled;
}

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
        VoxRasterSnapshot compact_source;
        bool compact = false;
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
        // An earlier non-mipmapped upload can gain GPU-generated levels.
        // New uploads still use the raster image's CPU mipmaps.
        bool needs_mipmaps = false;
    };
    Request prepare(VoxGraphiteImage const& image, int upload_width, int upload_height, bool mipmapped)
    {
        size_t limit = std::min(byte_limit, size_t(8 * 1024 * 1024));
        if (!entry_limit || !image.pixels || image.width <= 0 || image.height <= 0
            || upload_width <= 0 || upload_height <= 0 || image.pitch <= 0) return {};
        size_t row_bytes = size_t(image.width) * 4, rows = image.height, pitch = image.pitch;
        bool allow_compact = !(image.flags & 4) && vox_compressed_image_uploads_enabled();
        size_t source_limit = allow_compact ? 64 * 1024 * 1024 : limit;
        if (image.flags & 4) {
            size_t w = image.width, h = image.height;
            size_t uv_w = image.flags & 16 ? w : (w + 1) / 2;
            size_t uv_h = image.flags & 16 ? h : (h + 1) / 2;
            if (w > limit / h || uv_w > limit / uv_h) return {};
            row_bytes = w * h + 2 * uv_w * uv_h; rows = 1; pitch = row_bytes;
        }
        if (row_bytes > pitch || row_bytes > source_limit / rows
            || size_t(upload_width) > limit / size_t(upload_height) / 4) return {};
        size_t texture_bytes = size_t(upload_width) * upload_height * 4;
        if (mipmapped) texture_bytes += texture_bytes / 3 + 64;
        size_t cost = row_bytes * rows + texture_bytes;
        if (texture_bytes > limit || (cost > limit && !allow_compact)) return {};
        Texture mipmap_source {};
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            auto const& entry = **it;
            auto const& prior = entry.image;
            if (entry.upload_width != upload_width || entry.upload_height != upload_height
                || prior.width != image.width || prior.height != image.height
                || prior.flags != image.flags || prior.has_color_profile != image.has_color_profile
                || (image.has_color_profile && std::memcmp(prior.color_profile, image.color_profile, sizeof(image.color_profile)))) continue;
            bool equal = !entry.compact || entry.compact_source.equal(image.pixels, row_bytes, pitch, rows);
            for (size_t y = 0; equal && !entry.compact && y < rows; ++y)
                equal = !std::memcmp(entry.source.data() + y * row_bytes, image.pixels + y * pitch, row_bytes);
            if (!equal) continue;
            // Prefer an existing complete upload to upgrading another entry.
            // Planar YUV retains its own plane-upload path.
            if (mipmapped && !entry.mipmapped) {
                if (!(image.flags & 4) && !entry.compact && cost <= limit)
                    mipmap_source = entry.texture;
                continue;
            }
            auto texture = entry.texture;
            entries.splice(entries.begin(), entries, it);
            return {std::move(texture), nullptr};
        }
        auto entry = std::make_unique<Entry>();
        entry->image = image; entry->image.pixels = nullptr;
        entry->upload_width = upload_width; entry->upload_height = upload_height;
        entry->mipmapped = mipmapped;
        entry->compact = cost > limit;
        if (entry->compact) {
            // Only the owned representation changes. Decode size, CPU mip
            // construction, color conversion and GPU sampling stay unchanged.
            entry->compact_source = VoxRasterSnapshot(image.pixels, row_bytes, pitch, rows);
            cost = entry->compact_source.size() + texture_bytes;
            if (cost > limit) return {};
        } else {
            entry->source.resize(row_bytes * rows);
            for (size_t y = 0; y < rows; ++y)
                std::memcpy(entry->source.data() + y * row_bytes, image.pixels + y * pitch, row_bytes);
        }
        entry->cost = cost;
        bool needs_mipmaps = bool(mipmap_source);
        return {std::move(mipmap_source), std::move(entry), needs_mipmaps};
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
