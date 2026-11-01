#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint8_t> blurred(float scale, float sigma, float phase,
    bool partial, bool translucent, bool regional)
{
    constexpr int w = 256, h = 192;
    int width = w * scale, height = h * scale, pitch = width * 4 + 16;
    std::vector<uint8_t> pixels(size_t(pitch) * height, 0xa9);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = pixels.data() + size_t(y) * pitch + x * 4;
        p[3] = translucent ? 173 : 255;
        p[0] = (x * 7 + y * 13) % p[3];
        p[1] = (x * 11 + y * 3) % p[3]; p[2] = p[3] / 3;
    }
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    CGColorSpaceRelease(color); assert(context);
    CGContextScaleCTM(context, scale, scale);
    CGContextClipToRect(context, CGRectMake(5.25, 8.5, 241, 171));
    ladybird_v_skia_set_chromium_painting(1);
    auto bounds = SkRect::MakeXYWH(partial ? -23.25f : 83.25f,
        partial ? -17.5f : 71.5f + phase, 43.5f, 29.25f);
    auto content = std::make_unique<IsolatedInputRecording>();
    auto* canvas = content->recorder.beginRecording(SkRect::MakeWH(w, h));
    content->bounds = bounds;
    SkPoint points[] {{bounds.left(), bounds.top()}, {bounds.right(), bounds.bottom()}};
    SkColor colors[] {0xff3f8ae3, 0xa7e25373, 0xff60d576};
    SkPaint ink; ink.setAntiAlias(true);
    ink.setShader(SkGradientShader::MakeLinear(points, colors, nullptr, 3, SkTileMode::kClamp));
    canvas->drawRoundRect(bounds, 7.25f, 12.5f, ink);
    s_isolated_input_recordings[context] = std::move(content);
    if (regional) unsetenv("VOX_DISABLE_BLUR_PICTURE_REGIONS");
    else setenv("VOX_DISABLE_BLUR_PICTURE_REGIONS", "1", 1);
    assert(ladybird_v_skia_end_css_gradient_blur(context, context, w, h, scale, sigma));
    assert(!s_isolated_input_recordings.count(context));
    CGContextFlush(context); CGContextRelease(context);
    for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
        assert(pixels[size_t(y) * pitch + x] == 0xa9);
    return pixels;
}
int main()
{
    assert(picture_region_draw());
    unsigned cases = 0;
    for (float scale : {1.f, 1.25f, 1.5f, 2.f, 3.f})
    for (float sigma : {.3f, 1.5f, 8.f, 30.f})
    for (float phase : {0.f, .25f}) for (bool partial : {false, true})
    for (bool translucent : {false, true}) {
        auto expected = blurred(scale, sigma, phase, partial, translucent, false);
        auto actual = blurred(scale, sigma, phase, partial, translucent, true);
        if (expected != actual) {
            size_t differences = 0; for (size_t i = 0; i < expected.size(); ++i)
                differences += expected[i] != actual[i];
            std::cerr << "Blur differs: scale=" << scale << " sigma=" << sigma << " phase=" << phase
                << " partial=" << partial << " translucent=" << translucent
                << " bytes=" << differences << '\n';
            return 1;
        }
        ++cases;
    }
    unsetenv("VOX_DISABLE_BLUR_PICTURE_REGIONS");
    std::cout << cases << " blur-region scenes match full targets exactly\n";
}
