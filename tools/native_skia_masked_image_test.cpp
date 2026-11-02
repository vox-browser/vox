// Independent complete raster references for the atomic image/mask API.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    void* library = nullptr;
    if (auto name = std::getenv("VOX_MASKED_IMAGE_REFERENCE_LIBRARY")) {
        library = dlopen(name, RTLD_NOW | RTLD_LOCAL); assert(library);
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
    auto background = resolve("ladybird_v_skia_set_image_background", &ladybird_v_skia_set_image_background);
    auto draw = resolve("ladybird_v_skia_draw_rgba_image", &ladybird_v_skia_draw_rgba_image);
    constexpr int width = 160, height = 120, tile_height = 128;
    int cases = 0;
    for (bool clipped : {false, true}) for (int scale : {1, 2}) for (int image_alpha : {113, 255})
    for (int background_alpha : {0, 128, 255}) for (int radius : {4, 10})
    for (float phase : {0.f, .25f, .5f}) {
        int pw = width * scale, ph = height * scale;
        std::vector<uint8_t> actual(size_t(pw) * ph * 4);
        for (size_t i = 0; i < actual.size(); i += 4) {
            actual[i] = 252; actual[i + 1] = 253; actual[i + 2] = 255; actual[i + 3] = 255;
        }
        auto expected = actual;
        auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& bytes) {
            auto context = CGBitmapContextCreate(bytes.data(), pw, ph, 8, pw * 4, space,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context); CGContextScaleCTM(context, scale, scale); return context;
        };
        auto destination = make(actual), control = make(expected); CGColorSpaceRelease(space);
        if (clipped) {
            auto bounds = CGRectMake(35, height - 61, 14, 15);
            CGContextClipToRect(destination, bounds); CGContextClipToRect(control, bounds);
        }
        auto original_clip = CGContextGetClipBoundingBox(destination);
        painting(1); recording(0, width, height); layer(0, 0, 1); size(width, 1000);
        grid(nullptr, 0, pw, tile_height * scale, 1);
        std::vector<uint8_t> source(20 * 20 * 4);
        for (int y = 0; y < 20; ++y) for (int x = 0; x < 20; ++x) {
            auto* p = source.data() + (y * 20 + x) * 4;
            p[0] = x * 9; p[1] = y * 7; p[2] = 180; p[3] = image_alpha;
        }
        float radii[8]; std::fill_n(radii, 8, float(radius));
        background(35, 72, 119, background_alpha);
        assert(draw(destination, source.data(), 20, 20, 80, 34 + phase, 45, 20, 20,
            0, 0, 20, 20, 34 + phase, 45, 20, 20, 1, 0, 0, 1, 0, 0,
            0, 0, 0, width, height, 1, 0, 2 | VOX_GRAPHITE_IMAGE_ROUNDED_ALPHA_MASK, radii));

        auto info = SkImageInfo::Make(20, 20, kRGBA_8888_SkColorType,
            kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
        auto image = SkImages::RasterFromPixmapCopy(SkPixmap(info, source.data(), 80)); assert(image);
        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(pw, tile_height * scale));
        canvas->clear(SkColorSetRGB(252, 253, 255)); canvas->scale(scale, scale);
        auto bounds = SkRect::MakeXYWH(34 + phase, 45, 20, 20);
        auto rounded = SkRRect::MakeRectXY(bounds, radius, radius);
        canvas->saveLayer(bounds, nullptr); canvas->save();
        canvas->clipRRect(rounded, true);
        SkPaint paint; paint.setAntiAlias(true);
        paint.setColor(SkColorSetARGB(background_alpha, 35, 72, 119));
        canvas->drawRect(bounds, paint);
        paint.setColor(SK_ColorWHITE);
        canvas->translate(34 + phase, 45);
        canvas->drawImageRect(image, SkRect::MakeWH(20, 20), SkSamplingOptions(SkFilterMode::kLinear), &paint);
        canvas->restore();
        paint.setBlendMode(SkBlendMode::kDstIn); paint.setAntiAlias(false);
        canvas->saveLayer(bounds, &paint);
        paint.setBlendMode(SkBlendMode::kSrcOver); paint.setAntiAlias(true);
        canvas->drawRRect(rounded, paint); canvas->restore(); canvas->restore();
        SkSerialProcs procs; procs.fImageProc = serialize_shared_picture_image;
        auto bytes = recorder.finishRecordingAsPicture()->serialize(&procs); assert(bytes);
        std::vector<uint32_t> raster(size_t(pw) * tile_height * scale);
        float matrix[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(shared_picture_draw()(reinterpret_cast<uint8_t*>(raster.data()), pw,
            tile_height * scale, pw * 4, bytes->data(), bytes->size(), matrix));
        assert(composite_pixels(control, std::move(raster), pw, tile_height * scale,
            0, height - tile_height, width, tile_height, true));
        CGContextFlush(destination); CGContextFlush(control);
        assert(CGRectEqualToRect(original_clip, CGContextGetClipBoundingBox(destination)));
        if (actual != expected) {
            int count = 0;
            for (size_t i = 0; i < actual.size(); i += 4)
                if (std::memcmp(actual.data() + i, expected.data() + i, 4)) ++count;
            std::fprintf(stderr, "clipped=%d scale=%d image_alpha=%d background_alpha=%d radius=%d phase=%g: %d pixels\n",
                clipped, scale, image_alpha, background_alpha, radius, phase, count);
            return 1;
        }
        CGContextRelease(destination); CGContextRelease(control); ++cases;
    }
    painting(0);
    std::vector<uint8_t> pixels(40 * 40 * 4, 0);
    auto before = pixels;
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), 40, 40, 8, 160, space,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); assert(context);
    uint8_t source[] {120, 50, 90, 255};
    float radii[8]; std::fill_n(radii, 8, 5.f);
    auto attempt = [&](float const* clip) {
        return draw(context, source, 1, 1, 4, 10, 10, 20, 20,
            0, 0, 1, 1, 10, 10, 20, 20, 1, 0, 0, 1, 0, 0,
            0, 0, 0, 40, 40, 1, 0, VOX_GRAPHITE_IMAGE_ROUNDED_ALPHA_MASK, clip);
    };
    assert(!attempt(radii)); // No unmasked CPU fallback after GPU rejection.
    painting(1);
    assert(!attempt(nullptr));
    assert(pixels == before);
    if (!library) {
        // A retained transparent picture must not overwrite the masked leaf
        // with an ordinary image when no visible background blocks recording.
        layer(0, 0, 0); size(40, 40); grid(nullptr, 0, 40, 40, 1);
        recording(0, 40, 40);
        assert(attempt(radii)); CGContextFlush(context);
        auto masked = pixels;
        std::fill(pixels.begin(), pixels.end(), 0);
        recording(1, 40, 40);
        ladybird_v_skia_set_layer_shared_recording(1);
        assert(attempt(radii));
        ladybird_v_skia_finish_shared_recording();
        recording(0, 40, 40); CGContextFlush(context);
        assert(pixels == masked);
    }
    CGContextRelease(context); painting(0);
    std::printf("PASS: %d masked image/background scopes match complete rasters\n", cases);
}
