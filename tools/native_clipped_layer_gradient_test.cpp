#define VOX_TEST_CLIPPED_GRADIENTS
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

// A strip or damage repaint clips a large CSS radial gradient (vlang.io's
// media scene) to a few rows. Root and independent composited layers keep
// their complete GPU target and dither phase, so the clipped rows must equal
// those of a complete replay, and every other row keeps its backdrop.
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

static void rectangle(std::vector<float>& path, float x, float y, float w, float h)
{
    auto segment = [&](float op, float px, float py) {
        float values[12] {op, px, py};
        path.insert(path.end(), values, values + 12);
    };
    segment(0, x, y);
    segment(1, x + w, y);
    segment(1, x + w, y + h);
    segment(1, x, y + h);
    segment(5, 0, 0);
}

static std::vector<uint8_t> draw_scene(float scroll, std::vector<SkRect> const& damage)
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
    for (auto const& rect : damage) {
        clips.push_back(CGRectMake(rect.left(), css_height - rect.bottom(), rect.width(), rect.height()));
        published.insert(published.end(), {rect.left(), rect.top(), rect.width(), rect.height()});
    }
    if (!clips.empty()) CGContextClipToRects(context, clips.data(), clips.size());
    ladybird_v_skia_set_scroll_damage_rects(context, published.data(), int(published.size() / 4));
    float x = 33, y = 348, w = 958, h = 438;
    std::vector<float> path;
    rectangle(path, x, y, w, h);
    // radial-gradient(ellipse at 80% 80%, #273e5b65, transparent 70%)
    float cx = x + w * 0.8f, cy = y + h * 0.8f, rx = 790, ry = 370, sy = ry / rx;
    float stops[] {0x27 / 255.f, 0x3e / 255.f, 0x5b / 255.f, 0x65 / 255.f, 0,
        0, 0, 0, 0, 0.7f};
    float clip[12] {x, y, w, h, 0, 0, 0, 0, 0, 0, 0, 0};
    float ancestor[12] {x, y, w, h + 2, 13, 13, 13, 13, 0, 0, 0, 0};
    assert(ladybird_v_skia_draw_clipped_svg_radial_gradient_path(context, path.data(),
        int(path.size() / 12), 0, 1, 0, 0, 1, 0, -scroll, 0, 0, 0, css_width, css_height,
        0, 0, 0, 0, 4, cx, cy * sy, 0, cx, cy * sy, rx, 1, 0, 0, sy, 0, 0, 4, 0, stops, 2,
        1, 1, clip, ancestor));
    ladybird_v_skia_set_scroll_damage_rects(nullptr, nullptr, 0);
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
}

int main()
{
    assert(graphite_path_region_draw());
    ladybird_v_skia_set_chromium_painting(1);
    int width = css_width * scale, pitch = width * 4;
    auto untouched = backdrop();
    unsigned cases = 0;
    for (bool root : {true, false}) {
        s_raster_layer_is_root = root;
        s_raster_origin_x = root ? 0 : 16;
        s_raster_origin_y = root ? 0 : 331.5;
        for (float scroll : {0.f, 37.5f, 240.f}) {
            auto full = draw_scene(scroll, {});
            for (float strip_top : {42.f, 131.5f, 620.f, 740.f}) {
                auto strip_rect = SkRect::MakeXYWH(0, strip_top, css_width, 20);
                auto before = s_test_clipped_gradients;
                auto strip = draw_scene(scroll, {strip_rect});
                bool touches = strip_top + 20 > 348 - scroll && strip_top < 786 - scroll;
                assert(s_test_clipped_gradients == before + (touches ? 1 : 0));
                int first = int(strip_top * scale), last = int((strip_top + 20) * scale);
                for (int y = 0; y < css_height * scale; ++y) {
                    auto const& expected = y >= first && y < last ? full : untouched;
                    if (!std::equal(strip.begin() + size_t(y) * pitch, strip.begin() + size_t(y + 1) * pitch,
                            expected.begin() + size_t(y) * pitch)) {
                        std::cerr << "Clipped gradient row differs: root=" << root << " scroll=" << scroll
                            << " strip=" << strip_top << " row=" << y << '\n';
                        return 1;
                    }
                }
                ++cases;
            }
        }
    }
    std::cout << cases << " clipped root and layer gradient strips match complete replays exactly\n";
}
