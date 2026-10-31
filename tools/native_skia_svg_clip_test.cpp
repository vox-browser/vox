// Compare SVG publication with independently clipped complete Dawn rasters.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    void* library = nullptr;
    if (auto path = std::getenv("VOX_SVG_CLIP_REFERENCE_LIBRARY")) {
        library = dlopen(path, RTLD_NOW | RTLD_LOCAL); assert(library);
    }
    auto resolve = [&]<typename T>(char const* name, T current) {
        auto value = library ? reinterpret_cast<T>(dlsym(library, name)) : current;
        assert(value); return value;
    };
    auto set_painting = resolve("ladybird_v_skia_set_chromium_painting", &ladybird_v_skia_set_chromium_painting);
    auto set_recording = resolve("ladybird_v_skia_set_shared_recording", &ladybird_v_skia_set_shared_recording);
    auto set_layer = resolve("ladybird_v_skia_set_raster_layer", &ladybird_v_skia_set_raster_layer);
    auto set_size = resolve("ladybird_v_skia_set_raster_layer_size", &ladybird_v_skia_set_raster_layer_size);
    auto set_grid = resolve("ladybird_v_skia_set_msaa_grid", &ladybird_v_skia_set_msaa_grid);
    auto add_clip = resolve("ladybird_v_skia_add_shared_rounded_clip", &ladybird_v_skia_add_shared_rounded_clip);
    auto draw_batch = resolve("ladybird_v_skia_draw_svg_path_batch", &ladybird_v_skia_draw_svg_path_batch);
    int cases = 0, guards = 0;
    constexpr int width = 1024, height = 852;
    float identity[] {1, 0, 0, 1, 0, 0};
    for (bool root : {false, true}) for (int scale : {1, 2})
    for (uint32_t background : {0U, 0xffffffffU, 0xfff5faf0U})
    for (bool rounded : {false, true}) for (float phase : {0.f, .25f, .5f, .875f}) {
        int pw = width * scale, ph = height * scale, pitch = pw * 4;
        std::vector<uint8_t> actual(size_t(pitch) * ph);
        for (size_t i = 0; i < actual.size(); i += 4) {
            actual[i] = background >> 16; actual[i + 1] = background >> 8;
            actual[i + 2] = background; actual[i + 3] = background >> 24;
        }
        auto expected = actual;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), pw, ph, 8, pitch, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context); CGContextScaleCTM(context, scale, scale); return context;
        };
        auto destination = make(actual), control = make(expected);
        CGColorSpaceRelease(space);
        set_painting(1); set_recording(0, width, height);
        set_layer(0, root ? 0 : 56, root); set_size(root ? width : 164, root ? 3343 : 839);
        int cell = 0; set_grid(&cell, 1, (root ? 1024 : 192) * scale,
            (root ? 256 : 800) * scale, 1);
        float clip[] {34, 675, 97, 96, 0, 0, 0, 0, 0, 0, 0, 0};
        CGContextSaveGState(destination);
        for (int duplicate = 0; duplicate < 2; ++duplicate) {
            std::fill_n(clip + 4, 8, rounded && !duplicate ? 12.f : 0.f);
            add_clip(destination, clip, identity);
            auto bounds = CGRectMake(34, height - 771, 97, 96);
            if (rounded && !duplicate) {
                auto path = CGPathCreateWithRoundedRect(bounds, 12, 12, nullptr);
                CGContextAddPath(destination, path); CGContextClip(destination); CGPathRelease(path);
            } else CGContextClipToRect(destination, bounds);
        }
        auto original_clip = CGContextGetClipBoundingBox(destination);
        if (!library) { assert(svg_batch_has_complete_raster_clips(destination, width, height, scale)); ++guards; }
        float rectangle[5 * 12] {}, curve[4 * 12] {};
        float points[][2] {{0, 0}, {30.1483f, 0}, {30.1483f, 29.9926f}, {0, 29.9926f}};
        for (int i = 0; i < 4; ++i) {
            rectangle[i * 12] = i ? 1 : 0;
            rectangle[i * 12 + 1] = points[i][0]; rectangle[i * 12 + 2] = points[i][1];
        }
        rectangle[4 * 12] = 5;
        curve[1] = 5; curve[2] = 40;
        curve[12] = 3; curve[13] = 25; curve[14] = 66;
        curve[15] = 30; curve[16] = 43; curve[17] = 10; curve[18] = 65;
        curve[24] = 1; curve[25] = 15; curve[26] = 45; curve[36] = 5;
        VoxGraphitePath paths[2] {};
        paths[0].segments = rectangle; paths[0].segment_count = 5;
        paths[1].segments = curve; paths[1].segment_count = 4;
        for (int i = 0; i < 2; ++i) {
            auto& p = paths[i]; p.matrix[0] = p.matrix[4] = p.matrix[8] = 1;
            p.matrix[2] = i ? 34 : (rounded ? 34.2148f : 64.2148f) + phase; p.matrix[5] = 675;
            p.red = i ? 57 : 255; p.green = i ? 10 : 204; p.blue = i ? 145 : 0;
            p.alpha = 255; p.opacity = 1; p.has_float_alpha = 1;
        }
        assert(draw_batch(destination, paths, 2, identity, 32, 673, 66, 70,
            0, 0, 0, width, height, 1, nullptr));
        assert(CGRectEqualToRect(original_clip, CGContextGetClipBoundingBox(destination)));
        CGContextRestoreGState(destination);

        int tw = (root ? 1024 : 164) * scale, th = (root ? 256 : 839) * scale;
        int origin_y = root ? 508 : 56;
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(tw, th));
        canvas->clear(root ? background : SK_ColorTRANSPARENT);
        canvas->scale(scale, scale); canvas->translate(0, -origin_y);
        if (rounded) canvas->clipRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(34, 675, 97, 96), 12, 12), true);
        canvas->clipRect(SkRect::MakeXYWH(34, 675, 97, 96), false);
        canvas->clipRect(SkRect::MakeXYWH(34, 675, 97, 96), true);
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SkColorSetRGB(255, 204, 0));
        canvas->drawRect(SkRect::MakeXYWH((rounded ? 34.2148f : 64.2148f) + phase, 675, 30.1483f, 29.9926f), paint);
        SkPath path;
        path.moveTo(39, 715); path.cubicTo(64, 718, 44, 740, 59, 741); path.lineTo(49, 720); path.close();
        paint.setColor(SkColorSetRGB(57, 10, 145)); canvas->drawPath(path, paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        assert(bytes);
        float matrix[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        std::vector<uint32_t> pixels(size_t(tw) * th);
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()), tw, th,
            tw * 4, bytes->data(), bytes->size(), matrix));
        assert(composite_pixels(control, std::move(pixels), tw, th, 0,
            height - origin_y - float(th) / scale, float(tw) / scale, float(th) / scale, root));
        CGContextFlush(destination); CGContextFlush(control);
        if (actual != expected) {
            auto mismatch = std::mismatch(actual.begin(), actual.end(), expected.begin());
            auto i = size_t(mismatch.first - actual.begin());
            std::fprintf(stderr, "root=%d scale=%d background=%08x rounded=%d phase=%g at=%zu,%zu channel=%zu actual=%u expected=%u\n",
                root, scale, background, rounded, phase, i / 4 % pw, i / 4 / pw, i % 4, *mismatch.first, *mismatch.second);
            return 1;
        }
        CGContextRelease(destination); CGContextRelease(control); ++cases;
    }
    if (!library) {
        std::vector<uint8_t> pixels(160 * 120 * 4);
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(pixels.data(), 160, 120, 8, 160 * 4, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context);
        auto eligible = [&] { return svg_batch_has_complete_raster_clips(context, 160, 120, 1); };
        set_recording(0, 160, 120);
        assert(!eligible()); ++guards; // An implicit Quartz clip is insufficient.
        float clip[] {20, 20, 100, 80, 0, 0, 0, 0, 0, 0, 0, 0};
        add_clip(context, clip, identity);
        CGContextClipToRect(context, CGRectMake(20, 20, 100, 80));
        assert(eligible()); ++guards;
        assert(!svg_batch_has_complete_raster_clips(context, 159, 120, 1)); ++guards;
        assert(!svg_batch_has_complete_raster_clips(context, 160, 120, 2)); ++guards;
        CGContextSaveGState(context);
        CGContextClipToRect(context, CGRectMake(30, 30, 60, 40));
        assert(!eligible()); ++guards; // Preserve a narrower untracked clip.
        CGContextRestoreGState(context);
        CGContextSaveGState(context); CGContextTranslateCTM(context, 1, 0);
        assert(!eligible()); ++guards; CGContextRestoreGState(context);
        ladybird_v_skia_save_shared_clip(context);
        ladybird_v_skia_block_shared_clip(context);
        assert(!eligible()); ++guards; // Path/mask callers mark nonrectangular state.
        ladybird_v_skia_restore_shared_clip(context);
        assert(eligible()); ++guards;
        ladybird_v_skia_save_shared_clip(context);
        float skew[] {1, .25f, 0, 1, 0, 0}; add_clip(context, clip, skew);
        assert(!eligible()); ++guards; ladybird_v_skia_restore_shared_clip(context);
        ladybird_v_skia_save_shared_clip(context);
        clip[2] = 0; add_clip(context, clip, identity);
        assert(!eligible()); ++guards; ladybird_v_skia_restore_shared_clip(context);
        assert(eligible()); ++guards;
        CGContextRelease(context);
    }
    std::printf("PASS: %d clipped SVG batches match complete Dawn rasters; %d eligibility checks pass\n", cases, guards);
}
