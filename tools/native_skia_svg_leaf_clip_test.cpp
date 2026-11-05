// A clipped leaf must match one complete GPU picture, including viewport AA.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static void check_clip_intersections()
{
    // Only tracked geometry is inspected here; no bitmap or GPU is needed.
    auto context = reinterpret_cast<CGContextRef>(uintptr_t(1));
    auto shape = SkRect::MakeXYWH(20, 20, 10, 10);
    assert(!svg_leaf_intersects_raster_clip(context, shape));
    SharedClip clip {SkRRect::MakeRect(SkRect::MakeXYWH(10, 10, 40, 40)), SkMatrix::I()};
    s_shared_clips[context].clips.push_back(clip);
    assert(!svg_leaf_intersects_raster_clip(context, shape));
    auto near = SkRect::MakeXYWH(10.75f, 20, 5, 5);
    assert(svg_leaf_intersects_raster_clip(context, near, 1));
    assert(!svg_leaf_intersects_raster_clip(context, near, 2));
    assert(svg_leaf_intersects_raster_clip(context, SkRect::MakeXYWH(5, 20, 20, 10)));
    assert(svg_leaf_intersects_raster_clip(context, SkRect::MakeXYWH(20, 5, 10, 20)));
    assert(svg_leaf_intersects_raster_clip(context, SkRect::MakeXYWH(40, 20, 20, 10)));
    assert(svg_leaf_intersects_raster_clip(context, SkRect::MakeXYWH(20, 40, 10, 20)));
    assert(!svg_leaf_intersects_raster_clip(context, SkRect::MakeXYWH(60, 20, 10, 10)));
    // A containing outer clip must not hide an intersecting inner clip.
    clip.rect = SkRRect::MakeRect(SkRect::MakeXYWH(25, 10, 25, 40));
    s_shared_clips[context].clips.push_back(clip);
    assert(svg_leaf_intersects_raster_clip(context, shape));
    clip.rect = SkRRect::MakeRect(SkRect::MakeXYWH(70, 70, 10, 10));
    s_shared_clips[context].clips.push_back(clip);
    assert(!svg_leaf_intersects_raster_clip(context, shape));
    s_shared_clips[context].clips.clear();
    clip.rect = SkRRect::MakeRectXY(SkRect::MakeXYWH(10, 10, 40, 40), 12, 12);
    s_shared_clips[context].clips.push_back(clip);
    assert(!svg_leaf_intersects_raster_clip(context, shape));
    assert(svg_leaf_intersects_raster_clip(context, SkRect::MakeXYWH(11, 11, 4, 4)));
    // Geometry is in canvas space, whereas retained clips have local bounds.
    clip.matrix = SkMatrix::MakeAll(-2, 0, 150, 0, 3, .375f, 0, 0, 1);
    s_shared_clips[context].clips = {clip};
    assert(!svg_leaf_intersects_raster_clip(context, clip.matrix.mapRect(shape)));
    assert(svg_leaf_intersects_raster_clip(context,
        clip.matrix.mapRect(SkRect::MakeXYWH(11, 11, 4, 4))));
    s_shared_clips.erase(context);
}

static void check_pixel_exact_cuts()
{
    // A rectangular cut on whole device pixels masks Quartz pixels completely.
    auto context = reinterpret_cast<CGContextRef>(uintptr_t(2));
    auto crossing = SkRect::MakeXYWH(5, 20, 20, 10);
    SharedClip clip {SkRRect::MakeRect(SkRect::MakeXYWH(10, 10, 40, 40)), SkMatrix::I()};
    s_shared_clips[context].clips = {clip};
    assert(svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 1));
    assert(svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 2));
    clip.rect = SkRRect::MakeRect(SkRect::MakeXYWH(10.25f, 10, 40, 40));
    s_shared_clips[context].clips = {clip};
    assert(!svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 1));
    assert(!svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 2));
    assert(svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 4));
    // Only crossed edges matter: a fractional edge the leaf does not reach.
    clip.rect = SkRRect::MakeRect(SkRect::MakeLTRB(10, 10, 50.5f, 50));
    s_shared_clips[context].clips = {clip};
    assert(svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 1));
    assert(!svg_leaf_clip_cuts_are_pixel_exact(context, SkRect::MakeXYWH(40, 20, 20, 10), 1));
    // A containing clip with fractional edges does not cut the leaf.
    s_shared_clips[context].clips = {SharedClip {SkRRect::MakeRect(SkRect::MakeXYWH(0.25f, 0.25f, 99, 99)),
        SkMatrix::I()}, SharedClip {SkRRect::MakeRect(SkRect::MakeXYWH(10, 10, 40, 40)), SkMatrix::I()}};
    assert(svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 1));
    // Rounded corners, skewed and fractionally translated clips keep GPU coverage.
    clip.rect = SkRRect::MakeRectXY(SkRect::MakeXYWH(10, 10, 40, 40), 4, 4);
    clip.matrix = SkMatrix::I();
    s_shared_clips[context].clips = {clip};
    assert(!svg_leaf_clip_cuts_are_pixel_exact(context, crossing, 1));
    clip.rect = SkRRect::MakeRect(SkRect::MakeXYWH(10, 10, 40, 40));
    clip.matrix = SkMatrix::MakeAll(1, .25f, 0, 0, 1, 0, 0, 0, 1);
    s_shared_clips[context].clips = {clip};
    assert(!svg_leaf_clip_cuts_are_pixel_exact(context, clip.matrix.mapRect(crossing), 1));
    clip.matrix = SkMatrix::MakeAll(-2, 0, 150, 0, 3, .375f, 0, 0, 1);
    s_shared_clips[context].clips = {clip};
    assert(!svg_leaf_clip_cuts_are_pixel_exact(context,
        clip.matrix.mapRect(SkRect::MakeXYWH(20, 5, 10, 20)), 1));
    assert(svg_leaf_clip_cuts_are_pixel_exact(context,
        clip.matrix.mapRect(SkRect::MakeXYWH(5, 20, 20, 10)), 1));
    s_shared_clips.erase(context);
}

static void check_glyph_device_clips()
{
    // A glyph tile may apply rectangular clips itself only when every edge lies
    // on a device pixel and Quartz clips to exactly the tracked rectangle.
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    for (float scale : {1.f, 2.f}) {
        auto context = CGBitmapContextCreate(nullptr, 200, 200, 8, 800, space,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        assert(context);
        CGContextScaleCTM(context, scale, scale);
        float canvas_height = 200 / scale;
        auto quartz = [&](SkRect r) {
            CGContextClipToRect(context, CGRectMake(r.left(), canvas_height - r.bottom(), r.width(), r.height()));
        };
        SkIRect device;
        assert(!glyph_bitmap_device_clip(context, scale, canvas_height, device));
        auto cell = SkRect::MakeLTRB(10.5f, 10, 50.5f, 30);
        CGContextSaveGState(context);
        quartz(cell);
        s_shared_clips[context].clips = {SharedClip {SkRRect::MakeRect(cell), SkMatrix::I()}};
        assert(glyph_bitmap_device_clip(context, scale, canvas_height, device) == (scale == 2));
        if (scale == 2) assert(device == SkIRect::MakeLTRB(21, 20, 101, 60));
        // Nested rectangles use their intersection.
        auto inner = SkRect::MakeLTRB(0, 15, 30, 80);
        quartz(inner);
        s_shared_clips[context].clips.push_back(SharedClip {SkRRect::MakeRect(inner), SkMatrix::I()});
        assert(glyph_bitmap_device_clip(context, scale, canvas_height, device) == (scale == 2));
        if (scale == 2) assert(device == SkIRect::MakeLTRB(21, 30, 60, 60));
        // Rounded, skewed, untracked or unsupported clips keep the composited path.
        s_shared_clips[context].clips.back().rect = SkRRect::MakeRectXY(inner, 2, 2);
        assert(!glyph_bitmap_device_clip(context, scale, canvas_height, device));
        s_shared_clips[context].clips.back().rect = SkRRect::MakeRect(inner);
        s_shared_clips[context].clips.back().matrix = SkMatrix::MakeAll(1, .25f, 0, 0, 1, 0, 0, 0, 1);
        assert(!glyph_bitmap_device_clip(context, scale, canvas_height, device));
        s_shared_clips[context].clips.pop_back();
        assert(!glyph_bitmap_device_clip(context, scale, canvas_height, device));
        s_shared_clips[context].clips = {SharedClip {SkRRect::MakeRect(cell), SkMatrix::I()}};
        s_shared_clips[context].unsupported = true;
        assert(!glyph_bitmap_device_clip(context, scale, canvas_height, device));
        s_shared_clips.erase(context);
        CGContextRestoreGState(context);
        CGContextRelease(context);
    }
    CGColorSpaceRelease(space);
}

int main()
{
    check_clip_intersections();
    check_pixel_exact_cuts();
    check_glyph_device_clips();
    constexpr int width = 320, height = 240;
    int cases = 0, pixel_exact_cuts = 0;
    for (int scale : {1, 2}) for (float phase : {.125f, .372f, .5f, .875f})
    for (bool contained : {false, true}) for (int placement : {0, 1, 2, 3}) {
        bool clipped = placement != 0;
        int pw = width * scale, ph = height * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4, 255), expected = actual;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto c = CGBitmapContextCreate(pixels.data(), pw, ph, 8, pw * 4, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(c); CGContextScaleCTM(c, scale, scale); return c;
        };
        auto context = make(actual), control = make(expected);
        CGColorSpaceRelease(space);
        ladybird_v_skia_set_chromium_painting(1);
        ladybird_v_skia_set_shared_recording(0, width, height);
        ladybird_v_skia_set_raster_layer(0, 0, 1);
        ladybird_v_skia_set_raster_layer_size(width, height);
        int cell = 0;
        ladybird_v_skia_set_msaa_grid(&cell, 1, width * scale, 256 * scale, 1);
        float clip[] {15, 66, 240, 74, 0, 0, 0, 0, 0, 0, 0, 0};
        float matrix[] {1, 0, 0, 1, 0, phase};
        for (int duplicate = 0; duplicate < (contained ? 2 : 1); ++duplicate) {
            clip[3] = duplicate ? 74.125f : 74;
            ladybird_v_skia_add_shared_rounded_clip(context, clip, matrix);
            CGContextClipToRect(context, CGRectMake(15, height - 66 - clip[3] - phase, 240, clip[3]));
        }
        float path[4 * 12] {};
        path[1] = 39;
        path[2] = placement == 0 ? 80 : placement == 1 ? 66.257385f : placement == 2 ? 66 : 66.125f;
        path[12] = 1; path[13] = 46; path[14] = path[2];
        path[24] = 1; path[25] = 39; path[26] = placement == 1 ? 145 : 90;
        path[36] = 5;
        auto bounds = path_from_serialized_segments(path, 4).getBounds();
        bounds.offset(0, phase);
        assert(svg_leaf_intersects_raster_clip(context, bounds, scale) == clipped);
        // Whole-pixel cuts take the ordinary leaf path; it must still match.
        pixel_exact_cuts += clipped && svg_leaf_clip_cuts_are_pixel_exact(context, bounds, scale);
        assert(ladybird_v_skia_draw_svg_path(context, path, 4, 0,
            1, 0, 0, 1, 0, phase, 0, 0, 0, width, height,
            44, 0, 34, 255, 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, nullptr, 0, 0, 1));
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(pw, 256 * scale);
        canvas->clear(SK_ColorWHITE); canvas->scale(scale, scale); canvas->translate(0, phase);
        canvas->clipRect(SkRect::MakeXYWH(15, 66, 240, 74), true);
        if (contained) canvas->clipRect(SkRect::MakeXYWH(15, 66, 240, 74.125f), true);
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SkColorSetRGB(44, 0, 34));
        canvas->drawPath(path_from_serialized_segments(path, 4), paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        std::vector<uint32_t> gpu(size_t(pw) * 256 * scale);
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(gpu.data()), pw, 256 * scale,
            pw * 4, bytes->data(), bytes->size(), identity));
        assert(composite_pixels(control, std::move(gpu), pw, 256 * scale,
            0, height - 256, width, 256, true));
        CGContextFlush(context); CGContextFlush(control);
        if (actual != expected) {
            int differences = 0;
            for (size_t i = 0; i < actual.size(); i += 4)
                differences += !std::equal(actual.data() + i, actual.data() + i + 4, expected.data() + i);
            std::fprintf(stderr, "scale=%d phase=%g containing=%d placement=%d differences=%d\n", scale, phase, contained, placement, differences);
            return 1;
        }
        CGContextRelease(context); CGContextRelease(control); ++cases;
    }
    assert(pixel_exact_cuts > 0);
    std::printf("PASS: %d contained/clipped SVG leaves match complete GPU pictures"
        " (%d cut on whole device pixels)\n", cases, pixel_exact_cuts);
}
