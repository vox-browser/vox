// A compositor picture must rasterize in local coordinates at every page offset.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static void icon(SkCanvas* canvas)
{
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetRGB(137, 173, 80));
    canvas->drawOval(SkRect::MakeXYWH(27, 20, 32, 32), paint);
    SkPath path;
    path.moveTo(35, 31); path.lineTo(47, 41); path.lineTo(48, 31); path.close();
    paint.setColor(SK_ColorWHITE);
    canvas->drawPath(path, paint);
}

static std::vector<uint32_t> reference(int scale, bool background, int alpha)
{
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(268, 220));
    SkPaint paint;
    paint.setAntiAlias(true);
    if (background) {
        paint.setColor(SkColorSetARGB(alpha, 252, 253, 255));
        canvas->drawRect(SkRect::MakeWH(268.1875f, 220), paint);
    }
    paint.setColor(SkColorSetARGB(alpha, 0, 0, 0));
    canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(25, 120, 218, 40), 8, 8), paint);
    icon(canvas);
    auto bytes = recorder.finishRecordingAsPicture()->serialize();
    std::vector<uint32_t> pixels(268 * 220 * scale * scale);
    float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
    assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()),
        268 * scale, 220 * scale, 268 * scale * 4, bytes->data(), bytes->size(), matrix));
    return pixels;
}

static void root_background(int scale)
{
    constexpr int width = 512, height = 512;
    int pitch = width * scale * 4;
    std::vector<uint8_t> actual(size_t(pitch) * height * scale), expected;
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto destination = CGBitmapContextCreate(actual.data(), width * scale, height * scale,
        8, pitch, space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(destination);
    CGContextScaleCTM(destination, scale, scale);
    CGContextSetRGBFillColor(destination, 1, 1, 1, 1);
    CGContextFillRect(destination, CGRectMake(0, 0, width, height));
    ladybird_v_skia_set_shared_recording(1, width, height);
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_record_rect(destination, 0, 0, width, height, 255, 255, 255, 255);
    // The browser selects the root again after painting the frame background.
    ladybird_v_skia_set_raster_layer(0, 0, 1);
    ladybird_v_skia_set_raster_layer_size(width, height);
    ladybird_v_skia_set_root_raster_scroll_y(0);
    int cell = 0;
    ladybird_v_skia_set_msaa_grid(&cell, 1, 256, 256, 3 * scale);
    CGContextSetRGBFillColor(destination, 0, 1, 0, 1);
    CGContextFillRect(destination, CGRectMake(0, height - 100, 100, 100));
    CGContextFlush(destination);
    expected = actual;
    auto* canvas = shared_recording_canvas(destination);
    assert(canvas);
    SkPaint paint;
    paint.setColor(SK_ColorGREEN);
    canvas->drawRect(SkRect::MakeWH(100, 100), paint);
    shared_recording_content(destination, SkRect::MakeWH(100, 100), 0, 0);
    ladybird_v_skia_finish_shared_recording();
    CGContextFlush(destination);
    assert(actual == expected);
    CGContextRelease(destination);
}

static void shadow_overflow(int scale, bool switch_layer)
{
    constexpr int width = 1024, height = 852;
    constexpr float x = 46, y = 312, page_y = 60, scroll_y = 13.25f;
    constexpr float box_width = 268, box_height = 220;
    int pitch = width * scale * 4;
    std::vector<uint8_t> actual(size_t(pitch) * height * scale), expected(actual);
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto make = [&](auto& pixels) {
        auto context = CGBitmapContextCreate(pixels.data(), width * scale, height * scale,
            8, pitch, space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(context); CGContextScaleCTM(context, scale, scale); return context;
    };
    auto destination = make(actual), control = make(expected);
    CGColorSpaceRelease(space);
    ladybird_v_skia_set_shared_recording(0, width, height);
    ladybird_v_skia_set_raster_layer(x, y, 0);
    ladybird_v_skia_set_raster_layer_size(box_width, box_height);
    int cell = 0;
    ladybird_v_skia_set_msaa_grid(&cell, 1, 270 * scale, 222 * scale, 1);
    ladybird_v_skia_set_layer_shared_recording(1);
    for (auto blur : {20.f, 1.f})
        assert(ladybird_v_skia_draw_outer_box_shadow(destination,
            x, y + 4, box_width, box_height, 0, 0, 0, 0, 0, 0, 0, 0,
            x, y, box_width, box_height, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 0, 0, 1, 0, 0, 0, page_y, scroll_y, width, height,
            blur, 41, 42, 46, 20, 0));
    assert(ladybird_v_skia_draw_rounded_rect(destination, x, y,
        box_width, box_height, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 0, 0, 1, 0, 0, 0, page_y, scroll_y, width, height,
        255, 255, 255, 255, 1, 0, 1, 0));
    if (switch_layer) ladybird_v_skia_set_raster_layer(0, 0, 1);
    else ladybird_v_skia_finish_shared_recording();
    assert(!s_shared_root_recording);

    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
    auto box = SkRect::MakeXYWH(x, y + page_y - scroll_y, box_width, box_height);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(20, 41, 42, 46));
    for (auto blur : {20.f, 1.f}) {
        canvas->save();
        canvas->clipRect(box, SkClipOp::kDifference, true);
        paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, blur / 2));
        canvas->drawRect(box.makeOffset(0, 4), paint);
        canvas->restore();
    }
    paint.setMaskFilter(nullptr);
    paint.setColor(SK_ColorWHITE);
    canvas->drawRect(box, paint);
    auto bytes = recorder.finishRecordingAsPicture()->serialize();
    std::vector<uint32_t> pixels(size_t(width) * height * scale * scale);
    float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
    assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()),
        width * scale, height * scale, pitch, bytes->data(), bytes->size(), matrix));
    composite_pixels(control, std::move(pixels), width * scale, height * scale,
        0, 0, width, height, true);
    CGContextFlush(destination); CGContextFlush(control);
    assert(actual == expected);
    // The tails beyond the compositor box must come from the same picture.
    size_t outside = (size_t(int((y + page_y - scroll_y + box_height + 4) * scale))
        * width * scale + int((x + box_width / 2) * scale)) * 4 + 3;
    assert(actual[outside] > 0);
    CGContextRelease(destination); CGContextRelease(control);
}

int main()
{
    assert(shared_picture_draw() && graphite_shape_draw());
    ladybird_v_skia_set_chromium_painting(1);
    for (int scale : {1, 2}) {
        root_background(scale);
        for (bool switch_layer : {false, true}) shadow_overflow(scale, switch_layer);
    }
    int comparisons = 0;
    for (int scale : {1, 2}) for (int x : {46, 346, 746})
    for (int y : {32, 312, 492}) for (bool background : {false, true})
    for (int alpha : {128, 255}) for (bool switch_layer : {false, true}) {
        constexpr int width = 1024, height = 852;
        constexpr float page_y = 60, scroll_y = 13.25f;
        auto top = y + page_y - scroll_y;
        int pitch = width * scale * 4;
        std::vector<uint8_t> actual(size_t(pitch) * height * scale), expected(actual);
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), width * scale, height * scale,
                8, pitch, space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context); CGContextScaleCTM(context, scale, scale); return context;
        };
        auto destination = make(actual), control = make(expected);
        CGColorSpaceRelease(space);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0, width, height);
        ladybird_v_skia_set_raster_layer(x, y, 0);
        ladybird_v_skia_set_raster_layer_size(268, 220);
        int cell = 0;
        ladybird_v_skia_set_msaa_grid(&cell, 1, 270 * scale, 222 * scale, 1);
        ladybird_v_skia_set_layer_shared_recording(1);
        if (background)
            ladybird_v_skia_record_rect(destination, x, height - top - 220,
                268.1875f, 220, 252, 253, 255, alpha);
        assert(ladybird_v_skia_draw_rounded_rect(destination, x + 25, y + 120,
            218, 40, 8, 8, 8, 8, 8, 8, 8, 8, 1, 0, 0, 1, 0, 0,
            0, page_y, scroll_y, width, height, 0, 0, 0, alpha, 1, 0, 1, 0));
        auto* canvas = shared_recording_canvas(destination);
        assert(canvas && s_shared_root_recording && !s_shared_root_recording->root);
        canvas->save(); canvas->translate(x, top); icon(canvas); canvas->restore();
        shared_recording_content(destination, SkRect::MakeXYWH(x + 27, top + 20, 32, 32), page_y, scroll_y);
        if (switch_layer) ladybird_v_skia_set_raster_layer(0, 0, 1);
        else ladybird_v_skia_finish_shared_recording();
        assert(!s_shared_root_recording);
        composite_pixels(control, reference(scale, background, alpha), 268 * scale,
            220 * scale, x, height - top - 220, 268, 220, true);
        CGContextFlush(destination); CGContextFlush(control);
        if (actual != expected) {
            size_t differences = 0;
            for (size_t i = 0; i < actual.size(); ++i) if (actual[i] != expected[i]) {
                if (differences++ < 5) std::cerr << " byte=" << i << " expected="
                    << int(expected[i]) << " actual=" << int(actual[i]) << '\n';
            }
            std::cerr << "Local layer mismatch scale=" << scale << " x=" << x << " y=" << y
                << " background=" << background << " alpha=" << alpha
                << " switch=" << switch_layer << " differences=" << differences << '\n';
            return 1;
        }
        // Unsupported content must leave the ordinary leaf pixels intact.
        ladybird_v_skia_set_raster_layer(x, y, 0);
        ladybird_v_skia_set_raster_layer_size(268, 220);
        ladybird_v_skia_set_layer_shared_recording(1);
        assert(shared_recording_canvas(destination));
        shared_recording_content(destination, SkRect::MakeXYWH(x, top, 32, 32), page_y, scroll_y);
        shared_recording_block(SkRect::MakeXYWH(x, top, 32, 32));
        ladybird_v_skia_finish_shared_recording();
        CGContextFlush(destination);
        assert(actual == expected);
        CGContextRelease(destination); CGContextRelease(control);
        ++comparisons;
    }
    ladybird_v_skia_set_chromium_painting(0);
    std::cout << comparisons << " local compositor pictures match; root backgrounds and blocked fallback pixels preserved\n";
}
