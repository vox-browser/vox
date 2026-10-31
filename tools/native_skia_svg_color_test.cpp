// Compare retained SVG paint colors with complete, independently painted GPU pictures.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    constexpr int width = 64, height = 64;
    float geometry[] {0, 9.5, 10.5, 0,0,0,0,0,0,0,0,0,
        1, 48.5, 10.5, 0,0,0,0,0,0,0,0,0,
        1, 48.5, 43.5, 0,0,0,0,0,0,0,0,0,
        1, 9.5, 43.5, 0,0,0,0,0,0,0,0,0,
        5, 0,0,0,0,0,0,0,0,0,0,0};
    int cases = 0;
    for (int scale : {1, 2}) for (bool batch : {false, true})
    for (bool stroke : {false, true}) for (float alpha : {.4f, .59f, 1.f}) {
        int pw = width * scale, ph = height * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4);
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(actual.data(), pw, ph, 8, pw * 4, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context);
        CGContextScaleCTM(context, scale, scale);
        CGContextSetRGBFillColor(context, 1, 1, 1, 1);
        CGContextFillRect(context, CGRectMake(0, 0, width, height));
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0, width, height);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        float color[] {.23f, .25f, .27f, alpha};
        if (batch) {
            VoxGraphitePath path {};
            path.matrix[0] = path.matrix[4] = path.matrix[8] = 1;
            path.segments = geometry; path.segment_count = 5;
            path.red = 59; path.green = 64; path.blue = 69; path.alpha = 255;
            path.has_float_color = 1;
            std::copy(color, color + 4, path.float_color);
            path.stroke = stroke; path.stroke_width = 1; path.miter_limit = 4;
            float identity[] {1, 0, 0, 1, 0, 0};
            assert(ladybird_v_skia_draw_svg_path_batch(context, &path, 1, identity,
                0, 0, width, height, 0, 0, 0, width, height, 1, nullptr));
        } else {
            assert(ladybird_v_skia_draw_svg_path_with_colors(context, geometry, 5, 0,
                1, 0, 0, 1, 0, 0, 0, 0, 0, width, height,
                59, 64, 69, 255, !stroke, 59, 64, 69, 255, stroke,
                1, 0, 0, 4, 0, nullptr, 0, 0, 1,
                stroke ? nullptr : color, stroke ? color : nullptr));
        }
        CGContextFlush(context);
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(pw, ph));
        canvas->clear(SK_ColorWHITE); canvas->scale(scale, scale);
        SkPaint paint; paint.setAntiAlias(true);
        paint.setColor4f({color[0], color[1], color[2], color[3]});
        if (stroke) { paint.setStyle(SkPaint::kStroke_Style); paint.setStrokeWidth(1); }
        SkPath path; path.addRect(SkRect::MakeLTRB(9.5, 10.5, 48.5, 43.5));
        canvas->drawPath(path, paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint8_t> expected(size_t(pw) * ph * 4);
        float matrix[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(expected.data(), pw, ph, pw * 4,
            bytes->data(), bytes->size(), matrix));
        int differences = 0;
        for (size_t i = 0; i < actual.size(); i += 4)
            for (int c = 0; c < 4; ++c)
                differences += actual[i + c] != expected[i + (c == 0 ? 2 : c == 2 ? 0 : c)];
        if (differences) std::fprintf(stderr,
            "scale=%d batch=%d stroke=%d alpha=%g different bytes=%d\n", scale, batch, stroke, alpha, differences);
        assert(!differences);
        CGContextRelease(context); ++cases;
    }
    std::printf("PASS: %d leaf/batch float SVG paint comparisons match complete GPU pictures\n", cases);
}
