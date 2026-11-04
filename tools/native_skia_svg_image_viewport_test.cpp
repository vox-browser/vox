// An SVG image viewport clips without AA before the SVG overflow clip.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    constexpr int width = 320, height = 240;
    int cases = 0;
    for (int scale : {1, 2}) for (float phase : {.125f, .372f, .5f, .875f})
    for (bool contained : {false, true}) {
        int pw = width * scale, ph = height * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4, 255), expected = actual;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto c = CGBitmapContextCreate(pixels.data(), pw, ph, 8, pw * 4, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(c); CGContextScaleCTM(c, scale, scale); return c;
        };
        auto context = make(actual), control = make(expected);
        CGColorSpaceRelease(space);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0, width, height);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(width, height);
        int cell = 0;
        ladybird_v_skia_set_msaa_grid(&cell, 1, width * scale, 256 * scale, 1);
        float clip[] {15, 66, 12, 12, 0, 0, 0, 0, 0, 0, 0, 0};
        float matrix[] {1, 0, 0, 1, 0, phase};
        for (int duplicate = 0; duplicate < (contained ? 2 : 1); ++duplicate) {
            clip[3] = 12;
            if (duplicate) ladybird_v_skia_add_shared_rounded_clip(context, clip, matrix);
            else ladybird_v_skia_add_shared_image_viewport_clip(context, clip, matrix);
            CGContextClipToRect(context, CGRectMake(15, height - 66 - clip[3] - phase, 12, clip[3]));
        }
        float path[4 * 12] {};
        path[1] = 14; path[2] = 65;
        path[12] = 1; path[13] = 29; path[14] = 65;
        path[24] = 1; path[25] = 14; path[26] = 81;
        path[36] = 5;
        assert(ladybird_v_skia_draw_svg_path(context, path, 4, 0,
            1, 0, 0, 1, 0, phase, 0, 0, 0, width, height,
            44, 0, 34, 255, 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, nullptr, 0, 0, 1));
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(pw, 256 * scale);
        canvas->clear(SK_ColorWHITE); canvas->scale(scale, scale); canvas->translate(0, phase);
        canvas->clipRect(SkRect::MakeXYWH(15, 66, 12, 12), false);
        if (contained) canvas->clipRect(SkRect::MakeXYWH(15, 66, 12, 12), true);
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SkColorSetRGB(44, 0, 34));
        canvas->drawPath(path_from_serialized_segments(path, 4), paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint32_t> gpu(size_t(pw) * 256 * scale);
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(gpu.data()), pw, 256 * scale,
            pw * 4, bytes->data(), bytes->size(), identity));
        assert(composite_pixels(control, std::move(gpu), pw, 256 * scale,
            0, height - 256, width, 256, true));
        CGContextFlush(context); CGContextFlush(control);
        if (actual != expected) {
            int differences = 0;
            for (size_t i = 0; i < actual.size(); i += 4)
                differences += !std::equal(actual.data() + i, actual.data() + i + 4, expected.data() + i);
            std::fprintf(stderr, "scale=%d phase=%g containing=%d differences=%d\n", scale, phase, contained, differences);
            return 1;
        }
        CGContextRelease(context); CGContextRelease(control); ++cases;
    }
    std::printf("PASS: %d SVG image viewports match hard-image and SVG-overflow GPU clips\n", cases);
}
