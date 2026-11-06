#include "../native_picture_raster_cache.h"
#include <cassert>
#include <iostream>

static void ownership_and_rows()
{
    VoxPictureRasterCache cache;
    std::vector<uint8_t> key {1, 2, 3, 4}, original = key;
    constexpr size_t pitch = 80, row = 64, height = 7;
    std::vector<uint8_t> input(pitch * height, 199), output(input.size(), 171);
    for (size_t y = 0; y < height; ++y)
        for (size_t x = 0; x < row; ++x) input[y * pitch + x] = (x * 31 + y * 13) % 256;
    auto pixels = input;
    assert(!cache.restore(key, output.data(), row, pitch, height));
    cache.store(key, input.data(), row, pitch, height);
    std::fill(input.begin(), input.end(), 0);
    key[0] = 99;
    assert(!cache.restore(key, output.data(), row, pitch, height));
    assert(cache.restore(original, output.data(), row, pitch, height));
    for (size_t y = 0; y < height; ++y) {
        for (size_t x = 0; x < row; ++x) assert(output[y * pitch + x] == pixels[y * pitch + x]);
        for (size_t x = row; x < pitch; ++x) assert(output[y * pitch + x] == 171);
    }
    assert(!cache.restore(original, output.data(), row / 2, pitch, height));
    assert(!cache.restore(original, output.data(), row, pitch, height - 1));
    assert(!cache.restore(original, output.data(), row, row - 1, height));
    assert(!cache.restore(original, output.data(), row, SIZE_MAX, height));
    // Replacing a successful key does not create duplicate entries.
    cache.store(original, input.data(), row, pitch, height);
    assert(cache.entries() == 1);
    assert(cache.restore(original, output.data(), row, pitch, height));
    for (size_t y = 0; y < height; ++y)
        for (size_t x = 0; x < row; ++x) assert(output[y * pitch + x] == 0);
    cache.clear();
    assert(cache.entries() == 0 && cache.bytes() == 0);
    assert(!cache.restore(original, output.data(), row, pitch, height));
}

static void budgets_and_eviction()
{
    std::vector<uint8_t> pixels(256 * 4, 7), output(pixels.size(), 0);
    VoxPictureRasterCache cache(8192, 2);
    std::vector<uint8_t> a {1}, b {2}, c {3};
    cache.store(a, pixels.data(), pixels.size(), pixels.size(), 1);
    cache.store(b, pixels.data(), pixels.size(), pixels.size(), 1);
    assert(cache.restore(a, output.data(), pixels.size(), pixels.size(), 1));
    cache.store(c, pixels.data(), pixels.size(), pixels.size(), 1);
    assert(cache.entries() == 2 && cache.bytes() <= 8192);
    assert(!cache.restore(b, output.data(), pixels.size(), pixels.size(), 1));
    assert(cache.restore(a, output.data(), pixels.size(), pixels.size(), 1));
    for (int i = 0; i < 1000; ++i) {
        std::vector<uint8_t> key(64, uint8_t(i));
        key[0] = i >> 8;
        cache.store(key, pixels.data(), pixels.size(), pixels.size(), 1);
        assert(cache.entries() <= 2 && cache.bytes() <= 8192);
    }
    // Incompressible storage must fit the byte budget as well as the count cap.
    VoxPictureRasterCache small(1500, 64);
    for (size_t i = 0; i < pixels.size(); ++i) pixels[i] = (i * 31 + i / 11) % 256;
    small.store(a, pixels.data(), pixels.size(), pixels.size(), 1);
    assert(small.entries() == 1);
    small.store(b, pixels.data(), pixels.size(), pixels.size(), 1);
    assert(small.entries() == 1 && small.bytes() <= 1500);
    assert(!small.restore(a, output.data(), pixels.size(), pixels.size(), 1));
    std::vector<uint8_t> oversized(1024 * 1024 + 1, 0);
    cache.store(oversized, pixels.data(), pixels.size(), pixels.size(), 1);
    assert(!cache.restore(oversized, output.data(), pixels.size(), pixels.size(), 1));
    VoxPictureRasterCache disabled(0, 0);
    disabled.store(a, pixels.data(), pixels.size(), pixels.size(), 1);
    assert(disabled.entries() == 0);
    assert(!cache.restore(a, output.data(), 4, 4, SIZE_MAX));
}

int main()
{
    ownership_and_rows();
    budgets_and_eviction();
    // Flat transparent/opaque layers exercise compressed snapshots; high
    // entropy layers exercise raw storage, including unaligned input rows.
    VoxPictureRasterCache cache;
    for (int scene = 0; scene < 70; ++scene) {
        size_t row = 4 * (17 + scene), height = 3 + scene, pitch = row + 12;
        std::vector<uint8_t> source(pitch * height + 1), target(source.size(), 219), key {uint8_t(scene)};
        for (size_t i = 0; i < source.size(); ++i)
            source[i] = scene % 3 == 0 ? 0 : scene % 3 == 1 ? 255 : (i * 67 + i / 19) % 256;
        cache.store(key, source.data() + 1, row, pitch, height);
        assert(cache.restore(key, target.data() + 1, row, pitch, height));
        assert(target[0] == 219);
        for (size_t y = 0; y < height; ++y) {
            assert(!std::memcmp(source.data() + 1 + y * pitch, target.data() + 1 + y * pitch, row));
            for (size_t x = row; x < pitch; ++x) assert(target[1 + y * pitch + x] == 219);
        }
    }
    std::cout << "Picture raster cache: owned inputs, exact padded/unaligned rows, mutation, eviction and bounds passed\n";
}
