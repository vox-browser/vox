#pragma once
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

// Independent tiles of one leaf have immutable CPU backdrops. Queue their
// original-sized render passes and readbacks before waiting for the GPU once.
// Nothing is published to a caller until every tile has completed successfully.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shape_regions_pixels(VoxGraphitePixelRegion const* regions,
    VoxGraphiteShape const* shapes, int count, int width, int height, int has_background)
{
    if (!regions || !shapes || count <= 0 || count > 64 || width <= 0 || height <= 0
        || width > 16384 || height > 16384) return 0;
    if (size_t(width) * height > 1024 * 1024
        || size_t(width) * height * count > 8 * 1024 * 1024) return 0;
    struct Readback { std::unique_ptr<const SkImage::AsyncReadResult> result; };
    struct Patch {
        SmallShapePatchBounds bounds;
        std::vector<uint8_t> pixels;
        VoxGraphiteRasterCache::Request cached;
        std::shared_ptr<Readback> readback;
    };
    std::vector<Patch> patches(count);
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.pitch <= 0 || view.width > width || view.height > height
            || view.x > width - view.width || view.y > height - view.height
            || size_t(view.pitch) < size_t(view.width) * 4
            || !small_shape_patch_bounds(shapes[i], width, height, patches[i].bounds)) return 0;
        auto& patch = patches[i];
        patch.pixels.resize(size_t(patch.bounds.width) * patch.bounds.height * 4);
        if (has_background && !patch.pixels.empty())
            copy_shape_patch(view, patch.pixels.data(), patch.bounds.left, patch.bounds.top,
                patch.bounds.width, patch.bounds.height, false);
    }
    std::lock_guard lock(gpu_mutex);
    skgpu::graphite::Context* gpu = nullptr;
    int reads = 0;
    bool success = true;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    for (int i = 0; i < count; ++i) {
        auto& patch = patches[i];
        if (patch.pixels.empty()) continue;
        patch.cached = shape_cache.prepare_patches(shapes[i], width, height,
            int(patch.pixels.size() / 4), has_background != 0, patch.pixels.data());
        if (patch.cached.hit) continue;
        if (!gpu) gpu = context();
        if (!gpu) { success = false; break; }
        std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
        sk_sp<SkSurface> temporary_surface;
        auto* surface = region_target(gpu, info);
        auto* recorder = region_recorder.get();
        if (!surface) {
            temporary_recorder = gpu->makeRecorder();
            recorder = temporary_recorder.get();
            if (!recorder) { success = false; break; }
            temporary_surface = SkSurfaces::RenderTarget(recorder, info);
            surface = temporary_surface.get();
        }
        if (!surface) { success = false; break; }
        auto* canvas = surface->getCanvas();
        SkAutoCanvasRestore state(canvas, true);
        canvas->clear(SK_ColorTRANSPARENT);
        auto const& b = patch.bounds;
        if (has_background)
            surface->writePixels(SkPixmap(info.makeWH(b.width, b.height), patch.pixels.data(),
                size_t(b.width) * 4), b.left, b.top);
        draw_shape_on_canvas(canvas, shapes[i], width, height);
        auto recording = recorder->snap();
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) {
            success = false;
            break;
        }
        patch.readback = std::make_shared<Readback>();
        // The callback owns its handle even if submission fails or a later
        // tile declines. It never refers to stack storage or moved patches.
        auto* callback = new std::shared_ptr<Readback>(patch.readback);
        gpu->asyncRescaleAndReadPixels(surface, info.makeWH(b.width, b.height),
            SkIRect::MakeXYWH(b.left, b.top, b.width, b.height),
            SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
            [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> result) {
                std::unique_ptr<std::shared_ptr<Readback>> owner(
                    static_cast<std::shared_ptr<Readback>*>(target));
                (*owner)->result = std::move(result);
            }, callback);
        ++reads;
    }
    // Drain any already queued callbacks on an unsuccessful batch too.
    if (reads && !gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)))
        success = false;
    if (!success) return 0;
    for (auto& patch : patches) {
        if (!patch.readback) continue;
        auto const& result = patch.readback->result;
        if (!result) return 0;
        auto const& b = patch.bounds;
        for (int y = 0; y < b.height; ++y)
            std::memcpy(patch.pixels.data() + size_t(y) * b.width * 4,
                static_cast<uint8_t const*>(result->data(0)) + size_t(y) * result->rowBytes(0),
                size_t(b.width) * 4);
        shape_cache.finish(std::move(patch.cached), patch.pixels.data(), int(patch.pixels.size()));
    }
    for (int i = 0; i < count; ++i) {
        if (!has_background) clear_shape_region(regions[i]);
        auto& patch = patches[i];
        if (!patch.pixels.empty())
            copy_shape_patch(regions[i], patch.pixels.data(), patch.bounds.left, patch.bounds.top,
                patch.bounds.width, patch.bounds.height, true);
    }
    static bool diagnostic = std::getenv("VOX_SHAPE_BATCH_DIAGNOSTIC") != nullptr;
    if (diagnostic) {
        static unsigned samples[2];
        auto* marker = std::getenv("VOX_POL_INPUT_MARKER");
        int input = marker && access(marker, F_OK) == 0;
        if (samples[input]++ < 16)
            std::fprintf(stderr, "VOX_SHAPE_BATCH_EXECUTED input=%d jobs=%d gpu_reads=%d submissions=%d\n",
                input, count, reads, reads != 0);
    }
    return 1;
}
