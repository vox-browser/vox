#pragma once

// Each job is a separate original-sized target. In particular, MSAA resolves
// and backdrop uploads must not cross tile boundaries. Only the submission and
// CPU wait are shared. Callbacks own their state even after a failed submit.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shape_parts_batch_pixels(VoxGraphiteShapeParts const* jobs,
    int count, int width, int height, int has_background)
{
    if (!jobs || count <= 0 || count > 64 || width <= 0 || height <= 0
        || width > 16384 || height > 16384
        || size_t(width) * height > 1024 * 1024
        || size_t(width) * height * count > 8 * 1024 * 1024) return 0;
    struct Readback { std::unique_ptr<const SkImage::AsyncReadResult> result; };
    struct Job {
        std::vector<uint8_t> pixels;
        std::vector<int> rectangles;
        std::vector<std::shared_ptr<Readback>> reads;
        VoxGraphiteRasterCache::Request cached;
    };
    std::vector<Job> pending(count);
    size_t total = 0;
    for (int i = 0; i < count; ++i) {
        auto const& source = jobs[i];
        SmallShapePatchBounds bounds;
        if (!source.regions || source.count <= 0 || source.count > 4
            || !small_shape_patch_bounds(source.shape, width, height, bounds, false)) return 0;
        auto& job = pending[i];
        size_t area = 0;
        for (int j = 0; j < source.count; ++j) {
            auto const& view = source.regions[j];
            if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
                || view.pitch <= 0 || view.width > width || view.height > height
                || view.x > width - view.width || view.y > height - view.height
                || size_t(view.pitch) < size_t(view.width) * 4) return 0;
            for (int k = 0; k < j; ++k) {
                auto const& prior = source.regions[k];
                if (view.x < prior.x + prior.width && prior.x < view.x + view.width
                    && view.y < prior.y + prior.height && prior.y < view.y + view.height) return 0;
            }
            area += size_t(view.width) * view.height;
            job.rectangles.insert(job.rectangles.end(), {view.x, view.y, view.width, view.height});
        }
        total += area;
        if (area > 65536 || total > 1024 * 1024) return 0;
        job.pixels.resize(area * 4);
        job.reads.resize(source.count);
        size_t offset = 0;
        for (int j = 0; j < source.count; ++j) {
            auto const& view = source.regions[j];
            if (has_background) for (int y = 0; y < view.height; ++y)
                std::memcpy(job.pixels.data() + offset + size_t(y) * view.width * 4,
                    view.pixels + size_t(y) * view.pitch, size_t(view.width) * 4);
            offset += size_t(view.width) * view.height * 4;
        }
    }
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    bool success = true;
    unsigned reads = 0, hits = 0;
    for (int i = 0; i < count; ++i) {
        auto const& source = jobs[i];
        auto& job = pending[i];
        job.cached = shape_cache.prepare_shape_parts(source.shape, width, height,
            int(job.pixels.size() / 4), has_background != 0, job.pixels.data(), job.rectangles);
        if (job.cached.hit) { ++hits; continue; }
        FullDrawRecorder recorder(gpu);
        if (!recorder.get()) { success = false; break; }
        auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
        if (!surface) { success = false; break; }
        auto* canvas = surface->getCanvas();
        canvas->clear(SK_ColorTRANSPARENT);
        size_t offset = 0;
        if (has_background) for (int j = 0; j < source.count; ++j) {
            auto const& view = source.regions[j];
            surface->writePixels(SkPixmap(info.makeWH(view.width, view.height),
                job.pixels.data() + offset, size_t(view.width) * 4), view.x, view.y);
            offset += size_t(view.width) * view.height * 4;
        }
        draw_shape_on_canvas(canvas, source.shape, width, height);
        auto recording = recorder.get()->snap();
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) {
            success = false; break;
        }
        for (int j = 0; j < source.count; ++j) {
            auto const& view = source.regions[j];
            auto result = std::make_shared<Readback>();
            job.reads[j] = result;
            auto* owner = new std::shared_ptr<Readback>(std::move(result));
            gpu->asyncRescaleAndReadPixels(surface.get(), info.makeWH(view.width, view.height),
                SkIRect::MakeXYWH(view.x, view.y, view.width, view.height),
                SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
                [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                    std::unique_ptr<std::shared_ptr<Readback>> owner(
                        static_cast<std::shared_ptr<Readback>*>(target));
                    (*owner)->result = std::move(data);
                }, owner);
            ++reads;
        }
#ifdef VOX_TEST_SHAPE_PARTS_BATCH
        if (i == 0 && std::getenv("VOX_TEST_SHAPE_PARTS_FAIL_AFTER_QUEUE")) {
            success = false; break;
        }
#endif
    }
    // Drain earlier jobs even if a later recording fails. CPU outputs and
    // cache admissions remain staged until every callback has succeeded.
    if (reads && !gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)))
        success = false;
    if (!success) return 0;
    for (auto const& job : pending)
        for (auto const& read : job.reads)
            if (read && !read->result) return 0;
#ifdef VOX_TEST_SHAPE_PARTS_BATCH
    if (std::getenv("VOX_TEST_SHAPE_PARTS_FAIL_BEFORE_PUBLISH")) return 0;
#endif
    for (int i = 0; i < count; ++i) {
        auto const& source = jobs[i];
        auto& job = pending[i];
        size_t offset = 0;
        for (int j = 0; j < source.count; ++j) {
            auto const& view = source.regions[j];
            if (job.reads[j]) for (int y = 0; y < view.height; ++y)
                std::memcpy(job.pixels.data() + offset + size_t(y) * view.width * 4,
                    static_cast<uint8_t const*>(job.reads[j]->result->data(0))
                        + size_t(y) * job.reads[j]->result->rowBytes(0), size_t(view.width) * 4);
            offset += size_t(view.width) * view.height * 4;
        }
        shape_cache.finish(std::move(job.cached), job.pixels.data(), int(job.pixels.size()));
    }
    for (int i = 0; i < count; ++i) {
        auto const& source = jobs[i];
        size_t offset = 0;
        for (int j = 0; j < source.count; ++j) {
            auto const& view = source.regions[j];
            for (int y = 0; y < view.height; ++y)
                std::memcpy(view.pixels + size_t(y) * view.pitch,
                    pending[i].pixels.data() + offset + size_t(y) * view.width * 4, size_t(view.width) * 4);
            offset += size_t(view.width) * view.height * 4;
        }
    }
    if (std::getenv("VOX_ROUNDED_TILE_BATCH_DIAGNOSTICS"))
        std::fprintf(stderr, "VOX_ROUNDED_TILE_BATCH jobs=%d hits=%u reads=%u submissions=%d\n",
            count, hits, reads, reads != 0);
    return 1;
}
