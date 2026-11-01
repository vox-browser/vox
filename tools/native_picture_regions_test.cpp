#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint8_t> gradient_text(int scale, float phase, bool partial,
    bool translucent, bool regional)
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
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    CGContextClipToRect(context, CGRectMake(5.25, 8.5, 241, 171));
    ladybird_v_skia_set_chromium_painting(1);
    float x = partial ? -13.25f : 37.25f;
    float top = 51.5f + phase, box_width = 132.5f, box_height = 49.25f;
    auto bounds = SkRect::MakeXYWH(x, top, box_width, box_height);
    auto mask = std::make_unique<IsolatedInputRecording>();
    auto* canvas = mask->recorder.beginRecording(SkRect::MakeWH(w, h));
    mask->bounds = bounds;
    SkPaint ink; ink.setAntiAlias(true); ink.setColor(SK_ColorWHITE);
    canvas->drawRoundRect(bounds, 7.25f, 12.5f, ink);
    auto content = std::make_unique<IsolatedInputRecording>();
    canvas = content->recorder.beginRecording(SkRect::MakeWH(w, h));
    content->bounds = bounds;
    SkPoint points[] {{x, top}, {x + box_width, top + box_height}};
    SkColor colors[] {0xff3f8ae3, 0xa7e25373, 0xff60d576};
    ink.setShader(SkGradientShader::MakeLinear(points, colors, nullptr, 3, SkTileMode::kClamp));
    canvas->drawRect(SkRect::MakeWH(w, h), ink);
    s_isolated_input_recordings[context] = std::move(content);
    if (regional) unsetenv("VOX_DISABLE_PICTURE_REGIONS");
    else setenv("VOX_DISABLE_PICTURE_REGIONS", "1", 1);
    assert(ladybird_v_skia_draw_gradient_text(context, mask.release(), context,
        w, h, scale, x, h - top - box_height, box_width, box_height));
    assert(!s_isolated_input_recordings.count(context));
    CGContextFlush(context); CGContextRelease(context);
    for (int y = 0; y < height; ++y) for (int x = width * 4; x < pitch; ++x)
        assert(pixels[size_t(y) * pitch + x] == 0xa9);
    return pixels;
}

int main()
{
    auto region = picture_region_draw();
    assert(region); // A missing optional symbol must not masquerade as coverage.
    unsigned cases = 0;
    for (int scale : {1, 2}) for (float phase : {0.f, .25f, .5f, .75f})
    for (bool partial : {false, true}) for (bool translucent : {false, true}) {
        auto expected = gradient_text(scale, phase, partial, translucent, false);
        auto actual = gradient_text(scale, phase, partial, translucent, true);
        if (expected != actual) {
            std::cerr << "Gradient text differs: scale=" << scale << " phase=" << phase
                << " partial=" << partial << " translucent=" << translucent << '\n';
            return 1;
        }
        ++cases;
    }
    unsetenv("VOX_DISABLE_PICTURE_REGIONS");
    // Compare actual compact GPU transfers with crops of the original target.
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(320, 256));
    SkPaint ink; ink.setAntiAlias(true); ink.setColor(0xc54d91e3);
    canvas->drawRoundRect(SkRect::MakeXYWH(18.25f, 27.5f, 233.75f, 166.25f), 13, 17, ink);
    SkPath path; path.moveTo(3.25f, 4); path.cubicTo(90, 17, 9, 240, 300, 216);
    path.lineTo(141, 73); path.close(); canvas->drawPath(path, ink);
    auto bytes = recorder.finishRecordingAsPicture()->serialize(); assert(bytes);
    float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
    std::vector<uint8_t> full(320 * 256 * 4);
    assert(shared_picture_draw()(full.data(), 320, 256, 320 * 4,
        bytes->data(), bytes->size(), identity));
    int rectangles[][4] {{0, 0, 1, 1}, {11, 19, 173, 121}, {319, 255, 1, 1},
        {0, 0, 320, 256}, {71, 103, 249, 153}};
    for (auto const& r : rectangles) {
        int pitch = r[2] * 4 + 13;
        std::vector<uint8_t> compact(size_t(pitch) * r[3] + 1, 0xa9);
        assert(region(compact.data() + 1, 320, 256, pitch, r[0], r[1], r[2], r[3],
            bytes->data(), bytes->size(), identity));
        assert(compact.front() == 0xa9);
        for (int y = 0; y < r[3]; ++y) {
            auto* row = compact.data() + 1 + size_t(y) * pitch;
            assert(!std::memcmp(row, full.data() + (size_t(r[1] + y) * 320 + r[0]) * 4,
                size_t(r[2]) * 4));
            for (int x = r[2] * 4; x < pitch; ++x) assert(row[x] == 0xa9);
        }
        ++cases;
    }
    std::vector<uint8_t> untouched(128, 0xa9), saved = untouched;
    int invalid[][4] {{-1, 0, 1, 1}, {0, -1, 1, 1}, {0, 0, 0, 1},
        {0, 0, 1, 0}, {319, 0, 2, 1}, {0, 255, 1, 2}, {0, 0, 321, 1}};
    for (auto const& r : invalid) {
        assert(!region(untouched.data(), 320, 256, 32, r[0], r[1], r[2], r[3],
            bytes->data(), bytes->size(), identity));
        assert(untouched == saved);
    }
    assert(!region(untouched.data(), 320, 256, 3, 0, 0, 1, 1,
        bytes->data(), bytes->size(), identity));
    assert(untouched == saved);
    std::cout << cases << " picture-region scenes match full targets; invalid transfers leave output unchanged\n";
}
