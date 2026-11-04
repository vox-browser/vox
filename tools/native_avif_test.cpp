#include "../native_avif.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

static std::vector<uint8_t> read(std::string const& name) {
    std::ifstream file(name, std::ios::binary);
    assert(file);
    return {std::istreambuf_iterator<char>(file), {}};
}

int main(int argc, char** argv) {
    assert(argc == 2 && vox_avif_available());
    std::string directory = argv[1];
    int cases = 0;
    for (auto name : {"slate-hero.jpeg", "slate-card.jpeg", "red.avif", "alpha.avif"}) {
        auto bytes = read(directory + "/" + name);
        assert(vox_avif_is_avif(bytes.data(), bytes.size()));
        int w = std::string(name) == "slate-hero.jpeg" ? 585 : std::string(name) == "slate-card.jpeg" ? 390 : 32;
        int h = std::string(name) == "slate-hero.jpeg" ? 390 : std::string(name) == "slate-card.jpeg" ? 260 : std::string(name) == "red.avif" ? 24 : 16;
        for (int premultiply : {0, 1}) {
            int32_t width = -1, height = -1, pitch = -1;
            auto* pixels = vox_avif_decode_rgba(bytes.data(), bytes.size(), premultiply, &width, &height, &pitch);
            assert(pixels && width == w && height == h && pitch == w * 4);
            for (int y = 0; y < h; ++y) for (int x = 0; x < w; ++x) {
                auto* p = pixels + y * pitch + x * 4;
                if (std::string(name) == "alpha.avif") {
                    uint8_t alpha[] {0, 64, 128, 255};
                    assert(p[3] == alpha[x / 8]);
                    if (premultiply) for (int c = 0; c < 3; ++c) assert(p[c] <= p[3]);
                    else assert(p[2] > p[1] && p[1] > p[0]);
                } else {
                    assert(p[3] == 255);
                    if (std::string(name) == "red.avif") assert(p[0] >= 253 && p[1] <= 2 && p[2] <= 2);
                }
            }
            vox_avif_release(pixels);
            ++cases;
        }
    }
    for (auto name : {"animated.avif", "oversize.avif", "icc.avif"}) {
        auto bytes = read(directory + "/" + name);
        int32_t width = -1, height = -1, pitch = -1;
        assert(!vox_avif_decode_rgba(bytes.data(), bytes.size(), 0, &width, &height, &pitch));
        assert(width == 0 && height == 0 && pitch == 0);
        ++cases;
    }
    auto bytes = read(directory + "/red.avif");
    for (size_t length : {size_t(0), size_t(1), size_t(12), size_t(20), bytes.size() / 2}) {
        int32_t width = -1, height = -1, pitch = -1;
        assert(!vox_avif_decode_rgba(bytes.data(), length, 0, &width, &height, &pitch));
        assert(width == 0 && height == 0 && pitch == 0);
        ++cases;
    }
    int32_t width = -1, height = -1, pitch = -1;
    assert(!vox_avif_decode_rgba(bytes.data(), bytes.size(), 0, nullptr, &height, &pitch));
    assert(height == 0 && pitch == 0);
    assert(!vox_avif_decode_rgba(nullptr, bytes.size(), 0, &width, &height, &pitch));
    assert(!vox_avif_decode_rgba(bytes.data(), UINT64_MAX, 0, &width, &height, &pitch));
    vox_avif_release(nullptr);
    std::printf("AVIF: %d decoding/alpha/format/limit controls passed\n", cases + 3);
}
