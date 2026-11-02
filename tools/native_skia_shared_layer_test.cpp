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
    int tile_width = 270 * scale, tile_height = 222 * scale;
    std::vector<uint32_t> tile(size_t(tile_width) * tile_height);
    float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
    assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(tile.data()),
        tile_width, tile_height, tile_width * 4, bytes->data(), bytes->size(), matrix));
    std::vector<uint32_t> pixels(268 * 220 * scale * scale);
    for (int y = 0; y < 220 * scale; ++y)
        std::copy_n(tile.data() + size_t(y) * tile_width, 268 * scale,
            pixels.data() + size_t(y) * 268 * scale);
    return pixels;
}

// Assemble the expected viewport from independently rasterized full tiles.
// Exercise both tile axes, border ownership, and a clipped/scrolled layer.
static void tiled_layer(int scale, int scroll_y, bool projected_root_scroll = false)
{
    constexpr int width = 704, height = 512, x = 17, y = 37;
    constexpr int layer_width = 534, layer_height = 892;
    int top = y - scroll_y;
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
    SkPictureRecorder recorder;
    auto* reference_canvas = recorder.beginRecording(SkRect::MakeWH(layer_width, layer_height));
    auto draw = [](SkCanvas* canvas) {
        SkPaint paint; paint.setAntiAlias(true);
        for (int row = 0; row < 4; ++row) {
            paint.setColor(SkColorSetRGB(0, 119, 255));
            canvas->drawRRect(SkRRect::MakeRectXY(
                SkRect::MakeXYWH(247, 201 + row * 220, 218, 40), 8, 8), paint);
            canvas->save(); canvas->translate(245, 190 + row * 220); icon(canvas); canvas->restore();
        }
    };
    draw(reference_canvas);
    auto bytes = recorder.finishRecordingAsPicture()->serialize();
    int tile_width = 270 * scale, tile_height = 222 * scale;
    ladybird_v_skia_set_shared_recording(0, width, height);
    ladybird_v_skia_set_root_raster_scroll_y(projected_root_scroll ? scroll_y : 0);
    ladybird_v_skia_set_raster_layer(x, y, 0);
    ladybird_v_skia_set_raster_layer_size(layer_width, layer_height);
    int cell = 0;
    ladybird_v_skia_set_msaa_grid(&cell, 1, tile_width, tile_height, 2);
    ladybird_v_skia_set_layer_shared_recording(1);
    auto* canvas = shared_recording_canvas(destination);
    assert(canvas);
    canvas->translate(x, top); draw(canvas);
    shared_recording_content(destination, SkRect::MakeXYWH(x, top, layer_width, layer_height),
        0, projected_root_scroll ? 0 : scroll_y);
    ladybird_v_skia_finish_shared_recording();
    ladybird_v_skia_set_root_raster_scroll_y(0);

    int first_y = std::max(0, -top) * scale;
    int visible_height = std::min(layer_height * scale - first_y,
        (height - std::max(0, top)) * scale);
    int output_width = layer_width * scale;
    std::vector<uint32_t> pixels(size_t(output_width) * visible_height);
    for (int row = 0; row * (tile_height - 2) < first_y + visible_height; ++row) {
        for (int column = 0; column < 2; ++column) {
            int ox = column * (tile_width - 2), oy = row * (tile_height - 2);
            float matrix[] {float(scale), 0, float(-ox), 0, float(scale), float(-oy), 0, 0, 1};
            std::vector<uint32_t> tile(size_t(tile_width) * tile_height);
            assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(tile.data()),
                tile_width, tile_height, tile_width * 4, bytes->data(), bytes->size(), matrix));
            int left = column == 0 ? 0 : ox + 1;
            int right = std::min(output_width, ox + tile_width - 1);
            int begin = std::max(first_y, row == 0 ? 0 : oy + 1);
            int end = std::min(first_y + visible_height, oy + tile_height - 1);
            for (int py = begin; py < end; ++py)
                std::copy_n(tile.data() + size_t(py - oy) * tile_width + left - ox,
                    right - left, pixels.data() + size_t(py - first_y) * output_width + left);
        }
    }
    composite_pixels(control, std::move(pixels), output_width, visible_height,
        x, height - std::max(0, top) - float(visible_height) / scale,
        layer_width, float(visible_height) / scale, true);
    CGContextFlush(destination); CGContextFlush(control);
    if (actual != expected)
        std::cerr << "Tiled layer differs: scale=" << scale << " scroll=" << scroll_y << '\n';
    assert(actual == expected);
    CGContextRelease(destination); CGContextRelease(control);
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

// Split compositor pictures must sample the parent before fallback painting,
// then round each picture's SrcOver independently, including translucent parents.
static void backdrop_layers(int scale, int alpha, bool switch_layer, bool backdrop_hint)
{
    constexpr int width = 96, height = 80;
    const int pixel_width = width * scale, pixel_height = height * scale;
    std::vector<uint8_t> actual(size_t(pixel_width) * pixel_height * 4), expected;
    for (size_t i = 0; i < actual.size(); i += 4) {
        actual[i] = 97 * alpha / 255;
        actual[i + 1] = 151 * alpha / 255;
        actual[i + 2] = 223 * alpha / 255;
        actual[i + 3] = alpha;
    }
    expected = actual;
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto destination = CGBitmapContextCreate(actual.data(), pixel_width, pixel_height,
        8, pixel_width * 4, space, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(destination);
    CGContextScaleCTM(destination, scale, scale);
    ladybird_v_skia_set_shared_recording(0, width, height);
    // Offscreen parents resume after child effects with this hint disabled.
    // Their already-painted prefix must survive the following picture too.
    ladybird_v_skia_set_shared_layer_backdrop(backdrop_hint);
    for (int layer = 0; layer < 2; ++layer) {
        ladybird_v_skia_set_raster_layer(8 + layer * 4, 8 + layer * 4, 0);
        ladybird_v_skia_set_raster_layer_size(72, 56);
        int cell = 0;
        ladybird_v_skia_set_msaa_grid(&cell, 1, 74 * scale, 58 * scale, 1);
        ladybird_v_skia_set_layer_shared_recording(1);
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
        for (int leaf = 0; leaf < 2; ++leaf) {
            float x = 8 + layer * 4 + leaf * 7, y = 8 + layer * 4 + leaf * 5;
            int r = 41 + leaf * 70, g = 42 + layer * 80, b = 46 + leaf * 60, a = 20 + leaf * 85;
            assert(ladybird_v_skia_draw_rounded_rect(destination, x, y, 60, 44,
                8, 8, 8, 8, 8, 8, 8, 8, 1, 0, 0, 1, 0, 0, 0, 0, 0,
                width, height, r, g, b, a, 1, 0, 1, 0));
            SkPaint paint; paint.setAntiAlias(true); paint.setColor(SkColorSetARGB(a, r, g, b));
            canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(x, y, 60, 44), 8, 8), paint);
        }
        shared_recording_content(destination,
            SkRect::MakeXYWH(8 + layer * 4, 8 + layer * 4, 72, 56), 0, 0);
        if (switch_layer) ladybird_v_skia_set_raster_layer(0, 0, 1);
        else ladybird_v_skia_finish_shared_recording();
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint32_t> pixels(size_t(pixel_width) * pixel_height);
        float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()), pixel_width,
            pixel_height, pixel_width * 4, bytes->data(), bytes->size(), matrix));
        auto* source = reinterpret_cast<uint8_t const*>(pixels.data());
        for (size_t i = 0; i < expected.size(); i += 4) {
            float remaining = 1.f - float(source[i + 3]) / 255.f;
            for (int channel = 0; channel < 4; ++channel) {
                int bgra = channel == 0 ? 2 : channel == 2 ? 0 : channel;
                float value = std::fma(float(expected[i + channel]) / 255.f, remaining,
                    float(source[i + bgra]) / 255.f);
                expected[i + channel] = uint8_t(std::nearbyint(double(value) * 255.));
            }
        }
    }
    ladybird_v_skia_set_shared_layer_backdrop(0);
    CGContextFlush(destination);
    if (actual != expected) {
        std::cerr << "Backdrop layers differ: scale=" << scale
            << " alpha=" << alpha << " switch=" << switch_layer
            << " backdrop_hint=" << backdrop_hint << '\n';
        size_t count = 0;
        for (size_t i = 0; i < actual.size(); ++i) {
            if (actual[i] == expected[i]) continue;
            if (count++ < 12) std::cerr << "  " << i / 4 % pixel_width << ','
                << i / 4 / pixel_width << " channel=" << i % 4
                << " actual=" << int(actual[i]) << " expected=" << int(expected[i]) << '\n';
        }
        std::cerr << "  differing channels=" << count << '\n';
    }
    assert(actual == expected);
    CGContextRelease(destination);
}

static void clipped_layer(int scale, bool blocked)
{
    constexpr int width = 512, height = 512;
    constexpr float page_y = 60, scroll_y = 13.25f;
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
    ladybird_v_skia_set_raster_layer(0, 0, 0);
    ladybird_v_skia_set_raster_layer_size(width, height);
    int cell = 0;
    ladybird_v_skia_set_msaa_grid(&cell, 1, 258 * scale, 258 * scale, 1);
    ladybird_v_skia_set_layer_shared_recording(1);
    // Clip state exists before the first draw and is independent of other contexts.
    float outer[] {20, 30, 280, 240, 0, 0, 0, 0, 0, 0, 0, 0};
    float rounded[] {50, 50, 180, 120, 20, 12, 9, 9, 18, 24, 0, 0};
    float transform[] {.819152f, .573576f, -.573576f, .819152f, 100, page_y - scroll_y};
    float identity[] {1, 0, 0, 1, 0, page_y - scroll_y};
    ladybird_v_skia_save_shared_clip(destination);
    ladybird_v_skia_add_shared_rounded_clip(destination, outer, identity);
    ladybird_v_skia_save_shared_clip(destination);
    ladybird_v_skia_add_shared_rounded_clip(destination, rounded, transform);
    assert(!s_shared_clips[destination].unsupported);
    if (blocked) ladybird_v_skia_block_shared_clip(destination);
    assert(ladybird_v_skia_draw_rounded_rect(destination, 0, 0, 400, 400,
        8, 8, 8, 8, 8, 8, 8, 8, 1, 0, 0, 1, 0, 0, 0, page_y, scroll_y,
        width, height, 137, 173, 80, 255, 1, 0, 1, 0));
    shared_recording_content(destination, SkRect::MakeWH(400, 400), page_y, scroll_y);
    assert(s_shared_root_recording->destination == destination);
    ladybird_v_skia_save_shared_clip(control);
    ladybird_v_skia_block_shared_clip(control);
    ladybird_v_skia_restore_shared_clip(destination);
    assert(!s_shared_clips[destination].unsupported);
    ladybird_v_skia_record_rect(destination, 260, height - 90 - page_y + scroll_y, 80, 20, 80, 40, 170, 255);
    ladybird_v_skia_restore_shared_clip(destination);
    ladybird_v_skia_restore_shared_clip(control);
    assert(s_shared_clips.empty());
    if (blocked) {
        CGContextFlush(destination); expected = actual;
    } else {
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
        canvas->translate(0, page_y - scroll_y);
        canvas->clipRect(SkRect::MakeXYWH(20, 30, 280, 240), true);
        canvas->save();
        canvas->setMatrix(SkMatrix::MakeAll(transform[0], transform[2], transform[4],
            transform[1], transform[3], transform[5], 0, 0, 1));
        SkVector radii[] {{20, 12}, {9, 9}, {18, 24}, {0, 0}};
        SkRRect clip; clip.setRectRadii(SkRect::MakeXYWH(50, 50, 180, 120), radii);
        canvas->clipRRect(clip, true);
        canvas->setMatrix(SkMatrix::Translate(0, page_y - scroll_y));
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SkColorSetRGB(137, 173, 80));
        canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeWH(400, 400), 8, 8), paint);
        canvas->restore();
        paint.setColor(SkColorSetRGB(80, 40, 170));
        canvas->drawRect(SkRect::MakeXYWH(260, 70, 80, 20), paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint32_t> pixels(size_t(width) * height * scale * scale);
        float matrix[] {float(scale), 0, 0, 0, float(scale), 0, 0, 0, 1};
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()), width * scale,
            height * scale, pitch, bytes->data(), bytes->size(), matrix));
        composite_pixels(control, std::move(pixels), width * scale, height * scale,
            0, 0, width, height, true);
    }
    ladybird_v_skia_finish_shared_recording();
    CGContextFlush(destination); CGContextFlush(control);
    if (actual != expected) {
        size_t differences = 0;
        for (size_t i = 0; i < actual.size(); ++i) if (actual[i] != expected[i]) {
            if (differences++ < 8) std::cerr << " clip byte=" << i << " expected="
                << int(expected[i]) << " actual=" << int(actual[i]) << '\n';
        }
        std::cerr << "Clipped layer scale=" << scale << " blocked=" << blocked
            << " differences=" << differences << '\n';
    }
    assert(actual == expected);
    CGContextRelease(destination); CGContextRelease(control);
}

static void gradient_layer(int scale, int kind, bool stroke, bool batch, bool linear)
{
    constexpr int width = 256, height = 256;
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
    float segments[] {
        0, 20, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 200, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 200, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 20, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    float stops[] { .2f, .8f, .1f, 1, 0, .9f, .3f, .2f, .4f, .45f,
        .1f, .2f, .9f, .8f, 1 };
    VoxGraphitePath path {};
    path.segments = segments; path.segment_count = 5; path.alpha = 255;
    path.stroke = stroke; path.stroke_width = 7; path.miter_limit = 4;
    path.line_cap = 1; path.line_join = 1;
    path.gradient = kind; path.stop_count = 3; path.stops = stops;
    path.opacity = .625f; path.linear_color_space = linear;
    float local[] { .95f, -.1f, 14, .1f, .95f, 4, 0, 0, 1 };
    std::copy_n(local, 9, path.matrix);
    float gradient[] { .9f, .05f, 2, -.05f, 1, 3, 0, 0, 1 };
    std::copy_n(gradient, 9, path.gradient_matrix);
    float points[] { 30, 40, kind == 1 ? 190.f : 0.f, kind == 1 ? 160.f : 100.f, 100, 130 };
    std::copy_n(points, 6, path.gradient_points);
    ladybird_v_skia_set_shared_recording(0, width, height);
    ladybird_v_skia_set_raster_layer(0, 0, 0);
    ladybird_v_skia_set_raster_layer_size(width, height);
    int cell = 0;
    ladybird_v_skia_set_msaa_grid(&cell, 1, 258 * scale, 258 * scale, 1);
    ladybird_v_skia_set_layer_shared_recording(1);
    if (batch) {
        float outer[] {1, 0, 0, 1, 0, 0};
        assert(ladybird_v_skia_draw_svg_path_batch(destination, &path, 1, outer,
            0, 0, width, height, 0, 0, 0, width, height, 0, nullptr));
    } else {
        assert(draw_svg_gradient_path(destination, segments, 5, 0,
            local[0], local[3], local[1], local[4], local[2], local[5],
            0, 0, 0, width, height, stroke, 7, 1, 1, 4,
            gradient[0], gradient[3], gradient[1], gradient[4], gradient[2], gradient[5],
            0, linear, stops, 3, .625f, kind, points, 0, nullptr, nullptr,
            [&](auto const&, auto const&, auto, auto const&) { return chromium_svg_gradient_shader(path); }));
    }
    assert(s_shared_root_recording && !s_shared_root_recording->replay_bounds.empty());
    ladybird_v_skia_finish_shared_recording();
    // The independent descriptor renderer uses the current Chromium Skia API.
    // This checks the serialized old-Skia shader and paint against that path.
    for (int i = 0; i < 6; ++i) path.matrix[i] *= scale;
    std::vector<uint32_t> pixels(size_t(width) * height * scale * scale);
    assert(graphite_path_draw()(reinterpret_cast<uint8_t*>(pixels.data()),
        width * scale, height * scale, pitch, 0, &path));
    composite_pixels(control, std::move(pixels), width * scale, height * scale,
        0, 0, width, height, true);
    CGContextFlush(destination); CGContextFlush(control);
    if (actual != expected) {
        size_t count = 0;
        for (size_t i = 0; i < actual.size(); ++i) count += actual[i] != expected[i];
        std::cerr << "Gradient mismatch scale=" << scale << " kind=" << kind
            << " stroke=" << stroke << " batch=" << batch << " linear=" << linear
            << " bytes=" << count << '\n';
        assert(actual == expected);
    }
    CGContextRelease(destination); CGContextRelease(control);
}

static void invalid_gradient_batch()
{
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(100, 100));
    VoxGraphitePath paths[2] {};
    paths[1].gradient = 1; // No stops: reject before recording even the first path.
    assert(!record_chromium_svg_path_batch(canvas, paths, 2, SkMatrix::I(),
        SkRect::MakeWH(100, 100), nullptr));
    assert(recorder.finishRecordingAsPicture()->approximateOpCount() == 0);
}

int main()
{
    assert(shared_picture_draw() && graphite_shape_draw());
    ladybird_v_skia_set_chromium_painting(1);
    invalid_gradient_batch();
    for (int scale : {1, 2}) for (int kind : {1, 2}) for (bool stroke : {false, true})
    for (bool batch : {false, true}) for (bool linear : {false, true})
        gradient_layer(scale, kind, stroke, batch, linear);
    for (int scale : {1, 2}) {
        for (int scroll : {0, 151}) {
            tiled_layer(scale, scroll);
            tiled_layer(scale, scroll, true);
        }
        for (int alpha : {0, 64, 128, 224, 255}) for (bool switch_layer : {false, true})
        for (bool backdrop_hint : {false, true})
            backdrop_layers(scale, alpha, switch_layer, backdrop_hint);
        root_background(scale);
        clipped_layer(scale, false);
        clipped_layer(scale, true);
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
