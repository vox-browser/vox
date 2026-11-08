#include "../native/include/native_graphite_raster_cache.h"
#include <cassert>
#include <iostream>
#include <limits>

static std::vector<VoxGraphiteImage> placements(uint8_t const* source)
{
    VoxGraphiteImage image {};
    image.matrix[0] = image.matrix[4] = image.matrix[8] = 1;
    image.source[2] = image.source[3] = image.width = image.height = 2;
    image.destination[2] = image.destination[3] = image.clip[2] = image.clip[3] = 2;
    image.opacity = 1; image.pitch = 8; image.pixels = source;
    auto second = image;
    second.destination[0] = second.clip[0] = 1;
    return {image, second};
}

int main()
{
    std::vector<uint8_t> source(16, 87), backdrop(16, 31), pixels;
    auto images = placements(source.data());
    VoxGraphiteRasterCache cache;
    auto request = cache.prepare_tiles(images.data(), 2, 2, 2, 8, true, backdrop.data());
    assert(!request.hit && request.pending);
    pixels.assign(16, 123);
    cache.finish(std::move(request), pixels.data(), 8);
    pixels = backdrop;
    assert(cache.prepare_tiles(images.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    assert(pixels == std::vector<uint8_t>(16, 123));
    int misses = 0;
    auto miss = [&](std::vector<VoxGraphiteImage> const& changed) {
        pixels = backdrop;
        assert(!cache.prepare_tiles(changed.data(), int(changed.size()), 2, 2, 8, true, pixels.data()).hit);
        assert(pixels == backdrop);
        ++misses;
    };
    // Every placement contributes its geometry, sampling, profile and alpha.
    for (int placement = 0; placement < 2; ++placement) {
        for (int field = 0; field < 29; ++field) {
            auto changed = images;
            auto& image = changed[placement];
            if (field < 9) image.matrix[field] += .25f;
            else if (field < 13) image.source[field - 9] += .25f;
            else if (field < 17) image.destination[field - 13] += .25f;
            else image.clip[field - 17] += .25f;
            miss(changed);
        }
        auto changed = images; changed[placement].opacity = .5f; miss(changed);
        changed = images; changed[placement].nearest = 1; miss(changed);
        changed = images; changed[placement].flags = VOX_GRAPHITE_IMAGE_FORCE_MSAA; miss(changed);
        changed = images; changed[placement].flags = VOX_GRAPHITE_IMAGE_REPEAT_X; miss(changed);
        changed = images; changed[placement].flags = VOX_GRAPHITE_IMAGE_REPEAT_Y; miss(changed);
        changed = images; changed[placement].has_color_profile = 1; miss(changed);
        changed = images; changed[placement].has_background_color = 1; miss(changed);
    }
    auto changed = images;
    std::swap(changed[0], changed[1]); miss(changed);
    changed.pop_back(); miss(changed);
    changed = images; changed.push_back(images[0]); miss(changed);
    // A color change under a transparent pattern changes the resolved pixels.
    changed = images;
    changed[0].has_background_color = 1;
    changed[0].background_rgba[3] = 255;
    pixels = backdrop;
    auto colored = cache.prepare_tiles(changed.data(), 2, 2, 2, 8, true, pixels.data());
    assert(colored.pending && !colored.hit);
    cache.finish(std::move(colored), pixels.data(), 8);
    for (int channel = 0; channel < 4; ++channel) {
        auto modified = changed;
        modified[0].background_rgba[channel]++;
        pixels = backdrop;
        assert(!cache.prepare_tiles(modified.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    }
    changed[0].border_width = 2;
    pixels = backdrop;
    auto bordered = cache.prepare_tiles(changed.data(), 2, 2, 2, 8, true, pixels.data());
    assert(bordered.pending && !bordered.hit);
    cache.finish(std::move(bordered), pixels.data(), 8);
    for (int component = 0; component < 12; ++component) {
        auto modified = changed;
        modified[0].border_rect[component]++;
        pixels = backdrop;
        assert(!cache.prepare_tiles(modified.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    }
    for (int channel = 0; channel < 4; ++channel) {
        auto modified = changed;
        modified[0].border_rgba[channel]++;
        pixels = backdrop;
        assert(!cache.prepare_tiles(modified.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    }
    pixels = backdrop; pixels[3]++;
    assert(!cache.prepare_tiles(images.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    pixels = backdrop;
    assert(!cache.prepare_tiles(images.data(), 2, 2, 2, 8, false, pixels.data()).hit);
    assert(!cache.prepare_tiles(images.data(), 2, 1, 2, 8, true, pixels.data()).hit);
    assert(!cache.prepare_tiles(images.data(), 2, 2, 1, 8, true, pixels.data()).hit);
    source.back()++; miss(images); source.back()--;

    // Recreated source allocations and padded rows use owned values. Padding
    // is excluded from the key and remains untouched when copying output.
    auto replacement = source;
    changed = placements(replacement.data()); pixels = backdrop;
    assert(cache.prepare_tiles(changed.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    std::vector<uint8_t> padded_source(24, 9), padded_output(24, 44);
    for (int y = 0; y < 2; ++y) {
        std::memcpy(padded_source.data() + y * 12, source.data() + y * 8, 8);
        std::memcpy(padded_output.data() + y * 12, backdrop.data() + y * 8, 8);
    }
    changed = placements(padded_source.data());
    for (auto& image : changed) image.pitch = 12;
    assert(cache.prepare_tiles(changed.data(), 2, 2, 2, 12, true, padded_output.data()).hit);
    for (int y = 0; y < 2; ++y) for (int x = 0; x < 12; ++x)
        assert(padded_output[y * 12 + x] == (x < 8 ? 123 : 44));
    changed[1].pixels = replacement.data();
    assert(!cache.prepare_tiles(changed.data(), 2, 2, 2, 8, true, pixels.data()).pending);

    // Planar inputs retain every chroma byte and each placement's profile.
    for (int flags : {0, 1, 4, 4 | 8, 4 | 16, 4 | 8 | VOX_GRAPHITE_IMAGE_YUV422}) {
        std::vector<uint8_t> bytes(36, 50);
        auto group = placements(bytes.data());
        for (auto& image : group) {
            image.width = image.height = 3; image.pitch = 12; image.flags = flags;
            image.has_color_profile = 1;
            for (int p = 0; p < 10; ++p) image.color_profile[p] = .1f * p;
        }
        pixels = backdrop;
        auto pending = cache.prepare_tiles(group.data(), 2, 2, 2, 8, false, pixels.data());
        assert(!pending.hit && pending.pending);
        cache.finish(std::move(pending), pixels.data(), 8);
        assert(cache.prepare_tiles(group.data(), 2, 2, 2, 8, false, pixels.data()).hit);
        size_t last = flags & 4 ? (flags & 16 ? 26 : flags & VOX_GRAPHITE_IMAGE_YUV422 ? 20 : 16) : 35;
        bytes[last]++;
        assert(!cache.prepare_tiles(group.data(), 2, 2, 2, 8, false, pixels.data()).hit);
        bytes[last]--;
        for (int placement = 0; placement < 2; ++placement) for (int p = 0; p < 10; ++p) {
            auto modified = group;
            modified[placement].color_profile[p] += .01f;
            assert(!cache.prepare_tiles(modified.data(), 2, 2, 2, 8, false, pixels.data()).hit);
        }
    }
    // The descriptor vector is part of the memory cap; failed requests and
    // clearing must not publish an entry. Single-image and batch keys differ.
    constexpr size_t cost = 2 * sizeof(VoxGraphiteImage) + 48;
    VoxGraphiteRasterCache small(cost, 1), tiny(cost - 1), disabled(cost, 0);
    pixels = backdrop;
    assert(small.prepare_tiles(images.data(), 2, 2, 2, 8, true, pixels.data()).pending);
    assert(!tiny.prepare_tiles(images.data(), 2, 2, 2, 8, true, pixels.data()).pending);
    assert(!disabled.prepare_tiles(images.data(), 2, 2, 2, 8, true, pixels.data()).pending);
    assert(!cache.prepare_tiles(nullptr, 2, 2, 2, 8, true, pixels.data()).pending);
    assert(!cache.prepare_tiles(images.data(), 0, 2, 2, 8, true, pixels.data()).pending);
    assert(!cache.prepare_tiles(images.data(), std::numeric_limits<int>::max(), 2, 2, 8, true, pixels.data()).pending);
    assert(!cache.prepare_tiles(images.data(), 2, 2, 2, 7, true, pixels.data()).pending);
    assert(!cache.prepare_tiles(images.data(), 2, 2, 2, 8, true, nullptr).pending);
    pixels = backdrop;
    assert(!cache.prepare(images[0], 2, 2, 8, true, pixels.data()).hit);
    images = placements(replacement.data());
    source.clear(); source.shrink_to_fit();
    assert(cache.prepare_tiles(images.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    cache.clear();
    assert(!cache.prepare_tiles(images.data(), 2, 2, 2, 8, true, pixels.data()).hit);
    std::cout << "Image tile cache: " << misses << " parameter/ordering misses, mutable pixels, owned sources, padding and memory limits passed\n";
}
