// GPU-resident canvas (experiment): included by native_graphite_darwin.mm after
// draw_shadow_on_canvas() and draw_shape_on_canvas(). One frame's repainted
// device rectangles live on shared-storage GPU surfaces. Leaves record into
// them directly; a single read waits for the GPU once and returns them all,
// as Chromium rasterizes every display item of a tile in one GPU pass.
namespace {
struct CanvasTile {
    int x, y, width, height;
    // The repainted rectangle inside this surface, in surface coordinates.
    SkIRect clip;
    sk_sp<SkSurface> surface;
};
std::unique_ptr<skgpu::graphite::Recorder> canvas_recorder;
std::vector<CanvasTile> canvas_tiles;
std::vector<sk_sp<SkSurface>> canvas_surface_pool;

SkImageInfo canvas_info(int width, int height)
{
    return SkImageInfo::Make(width, height, kBGRA_8888_SkColorType, kPremul_SkAlphaType,
        SkColorSpace::MakeSRGB());
}

// The owning Context is being destroyed: release every canvas resource first.
void canvas_reset()
{
    canvas_tiles.clear();
    canvas_surface_pool.clear();
    canvas_recorder.reset();
}

// Repainted rectangles change size from frame to frame (scroll steps, damage
// and the 8-pixel alignment), so surfaces are allocated with rounded-up sizes
// and reused whenever they are large enough; a tile uses its top-left corner.
constexpr size_t canvas_pool_byte_limit = 64 * 1024 * 1024;

size_t canvas_surface_bytes(SkSurface const& surface)
{
    return size_t(surface.width()) * size_t(surface.height()) * 4;
}

void canvas_release_tiles()
{
    size_t pooled = 0;
    for (auto const& surface : canvas_surface_pool) pooled += canvas_surface_bytes(*surface);
    for (auto& tile : canvas_tiles) {
        size_t bytes = canvas_surface_bytes(*tile.surface);
        if (canvas_surface_pool.size() < 8 && pooled + bytes <= canvas_pool_byte_limit) {
            pooled += bytes;
            canvas_surface_pool.push_back(std::move(tile.surface));
        }
    }
    canvas_tiles.clear();
}

int canvas_rounded_size(int value, int step)
{
    return std::min(16384, (value + step - 1) / step * step);
}

void apply_canvas_clips(SkCanvas* canvas, CanvasTile const& tile,
    VoxGraphiteCanvasClip const* clips, int count)
{
    for (int index = 0; clips && index < count; ++index) {
        SkMatrix matrix;
        matrix.set9(clips[index].matrix);
        matrix.postTranslate(-tile.x, -tile.y);
        canvas->setMatrix(matrix);
        canvas->clipRRect(rounded_rect(clips[index].rect), SkClipOp::kIntersect,
            clips[index].antialias != 0);
    }
}

template<typename Draw>
int canvas_draw(float const* bounds, VoxGraphiteCanvasClip const* clips, int clip_count, Draw draw)
{
    if (canvas_tiles.empty()) return 0;
    for (auto& tile : canvas_tiles) {
        if (bounds && (bounds[2] <= tile.x || bounds[0] >= tile.x + tile.width
                || bounds[3] <= tile.y || bounds[1] >= tile.y + tile.height)) continue;
        auto* canvas = tile.surface->getCanvas();
        canvas->save();
        canvas->resetMatrix();
        canvas->clipRect(SkRect::Make(tile.clip));
        apply_canvas_clips(canvas, tile, clips, clip_count);
        draw(canvas, tile);
        canvas->restore();
    }
    return 1;
}

void canvas_local_matrix(float const* device, float* local, CanvasTile const& tile)
{
    SkMatrix matrix;
    matrix.set9(device);
    matrix.postTranslate(-tile.x, -tile.y);
    matrix.get9(local);
}
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_begin(int const* rects, int count)
{
    // Eight values per rectangle: the surface x, y, width, height and the
    // repainted device rectangle drawn inside it, both in canvas device pixels.
    if (!rects || count <= 0 || count > 16) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    canvas_release_tiles();
    if (!canvas_recorder) {
        skgpu::graphite::RecorderOptions options;
        options.fGpuBudgetInBytes = 32 * 1024 * 1024;
        canvas_recorder = gpu->makeRecorder(options);
        if (!canvas_recorder) return 0;
    }
    for (int index = 0; index < count; ++index) {
        int const* rect = rects + index * 8;
        if (rect[2] <= 0 || rect[3] <= 0 || rect[2] > 16384 || rect[3] > 16384) {
            canvas_release_tiles();
            return 0;
        }
        sk_sp<SkSurface> surface;
        auto best = canvas_surface_pool.end();
        for (auto it = canvas_surface_pool.begin(); it != canvas_surface_pool.end(); ++it) {
            if ((*it)->width() >= rect[2] && (*it)->height() >= rect[3]
                && (best == canvas_surface_pool.end()
                    || canvas_surface_bytes(**it) < canvas_surface_bytes(**best))) best = it;
        }
        if (best != canvas_surface_pool.end()) {
            surface = std::move(*best);
            canvas_surface_pool.erase(best);
        } else {
            surface = vox_shared_surface(canvas_recorder.get(),
                canvas_info(canvas_rounded_size(rect[2], 256), canvas_rounded_size(rect[3], 128)));
        }
        if (!surface) {
            canvas_release_tiles();
            return 0;
        }
        auto clip = SkIRect::MakeXYWH(rect[4] - rect[0], rect[5] - rect[1], rect[6], rect[7]);
        if (!clip.intersect(SkIRect::MakeWH(rect[2], rect[3]))) {
            canvas_release_tiles();
            return 0;
        }
        canvas_tiles.push_back({rect[0], rect[1], rect[2], rect[3], clip, std::move(surface)});
    }
    return 1;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_upload(int index, uint8_t const* bgra, int pitch)
{
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu || index < 0 || index >= int(canvas_tiles.size()) || !bgra) return 0;
    auto& tile = canvas_tiles[size_t(index)];
    vox_shared_write(gpu, tile.surface, SkPixmap(canvas_info(tile.width, tile.height), bgra, pitch), 0, 0);
    return 1;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_shadow(VoxGraphiteShadow const* shadow, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count)
{
    if (!shadow) return 0;
    std::lock_guard lock(gpu_mutex);
    return canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
        auto local = *shadow;
        canvas_local_matrix(shadow->matrix, local.matrix, tile);
        draw_shadow_on_canvas(canvas, local);
    });
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_shape(VoxGraphiteShape const* shape, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count)
{
    if (!shape) return 0;
    std::lock_guard lock(gpu_mutex);
    return canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
        auto local = *shape;
        local.force_msaa = 0;
        canvas_local_matrix(shape->matrix, local.matrix, tile);
        draw_shape_on_canvas(canvas, local, tile.width, tile.height);
    });
}

// A root shape inside a Chromium MSAA tile: its own leaf path draws over the
// backdrop in a multisampled pass, then publishes under the destination clips.
// Do the same on the GPU: copy the canvas area to a scratch surface, draw the
// shape there in a multisampled pass, and copy it back through the clips.
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_shape_msaa(VoxGraphiteShape const* shape, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count)
{
    if (!shape || !bounds) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!canvas_recorder) return 0;
    SkPaint copy;
    copy.setBlendMode(SkBlendMode::kSrc);
    for (auto& tile : canvas_tiles) {
        auto area = SkRect::MakeLTRB(bounds[0] - tile.x, bounds[1] - tile.y,
            bounds[2] - tile.x, bounds[3] - tile.y).roundOut();
        if (!area.intersect(tile.clip)) continue;
        auto snapshot = tile.surface->makeImageSnapshot(area);
        auto scratch = snapshot ? SkSurfaces::RenderTarget(canvas_recorder.get(),
            canvas_info(area.width(), area.height())) : nullptr;
        if (!scratch) return 0;
        auto* draw = scratch->getCanvas();
        draw->drawImage(snapshot, 0, 0, SkSamplingOptions(), &copy);
        auto local = *shape;
        local.force_msaa = 1;
        SkMatrix matrix;
        matrix.set9(shape->matrix);
        matrix.postTranslate(-(tile.x + area.x()), -(tile.y + area.y()));
        matrix.get9(local.matrix);
        draw_shape_on_canvas(draw, local, area.width(), area.height());
        auto result = scratch->makeImageSnapshot();
        if (!result) return 0;
        auto* canvas = tile.surface->getCanvas();
        canvas->save();
        canvas->resetMatrix();
        canvas->clipRect(SkRect::Make(area));
        apply_canvas_clips(canvas, tile, clips, clip_count);
        canvas->resetMatrix();
        canvas->drawImage(result, area.x(), area.y(), SkSamplingOptions(), &copy);
        canvas->restore();
    }
    return 1;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_path(VoxGraphitePath const* path, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count)
{
    if (!path || !path->segments || path->segment_count <= 0) return 0;
    std::lock_guard lock(gpu_mutex);
    bool drawn = true;
    int result = canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
        auto local = *path;
        canvas_local_matrix(path->matrix, local.matrix, tile);
        drawn = draw_path_on_canvas(canvas, &local) && drawn;
    });
    return result && drawn;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_image(VoxGraphiteImage const* image, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count)
{
    if (!image || !image_draw_is_valid(image)) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!canvas_recorder) return 0;
    PreparedImageDraw prepared;
    plan_image_draw(image, prepared);
    if (!prepare_image_texture(canvas_recorder.get(), image, prepared)) return 0;
    if (prepared.upload.pending) {
        // A new upload enters the shared upload cache below. Queue its texture
        // writes and mipmap generation now, ahead of any other recorder that
        // finds the cached texture before this canvas is read back.
        auto* gpu = context();
        if (auto recording = canvas_recorder->snap(); gpu && recording) {
            skgpu::graphite::InsertRecordingInfo insertion;
            insertion.fRecording = recording.get();
            if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
        }
    }
    int result = canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
        auto local = *image;
        local.flags &= ~VOX_GRAPHITE_IMAGE_FORCE_MSAA;
        canvas_local_matrix(image->matrix, local.matrix, tile);
        draw_prepared_image(canvas, &local, prepared);
    });
    image_upload_cache.finish(std::move(prepared.upload), prepared.texture);
    return result;
}

// Premultiplied BGRA pixels rasterized on a transparent CPU target, composited
// source-over at an integral device position: text and other CPU-only leaves.
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_pixels(uint8_t const* bgra, int width, int height, int pitch,
    int device_x, int device_y, VoxGraphiteCanvasClip const* clips, int clip_count)
{
    if (!bgra || width <= 0 || height <= 0 || pitch < width * 4) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!canvas_recorder) return 0;
    auto raster = SkImages::RasterFromPixmapCopy(SkPixmap(canvas_info(width, height), bgra, size_t(pitch)));
    auto image = raster ? vox_shared_image(canvas_recorder.get(), raster, {}) : nullptr;
    if (!image) return 0;
    float bounds[] {float(device_x), float(device_y), float(device_x + width), float(device_y + height)};
    return canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
        canvas->setMatrix(SkMatrix::Translate(device_x - tile.x, device_y - tile.y));
        canvas->drawImage(image, 0, 0, SkSamplingOptions(SkFilterMode::kNearest), nullptr);
    });
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_read(VoxGraphitePixelRegion const* views, int count)
{
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu || !views || count != int(canvas_tiles.size()) || !canvas_recorder) return 0;
    auto recording = canvas_recorder->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    }
    for (int index = 0; index < count; ++index) {
        auto const& tile = canvas_tiles[size_t(index)];
        auto const& view = views[index];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.x + view.width > tile.width || view.y + view.height > tile.height) return 0;
        std::unique_ptr<const SkImage::AsyncReadResult> result;
        auto info = canvas_info(view.width, view.height);
        vox_shared_readback(gpu, tile.surface.get(), info,
            SkIRect::MakeXYWH(view.x, view.y, view.width, view.height),
            SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
            [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
            }, &result);
        if (!result && !gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) return 0;
        if (!result) return 0;
        for (int row = 0; row < view.height; ++row)
            std::memcpy(view.pixels + size_t(row) * view.pitch,
                static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0),
                size_t(view.width) * 4);
    }
    return 1;
}

extern "C" __attribute__((visibility("default")))
void vox_graphite_canvas_end()
{
    std::lock_guard lock(gpu_mutex);
    canvas_release_tiles();
}
