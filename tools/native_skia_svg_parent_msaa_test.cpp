// Compare batched SVG ellipses with a complete raster containing a path that
// selects MSAA. Exercise both the direct Metal and clipped Dawn publication.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    void* library = nullptr;
    if (auto path = std::getenv("VOX_SVG_MSAA_REFERENCE_LIBRARY")) {
        library = dlopen(path, RTLD_NOW | RTLD_LOCAL); assert(library);
    }
    auto resolve = [&]<typename T>(char const* name, T current) {
        auto value = library ? reinterpret_cast<T>(dlsym(library, name)) : current;
        assert(value); return value;
    };
    auto painting = resolve("ladybird_v_skia_set_chromium_painting", &ladybird_v_skia_set_chromium_painting);
    auto recording = resolve("ladybird_v_skia_set_shared_recording", &ladybird_v_skia_set_shared_recording);
    auto layer = resolve("ladybird_v_skia_set_raster_layer", &ladybird_v_skia_set_raster_layer);
    auto size = resolve("ladybird_v_skia_set_raster_layer_size", &ladybird_v_skia_set_raster_layer_size);
    auto grid = resolve("ladybird_v_skia_set_msaa_grid", &ladybird_v_skia_set_msaa_grid);
    auto clip = resolve("ladybird_v_skia_add_shared_rounded_clip", &ladybird_v_skia_add_shared_rounded_clip);
    auto draw = resolve("ladybird_v_skia_draw_svg_path_batch", &ladybird_v_skia_draw_svg_path_batch);
    constexpr int width = 1024, height = 768, tile_rows = 256, origin_y = 254;
    float identity[] {1, 0, 0, 1, 0, 0};
    int cases = 0, different = 0;
    for (bool regional : {false, true}) for (bool clipped : {false, true}) for (bool msaa : {false, true})
    for (int scale : {1, 2}) for (float phase : {0.f, .25f, .5f, .875f})
    for (uint32_t background : {0xfffcfdffU, 0xff78b247U}) {
        if (regional) unsetenv("VOX_DISABLE_SVG_IMAGE_REGIONS");
        else setenv("VOX_DISABLE_SVG_IMAGE_REGIONS", "1", 1);
        int pw = width * scale, ph = height * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4);
        for (size_t i = 0; i < actual.size(); i += 4) {
            actual[i] = background >> 16; actual[i + 1] = background >> 8;
            actual[i + 2] = background; actual[i + 3] = 255;
        }
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto destination = CGBitmapContextCreate(actual.data(), pw, ph, 8, pw * 4, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(destination);
        CGContextScaleCTM(destination, scale, scale);
        painting(1); recording(0, width, height);
        layer(0, 0, 1); size(width, 8967);
        int cell = 1; grid(&cell, msaa ? 1 : 0, width * scale, tile_rows * scale, 1);
        if (clipped) {
            float bounds[] {680, 328, 20, 20, 0, 0, 0, 0, 0, 0, 0, 0};
            clip(destination, bounds, identity);
            CGContextClipToRect(destination, CGRectMake(680, height - 348, 20, 20));
        }
        float segments[3][12] {};
        VoxGraphitePath paths[3] {};
        for (int i = 0; i < 3; ++i) {
            auto& s = segments[i];
            s[0] = 6; s[1] = .5f + 6 * i; s[2] = 7;
            s[3] = 3.5f + 6 * i; s[4] = 10;
            auto& p = paths[i];
            p.segments = s; p.segment_count = 1;
            p.matrix[0] = p.matrix[4] = p.matrix[8] = 1;
            p.matrix[2] = 682 + phase; p.matrix[5] = 329;
            p.red = 112; p.green = 115; p.blue = 123;
            p.alpha = 255; p.opacity = 1; p.has_float_alpha = 1;
        }
        assert(draw(destination, paths, 3, identity, 680, 328, 20, 20,
            0, 0, 0, width, height, 1, nullptr));
        CGContextFlush(destination);

        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(pw, tile_rows * scale));
        canvas->clear(background);
        canvas->scale(scale, scale);
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SK_ColorRED);
        if (msaa) {
            // This visible, non-convex path is elsewhere in the same tile.
            // It participates in the independent reference only; compare the
            // ellipses' viewport rather than the unrelated path's pixels.
            SkPath path;
            path.moveTo(10, 10); path.lineTo(40, 40); path.lineTo(10, 40);
            path.lineTo(40, 10); path.lineTo(25, 45); path.close();
            canvas->drawPath(path, paint);
        }
        canvas->translate(0, -origin_y);
        canvas->clipRect(SkRect::MakeXYWH(680, 328, 20, 20));
        paint.setColor(SkColorSetRGB(112, 115, 123));
        for (int i = 0; i < 3; ++i)
            canvas->drawOval(SkRect::MakeLTRB(682.5f + 6 * i + phase, 336,
                685.5f + 6 * i + phase, 339), paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize(); assert(bytes);
        std::vector<uint32_t> expected(size_t(pw) * tile_rows * scale);
        float matrix[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(expected.data()), pw,
            tile_rows * scale, pw * 4, bytes->data(), bytes->size(), matrix));
        int errors = 0;
        for (int y = 328 * scale; y < 348 * scale; ++y)
        for (int x = 680 * scale; x < 700 * scale; ++x) {
            auto a = actual.data() + (size_t(y) * pw + x) * 4;
            auto e = reinterpret_cast<uint8_t*>(expected.data())
                + (size_t(y - origin_y * scale) * pw + x) * 4;
            if (a[0] != e[2] || a[1] != e[1] || a[2] != e[0] || a[3] != e[3]) ++errors;
        }
        if (errors) {
            std::fprintf(stderr, "clipped=%d msaa=%d scale=%d phase=%g background=%08x: %d differing pixels\n",
                clipped, msaa, scale, phase, background, errors);
            different += errors;
        }
        CGContextRelease(destination); ++cases;
    }
    std::printf("%s: %d SVG ellipse batches; %d differing pixels\n", different ? "FAIL" : "PASS", cases, different);
    return different ? 1 : 0;
}
