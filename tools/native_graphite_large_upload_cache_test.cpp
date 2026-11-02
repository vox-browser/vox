#include "../native_graphite_image_upload_cache.h"
#include <cassert>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <memory>

int main(int argc, char** argv)
{
    if (argc == 3 && !std::strcmp(argv[1], "--policy")) {
        assert(vox_compressed_image_uploads_enabled() == (argv[2][0] == '1'));
        return 0;
    }
    assert(argc == 1);
    setenv("VOX_ENABLE_COMPRESSED_IMAGE_UPLOADS", "1", 1);
    unsetenv("VOX_DISABLE_COMPRESSED_IMAGE_UPLOADS");
    constexpr int width = 2049, height = 1031, pitch = width * 4 + 17;
    std::vector<uint8_t> source(size_t(pitch) * height, 0xA9);
    for (int y = 0; y < height; ++y)
        std::fill_n(source.data() + size_t(y) * pitch, width * 4, uint8_t(y % 7));
    VoxGraphiteImage image {};
    image.width = width; image.height = height; image.pitch = pitch;
    image.pixels = source.data(); image.flags = 1;
    VoxGraphiteImageUploadCache<std::shared_ptr<int>> cache(512 * 1024, 2);
    auto first = cache.prepare(image, 256, 128, false);
    assert(first.pending && !first.texture && !first.needs_mipmaps);
    auto texture = std::make_shared<int>(17);
    source[0]++; // The pending entry must already own its original input.
    cache.finish(std::move(first), texture);
    assert(!cache.prepare(image, 256, 128, false).texture);
    source[0]--;
    assert(cache.prepare(image, 256, 128, false).texture == texture);
    for (size_t at : {size_t(0), size_t(pitch) * (height / 2) + width * 2,
                      size_t(pitch) * (height - 1) + width * 4 - 1}) {
        source[at]++;
        assert(!cache.prepare(image, 256, 128, false).texture);
        source[at]--;
    }
    auto other = source;
    for (int y = 0; y < height; ++y) other[size_t(y) * pitch + width * 4]++;
    image.pixels = other.data();
    assert(cache.prepare(image, 256, 128, false).texture == texture);
    image.pixels = source.data();
    // Newly admitted sources must retain the legacy CPU mip generation. An
    // upload that used to be uncached cannot inherit GPU-generated mip levels.
    auto mips = cache.prepare(image, 256, 128, true);
    assert(!mips.texture && mips.pending && !mips.needs_mipmaps);
    auto mip_texture = std::make_shared<int>(19);
    cache.clear(); // Pending data survives eviction/clear before completion.
    cache.finish(std::move(mips), mip_texture);
    assert(cache.prepare(image, 256, 128, true).texture == mip_texture);
    auto changed = image;
    changed.has_color_profile = 1;
    assert(!cache.prepare(changed, 256, 128, true).texture);
    changed = image; changed.flags = 3;
    assert(!cache.prepare(changed, 256, 128, true).texture);
    // Bounds reject before dereferencing the deliberately tiny source.
    uint8_t tiny[4] {};
    changed = image; changed.pixels = tiny; changed.width = 8193;
    changed.height = 8192; changed.pitch = changed.width * 4;
    assert(!cache.prepare(changed, 256, 128, false).pending);
    {
        // A base upload can fit raw while adding mip storage crosses the
        // preceding admission limit. This new admission also needs CPU mips.
        std::vector<uint8_t> small(256 * 128 * 4, 73);
        auto boundary = image;
        boundary.width = 256; boundary.height = 128; boundary.pitch = 256 * 4;
        boundary.pixels = small.data();
        VoxGraphiteImageUploadCache<std::shared_ptr<int>> edge(300000);
        auto base = edge.prepare(boundary, 256, 128, false);
        assert(base.pending);
        edge.finish(std::move(base), texture);
        auto upgrade = edge.prepare(boundary, 256, 128, true);
        assert(!upgrade.texture && upgrade.pending && !upgrade.needs_mipmaps);
    }
    assert(!cache.prepare(image, 8192, 8192, false).pending);
    assert(!cache.prepare(image, std::numeric_limits<int>::max(), 1, false).pending);
    // Incompressible inputs do not gain a larger retained-byte allowance.
    uint32_t random = 1;
    for (auto& byte : other) {
        random ^= random << 13; random ^= random >> 17; random ^= random << 5;
        byte = uint8_t(random);
    }
    changed = image; changed.pixels = other.data();
    assert(!cache.prepare(changed, 256, 128, false).pending);
    std::cout << "Large upload snapshots: ownership, mutation, padding, mips and bounds passed\n";
}
