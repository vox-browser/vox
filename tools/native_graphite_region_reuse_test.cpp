#include "../native/include/native_graphite_bridge.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <vector>

// Alternate image, small-shape, rounded-part and path draws on one target.
// A saved matrix, clip or old texel must never leak into the next operation.
int main(int argc, char** argv)
{
    assert(argc == 3);
    auto* control = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto* candidate = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(control && candidate);
#define LOAD(handle, name) reinterpret_cast<decltype(&name)>(dlsym(handle, #name))
    auto image_full = LOAD(control, vox_graphite_draw_image_pixels);
    auto image_region = LOAD(candidate, vox_graphite_draw_image_region_pixels);
    auto shape_full = LOAD(control, vox_graphite_draw_shape_pixels);
    auto shape_region = LOAD(candidate, vox_graphite_draw_shape_region_pixels);
    auto shape_parts = LOAD(candidate, vox_graphite_draw_rounded_parts_pixels);
    auto path_full = LOAD(control, vox_graphite_draw_path_pixels);
    auto path_region = LOAD(candidate, vox_graphite_draw_path_region_pixels);
    auto clear = LOAD(candidate, vox_graphite_release_unused_graphics_memory);
    auto finish = LOAD(candidate, vox_graphite_finish_frame);
#undef LOAD
    assert(image_full && image_region && shape_full && shape_region && shape_parts
        && path_full && path_region && clear && finish);
    size_t comparisons = 0;
    for (int pass = 0; pass < 48; ++pass) {
        // Repeated extents share targets; distinct extents exceed the bounded
        // allocation cache. The final extent takes the uncached fallback.
        int width = pass < 6 ? 544 : pass == 47 ? 1100 : 544 + pass;
        int height = pass == 47 ? 1100 : 256;
        for (int op = 0; op < 8; ++op) {
            int x = op % 2 ? 11 : 0, y = op % 3 ? 7 : 0;
            constexpr int w = 160, h = 120, pitch = w * 4 + 13;
            int background = (pass + op) % 2;
            std::vector<uint8_t> actual(1 + pitch * h, 0xa9);
            std::vector<uint8_t> expected(size_t(width) * height * 4);
            for (int row = 0; row < h; ++row) for (int col = 0; col < w; ++col) {
                auto* p = actual.data() + 1 + row * pitch + col * 4;
                p[3] = uint8_t(col * 7 + row * 11 + pass);
                p[0] = p[3] / 2; p[1] = p[3] / 3; p[2] = p[3] / 4;
            }
            for (int row = 0; row < h; ++row)
                std::memcpy(expected.data() + (size_t(y + row) * width + x) * 4,
                    actual.data() + 1 + row * pitch, w * 4);
            VoxGraphitePixelRegion region {x, y, w, h, pitch, actual.data() + 1};
            float matrix[] {op % 2 ? 2.f : 1.f, 0, -.375f + pass * .125f,
                0, op % 2 ? 2.f : 1.f, .25f - op, 0, 0, 1};
            if (op % 4 == 0) {
                std::vector<uint8_t> source(37 * 29 * 4);
                for (size_t i = 0; i < source.size(); i += 4) {
                    source[i] = uint8_t(i + pass); source[i + 1] = uint8_t(i / 7);
                    source[i + 2] = uint8_t(op + i / 3); source[i + 3] = 255;
                }
                VoxGraphiteImage image {};
                std::copy_n(matrix, 9, image.matrix);
                image.width = 37; image.height = 29; image.pitch = 37 * 4;
                image.source[2] = 37; image.source[3] = 29;
                image.destination[2] = 173; image.destination[3] = 113;
                image.clip[0] = 5 + op; image.clip[1] = 3;
                image.clip[2] = 127; image.clip[3] = 91;
                std::fill(image.clip + 4, image.clip + 12, 4.5f);
                image.opacity = .7f; image.pixels = source.data();
                image.flags = pass % 2 ? VOX_GRAPHITE_IMAGE_FORCE_MSAA : 0;
                assert(image_full(expected.data(), width, height, width * 4, background, &image));
                assert(image_region(&region, width, height, background, &image));
            } else if (op % 4 == 3) {
                float segments[] {0, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    1, 130, 17, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    1, 25, 101, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
                VoxGraphitePath path {};
                std::copy_n(matrix, 9, path.matrix);
                path.segments = segments; path.segment_count = 4;
                path.red = 87; path.green = 179; path.blue = uint8_t(pass); path.alpha = 191;
                path.has_clip = 1; path.clip[2] = 97; path.clip[3] = 83;
                std::fill(path.clip + 4, path.clip + 12, 3.f);
                assert(path_full(expected.data(), width, height, width * 4, background, &path));
                assert(path_region(&region, width, height, background, &path));
            } else {
                VoxGraphiteShape shape {};
                std::copy_n(matrix, 9, shape.matrix);
                shape.rect[0] = 17; shape.rect[1] = 13;
                shape.rect[2] = op % 4 == 1 ? 40 : 400;
                shape.rect[3] = op % 4 == 1 ? 12 : 180;
                std::fill(shape.rect + 4, shape.rect + 12, 3.5f);
                shape.fill = 1; shape.anti_alias = 1; shape.force_msaa = pass % 2;
                shape.red = uint8_t(pass); shape.green = 167; shape.blue = 79;
                shape.alpha = op % 4 == 1 ? 197 : 255;
                assert(shape_full(expected.data(), width, height, width * 4, background, &shape));
                assert(op % 4 == 1 ? shape_region(&region, width, height, background, &shape)
                    : shape_parts(&region, 1, width, height, background, &shape));
            }
            assert(actual[0] == 0xa9);
            for (int row = 0; row < h; ++row) {
                if (std::memcmp(actual.data() + 1 + row * pitch,
                        expected.data() + (size_t(y + row) * width + x) * 4, w * 4)) {
                    std::fprintf(stderr, "Reuse mismatch pass=%d op=%d extent=%dx%d\n", pass, op, width, height);
                    return 1;
                }
                for (int byte = w * 4; byte < pitch; ++byte)
                    assert(actual[1 + row * pitch + byte] == 0xa9);
            }
            ++comparisons;
            finish();
        }
        if (pass == 5 || pass == 46) clear();
    }
    clear();
    std::printf("Graphite shared targets: %zu exact mixed-operation GPU comparisons passed\n", comparisons);
}
