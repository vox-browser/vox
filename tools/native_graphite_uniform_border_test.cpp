#include "../native_graphite_solid_rect.h"
#include <cassert>
#include <cstdio>
#include <dlfcn.h>
#include <limits>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 2);
    auto library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL); assert(library);
    auto reference = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(library, "vox_graphite_draw_shape_pixels")); assert(reference);
    constexpr int width = 128, height = 96, pitch = width * 4 + 16;
    unsigned accepted = 0, rejected = 0;
    for (int mode : {0,6}) for (int scale : {1,2}) for (bool background : {false,true})
    for (bool antialias : {false,true}) for (bool msaa : {false,true})
    for (bool floating : {false,true}) for (float phase : {0.f,.5f})
    for (float border : {1.f,2.f,3.f,4.f}) for (float x : {-3.5f,10.f,20.f,100.5f}) {
        VoxGraphiteShape shape{};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        shape.rect[0] = x + phase; shape.rect[1] = 9 + phase;
        shape.rect[2] = 24; shape.rect[3] = 28;
        shape.fill = mode; shape.border_widths[0] = border; shape.thickness = border;
        shape.red = 22; shape.green = 83; shape.blue = 147; shape.alpha = 255;
        shape.has_float_color = floating;
        shape.float_color[0] = shape.red / 255.f;
        shape.float_color[1] = shape.green / 255.f;
        shape.float_color[2] = shape.blue / 255.f; shape.float_color[3] = 1;
        shape.anti_alias = antialias; shape.force_msaa = msaa;
        std::vector<uint8_t> input(1 + size_t(pitch) * height, 0xa5);
        for (int y = 0; y < height; ++y) for (int col = 0; col < width; ++col) {
            auto* pixel = input.data() + 1 + size_t(y) * pitch + col * 4;
            pixel[0] = (col * 7 + y * 3) % 128;
            pixel[1] = (col * 3 + y * 5) % 128;
            pixel[2] = (col * 2 + y * 11) % 128;
            pixel[3] = 128 + (col + y) % 128;
        }
        auto actual = input;
        bool resolved = vox_draw_solid_uniform_border(actual.data() + 1, width, height,
            pitch, background, shape);
        if (!resolved) { assert(actual == input); ++rejected; continue; }
        auto expected = input;
        // Mode 6 reaches the independent GPU ring renderer even when the
        // original mode-0 API can already resolve a stroke in software.
        auto gpu_shape = shape; gpu_shape.fill = 6;
        assert(reference(expected.data() + 1, width, height, pitch, background, &gpu_shape));
        if (actual != expected) {
            std::fprintf(stderr, "Mismatch scale=%d background=%d aa=%d msaa=%d float=%d phase=%g border=%g x=%g\n",
                scale, background, antialias, msaa, floating, phase, border, x);
            return 1;
        }
        ++accepted;
    }
    assert(accepted == 1280 && rejected == 768);
    VoxGraphiteShape good{};
    good.matrix[0] = good.matrix[4] = good.matrix[8] = 1;
    good.rect[0] = good.rect[1] = 10.5f; good.rect[2] = good.rect[3] = 20;
    good.fill = 6; good.border_widths[0] = 1; good.alpha = 255;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 71);
    auto rejects = [&](VoxGraphiteShape const& shape) {
        auto before = pixels;
        assert(!vox_draw_solid_uniform_border(pixels.data(), width, height, pitch, true, shape));
        assert(pixels == before);
    };
    auto value = good; value.fill = 7; rejects(value);
    value = good; value.has_underlay = 1; rejects(value);
    value = good; value.clip_out_count = 1; rejects(value);
    value = good; value.alpha = 254; rejects(value);
    value = good; value.rect[0] += .125f; rejects(value);
    value = good; value.matrix[0] = 3; rejects(value);
    value = good; value.matrix[2] = 2097152; rejects(value);
    value = good; value.border_widths[0] = .25f; rejects(value);
    value = good; value.border_widths[0] = 0; rejects(value);
    value = good; value.border_widths[0] = 30; rejects(value);
    value = good; value.has_float_color = 1; value.float_color[3] = .99f; rejects(value);
    value = good; value.rect[0] = std::numeric_limits<float>::infinity(); rejects(value);
    for (int i = 4; i < 12; ++i) { value = good; value.rect[i] = .5f; rejects(value); }
    std::printf("PASS %u exact GPU uniform-border comparisons, %u alignment fallbacks and invalid-input guards\n", accepted, rejected);
}
