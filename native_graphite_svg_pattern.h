#pragma once
#include "include/core/SkPictureRecorder.h"

// SVG background patterns are paint-record shaders. Their SVG paths rasterize
// inside the shader tile, independently of the parent's multisample pass.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_svg_pattern_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphitePath const* paths, int count,
    float const* parent_values, float const* tile, float const* clip,
    float opacity, int linear)
{
    if (!pixels || !paths || !parent_values || !tile || !clip || count <= 0 || count > 32768
        || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || size_t(width) * height > 8 * 1024 * 1024 || pitch < width * 4
        || !(tile[2] > 0 && tile[3] > 0) || !(clip[2] > 0 && clip[3] > 0)
        || !std::isfinite(opacity)) return 0;
    for (int i = 0; i < 9; ++i) if (!std::isfinite(parent_values[i])) return 0;
    for (int i = 0; i < 4; ++i) if (!std::isfinite(tile[i])) return 0;
    for (int i = 0; i < 12; ++i) if (!std::isfinite(clip[i]) || (i >= 4 && clip[i] < 0)) return 0;
    if (tile[2] > 16384 || tile[3] > 16384 || double(tile[2]) * tile[3] > 8 * 1024 * 1024) return 0;
    size_t segments = 0;
    for (int i = 0; i < count; ++i) {
        if (!paths[i].segments || paths[i].segment_count <= 0 || paths[i].segment_count > 32768
            || paths[i].gradient || paths[i].stroke || !std::isfinite(paths[i].opacity)) return 0;
        segments += paths[i].segment_count;
        if (segments > 1024 * 1024) return 0;
        for (float value : paths[i].matrix) if (!std::isfinite(value)) return 0;
    }
    std::lock_guard lock(gpu_mutex);
    double pixel_width = std::ceil(double(tile[2]) * std::hypot(parent_values[0],parent_values[3]));
    double pixel_height = std::ceil(double(tile[3]) * std::hypot(parent_values[1],parent_values[4]));
    if (!(pixel_width > 0 && pixel_height > 0) || pixel_width > 16384 || pixel_height > 16384
        || pixel_width * pixel_height > 8 * 1024 * 1024) return 0;
    int tile_width = pixel_width, tile_height = pixel_height;
    float scale_x = tile_width / tile[2], scale_y = tile_height / tile[3];
    SkPictureRecorder picture_recorder;
    auto bounds = SkRect::MakeWH(tile_width, tile_height);
    auto* inner = picture_recorder.beginRecording(bounds);
    for (int i = 0; i < count; ++i) {
        SkAutoCanvasRestore state(inner, true);
        auto path = paths[i];
        for (int j = 0; j < 3; ++j) path.matrix[j] *= scale_x;
        for (int j = 3; j < 6; ++j) path.matrix[j] *= scale_y;
        if (!draw_path_on_canvas(inner, &path)) return 0;
    }
    auto picture = picture_recorder.finishRecordingAsPicture();
    auto raster = SkImages::DeferredFromPicture(picture, SkISize::Make(tile_width, tile_height),
        nullptr, nullptr, SkImages::BitDepth::kU8, SkColorSpace::MakeSRGB());
    if (!raster) return 0;
    auto* gpu = context();
    if (!gpu) return 0;
    auto recorder = gpu->makeRecorder();
    auto texture = SkImages::TextureFromImage(recorder.get(), raster);
    if (!texture) return 0;
    auto phase = SkMatrix::Translate(tile[0], tile[1]);
    phase.preScale(1 / scale_x, 1 / scale_y);
    auto shader = texture->makeShader(SkTileMode::kRepeat, SkTileMode::kRepeat,
        SkSamplingOptions(linear ? SkFilterMode::kLinear : SkFilterMode::kNearest), &phase);
    if (!shader) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    SkMatrix matrix;
    matrix.set9(parent_values);
    canvas->setMatrix(matrix);
    canvas->clipRRect(rounded_rect(clip), true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(std::clamp(opacity, 0.f, 1.f));
    paint.setShader(std::move(shader));
    canvas->drawRect(SkRect::MakeXYWH(clip[0], clip[1], clip[2], clip[3]), paint);
    return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
}
