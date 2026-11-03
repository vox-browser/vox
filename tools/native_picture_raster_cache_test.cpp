#include "../native_picture_raster_cache.h"
#include <cassert>
#include <iostream>
#include <limits>

int main()
{
    std::vector<uint8_t> source {1, 2, 3, 4}, pixels(48, 17);
    VoxGraphitePictureRegion region {};
    region.output = {2, 3, 2, 3, 16, pixels.data()};
    region.bytes = source.data(); region.size = source.size();
    region.matrix[0] = region.matrix[4] = region.matrix[8] = 1;
    VoxPictureRasterCache cache(4096, 2, 1024);
    auto cold = cache.prepare(&region, 1, 16, 16, true);
    assert(!cold.hit && !cold.key.empty());
    for (int y = 0; y < 3; ++y) std::fill_n(pixels.data() + y * 16, 8, uint8_t(40 + y));
    cache.finish(std::move(cold), &region, 1);
    std::fill(pixels.begin(), pixels.end(), 17);
    auto original = pixels;
    assert(cache.prepare(&region, 1, 16, 16, true).hit);
    for (int y = 0; y < 3; ++y) {
        for (int x = 0; x < 8; ++x) assert(pixels[y * 16 + x] == 40 + y);
        for (int x = 8; x < 16; ++x) assert(pixels[y * 16 + x] == 17);
    }
    // Every real input, including unsampled backdrop bytes, changes identity.
    pixels = original; pixels[1]++;
    assert(!cache.prepare(&region, 1, 16, 16, true).hit);
    pixels = original; source[2]++;
    assert(!cache.prepare(&region, 1, 16, 16, true).hit); source[2]--;
    for (int i = 0; i < 9; ++i) {
        region.matrix[i] += .125f;
        assert(!cache.prepare(&region, 1, 16, 16, true).hit);
        region.matrix[i] -= .125f;
    }
    assert(!cache.prepare(&region, 1, 17, 16, true).hit);
    assert(!cache.prepare(&region, 1, 16, 17, true).hit);
    region.output.x++; assert(!cache.prepare(&region, 1, 16, 16, true).hit); region.output.x--;
    region.output.y++; assert(!cache.prepare(&region, 1, 16, 16, true).hit); region.output.y--;
    assert(!cache.prepare(&region, 1, 16, 16, false).hit);
    // Caller storage and row stride are not identities. Padding stays untouched.
    auto alternate_source = source;
    std::vector<uint8_t> alternate_pixels(36, 17);
    region.bytes = alternate_source.data();
    region.output.pixels = alternate_pixels.data(); region.output.pitch = 12;
    assert(cache.prepare(&region, 1, 16, 16, true).hit);
    for (int y = 0; y < 3; ++y) {
        for (int x = 0; x < 8; ++x) assert(alternate_pixels[y * 12 + x] == 40 + y);
        for (int x = 8; x < 12; ++x) assert(alternate_pixels[y * 12 + x] == 17);
    }
    cache.clear(); assert(cache.size() == 0 && cache.bytes() == 0);
    // Limits include owned picture inputs, backdrop and output, with LRU eviction.
    for (int i = 0; i < 100; ++i) {
        alternate_source[0] = uint8_t(i);
        auto miss = cache.prepare(&region, 1, 16, 16, false);
        assert(!miss.hit && !miss.key.empty());
        cache.finish(std::move(miss), &region, 1);
        assert(cache.size() <= 2 && cache.bytes() <= 4096);
    }
    alternate_source[0] = 98;
    assert(cache.prepare(&region, 1, 16, 16, false).hit); // Promote older entry.
    alternate_source[0] = 100;
    auto miss = cache.prepare(&region, 1, 16, 16, false);
    cache.finish(std::move(miss), &region, 1);
    alternate_source[0] = 99;
    assert(!cache.prepare(&region, 1, 16, 16, false).hit);
    VoxPictureRasterCache byte_bounded(512, 128, 512);
    for (int i = 0; i < 100; ++i) {
        alternate_source[0] = uint8_t(i);
        auto pending = byte_bounded.prepare(&region, 1, 16, 16, false);
        assert(!pending.hit && !pending.key.empty());
        byte_bounded.finish(std::move(pending), &region, 1);
        assert(byte_bounded.bytes() <= 512);
    }
    alternate_source[0] = 0;
    assert(!byte_bounded.prepare(&region, 1, 16, 16, false).hit);
    region.output.width = 16; region.output.height = 16; region.output.pitch = 64;
    assert(cache.prepare(&region, 1, 32, 32, true).key.empty()); // Over budget, no reads.
    region.output.width = 2; region.output.height = 3; region.output.pitch = -1;
    assert(cache.prepare(&region, 1, 16, 16, true).key.empty());
    region.output.pitch = 12; region.matrix[0] = std::numeric_limits<float>::quiet_NaN();
    assert(cache.prepare(&region, 1, 16, 16, true).key.empty());
    std::cout << "Exact picture raster cache ownership, parameters, padding and limits pass\n";
}
