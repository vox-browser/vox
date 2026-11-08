#include "../native/include/native_raster_snapshot.h"
#include <cassert>
#include <iostream>
#include <random>

static void check(std::vector<uint8_t> const& original, size_t row_bytes, size_t height,
    bool compressed)
{
    auto owned = original;
    VoxRasterSnapshot snapshot(std::move(owned));
    assert(compressed ? snapshot.size() < original.size() / 2 : snapshot.size() == original.size());
    assert(snapshot.equal(original.data(), row_bytes, row_bytes, height));
    assert(!snapshot.equal(original.data(), row_bytes + 4, row_bytes + 4, height));
    std::vector<uint8_t> padded(1 + height * (row_bytes + 7), 91);
    assert(snapshot.copy_to(padded.data() + 1, row_bytes, row_bytes + 7, height));
    for (size_t y = 0; y < height; ++y) {
        assert(!std::memcmp(padded.data() + 1 + y * (row_bytes + 7), original.data() + y * row_bytes, row_bytes));
        for (size_t i = 0; i < 7; ++i) assert(padded[1 + y * (row_bytes + 7) + row_bytes + i] == 91);
    }
    assert(padded[0] == 91);
    assert(snapshot.equal(padded.data() + 1, row_bytes, row_bytes + 7, height));
    // A changed word at either end or across a row boundary must miss.
    for (size_t at : {size_t(0), row_bytes - 1, row_bytes, original.size() - 1}) {
        size_t padded_at = 1 + at / row_bytes * (row_bytes + 7) + at % row_bytes;
        padded[padded_at] ^= 1;
        assert(!snapshot.equal(padded.data() + 1, row_bytes, row_bytes + 7, height));
        padded[padded_at] ^= 1;
    }
}

int main()
{
    // Runs cross rows and include all bit patterns, including zero and UINT_MAX.
    std::vector<uint8_t> flat(257 * 31 * 4);
    check(flat, 257 * 4, 31, true);
    std::fill(flat.begin(), flat.end(), 255);
    check(flat, 257 * 4, 31, true);
    std::mt19937 random(73441);
    for (int trial = 0; trial < 64; ++trial) {
        auto mixed = flat;
        // Short literals border long runs; boundaries need not align with rows.
        size_t at = 0;
        while (at < mixed.size() / 4) {
            size_t count = std::min(size_t(random() % 137 + 1), mixed.size() / 4 - at);
            uint32_t value = random();
            bool run = random() % 3 != 0;
            for (size_t i = 0; i < count; ++i) {
                uint32_t next = run ? value : uint32_t(random());
                std::memcpy(mixed.data() + (at + i) * 4, &next, 4);
            }
            at += count;
        }
        // These fixtures compress, though some exceed the stricter half-size bound.
        auto owned = mixed;
        VoxRasterSnapshot snapshot(std::move(owned));
        assert(snapshot.size() < mixed.size());
        assert(snapshot.equal(mixed.data(), 257 * 4, 257 * 4, 31));
        std::vector<uint8_t> decoded(mixed.size());
        assert(snapshot.copy_to(decoded.data(), 257 * 4, 257 * 4, 31));
        assert(decoded == mixed);
    }
    auto noise = flat;
    for (auto& value : noise) value = uint8_t(random());
    check(noise, 257 * 4, 31, false);
    check(std::vector<uint8_t>(28, 7), 4, 7, false);
    check(std::vector<uint8_t>(4097, 7), 241, 17, false);
    // Repeated words may start unaligned, end in an odd word, and cross
    // arbitrary row boundaries. Every word remains part of the cache key.
    for (size_t width : {1, 2, 3, 7, 16, 31, 64, 257, 544}) {
        size_t height = 1200 / width + 2, row_bytes = width * 4, pitch = row_bytes + 7;
        std::vector<uint8_t> original(row_bytes * height), input(1 + pitch * height, 91);
        uint32_t value = 0x1234abcd;
        for (size_t i = 0; i < original.size(); i += 4)
            std::memcpy(original.data() + i, &value, 4);
        auto owned = original;
        VoxRasterSnapshot snapshot(std::move(owned));
        assert(snapshot.size() < original.size());
        assert(snapshot.copy_to(input.data() + 1, row_bytes, pitch, height));
        assert(snapshot.equal(input.data() + 1, row_bytes, pitch, height));
        for (size_t y = 0; y < height; ++y) {
            assert(!std::memcmp(input.data() + 1 + y * pitch,
                original.data() + y * row_bytes, row_bytes));
            for (size_t x = 0; x < width; ++x) {
                size_t at = 1 + y * pitch + x * 4 + (x + y) % 4;
                input[at] ^= 1;
                assert(!snapshot.equal(input.data() + 1, row_bytes, pitch, height));
                input[at] ^= 1;
            }
            for (size_t x = row_bytes; x < pitch; ++x) assert(input[1 + y * pitch + x] == 91);
        }
        assert(input[0] == 91);
    }
    // A proven opaque image interior can ignore its hidden backdrop. Exercise
    // both raw and compressed snapshots, row padding and mask boundaries.
    for (bool compressed : {false, true}) {
        constexpr size_t width = 67, height = 31, row_bytes = width * 4, pitch = row_bytes + 7;
        std::vector<uint8_t> original(row_bytes * height, 47), input(pitch * height, 201);
        if (!compressed) for (auto& byte : original) byte = uint8_t(random());
        auto owned = original;
        VoxRasterSnapshot snapshot(std::move(owned));
        assert((snapshot.size() < original.size()) == compressed);
        for (size_t y = 0; y < height; ++y)
            std::memcpy(input.data() + y * pitch, original.data() + y * row_bytes, row_bytes);
        VoxRasterSnapshot::Rect mask {3, 2, 51, 28};
        for (size_t y = mask.top; y < mask.bottom; ++y)
            for (size_t x = mask.left * 4; x < mask.right * 4; ++x) input[y * pitch + x] ^= 73;
        assert(!snapshot.equal(input.data(), row_bytes, pitch, height));
        assert(snapshot.equal_outside_rectangle(input.data(), row_bytes, pitch, height, mask));
        for (auto offset : {mask.top * pitch + (mask.left - 1) * 4,
                mask.top * pitch + mask.right * 4,
                (mask.top - 1) * pitch + mask.left * 4,
                mask.bottom * pitch + mask.left * 4}) {
            input[offset] ^= 31;
            assert(!snapshot.equal_outside_rectangle(input.data(), row_bytes, pitch, height, mask));
            input[offset] ^= 31;
        }
        assert(!snapshot.equal_outside_rectangle(input.data(), row_bytes, pitch, height, {4, 0, 3, 1}));
        assert(!snapshot.equal_outside_rectangle(input.data(), row_bytes, pitch, height, {0, 0, width + 1, 1}));
        assert(!snapshot.equal_outside_rectangle(input.data(), row_bytes, pitch, height, {0, 0, 1, height + 1}));
        std::vector<uint8_t> decoded(original.size());
        assert(snapshot.copy_to(decoded.data(), row_bytes, row_bytes, height));
        assert(decoded == original);
    }
    // Literal spans cross rows and SIMD-sized boundaries. Check the exact
    // retained word count as well as padded replay and mutation detection.
    for (size_t literals : {1, 2, 3, 15, 16, 17, 31, 32, 33, 255, 1024}) {
        constexpr size_t width = 7, prefix = 1025;
        size_t height = (prefix + literals + 1031 + width - 1) / width;
        std::vector<uint8_t> bytes(width * height * 4);
        for (size_t i = 0; i < width * height; ++i) {
            uint32_t value = i < prefix ? 0x2718abcd
                : i < prefix + literals ? uint32_t((i - prefix) * 7919 + 17)
                : 0xaebc3347;
            std::memcpy(bytes.data() + i * 4, &value, 4);
        }
        auto owned = bytes;
        VoxRasterSnapshot snapshot(std::move(owned));
        assert(snapshot.size() == (literals + 5) * 4);
        check(bytes, width * 4, height, true);
    }
    // Every alignment of a short repeated run must terminate its neighboring
    // literals at the same word, including tails shorter than one SIMD group.
    for (size_t prefix = 1; prefix <= 19; ++prefix)
    for (size_t run = 1; run <= 19; ++run) {
        constexpr size_t words = 2051;
        std::vector<uint8_t> bytes(words * 4);
        for (size_t i = 0; i < words; ++i) {
            uint32_t value = i < prefix ? uint32_t(i * 7919 + 17)
                : i < prefix + run ? 0x1234abcd : 0xaebc3347;
            std::memcpy(bytes.data() + i * 4, &value, 4);
        }
        auto owned = bytes;
        VoxRasterSnapshot snapshot(std::move(owned));
        size_t packed_words = run >= 3 ? prefix + 5 : prefix + run + 3;
        assert(snapshot.size() == packed_words * 4);
        assert(snapshot.equal(bytes.data(), words * 4, words * 4, 1));
        std::vector<uint8_t> decoded(bytes.size());
        assert(snapshot.copy_to(decoded.data(), words * 4, words * 4, 1));
        assert(decoded == bytes);
    }
    // Construct straight from caller rows. Both raw and packed paths own their
    // bytes after return and never retain row padding or unaligned pointers.
    for (bool packed : {false, true}) for (size_t width : {1, 7, 67, 257, 1024})
    for (size_t padding : {0, 1, 7, 64}) for (size_t height : {1, 37}) {
        size_t row_bytes = width * 4, pitch = row_bytes + padding;
        std::vector<uint8_t> source(1 + pitch * height, 91), expected(row_bytes * height);
        for (size_t i = 0; i < expected.size(); ++i)
            expected[i] = packed ? uint8_t((i / 4096) % 2 ? 0xff : 0) : uint8_t(random());
        for (size_t y = 0; y < height; ++y)
            std::memcpy(source.data() + 1 + y * pitch, expected.data() + y * row_bytes, row_bytes);
        auto old_input = expected;
        VoxRasterSnapshot old(std::move(old_input));
        VoxRasterSnapshot direct(source.data() + 1, row_bytes, pitch, height);
        assert(direct.size() == old.size());
        assert(direct.equal(source.data() + 1, row_bytes, pitch, height));
        std::fill(source.begin(), source.end(), 13);
        std::vector<uint8_t> actual(expected.size());
        assert(direct.copy_to(actual.data(), row_bytes, row_bytes, height));
        assert(actual == expected);
    }
    VoxRasterSnapshot empty;
    assert(empty.equal(nullptr, 0, 0, 0));
    assert(empty.copy_to(nullptr, 0, 0, 0));
    // Arbitrary subviews must preserve padding and compare every selected
    // byte, including runs and literals crossing the view's row boundaries.
    for (bool packed : {false, true}) for (size_t width : {1, 7, 67, 257}) {
        constexpr size_t height = 37;
        std::vector<uint8_t> bytes(width * height * 4, 47);
        for (size_t i = 0; i < bytes.size(); ++i)
            if (!packed || i % 511 < 17) bytes[i] = uint8_t(random());
        auto owned = bytes;
        VoxRasterSnapshot snapshot(std::move(owned));
        for (size_t trial = 0; trial < 127; ++trial) {
            size_t x = random() % width, y = random() % height;
            size_t w = 1 + random() % (width - x), h = 1 + random() % (height - y), pitch = w * 4 + 7;
            VoxRasterSnapshot::Rect region {x, y, x + w, y + h};
            std::vector<uint8_t> view(1 + pitch * h, 91);
            assert(snapshot.copy_region_to(view.data() + 1, width, height, pitch, region));
            for (size_t row = 0; row < h; ++row) {
                assert(!std::memcmp(view.data() + 1 + row * pitch,
                    bytes.data() + ((y + row) * width + x) * 4, w * 4));
                for (size_t p = w * 4; p < pitch; ++p) assert(view[1 + row * pitch + p] == 91);
            }
            assert(view[0] == 91);
            assert(snapshot.equal_region(view.data() + 1, width, height, pitch, region));
            size_t changed = 1 + (random() % h) * pitch + random() % (w * 4);
            view[changed] ^= 1;
            assert(!snapshot.equal_region(view.data() + 1, width, height, pitch, region));
            assert(!snapshot.equal_region(view.data(), width, height, pitch, {0, 0, width + 1, height}));
            assert(!snapshot.copy_region_to(view.data(), width, height, pitch, {0, 0, width, height + 1}));
        }
    }
    std::cout << "Raster snapshots: exact runs/literals, unaligned rows, padding, mutation and raw fallback passed\n";
}
