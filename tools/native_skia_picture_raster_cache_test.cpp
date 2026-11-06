#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <iostream>

static sk_sp<SkPicture> scene(int color, bool image)
{
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(320, 256));
    SkPaint paint; paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(137, 31, color, 201));
    canvas->drawRRect(SkRRect::MakeRectXY(SkRect::MakeXYWH(5.25f, 7.5f, 240, 180), 13, 9), paint);
    SkPoint points[] {{20, 17}, {230, 203}};
    SkColor colors[] {0x00ff0000, 0x8738caaa, 0xfefeff37};
    paint.setShader(SkGradientShader::MakeLinear(points, colors, nullptr, 3, SkTileMode::kClamp));
    canvas->drawOval(SkRect::MakeXYWH(29.5f, 51, 193, 117), paint);
    if (image) {
        auto surface = SkSurfaces::Raster(SkImageInfo::MakeN32Premul(19, 17)); assert(surface);
        surface->getCanvas()->clear(SkColorSetARGB(128, color, 17, 219));
        canvas->drawImage(surface->makeImageSnapshot(), 43.5f, 71.25f);
    }
    return recorder.finishRecordingAsPicture();
}

static std::vector<uint8_t> render(SkPicture const* picture, int scale, bool tiled,
    int background, float origin, bool cached)
{
    constexpr int w = 320, h = 256;
    int width = w * scale, height = h * scale, pitch = width * 4;
    std::vector<uint8_t> output(size_t(pitch) * height);
    auto group = std::make_unique<SharedRootRecording>();
    group->backdrop.resize(size_t(width) * height);
    auto* backdrop = reinterpret_cast<uint8_t*>(group->backdrop.data());
    for (size_t i = 0; i < output.size(); i += 4) {
        output[i] = backdrop[i + 2] = uint8_t(background + (i / 4) % 37);
        output[i + 1] = backdrop[i + 1] = 57;
        output[i + 2] = backdrop[i] = 93;
        output[i + 3] = backdrop[i + 3] = 255;
    }
    group->backdrop_width = width;
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto destination = CGBitmapContextCreate(output.data(), width, height, 8, pitch, color,
        CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color); assert(destination);
    CGContextScaleCTM(destination, scale, scale);
    group->destination = destination;
    group->canvas_width = group->viewport_width = w;
    group->canvas_height = group->viewport_height = h;
    group->layer_width = w - origin; group->layer_height = h;
    group->origin_x = origin; group->scale = scale; group->root = false;
    group->columns = group->rows = 1;
    if (tiled) {
        group->tile_width = 130 * scale; group->tile_height = 130 * scale;
        group->columns = 3; group->rows = 3;
    }
    group->recorder = std::make_unique<SkPictureRecorder>();
    auto* canvas = group->recorder->beginRecording(SkRect::MakeWH(w, h));
    picture->playback(canvas);
    group->replay_bounds.push_back(SkRect::MakeWH(w, h));
    setenv("VOX_RETAIN_UNCACHED_PICTURE_RASTER", cached ? "" : "1", 1);
    s_shared_root_recording = std::move(group);
    finish_shared_recording();
    CGContextRelease(destination);
    return output;
}

int main()
{
    assert(shared_picture_draw() && picture_regions_draw());
    setenv("VOX_PICTURE_RASTER_CACHE_DIAGNOSTICS", "1", 1);
    size_t cases = 0;
    for (int scale : {1, 2}) for (bool tiled : {false, true})
    for (float origin : {0.f, .25f}) for (bool image : {false, true}) {
        clear_picture_raster_cache();
        auto picture = scene(63, image);
        std::vector<uint8_t> last;
        for (int background : {10, 80, 140}) {
            auto expected = render(picture.get(), scale, tiled, background, origin, false);
            auto first = render(picture.get(), scale, tiled, background, origin, true);
            auto again = render(picture.get(), scale, tiled, background, origin, true);
            assert(first == expected && again == expected);
            assert(s_picture_raster_cache.entries() == 1);
            if (!last.empty()) assert(first != last);
            last = std::move(first); ++cases;
        }
        // New paint bytes cannot reuse pixels even with identical geometry.
        auto changed = scene(179, image);
        auto expected = render(changed.get(), scale, tiled, 10, origin, false);
        auto actual = render(changed.get(), scale, tiled, 10, origin, true);
        assert(actual == expected && actual != render(picture.get(), scale, tiled, 10, origin, true));
        assert(s_picture_raster_cache.entries() == 2);
        clear_picture_raster_cache();
        assert(s_picture_raster_cache.entries() == 0 && s_picture_raster_cache.bytes() == 0);
    }
    float matrix[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
    auto bytes = scene(99, false)->serialize();
    VoxChromiumRasterGrid grid {130, 131, 3, 4};
    auto key = picture_raster_key(bytes.get(), 320, 256, 0, 0, grid, matrix, true);
    assert(key != picture_raster_key(bytes.get(), 319, 256, 0, 0, grid, matrix, true));
    assert(key != picture_raster_key(bytes.get(), 320, 255, 0, 0, grid, matrix, true));
    assert(key != picture_raster_key(bytes.get(), 320, 256, 1, 0, grid, matrix, true));
    assert(key != picture_raster_key(bytes.get(), 320, 256, 0, 1, grid, matrix, true));
    assert(key != picture_raster_key(bytes.get(), 320, 256, 0, 0, grid, matrix, false));
    for (int field = 0; field < 4; ++field) {
        auto modified = grid;
        if (field == 0) ++modified.width;
        if (field == 1) ++modified.height;
        if (field == 2) ++modified.columns;
        if (field == 3) ++modified.rows;
        assert(key != picture_raster_key(bytes.get(), 320, 256, 0, 0, modified, matrix, true));
    }
    for (int i = 0; i < 9; ++i) {
        matrix[i] += .125f;
        assert(key != picture_raster_key(bytes.get(), 320, 256, 0, 0, grid, matrix, true));
        matrix[i] -= .125f;
    }
    std::cout << "Transparent picture cache: " << cases
        << " exact current-backdrop, raster-grid, phase, image and mutation scenes passed\n";
}
