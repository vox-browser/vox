// Compare an isolated rounded background/border with its independent Skia
// saveLayer recording, including fractional sticky translations.
#include "../native_skia_text_darwin.cpp"
#include "../native_opacity_group_darwin.h"
#include <cassert>
#include <cstdio>

int main()
{
    assert(shared_picture_draw());
    int failures = 0, cases = 0;
    for (int scale : {1, 2}) for (float phase : {0.f, .5f})
    for (float translation : {0.f, -182.5f}) {
        constexpr int width = 1024, height = 768;
        int pw = width * scale, ph = height * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4);
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(actual.data(), pw, ph, 8, pw * 4,
            space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context);
        CGContextScaleCTM(context, scale, scale);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0, width, height);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(width, height);
        int tile = 0;
        ladybird_v_skia_set_msaa_tiles(&tile, 1, height * scale + 2);
        float x = 969.5f + phase, y = 683.5f + phase;
        float rect[] {x, y, 31, 31, 15.5, 15.5, 15.5, 15.5, 15.5, 15.5, 15.5, 15.5};
        ladybird_v_skia_set_rounded_rect_underlay(rect, 53, 102, 240, 255);
        assert(ladybird_v_skia_draw_rounded_rect(context, x, y, 31, 31,
            15.5, 15.5, 15.5, 15.5, 15.5, 15.5, 15.5, 15.5,
            1, 0, 0, 1, 0, translation, 0, 0, 0, width, height,
            53, 102, 240, 255, 0, 1, 1, 1));
        CGContextFlush(context); CGContextRelease(context);
        std::vector<uint8_t> white(actual.size(), 255), composite(actual.size());
        native_composite_opacity_pixels(actual.data(), white.data(), composite.data(),
            actual.size() / 4, .5f);

        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(pw, ph));
        canvas->clear(SK_ColorWHITE);
        canvas->scale(scale, scale);
        canvas->translate(0, translation);
        auto bounds = SkRect::MakeXYWH(x - .5f, y - .5f, 32, 32);
        SkPaint opacity; opacity.setAlphaf(.5f);
        canvas->saveLayer(&bounds, &opacity);
        auto rounded = SkRRect::MakeRectXY(SkRect::MakeXYWH(x, y, 31, 31), 15.5, 15.5);
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SkColorSetRGB(53, 102, 240));
        canvas->drawRRect(rounded, paint);
        paint.setStyle(SkPaint::kStroke_Style); paint.setStrokeWidth(1);
        canvas->drawRRect(rounded, paint);
        // A transparent subpixel path selects MSAA just as an SVG descendant
        // does, without introducing another visible pixel into the comparison.
        SkPaint noop; noop.setAntiAlias(true);
        noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
        SkPathBuilder path;
        path.moveTo(x + 15, y + 15);
        path.cubicTo(x + 15.01f, y + 15.001f, x + 15, y + 15.01f,
            x + 15.01f, y + 15.01f);
        path.lineTo(x + 15.005f, y + 15.002f); path.close();
        canvas->drawPath(path.detach(), noop);
        canvas->restore();
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint8_t> expected(actual.size());
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(expected.data(), pw, ph, pw * 4,
            bytes->data(), bytes->size(), identity));
        int different = 0;
        for (size_t i = 0; i < expected.size(); i += 4) {
            std::swap(expected[i], expected[i + 2]);
            if (!std::equal(expected.begin() + i, expected.begin() + i + 4,
                    composite.begin() + i)) ++different;
        }
        std::printf("scale=%d phase=%g translation=%g: %d differing pixels\n",
            scale, phase, translation, different);
        failures += different; ++cases;
    }
    std::printf("Compound rounded stroke: %d cases\n", cases);
    return failures ? 1 : 0;
}
