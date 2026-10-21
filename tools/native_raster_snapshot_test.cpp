#include "../native_raster_snapshot.h"
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
    VoxRasterSnapshot empty;
    assert(empty.equal(nullptr, 0, 0, 0));
    assert(empty.copy_to(nullptr, 0, 0, 0));
    std::cout << "Raster snapshots: exact runs/literals, unaligned rows, padding, mutation and raw fallback passed\n";
}
