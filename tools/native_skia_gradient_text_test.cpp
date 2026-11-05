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
    assert(ladybird_v_skia_begin_isolated_input(context, css_w, css_h));
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
    assert(ladybird_v_skia_begin_isolated_input(context, css_w, css_h));
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
    CGContextRelease(context);
    CGColorSpaceRelease(color_space);
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
    unsetenv("VOX_CACHE_GRADIENT_TEXT"); unsetenv("VOX_DISABLE_PICTURE_REGIONS");
    std::cout << "Gradient text cache: " << cases << " exact cold/warm frames, changed mask/color/backdrop, region modes and 1x/2x passed\n";
    std::cout << "Retained text mask ownership, fallback and GPU composition passed\n";
}
