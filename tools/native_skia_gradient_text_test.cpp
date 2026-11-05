#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static std::vector<uint32_t> cached_text_frame(bool cache, bool regional, int scale, bool changed_mask,
    bool changed_color, bool changed_backdrop, float phase)
{
    if (cache) setenv("VOX_CACHE_GRADIENT_TEXT", "1", 1);
    else unsetenv("VOX_CACHE_GRADIENT_TEXT");
    if (regional) unsetenv("VOX_DISABLE_PICTURE_REGIONS");
    else setenv("VOX_DISABLE_PICTURE_REGIONS", "1", 1);
    constexpr int css_w = 80, css_h = 64;
    int width = css_w * scale, height = css_h * scale;
    std::vector<uint32_t> pixels(size_t(width) * height);
    auto* rows = reinterpret_cast<uint8_t*>(pixels.data());
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        auto* p = rows + (y * width + x) * 4;
        p[0] = (x * 3 + y + changed_backdrop) % 128;
        p[1] = (x + y * 5) % 128; p[2] = (x * 7 + y * 3) % 128; p[3] = 255;
    }
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    assert(context); CGColorSpaceRelease(color);
    CGContextScaleCTM(context, scale, scale);
    s_chromium_painting = true;
    assert(ladybird_v_skia_begin_gradient_text_input(context, css_w, css_h));
    auto* mask_canvas = isolated_input_recording_canvas(context);
    SkPaint mask_paint; mask_paint.setColor(changed_mask ? 0x70000000 : 0xe0000000); mask_paint.setAntiAlias(true);
    mask_canvas->drawRoundRect(SkRect::MakeXYWH(9 + phase, 11.5, 37, 29), 4.5, 3.5, mask_paint);
    auto face = font_manager()->matchFamilyStyle("Arial", SkFontStyle());
    assert(face);
    SkFont font(face, 12);
    mask_canvas->drawSimpleText(changed_mask ? "V1" : "V0", 2, SkTextEncoding::kUTF8,
        10 + phase, 28, font, mask_paint);
    s_isolated_input_recordings[context]->bounds = SkRect::MakeWH(css_w, css_h);
    auto* mask = ladybird_v_skia_take_isolated_input(context);
    assert(ladybird_v_skia_begin_gradient_text_input(context, css_w, css_h));
    auto* content = s_isolated_input_recordings[context].get();
    content->bounds = SkRect::MakeWH(css_w, css_h);
    SkPoint points[] {{0, 0}, {css_w, css_h}};
    SkColor colors[] {changed_color ? SK_ColorBLUE : SK_ColorRED, SK_ColorGREEN};
    SkPaint gradient;
    gradient.setShader(SkGradientShader::MakeLinear(points, colors, nullptr, 2, SkTileMode::kClamp));
    content->recorder.getRecordingCanvas()->drawRect(SkRect::MakeWH(css_w, css_h), gradient);
    assert(ladybird_v_skia_draw_gradient_text(context, mask, context,
        css_w, css_h, scale, 4, 6, 56, 51));
    assert(s_isolated_input_recordings.empty());
    CGContextFlush(context); CGContextRelease(context);
    return pixels;
}

static std::vector<uint8_t> deferred_text_frame(bool defer, int scale, float phase,
    bool unsupported = false)
{
    constexpr int w = 80, h = 64;
    std::vector<uint8_t> output(w * h * scale * scale * 4), mask(output.size()), content(output.size());
    for (size_t i = 0; i < output.size(); i += 4) {
        output[i] = 37; output[i+1] = 61; output[i+2] = 89; output[i+3] = 255;
    }
    auto original = output;
    auto make_context = [&](auto& pixels) {
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto ctx = CGBitmapContextCreate(pixels.data(), w * scale, h * scale, 8, w * scale * 4,
            color, CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        assert(ctx); CGColorSpaceRelease(color); CGContextScaleCTM(ctx, scale, scale);
        return ctx;
    };
    auto destination = make_context(output), mask_context = make_context(mask), source = make_context(content);
    if (defer) setenv("VOX_DEFER_GRADIENT_TEXT_INPUTS", "1", 1);
    else unsetenv("VOX_DEFER_GRADIENT_TEXT_INPUTS");
    ladybird_v_skia_begin_deferred_layer_frame(0);
    ladybird_v_skia_set_shared_recording(0, w, h);
    assert(ladybird_v_skia_begin_gradient_text_input(mask_context, w, h));
    bool omitted = isolated_input_defers_leaf_raster(mask_context);
    assert(omitted == (defer && !s_gradient_text_deferral_abandoned));
    if (!s_typefaces[RegularFont])
        s_typefaces[RegularFont] = font_manager()->matchFamilyStyle("Arial", SkFontStyle());
    auto* face = select_typeface("", 0, 400, 0); assert(face);
    uint16_t glyphs[] {face->unicharToGlyph('V'), face->unicharToGlyph('0')};
    double positions[] {0, 0, 12, 0};
    assert(ladybird_v_skia_draw_glyph_run(mask_context, "", 0, glyphs, positions, 2,
        16, 400, 0, 10 + phase, 30, 1, 0, 0, 1, 0, 0, 0, 0, 0, w, h, 255, 255, 255, 255, 16));
    CGContextFlush(mask_context);
    auto empty = [](auto const& pixels) {
        return std::all_of(pixels.begin(), pixels.end(), [](auto byte) { return byte == 0; });
    };
    assert(empty(mask) == omitted);
    auto* input = ladybird_v_skia_take_isolated_input(mask_context);
    assert(ladybird_v_skia_begin_gradient_text_input(source, w, h));
    assert(ladybird_v_skia_draw_rounded_rect(source, 0, 0, w, h, 0,0,0,0,0,0,0,0,
        1,0,0,1,0,0,0,0,0,w,h, 173,37,91,255,1,0,0,0));
    CGContextFlush(source);
    assert(empty(content) == omitted);
    if (unsupported) ladybird_v_skia_block_shared_clip(source);
    int drawn = ladybird_v_skia_draw_gradient_text(source, input, destination, w, h, scale, 0, 0, w, h);
    assert(drawn == !unsupported);
    bool completed = ladybird_v_skia_finish_deferred_layer_frame();
    assert(completed == !(omitted && unsupported));
    if (unsupported) assert(output == original);
    CGContextRelease(destination); CGContextRelease(mask_context); CGContextRelease(source);
    return output;
}

int main()
{
    auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    std::vector<uint32_t> pixels(64 * 64, 0xff123456);
    auto context = CGBitmapContextCreate(pixels.data(), 64, 64, 8, 64 * 4,
        color_space, static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedLast)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Big));
    assert(context);
    s_chromium_painting = false;
    assert(!ladybird_v_skia_begin_isolated_input(context, 64, 64));
    assert(!ladybird_v_skia_take_isolated_input(context));
    s_chromium_painting = true;
    assert(shared_picture_draw());
    assert(!ladybird_v_skia_begin_isolated_input(context, 0, 64));
    for (bool unsupported : {false, true}) {
        assert(ladybird_v_skia_begin_isolated_input(context, 64, 64));
        auto* mask_canvas = isolated_input_recording_canvas(context);
        SkPaint opaque;
        opaque.setColor(SK_ColorBLACK);
        mask_canvas->drawRect(SkRect::MakeXYWH(8, 8, 16, 16), opaque);
        s_isolated_input_recordings[context]->bounds = SkRect::MakeWH(64, 64);
        auto* mask = ladybird_v_skia_take_isolated_input(context);
        assert(mask && !isolated_input_recording_canvas(context));
        // CoreGraphics may reuse the released mask's address for the content.
        assert(ladybird_v_skia_begin_isolated_input(context, 64, 64));
        auto* content = s_isolated_input_recordings[context].get();
        content->bounds = SkRect::MakeWH(64, 64);
        if (unsupported) ladybird_v_skia_block_shared_clip(context);
        content->recorder.getRecordingCanvas()->clear(SK_ColorRED);
        auto before = pixels;
        int result = ladybird_v_skia_draw_gradient_text(context, mask, context,
            64, 64, 1, 0, 0, 64, 64);
        assert(s_isolated_input_recordings.empty());
        assert(result == !unsupported);
        if (unsupported) {
            assert(before == pixels);
        } else {
            auto* bytes = reinterpret_cast<uint8_t*>(pixels.data());
            assert(bytes[(12 * 64 + 12) * 4] == 255);
            assert(bytes[(12 * 64 + 12) * 4 + 1] == 0);
            assert(pixels[0] == before[0]);
        }
    }
    assert(ladybird_v_skia_begin_isolated_input(context, 64, 64));
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(context));
    assert(s_isolated_input_recordings.empty());
    ladybird_v_skia_discard_isolated_input(nullptr);
    s_shared_clips.erase(context);
    unsigned cases = 0;
    for (bool regional : {false, true}) for (int scale : {1, 2})
        for (bool mask : {false, true}) for (bool color : {false, true})
        for (bool backdrop : {false, true}) for (float phase : {0.f, .25f}) {
            auto reference = cached_text_frame(false, regional, scale, mask, color, backdrop, phase);
            auto cold = cached_text_frame(true, regional, scale, mask, color, backdrop, phase);
            auto hits = s_gradient_text_raster_cache_hits;
            auto warm = cached_text_frame(true, regional, scale, mask, color, backdrop, phase);
            assert(reference == cold && reference == warm);
            assert(s_gradient_text_raster_cache_hits == hits + 1);
            ++cases;
        }
    s_gradient_text_raster_cache.clear();
    for (bool regional : {false, true}) for (int scale : {1, 2}) for (float phase : {0.f, .25f}) {
        unsetenv("VOX_SHARED_PICTURE_TYPEFACES");
        auto expected = cached_text_frame(false, regional, scale, false, false, false, phase);
        setenv("VOX_SHARED_PICTURE_TYPEFACES", "1", 1);
        assert(cached_text_frame(false, regional, scale, false, false, false, phase) == expected);
        // An explicit transport override must retain the embedded-font path.
        setenv("VOX_DISABLE_SHARED_PICTURE_PIXELS", "1", 1);
        assert(cached_text_frame(false, regional, scale, false, false, false, phase) == expected);
        unsetenv("VOX_DISABLE_SHARED_PICTURE_PIXELS");
    }
    unsetenv("VOX_SHARED_PICTURE_TYPEFACES");
    for (int scale : {1, 2}) for (float phase : {0.f, .25f, .5f, .75f}) {
        unsetenv("VOX_REUSE_DAWN_REGION_RECORDER");
        auto reference = cached_text_frame(false, true, scale, false, true, false, phase);
        setenv("VOX_REUSE_DAWN_REGION_RECORDER", "1", 1);
        auto first = cached_text_frame(false, true, scale, false, true, false, phase);
        auto reused = cached_text_frame(false, true, scale, false, true, false, phase);
        assert(reference == first && reference == reused);
    }
    unsetenv("VOX_REUSE_DAWN_REGION_RECORDER");
    for (int scale : {1, 2}) for (float phase : {0.f, .25f, .5f, .75f}) {
        auto expected = deferred_text_frame(false, scale, phase);
        assert(deferred_text_frame(true, scale, phase) == expected);
    }
    deferred_text_frame(true, 2, .25f, true);
    assert(s_gradient_text_deferral_abandoned);
    assert(deferred_text_frame(true, 2, .25f) == deferred_text_frame(false, 2, .25f));
    // Discarded mask inputs also invalidate the transaction, even before the
    // compositor is called, so their omitted pixels cannot be published.
    s_gradient_text_deferral_abandoned = false;
    setenv("VOX_DEFER_GRADIENT_TEXT_INPUTS", "1", 1);
    ladybird_v_skia_begin_deferred_layer_frame(0);
    assert(ladybird_v_skia_begin_gradient_text_input(context, 64, 64));
    assert(isolated_input_defers_leaf_raster(context));
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(context));
    assert(!ladybird_v_skia_finish_deferred_layer_frame() && s_gradient_text_deferral_abandoned);
    s_gradient_text_deferral_abandoned = false;
    ladybird_v_skia_begin_deferred_layer_frame(0);
    assert(ladybird_v_skia_begin_gradient_text_input(context, 64, 64));
    auto* unfinished = ladybird_v_skia_take_isolated_input(context);
    assert(!ladybird_v_skia_finish_deferred_layer_frame());
    ladybird_v_skia_begin_deferred_layer_frame(0);
    assert(ladybird_v_skia_begin_gradient_text_input(context, 64, 64));
    assert(!isolated_input_defers_leaf_raster(context));
    ladybird_v_skia_discard_isolated_input(unfinished);
    ladybird_v_skia_discard_isolated_input(ladybird_v_skia_take_isolated_input(context));
    assert(ladybird_v_skia_finish_deferred_layer_frame());
    CGContextRelease(context);
    CGColorSpaceRelease(color_space);
    unsetenv("VOX_DEFER_GRADIENT_TEXT_INPUTS");
    unsetenv("VOX_CACHE_GRADIENT_TEXT"); unsetenv("VOX_DISABLE_PICTURE_REGIONS");
    std::cout << "Gradient text cache: " << cases << " exact cold/warm frames, changed mask/color/backdrop, region modes and 1x/2x passed\n";
    std::cout << "Retained text mask ownership, fallback and GPU composition passed\n";
    std::cout << "Gradient text deferral: eight exact glyph/shape scenes, untouched input bitmaps, rejection and ordinary retry passed\n";
}
