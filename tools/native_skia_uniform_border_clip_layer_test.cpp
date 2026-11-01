// Compare the native compound border with Blink's independently recorded
// outer clip, layer, background and inverse-inner-path paint sequence.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    assert(shared_picture_draw());
    int cases = 0;
    for (int scale : {1, 2}) for (bool recording : {false, true})
    for (int alpha : {26, 38, 128}) {
        int width = 96 * scale, height = 64 * scale;
        int tile_height = 256 * scale;
        std::vector<uint8_t> actual(size_t(width) * height * 4, 252);
        for (size_t i = 3; i < actual.size(); i += 4) actual[i] = 255;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(actual.data(), width, height, 8, width * 4,
            space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context);
        CGContextScaleCTM(context, scale, scale);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(96, 64);
        int tile = 0;
        ladybird_v_skia_set_msaa_grid(&tile, 1, width, tile_height, 1);
        ladybird_v_skia_set_shared_recording(recording, 96, 64);
        float background[] {10, 12, 76, 40, 20, 20, 20, 20, 20, 20, 20, 20};
        float widths[] {1, 1, 1, 1};
        ladybird_v_skia_set_rounded_rect_underlay(background, 255, 255, 255, 255);
        ladybird_v_skia_set_rounded_border_widths(widths);
        assert(ladybird_v_skia_draw_rounded_rect(context, 10.5, 12.5, 75, 39,
            19.5, 19.5, 19.5, 19.5, 19.5, 19.5, 19.5, 19.5,
            1, 0, 0, 1, 0, 0, 0, 0, 0, 96, 64, 0, 0, 0, alpha, 7, 1, 1, 1));
        ladybird_v_skia_finish_shared_recording();
        CGContextFlush(context);

        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, tile_height));
        canvas->clear(SkColorSetRGB(252, 252, 252));
        canvas->scale(scale, scale);
        auto outer = SkRRect::MakeRectXY(SkRect::MakeXYWH(10, 12, 76, 40), 20, 20);
        auto inner = SkRRect::MakeRectXY(SkRect::MakeXYWH(11, 13, 74, 38), 19, 19);
        canvas->save();
        canvas->clipRRect(outer, SkClipOp::kIntersect, true);
        canvas->saveLayer(nullptr, nullptr);
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SK_ColorWHITE);
        canvas->drawRect(outer.rect(), paint);
        SkPathBuilder path; path.addRRect(inner);
        auto hole = path.detach(); hole.setFillType(SkPathFillType::kInverseWinding);
        paint.setColor(SkColorSetARGB(alpha, 0, 0, 0));
        canvas->drawPath(hole, paint);
        canvas->restore(); canvas->restore();
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint8_t> expected(size_t(width) * tile_height * 4);
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(expected.data(), width, tile_height, width * 4,
            bytes->data(), bytes->size(), identity));
        expected.resize(actual.size()); // The viewport owns the leading tile rows.
        if (actual != expected) {
            std::fprintf(stderr, "clip layer differs scale=%d recording=%d alpha=%d\n",
                scale, recording, alpha);
            int shown = 0;
            for (size_t i = 0; i < actual.size(); i += 4) if (actual[i] != expected[i] && shown++ < 12)
                std::fprintf(stderr, "%zu,%zu actual=%d expected=%d\n", i / 4 % width,
                    i / 4 / width, actual[i], expected[i]);
        }
        assert(actual == expected);
        CGContextRelease(context);
        ladybird_v_skia_set_shared_recording(0, 0, 0);
        ++cases;
    }
    std::printf("Uniform border clip layer: %d exact native/GPU cases passed\n", cases);
}
