#define VOX_TEST_DIRECT_GRADIENT_BLUR
#include "../native_skia_text_darwin.cpp"
#include <cassert>

static std::vector<uint8_t> render(int scale, bool opaque, bool radial,
    float sigma, bool direct, bool fail)
{
    constexpr int width = 233, height = 157;
    int pitch = (width * scale + 3) * 4;
    std::vector<uint8_t> pixels(size_t(pitch) * height * scale, 0xcd);
    for (int y = 0; y < height * scale; ++y)
        for (int x = 0; x < width * scale; ++x) {
            auto* p = pixels.data() + size_t(y) * pitch + x * 4;
            p[0] = (x + 3 * y) % 67;
            p[1] = (3 * x + y) % 83;
            p[2] = (x + y) % 97;
            p[3] = opaque ? 255 : 127;
        }
    auto original = pixels;
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto destination = CGBitmapContextCreate(pixels.data(), width * scale,
        height * scale, 8, pitch, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    auto source = CGBitmapContextCreate(nullptr, width * scale, height * scale,
        8, width * scale * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(destination && source);
    CGContextScaleCTM(destination, scale, scale);
    CGContextScaleCTM(source, scale, scale);
    assert(ladybird_v_skia_begin_isolated_input(source, width, height));
    auto& recording = *s_isolated_input_recordings.at(source);
    auto* canvas = recording.recorder.getRecordingCanvas();
    SkRect bounds = SkRect::MakeXYWH(31.25f, 40.5f, 133.75f, 65.25f);
    recording.bounds = bounds;
    SkColor colors[] {SkColorSetARGB(193, 117, 213, 43), SK_ColorTRANSPARENT};
    SkPoint points[] {{31.25f, 40.5f}, {165, 105.75f}};
    auto shader = radial
        ? SkGradientShader::MakeRadial({92.25f, 71.5f}, 65.75f, colors, nullptr, 2,
            SkTileMode::kClamp)
        : SkGradientShader::MakeLinear(points, colors, nullptr, 2, SkTileMode::kClamp);
    assert(shader);
    SkPaint paint;
    paint.setShader(shader);
    paint.setAntiAlias(true);
    paint.setDither(true);
    canvas->drawOval(bounds, paint);
    if (direct) unsetenv("VOX_DISABLE_DIRECT_GRADIENT_BLUR_BACKDROP");
    else setenv("VOX_DISABLE_DIRECT_GRADIENT_BLUR_BACKDROP", "1", 1);
    s_test_fail_direct_gradient_blur = fail;
    auto before = s_test_direct_gradient_blur_successes;
    assert(ladybird_v_skia_end_css_gradient_blur(source, destination,
        width, height, scale, sigma));
    assert(s_test_direct_gradient_blur_successes - before
        == unsigned(direct && opaque && !fail));
    for (int y = 0; y < height * scale; ++y)
        for (int x = width * scale * 4; x < pitch; ++x)
            assert(pixels[size_t(y) * pitch + x] == original[size_t(y) * pitch + x]);
    CGContextRelease(source);
    CGContextRelease(destination);
    return pixels;
}

int main()
{
    // These comparisons cover the legacy GPU composite and its direct-backdrop
    // upload; opaque backdrops otherwise take the content-anchored layer.
    setenv("VOX_DISABLE_ANCHORED_GRADIENT_BLUR", "1", 1);
    ladybird_v_skia_set_chromium_painting(1);
    unsigned cases = 0;
    for (int scale : {1, 2})
        for (bool opaque : {false, true})
            for (bool radial : {false, true})
                for (float sigma : {1.5f, 9.25f, 30.f}) {
                    auto control = render(scale, opaque, radial, sigma, false, false);
                    assert(control == render(scale, opaque, radial, sigma, true, false));
                    assert(control == render(scale, opaque, radial, sigma, true, true));
                    cases += 2;
                }
    std::printf("%u exact gradient-blur backdrop and forced-rollback comparisons\n", cases);
    ladybird_v_skia_set_chromium_painting(0);
}
