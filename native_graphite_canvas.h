// GPU-resident canvas (experiment): included by native_graphite_darwin.mm after
// draw_shadow_on_canvas() and draw_shape_on_canvas(). One frame's repainted
// device rectangles live on shared-storage GPU surfaces. Leaves record into
// them directly; a single read waits for the GPU once and returns them all,
// as Chromium rasterizes every display item of a tile in one GPU pass.
#import <IOSurface/IOSurface.h>
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
id<MTLComputePipelineState> canvas_readback_pipeline;
VoxGraphiteImageUploadCache<sk_sp<SkImage>> canvas_backdrop_uploads {16 * 1024 * 1024, 4};
size_t canvas_backdrop_texture_hits;

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
    canvas_backdrop_uploads.clear();
    canvas_recorder.reset();
    [canvas_readback_pipeline release];
    canvas_readback_pipeline = nil;
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
        size_t slots=std::getenv("VOX_GPU_CANVAS_NATIVE_GRID")?64:8;
        if (canvas_surface_pool.size() < slots && pooled + bytes <= canvas_pool_byte_limit) {
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

static int canvas_begin_impl(int const* rects, int count, bool native_grid)
{
    // Eight values per rectangle: the surface x, y, width, height and the
    // repainted device rectangle drawn inside it, both in canvas device pixels.
    if (!rects || count <= 0 || count > (native_grid?64:16)) return 0;
    size_t requested=0;
    for(int index=0;index<count;++index) {
        int width=rects[index*8+2],height=rects[index*8+3];
        if(width<=0 || height<=0 || width>16384 || height>16384) return 0;
        requested+=size_t(native_grid?width:canvas_rounded_size(width,256))
            *(native_grid?height:canvas_rounded_size(height,128))*4;
        if(native_grid && requested>canvas_pool_byte_limit) return 0;
    }
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
                && (!native_grid || ((*it)->width()==rect[2] && (*it)->height()==rect[3]))
                && (best == canvas_surface_pool.end()
                    || canvas_surface_bytes(**it) < canvas_surface_bytes(**best))) best = it;
        }
        if (best != canvas_surface_pool.end()) {
            surface = std::move(*best);
            canvas_surface_pool.erase(best);
        } else {
            surface = vox_shared_surface(canvas_recorder.get(),
                canvas_info(native_grid?rect[2]:canvas_rounded_size(rect[2],256),
                    native_grid?rect[3]:canvas_rounded_size(rect[3],128)),
                std::getenv("VOX_GPU_CANVAS_LINEAR_TEXTURES") != nullptr);
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
int vox_graphite_canvas_begin(int const* rects,int count) { return canvas_begin_impl(rects,count,false); }
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_begin_native_grid(int const* rects,int count) { return canvas_begin_impl(rects,count,true); }

static int canvas_upload_impl(int index, uint8_t const* bgra, int pitch, bool queued)
{
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu || index < 0 || index >= int(canvas_tiles.size()) || !bgra) return 0;
    auto& tile = canvas_tiles[size_t(index)];
    if (pitch < tile.width * 4) return 0;
    if (std::getenv("VOX_GPU_CANVAS_LINEAR_DIAGNOSTICS")) {
        auto texture = vox_shared_metal_texture(tile.surface.get());
        std::fprintf(stderr, "Vox GPU canvas texture: linear=%d size=%dx%d\n",
            int(texture && texture.buffer), tile.width, tile.height);
    }
    auto pixels = SkPixmap(canvas_info(tile.width, tile.height), bgra, pitch);
    if (queued || std::getenv("VOX_GPU_CANVAS_STAGED_UPLOAD")) {
        // Graphite copies the source into its upload buffer now and orders the
        // transfer with subsequent draws. Finish them together at readback,
        // rather than submitting/waiting before a CPU texture replacement.
        bool written = tile.surface->getCanvas()->writePixels(pixels.info(), pixels.addr(), pixels.rowBytes(), 0, 0);
        if (written && std::getenv("VOX_GPU_CANVAS_STAGED_UPLOAD_DIAGNOSTICS"))
            std::fprintf(stderr, "Vox GPU canvas staged upload: size=%dx%d\n", tile.width, tile.height);
        return written;
    }
    vox_shared_write(gpu, tile.surface, pixels, 0, 0);
    return 1;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_upload(int index, uint8_t const* bgra, int pitch)
{ return canvas_upload_impl(index,bgra,pitch,false); }
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_upload_queued(int index, uint8_t const* bgra, int pitch)
{ return canvas_upload_impl(index,bgra,pitch,true); }

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

// Native-grid tiles retain the ordinary root raster origin and extent. Select
// their coverage mode directly, without allocating an isolated scratch pass.
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_shape_native_grid(VoxGraphiteShape const* shape, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count, int const* msaa_rects, int msaa_count)
{
    if(!shape || !bounds || msaa_count<0 || msaa_count>4096 || (msaa_count && !msaa_rects)) return 0;
    std::lock_guard lock(gpu_mutex);
    if(!canvas_recorder) return 0;
    if(canvas_tiles.empty()) return 0;
    for(auto const& tile:canvas_tiles) {
        if(bounds[2]<=tile.x || bounds[0]>=tile.x+tile.width
            || bounds[3]<=tile.y || bounds[1]>=tile.y+tile.height) continue;
        auto* canvas=tile.surface->getCanvas();
        canvas->save();
        canvas->resetMatrix();
        auto local=*shape;
        canvas_local_matrix(shape->matrix,local.matrix,tile);
        local.force_msaa=0;
        for(int index=0;index<msaa_count;++index) {
            auto* rect=msaa_rects+index*4;
            auto area=SkIRect::MakeXYWH(rect[0]-tile.x,rect[1]-tile.y,rect[2],rect[3]);
            if(area.intersect(tile.clip)) {
                // Select the pass before clipping away the origin marker.
                force_msaa_render_pass(canvas,tile.width,tile.height);
                break;
            }
        }
        canvas->clipRect(SkRect::Make(tile.clip));
        apply_canvas_clips(canvas,tile,clips,clip_count);
        draw_shape_on_canvas(canvas,local,tile.width,tile.height);
        canvas->restore();
    }
    return 1;
}

// Render each coverage mode in its own pass before selecting its raster tiles.
// A prior canvas path or a difference clip must not change rrect coverage.
#ifdef VOX_TEST_ISOLATED_CANVAS_FAILURE
static int vox_test_isolated_shape_fail_after = -1;
#endif
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_shape_isolated(VoxGraphiteShape const* shape, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count, int const* msaa_rects, int msaa_count)
{
    if (!shape || !bounds || msaa_count < 0 || msaa_count > 4096 || (msaa_count && !msaa_rects)) return 0;
    auto raster = SkRect::MakeLTRB(bounds[0], bounds[1], bounds[2], bounds[3]);
    if (!raster.isFinite() || raster.isEmpty()) return 0;
    auto size = raster.roundOut();
    if (size.width() <= 0 || size.height() <= 0 || size.width() > 16384 || size.height() > 16384
        || size_t(size.width()) * size.height() > 64 * 1024 * 1024 / 4) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!canvas_recorder) return 0;
    SkPaint copy;
    copy.setBlendMode(SkBlendMode::kSrc);
    struct Pass {
        CanvasTile* tile;
        SkIRect area;
        SkPath mask;
        bool masked, msaa;
        sk_sp<SkImage> result;
    };
    std::vector<Pass> passes;
    for (auto& tile : canvas_tiles) {
        auto area = SkRect::MakeLTRB(bounds[0] - tile.x, bounds[1] - tile.y,
            bounds[2] - tile.x, bounds[3] - tile.y).roundOut();
        auto visible = area;
        if (!visible.intersect(tile.clip)) continue;
        auto sampled = area;
        if (!sampled.intersect(SkIRect::MakeWH(tile.width, tile.height))) continue;
        SkPathBuilder builder;
        bool intersects = false;
        for (int index = 0; index < msaa_count; ++index) {
            auto* rect = msaa_rects + index * 4;
            auto part = SkIRect::MakeXYWH(rect[0] - tile.x, rect[1] - tile.y, rect[2], rect[3]);
            if (!part.intersect(area)) continue;
            builder.addRect(SkRect::Make(part));
            intersects = true;
        }
        auto mask = builder.detach();
        auto snapshot = tile.surface->makeImageSnapshot(sampled);
        if (!snapshot) return 0;
        for (int msaa = 0; msaa <= int(intersects); ++msaa) {
            auto scratch = SkSurfaces::RenderTarget(canvas_recorder.get(), canvas_info(area.width(), area.height()));
            if (!scratch) return 0;
            auto* draw = scratch->getCanvas();
            draw->drawImage(snapshot, sampled.x() - area.x(), sampled.y() - area.y(), SkSamplingOptions(), &copy);
            auto local = *shape;
            local.force_msaa = msaa;
            SkMatrix matrix;
            matrix.set9(shape->matrix);
            matrix.postTranslate(-(tile.x + area.x()), -(tile.y + area.y()));
            matrix.get9(local.matrix);
            draw_shape_on_canvas(draw, local, area.width(), area.height());
            auto result = scratch->makeImageSnapshot();
            if (!result) return 0;
            passes.push_back({&tile, area, mask, intersects, bool(msaa), std::move(result)});
#ifdef VOX_TEST_ISOLATED_CANVAS_FAILURE
            if (vox_test_isolated_shape_fail_after == 0) return 0;
            if (vox_test_isolated_shape_fail_after > 0) --vox_test_isolated_shape_fail_after;
#endif
        }
    }
    // Prepare every target before changing any destination; a failure can
    // replay the ordinary leaf over its original backdrop exactly once.
    for (auto const& pass : passes) {
        auto* canvas = pass.tile->surface->getCanvas();
        canvas->save();
        canvas->resetMatrix();
        canvas->clipRect(SkRect::Make(pass.area));
        if (pass.masked) canvas->clipPath(pass.mask, pass.msaa ? SkClipOp::kIntersect : SkClipOp::kDifference, false);
        apply_canvas_clips(canvas, *pass.tile, clips, clip_count);
        canvas->resetMatrix();
        canvas->drawImage(pass.result, pass.area.x(), pass.area.y(), SkSamplingOptions(), &copy);
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

static int canvas_draw_image(VoxGraphiteImage const* image, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count, int const* msaa_rects, int msaa_count)
{
    if (!image || !bounds || !image_draw_is_valid(image)) return 0;
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
    // The ordinary pass excludes the disjoint rectangles owned by MSAA tiles.
    int result = canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
        canvas->resetMatrix();
        for (int index = 0; index < msaa_count; ++index) {
            auto* rect = msaa_rects + index * 4;
            canvas->clipRect(SkRect::MakeXYWH(rect[0] - tile.x, rect[1] - tile.y,
                rect[2], rect[3]), SkClipOp::kDifference, false);
        }
        auto local = *image;
        local.flags &= ~VOX_GRAPHITE_IMAGE_FORCE_MSAA;
        canvas_local_matrix(image->matrix, local.matrix, tile);
        draw_prepared_image(canvas, &local, prepared);
    });
    if (msaa_count) {
        // Like the multisampled shape pass, preserve the backdrop and return
        // the image through the destination clips without a CPU round trip.
        SkPaint copy;
        copy.setBlendMode(SkBlendMode::kSrc);
        for (auto& tile : canvas_tiles) {
            auto area = SkRect::MakeLTRB(bounds[0] - tile.x, bounds[1] - tile.y,
                bounds[2] - tile.x, bounds[3] - tile.y).roundOut();
            if (!area.intersect(tile.clip)) continue;
            SkPathBuilder mask;
            bool intersects = false;
            for (int index = 0; index < msaa_count; ++index) {
                auto* rect = msaa_rects + index * 4;
                auto part = SkIRect::MakeXYWH(rect[0] - tile.x, rect[1] - tile.y,
                    rect[2], rect[3]);
                if (!part.intersect(area)) continue;
                mask.addRect(SkRect::Make(part));
                intersects = true;
            }
            if (!intersects) continue;
            auto snapshot = tile.surface->makeImageSnapshot(area);
            auto scratch = snapshot ? SkSurfaces::RenderTarget(canvas_recorder.get(),
                canvas_info(area.width(), area.height())) : nullptr;
            if (!scratch) return 0;
            auto* draw = scratch->getCanvas();
            draw->drawImage(snapshot, 0, 0, SkSamplingOptions(), &copy);
            force_msaa_render_pass(draw, area.width(), area.height());
            auto local = *image;
            local.flags &= ~VOX_GRAPHITE_IMAGE_FORCE_MSAA;
            SkMatrix matrix;
            matrix.set9(image->matrix);
            matrix.postTranslate(-(tile.x + area.x()), -(tile.y + area.y()));
            matrix.get9(local.matrix);
            draw_prepared_image(draw, &local, prepared);
            auto filtered = scratch->makeImageSnapshot();
            if (!filtered) return 0;
            auto* canvas = tile.surface->getCanvas();
            canvas->save();
            canvas->resetMatrix();
            canvas->clipRect(SkRect::Make(area));
            canvas->clipPath(mask.detach(), SkClipOp::kIntersect, false);
            apply_canvas_clips(canvas, tile, clips, clip_count);
            canvas->resetMatrix();
            canvas->drawImage(filtered, area.x(), area.y(), SkSamplingOptions(), &copy);
            canvas->restore();
        }
    }
    image_upload_cache.finish(std::move(prepared.upload), prepared.texture);
    return result;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_image(VoxGraphiteImage const* image, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count)
{
    return canvas_draw_image(image, bounds, clips, clip_count, nullptr, 0);
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_image_msaa(VoxGraphiteImage const* image, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count, int const* msaa_rects, int msaa_count)
{
    if (!msaa_rects || msaa_count <= 0 || msaa_count > 4096) return 0;
    return canvas_draw_image(image, bounds, clips, clip_count, msaa_rects, msaa_count);
}

// Premultiplied BGRA pixels rasterized on a transparent CPU target, composited
// source-over at an integral device position: text and other CPU-only leaves.
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_layer_pixels(uint8_t const* bgra, int width, int height, int pitch,
    int device_x, int device_y, VoxGraphiteCanvasClip const* clips, int clip_count, float opacity, int blend_mode)
{
    if (!bgra || width <= 0 || height <= 0 || width > 16384 || height > 16384 || pitch < width * 4
        || !std::isfinite(opacity) || opacity < 0 || opacity > 1 || (blend_mode != 0 && blend_mode != 3)) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!canvas_recorder) return 0;
    auto raster = SkImages::RasterFromPixmapCopy(SkPixmap(canvas_info(width, height), bgra, size_t(pitch)));
    auto image = raster ? vox_shared_image(canvas_recorder.get(), raster, {}) : nullptr;
    if (!image) return 0;
    SkPaint paint;
    paint.setAlphaf(opacity);
    paint.setBlendMode(blend_mode == 3 ? SkBlendMode::kScreen : SkBlendMode::kSrcOver);
    float bounds[] {float(device_x), float(device_y), float(device_x + width), float(device_y + height)};
    return canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
        canvas->setMatrix(SkMatrix::Translate(device_x - tile.x, device_y - tile.y));
        canvas->drawImage(image, 0, 0, SkSamplingOptions(SkFilterMode::kNearest), &paint);
    });
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_pixels(uint8_t const* bgra, int width, int height, int pitch,
    int device_x, int device_y, VoxGraphiteCanvasClip const* clips, int clip_count)
{
    return vox_graphite_canvas_draw_layer_pixels(bgra, width, height, pitch, device_x, device_y,
        clips, clip_count, 1, 0);
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_copy_pixels(uint8_t const* bgra, int width, int height, int pitch,
    int device_x, int device_y)
{
    if (!bgra || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || pitch < width * 4 || size_t(width) * height > 32 * 1024 * 1024 / 4
        || device_x < 0 || device_y < 0 || device_x > 16384 - width || device_y > 16384 - height) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!canvas_recorder) return 0;
    // Retained video backdrops often repeat unchanged across scroll frames.
    // This private cache owns exact source rows and textures, ignoring padding.
    // Larger inputs keep the ordinary upload rather than digest-only matching.
    bool cached = std::getenv("VOX_GPU_CANVAS_CACHE_BACKDROP")
        && size_t(width) * height <= 4 * 1024 * 1024 / 4;
    VoxGraphiteImage key {.width = width, .height = height, .pitch = pitch, .flags = 1, .pixels = bgra};
    auto request = cached ? canvas_backdrop_uploads.prepare(key, width, height, false)
        : decltype(canvas_backdrop_uploads)::Request{};
    auto image = request.texture;
    bool reused = bool(image);
    if (!image) {
        auto raster = SkImages::RasterFromPixmapCopy(SkPixmap(canvas_info(width, height), bgra, size_t(pitch)));
        image = raster ? vox_shared_image(canvas_recorder.get(), raster, {}) : nullptr;
    }
    if (!image) return 0;
    if (cached) {
        if (reused) ++canvas_backdrop_texture_hits;
        canvas_backdrop_uploads.finish(std::move(request), image);
        if (std::getenv("VOX_GPU_CANVAS_BACKDROP_CACHE_DIAGNOSTICS"))
            std::fprintf(stderr, "Vox GPU backdrop texture: reused=%d size=%dx%d\n", reused, width, height);
    }
    float bounds[] {float(device_x), float(device_y), float(device_x + width), float(device_y + height)};
    SkPaint copy;
    copy.setBlendMode(SkBlendMode::kSrc);
    return canvas_draw(bounds, nullptr, 0, [&](SkCanvas* canvas, CanvasTile const& tile) {
        canvas->setMatrix(SkMatrix::Translate(device_x - tile.x, device_y - tile.y));
        canvas->drawImage(image, 0, 0, SkSamplingOptions(SkFilterMode::kNearest), &copy);
    });
}

// An inset box shadow keeps Skia's double rounded rectangle, color filter and
// blur exactly as its tiled raster records them, drawn over the frame's pixels.
// In a Chromium MSAA tile it draws, as shapes do, in a multisampled scratch
// pass over a copy of the area and returns through the destination clips.
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_draw_picture(uint8_t const* bytes, size_t size, float const* bounds,
    VoxGraphiteCanvasClip const* clips, int clip_count, int msaa)
{
    if (!bytes || !size || size > 1024 * 1024 || !bounds) return 0;
    SkDeserialProcs procs;
    procs.fAllowSkSL = false;
    procs.fImageProc = [](void const*, size_t, std::optional<SkAlphaType>, void*) -> sk_sp<SkImage> {
        return nullptr;
    };
    procs.fTypefaceStreamProc = [](SkStream&, void*) -> sk_sp<SkTypeface> { return nullptr; };
    auto picture = SkPicture::MakeFromData(bytes, size, &procs);
    if (!picture) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!msaa)
        return canvas_draw(bounds, clips, clip_count, [&](SkCanvas* canvas, CanvasTile const& tile) {
            canvas->setMatrix(SkMatrix::Translate(-tile.x, -tile.y));
            canvas->drawPicture(picture);
        });
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
        force_msaa_render_pass(draw, area.width(), area.height());
        draw->setMatrix(SkMatrix::Translate(-(tile.x + area.x()), -(tile.y + area.y())));
        draw->drawPicture(picture);
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

static bool canvas_ensure_copy_pipeline(id<MTLDevice> device)
{
    if (!canvas_readback_pipeline) {
        // Read integer texels from the exact storage used by the established
        // reader. A Skia image draw can resample snapshot/resolve coverage.
        NSString* source=@"#include <metal_stdlib>\nusing namespace metal;\n"
            "kernel void canvas_readback(texture2d<float,access::read> source [[texture(0)]],"
            "texture2d<float,access::write> target [[texture(1)]],"
            "constant int4& offset [[buffer(0)]],uint2 p [[thread_position_in_grid]]) {"
            "uint2 s=p+uint2(offset.xy);target.write(source.read(s),s+uint2(offset.zw));}";
        id<MTLLibrary> library=[device newLibraryWithSource:source options:nil error:nil];
        id<MTLFunction> function=[library newFunctionWithName:@"canvas_readback"];
        canvas_readback_pipeline=function ? [device newComputePipelineStateWithFunction:function error:nil] : nil;
        [function release]; [library release];
        if (!canvas_readback_pipeline) return false;
    }
    return true;
}

#ifdef VOX_TEST_CANVAS_PRESENT
static void (*canvas_present_test_before_commit)(void*);
static void* canvas_present_test_context;
static int canvas_present_test_fail_target = -1;
#endif
// The kernel tracks cross-process IOSurface hazards once Metal work has been
// scheduled. Chromium uses the same boundary before Core Animation access;
// CPU capture still waits for completion. Targets stay private until success.
extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_present(VoxGraphiteCanvasSurfaceRegion const* regions,
    int count, void** completion)
{ @autoreleasepool {
    if (completion) *completion = nullptr;
    if (!completion || !regions || count <= 0 || count > 66) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu || !canvas_recorder || canvas_tiles.empty() || !gpu_frame_queue) return 0;
    auto device = vox_shared_metal_device(canvas_recorder.get());
    if (!device || !canvas_ensure_copy_pipeline(device)) return 0;
    auto valid_surface = [](IOSurfaceRef surface) {
        return surface && !IOSurfaceGetPlaneCount(surface)
            && IOSurfaceGetPixelFormat(surface) == uint32_t('RGBA')
            && IOSurfaceGetBytesPerElement(surface) == 4
            && IOSurfaceGetWidth(surface) > 0 && IOSurfaceGetWidth(surface) <= 16384
            && IOSurfaceGetHeight(surface) > 0 && IOSurfaceGetHeight(surface) <= 16384
            && IOSurfaceGetBytesPerRow(surface) >= IOSurfaceGetWidth(surface) * 4;
    };
    auto same_surface=[](IOSurfaceRef a, IOSurfaceRef b) {
        return a && b && IOSurfaceGetID(a)==IOSurfaceGetID(b);
    };
    std::vector<IOSurfaceRef> targets, previous, leases;
    std::vector<size_t> target_indices;
    std::vector<SkIRect> sources, destinations;
    size_t bytes = 0;
    for (int index=0; index<count; ++index) {
        auto const& region=regions[index];
        auto target=static_cast<IOSurfaceRef>(region.surface);
        auto prefix=static_cast<IOSurfaceRef>(region.previous);
        if (!valid_surface(target) || same_surface(target,prefix)
            || region.canvas_x < 0 || region.canvas_y < 0
            || region.surface_x < 0 || region.surface_y < 0
            || region.width <= 0 || region.height <= 0
            || region.width > 16384 || region.height > 16384
            || region.canvas_x > 32768-region.width || region.canvas_y > 32768-region.height
            || size_t(region.width) > IOSurfaceGetWidth(target)
            || size_t(region.surface_x) > IOSurfaceGetWidth(target)-size_t(region.width)
            || size_t(region.height) > IOSurfaceGetHeight(target)
            || size_t(region.surface_y) > IOSurfaceGetHeight(target)-size_t(region.height)
            || (prefix && (!valid_surface(prefix)
                || IOSurfaceGetWidth(prefix)!=IOSurfaceGetWidth(target)
                || IOSurfaceGetHeight(prefix)!=IOSurfaceGetHeight(target)))) return 0;
        auto source=SkIRect::MakeXYWH(region.canvas_x,region.canvas_y,region.width,region.height);
        auto destination=SkIRect::MakeXYWH(region.surface_x,region.surface_y,region.width,region.height);
        for (int earlier=0; earlier<index; ++earlier) {
            if (SkIRect::Intersects(source,sources[earlier])
                || (same_surface(static_cast<IOSurfaceRef>(regions[earlier].surface),target)
                    && SkIRect::Intersects(destination,destinations[earlier]))) return 0;
        }
        auto found=std::find_if(targets.begin(),targets.end(),[&](auto value){return same_surface(value,target);});
        size_t slot=found-targets.begin();
        if (found==targets.end()) {
            size_t allocation=IOSurfaceGetAllocSize(target);
            if (allocation > 128*1024*1024 || bytes > 128*1024*1024-allocation) return 0;
            bytes+=allocation;
            targets.push_back(target); previous.push_back(prefix);
        } else if (previous[slot]!=prefix && !same_surface(previous[slot],prefix)) return 0;
        target_indices.push_back(slot); sources.push_back(source); destinations.push_back(destination);
    }
    for (auto prefix:previous)
        if (prefix && std::any_of(targets.begin(),targets.end(),[&](auto value){return same_surface(value,prefix);})) return 0;
    std::vector<id<MTLTexture>> inputs;
    for (auto const& tile:canvas_tiles) {
        auto texture=vox_shared_metal_texture(tile.surface.get());
        if (!texture) return 0;
        auto damage=tile.clip.makeOffset(tile.x,tile.y);
        uint64_t covered=0;
        for (auto region:sources) if (region.intersect(damage))
            covered+=uint64_t(region.width())*region.height();
        if (covered!=uint64_t(damage.width())*damage.height()) return 0;
        inputs.push_back(texture);
    }
    std::vector<id<MTLTexture>> outputs, prefixes;
    auto release_textures=[&] {
        for (auto texture:outputs) [texture release];
        for (auto texture:prefixes) [texture release];
    };
    for (size_t index=0; index<targets.size(); ++index) {
        auto* descriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
            width:IOSurfaceGetWidth(targets[index]) height:IOSurfaceGetHeight(targets[index]) mipmapped:NO];
        descriptor.storageMode=MTLStorageModeShared;
        descriptor.usage=MTLTextureUsageShaderWrite|MTLTextureUsageRenderTarget;
#ifdef VOX_TEST_CANVAS_PRESENT
        if (canvas_present_test_fail_target == int(index)) { release_textures(); return 0; }
#endif
        auto output=[device newTextureWithDescriptor:descriptor iosurface:targets[index] plane:0];
        if (output) outputs.push_back(output);
        if (!output) { release_textures(); return 0; }
        id<MTLTexture> prefix=nil;
        if (previous[index]) {
            descriptor.usage=MTLTextureUsageShaderRead;
            prefix=[device newTextureWithDescriptor:descriptor iosurface:previous[index] plane:0];
            if (!prefix) { release_textures(); return 0; }
        }
        prefixes.push_back(prefix);
    }
    id<MTLCommandBuffer> commands=[gpu_frame_queue commandBuffer];
    bool encoded=commands!=nil;
    for (size_t index=0; encoded && index<targets.size(); ++index) {
        if (prefixes[index]) {
            auto encoder=[commands blitCommandEncoder];
            encoded=encoder!=nil;
            if (encoder) {
                [encoder copyFromTexture:prefixes[index] sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0)
                    sourceSize:MTLSizeMake(outputs[index].width,outputs[index].height,1)
                    toTexture:outputs[index] destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];
                [encoder endEncoding];
            }
        } else {
            auto* pass=[MTLRenderPassDescriptor renderPassDescriptor];
            pass.colorAttachments[0].texture=outputs[index];
            pass.colorAttachments[0].loadAction=MTLLoadActionClear;
            pass.colorAttachments[0].storeAction=MTLStoreActionStore;
            pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,0);
            auto encoder=[commands renderCommandEncoderWithDescriptor:pass];
            encoded=encoder!=nil;
            [encoder endEncoding];
        }
    }
    // Preserve the established order when the source canvas tiles overlap.
    for (size_t tile_index=0; encoded && tile_index<canvas_tiles.size(); ++tile_index) {
        auto const& tile=canvas_tiles[tile_index];
        auto damage=tile.clip.makeOffset(tile.x,tile.y);
        for (int index=0; encoded && index<count; ++index) {
            auto area=sources[index];
            if (!area.intersect(damage)) continue;
            auto encoder=[commands computeCommandEncoder];
            if (!encoder) { encoded=false; break; }
            auto const& region=regions[index];
            int offset[]={area.x()-tile.x,area.y()-tile.y,
                tile.x-region.canvas_x+region.surface_x,tile.y-region.canvas_y+region.surface_y};
            [encoder setComputePipelineState:canvas_readback_pipeline];
            [encoder setTexture:inputs[tile_index] atIndex:0];
            [encoder setTexture:outputs[target_indices[index]] atIndex:1];
            [encoder setBytes:offset length:sizeof(offset) atIndex:0];
            [encoder dispatchThreads:MTLSizeMake(area.width(),area.height(),1) threadsPerThreadgroup:MTLSizeMake(8,8,1)];
            [encoder endEncoding];
        }
    }
    release_textures();
    if (!encoded) return 0;
    auto recording=canvas_recorder->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording=recording.get();
        if (gpu->insertRecording(insertion)!=skgpu::graphite::InsertStatus::kSuccess) return -1;
    }
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kNo))) return -1;
    for (auto surface:targets) leases.push_back(surface);
    for (auto surface:previous) if (surface && !std::any_of(leases.begin(),leases.end(),[&](auto value){return same_surface(value,surface);})) leases.push_back(surface);
    for (auto surface:leases) { CFRetain(surface); IOSurfaceIncrementUseCount(surface); }
    [commands addCompletedHandler:^(id<MTLCommandBuffer>) {
        for (auto surface:leases) { IOSurfaceDecrementUseCount(surface); CFRelease(surface); }
    }];
#ifdef VOX_TEST_CANVAS_PRESENT
    if (canvas_present_test_before_commit) canvas_present_test_before_commit(canvas_present_test_context);
#endif
    [commands commit];
    [commands waitUntilScheduled];
    if (commands.status==MTLCommandBufferStatusError) {
#ifdef VOX_TEST_CANVAS_PRESENT
        std::fprintf(stderr,"GPU present error: %s\n",commands.error.description.UTF8String);
#endif
        return -1;
    }
    *completion=(__bridge void*)[commands retain];
    return 1;
} }

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_wait_present(void* completion)
{
    if (!completion) return 0;
    auto commands=(__bridge id<MTLCommandBuffer>)completion;
    [commands waitUntilCompleted];
    bool ok=commands.status==MTLCommandBufferStatusCompleted;
    [commands release];
    return ok;
}
extern "C" __attribute__((visibility("default")))
void vox_graphite_canvas_release_present(void* completion)
{
    [(__bridge id<MTLCommandBuffer>)completion release];
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_read_iosurface(void* handle, int width, int height)
{ @autoreleasepool {
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    auto surface = static_cast<IOSurfaceRef>(handle);
    if (!gpu || !surface || !canvas_recorder || canvas_tiles.empty()
        || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || size_t(width) * height > canvas_pool_byte_limit / 4
        || IOSurfaceGetWidth(surface) != size_t(width)
        || IOSurfaceGetHeight(surface) != size_t(height)
        || IOSurfaceGetPixelFormat(surface) != uint32_t('RGBA')
        || IOSurfaceGetBytesPerElement(surface) != 4
        || IOSurfaceGetBytesPerRow(surface) < size_t(width) * 4) return 0;
    auto device = vox_shared_metal_device(canvas_recorder.get());
    if (!device || !gpu_frame_queue) return 0;
    if (!canvas_ensure_copy_pipeline(device)) return 0;
    auto frame = SkIRect::MakeWH(width,height);
    std::vector<id<MTLTexture>> textures;
    for (auto const& tile : canvas_tiles) {
        auto damage=tile.clip.makeOffset(tile.x,tile.y);
        auto texture=vox_shared_metal_texture(tile.surface.get());
        if (!frame.contains(damage) || !texture) return 0;
        textures.push_back(texture);
    }
    auto* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
        width:width height:height mipmapped:NO];
    descriptor.storageMode=MTLStorageModeShared;
    descriptor.usage=MTLTextureUsageShaderWrite;
    id<MTLTexture> target=[device newTextureWithDescriptor:descriptor iosurface:surface plane:0];
    if (!target) return 0;
    id<MTLCommandBuffer> commands=[gpu_frame_queue commandBuffer];
    bool encoded=commands!=nil;
    for(size_t index=0;encoded && index<canvas_tiles.size();++index) {
        auto const& tile=canvas_tiles[index];
        // Separate encoders preserve ordered overlapping damage writes with
        // Metal's ordinary tracked resource hazards.
        id<MTLComputeCommandEncoder> encoder=[commands computeCommandEncoder];
        if (!encoder) { encoded=false; break; }
        int offset[]={tile.clip.x(),tile.clip.y(),tile.x,tile.y};
        [encoder setComputePipelineState:canvas_readback_pipeline];
        [encoder setTexture:textures[index] atIndex:0];
        [encoder setTexture:target atIndex:1];
        [encoder setBytes:offset length:sizeof(offset) atIndex:0];
        [encoder dispatchThreads:MTLSizeMake(tile.clip.width(),tile.clip.height(),1)
            threadsPerThreadgroup:MTLSizeMake(8,8,1)];
        [encoder endEncoding];
    }
    [target release]; // The command buffer owns its encoded resources.
    if (!encoded || IOSurfaceUnlock(surface,0,nullptr)!=kIOReturnSuccess) return 0;
    auto recording=canvas_recorder->snap();
    bool ok=true;
    if(recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording=recording.get();
        ok=gpu->insertRecording(insertion)==skgpu::graphite::InsertStatus::kSuccess;
    }
    // Both submissions use the same VoxFrameMetalQueue. The source recording
    // commits first; waiting for the following compute command completes both.
    bool submitted=gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kNo));
    if(ok && submitted) {
        [commands commit]; [commands waitUntilCompleted];
        ok=commands.status==MTLCommandBufferStatusCompleted;
    } else {
        // Finish any accepted source work before returning CPU access.
        gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes));
    }
    gpu->checkAsyncWorkCompletion();
    bool locked = IOSurfaceLock(surface,0,nullptr) == kIOReturnSuccess;
    return ok && submitted && locked ? 1 : -1;
} }

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_read_direct(VoxGraphitePixelRegion const* views, int count)
{
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu || !views || count != int(canvas_tiles.size()) || !canvas_recorder) return 0;
    // Validate every destination and target before submitting or touching any
    // output. The caller can fall back to the staged reader on failure.
    std::vector<id<MTLTexture>> textures;
    for (int index = 0; index < count; ++index) {
        auto const& tile = canvas_tiles[size_t(index)];
        auto const& view = views[index];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > tile.width || view.x > tile.width - view.width
            || view.height > tile.height || view.y > tile.height - view.height
            || view.width > INT_MAX / 4 || view.pitch < view.width * 4) return 0;
        auto texture = vox_shared_metal_texture(tile.surface.get());
        if (!texture) return 0;
        textures.push_back(texture);
    }
    auto recording = canvas_recorder->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    }
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) return 0;
    for (int index = 0; index < count; ++index) {
        auto const& view = views[index];
        [textures[size_t(index)] getBytes:view.pixels bytesPerRow:view.pitch
            fromRegion:MTLRegionMake2D(view.x, view.y, view.width, view.height) mipmapLevel:0];
    }
    return 1;
}

// Stage all damaged rectangles in one Metal submission. getBytes() on a
// compressed render target otherwise expands its tiles on the calling thread.
// The GPU blit resolves that storage before one wait and an ordinary row copy.
#ifdef VOX_TEST_CANVAS_BLIT_FAILURE
static int vox_test_canvas_blit_fail_after = -1;
static unsigned vox_test_canvas_blit_calls;
#endif
static int canvas_read_blit(VoxGraphitePixelRegion const* views, int count)
{ @autoreleasepool {
    auto* gpu = context();
    id<MTLDevice> device = vox_shared_metal_device(canvas_recorder.get());
    if (!gpu || !device || !gpu_frame_queue || !views || count <= 0
        || count != int(canvas_tiles.size())) return 0;
    NSMutableArray<id<MTLBuffer>>* buffers = [NSMutableArray array];
    std::vector<id<MTLTexture>> textures;
    std::vector<size_t> pitches;
    size_t bytes = 0;
    constexpr size_t limit = 64 * 1024 * 1024;
    // Validate and allocate everything before submitting or touching output.
    for (int index = 0; index < count; ++index) {
        auto const& tile = canvas_tiles[size_t(index)];
        auto const& view = views[index];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > tile.width || view.x > tile.width - view.width
            || view.height > tile.height || view.y > tile.height - view.height
            || view.width > INT_MAX / 4 || view.pitch < view.width * 4) return 0;
        auto texture = vox_shared_metal_texture(tile.surface.get());
        if (!texture) return 0;
        size_t pitch = (size_t(view.width) * 4 + 255) & ~size_t(255);
        if (pitch > (limit - bytes) / size_t(view.height)) return 0;
        size_t length = pitch * size_t(view.height);
        id<MTLBuffer> buffer = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        if (!buffer) return 0;
        [buffers addObject:buffer]; [buffer release];
        textures.push_back(texture); pitches.push_back(pitch); bytes += length;
#ifdef VOX_TEST_CANVAS_BLIT_FAILURE
        if (vox_test_canvas_blit_fail_after == index) return 0;
#endif
    }
    id<MTLCommandBuffer> commands = [gpu_frame_queue commandBuffer];
    id<MTLBlitCommandEncoder> encoder = [commands blitCommandEncoder];
    if (!encoder) return 0;
    for (int index = 0; index < count; ++index) {
        auto const& view = views[index];
        [encoder copyFromTexture:textures[size_t(index)] sourceSlice:0 sourceLevel:0
            sourceOrigin:MTLOriginMake(view.x, view.y, 0)
            sourceSize:MTLSizeMake(view.width, view.height, 1)
            toBuffer:buffers[index] destinationOffset:0 destinationBytesPerRow:pitches[size_t(index)]
            destinationBytesPerImage:pitches[size_t(index)] * size_t(view.height)];
    }
    [encoder endEncoding];
    auto recording = canvas_recorder->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    }
    // Both command buffers use VoxFrameMetalQueue; source writers commit first.
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kNo))) return 0;
    [commands commit]; [commands waitUntilCompleted];
    gpu->checkAsyncWorkCompletion();
    if (commands.status != MTLCommandBufferStatusCompleted) return 0;
    for (int index = 0; index < count; ++index) {
        auto const& view = views[index];
        auto* source = static_cast<uint8_t const*>(buffers[index].contents);
        for (int row = 0; row < view.height; ++row)
            std::memcpy(view.pixels + size_t(row) * view.pitch,
                source + size_t(row) * pitches[size_t(index)], size_t(view.width) * 4);
    }
    if (std::getenv("VOX_GPU_CANVAS_BLIT_READBACK_DIAGNOSTICS"))
        std::fprintf(stderr, "VOX_GPU_BLIT_READBACK regions=%d bytes=%zu\n", count, bytes);
#ifdef VOX_TEST_CANVAS_BLIT_FAILURE
    ++vox_test_canvas_blit_calls;
#endif
    return 1;
} }

extern "C" __attribute__((visibility("default")))
int vox_graphite_canvas_read(VoxGraphitePixelRegion const* views, int count)
{
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu || !views || count != int(canvas_tiles.size()) || !canvas_recorder) return 0;
    for (int index = 0; index < count; ++index) {
        auto const& tile = canvas_tiles[size_t(index)];
        auto const& view = views[index];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > tile.width || view.x > tile.width - view.width
            || view.height > tile.height || view.y > tile.height - view.height
            || view.width > INT_MAX / 4 || view.pitch < view.width * 4) return 0;
    }
    if (std::getenv("VOX_GPU_CANVAS_BLIT_READBACK") && canvas_read_blit(views, count)) return 1;
    auto recording = canvas_recorder->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    }
    for (int index = 0; index < count; ++index) {
        auto const& tile = canvas_tiles[size_t(index)];
        auto const& view = views[index];
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
