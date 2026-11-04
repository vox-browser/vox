#define VOX_TEST_CLIPPED_DECORATION_GROUPS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

// A strip or damage repaint of a decoration group (shadow, rounded fill and
// border batched through the document-anchored root grid) covers only the
// clipped rows. They must equal those of a complete replay, and every other
// row keeps its original backdrop.
static constexpr int css_width = 512, css_height = 384, scale = 2;

static std::vector<uint8_t> backdrop()
{
    int width = css_width * scale, height = css_height * scale;
    std::vector<uint8_t> pixels(size_t(width) * height * 4);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + (size_t(y) * width + x) * 4;
        p[0] = uint8_t(17 + ((x * 3 + y * 5) & 15)); p[1] = uint8_t(29 + (y & 31));
        p[2] = 43; p[3] = 255;
    }
    return pixels;
}

static std::vector<uint8_t> draw_group(float scroll, bool deferred, std::vector<SkRect> const& strips)
{
    int width = css_width * scale, height = css_height * scale;
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(context);
    CGContextScaleCTM(context, scale, scale);
    std::vector<CGRect> clips;
    std::vector<float> published;
    for (auto const& rect : strips) {
        clips.push_back(CGRectMake(rect.left(), css_height - rect.bottom(), rect.width(), rect.height()));
        published.insert(published.end(), {rect.left(), rect.top(), rect.width(), rect.height()});
    }
    if (!clips.empty()) CGContextClipToRects(context, clips.data(), clips.size());
    ladybird_v_skia_set_scroll_damage_rects(context, published.data(), int(published.size() / 4));
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, css_width, css_height);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(css_width, 2048);
    ladybird_v_skia_set_root_raster_scroll_y(scroll);
    int cells[] {0, 1, 2, 3, 4, 5, 6, 7};
    ladybird_v_skia_set_msaa_grid(cells, 0, width, 256, 1);
    unsetenv("VOX_DISABLE_INSET_DECORATION_BOUNDS");
    unsetenv("VOX_DISABLE_INSET_PICTURE_REGIONS");
    setenv("VOX_DISABLE_INSET_PICTURE_BATCH", "0", 1);
    auto begin = deferred ? ladybird_v_skia_begin_deferred_inset_decorations
        : ladybird_v_skia_begin_inset_decorations;
    float x = 40.25f, y = 60.5f, w = 400, h = 260;
    assert(begin(context, x - 60, y - 40, w + 120, h + 120, css_width, css_height, 0, 0));
    // vlang.io-like card: 0 20px 50px #0009 shadow, rounded fill and border.
    assert(ladybird_v_skia_draw_outer_box_shadow(context, x, y + 20, w, h, 13, 13, 13, 13,
        13, 13, 13, 13, x, y, w, h, 13, 13, 13, 13, 13, 13, 13, 13, 1, 0, 0, 1, 0, -scroll,
        0, 0, 0, css_width, css_height, 50, 0, 0, 0, 153, 1));
    for (int fill : {1, 0})
        assert(ladybird_v_skia_draw_rounded_rect(context, x, y, w, h, 13, 13, 13, 13, 13, 13,
            13, 13, 1, 0, 0, 1, 0, -scroll, 0, 0, 0, css_width, css_height,
            fill ? 16 : 52, fill ? 23 : 65, fill ? 34 : 81, 255, fill, 1, 1, 1));
    assert(ladybird_v_skia_end_deferred_inset_decorations(context));
    ladybird_v_skia_set_scroll_damage_rects(nullptr, nullptr, 0);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
}

int main()
{
    int pitch = css_width * scale * 4;
    auto untouched = backdrop();
    unsigned cases = 0;
    for (bool deferred : {false, true}) for (float scroll : {0.f, 37.5f, 120.f}) {
        auto full = draw_group(scroll, deferred, {});
        for (float strip_top : {30.f, 131.5f, 300.f, 364.f}) {
            auto strip_rect = SkRect::MakeXYWH(0, strip_top, css_width, 20);
            auto before = s_test_clipped_decoration_groups;
            auto strip = draw_group(scroll, deferred, {strip_rect});
            assert(s_test_clipped_decoration_groups == before + 1);
            int first = int(strip_top * scale), last = int((strip_top + 20) * scale);
            for (int row = 0; row < css_height * scale; ++row) {
                auto const& expected = row >= first && row < last ? full : untouched;
                if (!std::equal(strip.begin() + size_t(row) * pitch, strip.begin() + size_t(row + 1) * pitch,
                        expected.begin() + size_t(row) * pitch)) {
                    std::cerr << "Clipped decoration group row differs: deferred=" << deferred
                        << " scroll=" << scroll << " strip=" << strip_top << " row=" << row << '\n';
                    return 1;
                }
            }
            ++cases;
        }
    }
    std::cout << cases << " clipped decoration group strips match complete replays exactly\n";
}
