#include "../native/include/native_graphite_solid_rect.h"
#include <cassert>
#include <iostream>
#include <limits>
#include <vector>

int main()
{
    VoxGraphiteShape shape {};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.rect[0] = shape.rect[1] = 1;
    shape.rect[2] = shape.rect[3] = 2;
    shape.fill = shape.anti_alias = shape.force_msaa = 1;
    shape.red = 22; shape.green = 33; shape.blue = 44; shape.alpha = 255;
    // Exercise unaligned storage and row padding as well as existing backdrop.
    std::vector<uint8_t> storage(1 + 19 * 4, 89);
    auto* pixels = storage.data() + 1;
    assert(vox_draw_solid_rect(pixels, 4, 4, 19, true, shape));
    assert(storage[0] == 89);
    for (int y = 0; y < 4; ++y) for (int x = 0; x < 19; ++x) {
        bool interior = (y == 1 || y == 2) && x >= 4 && x < 12;
        uint8_t colors[] {44, 33, 22, 255};
        assert(pixels[y * 19 + x] == (interior ? colors[x % 4] : 89));
    }
    assert(vox_draw_solid_rect(pixels, 4, 4, 19, false, shape));
    for (int y = 0; y < 4; ++y) for (int x = 0; x < 19; ++x) {
        bool interior = (y == 1 || y == 2) && x >= 4 && x < 12;
        uint8_t colors[] {44, 33, 22, 255};
        assert(pixels[y * 19 + x] == (x >= 16 ? 89 : interior ? colors[x % 4] : 0));
    }
    auto before = storage;
    auto rejected = [&](VoxGraphiteShape const& value) {
        assert(!vox_draw_solid_rect(pixels, 4, 4, 19, true, value));
        assert(storage == before);
    };
    auto value = shape; value.alpha = 254; rejected(value);
    value = shape; value.fill = 0; rejected(value);
    value = shape; value.has_underlay = 1; rejected(value);
    value = shape; value.clip_out_count = 1; rejected(value);
    value = shape; value.rect[2] = 0; rejected(value);
    for (int i = 4; i < 12; ++i) { value = shape; value.rect[i] = .5f; rejected(value); }
    for (int i : {1, 3, 6, 7}) { value = shape; value.matrix[i] = .25f; rejected(value); }
    for (int i : {0, 4, 8}) { value = shape; value.matrix[i] = -1; rejected(value); }
    value = shape; value.matrix[2] = .5f; rejected(value);
    value = shape; value.rect[1] = 0;
    value.matrix[5] = std::nextafter(1.0f, 0.0f); rejected(value);
    value = shape; value.rect[0] = std::numeric_limits<float>::infinity(); rejected(value);
    value = shape; value.rect[1] = std::numeric_limits<float>::quiet_NaN(); rejected(value);
    assert(!vox_draw_solid_rect(nullptr, 4, 4, 19, true, shape));
    assert(!vox_draw_solid_rect(pixels, 4, 4, 15, true, shape));
    assert(!vox_draw_solid_rect(pixels, 0, 4, 19, true, shape));
    // Retina half-CSS-pixel edges become complete device pixels.
    shape.matrix[0] = shape.matrix[4] = 2;
    shape.rect[0] = shape.rect[1] = -.5f;
    shape.rect[2] = shape.rect[3] = 1;
    assert(vox_draw_solid_rect(pixels, 4, 4, 19, false, shape));
    assert(pixels[0] == 44 && pixels[3] == 255 && pixels[4] == 0 && pixels[19] == 0);
    shape.matrix[0] = shape.matrix[4] = 1;
    shape.rect[0] = shape.rect[1] = .5f;
    shape.rect[2] = shape.rect[3] = 3;
    shape.fill = 0; shape.thickness = 1;
    assert(vox_draw_solid_stroke(pixels, 4, 4, 19, false, shape));
    for (int y = 0; y < 4; ++y) for (int x = 0; x < 4; ++x) {
        bool border = x == 0 || y == 0 || x == 3 || y == 3;
        assert(pixels[y * 19 + x * 4 + 3] == (border ? 255 : 0));
    }
    auto stroke_rejected = [&](VoxGraphiteShape const& candidate) {
        std::fill(storage.begin(), storage.end(), 91);
        auto original = storage;
        assert(!vox_draw_solid_stroke(pixels, 4, 4, 19, false, candidate));
        assert(storage == original);
    };
    value = shape; value.thickness = .5f; stroke_rejected(value);
    value = shape; value.thickness = 0; stroke_rejected(value);
    value = shape; value.rect[0] = 1; stroke_rejected(value);
    value = shape; value.rect[4] = 1; stroke_rejected(value);
    value = shape; value.alpha = 128; stroke_rejected(value);
    value = shape; value.has_underlay = 1; stroke_rejected(value);
    value = shape; value.rect[2] = .5f; stroke_rejected(value);
    value = shape; value.rect[0] = std::numeric_limits<float>::infinity(); stroke_rejected(value);
    std::cout << "Solid rectangle: exact coverage, backdrop, padding, clipping and fallback guards passed\n";
}
