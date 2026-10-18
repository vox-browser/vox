#include "../native_graphite_raster_cache.h"
#include <cassert>
#include <iostream>
#include <limits>

static VoxGraphiteImage image(uint8_t const* pixels)
{
    VoxGraphiteImage value {};
    value.matrix[0] = value.matrix[4] = value.matrix[8] = 1;
    value.source[2] = value.destination[2] = value.clip[2] = value.width = 2;
    value.source[3] = value.destination[3] = value.clip[3] = value.height = 2;
    value.opacity = 1;
    value.pitch = 8;
    value.pixels = pixels;
    return value;
}

int main()
{
    std::vector<uint8_t> source(16, 87), pixels(16, 31);
    auto descriptor = image(source.data());
    VoxGraphiteRasterCache cache;
    auto miss = cache.prepare(descriptor, 2, 2, 8, true, pixels.data());
    assert(!miss.hit && miss.pending);
    std::fill(pixels.begin(), pixels.end(), 123);
    cache.finish(std::move(miss), pixels.data(), 8);
    std::fill(pixels.begin(), pixels.end(), 31);
    assert(cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 123));

    // Reused allocations and changes outside the source crop must be observed.
    source[15]++;
    std::fill(pixels.begin(), pixels.end(), 31);
    assert(!cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);
    source[15]--;
    pixels[15]++;
    assert(!cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);
    pixels[15]--;

    // Every render parameter that affects the result participates in identity.
    auto check_miss = [&](VoxGraphiteImage const& changed) {
        assert(!cache.prepare(changed, 2, 2, 8, true, pixels.data()).hit);
    };
    for (int field = 0; field < 9 + 4 + 4 + 12; ++field) {
        auto changed = descriptor;
        if (field < 9) changed.matrix[field] += .25f;
        else if (field < 13) changed.source[field - 9] += .25f;
        else if (field < 17) changed.destination[field - 13] += .25f;
        else changed.clip[field - 17] += .25f;
        check_miss(changed);
    }
    auto changed = descriptor; changed.opacity = .5f; check_miss(changed);
    changed = descriptor; changed.nearest = 1; check_miss(changed);
    changed = descriptor; changed.flags = 1; check_miss(changed);
    changed = descriptor; changed.width = 1; check_miss(changed);
    changed = descriptor; changed.height = 1; check_miss(changed);
    changed = descriptor; changed.has_color_profile = 1; check_miss(changed);
    assert(!cache.prepare(descriptor, 1, 2, 8, true, pixels.data()).hit);
    assert(!cache.prepare(descriptor, 2, 1, 8, true, pixels.data()).hit);
    assert(!cache.prepare(descriptor, 2, 2, 8, false, pixels.data()).hit);

    // Compare owned pixel values, not pointers or row padding, for both inputs.
    std::vector<uint8_t> padded_source(24, 0), padded_output(24, 44);
    for (int y = 0; y < 2; ++y) {
        std::memcpy(padded_source.data() + y * 12, source.data() + y * 8, 8);
        std::memcpy(padded_output.data() + y * 12, pixels.data() + y * 8, 8);
    }
    changed = descriptor; changed.pixels = padded_source.data(); changed.pitch = 12;
    assert(cache.prepare(changed, 2, 2, 12, true, padded_output.data()).hit);
    for (int y = 0; y < 2; ++y) {
        for (int x = 0; x < 8; ++x) assert(padded_output[y * 12 + x] == 123);
        for (int x = 8; x < 12; ++x) assert(padded_output[y * 12 + x] == 44);
    }
    cache.clear();
    assert(!cache.prepare(descriptor, 2, 2, 8, true, pixels.data()).hit);

    // Cache full profiles, planar YUV (including odd 4:2:0 dimensions), and
    // transparent draws, which have no dependency on the output's old contents.
    for (int flags : {0, 4, 4 | 8, 4 | 16}) {
        std::vector<uint8_t> planes(27, 50);
        auto planar = image(planes.data());
        planar.width = planar.height = 3;
        planar.pitch = 12;
        planar.flags = flags;
        if (!flags) { planes.resize(36, 50); planar.pixels = planes.data(); }
        planar.has_color_profile = 1;
        for (int p = 0; p < 10; ++p) planar.color_profile[p] = .1f * p;
        auto request = cache.prepare(planar, 2, 2, 8, false, pixels.data());
        assert(!request.hit && request.pending);
        cache.finish(std::move(request), pixels.data(), 8);
        assert(cache.prepare(planar, 2, 2, 8, false, pixels.data()).hit);
        size_t last = flags & 4 ? (flags & 16 ? 26 : 16) : 35;
        planes[last]++;
        assert(!cache.prepare(planar, 2, 2, 8, false, pixels.data()).hit);
        planes[last]--;
        for (int p = 0; p < 10; ++p) {
            auto profile = planar;
            profile.color_profile[p] += .1f;
            assert(!cache.prepare(profile, 2, 2, 8, false, pixels.data()).hit);
        }
    }

    // LRU and byte caps bound retained memory; failures are never published.
    VoxGraphiteRasterCache small(64, 2);
    auto put = [&](int key) {
        auto value = descriptor; value.nearest = key;
        auto request = small.prepare(value, 2, 2, 8, false, pixels.data());
        bool hit = request.hit;
        small.finish(std::move(request), pixels.data(), 8);
        return hit;
    };
    assert(!put(0)); assert(!put(1)); assert(put(0));
    assert(!put(2)); assert(put(0)); assert(!put(1));
    VoxGraphiteRasterCache tiny(31);
    assert(!tiny.prepare(descriptor, 2, 2, 8, false, pixels.data()).pending);
    VoxGraphiteRasterCache disabled(1024, 0);
    assert(!disabled.prepare(descriptor, 2, 2, 8, false, pixels.data()).pending);
    changed = descriptor; changed.width = changed.height = std::numeric_limits<int>::max();
    assert(!cache.prepare(changed, 2, 2, 8, false, pixels.data()).pending);
    changed.flags = 4;
    assert(!cache.prepare(changed, 2, 2, 8, false, pixels.data()).pending);
    assert(!cache.prepare(descriptor, 2, 2, 7, false, pixels.data()).pending);
    assert(!cache.prepare(descriptor, 0, 2, 8, false, pixels.data()).pending);
    assert(!cache.prepare(descriptor, 2, 2, 8, false, nullptr).pending);
    // Shapes retain clip-out contents, MSAA mode and the optional underlay.
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[2] = shape.rect[3] = 2;
    shape.thickness = 1;
    shape.alpha = 255;
    shape.fill = shape.anti_alias = 1;
    float clips[] {0, 0, 1, 1};
    shape.clip_outs = clips;
    shape.clip_out_count = 1;
    shape.has_underlay = 1;
    auto request = cache.prepare(shape, 2, 2, 8, false, pixels.data());
    assert(!request.hit && request.pending);
    cache.finish(std::move(request), pixels.data(), 8);
    assert(cache.prepare(shape, 2, 2, 8, false, pixels.data()).hit);
    auto shape_misses = [&](VoxGraphiteShape const& value) {
        assert(!cache.prepare(value, 2, 2, 8, false, pixels.data()).hit);
    };
    for (int i = 0; i < 9 + 12 + 12; ++i) {
        auto value = shape;
        if (i < 9) value.matrix[i] += .125f;
        else if (i < 21) value.rect[i - 9] += .125f;
        else value.underlay_rect[i - 21] += .125f;
        shape_misses(value);
    }
    auto value = shape; value.thickness++; shape_misses(value);
    value = shape; value.red++; shape_misses(value);
    value = shape; value.green++; shape_misses(value);
    value = shape; value.blue++; shape_misses(value);
    value = shape; value.alpha--; shape_misses(value);
    value = shape; value.fill = 0; shape_misses(value);
    value = shape; value.anti_alias = 0; shape_misses(value);
    value = shape; value.force_msaa = 1; shape_misses(value);
    value = shape; value.has_underlay = 0; shape_misses(value);
    value = shape; value.clip_out_count = 0; shape_misses(value);
    for (int i = 0; i < 4; ++i) {
        value = shape; value.underlay_rgba[i]++; shape_misses(value);
        clips[i]++; shape_misses(shape); clips[i]--;
    }
    assert(!cache.prepare(shape, 2, 2, 8, true, pixels.data()).hit);
    value = shape; value.clip_out_count = -1;
    assert(!cache.prepare(value, 2, 2, 8, false, pixels.data()).pending);
    value = shape; value.clip_outs = nullptr;
    assert(!cache.prepare(value, 2, 2, 8, false, pixels.data()).pending);
    std::vector<uint8_t> large_output(200 * 200 * 4);
    assert(!cache.prepare(shape, 200, 200, 800, false, large_output.data()).pending);
    assert(cache.prepare(descriptor, 200, 200, 800, false, large_output.data()).pending);
    cache.clear();
    assert(!cache.prepare(shape, 2, 2, 8, false, pixels.data()).hit);
    // Corner patches retain the original surface geometry in addition to the
    // packed pixels, so a different GPU coverage calculation cannot alias.
    shape.clip_out_count = 0;
    std::fill(pixels.begin(), pixels.end(), 19);
    request = cache.prepare_patches(shape, 631, 303, 4, true, pixels.data());
    assert(!request.hit && request.pending);
    std::fill(pixels.begin(), pixels.end(), 71);
    cache.finish(std::move(request), pixels.data(), 16);
    std::fill(pixels.begin(), pixels.end(), 19);
    assert(!cache.prepare_patches(shape, 632, 303, 4, true, pixels.data()).hit);
    assert(!cache.prepare_patches(shape, 631, 304, 4, true, pixels.data()).hit);
    assert(!cache.prepare(shape, 4, 1, 16, true, pixels.data()).hit);
    assert(cache.prepare_patches(shape, 631, 303, 4, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 71));
    std::fill(pixels.begin(), pixels.end(), 19); pixels[15]++;
    assert(!cache.prepare_patches(shape, 631, 303, 4, true, pixels.data()).hit);
    shape.clip_out_count = 1;
    assert(!cache.prepare_patches(shape, 631, 303, 4, true, pixels.data()).pending);
    shape.clip_out_count = 0;
    assert(!cache.prepare_patches(shape, 0, 303, 4, true, pixels.data()).pending);
    assert(!cache.prepare_patches(shape, 631, 303, -1, true, pixels.data()).pending);
    std::cout << "Graphite raster cache: source/backdrop mutation, geometry, profiles, strides, YUV, LRU and bounds passed\n";
}
