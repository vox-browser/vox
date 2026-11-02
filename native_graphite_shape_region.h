#pragma once
#include "native_graphite_shape_region_policy.h"

// Preserve the complete target and draw. Only CPU transfers are restricted
// to the requested view; the rest of the original tile remains transparent.
static bool draw_bounded_shape_region(VoxGraphitePixelRegion const& view,
    int width, int height, bool has_background, VoxGraphiteShape const& shape)
{
    if (!vox_large_shape_regions_enabled() || size_t(width) * height > 1024 * 1024
        || size_t(view.width) * view.height > 256 * 1024 || shape.clip_out_count < 0
        || shape.clip_out_count > 4096 || (shape.clip_out_count && !shape.clip_outs)) return false;
    for (float value : shape.matrix) if (!std::isfinite(value)) return false;
    for (float value : shape.rect) if (!std::isfinite(value)) return false;
    if (!std::isfinite(shape.thickness)) return false;
    if (shape.has_underlay) for (float value : shape.underlay_rect)
        if (!std::isfinite(value)) return false;
    for (int i = 0; i < shape.clip_out_count * 4; ++i)
        if (!std::isfinite(shape.clip_outs[i])) return false;
    std::lock_guard lock(gpu_mutex);
    auto cached = shape_cache.prepare_shape_region(shape, width, height, view, has_background);
    auto diagnostic = [&] {
        if (!std::getenv("VOX_LARGE_SHAPE_REGION_DIAGNOSTICS")) return;
        using Clock = double (*)();
        static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
        std::fprintf(stderr, "VOX_LARGE_SHAPE_REGION target=%dx%d view=%d,%d,%d,%d hit=%d t_us=%.3f\n",
            width, height, view.x, view.y, view.width, view.height, cached.hit, clock ? clock() : -1.0);
    };
    if (cached.hit) { diagnostic(); return true; }
    auto* gpu = context();
    if (!gpu) return false;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
    sk_sp<SkSurface> temporary_surface;
    auto* surface = region_target(gpu, info);
    auto* recorder = region_recorder.get();
    if (!surface) {
        temporary_recorder = gpu->makeRecorder(); recorder = temporary_recorder.get();
        if (!recorder) return false;
        temporary_surface = SkSurfaces::RenderTarget(recorder, info); surface = temporary_surface.get();
    }
    if (!surface) return false;
    auto* canvas = surface->getCanvas();
    SkAutoCanvasRestore state(canvas, true);
    canvas->clear(SK_ColorTRANSPARENT);
    auto view_info = info.makeWH(view.width, view.height);
    if (has_background) surface->writePixels(SkPixmap(view_info, view.pixels, view.pitch), view.x, view.y);
    draw_shape_on_canvas(canvas, shape, width, height);
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return false;
    struct Readback { std::unique_ptr<const SkImage::AsyncReadResult> pixels; };
    auto result = std::make_shared<Readback>();
    auto* callback = new std::shared_ptr<Readback>(result);
    gpu->asyncRescaleAndReadPixels(surface, view_info,
        SkIRect::MakeXYWH(view.x, view.y, view.width, view.height),
        SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
        [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
            std::unique_ptr<std::shared_ptr<Readback>> owner(static_cast<std::shared_ptr<Readback>*>(target));
            (*owner)->pixels = std::move(data);
        }, callback);
#ifdef VOX_TEST_LARGE_SHAPE_REGION_FAILURES
    if (std::getenv("VOX_TEST_LARGE_SHAPE_REGION_FAIL_AFTER_READ")) {
        std::fprintf(stderr, "VOX_LARGE_SHAPE_REGION_TEST_FAILED queued_reads=1\n");
        return false;
    }
#endif
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result->pixels) return false;
    for (int y = 0; y < view.height; ++y)
        std::memcpy(view.pixels + size_t(y) * view.pitch,
            static_cast<uint8_t const*>(result->pixels->data(0)) + size_t(y) * result->pixels->rowBytes(0),
            size_t(view.width) * 4);
    shape_cache.finish(std::move(cached), view.pixels, view.pitch);
    diagnostic();
    return true;
}
