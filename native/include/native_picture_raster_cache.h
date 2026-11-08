#pragma once
#include "native_raster_snapshot.h"
#include <cstdint>
#include <cstring>
#include <list>
#include <vector>

// Cache only a complete transparent raster, before it meets a destination.
// The caller supplies every raster parameter and the serialized picture. Keys
// own their bytes; a hash match alone never establishes identity.
class VoxPictureRasterCache {
    struct Entry {
        uint64_t hash;
        std::vector<uint8_t> key;
        size_t row_bytes, height;
        VoxRasterSnapshot pixels;
        size_t cost() const { return sizeof(Entry) + key.size() + pixels.size(); }
    };
    std::list<Entry> entries_;
    size_t bytes_ = 0;
    size_t limit_, count_;
    static uint64_t hash(std::vector<uint8_t> const& key)
    {
        uint64_t value = 14695981039346656037ull;
        for (auto byte : key) value = (value ^ byte) * 1099511628211ull;
        return value;
    }
    bool eligible(std::vector<uint8_t> const& key, size_t row_bytes,
        size_t pitch, size_t height) const
    {
        return !key.empty() && key.size() <= 1024 * 1024 && row_bytes
            && row_bytes % 4 == 0 && pitch >= row_bytes && height && pitch <= SIZE_MAX / height
            && height <= (8 * 1024 * 1024) / row_bytes
            && key.size() < limit_ && count_;
    }
public:
    explicit VoxPictureRasterCache(size_t limit = 32 * 1024 * 1024, size_t count = 64)
        : limit_(limit), count_(count) { }
    void clear() { entries_.clear(); bytes_ = 0; }
    size_t bytes() const { return bytes_; }
    size_t entries() const { return entries_.size(); }
    bool restore(std::vector<uint8_t> const& key, uint8_t* pixels,
        size_t row_bytes, size_t pitch, size_t height)
    {
        if (!pixels || !eligible(key, row_bytes, pitch, height)) return false;
        uint64_t digest = hash(key);
        for (auto it = entries_.begin(); it != entries_.end(); ++it) {
            if (it->hash != digest || it->row_bytes != row_bytes || it->height != height
                || it->key != key) continue;
            if (!it->pixels.copy_to(pixels, row_bytes, pitch, height)) return false;
            entries_.splice(entries_.begin(), entries_, it);
            return true;
        }
        return false;
    }
    void store(std::vector<uint8_t> const& key, uint8_t const* pixels,
        size_t row_bytes, size_t pitch, size_t height)
    {
        if (!pixels || !eligible(key, row_bytes, pitch, height)) return;
        Entry entry {hash(key), key, row_bytes, height,
            VoxRasterSnapshot(pixels, row_bytes, pitch, height)};
        size_t cost = entry.cost();
        if (cost > limit_) return;
        for (auto it = entries_.begin(); it != entries_.end();) {
            if (it->hash == entry.hash && it->key == key
                && it->row_bytes == row_bytes && it->height == height) {
                bytes_ -= it->cost(); it = entries_.erase(it);
            } else ++it;
        }
        while (!entries_.empty() && (bytes_ > limit_ - cost || entries_.size() >= count_)) {
            bytes_ -= entries_.back().cost(); entries_.pop_back();
        }
        bytes_ += cost;
        entries_.push_front(std::move(entry));
    }
};
