// Recorded compositor shadows must retain the same fractional sRGB inputs as
// the leaf renderer. Compare the bridge with an independently recorded picture.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static int check(int scale, bool fractional, std::array<float, 4> color)
{
    constexpr int width = 128, height = 96;
    int pw = width * scale, ph = height * scale;
    std::vector<uint8_t> actual(size_t(pw) * ph * 4);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(actual.data(), pw, ph, 8, pw * 4, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); assert(context);
    CGContextScaleCTM(context, scale, scale);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, width, height);
    ladybird_v_skia_set_raster_layer(0, 0, 0);
    ladybird_v_skia_set_raster_layer_size(width, height);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, pw, 256 * scale, 1);
    ladybird_v_skia_set_layer_shared_recording(1);
    auto byte = SkColor4f{color[0], color[1], color[2], color[3]}.toSkColor();
    ladybird_v_skia_set_unrounded_paint_color(fractional ? color.data() : nullptr);
    assert(ladybird_v_skia_draw_outer_box_shadow(context,
        24, 28, 80, 40, 12, 12, 12, 12, 12, 12, 12, 12,
        24, 24, 80, 40, 12, 12, 12, 12, 12, 12, 12, 12,
        1, 0, 0, 1, 0, 0, 0, 0, 0, width, height,
        16, SkColorGetR(byte), SkColorGetG(byte), SkColorGetB(byte), SkColorGetA(byte), 0));
    ladybird_v_skia_finish_shared_recording();
    assert(!s_shared_root_recording);
    CGContextFlush(context);

    SkPictureRecorder recorder;
    auto canvas = recorder.beginRecording(SkRect::MakeWH(pw, 256 * scale));
    canvas->scale(scale, scale);
    auto content = SkRRect::MakeRectXY(SkRect::MakeXYWH(24, 24, 80, 40), 12, 12);
    canvas->clipRRect(content, SkClipOp::kDifference, true);
    SkPaint paint;
    paint.setAntiAlias(true);
    if (fractional) paint.setColor4f({color[0], color[1], color[2], color[3]});
    else paint.setColor(byte);
    paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, 8));
    canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(24, 28, 80, 40), 12, 12), paint);
    auto picture = recorder.finishRecordingAsPicture()->serialize();
    std::vector<uint8_t> expected(size_t(pw) * 256 * scale * 4);
    float identity[]{1, 0, 0, 0, 1, 0, 0, 0, 1};
    assert(shared_picture_draw()(expected.data(), pw, 256 * scale, pw * 4,
        picture->data(), picture->size(), identity));
    int different = 0;
    for (int y = 0; y < ph; ++y) for (int x = 0; x < pw; ++x) {
        auto a = actual.data() + (size_t(y) * pw + x) * 4;
        auto e = expected.data() + (size_t(y) * pw + x) * 4;
        if (a[0] != e[2] || a[1] != e[1] || a[2] != e[0] || a[3] != e[3]) ++different;
    }
    std::printf("scale=%d fractional=%d alpha=%.9g: %d differing pixels\n",
        scale, fractional, color[3], different);
    CGContextRelease(context);
    ladybird_v_skia_set_layer_shared_recording(0);
    ladybird_v_skia_set_msaa_grid(nullptr, 0, 0, 0, 0);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    return different;
}

int main()
{
    assert(shared_picture_draw());
    int different = 0;
    for (int scale : {1, 2}) for (bool fractional : {false, true})
    for (auto color : {std::array<float, 4>{0, 0, 0, .05f},
        std::array<float, 4>{10.5f / 255, 100.25f / 255, 200.75f / 255, .125f}})
        different += check(scale, fractional, color);
    return different ? 1 : 0;
}
