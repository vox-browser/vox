#ifndef VOX_NATIVE_RASTER_SNAPSHOT_H
#define VOX_NATIVE_RASTER_SNAPSHOT_H

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <utility>
#include <vector>

// Owned, lossless rows for CPU raster-cache inputs and results. Flat RGBA
// regions use word runs; noisy images stay raw. A hit compares/expands directly
// into the caller's rows, without allocating a temporary decoded bitmap.
class VoxRasterSnapshot {
    std::vector<uint8_t> raw_;
    std::vector<uint32_t> packed_;
    size_t logical_bytes_ = 0;

    static uint32_t word(uint8_t const* bytes)
    {
        uint32_t result;
        std::memcpy(&result, bytes, sizeof(result));
        return result;
    }
    template<typename Emit>
    static void encode(uint8_t const* bytes, size_t words, Emit emit)
    {
        size_t at = 0;
        while (at < words) {
            size_t end = at + 1;
            uint32_t value = word(bytes + at * 4);
            while (end < words && word(bytes + end * 4) == value) ++end;
            if (end - at >= 3) {
                emit(uint32_t((end - at) * 2 + 1));
                emit(value);
                at = end;
                continue;
            }
            size_t start = at;
            at = end;
            while (at < words) {
                if (at + 2 < words && word(bytes + at * 4) == word(bytes + (at + 1) * 4)
                    && word(bytes + at * 4) == word(bytes + (at + 2) * 4)) break;
                ++at;
            }
            emit(uint32_t((at - start) * 2));
            for (size_t i = start; i < at; ++i) emit(word(bytes + i * 4));
        }
    }
    template<bool Compare>
    bool replay(uint8_t const* input, uint8_t* output, size_t row_bytes,
        size_t pitch, size_t height) const
    {
        if (pitch < row_bytes || (height && row_bytes > SIZE_MAX / height)
            || row_bytes * height != logical_bytes_ || (!packed_.empty() && row_bytes % 4)) return false;
        if (!logical_bytes_) return true;
        if (packed_.empty()) {
            for (size_t y = 0; y < height; ++y) {
                if constexpr (Compare) {
                    if (std::memcmp(input + y * pitch, raw_.data() + y * row_bytes, row_bytes)) return false;
                } else std::memcpy(output + y * pitch, raw_.data() + y * row_bytes, row_bytes);
            }
            return true;
        }
        size_t y = 0, x = 0, at = 0;
        while (at < packed_.size()) {
            uint32_t tag = packed_[at++];
            size_t remaining = tag >> 1;
            bool repeated = tag & 1;
            uint32_t value = repeated ? packed_[at++] : 0;
            while (remaining) {
                size_t count = std::min(remaining, (row_bytes - x) / 4);
                if (repeated) {
                    for (size_t i = 0; i < count; ++i) {
                        if constexpr (Compare) {
                            if (word(input + y * pitch + x + i * 4) != value) return false;
                        } else std::memcpy(output + y * pitch + x + i * 4, &value, 4);
                    }
                } else {
                    if constexpr (Compare) {
                        if (std::memcmp(input + y * pitch + x, packed_.data() + at, count * 4)) return false;
                    } else std::memcpy(output + y * pitch + x, packed_.data() + at, count * 4);
                    at += count;
                }
                x += count * 4;
                if (x == row_bytes) { x = 0; ++y; }
                remaining -= count;
            }
        }
        return true;
    }
public:
    VoxRasterSnapshot() = default;
    explicit VoxRasterSnapshot(std::vector<uint8_t>&& bytes)
        : raw_(std::move(bytes)), logical_bytes_(raw_.size())
    {
        // Small control rasters avoid codec overhead. Counts fit a 31-bit
        // word length, including when this helper is used outside the cache.
        if (raw_.size() < 4096 || raw_.size() % 4 || raw_.size() / 4 > 0x7fffffff) return;
        size_t count = 0;
        encode(raw_.data(), raw_.size() / 4, [&](uint32_t) { ++count; });
        if (count * 4 >= raw_.size() - raw_.size() / 8) return;
        packed_.reserve(count);
        encode(raw_.data(), raw_.size() / 4, [&](uint32_t value) { packed_.push_back(value); });
        std::vector<uint8_t>().swap(raw_);
    }
    size_t size() const { return raw_.size() + packed_.size() * 4; }
    bool equal(uint8_t const* pixels, size_t row_bytes, size_t pitch, size_t height) const
    {
        return replay<true>(pixels, nullptr, row_bytes, pitch, height);
    }
    bool copy_to(uint8_t* pixels, size_t row_bytes, size_t pitch, size_t height) const
    {
        return replay<false>(nullptr, pixels, row_bytes, pitch, height);
    }
};
#endif
