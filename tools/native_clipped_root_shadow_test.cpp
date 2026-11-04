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

static std::vector<uint8_t> draw_card_shadow(float scroll, float strip_top, float strip_height)
{
    int width = css_width * scale, height = css_height * scale;
    auto pixels = backdrop();
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color); assert(context);
    CGContextScaleCTM(context, scale, scale);
    if (strip_height > 0)
        CGContextClipToRect(context, CGRectMake(0, css_height - strip_top - strip_height,
            css_width, strip_height));
    s_root_raster_scroll_y = scroll;
    // vlang.io-like card: 0 20px 50px #0009 around a 16px rounded box.
    float x = 64.25f, y = 120.5f, w = 896, h = 520;
    assert(ladybird_v_skia_draw_outer_box_shadow(context, x, y + 20, w, h, 16, 16, 16, 16,
        16, 16, 16, 16, x, y, w, h, 16, 16, 16, 16, 16, 16, 16, 16, 1, 0, 0, 1, 0, 0, 0, 0,
        0, css_width, css_height, 50, 0, 0, 0, 153, 1));
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
    std::cout << cases << " clipped root shadow strips match complete replays exactly\n";
}
