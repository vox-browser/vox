#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static void check_shadow_bounds(float blur, float outset)
{
    constexpr int width = 1024, height = 828;
    std::vector<uint8_t> pixels(size_t(width) * height * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, space,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(space);
    assert(context);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, width, 768);
    float top = std::min(0.f, 4 - outset), bottom = std::max(64.f, 68 + outset);
    ladybird_v_skia_set_raster_layer(-outset, top, 0);
    ladybird_v_skia_set_raster_layer_size(width + 2 * outset, bottom - top);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 576, 128, 2);
    ladybird_v_skia_set_layer_shared_recording(1);
    assert(ladybird_v_skia_draw_outer_box_shadow(context,
        0, 4, width, 64, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, width, 64, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 0, 0, 1, 0, 0, 0, 60, 0, width, height,
        blur, 0, 0, 0, 20, 0));
    assert(s_shared_root_recording);
    auto const& group = *s_shared_root_recording;
    assert(group.replay_bounds.size() == 1);
    auto expected = SkRect::MakeLTRB(-outset, 64 - outset, width + outset, 128 + outset);
    auto actual = group.replay_bounds.front();
    if (actual != expected) {
        std::cerr << "Recorded shadow blur=" << blur << " bounds=" << actual.left() << ','
            << actual.top() << ',' << actual.right() << ',' << actual.bottom()
            << " expected=" << expected.left() << ',' << expected.top() << ','
            << expected.right() << ',' << expected.bottom() << '\n';
        std::abort();
    }
    // The 20px header blur has a 1084x124 compositor recording. Its visible
    // portion must retain the 576x128 tile grid, not a 1024x148 leaf buffer.
    if (blur == 20) {
        auto bounds = SkRect::MakeXYWH(group.origin_x, group.origin_y + 60,
            group.layer_width, group.layer_height);
        bounds.join(actual);
        assert(bounds == SkRect::MakeXYWH(-30, 34, 1084, 124));
        assert(bounds.intersect(SkRect::MakeWH(width, height)));
        assert(bounds == SkRect::MakeXYWH(0, 34, 1024, 124));
        assert(bounds.top() - group.origin_y - 60 == 0);
        assert(bounds.height() <= group.tile_height);
    }
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    ladybird_v_skia_set_chromium_painting(0);
    CGContextRelease(context);
}

int main()
{
    check_shadow_bounds(20, 30);
    check_shadow_bounds(0, 0);
    check_shadow_bounds(1, 2);
    check_shadow_bounds(16, 24);
    std::cout << "Shadow recordings retain zero, fractional-sigma and header tile extents\n";
}
