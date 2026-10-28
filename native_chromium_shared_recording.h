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
    float origin_x = 0, origin_y = 0, layer_width = 0, layer_height = 0;
    std::vector<SkRect> replay_bounds;
    std::vector<SkRect> blocked_bounds;
    std::vector<uint32_t> backdrop;
    int backdrop_width = 0;
};
std::unique_ptr<SharedRootRecording> s_shared_root_recording;
bool s_shared_root_enabled = false;
bool s_shared_layer_enabled = false;
bool s_shared_layer_backdrop = false;
int s_shared_viewport_width = 0, s_shared_viewport_height = 0;

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
    if (!(s_raster_layer_is_root ? s_shared_root_enabled : s_shared_layer_enabled)
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
        group->root = s_raster_layer_is_root;
        group->origin_x = s_raster_origin_x;
        group->origin_y = s_raster_origin_y;
        group->layer_width = s_raster_layer_width;
        group->layer_height = s_raster_layer_height;
        group->viewport_width = s_shared_viewport_width;
        group->viewport_height = s_shared_viewport_height;
        if (!group->root && s_shared_layer_backdrop) {
            int pixel_width = CGBitmapContextGetWidth(destination);
            int pixel_height = CGBitmapContextGetHeight(destination);
            if (size_t(pixel_width) * pixel_height > 8 * 1024 * 1024) return nullptr;
            group->backdrop.resize(size_t(pixel_width) * pixel_height);
            if (!copy_backdrop(destination, {}, scale, pixel_width, pixel_height, group->backdrop))
                return nullptr;
            group->backdrop_width = pixel_width;
        }
        group->recorder = std::make_unique<SkPictureRecorder>();
        group->recorder->beginRecording(SkRect::MakeWH(width, height));
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

void shared_recording_clip(CGContextRef destination, SkCanvas* canvas)
{
    canvas->resetMatrix();
    auto found = s_shared_clips.find(destination);
    if (found == s_shared_clips.end()) return;
    if (found->second.unsupported) {
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
    if (!shared_recording_canvas(destination) || s_msaa_grid_columns <= 0) return;
    auto& group = *s_shared_root_recording;
    group.replay_bounds.push_back(bounds);
    group.page_y = page_y;
    group.scroll_y = group.root ? s_root_raster_scroll_y : scroll_y;
    group.tile_width = s_msaa_grid_width;
    group.tile_height = s_msaa_grid_height;
    group.columns = s_msaa_grid_columns;
    int height = std::max(1, int(std::ceil(s_raster_layer_height * group.scale)));
    group.rows = std::max(1, (height - 2 + group.tile_height - 3) / (group.tile_height - 2));
}

sk_sp<SkData> serialize_shared_picture_image(SkImage* image, void*)
{
    int dimensions[] {image->width(), image->height()};
    size_t pitch = size_t(dimensions[0]) * 4;
    auto bytes = SkData::MakeUninitialized(sizeof(dimensions) + pitch * dimensions[1]);
    auto* data = static_cast<uint8_t*>(bytes->writable_data());
    std::memcpy(data, dimensions, sizeof(dimensions));
    auto info = SkImageInfo::Make(dimensions[0], dimensions[1], kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    if (!image->readPixels(nullptr, info, data + sizeof(dimensions), pitch, 0, 0)) return nullptr;
    return bytes;
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
    if ((image.flags & (4 | 64 | 128)) || image.has_color_profile || image.has_background_color
        || image.border_width > 0
        || size_t(image.width) * image.height > 8 * 1024 * 1024
        || std::any_of(image.clip + 4, image.clip + 12, [](float radius) { return radius != 0; })) {
        shared_recording_block(matrix.mapRect(target));
        return;
    }
    auto info = SkImageInfo::Make(image.width, image.height, kRGBA_8888_SkColorType,
        (image.flags & 1) ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    SkPixmap source(info, image.pixels, image.pitch);
    std::vector<uint8_t> premultiplied;
    if (!(image.flags & 1)) {
        premultiplied.resize(size_t(image.width) * image.height * 4);
        info = info.makeAlphaType(kPremul_SkAlphaType);
        if (!source.readPixels(info, premultiplied.data(), size_t(image.width) * 4)) {
            shared_recording_block(matrix.mapRect(target));
            return;
        }
        source = SkPixmap(info, premultiplied.data(), size_t(image.width) * 4);
    }
    int upload_width = image.width, upload_height = image.height;
    float scale = s_shared_root_recording->scale;
    float target_width = std::ceil(target.width() * std::hypot(matrix.getScaleX(), matrix.getSkewY()) * scale);
    float target_height = std::ceil(target.height() * std::hypot(matrix.getSkewX(), matrix.getScaleY()) * scale);
    bool complete_source = image.source[0] == 0 && image.source[1] == 0
        && image.source[2] == image.width && image.source[3] == image.height;
    if (!image.nearest && complete_source) {
        for (int level = 1; level < 31; ++level) {
            int divisor = 1 << level;
            int width = (image.width + divisor - 1) / divisor;
            int height = (image.height + divisor - 1) / divisor;
            if (width < target_width || height < target_height) break;
            upload_width = width;
            upload_height = height;
            if (width == 1 && height == 1) break;
        }
    }
    std::vector<uint8_t> scaled;
    if (upload_width != image.width || upload_height != image.height) {
        scaled.resize(size_t(upload_width) * upload_height * 4);
        SkPixmap resized(info.makeWH(upload_width, upload_height), scaled.data(), size_t(upload_width) * 4);
        if (!source.scalePixels(resized, SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest))) {
            shared_recording_block(matrix.mapRect(target));
            return;
        }
        source = resized;
    }
    auto bitmap = SkImages::RasterFromPixmapCopy(source);
    if (!bitmap) { shared_recording_block(matrix.mapRect(target)); return; }
    float sx = float(upload_width) / image.width, sy = float(upload_height) / image.height;
    auto source_rect = SkRect::MakeXYWH(image.source[0] * sx, image.source[1] * sy,
        image.source[2] * sx, image.source[3] * sy);
    auto clip = SkRect::MakeXYWH(image.clip[0], image.clip[1], image.clip[2], image.clip[3]);
    bool mips = !image.nearest && complete_source
        && target_width < upload_width && target_height < upload_height;
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(image.opacity);
    canvas->save();
    shared_recording_clip(destination, canvas);
    canvas->setMatrix(matrix);
    if (clip != target) canvas->clipRect(clip, true);
    canvas->drawImageRect(bitmap, source_rect, target,
        SkSamplingOptions(image.nearest ? SkFilterMode::kNearest : SkFilterMode::kLinear,
            mips ? SkMipmapMode::kLinear : SkMipmapMode::kNone),
        &paint, SkCanvas::kStrict_SrcRectConstraint);
    canvas->restore();
}

void finish_shared_recording()
{
    auto group = std::move(s_shared_root_recording);
    if (!group || group->replay_bounds.empty() || !group->columns) return;
    if (int64_t(group->columns) * group->rows > INT32_MAX) return;
    auto picture = group->recorder->finishRecordingAsPicture();
    SkSerialProcs procs;
    procs.fImageProc = serialize_shared_picture_image;
    auto bytes = picture->serialize(&procs);
    if (!bytes || bytes->size() > 64 * 1024 * 1024) return;
    if (!group->root) {
        // A layer is atomic: an unsupported image, allocation failure or backend
        // failure leaves all of its ordinary leaf draws intact.
        if (!group->blocked_bounds.empty() || !(group->layer_width > 0)
            || !(group->layer_height > 0) || !std::isfinite(group->layer_width)
            || !std::isfinite(group->layer_height)
            || group->layer_width * group->scale > 16384
            || group->layer_height * group->scale > 16384) return;
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
        if (!shared_picture_draw()(reinterpret_cast<uint8_t*>(pixels.data()), width,
                height, width * 4, bytes->data(), bytes->size(), matrix)) return;
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
        composite_pixels(group->destination, std::move(pixels), width, height, left,
            group->canvas_height - top - height / group->scale,
            width / group->scale, height / group->scale, true);
        return;
    }
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
    if (shared_recording_canvas(destination))
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
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    canvas->save();
    shared_recording_clip(destination, canvas);
    canvas->drawRect(SkRect::MakeXYWH(x,
        s_shared_root_recording->canvas_height - y - height, width, height), paint);
    canvas->restore();
}
