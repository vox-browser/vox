#pragma once

// Only independent views of one leaf enter this batch. Preserve the serial
// target, backdrop, sampling and MSAA for each, then wait for readbacks once.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_image_regions_pixels(VoxGraphitePixelRegion const* regions,
    VoxGraphiteImage const* images, int count, int width, int height, int has_background)
{
    if (!regions || !images || count < 2 || count > 64 || width <= 0 || height <= 0
        || width > 16384 || height > 16384 || size_t(width) * height > 1024 * 1024
        || size_t(width) * height * count > 8 * 1024 * 1024) return 0;
    struct Span { uintptr_t begin, end; };
    auto span = [](void const* pixels, int w, int h, int pitch, size_t maximum, Span& out) {
        if (!pixels || w <= 0 || h <= 0 || pitch <= 0 || size_t(pitch) < size_t(w) * 4)
            return false;
        size_t bytes = size_t(h - 1) * pitch + size_t(w) * 4;
        uintptr_t begin = reinterpret_cast<uintptr_t>(pixels);
        if (bytes > maximum || bytes > UINTPTR_MAX - begin) return false;
        out = {begin, begin + bytes};
        return true;
    };
    auto overlaps = [](Span a, Span b) { return a.begin < b.end && b.begin < a.end; };
    std::vector<Span> destinations(count), sources(count);
    size_t pixels = 0;
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        auto const& image = images[i];
        if (!image_draw_is_valid(&image) || (image.flags & 4)
            || !span(image.pixels, image.width, image.height, image.pitch, 64 * 1024 * 1024, sources[i])
            || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > width || view.height > height
            || view.x > width - view.width || view.y > height - view.height
            || !span(view.pixels, view.width, view.height, view.pitch, 32 * 1024 * 1024, destinations[i])) return 0;
        pixels += size_t(view.width) * view.height;
        if (pixels > 4 * 1024 * 1024) return 0;
    }
    // Also exclude a source that a later output publication would overwrite.
    for (int i = 0; i < count; ++i) for (int j = 0; j < count; ++j)
        if ((i != j && overlaps(destinations[i], destinations[j]))
            || overlaps(destinations[i], sources[j])) return 0;
    struct Readback { std::unique_ptr<const SkImage::AsyncReadResult> result; };
    struct Job {
        std::unique_ptr<uint8_t[]> pixels;
        VoxGraphiteRasterCache::Request cached;
        PreparedImageDraw prepared;
        std::shared_ptr<Readback> readback;
    };
    // Texture ownership is released while the renderer mutex is still held.
    std::lock_guard lock(gpu_mutex);
    std::vector<Job> jobs(count);
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        // Every byte is supplied by a cache hit or a completed readback.
        // The immutable caller view remains the GPU's original backdrop.
        jobs[i].pixels.reset(new uint8_t[size_t(view.width) * view.height * 4]);
    }
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    skgpu::graphite::Context* gpu = nullptr;
    int reads = 0, hits = 0;
    bool success = true;
    for (int i = 0; i < count; ++i) {
        auto& job = jobs[i];
        auto const& view = regions[i];
        auto const& image = images[i];
        job.cached = image_cache.prepare_region(image, width, height, view, has_background != 0,
            job.pixels.get(), view.width * 4);
        if (job.cached.hit) { ++hits; continue; }
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
        auto view_info = info.makeWH(view.width, view.height);
        if (has_background) surface->writePixels(SkPixmap(view_info, view.pixels,
            view.pitch), view.x, view.y);
        plan_image_draw(&image, job.prepared);
        if (!prepare_image_texture(recorder, &image, job.prepared)) { success = false; break; }
        if (image.flags & VOX_GRAPHITE_IMAGE_FORCE_MSAA) force_msaa_render_pass(canvas, width, height);
        draw_prepared_image(canvas, &image, job.prepared);
        auto recording = recorder->snap();
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) {
            success = false; break;
        }
        job.readback = std::make_shared<Readback>();
        auto* callback = new std::shared_ptr<Readback>(job.readback);
        gpu->asyncRescaleAndReadPixels(surface, view_info,
            SkIRect::MakeXYWH(view.x, view.y, view.width, view.height),
            SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
            [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> result) {
                std::unique_ptr<std::shared_ptr<Readback>> owner(
                    static_cast<std::shared_ptr<Readback>*>(target));
                (*owner)->result = std::move(result);
            }, callback);
        ++reads;
    }
    // Queued callbacks own their state, including after a later draw fails.
    if (reads && !gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)))
        success = false;
    if (!success) {
        if (std::getenv("VOX_IMAGE_BATCH_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_IMAGE_REGION_BATCH_FAILED queued_reads=%d\n", reads);
        return 0;
    }
    for (auto const& job : jobs) if (job.readback && !job.readback->result) return 0;
    for (int i = 0; i < count; ++i) {
        auto& job = jobs[i];
        auto const& view = regions[i];
        if (!job.readback) continue;
        auto const& result = job.readback->result;
        for (int y = 0; y < view.height; ++y)
            std::memcpy(job.pixels.get() + size_t(y) * view.width * 4,
                static_cast<uint8_t const*>(result->data(0)) + size_t(y) * result->rowBytes(0),
                size_t(view.width) * 4);
        image_upload_cache.finish(std::move(job.prepared.upload), job.prepared.texture);
        image_cache.finish(std::move(job.cached), job.pixels.get(), view.width * 4);
    }
    for (int i = 0; i < count; ++i) for (int y = 0; y < regions[i].height; ++y)
        std::memcpy(regions[i].pixels + size_t(y) * regions[i].pitch,
            jobs[i].pixels.get() + size_t(y) * regions[i].width * 4, size_t(regions[i].width) * 4);
    if (std::getenv("VOX_IMAGE_BATCH_DIAGNOSTICS")) {
        using Clock = double (*)();
        static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
        std::fprintf(stderr, "VOX_IMAGE_REGION_BATCH jobs=%d hits=%d reads=%d submissions=%d t_us=%.3f\n",
            count, hits, reads, reads != 0, clock ? clock() : -1.0);
    }
    return 1;
}
