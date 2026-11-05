#ifndef VOX_NATIVE_GRAPHITE_IMAGE_UPLOAD_CACHE_H
#define VOX_NATIVE_GRAPHITE_IMAGE_UPLOAD_CACHE_H

#include "native_graphite_bridge.h"
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <list>
#include <memory>
#include <vector>

// A seeded 128-bit digest of decoded rows, independent of their padding. The
// seed is chosen per process, so page content cannot aim a collision at the
// upload of another image.
inline void vox_image_upload_digest(uint8_t const* pixels, size_t row_bytes, size_t rows,
    size_t pitch, uint64_t (&digest)[2])
{
    static uint64_t const seed = [] {
        uint64_t value;
        arc4random_buf(&value, sizeof value);
        return value;
    }();
    constexpr uint64_t p1 = 0x9E3779B185EBCA87ull, p2 = 0xC2B2AE3D27D4EB4Full,
        p3 = 0x165667B19E3779F9ull;
    auto rotate = [](uint64_t value, int bits) { return (value << bits) | (value >> (64 - bits)); };
    uint64_t lanes[8];
    for (int lane = 0; lane < 8; ++lane) lanes[lane] = seed + p1 * uint64_t(lane + 1);
    auto mix = [&](uint64_t const (&words)[8]) {
        for (int lane = 0; lane < 8; ++lane)
            lanes[lane] = rotate(lanes[lane] + words[lane] * p2, 31) * p1;
    };
    for (size_t y = 0; y < rows; ++y) {
        uint8_t const* row = pixels + y * pitch;
        size_t x = 0;
        uint64_t words[8];
        for (; x + sizeof words <= row_bytes; x += sizeof words) {
            std::memcpy(words, row + x, sizeof words);
            mix(words);
        }
        if (x < row_bytes) {
            // Every row has the same length, so zero padding is unambiguous.
            std::memset(words, 0, sizeof words);
            std::memcpy(words, row + x, row_bytes - x);
            mix(words);
        }
    }
    auto avalanche = [](uint64_t value) {
        value ^= value >> 33; value *= p2;
        value ^= value >> 29; value *= p3;
        return value ^ (value >> 32);
    };
    uint64_t first = row_bytes * p3 + rows, second = rows * p2 + row_bytes;
    for (int lane = 0; lane < 8; ++lane) {
        first = rotate(first ^ lanes[lane], 27) * p1 + p3;
        second += rotate(lanes[lane], 7 + lane * 7) * p2;
    }
    digest[0] = avalanche(first);
    digest[1] = avalanche(second ^ first);
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
        // Bytes verify a reused upload; a source too large to retain keeps
        // only their digest.
        std::vector<uint8_t> source;
        bool digested = false;
        uint64_t digest[2] {};
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
        // One entry may use half the budget. A large decoded image (vlang.io's
        // 1824x1468 DOOM screenshot, 13.4 MiB with its source copy) otherwise
        // repeats its CPU scale and upload for every tile of every repaint.
        size_t limit = byte_limit / 2;
        if (!entry_limit || !image.pixels || image.width <= 0 || image.height <= 0
            || upload_width <= 0 || upload_height <= 0 || image.pitch <= 0) return {};
        size_t row_bytes = size_t(image.width) * 4, rows = image.height, pitch = image.pitch;
        if (image.flags & 4) {
            size_t w = image.width, h = image.height;
            size_t uv_w = image.flags & 16 ? w : (w + 1) / 2;
            size_t uv_h = image.flags & (16 | VOX_GRAPHITE_IMAGE_YUV422) ? h : (h + 1) / 2;
            if (w > SIZE_MAX / 4 / h || uv_w > SIZE_MAX / 4 / uv_h) return {};
            row_bytes = w * h + 2 * uv_w * uv_h; rows = 1; pitch = row_bytes;
        }
        if (row_bytes > pitch || row_bytes > SIZE_MAX / rows
            || size_t(upload_width) > limit / size_t(upload_height) / 4) return {};
        size_t texture_bytes = size_t(upload_width) * upload_height * 4;
        if (mipmapped) texture_bytes += texture_bytes / 3 + 64;
        // A source too large to copy within the entry's share is verified by
        // its digest: vlang.io's 3993x2317 mascot (37 MB decoded) uploads at
        // 999x580, and would otherwise repeat a CPU scale for every draw.
        size_t source_bytes = row_bytes * rows;
        bool digested = source_bytes > limit || source_bytes + texture_bytes > limit;
        size_t cost = (digested ? sizeof(Entry::digest) : source_bytes) + texture_bytes;
        if (cost > limit) return {};
        uint64_t digest[2] {};
        bool have_digest = false;
        auto image_digest = [&] {
            if (!have_digest) vox_image_upload_digest(image.pixels, row_bytes, rows, pitch, digest);
            have_digest = true;
        };
        Texture mipmap_source {};
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            auto const& entry = **it;
            auto const& prior = entry.image;
            if (entry.upload_width != upload_width || entry.upload_height != upload_height
                || prior.width != image.width || prior.height != image.height
                || ((image.flags & 4) && (upload_width != image.width || upload_height != image.height)
                    && prior.nearest != image.nearest)
                || prior.flags != image.flags || prior.has_color_profile != image.has_color_profile
                || (image.has_color_profile && std::memcmp(prior.color_profile, image.color_profile, sizeof(image.color_profile)))) continue;
            if (entry.digested != digested) continue;
            bool equal = true;
            if (digested) {
                image_digest();
                equal = entry.digest[0] == digest[0] && entry.digest[1] == digest[1];
            }
            for (size_t y = 0; !digested && equal && y < rows; ++y)
                equal = !std::memcmp(entry.source.data() + y * row_bytes, image.pixels + y * pitch, row_bytes);
            if (!equal) continue;
            // Prefer an existing complete upload to upgrading another entry.
            // Planar YUV retains its own plane-upload path.
            if (mipmapped && !entry.mipmapped) {
                if (!(image.flags & 4)) mipmap_source = entry.texture;
                continue;
            }
            auto texture = entry.texture;
            entries.splice(entries.begin(), entries, it);
            return {std::move(texture), nullptr};
        }
        auto entry = std::make_unique<Entry>();
        entry->image = image; entry->image.pixels = nullptr;
        entry->upload_width = upload_width; entry->upload_height = upload_height;
        entry->mipmapped = mipmapped; entry->cost = cost;
        entry->digested = digested;
        if (digested) {
            image_digest();
            std::copy_n(digest, 2, entry->digest);
        } else {
            entry->source.resize(source_bytes);
            for (size_t y = 0; y < rows; ++y)
                std::memcpy(entry->source.data() + y * row_bytes, image.pixels + y * pitch, row_bytes);
        }
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
