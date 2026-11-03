#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>
#include <cstring>

static VoxGraphiteShape global_shape(int density)
{
    VoxGraphiteShape shape{};
    shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
    shape.matrix[2] = -144 * density;
    shape.matrix[5] = -568 * density;
    shape.rect[0] = 971.5f * density;
    shape.rect[1] = 702.5f * density;
    shape.rect[2] = shape.rect[3] = 31 * density;
    for (int i = 4; i < 12; ++i) shape.rect[i] = 15.5f * density;
    std::copy_n(shape.rect, 12, shape.underlay_rect);
    shape.thickness = density;
    shape.red = shape.underlay_rgba[0] = 53;
    shape.green = shape.underlay_rgba[1] = 102;
    shape.blue = shape.underlay_rgba[2] = 240;
    shape.alpha = shape.underlay_rgba[3] = 255;
    shape.has_underlay = shape.anti_alias = shape.force_msaa = 1;
    return shape;
}

static bool picture_space_pixels(int density, bool unprojected_control)
{
    auto actual = global_shape(density), expected = actual;
    // Independent local representation from Chromium's fixed-picture paint
    // offset, before its tile translation. Both matrices reach the same device
    // position; keeping the large global curve can change GPU edge rounding.
    expected.rect[0] = expected.underlay_rect[0] = 711.5f * density;
    expected.rect[1] = expected.underlay_rect[1] = 22.5f * density;
    expected.matrix[2] = 116 * density;
    expected.matrix[5] = 112 * density;
    ladybird_v_skia_set_paint_origin(260, 680, 1);
    if (!unprojected_control)
        assert(apply_chromium_paint_origin(actual, 1.f / density, 0, 0, 1.f / density, 0, 0));
    const int width = 1024 * density, height = 208 * density;
    std::vector<uint8_t> a(size_t(width) * height * 4), b(a.size());
    auto draw = graphite_shape_draw(); assert(draw);
    assert(draw(a.data(), width, height, width * 4, 0, &actual));
    assert(draw(b.data(), width, height, width * 4, 0, &expected));
    if (a != b) {
        unsigned count = 0;
        for (size_t i = 0; i < a.size(); i += 4)
            if (!std::equal(a.begin() + i, a.begin() + i + 4, b.begin() + i)) ++count;
        std::fprintf(stderr, "Opacity picture-space mismatch density=%d pixels=%u\n", density, count);
        return false;
    }
    return true;
}

static void eligibility_and_reset()
{
    auto original = global_shape(2), shape = original;
    ladybird_v_skia_set_paint_origin(260, 680, 0);
    assert(!apply_chromium_paint_origin(shape, .5, 0, 0, .5, 0, 0));
    ladybird_v_skia_set_paint_origin(260, 680, 1);
    for (auto matrix : {std::array<float, 6>{.5, .1, 0, .5, 0, 0},
             std::array<float, 6>{.5, 0, 0, 1, 0, 0},
             std::array<float, 6>{.5, 0, 0, .5, 1, 0}}) {
        assert(!apply_chromium_paint_origin(shape, matrix[0], matrix[1], matrix[2],
            matrix[3], matrix[4], matrix[5]));
        assert(shape.rect[0] == original.rect[0] && shape.matrix[2] == original.matrix[2]);
    }
    shape.clip_out_count = 1;
    assert(!apply_chromium_paint_origin(shape, .5, 0, 0, .5, 0, 0));
    shape = original;
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    assert(!apply_chromium_paint_origin(shape, .5, 0, 0, .5, 0, 0));
    ladybird_v_skia_set_paint_origin(INFINITY, 0, 1);
    assert(!apply_chromium_paint_origin(shape, .5, 0, 0, .5, 0, 0));
}

int main(int argc, char** argv)
{
    bool control = argc == 2 && !std::strcmp(argv[1], "--unprojected-control");
    eligibility_and_reset();
    for (int density : {1, 2}) if (!picture_space_pixels(density, control)) return 1;
    std::puts("Opacity paint offsets preserve both density grids; unsupported spaces and reset pass");
}
