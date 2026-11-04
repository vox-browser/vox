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

static void check_clipped_shadow_bounds(int scale, bool rounded, float offset)
{
    constexpr int width = 128, height = 96;
    int pw = width * scale, ph = height * scale;
    std::vector<uint8_t> pixels(size_t(pw) * ph * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), pw, ph, 8, pw * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, width, height);
    ladybird_v_skia_set_raster_layer(12, 8, 0);
    ladybird_v_skia_set_raster_layer_size(100, 80);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 128 * scale, 64 * scale, 1);
    ladybird_v_skia_set_layer_shared_recording(1);
    float clip[] {12 + offset, 8, 100, 80, 0, 0, 0, 0, 0, 0, 0, 0};
    if (rounded) std::fill(clip + 4, clip + 12, 8);
    float transform[] {1, 0, 0, 1, 0, 0};
    ladybird_v_skia_add_shared_rounded_clip(context, clip, transform);
    assert(ladybird_v_skia_draw_outer_box_shadow(context,
        12, 12, 100, 64, 8, 8, 8, 8, 8, 8, 8, 8,
        12, 8, 100, 64, 8, 8, 8, 8, 8, 8, 8, 8,
        1, 0, 0, 1, 0, 0, 0, 0, 0, width, height,
        16, 0, 0, 0, 13, 0));
    assert(s_shared_root_recording && s_shared_root_recording->replay_bounds.size() == 1);
    bool aligned = !rounded && offset * scale == std::floor(offset * scale);
    auto expected = aligned ? SkRect::MakeXYWH(12 + offset, 8, 100, 80)
        : SkRect::MakeLTRB(-12, -12, 136, 100);
    auto actual = s_shared_root_recording->replay_bounds.front();
    if (actual != expected) {
        std::fprintf(stderr, "clipped shadow bounds differ scale=%d rounded=%d offset=%g: "
            "actual=%g,%g,%g,%g expected=%g,%g,%g,%g\n", scale, rounded, offset,
            actual.left(), actual.top(), actual.right(), actual.bottom(),
            expected.left(), expected.top(), expected.right(), expected.bottom());
        std::exit(1);
    }
    // Aligned clipping removes only invisible overflow. The logical layer
    // remains the tile anchor, instead of expanding to the blur's scratch box.
    if (aligned && offset == 0) {
        auto const& group = *s_shared_root_recording;
        assert(actual == SkRect::MakeXYWH(group.origin_x, group.origin_y,
            group.layer_width, group.layer_height));
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
    for (int scale : {1, 2}) for (bool rounded : {false, true})
        for (float offset : {0.f, .5f}) check_clipped_shadow_bounds(scale, rounded, offset);
    std::cout << "Shadow recordings retain unclipped ink and aligned clip tile extents\n";
}
