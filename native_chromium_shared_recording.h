#pragma once
#include "native_opacity_group_darwin.h"

// Included after the native raster-layer state. The existing leaf renderer
// supplies the fallback frame; complete supported pictures replace root SVG
// tiles or one isolated CSS compositor surface before it is composited.
namespace {
struct SharedRootRecording {
    std::unique_ptr<SkPictureRecorder> recorder;
    CGContextRef destination;
    float canvas_width, canvas_height, scale, page_y = 0;
    int viewport_width, viewport_height;
    int tile_width = 0, tile_height = 0, columns = 0, rows = 0;
    double scroll_y = 0;
    bool root = true;
    bool speculative = false;
    bool checks_prefix = false;
    VoxRasterSnapshot original_prefix;
    float origin_x = 0, origin_y = 0, layer_width = 0, layer_height = 0;
    std::vector<SkRect> replay_bounds;
    std::vector<SkRect> blocked_bounds;
    std::vector<uint32_t> backdrop;
    int backdrop_width = 0;
    unsigned deferred_leaves = 0;
};
std::unique_ptr<SharedRootRecording> s_shared_root_recording;
bool s_shared_root_enabled = false;
bool s_shared_layer_enabled = false;
bool s_speculative_layer_enabled = false;
bool s_shared_layer_backdrop = false;
int s_shared_viewport_width = 0, s_shared_viewport_height = 0;
bool s_deferred_layer_frame_enabled = false;
bool s_deferred_layer_frame_failed = false;
std::unordered_map<CGContextRef, CGRect> s_deferred_layer_destinations;

extern "C" void ladybird_v_skia_begin_deferred_layer_frame(int enabled)
{
    s_deferred_layer_frame_enabled = enabled && !std::getenv("VOX_DISABLE_DEFERRED_LAYERS");
    s_deferred_layer_frame_failed = false;
    s_speculative_layer_enabled = false;
    s_deferred_layer_destinations.clear();
}

extern "C" int ladybird_v_skia_finish_deferred_layer_frame()
{
    int result = !s_deferred_layer_frame_failed;
    s_deferred_layer_frame_enabled = false;
    s_speculative_layer_enabled = false;
    s_deferred_layer_destinations.clear();
    return result;
}

// The native adapter calls this only for its private opacity bitmap, whose
// initial clip is constructed with ClipToRect. Never infer a rectangular clip
// from an arbitrary CGContext's bounding box.
extern "C" void ladybird_v_skia_set_deferred_layer_destination(CGContextRef context, int active)
{
    if (!active) { s_deferred_layer_destinations.erase(context); return; }
    if (!s_deferred_layer_frame_enabled || !context) return;
    auto clip = CGContextConvertRectToDeviceSpace(context, CGContextGetClipBoundingBox(context));
    if (CGRectIsEmpty(clip) || CGRectIsNull(clip) || CGRectIsInfinite(clip)) return;
    for (double edge : {CGRectGetMinX(clip), CGRectGetMinY(clip), CGRectGetMaxX(clip), CGRectGetMaxY(clip)})
        if (!std::isfinite(edge) || edge != std::floor(edge)) return;
    s_deferred_layer_destinations[context] = clip;
}

bool shared_recording_defers_leaf_raster(CGContextRef destination, SkRect const& ink)
{
    if (!s_deferred_layer_frame_enabled || !ink.isFinite() || ink.isEmpty()
        || !s_shared_root_recording || s_shared_root_recording->root
        || s_shared_root_recording->destination != destination
        || s_shared_root_recording->replay_bounds.empty()
        || !s_shared_root_recording->blocked_bounds.empty()
        || !s_deferred_layer_destinations.count(destination)) return false;
    auto& group = *s_shared_root_recording;
    auto bounds = SkRect::MakeXYWH(group.origin_x,
        group.origin_y + group.page_y - group.scroll_y, group.layer_width, group.layer_height);
    for (auto drawn : group.replay_bounds) {
        if (!drawn.isFinite()) return false;
        bounds.join(drawn);
    }
    // Preserve old fallback pixels outside the complete picture's publication
    // bounds, including text overflow and antialiasing fringes.
    if (!bounds.contains(ink)) return false;
    ++group.deferred_leaves;
    return true;
}

static double speculative_picture_time();
static void speculative_picture_decline(SharedRootRecording const&);
struct DeferredLayerPublication {
    SharedRootRecording const& group;
    bool published = false;
    ~DeferredLayerPublication() {
        if (group.deferred_leaves && !published) {
            s_deferred_layer_frame_failed = true;
            if (group.speculative) speculative_picture_decline(group);
            if (group.speculative && std::getenv("VOX_SPECULATIVE_PICTURE_DIAGNOSTICS"))
                std::fprintf(stderr, "VOX_SPECULATIVE_PICTURE_FAILED leaves=%u t_us=%.3f\n",
                    group.deferred_leaves, speculative_picture_time());
        }
    }
};
#ifdef VOX_TEST_DEFERRED_LAYERS
bool s_test_fail_deferred_layer;
#endif


struct SharedClip {
    SkRRect rect;
    SkMatrix matrix;
};
struct SharedClipState {
    std::vector<SharedClip> clips;
    bool unsupported = false;
    std::vector<std::pair<size_t, bool>> saves;
};
// Clips can precede the first recorded draw. Keep their state per destination,
// including while an offscreen mask or compositor layer is being painted.
std::unordered_map<CGContextRef, SharedClipState> s_shared_clips;

#include "native_chromium_speculative_recording.h"

decltype(&vox_graphite_draw_picture_pixels) shared_picture_draw()
{
    static auto draw = [] {
        void* library = dlopen("@rpath/libVoxGraphiteDawn.dylib", RTLD_LAZY | RTLD_LOCAL);
        return library ? reinterpret_cast<decltype(&vox_graphite_draw_picture_pixels)>(
            dlsym(library, "vox_graphite_draw_picture_pixels")) : nullptr;
    }();
    return draw;
}

SkCanvas* shared_recording_canvas(CGContextRef destination)
{
    if (auto* canvas = isolated_input_recording_canvas(destination)) return canvas;
    if (!(s_speculative_layer_enabled || (s_raster_layer_is_root ? s_shared_root_enabled : s_shared_layer_enabled))
        || !s_chromium_painting || !destination || !shared_picture_draw()) return nullptr;
    if (!s_shared_root_recording) {
        auto scale = raster_scale_for_context(destination);
        float width = CGBitmapContextGetWidth(destination) / scale;
        float height = CGBitmapContextGetHeight(destination) / scale;
        if (!(width > 0 && height > 0) || width > 16384 || height > 16384) return nullptr;
        auto group = std::make_unique<SharedRootRecording>();
        group->destination = destination;
        group->canvas_width = width;
        group->canvas_height = height;
        group->scale = scale;
        group->checks_prefix = s_raster_layer_is_root && s_speculative_layer_enabled;
        group->root = s_raster_layer_is_root && !group->checks_prefix;
        group->speculative = s_speculative_layer_enabled;
        group->origin_x = s_raster_origin_x;
        group->origin_y = s_raster_origin_y;
        group->layer_width = s_raster_layer_width;
        group->layer_height = s_raster_layer_height;
        group->viewport_width = s_shared_viewport_width;
        group->viewport_height = s_shared_viewport_height;
        if (!group->root) {
            // A child effect flushes its parent's picture, then paints into
            // that parent's bitmap. The next picture must retain this prefix
            // even when the parent is itself a transparent compositor layer.
            // Snapshot before recording fallback leaves so they blend once.
            int pixel_width = CGBitmapContextGetWidth(destination);
            int pixel_height = CGBitmapContextGetHeight(destination);
            if (size_t(pixel_width) * pixel_height > 8 * 1024 * 1024) return nullptr;
            auto prefix = read_backdrop(destination, {}, scale, pixel_width, pixel_height);
            if (!prefix.pixels) return nullptr;
            if (group->checks_prefix)
                group->original_prefix = VoxRasterSnapshot(prefix.pixels,
                    size_t(pixel_width) * 4, prefix.pitch, pixel_height);
            int left, top, right, bottom;
            // An empty canvas still uses the layer's fractional local origin.
            // A painted prefix already belongs to the destination's pixel grid.
            if (s_shared_layer_backdrop || group->speculative || native_opacity_layer_ink_bounds(prefix.pixels, prefix.pitch, 0, 0,
                    pixel_width, pixel_height, &left, &top, &right, &bottom)) {
                group->backdrop.resize(size_t(pixel_width) * pixel_height);
                copy_backdrop_pixels(prefix, pixel_width, pixel_height, group->backdrop);
                group->backdrop_width = pixel_width;
            }
        }
        group->recorder = std::make_unique<SkPictureRecorder>();
        auto* canvas = group->recorder->beginRecording(SkRect::MakeWH(width, height));
        // A compositor picture starts transparent, even over an opaque
        // destination. Its combined premultiplied ink is rounded before the
        // picture meets that prefix. Keep the prefix for publication below;
        // painting it into the picture changes overlapping shadow coverage.
        s_shared_root_recording = std::move(group);
    }
    return s_shared_root_recording->destination == destination
        ? s_shared_root_recording->recorder->getRecordingCanvas() : nullptr;
}

void shared_recording_block(SkRect bounds)
{
    if (s_shared_root_recording)
        s_shared_root_recording->blocked_bounds.push_back(bounds.makeOutset(2, 2));
}

void shared_recording_block(CGContextRef destination, SkRect bounds)
{
    auto input = s_isolated_input_recordings.find(destination);
    if (input != s_isolated_input_recordings.end())
        input->second->unsupported = true;
    else
        shared_recording_block(bounds);
}

void shared_recording_clip(CGContextRef destination, SkCanvas* canvas)
{
    canvas->resetMatrix();
    auto found = s_shared_clips.find(destination);
    if (found == s_shared_clips.end()) return;
    if (found->second.unsupported) {
        auto filter = s_isolated_input_recordings.find(destination);
        if (filter != s_isolated_input_recordings.end()) {
            filter->second->unsupported = true;
            return;
        }
        if (s_shared_root_recording)
            shared_recording_block(SkRect::MakeWH(s_shared_root_recording->canvas_width,
                s_shared_root_recording->canvas_height));
        return;
    }
    for (auto const& clip : found->second.clips) {
        canvas->setMatrix(clip.matrix);
        canvas->clipRRect(clip.rect, true);
    }
    canvas->resetMatrix();
}

void shared_recording_content(CGContextRef destination, SkRect bounds, float page_y, float scroll_y)
{
    auto filter = s_isolated_input_recordings.find(destination);
    if (filter != s_isolated_input_recordings.end()) {
        filter->second->bounds.join(bounds);
        return;
    }
    if (!shared_recording_canvas(destination) || s_msaa_grid_columns <= 0) return;
    auto& group = *s_shared_root_recording;
    group.replay_bounds.push_back(bounds);
    group.page_y = page_y;
    // Browser display-list matrices already include root scrolling. The
    // explicit bridge offset is additional scrolling, so both translations
    // must be removed when locating a non-root tile in document coordinates.
    group.scroll_y = s_root_raster_scroll_y + (group.root ? 0 : scroll_y);
    group.tile_width = s_msaa_grid_width;
    group.tile_height = s_msaa_grid_height;
    group.columns = s_msaa_grid_columns;
    int height = std::max(1, int(std::ceil(s_raster_layer_height * group.scale)));
    group.rows = std::max(1, (height - 2 + group.tile_height - 3) / (group.tile_height - 2));
}

void shared_recording_speculative_content(CGContextRef destination, SkRect bounds,
    float page_y, float scroll_y)
{
    if (!s_shared_root_recording || !s_shared_root_recording->speculative
        || s_shared_root_recording->destination != destination || !bounds.isFinite()) return;
    if (complete_speculative_picture_enabled())
        shared_recording_content(destination, bounds, page_y, scroll_y);
}

sk_sp<SkData> serialize_shared_picture_image(SkImage* image, void*)
{
    auto bytes = vox_encode_picture_image(image);
    return SharedPicturePixelsScope::active
        ? SharedPicturePixelsScope::active->encode(std::move(bytes)) : bytes;
}

void shared_recording_image(CGContextRef destination, SkMatrix const& matrix,
    VoxGraphiteImage const& image)
{
    auto* canvas = shared_recording_canvas(destination);
    if (!canvas) return;
    auto target = SkRect::MakeXYWH(image.destination[0], image.destination[1],
        image.destination[2], image.destination[3]);
    if (image.has_background_color)
        target.join(SkRect::MakeXYWH(image.clip[0], image.clip[1], image.clip[2], image.clip[3]));
    if (image.border_width > 0) {
        auto border = SkRect::MakeXYWH(image.border_rect[0], image.border_rect[1],
            image.border_rect[2], image.border_rect[3]);
        border.outset(image.border_width / 2, image.border_width / 2);
        target.join(border);
    }
    if ((image.flags & (4 | 64 | 128 | VOX_GRAPHITE_IMAGE_ROUNDED_ALPHA_MASK)) || image.has_background_color
        || image.border_width > 0
        || size_t(image.width) * image.height > 8 * 1024 * 1024) {
        shared_recording_block(destination, matrix.mapRect(target));
        return;
    }
    auto info = SkImageInfo::Make(image.width, image.height, kRGBA_8888_SkColorType,
        (image.flags & 1) ? kPremul_SkAlphaType : kUnpremul_SkAlphaType,
        vox_image_color_space_from_profile(image.has_color_profile ? image.color_profile : nullptr));
    SkPixmap source(info, image.pixels, image.pitch);
    std::vector<uint8_t> premultiplied;
    if (!(image.flags & 1)) {
        premultiplied.resize(size_t(image.width) * image.height * 4);
        info = info.makeAlphaType(kPremul_SkAlphaType);
        if (!source.readPixels(info, premultiplied.data(), size_t(image.width) * 4)) {
            shared_recording_block(destination, matrix.mapRect(target));
            return;
        }
        source = SkPixmap(info, premultiplied.data(), size_t(image.width) * 4);
    }
    int upload_width = image.width, upload_height = image.height;
    auto input = s_isolated_input_recordings.find(destination);
    float scale = input != s_isolated_input_recordings.end()
        ? input->second->scale : s_shared_root_recording->scale;
    if (input != s_isolated_input_recordings.end())
        input->second->bounds.join(matrix.mapRect(target));
    float scale_x = std::hypot(matrix.getScaleX() * scale, matrix.getSkewY() * scale)
        * image.destination[2] / image.source[2];
    float scale_y = std::hypot(matrix.getSkewX() * scale, matrix.getScaleY() * scale)
        * image.destination[3] / image.source[3];
    float target_width = image.width * scale_x, target_height = image.height * scale_y;
    bool complete_source = image.source[0] == 0 && image.source[1] == 0
        && image.source[2] == image.width && image.source[3] == image.height;
    // DrawImageRectOp::Serialize requests the full image at the draw's scale;
    // the strict source crop is applied after the decoded upload is selected.
    int decode_level = image.nearest ? 0 : vox_image_decode_level(image.flags);
    if (decode_level >= 0) {
        upload_width = vox_image_decode_axis(image.width, decode_level);
        upload_height = vox_image_decode_axis(image.height, decode_level);
    } else if (!image.nearest) {
        for (int level = 1; level < 31; ++level) {
            int divisor = 1 << level;
            int width = (image.width + divisor - 1) / divisor;
            int height = (image.height + divisor - 1) / divisor;
            if (width < std::ceil(target_width) || height < std::ceil(target_height)) break;
            upload_width = width;
            upload_height = height;
            if (width == 1 && height == 1) break;
        }
    }
    std::vector<uint8_t> scaled;
    if (upload_width != image.width || upload_height != image.height) {
        scaled.resize(size_t(upload_width) * upload_height * 4);
        SkPixmap resized(info.makeWH(upload_width, upload_height), scaled.data(), size_t(upload_width) * 4);
        // The recorder and GPU backend use different Skia revisions. Their CPU
        // resamplers differ, especially for odd source sizes; serialize the
        // same Chromium-pinned upload that a leaf draw would use.
        auto resize = graphite_image_resize();
        auto input = image;
        input.pixels = static_cast<uint8_t const*>(source.addr());
        input.pitch = int(source.rowBytes());
        input.flags = 1;
        bool success = resize
            ? resize(&input, scaled.data(), upload_width, upload_height, upload_width * 4)
            : source.scalePixels(resized, SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest));
        if (!success) {
            shared_recording_block(destination, matrix.mapRect(target));
            return;
        }
        source = resized;
    }
    auto bitmap = SkImages::RasterFromPixmapCopy(source);
    if (!bitmap) { shared_recording_block(destination, matrix.mapRect(target)); return; }
    float sx = float(upload_width) / image.width, sy = float(upload_height) / image.height;
    auto source_rect = SkRect::MakeXYWH(image.source[0] * sx, image.source[1] * sy,
        image.source[2] * sx, image.source[3] * sy);
    auto clip = SkRect::MakeXYWH(image.clip[0], image.clip[1], image.clip[2], image.clip[3]);
    bool mips = !image.nearest
        && target_width < upload_width && target_height < upload_height;
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(image.opacity);
    canvas->save();
    shared_recording_clip(destination, canvas);
    canvas->setMatrix(matrix);
    bool rounded = std::any_of(image.clip + 4, image.clip + 12, [](float radius) { return radius != 0; });
    if (rounded) {
        SkVector radii[] {{image.clip[4], image.clip[5]}, {image.clip[6], image.clip[7]},
            {image.clip[8], image.clip[9]}, {image.clip[10], image.clip[11]}};
        SkRRect shape;
        shape.setRectRadii(clip, radii);
        canvas->clipRRect(shape, SkClipOp::kIntersect, true);
    } else if (clip != target) canvas->clipRect(clip, true);
    auto sampling = SkSamplingOptions(image.nearest ? SkFilterMode::kNearest : SkFilterMode::kLinear,
        mips ? SkMipmapMode::kLinear : SkMipmapMode::kNone);
    if (complete_source) {
        // Blink keeps full images in natural coordinates and scales the
        // canvas. Folding that scale into the destination changes fractional
        // sampling even when the outer bounds and upload are identical.
        auto natural = SkRect::MakeXYWH(image.source[0], image.source[1],
            image.source[2], image.source[3]);
        canvas->concat(SkMatrix::RectToRect(natural, target));
        if (mips && source_rect.contains(SkRect::MakeWH(upload_width, upload_height))) {
            // cc::DrawImageRect replays a complete mipmapped source as a
            // natural image after applying its decode scale to the canvas.
            // Keeping that scale inside drawImageRect changes filtered texels.
            canvas->concat(SkMatrix::RectToRect(source_rect, natural));
            canvas->drawImage(bitmap, 0, 0, sampling, &paint);
        } else {
            canvas->drawImageRect(bitmap, source_rect, natural, sampling, &paint,
                image.nearest || mips ? SkCanvas::kStrict_SrcRectConstraint : SkCanvas::kFast_SrcRectConstraint);
        }
    } else {
        canvas->drawImageRect(bitmap, source_rect, target, sampling, &paint, SkCanvas::kStrict_SrcRectConstraint);
    }
    canvas->restore();
}

#include "native_chromium_retained_tiles.h"

void finish_shared_recording()
{
    auto group = std::move(s_shared_root_recording);
    if (!group) return;
    DeferredLayerPublication publication {*group};
    if (group->replay_bounds.empty() || !group->columns) return;
    if (group->checks_prefix) {
        // Root drawing can include platform operations outside this recorder.
        // No deferred root picture may overwrite those pixels. Compare the
        // untouched destination against its owned initial prefix, and replay
        // the whole frame if an unrecorded or non-deferred draw changed it.
        int width = CGBitmapContextGetWidth(group->destination);
        int height = CGBitmapContextGetHeight(group->destination);
        auto current = read_backdrop(group->destination, {}, group->scale, width, height);
        if (!current.pixels || !group->original_prefix.equal(current.pixels, size_t(width) * 4, current.pitch, height)) {
            speculative_picture_decline(*group);
            if (std::getenv("VOX_SPECULATIVE_PICTURE_DIAGNOSTICS"))
                std::fprintf(stderr, "VOX_SPECULATIVE_ROOT_CHANGED leaves=%u t_us=%.3f\n",
                    group->deferred_leaves, speculative_picture_time());
            return;
        }
    }
#ifdef VOX_TEST_DEFERRED_LAYERS
    if (s_test_fail_deferred_layer && group->deferred_leaves) return;
#endif
    if (group->deferred_leaves) {
        auto found = s_deferred_layer_destinations.find(group->destination);
        auto clip = CGContextConvertRectToDeviceSpace(group->destination,
            CGContextGetClipBoundingBox(group->destination));
        if (found == s_deferred_layer_destinations.end() || !CGRectEqualToRect(found->second, clip)) return;
    }
    if (int64_t(group->columns) * group->rows > INT32_MAX) return;
    auto picture = group->recorder->finishRecordingAsPicture();
    SkSerialProcs procs;
    procs.fImageProc = serialize_shared_picture_image;
    procs.fTypefaceProc = vox_serialize_picture_typeface;
    sk_sp<SkData> bytes;
    if (!group->root) {
        // A layer is atomic: an unsupported image, allocation failure or backend
        // failure leaves all of its ordinary leaf draws intact.
        if (!group->blocked_bounds.empty() || !(group->layer_width > 0)
            || !(group->layer_height > 0) || !std::isfinite(group->layer_width)
            || !std::isfinite(group->layer_height)
            || group->layer_width * group->scale > (group->checks_prefix ? 16777216 : 16384)
            || group->layer_height * group->scale > (group->checks_prefix ? 16777216 : 16384)) return;
        float left = group->origin_x;
        float top = group->origin_y + group->page_y - group->scroll_y;
        auto bounds = SkRect::MakeXYWH(left, top, group->layer_width, group->layer_height);
        // Shadows and SVG overflow can paint beyond the compositor box. Replace
        // their complete ink together with the contents, including the blur tail.
        for (auto ink : group->replay_bounds) {
            if (!ink.isFinite()) return;
            bounds.join(ink);
        }
        if (!bounds.intersect(SkRect::MakeWH(group->canvas_width, group->canvas_height))) return;
        // Retain the local raster phase when no leading overflow needs extra
        // pixels; rounding every origin also shifts existing fractional SVGs.
        if (bounds.left() != left || !group->backdrop.empty())
            left = std::floor(bounds.left() * group->scale) / group->scale;
        if (bounds.top() != top || !group->backdrop.empty())
            top = std::floor(bounds.top() * group->scale) / group->scale;
        int width = std::ceil((bounds.right() - left) * group->scale);
        int height = std::ceil((bounds.bottom() - top) * group->scale);
        if (width <= 0 || height <= 0 || width > 16384 || height > 16384
            || size_t(width) * height > 8 * 1024 * 1024) return;
        float matrix[] {group->scale, 0, -left * group->scale,
            0, group->scale, -top * group->scale, 0, 0, 1};
        std::vector<uint32_t> pixels(size_t(width) * height);
        double first_x = (left - group->origin_x) * group->scale;
        double first_y = (top - group->origin_y - group->page_y + group->scroll_y) * group->scale;
        VoxChromiumRasterGrid grid{group->tile_width, group->tile_height,
            group->columns, group->rows};
        // GPU coverage depends on the complete Chromium tile, including its
        // border. Cropping the render target to the visible layer changes edge
        // coverage when a tile contains both SVG paths and rounded rectangles.
        // Overflow and fractional scrolling may not align to this grid; retain
        // their existing picture raster rather than shifting the local phase.
        bool tiled = grid.width > 2 && grid.height > 2 && grid.columns > 0 && grid.rows > 0
            && first_x >= 0 && first_y >= 0
            && std::abs(first_x - std::round(first_x)) < .001
            && std::abs(first_y - std::round(first_y)) < .001
            && first_x + width <= int64_t(grid.columns) * (grid.width - 2) + 2
            && first_y + height <= int64_t(grid.rows) * (grid.height - 2) + 2;
        if (draw_retained_layer_tiles(*group, picture.get(), pixels, width, height, left, top)) {
            // Retained transparent ink joins the same backdrop/publication path.
        } else if ((bytes = picture->serialize(&procs)) && bytes->size() <= 64 * 1024 * 1024 && tiled) {
            if (!vox_draw_chromium_raster_grid(pixels, width, height,
                    std::lround(first_x), std::lround(first_y), grid,
                    [&](auto& tile, long offset_x, long offset_y, int) {
                        float tile_matrix[9];
                        std::copy(matrix, matrix + 9, tile_matrix);
                        tile_matrix[2] += offset_x;
                        tile_matrix[5] += offset_y;
                        return shared_picture_draw()(reinterpret_cast<uint8_t*>(tile.data()),
                            grid.width, grid.height, grid.width * 4,
                            bytes->data(), bytes->size(), tile_matrix);
                    })) return;
        } else {
            if (!bytes || bytes->size() > 64 * 1024 * 1024
                || !shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()), width,
                    height, width * 4, bytes->data(), bytes->size(), matrix)) return;
        }
        if (!group->backdrop.empty()) {
            // Each compositor picture blends over the pixels present before
            // its fallback leaves ran. Combining pictures on transparency first
            // loses Chromium's rounding at overlapping shadow edges.
            int x = std::lround(left * group->scale), y = std::lround(top * group->scale);
            if (x < 0 || y < 0 || x + width > group->backdrop_width
                || size_t(y + height) * group->backdrop_width > group->backdrop.size()) return;
            for (int row = 0; row < height; ++row) {
                auto* output = reinterpret_cast<uint8_t*>(pixels.data() + size_t(row) * width);
                auto* backdrop = reinterpret_cast<uint8_t const*>(group->backdrop.data()
                    + size_t(y + row) * group->backdrop_width + x);
                native_composite_opacity_pixels(output, backdrop, output, width, 1);
            }
        }
        publication.published = composite_pixels(group->destination, std::move(pixels), width, height, left,
            group->canvas_height - top - height / group->scale,
            width / group->scale, height / group->scale, true) != 0;
        if (publication.published && group->speculative && group->deferred_leaves
            && std::getenv("VOX_SPECULATIVE_PICTURE_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_SPECULATIVE_PICTURE_PUBLISH leaves=%u width=%d height=%d t_us=%.3f\n",
                group->deferred_leaves, width, height, speculative_picture_time());
        if (publication.published && group->checks_prefix && std::getenv("VOX_SPECULATIVE_PICTURE_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_SPECULATIVE_ROOT_PUBLISH leaves=%u t_us=%.3f\n",
                group->deferred_leaves, speculative_picture_time());
        if (publication.published && group->deferred_leaves && std::getenv("VOX_PICTURE_REGION_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_DEFERRED_LAYER leaves=%u width=%d height=%d\n",
                group->deferred_leaves, width, height);
        return;
    }
    bytes = picture->serialize(&procs);
    if (!bytes || bytes->size() > 64 * 1024 * 1024) return;
    int width = group->tile_width, height = group->tile_height;
    if (width <= 2 || height <= 2 || size_t(width) * height > 8 * 1024 * 1024) return;
    std::set<int> candidates;
    VoxChromiumRasterGrid grid{width, height, group->columns, group->rows};
    for (auto bounds : group->replay_bounds) {
        if (!bounds.isFinite() || !bounds.intersect(SkRect::MakeXYWH(0, group->page_y,
                group->viewport_width, group->viewport_height))) continue;
        bounds.offset(0, group->scroll_y - group->page_y);
        bounds = SkMatrix::Scale(group->scale, group->scale).mapRect(bounds);
        long left = grid.owner(std::floor(bounds.left()), width, grid.columns);
        long right = grid.owner(std::ceil(bounds.right()) - 1, width, grid.columns);
        long top = grid.owner(std::floor(bounds.top()), height, grid.rows);
        long bottom = grid.owner(std::ceil(bounds.bottom()) - 1, height, grid.rows);
        for (long row = top; row <= bottom; ++row)
            for (long column = left; column <= right; ++column)
                candidates.insert(int(row * grid.columns + column));
    }
    for (int cell : candidates) {
        int row = cell / grid.columns, column = cell % grid.columns;
        int origin_x = column * (width - 2), origin_y = row * (height - 2);
        float left = origin_x / group->scale;
        float top = origin_y / group->scale - group->scroll_y + group->page_y;
        auto tile = SkRect::MakeXYWH(left, top, width / group->scale, height / group->scale);
        // A partial viewport tile may omit surrounding commands that Chromium
        // records beyond the visible edge. Keep the leaf result for that tile.
        if (top < group->page_y || tile.bottom() > group->page_y + group->viewport_height)
            continue;
        bool blocked = false;
        for (auto bounds : group->blocked_bounds) {
            if (SkRect::Intersects(bounds, tile)) { blocked = true; break; }
        }
        if (blocked) continue;
        std::vector<uint32_t> pixels(size_t(width) * height);
        float matrix[] {group->scale, 0, -float(origin_x), 0, group->scale,
            float((group->scroll_y - group->page_y) * group->scale - origin_y), 0, 0, 1};
        if (!shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()), width,
                height, width * 4, bytes->data(), bytes->size(), matrix)) continue;
        int owned_left = origin_x + (column > 0 ? 1 : 0);
        int owned_top = origin_y + (row > 0 ? 1 : 0);
        int owned_right = std::min(origin_x + width - (column + 1 < grid.columns ? 1 : 0),
            int(group->viewport_width * group->scale));
        int owned_bottom = origin_y + height - (row + 1 < grid.rows ? 1 : 0);
        if (owned_right <= owned_left || owned_bottom <= owned_top) continue;
        auto clip = CGRectMake(owned_left / group->scale,
            group->canvas_height - (owned_bottom / group->scale - group->scroll_y + group->page_y),
            (owned_right - owned_left) / group->scale, (owned_bottom - owned_top) / group->scale);
        CGContextSaveGState(group->destination);
        CGContextClipToRect(group->destination, clip);
        composite_pixels(group->destination, std::move(pixels), width, height, left,
            group->canvas_height - tile.bottom(), tile.width(), tile.height(), true);
        CGContextRestoreGState(group->destination);
    }
}
}

extern "C" void ladybird_v_skia_set_shared_recording(int enabled, int width, int height)
{
    s_shared_root_recording.reset();
    s_shared_clips.clear();
    s_shared_layer_enabled = false;
    s_speculative_layer_enabled = false;
    s_shared_layer_backdrop = false;
    s_shared_root_enabled = enabled && width > 0 && height > 0;
    s_shared_viewport_width = width;
    s_shared_viewport_height = height;
}

extern "C" void ladybird_v_skia_save_shared_clip(CGContextRef destination)
{
    if (!destination) return;
    auto& state = s_shared_clips[destination];
    state.saves.emplace_back(state.clips.size(), state.unsupported);
}

extern "C" void ladybird_v_skia_restore_shared_clip(CGContextRef destination)
{
    auto found = s_shared_clips.find(destination);
    if (found == s_shared_clips.end() || found->second.saves.empty()) return;
    auto& state = found->second;
    auto saved = state.saves.back();
    state.saves.pop_back();
    state.clips.resize(saved.first);
    state.unsupported = saved.second;
    if (state.saves.empty() && state.clips.empty() && !state.unsupported)
        s_shared_clips.erase(found);
}

extern "C" void ladybird_v_skia_block_shared_recording(CGContextRef destination)
{
    auto input = s_isolated_input_recordings.find(destination);
    if (input != s_isolated_input_recordings.end()) {
        input->second->unsupported = true;
        return;
    }
    if (shared_recording_canvas(destination) && s_shared_root_recording)
        shared_recording_block(SkRect::MakeWH(s_shared_root_recording->canvas_width,
            s_shared_root_recording->canvas_height));
}

extern "C" void ladybird_v_skia_block_shared_clip(CGContextRef destination)
{
    if (!destination) return;
    s_shared_clips[destination].unsupported = true;
    ladybird_v_skia_block_shared_recording(destination);
}

extern "C" void ladybird_v_skia_add_shared_rounded_clip(CGContextRef destination,
    float const* rect, float const* transform)
{
    if (!destination) return;
    if (!rect || !transform
        || !std::all_of(rect, rect + 12, [](float v) { return std::isfinite(v); })
        || !std::all_of(transform, transform + 6, [](float v) { return std::isfinite(v); })) {
        ladybird_v_skia_block_shared_clip(destination);
        return;
    }
    SharedClip clip;
    clip.matrix = SkMatrix::MakeAll(transform[0], transform[2], transform[4],
        transform[1], transform[3], transform[5], 0, 0, 1);
    SkVector radii[] {{rect[4], rect[5]}, {rect[6], rect[7]},
        {rect[8], rect[9]}, {rect[10], rect[11]}};
    clip.rect.setRectRadii(SkRect::MakeXYWH(rect[0], rect[1],
        std::max(rect[2], 0.f), std::max(rect[3], 0.f)), radii);
    s_shared_clips[destination].clips.push_back(clip);
}

extern "C" void ladybird_v_skia_set_layer_shared_recording(int enabled)
{
    s_shared_layer_enabled = enabled != 0;
    s_speculative_layer_enabled = false;
    if (s_raster_layer_is_root && root_speculative_picture_enabled()
        && std::getenv("VOX_SPECULATIVE_PICTURE_DIAGNOSTICS")) {
        auto context = speculative_picture_current_context();
        auto ctm = context ? CGContextGetCTM(context) : CGAffineTransformIdentity;
        std::fprintf(stderr, "VOX_SPECULATIVE_ROOT_GATE enabled=%d root_shared=%d frame=%d direct_image=%d layer_width=%.9g layer_height=%.9g bitmap_width=%zu bitmap_height=%zu has_pixels=%d bits=%zu ctm=%.9g,%.9g,%.9g,%.9g,%.9g,%.9g eligible=%d t_us=%.3f\n",
            enabled, s_shared_root_enabled, s_deferred_layer_frame_enabled, s_direct_image_layer,
            s_raster_layer_width, s_raster_layer_height,
            context ? CGBitmapContextGetWidth(context) : 0, context ? CGBitmapContextGetHeight(context) : 0,
            context && CGBitmapContextGetData(context), context ? CGBitmapContextGetBitsPerPixel(context) : 0,
            ctm.a, ctm.b, ctm.c, ctm.d, ctm.tx, ctm.ty, speculative_picture_context_eligible(context), speculative_picture_time());
    }
    if (!enabled && speculative_picture_enabled() && s_deferred_layer_frame_enabled
        && (!s_raster_layer_is_root || (!s_shared_root_enabled && root_speculative_picture_enabled()))
        && !s_direct_image_layer
        && s_raster_layer_width > 0 && s_raster_layer_height > 0) {
        auto context = speculative_picture_current_context();
        if (speculative_picture_context_eligible(context)) {
            ladybird_v_skia_set_deferred_layer_destination(context, 1);
            if (s_deferred_layer_destinations.count(context)) {
                s_speculative_layer_enabled = true;
                s_shared_layer_enabled = true;
            }
        }
    }
}

extern "C" int ladybird_v_skia_layer_shared_recording_enabled()
{
    return s_shared_layer_enabled && !s_raster_layer_is_root;
}

extern "C" void ladybird_v_skia_set_shared_layer_backdrop(int enabled)
{
    s_shared_layer_backdrop = enabled != 0;
}

extern "C" void ladybird_v_skia_finish_shared_recording()
{
    finish_shared_recording();
}

extern "C" void ladybird_v_skia_record_rect(CGContextRef destination, float x,
    float y, float width, float height, uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha)
{
    auto* canvas = shared_recording_canvas(destination);
    if (!canvas) return;
    auto input = s_isolated_input_recordings.find(destination);
    float canvas_height = input != s_isolated_input_recordings.end()
        ? input->second->canvas_height : s_shared_root_recording->canvas_height;
    auto rect = SkRect::MakeXYWH(x, canvas_height - y - height, width, height);
    if (input != s_isolated_input_recordings.end()) input->second->bounds.join(rect);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    canvas->save();
    shared_recording_clip(destination, canvas);
    if (input == s_isolated_input_recordings.end() && s_shared_root_recording
        && s_shared_root_recording->destination == destination && s_shared_root_recording->speculative
        && complete_speculative_picture_enabled()) {
        float root_y = canvas_height - s_shared_root_recording->viewport_height - float(s_root_raster_scroll_y);
        rect.offset(0, -root_y);
        canvas->setMatrix(SkMatrix::Translate(0, root_y));
    }
    canvas->drawRect(rect, paint);
    canvas->restore();
}

// The platform adapter calls this after recording and before its ordinary
// CGContext fill. Older adapters ignore the new service and retain their
// ordinary pixels; the strict root-prefix guard then vetoes replacement.
extern "C" int ladybird_v_skia_defer_recorded_rect(CGContextRef destination,
    float x, float y, float width, float height)
{
    if (!s_shared_root_recording || s_shared_root_recording->destination != destination
        || !s_shared_root_recording->speculative
        || !complete_speculative_picture_enabled()) return 0;
    auto& group = *s_shared_root_recording;
    auto ink = SkRect::MakeXYWH(x, group.canvas_height - y - height, width, height).makeOutset(2, 2);
    shared_recording_speculative_content(destination, ink, group.canvas_height - group.viewport_height, 0);
    return shared_recording_defers_leaf_raster(destination, ink);
}

extern "C" void ladybird_v_skia_record_caret(CGContextRef destination, float x,
    float y, float width, float height, uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha)
{
    auto fallback = [&] {
        ladybird_v_skia_record_rect(destination, x, y, width, height, red, green, blue, alpha);
    };
    auto* canvas = shared_recording_canvas(destination);
    if (!canvas) return;
    auto* group = s_shared_root_recording.get();
    // Only a complete compositor picture can replace the ordinary leaf draw.
    if (!group || group->root || !(group->scale > 0) || !std::isfinite(x)
        || !std::isfinite(y) || !std::isfinite(width) || !std::isfinite(height)) {
        fallback();
        return;
    }
    float scale = group->scale;
    float top = group->canvas_height - y - height;
    float pixel_width = width * scale, pixel_height = height * scale;
    if (!(pixel_width > 0 && pixel_width <= 64 && pixel_height > 0 && pixel_height <= 4096)
        || std::abs(pixel_width - std::round(pixel_width)) > .001f
        || std::abs(pixel_height - std::round(pixel_height)) > .001f
        || std::abs(x * scale - std::round(x * scale)) > .001f) {
        fallback();
        return;
    }
    auto clips = s_shared_clips.find(destination);
    if (clips != s_shared_clips.end() && clips->second.unsupported) {
        fallback();
        return;
    }
    int raster_width = std::lround(pixel_width), raster_height = std::lround(pixel_height);
    // A solid caret layer is rasterized before its fractional translation.
    // Transparent end rows retain linear sampling at both caps; painting an
    // antialiased vector in the surrounding MSAA picture adds side coverage.
    std::vector<uint32_t> pixels(size_t(raster_width) * (raster_height + 2), 0);
    std::fill(pixels.begin() + raster_width, pixels.end() - raster_width,
        SkPreMultiplyColor(SkColorSetARGB(alpha, red, green, blue)));
    auto info = SkImageInfo::Make(raster_width, raster_height + 2, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto image = SkImages::RasterFromPixmapCopy(SkPixmap(info, pixels.data(), size_t(raster_width) * 4));
    if (!image) { fallback(); return; }
    auto local = SkMatrix::MakeAll(1 / scale, 0, x, 0, 1 / scale, top - 1 / scale, 0, 0, 1);
    SkPaint paint;
    paint.setShader(image->makeShader(SkTileMode::kClamp, SkTileMode::kClamp,
        SkSamplingOptions(SkFilterMode::kLinear), &local));
    canvas->save();
    canvas->resetMatrix();
    if (clips != s_shared_clips.end()) for (auto const& clip : clips->second.clips) {
        if (clip.rect.isRect() && clip.matrix.rectStaysRect()) {
            // The caret texture already supplies edge coverage. Clip to its
            // raster pixels rather than multiplying the fractional cap twice.
            auto bounds = SkMatrix::Scale(scale, scale).mapRect(clip.matrix.mapRect(clip.rect.rect()));
            SkIRect rounded;
            bounds.roundOut(&rounded);
            canvas->resetMatrix();
            canvas->clipRect(SkRect::MakeLTRB(rounded.left() / scale, rounded.top() / scale,
                rounded.right() / scale, rounded.bottom() / scale), SkClipOp::kIntersect, false);
        } else {
            canvas->setMatrix(clip.matrix);
            canvas->clipRRect(clip.rect, true);
        }
    }
    canvas->resetMatrix();
    float first_row = std::floor(top * scale) / scale;
    float last_row = std::ceil((top + height) * scale) / scale;
    canvas->drawRect(SkRect::MakeXYWH(x, first_row, width, last_row - first_row), paint);
    canvas->restore();
}
