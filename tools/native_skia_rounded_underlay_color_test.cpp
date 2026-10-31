// Compare the actual deferred underlay with an independently painted GPU picture.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

// A single rounded border crosses from one sample mode into the other.
// Assemble each complete tile independently and retain only its owned rows.
static int check_mixed_sample_tiles()
{
    int cases = 0;
    for (bool horizontal : {false, true}) for (int scale : {1, 2}) for (bool first_msaa : {false, true})
    for (float alpha : {.4f, .59f, 1.f}) {
        int pw = 64 * scale, ph = 64 * scale;
        int tile_width = (horizontal ? 32 : 64) * scale, tile_height = (horizontal ? 64 : 32) * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4, 255), expected(actual.size(), 255);
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(actual.data(), pw, ph, 8, pw * 4, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context); CGContextScaleCTM(context, scale, scale);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0, 64, 64);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(64, 64);
        int selected = first_msaa ? 0 : 1;
        ladybird_v_skia_set_msaa_grid(&selected, 1, tile_width, tile_height,
            (pw - 2 + tile_width - 3) / (tile_width - 2));
        float rect[] {10, 12, 40, 36, 4, 4, 4, 4, 4, 4, 4, 4};
        float background[] {.9634f, .96506f, .9966f, alpha};
        float border[] {.3335f, .35715f, .8065f, .73f};
        ladybird_v_skia_set_rounded_rect_underlay(rect, 246, 246, 254, 255);
        ladybird_v_skia_set_rounded_rect_underlay_color(background);
        ladybird_v_skia_set_unrounded_paint_color(border);
        assert(ladybird_v_skia_draw_rounded_rect(context,
            10.5, 12.5, 39, 35, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5,
            1, 0, 0, 1, 0, 0, 0, 0, 0, 64, 64,
            85, 91, 206, 186, 0, 1, 1, 1));
        CGContextFlush(context);
        for (int row = 0; row < 2; ++row) {
            bool msaa = row == selected;
            int origin_x = horizontal ? row * (tile_width - 2) : 0;
            int origin_y = horizontal ? 0 : row * (tile_height - 2);
            SkPictureRecorder recorder;
            auto* canvas = recorder.beginRecording(SkRect::MakeWH(tile_width, tile_height));
            canvas->clear(SK_ColorWHITE);
            if (msaa) {
                SkPath curve; curve.moveTo(0, 0); curve.cubicTo(.01f, .001f, 0, .01f, .01f, .01f);
                curve.lineTo(.005f, .002f); curve.close();
                SkPaint noop; noop.setAntiAlias(true); noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
                canvas->drawPath(curve, noop);
            }
            canvas->translate(-origin_x, -origin_y); canvas->scale(scale, scale);
            SkPaint paint; paint.setAntiAlias(true);
            // This complete leaf crosses an MSAA tile, so both modes keep
            // the same byte palette. A per-tile switch changes its corners.
            paint.setColor(SkColorSetARGB(255, 246, 246, 254));
            canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(10, 12, 40, 36), 4, 4), paint);
            paint.setColor4f({border[0], border[1], border[2], border[3]});
            paint.setStyle(SkPaint::kStroke_Style); paint.setStrokeWidth(1);
            canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(10.5, 12.5, 39, 35), 3.5, 3.5), paint);
            auto bytes = recorder.finishRecordingAsPicture()->serialize();
            std::vector<uint8_t> tile(size_t(tile_width) * tile_height * 4);
            float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
            assert(shared_picture_draw()(tile.data(), tile_width, tile_height, tile_width * 4,
                bytes->data(), bytes->size(), identity));
            int left = horizontal && row ? origin_x + 1 : 0;
            int top = !horizontal && row ? origin_y + 1 : 0;
            int right = std::min(pw, origin_x + tile_width - (horizontal ? 1 : 0));
            int bottom = std::min(ph, origin_y + tile_height - (horizontal ? 0 : 1));
            for (int y = top; y < bottom; ++y)
                swap_red_blue_pixels(expected.data() + (size_t(y) * pw + left) * 4,
                    tile.data() + (size_t(y - origin_y) * tile_width + left - origin_x) * 4, right - left);
        }
        if (actual != expected) std::fprintf(stderr,
            "mixed tiles horizontal=%d scale=%d first_msaa=%d alpha=%g differ\n", horizontal, scale, first_msaa, alpha);
        assert(actual == expected); CGContextRelease(context); ++cases;
    }
    return cases;
}

int main()
{
    constexpr int width = 64, height = 64;
    int cases = 0, typed_cases = 0;
    for (bool grid : {false, true}) for (bool msaa : {false, true}) for (int scale : {1, 2}) for (float alpha : {.4f, .59f, 1.f})
    for (bool opaque : {false, true}) for (bool recording : {false, true}) for (int state = 0; state < 5; ++state) {
        if (recording && !grid) continue; // Shared pictures require a complete tile grid.
        int pw = width * scale, ph = height * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4, opaque ? 255 : 0);
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(actual.data(), pw, ph, 8, pw * 4, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context);
        CGContextScaleCTM(context, scale, scale);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(recording, width, height);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(width, height);
        int tile = 0;
        if (grid) ladybird_v_skia_set_msaa_grid(msaa ? &tile : nullptr, msaa ? 1 : 0, width * scale, height * scale, 1);
        else ladybird_v_skia_set_msaa_tiles(msaa ? &tile : nullptr, msaa ? 1 : 0, height * scale);
        if (recording) {
            auto* canvas = shared_recording_canvas(context); assert(canvas);
            canvas->clear(opaque ? SK_ColorWHITE : SK_ColorTRANSPARENT);
            SkPath curve; curve.moveTo(0, 0); curve.cubicTo(.01f, .001f, 0, .01f, .01f, .01f);
            curve.lineTo(.005f, .002f); curve.close();
            SkPaint noop; noop.setAntiAlias(true); noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
            if (msaa) canvas->drawPath(curve, noop);
            shared_recording_content(context, SkRect::MakeWH(width, height), 0, 0);
        }
        float rect[] {10, 12, 40, 36, 4, 4, 4, 4, 4, 4, 4, 4};
        float background[] {.9634f, .96506f, .9966f, alpha};
        float border[] {.3335f, .35715f, .8065f, .73f};
        auto draw = [&](CGContextRef destination) {
            return ladybird_v_skia_draw_rounded_rect(destination,
                10.5, 12.5, 39, 35, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5,
                1, 0, 0, 1, 0, 0, 0, 0, 0, width, height,
                85, 91, 206, 186, 0, 1, 1, opaque);
        };
        ladybird_v_skia_set_rounded_rect_underlay(rect, 246, 246, 254, 255);
        ladybird_v_skia_set_rounded_rect_underlay_color(background);
        // Metadata is optional and belongs only to the next complete draw.
        if (state == 1) ladybird_v_skia_set_rounded_rect_underlay_color(nullptr);
        if (state == 2) ladybird_v_skia_set_rounded_rect_underlay(rect, 246, 246, 254, 255);
        if (state == 3) {
            assert(!draw(nullptr));
            ladybird_v_skia_set_rounded_rect_underlay(rect, 246, 246, 254, 255);
        }
        if (state == 4) {
            ladybird_v_skia_set_rounded_rect_underlay(nullptr, 0, 0, 0, 0);
        }
        ladybird_v_skia_set_unrounded_paint_color(border);
        assert(draw(context));
        if (recording) ladybird_v_skia_finish_shared_recording();
        CGContextFlush(context);
        // Opaque draws use the root tile. Transparent leaf fallback uses its
        // 2px-padded conservative stroke bounds (6,8)-(54,52); surface extent affects coverage.
        int left = (recording || (grid && opaque)) ? 0 : 6 * scale, top = (recording || (grid && opaque)) ? 0 : 8 * scale;
        int rw = (recording || (grid && opaque)) ? pw : 48 * scale, rh = (recording || (grid && opaque)) ? ph : 44 * scale;
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(rw, rh));
        canvas->clear(opaque ? SK_ColorWHITE : SK_ColorTRANSPARENT);
        // An independent harmless curve selects the multisampled pass only
        // for the corresponding production mode.
        SkPath curve; curve.moveTo(0, 0); curve.cubicTo(.01f, .001f, 0, .01f, .01f, .01f);
        curve.lineTo(.005f, .002f); curve.close();
        SkPaint noop; noop.setAntiAlias(true); noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
        if (msaa) canvas->drawPath(curve, noop);
        canvas->scale(scale, scale);
        if (!recording && (!grid || !opaque)) canvas->translate(-6, -8);
        SkPaint paint; paint.setAntiAlias(true);
        if ((recording || !msaa) && !state) paint.setColor4f({background[0], background[1], background[2], background[3]});
        else paint.setColor(SkColorSetARGB(255, 246, 246, 254));
        if (state != 4)
            canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(10, 12, 40, 36), 4, 4), paint);
        paint.setColor4f({border[0], border[1], border[2], border[3]});
        paint.setStyle(SkPaint::kStroke_Style); paint.setStrokeWidth(1);
        canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(10.5, 12.5, 39, 35), 3.5, 3.5), paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint8_t> expected(size_t(rw) * rh * 4);
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(expected.data(), rw, rh, rw * 4,
            bytes->data(), bytes->size(), identity));
        if (recording && !state) {
            // The typed native backend also retains optional components in
            // its public descriptor, independently of the leaf fallback.
            VoxGraphiteShape shape {};
            shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
            float stroke_rect[] {10.5, 12.5, 39, 35, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5, 3.5};
            std::copy_n(stroke_rect, 12, shape.rect);
            shape.thickness = 1; shape.anti_alias = 1; shape.force_msaa = msaa;
            shape.has_float_color = shape.has_underlay = shape.has_float_underlay_color = 1;
            std::copy_n(border, 4, shape.float_color);
            std::copy_n(rect, 12, shape.underlay_rect);
            std::copy_n(background, 4, shape.underlay_float_color);
            std::vector<uint8_t> typed(expected.size(), opaque ? 255 : 0);
            assert(graphite_shape_draw()(typed.data(), pw, ph, pw * 4, opaque, &shape));
            assert(typed == expected); ++typed_cases;
        }
        if (!recording && (!grid || !opaque)) {
            // Publish the independently painted leaf through Quartz too: its
            // premultiplied-alpha conversion is part of the native endpoint.
            std::vector<uint8_t> published(actual.size(), opaque ? 255 : 0);
            auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            auto control = CGBitmapContextCreate(published.data(), pw, ph, 8, pw * 4,
                color_space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            CGColorSpaceRelease(color_space); assert(control);
            CGContextScaleCTM(control, scale, scale);
            std::vector<uint32_t> patch(size_t(rw) * rh);
            std::memcpy(patch.data(), expected.data(), expected.size());
            assert(composite_pixels(control, std::move(patch), rw, rh, 6, height - 52, 48, 44, opaque));
            CGContextFlush(control); CGContextRelease(control);
            expected.resize(actual.size());
            swap_red_blue_pixels(expected.data(), published.data(), size_t(pw) * ph);
            left = top = 0; rw = pw; rh = ph;
        }
        int differences = 0;
        for (int y = 0; y < ph; ++y) for (int x = 0; x < pw; ++x)
            for (int c = 0; c < 4; ++c) {
                bool inside = x >= left && x < left + rw && y >= top && y < top + rh;
                uint8_t target = inside ? expected[(size_t(y - top) * rw + x - left) * 4
                    + (c == 0 ? 2 : c == 2 ? 0 : c)] : 0;
                differences += actual[(size_t(y) * pw + x) * 4 + c] != target;
            }
        if (differences) std::fprintf(stderr,
            "grid=%d msaa=%d scale=%d alpha=%g opaque=%d recording=%d state=%d different bytes=%d\n", grid, msaa, scale, alpha, opaque, recording, state, differences);
        assert(!differences);
        CGContextRelease(context); ++cases;
    }
    int mixed_cases = check_mixed_sample_tiles();
    std::printf("PASS: %d shared/fallback underlay and reset cases; %d typed GPU colors; %d mixed-mode tiles match complete pictures\n", cases, typed_cases, mixed_cases);
}
