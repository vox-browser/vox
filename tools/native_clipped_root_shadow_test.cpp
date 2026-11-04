#define VOX_TEST_CLIPPED_ROOT_SHADOWS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

// A strip or damage repaint clips a large root shadow to a few rows. Its
// document-anchored raster tiles must reproduce exactly the rows of a
// complete replay, and leave every other row of the backdrop untouched.
static constexpr int css_width = 1024, css_height = 768, scale = 2;

static std::vector<uint8_t> backdrop()
{
    int width = css_width * scale, height = css_height * scale;
    std::vector<uint8_t> pixels(size_t(width) * height * 4);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + (size_t(y) * width + x) * 4;
        p[0] = uint8_t(15 + ((x * 3 + y * 5) & 15));
        p[1] = uint8_t(23 + ((x * 7 + y) & 31));
        p[2] = uint8_t(36 + (y & 7));
        p[3] = 255;
    }
    return pixels;
}

static std::vector<uint8_t> draw_card_shadow(float scroll, float strip_top, float strip_height,
    std::vector<SkRect> const& extra = {})
{
    int width = css_width * scale, height = css_height * scale;
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color); assert(context);
    CGContextScaleCTM(context, scale, scale);
    std::vector<CGRect> clips;
    std::vector<float> published;
    if (strip_height > 0) {
        clips.push_back(CGRectMake(0, css_height - strip_top - strip_height, css_width, strip_height));
        published.insert(published.end(), {0, strip_top, float(css_width), strip_height});
    }
    for (auto const& rect : extra) {
        clips.push_back(CGRectMake(rect.left(), css_height - rect.bottom(), rect.width(), rect.height()));
        published.insert(published.end(), {rect.left(), rect.top(), rect.width(), rect.height()});
    }
    if (!clips.empty()) CGContextClipToRects(context, clips.data(), clips.size());
    // A reused frame publishes the same rectangles it clips to.
    ladybird_v_skia_set_scroll_damage_rects(context, published.data(), int(published.size() / 4));
    s_root_raster_scroll_y = scroll;
    // vlang.io-like card: 0 20px 50px #0009 around a 16px rounded box.
    float x = 64.25f, y = 120.5f, w = 896, h = 520;
    assert(ladybird_v_skia_draw_outer_box_shadow(context, x, y + 20, w, h, 16, 16, 16, 16,
        16, 16, 16, 16, x, y, w, h, 16, 16, 16, 16, 16, 16, 16, 16, 1, 0, 0, 1, 0, 0, 0, 0,
        0, css_width, css_height, 50, 0, 0, 0, 153, 1));
    ladybird_v_skia_set_scroll_damage_rects(nullptr, nullptr, 0);
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
}

int main()
{
    assert(graphite_shadow_draw());
    ladybird_v_skia_set_chromium_painting(1);
    s_raster_layer_is_root = true;
    s_raster_layer_height = 4000;
    int const tiles[] {0, 1, 2, 3, 4, 5, 6, 7};
    ladybird_v_skia_set_msaa_grid(tiles, 8, 544, 256, 4);
    int width = css_width * scale, pitch = width * 4;
    auto untouched = backdrop();
    unsigned cases = 0;
    for (float scroll : {0.f, 37.5f, 240.f}) {
        auto full = draw_card_shadow(scroll, 0, 0);
        for (float strip_top : {42.f, 131.5f, 620.f, 700.f, 740.f}) {
            float strip_height = 20;
            auto before = s_test_clipped_root_shadows;
            auto strip = draw_card_shadow(scroll, strip_top, strip_height);
            assert(s_test_clipped_root_shadows == before + 1);
            int first = int(strip_top * scale), last = int((strip_top + strip_height) * scale);
            for (int y = 0; y < css_height * scale; ++y) {
                auto const& expected = y >= first && y < last ? full : untouched;
                if (!std::equal(strip.begin() + size_t(y) * pitch, strip.begin() + size_t(y + 1) * pitch,
                        expected.begin() + size_t(y) * pitch)) {
                    std::cerr << "Clipped shadow row differs: scroll=" << scroll
                        << " strip=" << strip_top << " row=" << y << '\n';
                    return 1;
                }
            }
            ++cases;
        }
    }
    // A damage rectangle far from the shadow widens Quartz's clip bounds to
    // the whole viewport; the published rectangles keep the crop to the strip.
    auto full = draw_card_shadow(0, 0, 0);
    auto far = SkRect::MakeXYWH(1000, 4, 20, 20);
    auto before = s_test_clipped_root_shadows;
    auto split = draw_card_shadow(0, 700, 20, {far});
    assert(s_test_clipped_root_shadows == before + 1);
    for (int y = 0; y < css_height * scale; ++y) {
        bool strip_row = y >= 1400 && y < 1440;
        for (int x = 0; x < css_width * scale; ++x) {
            bool in_far = x >= 2000 && y >= 8 && y < 48;
            auto const& expected = strip_row || in_far ? full : untouched;
            for (int c = 0; c < 4; ++c) {
                size_t at = (size_t(y) * width + x) * 4 + c;
                if (split[at] != expected[at]) {
                    std::cerr << "Split clip differs at " << x << "," << y << '\n';
                    return 1;
                }
            }
        }
    }
    ++cases;
    // An independent composited layer rasterizes the whole shadow region on a
    // transparent target; its crops keep that target and transfer one strip.
    s_raster_layer_is_root = false;
    s_raster_origin_x = 16;
    s_raster_origin_y = 96;
    for (float scroll : {0.f, 37.5f}) {
        auto full = draw_card_shadow(scroll, 0, 0);
        for (float strip_top : {42.f, 620.f, 740.f}) {
            auto before = s_test_clipped_layer_shadows;
            auto strip = draw_card_shadow(scroll, strip_top, 20);
            assert(s_test_clipped_layer_shadows == before + 1);
            int first = int(strip_top * scale), last = int((strip_top + 20) * scale);
            for (int y = 0; y < css_height * scale; ++y) {
                auto const& expected = y >= first && y < last ? full : untouched;
                if (!std::equal(strip.begin() + size_t(y) * pitch, strip.begin() + size_t(y + 1) * pitch,
                        expected.begin() + size_t(y) * pitch)) {
                    std::cerr << "Clipped layer shadow row differs: scroll=" << scroll
                        << " strip=" << strip_top << " row=" << y << '\n';
                    return 1;
                }
            }
            ++cases;
        }
    }
    // Damage rectangles describe the canvas they were published for; an
    // offscreen layer has no clip of its own and is never cropped by them.
    {
        auto pixels = backdrop();
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(pixels.data(), width, css_height * scale, 8, pitch, color,
            static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
                | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
        CGColorSpaceRelease(color);
        CGContextScaleCTM(context, scale, scale);
        float published[] {0, 700, float(css_width), 20};
        ladybird_v_skia_set_scroll_damage_rects(context, published, 1);
        auto offscreen = CGBitmapContextCreate(nullptr, width, css_height * scale, 8, pitch,
            CGBitmapContextGetColorSpace(context), CGBitmapContextGetBitmapInfo(context));
        CGContextScaleCTM(offscreen, scale, scale);
        RasterRegion region {64, 100, 960, 700}, visible;
        assert(visible_raster_region(context, css_height, region, visible));
        assert(visible.top >= 698 && visible.bottom <= 700);
        assert(!visible_raster_region(offscreen, css_height, region, visible));
        ladybird_v_skia_set_scroll_damage_rects(nullptr, nullptr, 0);
        CGContextRelease(offscreen);
        CGContextRelease(context);
        ++cases;
    }
    std::cout << cases << " clipped root and layer shadow strips match complete replays exactly\n";
}
