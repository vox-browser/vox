#pragma once

#include "native_graphite_bridge.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <list>
#include <vector>

// Owned exact picture inputs and outputs only. The renderer holds its mutex;
// no Skia objects, GPU context, source addresses or shared-pixel leases survive.
class VoxPictureRasterCache {
    struct Entry {
        uint64_t hash;
        std::vector<uint8_t> key, pixels;
        size_t cost() const { return key.size() + pixels.size(); }
    };
    std::list<Entry> entries_;
    size_t bytes_ = 0, limit_, count_, single_;
    template<typename T> static void append(std::vector<uint8_t>& key, T const& value) {
        auto* bytes = reinterpret_cast<uint8_t const*>(&value);
        key.insert(key.end(), bytes, bytes + sizeof(value));
    }
public:
    struct Request {
        bool hit = false;
        uint64_t hash = 0;
        std::vector<uint8_t> key;
        size_t pixel_bytes = 0;
    };
    explicit VoxPictureRasterCache(size_t limit = 8 * 1024 * 1024,
        size_t count = 128, size_t single = 1024 * 1024)
        : limit_(limit), count_(count), single_(std::min(limit, single)) { }
    Request prepare(VoxGraphitePictureRegion const* regions, int count,
        int width, int height, bool background) {
        if (!regions || count <= 0 || count > 64 || width <= 0 || height <= 0
            || !count_ || !single_) return {};
        // Establish the entire retained cost before copying any payload.
        size_t key_bytes = sizeof(count) + sizeof(width) + sizeof(height) + sizeof(background);
        size_t pixel_bytes = 0;
        for (int i = 0; i < count; ++i) {
            auto const& r = regions[i];
            auto const& out = r.output;
            if (!r.bytes || !r.size || !out.pixels || out.width <= 0 || out.height <= 0
                || out.width > width || out.height > height || out.x < 0 || out.y < 0
                || out.x > width - out.width || out.y > height - out.height
                || size_t(out.pitch) < size_t(out.width) * 4 || out.pitch < 0) return {};
            for (float value : r.matrix) if (!std::isfinite(value)) return {};
            size_t header = sizeof(out.x) * 4 + sizeof(r.size) + sizeof(r.matrix);
            if (r.size > single_ || key_bytes > single_ - r.size) return {};
            key_bytes += r.size;
            if (key_bytes > single_ || header > single_ - key_bytes) return {};
            key_bytes += header;
            size_t row = size_t(out.width) * 4;
            if (row > single_ / size_t(out.height)) return {};
            size_t pixels = row * size_t(out.height);
            if (pixels > single_ - pixel_bytes) return {};
            pixel_bytes += pixels;
        }
        if (pixel_bytes > single_ || key_bytes > single_ - pixel_bytes) return {};
        if (background && pixel_bytes > single_ - pixel_bytes - key_bytes) return {};
        Request request;
        request.pixel_bytes = pixel_bytes;
        request.key.reserve(key_bytes + (background ? pixel_bytes : 0));
        append(request.key, count); append(request.key, width); append(request.key, height);
        append(request.key, background);
        for (int i = 0; i < count; ++i) {
            auto const& r = regions[i]; auto const& out = r.output;
            append(request.key, out.x); append(request.key, out.y);
            append(request.key, out.width); append(request.key, out.height);
            append(request.key, r.size); append(request.key, r.matrix);
            auto* bytes = static_cast<uint8_t const*>(r.bytes);
            request.key.insert(request.key.end(), bytes, bytes + r.size);
            if (background) for (int y = 0; y < out.height; ++y) {
                auto* row = out.pixels + size_t(y) * out.pitch;
                request.key.insert(request.key.end(), row, row + size_t(out.width) * 4);
            }
        }
        request.hash = 14695981039346656037ull;
        for (uint8_t value : request.key)
            request.hash = (request.hash ^ value) * 1099511628211ull;
        for (auto it = entries_.begin(); it != entries_.end(); ++it) {
            if (it->hash != request.hash || it->key != request.key) continue;
            size_t offset = 0;
            for (int i = 0; i < count; ++i) {
                auto const& out = regions[i].output;
                size_t row = size_t(out.width) * 4;
                for (int y = 0; y < out.height; ++y) {
                    std::memcpy(out.pixels + size_t(y) * out.pitch, it->pixels.data() + offset, row);
                    offset += row;
                }
            }
            entries_.splice(entries_.begin(), entries_, it);
            request.hit = true;
            request.key.clear();
            return request;
        }
        return request;
    }
    void finish(Request&& request, VoxGraphitePictureRegion const* regions, int count) {
        if (request.hit || request.key.empty()) return;
        Entry entry {request.hash, std::move(request.key), {}};
        entry.pixels.reserve(request.pixel_bytes);
        for (int i = 0; i < count; ++i) {
            auto const& out = regions[i].output;
            for (int y = 0; y < out.height; ++y) {
                auto* row = out.pixels + size_t(y) * out.pitch;
                entry.pixels.insert(entry.pixels.end(), row, row + size_t(out.width) * 4);
            }
        }
        while (!entries_.empty() && (entries_.size() >= count_ || bytes_ > limit_ - entry.cost())) {
            bytes_ -= entries_.back().cost();
            entries_.pop_back();
        }
        bytes_ += entry.cost(); entries_.push_front(std::move(entry));
    }
    void clear() { entries_.clear(); bytes_ = 0; }
    size_t bytes() const { return bytes_; }
    size_t size() const { return entries_.size(); }
};
