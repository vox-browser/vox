// A translated SVG mask must blend each path with its existing mask pixels.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    void* library = nullptr;
    if (auto name = std::getenv("VOX_SVG_MASK_BACKDROP_REFERENCE_LIBRARY")) {
        library = dlopen(name, RTLD_NOW | RTLD_LOCAL); assert(library);
    }
    auto resolve = [&]<typename T>(char const* name, T current) {
        auto value = library ? reinterpret_cast<T>(dlsym(library, name)) : current;
        assert(value); return value;
    };
    auto set_painting = resolve("ladybird_v_skia_set_chromium_painting", &ladybird_v_skia_set_chromium_painting);
    auto set_recording = resolve("ladybird_v_skia_set_shared_recording", &ladybird_v_skia_set_shared_recording);
    auto set_layer = resolve("ladybird_v_skia_set_raster_layer", &ladybird_v_skia_set_raster_layer);
    auto draw_path = resolve("ladybird_v_skia_draw_svg_path", &ladybird_v_skia_draw_svg_path);
    constexpr int canvas_height = 128, left = 24, top = 32, width = 64, height = 64;
    int cases = 0, guards = 0;
    for (int scale : {1, 2}) for (int alpha : {0, 128, 255})
    for (bool colored : {false, true}) for (bool stroke : {false, true})
    for (float phase : {0.f, .25f, .5f, .75f}) {
        int pw = width * scale, ph = height * scale, pitch = pw * 4 + 16;
        std::vector<uint8_t> actual(size_t(pitch) * ph, 0xa5);
        for (int y = 0; y < ph; ++y) for (int x = 0; x < pw; ++x) {
            size_t i = size_t(y) * pitch + x * 4;
            actual[i] = (colored ? 159 : 255) * alpha / 255;
            actual[i + 1] = (colored ? 207 : 255) * alpha / 255;
            actual[i + 2] = (colored ? 239 : 255) * alpha / 255;
            actual[i + 3] = alpha;
        }
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto context = CGBitmapContextCreate(actual.data(), pw, ph, 8, pitch, space,
            CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(space); assert(context);
        CGContextScaleCTM(context, scale, scale);
        CGContextTranslateCTM(context, -left, -(canvas_height - top - height));
        set_painting(1);
        set_recording(0, 128, canvas_height);
        set_layer(0, 0, 1);
        float data[4 * 12] {};
        float points[][2] {{30 + phase, 38.5f}, {78 + phase, 38.5f}, {54 + phase, 88.5f}};
        SkPath path;
        for (int i = 0; i < 3; ++i) {
            data[i * 12] = i ? 1 : 0;
            data[i * 12 + 1] = points[i][0]; data[i * 12 + 2] = points[i][1];
            if (i) path.lineTo(points[i][0], points[i][1]); else path.moveTo(points[i][0], points[i][1]);
        }
        data[36] = 5; path.close();
        // Assemble a complete mask independently, retaining its premultiplied
        // backdrop as an image in the same GPU pass as the black path.
        std::vector<uint32_t> backdrop(size_t(pw) * ph);
        for (int y = 0; y < ph; ++y)
            swap_red_blue_pixels(reinterpret_cast<uint8_t*>(backdrop.data() + size_t(y) * pw),
                actual.data() + size_t(y) * pitch, pw);
        auto info = SkImageInfo::Make(pw, ph, kBGRA_8888_SkColorType,
            kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
        auto background = SkImages::RasterFromPixmapCopy(SkPixmap(info, backdrop.data(), pw * 4));
        assert(background);
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(pw, ph));
        canvas->drawImage(background, 0, 0);
        canvas->scale(scale, scale); canvas->translate(-left, -top);
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(SK_ColorBLACK);
        if (stroke) { paint.setStyle(SkPaint::kStroke_Style); paint.setStrokeWidth(1); }
        canvas->drawPath(path, paint);
        SkSerialProcs procs; procs.fImageProc = serialize_shared_picture_image;
        auto bytes = recorder.finishRecordingAsPicture()->serialize(&procs);
        std::vector<uint32_t> expected(size_t(pitch / 4) * ph, 0xa5a5a5a5);
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(bytes && shared_picture_draw()(reinterpret_cast<uint8_t*>(expected.data()),
            pw, ph, pitch, bytes->data(), bytes->size(), identity));
        assert(draw_path(context, data, 4, 0, 1, 0, 0, 1, 0, 0,
            0, 0, 0, 128, canvas_height, 0, 0, 0, 255, !stroke,
            0, 0, 0, 255, stroke, 1, 0, 0, 4, 0, nullptr, 0, 0, 1));
        CGContextFlush(context);
        std::vector<uint8_t> rgba(actual.size());
        swap_red_blue_pixels(rgba.data(), reinterpret_cast<uint8_t*>(expected.data()), expected.size());
        if (actual != rgba) {
            int count = 0;
            for (size_t i = 0; i < actual.size(); ++i) if (actual[i] != rgba[i]) {
                if (count++ < 6) std::fprintf(stderr, "mask pixel %zu,%zu channel=%zu actual=%u expected=%u\n",
                    i % pitch / 4, i / pitch, i % 4, actual[i], rgba[i]);
            }
            std::fprintf(stderr, "scale=%d alpha=%d colored=%d stroke=%d phase=%g differing bytes=%d\n",
                scale, alpha, colored, stroke, phase, count);
            return 1;
        }
        std::vector<uint32_t> scratch(16 * 16);
        RasterRegion region {30, 38, 46, 54};
        assert(copy_svg_path_backdrop(context, region, scale, canvas_height, 16, 16, scratch)); ++guards;
        CGContextSaveGState(context); CGContextTranslateCTM(context, .25 / scale, 0);
        assert(!copy_svg_path_backdrop(context, region, scale, canvas_height, 16, 16, scratch)); ++guards;
        CGContextRestoreGState(context);
        assert(!copy_svg_path_backdrop(context, {0, 0, 16, 16}, scale, canvas_height, 16, 16, scratch)); ++guards;
        CGContextRelease(context); ++cases;
    }
    set_painting(0);
    std::printf("PASS: %d translated mask draws match complete GPU masks; %d mapping guards pass\n", cases, guards);
}
