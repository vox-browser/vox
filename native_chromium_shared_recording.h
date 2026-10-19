#pragma once

// Included after the native raster-layer state. The existing leaf renderer
// supplies the fallback frame; only complete, supported SVG tiles replace it.
namespace {
struct SharedRootRecording {
    std::unique_ptr<SkPictureRecorder> recorder;
    CGContextRef destination;
    float canvas_width, canvas_height, scale, page_y = 0;
    int viewport_width, viewport_height;
    int tile_width = 0, tile_height = 0, columns = 0, rows = 0;
    double scroll_y = 0;
    std::vector<SkRect> svg_bounds;
    std::vector<SkRect> blocked_bounds;
};
std::unique_ptr<SharedRootRecording> s_shared_root_recording;
bool s_shared_root_enabled = false;
int s_shared_viewport_width = 0, s_shared_viewport_height = 0;

auto shared_picture_draw()
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
    if (!s_shared_root_enabled || !s_chromium_painting || !s_raster_layer_is_root
        || !destination || !shared_picture_draw()) return nullptr;
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
        group->viewport_width = s_shared_viewport_width;
        group->viewport_height = s_shared_viewport_height;
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

void shared_recording_svg(CGContextRef destination, SkRect bounds, float page_y)
{
    if (!shared_recording_canvas(destination) || s_msaa_grid_columns <= 0) return;
    auto& group = *s_shared_root_recording;
    group.svg_bounds.push_back(bounds);
    group.page_y = page_y;
    group.scroll_y = s_root_raster_scroll_y;
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
    if ((image.flags & 4) || image.has_color_profile || size_t(image.width) * image.height > 8 * 1024 * 1024
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
    if (!group || group->svg_bounds.empty() || !group->columns) return;
    if (int64_t(group->columns) * group->rows > INT32_MAX) return;
    auto picture = group->recorder->finishRecordingAsPicture();
    SkSerialProcs procs;
    procs.fImageProc = serialize_shared_picture_image;
    auto bytes = picture->serialize(&procs);
    if (!bytes || bytes->size() > 64 * 1024 * 1024) return;
    int width = group->tile_width, height = group->tile_height;
    if (width <= 2 || height <= 2 || size_t(width) * height > 8 * 1024 * 1024) return;
    std::set<int> candidates;
    VoxChromiumRasterGrid grid{width, height, group->columns, group->rows};
    for (auto bounds : group->svg_bounds) {
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
    s_shared_root_enabled = enabled && width > 0 && height > 0;
    s_shared_viewport_width = width;
    s_shared_viewport_height = height;
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
    canvas->resetMatrix();
    canvas->drawRect(SkRect::MakeXYWH(x,
        s_shared_root_recording->canvas_height - y - height, width, height), paint);
    canvas->restore();
}
