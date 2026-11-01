#ifndef VOX_NATIVE_RASTER_SNAPSHOT_H
#define VOX_NATIVE_RASTER_SNAPSHOT_H

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <utility>
#include <vector>
#if defined(__aarch64__) && !defined(VOX_RASTER_SNAPSHOT_SCALAR_SCAN)
#include <arm_neon.h>
#endif

// Owned, lossless rows for CPU raster-cache inputs and results. Flat RGBA
// regions use word runs; noisy images stay raw. A hit compares/expands directly
// into the caller's rows, without allocating a temporary decoded bitmap.
class VoxRasterSnapshot {
public:
    struct Rect { size_t left, top, right, bottom; };
private:
    std::vector<uint8_t> raw_;
    std::vector<uint32_t> packed_;
    size_t logical_bytes_ = 0;

    static uint32_t word(uint8_t const* bytes)
    {
        uint32_t result;
        std::memcpy(&result, bytes, sizeof(result));
        return result;
    }
    static bool equal_run(uint8_t const* bytes, size_t words, uint32_t value)
    {
        // Reduce whole runs instead of branching on each pixel. memcpy keeps
        // unaligned caller rows valid and lets the compiler vectorize loads.
        uint64_t pattern = uint64_t(value) << 32 | value;
        uint64_t difference = 0;
        size_t pairs = words / 2;
        for (size_t i = 0; i < pairs; ++i) {
            uint64_t actual;
            std::memcpy(&actual, bytes + i * 8, 8);
            difference |= actual ^ pattern;
        }
        return !difference && (!(words & 1) || word(bytes + pairs * 8) == value);
    }
    static void copy_run(uint8_t* bytes, size_t words, uint32_t value)
    {
        uint64_t pattern = uint64_t(value) << 32 | value;
        size_t pairs = words / 2;
        for (size_t i = 0; i < pairs; ++i)
            std::memcpy(bytes + i * 8, &pattern, 8);
        if (words & 1) std::memcpy(bytes + pairs * 8, &value, 4);
    }
    template<typename Run, typename Literal>
    static void encode(uint8_t const* bytes, size_t words, Run run, Literal literal)
    {
        size_t at = 0;
        while (at < words) {
            size_t end = at + 1;
            uint32_t value = word(bytes + at * 4);
#if !defined(VOX_RASTER_SNAPSHOT_SCALAR_SCAN)
            if (end < words && word(bytes + end * 4) == value) {
                ++end;
                uint64_t pattern = uint64_t(value) << 32 | value;
                while (words - end >= 4) {
                    uint64_t first, second;
                    std::memcpy(&first, bytes + end * 4, 8);
                    std::memcpy(&second, bytes + end * 4 + 8, 8);
                    if ((first ^ pattern) | (second ^ pattern)) break;
                    end += 4;
                }
            }
#endif
            while (end < words && word(bytes + end * 4) == value) ++end;
            if (end - at >= 3) {
                run(end - at, value);
                at = end;
                continue;
            }
            size_t start = at;
            at = end;
#if defined(__aarch64__) && !defined(VOX_RASTER_SNAPSHOT_SCALAR_SCAN)
            // Test four possible three-word runs together. Exact packet
            // boundaries stay unchanged; the scalar tail finds the first hit.
            while (words - at >= 6) {
                uint32x4_t first, second, third;
                std::memcpy(&first, bytes + at * 4, 16);
                std::memcpy(&second, bytes + (at + 1) * 4, 16);
                std::memcpy(&third, bytes + (at + 2) * 4, 16);
                auto matches = vandq_u32(vceqq_u32(first, second), vceqq_u32(first, third));
                if (vmaxvq_u32(matches)) break;
                at += 4;
            }
#endif
            while (at < words) {
                if (at + 2 < words && word(bytes + at * 4) == word(bytes + (at + 1) * 4)
                    && word(bytes + at * 4) == word(bytes + (at + 2) * 4)) break;
                ++at;
            }
            literal(bytes + start * 4, at - start);
        }
    }
    static bool equal_span(uint8_t const* first, uint8_t const* second,
        size_t bytes, size_t x, size_t y, Rect ignore)
    {
        if (y < ignore.top || y >= ignore.bottom || x >= ignore.right
            || x + bytes <= ignore.left) return !std::memcmp(first, second, bytes);
        size_t before = ignore.left > x ? ignore.left - x : 0;
        size_t after = std::min(bytes, ignore.right > x ? ignore.right - x : 0);
        return !std::memcmp(first, second, before)
            && !std::memcmp(first + after, second + after, bytes - after);
    }
    template<bool Compare>
    bool replay(uint8_t const* input, uint8_t* output, size_t row_bytes,
        size_t pitch, size_t height, Rect ignore) const
    {
        if (pitch < row_bytes || (height && row_bytes > SIZE_MAX / height)
            || row_bytes * height != logical_bytes_ || (!packed_.empty() && row_bytes % 4)) return false;
        if (!logical_bytes_) return true;
        if (packed_.empty()) {
            for (size_t y = 0; y < height; ++y) {
                if constexpr (Compare) {
                    if (!equal_span(input + y * pitch, raw_.data() + y * row_bytes,
                            row_bytes, 0, y, ignore)) return false;
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
                    if constexpr (Compare) {
                        auto* bytes = input + y * pitch + x;
                        if (y < ignore.top || y >= ignore.bottom
                            || x >= ignore.right || x + count * 4 <= ignore.left) {
                            if (!equal_run(bytes, count, value)) return false;
                        } else {
                            size_t before = ignore.left > x ? (ignore.left - x) / 4 : 0;
                            size_t after = std::min(count, (ignore.right - x) / 4);
                            if (!equal_run(bytes, before, value)
                                || !equal_run(bytes + after * 4, count - after, value)) return false;
                        }
                    } else copy_run(output + y * pitch + x, count, value);
                } else {
                    if constexpr (Compare) {
                        if (!equal_span(input + y * pitch + x,
                                reinterpret_cast<uint8_t const*>(packed_.data() + at),
                                count * 4, x, y, ignore)) return false;
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
        encode(raw_.data(), raw_.size() / 4,
            [&](size_t, uint32_t) { count += 2; },
            [&](uint8_t const*, size_t words) { count += words + 1; });
        if (count * 4 >= raw_.size() - raw_.size() / 8) return;
        packed_.resize(count);
        size_t at = 0;
        encode(raw_.data(), raw_.size() / 4,
            [&](size_t words, uint32_t value) {
                packed_[at++] = uint32_t(words * 2 + 1);
                packed_[at++] = value;
            },
            [&](uint8_t const* bytes, size_t words) {
                packed_[at++] = uint32_t(words * 2);
                std::memcpy(packed_.data() + at, bytes, words * 4);
                at += words;
            });
        std::vector<uint8_t>().swap(raw_);
    }
    size_t size() const { return raw_.size() + packed_.size() * 4; }
    bool equal(uint8_t const* pixels, size_t row_bytes, size_t pitch, size_t height) const
    {
        return replay<true>(pixels, nullptr, row_bytes, pitch, height, Rect{});
    }
    // Only a caller with an independent opacity/coverage proof may ignore
    // these whole pixels. Edges, padding and all other input remain exact.
    bool equal_outside_rectangle(uint8_t const* pixels, size_t row_bytes,
        size_t pitch, size_t height, Rect ignore) const
    {
        if (ignore.left > ignore.right || ignore.right > row_bytes / 4
            || ignore.top > ignore.bottom || ignore.bottom > height) return false;
        ignore.left *= 4; ignore.right *= 4;
        return replay<true>(pixels, nullptr, row_bytes, pitch, height, ignore);
    }
    bool copy_to(uint8_t* pixels, size_t row_bytes, size_t pitch, size_t height) const
    {
        return replay<false>(nullptr, pixels, row_bytes, pitch, height, Rect{});
    }
private:
    template<bool Compare>
    bool replay_region(uint8_t const* input, uint8_t* output, size_t width,
        size_t height, size_t pitch, Rect region) const
    {
        if (region.left > region.right || region.right > width
            || region.top > region.bottom || region.bottom > height
            || width > SIZE_MAX / 4 || (height && width * 4 > SIZE_MAX / height)
            || width * 4 * height != logical_bytes_
            || pitch < (region.right - region.left) * 4) return false;
        if (region.left == region.right || region.top == region.bottom) return true;
        auto span = [&](uint8_t const* bytes, size_t count, size_t x, size_t y,
            bool repeated, uint32_t value) {
            if (y < region.top || y >= region.bottom) return true;
            size_t first = std::max(x, region.left), end = std::min(x + count, region.right);
            if (first >= end) return true;
            size_t offset = (y - region.top) * pitch + (first - region.left) * 4;
            if constexpr (Compare) {
                return repeated ? equal_run(input + offset, end - first, value)
                    : !std::memcmp(input + offset, bytes + (first - x) * 4, (end - first) * 4);
            } else {
                if (repeated) copy_run(output + offset, end - first, value);
                else std::memcpy(output + offset, bytes + (first - x) * 4, (end - first) * 4);
                return true;
            }
        };
        if (packed_.empty()) {
            for (size_t y = region.top; y < region.bottom; ++y)
                if (!span(raw_.data() + y * width * 4, width, 0, y, false, 0)) return false;
            return true;
        }
        size_t at = 0, x = 0, y = 0;
        while (at < packed_.size() && y < region.bottom) {
            uint32_t tag = packed_[at++];
            size_t remaining = tag >> 1;
            bool repeated = tag & 1;
            uint32_t value = repeated ? packed_[at++] : 0;
            while (remaining) {
                size_t count = std::min(remaining, width - x);
                if (!span(reinterpret_cast<uint8_t const*>(packed_.data() + at),
                        count, x, y, repeated, value)) return false;
                if (!repeated) at += count;
                x += count; remaining -= count;
                if (x == width) { x = 0; ++y; }
            }
        }
        return true;
    }
public:
    // Subviews keep the original raster's dimensions and exact owned bytes.
    // Caller rows contain only the requested rectangle, with arbitrary padding.
    bool equal_region(uint8_t const* pixels, size_t width, size_t height,
        size_t pitch, Rect region) const
    {
        return replay_region<true>(pixels, nullptr, width, height, pitch, region);
    }
    bool copy_region_to(uint8_t* pixels, size_t width, size_t height,
        size_t pitch, Rect region) const
    {
        return replay_region<false>(nullptr, pixels, width, height, pitch, region);
    }
};
#endif
