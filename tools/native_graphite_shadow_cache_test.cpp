#include "../native/include/native_graphite_raster_cache.h"
#include <cassert>
#include <iostream>

int main()
{
    VoxGraphiteShadow shadow {};
    shadow.matrix[0] = shadow.matrix[4] = shadow.matrix[8] = 1;
    shadow.shadow[2] = shadow.content[2] = 2;
    shadow.shadow[3] = shadow.content[3] = 2;
    shadow.blur = 3;
    shadow.alpha = 127;
    std::vector<uint8_t> pixels(16, 31);
    VoxGraphiteRasterCache cache;
    auto miss = cache.prepare(shadow, 2, 2, 8, true, pixels.data());
    assert(!miss.hit && miss.pending);
    std::fill(pixels.begin(), pixels.end(), 83);
    cache.finish(std::move(miss), pixels.data(), 8);
    auto reset = [&] { std::fill(pixels.begin(), pixels.end(), 31); };
    reset();
    assert(cache.prepare(shadow, 2, 2, 8, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 83));
    auto different = [&](VoxGraphiteShadow const& changed) {
        reset();
        assert(!cache.prepare(changed, 2, 2, 8, true, pixels.data()).hit);
    };
    for (int index = 0; index < 9 + 12 + 12; ++index) {
        auto changed = shadow;
        if (index < 9) changed.matrix[index] += .25f;
        else if (index < 21) changed.shadow[index - 9] += .25f;
        else changed.content[index - 21] += .25f;
        different(changed);
    }
    auto changed = shadow; changed.blur += 1; different(changed);
    changed = shadow; changed.red++; different(changed);
    changed = shadow; changed.green++; different(changed);
    changed = shadow; changed.blue++; different(changed);
    changed = shadow; changed.alpha++; different(changed);
    changed = shadow; changed.has_float_color = 1; different(changed);
    auto precise = shadow;
    precise.has_float_color = 1;
    precise.float_color[3] = .25f;
    reset();
    auto precise_miss = cache.prepare(precise, 2, 2, 8, true, pixels.data());
    assert(!precise_miss.hit && precise_miss.pending);
    cache.finish(std::move(precise_miss), pixels.data(), 8);
    assert(cache.prepare(precise, 2, 2, 8, true, pixels.data()).hit);
    for (int index = 0; index < 4; ++index) {
        auto other = precise;
        other.float_color[index] += .001f;
        different(other);
    }
    reset(); pixels[15]++;
    assert(!cache.prepare(shadow, 2, 2, 8, true, pixels.data()).hit);
    reset();
    assert(!cache.prepare(shadow, 1, 2, 8, true, pixels.data()).hit);
    assert(!cache.prepare(shadow, 2, 1, 8, true, pixels.data()).hit);
    assert(!cache.prepare(shadow, 2, 2, 8, false, pixels.data()).hit);

    // Input padding is irrelevant and output padding remains untouched.
    std::vector<uint8_t> padded(24, 31);
    padded[8] = padded[20] = 199;
    assert(cache.prepare(shadow, 2, 2, 12, true, padded.data()).hit);
    assert(padded[0] == 83 && padded[12] == 83 && padded[8] == 199 && padded[20] == 199);
    cache.clear(); reset();
    assert(!cache.prepare(shadow, 2, 2, 8, true, pixels.data()).hit);
    VoxGraphiteRasterCache tiny(32, 128);
    for (int index = 0; index < 128; ++index) {
        changed = shadow; changed.blur = float(index);
        auto request = tiny.prepare(changed, 2, 2, 8, true, pixels.data());
        tiny.finish(std::move(request), pixels.data(), 8);
    }
    changed = shadow; changed.blur = 127;
    assert(tiny.prepare(changed, 2, 2, 8, true, pixels.data()).hit);
    changed.blur = 126;
    assert(!tiny.prepare(changed, 2, 2, 8, true, pixels.data()).hit);
    std::cout << "Graphite shadow cache identity, padding and bounded storage passed\n";
}
