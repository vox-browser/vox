#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

// Viewport scroll reuse shifts retained gradient-blur pixels by whole device
// rows. That is exact only if rasterizing the same blurred content at another
// whole-device-pixel offset produces the same pixels, including when the blur
// layer is clipped by the top or bottom canvas edge.
static constexpr int css_width = 400, css_height = 300;

// An opaque backdrop that translates with the content.
static std::vector<uint8_t> backdrop(float scale, float offset)
{
    int width = css_width * scale, height = css_height * scale, pitch = width * 4;
    int shift = int(std::lround(offset * scale));
    std::vector<uint8_t> pixels(size_t(pitch) * height);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        int row = y - shift;
        p[0] = uint8_t(17 + ((x * 3 + row * 5) & 31));
        p[1] = uint8_t(23 + ((x * 7 + row * 11) & 63));
        p[2] = uint8_t(40 + ((row * 2) & 15));
        p[3] = 255;
    }
    return pixels;
}

// `strip_height` CSS rows starting at `strip_top` clip the replay, as a
// reused viewport clips it to the rows a scroll exposes.
static std::vector<uint8_t> blurred(float scale, float sigma, float offset, uint64_t key = 0,
    float strip_top = 0, float strip_height = 0)
{
    int width = css_width * scale, height = css_height * scale, pitch = width * 4;
    auto pixels = backdrop(scale, offset);
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color); assert(context);
    CGContextScaleCTM(context, scale, scale);
    if (strip_height > 0)
        CGContextClipToRect(context, CGRectMake(0, css_height - strip_top - strip_height,
            css_width, strip_height));
    ladybird_v_skia_set_chromium_painting(1);
    // vlang.io's `.showcase::before`: a translucent radial glow, blur(30px).
    auto bounds = SkRect::MakeXYWH(37, 61 + offset, 326, 171.5f);
    auto content = std::make_unique<IsolatedInputRecording>();
    auto* canvas = content->recorder.beginRecording(SkRect::MakeWH(css_width, css_height));
    content->bounds = bounds;
    SkColor colors[] {0x28263d5d, 0x00263d5d};
    float positions[] {0, .68f};
    SkMatrix ellipse = SkMatrix::Scale(1, bounds.height() / bounds.width());
    ellipse.postTranslate(bounds.centerX(), bounds.centerY());
    SkPaint ink;
    ink.setShader(SkGradientShader::MakeRadial({0, 0}, bounds.width() / 2, colors, positions, 2,
        SkTileMode::kClamp, 0, &ellipse));
    canvas->drawRect(bounds, ink);
    s_isolated_input_recordings[context] = std::move(content);
    // A nonzero content identity lets later offsets reuse the first raster.
    ladybird_v_skia_set_isolated_input_key(context, key);
    assert(ladybird_v_skia_end_css_gradient_blur(context, context, css_width, css_height,
        scale, sigma));
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
}

int main()
{
    assert(picture_region_draw());
    unsigned cases = 0, failures = 0;
    for (float scale : {1.f, 2.f})
    for (float sigma : {8.f, 30.f}) {
        // Fully visible, clipped by the top edge within and beyond the blur
        // extent, and clipped by the bottom edge.
        float offsets[] {0.f, -40.f, -97.5f, -150.f, -190.f, 60.5f, 110.f, 150.f};
        float base = 25.f;
        auto reference = blurred(scale, sigma, base);
        uint64_t key = 0x5eed0000 + uint64_t(scale * 100 + sigma);
        assert(blurred(scale, sigma, base, key) == reference);
        int width = css_width * scale, height = css_height * scale, pitch = width * 4;
        for (float offset : offsets) {
            // Fractional device offsets change the raster phase by design.
            if (std::abs(offset * scale - std::round(offset * scale)) > 1e-6) continue;
            auto actual = blurred(scale, sigma, base + offset);
            // Whole-device-pixel offsets reuse the cached layer exactly.
            assert(blurred(scale, sigma, base + offset, key) == actual);
            int rows = int(std::lround(offset * scale));
            size_t differences = 0, compared = 0; int worst = 0, first_row = -1;
            for (int y = 0; y < height; ++y) {
                int source = y - rows;
                if (source < 0 || source >= height) continue;
                for (int x = 0; x < pitch; ++x) {
                    int a = reference[size_t(source) * pitch + x];
                    int b = actual[size_t(y) * pitch + x];
                    ++compared;
                    if (a != b) {
                        ++differences;
                        worst = std::max(worst, std::abs(a - b));
                        if (first_row < 0) first_row = y;
                    }
                }
            }
            // A clipped replay writes exactly the full replay's strip rows.
            for (float strip_top : {0.f, 7.5f, css_height - 12.f}) {
                // Reused viewports clip on whole device rows.
                if (std::abs(strip_top * scale - std::round(strip_top * scale)) > 1e-6) continue;
                float strip_height = 12;
                auto strip = blurred(scale, sigma, base + offset, key, strip_top, strip_height);
                auto untouched = backdrop(scale, base + offset);
                int first = int(std::lround(strip_top * scale));
                int last = int(std::lround((strip_top + strip_height) * scale));
                for (int y = 0; y < height; ++y) {
                    auto const& expected = y >= first && y < last ? actual : untouched;
                    if (!std::equal(strip.begin() + size_t(y) * pitch,
                            strip.begin() + size_t(y + 1) * pitch, expected.begin() + size_t(y) * pitch)) {
                        ++failures;
                        std::cerr << "Strip replay differs: scale=" << scale << " sigma=" << sigma
                            << " offset=" << offset << " strip=" << strip_top << " row=" << y << '\n';
                        break;
                    }
                }
            }
            ++cases;
            if (differences) {
                ++failures;
                std::cerr << "Translated blur differs: scale=" << scale << " sigma=" << sigma
                    << " offset=" << offset << " bytes=" << differences << "/" << compared
                    << " max=" << worst << " first_row=" << first_row << '\n';
            }
        }
    }
    if (failures) {
        std::cerr << failures << "/" << cases << " translated blur scenes differ\n";
        return 1;
    }
    std::cout << cases << " translated blur scenes match exactly\n";
}
