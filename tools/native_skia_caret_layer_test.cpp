#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static void check_caret(int scale, float phase, int caret_width)
{
    int size = 64 * scale;
    std::vector<uint8_t> pixels(size_t(size) * size * 4, 255);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), size, size, 8, size * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    ladybird_v_skia_set_chromium_painting(1);
    ladybird_v_skia_set_shared_recording(0, 64, 64);
    ladybird_v_skia_set_raster_layer(0, 0, 0);
    ladybird_v_skia_set_raster_layer_size(64, 64);
    ladybird_v_skia_set_layer_shared_recording(1);
    int tile = 0;
    ladybird_v_skia_set_msaa_grid(&tile, 1, size, size, 2);
    auto* canvas = shared_recording_canvas(context);
    assert(canvas);
    SkPath curve;
    curve.moveTo(0, 0); curve.cubicTo(.01f, .001f, 0, .01f, .01f, .01f);
    curve.lineTo(.005f, .002f); curve.close();
    SkPaint noop;
    noop.setAntiAlias(true);
    noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
    canvas->drawPath(curve, noop);
    shared_recording_content(context, SkRect::MakeWH(64, 64), 0, 0);
    float top = 20 + phase / scale;
    // The text control clips at the caret's fractional first row. Applying
    // that coverage again would turn the half-covered cap into a quarter.
    float clip[] {0, top, 64, 44, 0, 0, 0, 0, 0, 0, 0, 0};
    float identity[] {1, 0, 0, 1, 0, 0};
    ladybird_v_skia_add_shared_rounded_clip(context, clip, identity);
    ladybird_v_skia_record_caret(context, 10, 64 - top - 20,
        caret_width, 20, 0, 0, 0, 255);
    ladybird_v_skia_finish_shared_recording();
    CGContextFlush(context);
    for (int y = 0; y < size; ++y) for (int x = 0; x < size; ++x) {
        float coverage = x >= 10 * scale && x < (10 + caret_width) * scale
            ? std::max(0.f, std::min(float(y + 1), (top + 20) * scale)
                - std::max(float(y), top * scale)) : 0.f;
        int expected = 255 - int(std::floor(255 * coverage + .5f));
        auto* pixel = pixels.data() + (size_t(y) * size + x) * 4;
        if (pixel[0] != expected || pixel[1] != expected || pixel[2] != expected || pixel[3] != 255) {
            std::fprintf(stderr, "scale=%d phase=%g width=%d xy=%d,%d expected=%d actual=%d,%d,%d,%d\n",
                scale, phase, caret_width, x, y, expected, pixel[0], pixel[1], pixel[2], pixel[3]);
            assert(false);
        }
    }
    CGContextRelease(context);
    ladybird_v_skia_set_shared_recording(0, 0, 0);
    ladybird_v_skia_set_chromium_painting(0);
}

int main()
{
    for (int scale : {1, 2}) for (float phase : {0.f, .25f, .5f, .75f})
        for (int width : {1, 2}) check_caret(scale, phase, width);
    std::puts("PASS: 16 exact compositor caret cases, scales, caps, clipping and neighboring pixels");
}
