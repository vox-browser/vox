#pragma once

// Queue independent image tiles together. Private GPU targets let backdrop
// uploads and readbacks stay in the command stream, without the shared Metal
// surface's CPU synchronization at each tile. Retain complete target extents:
// cropping them changes image interpolation and multisample coverage.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_image_regions_pixels(VoxGraphitePixelRegion const* regions,
    VoxGraphiteImage const* images, int count, int width, int height, int has_background)
{
    if (!regions || !images || count < 2 || count > 64 || width <= 0 || height <= 0
        || width > 16384 || height > 16384 || size_t(width) * height > 1024 * 1024
        || size_t(width) * height * count > 8 * 1024 * 1024) return 0;
    size_t total = 0;
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        if (!image_draw_is_valid(images + i) || !view.pixels
            || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > width || view.height > height
            || view.x > width - view.width || view.y > height - view.height
            || view.pitch <= 0 || size_t(view.pitch) < size_t(view.width) * 4) return 0;
        total += size_t(view.width) * view.height;
        if (total > 4 * 1024 * 1024) return 0;
    }
    struct Readback { std::unique_ptr<const SkImage::AsyncReadResult> result; };
    struct Tile {
        std::vector<uint8_t> pixels;
        VoxGraphiteRasterCache::Request cached;
        PreparedImageDraw prepared;
        std::shared_ptr<Readback> readback;
    };
    std::vector<Tile> tiles(count);
    std::lock_guard lock(gpu_mutex);
    skgpu::graphite::Context* gpu = nullptr;
    std::unique_ptr<FullDrawRecorder> lease;
    int reads = 0;
    bool success = true;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        auto& tile = tiles[i];
        tile.pixels.resize(size_t(view.width) * view.height * 4);
        if (has_background) for (int y = 0; y < view.height; ++y)
            std::memcpy(tile.pixels.data() + size_t(y) * view.width * 4,
                view.pixels + size_t(y) * view.pitch, size_t(view.width) * 4);
        auto staged = view;
        staged.pixels = tile.pixels.data();
        staged.pitch = view.width * 4;
        tile.cached = image_cache.prepare_region(images[i], width, height, staged, has_background != 0);
        if (tile.cached.hit) continue;
        if (!gpu) gpu = context();
        if (!gpu) { success = false; break; }
        if (!lease) lease = std::make_unique<FullDrawRecorder>(gpu);
        auto* recorder = lease->get();
        if (!recorder) { success = false; break; }
        auto surface = SkSurfaces::RenderTarget(recorder, info);
        if (!surface) { success = false; break; }
        auto* canvas = surface->getCanvas();
        canvas->clear(SK_ColorTRANSPARENT);
        if (has_background) surface->writePixels(SkPixmap(
            info.makeWH(view.width, view.height), staged.pixels, staged.pitch), view.x, view.y);
        auto const& image = images[i];
        auto& prepared = tile.prepared;
        plan_image_draw(&image, prepared);
        // A leaf's tile descriptors differ in translation and MSAA selection,
        // but sample the same immutable source. Share this batch's upload too.
        for (int prior = 0; prior < i; ++prior) {
            auto const& previous = images[prior];
            auto const& upload = tiles[prior].prepared;
            if (upload.texture && upload.upload_width == prepared.upload_width
                && upload.upload_height == prepared.upload_height
                && upload.needs_mips == prepared.needs_mips
                && previous.pixels == image.pixels && previous.pitch == image.pitch
                && previous.width == image.width && previous.height == image.height
                && previous.nearest == image.nearest
                && (previous.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
                    == (image.flags & ~VOX_GRAPHITE_IMAGE_FORCE_MSAA)
                && previous.has_color_profile == image.has_color_profile
                && (!image.has_color_profile || !std::memcmp(previous.color_profile,
                    image.color_profile, sizeof(image.color_profile)))) {
                prepared.texture = upload.texture;
                prepared.source_scale_x = upload.source_scale_x;
                prepared.source_scale_y = upload.source_scale_y;
                break;
            }
        }
        if (!prepared.texture && !prepare_image_texture(recorder, &image, prepared)) {
            success = false; break;
        }
        if (image.flags & VOX_GRAPHITE_IMAGE_FORCE_MSAA) force_msaa_render_pass(canvas, width, height);
        draw_prepared_image(canvas, &image, prepared);
        auto recording = recorder->snap();
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) {
            success = false; break;
        }
        tile.readback = std::make_shared<Readback>();
        // The callback owns its handle even if a later tile or submission
        // fails, so no pending callback can refer to this call's stack.
        auto* callback = new std::shared_ptr<Readback>(tile.readback);
        gpu->asyncRescaleAndReadPixels(surface.get(), info.makeWH(view.width, view.height),
            SkIRect::MakeXYWH(view.x, view.y, view.width, view.height),
            SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
            [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> result) {
                std::unique_ptr<std::shared_ptr<Readback>> owner(
                    static_cast<std::shared_ptr<Readback>*>(target));
                (*owner)->result = std::move(result);
            }, callback);
        ++reads;
    }
    // Drain queued work on failure as well, without publishing partial output.
    if (reads && !gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) success = false;
    if (!success) return 0;
    for (auto const& tile : tiles)
        if (tile.readback && !tile.readback->result) return 0;
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        auto& tile = tiles[i];
        if (tile.readback) {
            auto const& result = tile.readback->result;
            for (int y = 0; y < view.height; ++y)
                std::memcpy(tile.pixels.data() + size_t(y) * view.width * 4,
                    static_cast<uint8_t const*>(result->data(0)) + size_t(y) * result->rowBytes(0),
                    size_t(view.width) * 4);
            image_upload_cache.finish(std::move(tile.prepared.upload), tile.prepared.texture);
            image_cache.finish(std::move(tile.cached), tile.pixels.data(), view.width * 4);
        }
        for (int y = 0; y < view.height; ++y)
            std::memcpy(view.pixels + size_t(y) * view.pitch,
                tile.pixels.data() + size_t(y) * view.width * 4, size_t(view.width) * 4);
    }
    if (std::getenv("VOX_IMAGE_BATCH_DIAGNOSTICS")) {
        using Clock = double (*)();
        static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
        std::fprintf(stderr, "VOX_IMAGE_BATCH tiles=%d gpu_reads=%d submissions=%d t_us=%.3f\n",
            count, reads, reads != 0, clock ? clock() : -1.0);
    }
    return 1;
}
