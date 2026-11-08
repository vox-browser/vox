#include "../native/include/native_rgba_alpha_bounds.h"
#include <cassert>
#include <iostream>
#include <vector>

int main()
{
    unsigned cases = 0, random = 8173;
    for (int width : {1, 2, 3, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129, 1024})
    for (int height : {1, 2, 3, 15, 17, 64}) for (int padding : {0, 1, 7, 16})
    for (int pattern = 0; pattern < 12; ++pattern) {
        size_t pitch = size_t(width) * 4 + padding;
        std::vector<uint8_t> storage(pitch * height + 2, 0xa7);
        auto* pixels = storage.data() + 1;
        VoxRGBAAlphaBounds reference {width, height, 0, 0};
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
            random ^= random << 13; random ^= random >> 17; random ^= random << 5;
            bool ink = pattern == 0 || (pattern == 2 && x == width - 1)
                || (pattern == 3 && x == 0) || (pattern == 4 && y == height - 1)
                || (pattern == 5 && y == 0) || (pattern == 6 && x == width / 2 && y == height / 2)
                || (pattern >= 7 && random % (1u << (pattern - 6)) == 0);
            auto* p = pixels + size_t(y) * pitch + x * 4;
            p[0] = random; p[1] = random >> 8; p[2] = random >> 16; p[3] = ink ? 1 + random % 255 : 0;
            if (ink) {
                reference.left = std::min(reference.left, x); reference.right = std::max(reference.right, x + 1);
                reference.top = std::min(reference.top, y); reference.bottom = y + 1;
            }
        }
        if (reference.empty()) reference = {};
        auto actual = vox_rgba_alpha_bounds(pixels, width, height, pitch);
        assert(!std::memcmp(&actual, &reference, sizeof(actual))); ++cases;
    }
    assert(vox_rgba_alpha_bounds(nullptr, 16, 16, 64).empty());
    std::cout << cases << " exact alpha bounds with sparse/dense rows, unaligned pixels and padding\n";
}
