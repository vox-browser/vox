#pragma once
#include <map>
#include <string_view>
// GPU-resident canvas (experiment, VOX_EXPERIMENT_GPU_CANVAS=1). During a reused
// scroll frame the repainted device rectangles of the root canvas live on GPU
// surfaces in libVoxGraphite. Eligible leaves draw there with device-space
// matrices and the destination's mirrored rounded clips, instead of rendering
// a private target, reading it back and compositing it on the CPU. Any other
// access to the CPU canvas first reads every rectangle back with one GPU wait
// (flush); the next GPU leaf uploads the CPU pixels again. Chromium draws a
// tile's display items in one GPU pass the same way.
namespace {
struct GpuCanvasFrame {
    CGContextRef destination = nullptr;
    float scale = 1;
    std::vector<SkIRect> rects;
    // GPU surfaces: each repainted rectangle widened to the 8-pixel dither grid.
    std::vector<SkIRect> tiles;
    bool gpu_valid = false;
    bool cpu_stale = false;
    unsigned draws = 0, uploads = 0, flushes = 0, declined = 0;
    // Verification: compared pixels, differing pixels and largest channel error.
    uint64_t compared = 0, differing = 0;
    int max_error = 0;
    // Per-leaf verification (VOX_GPU_CANVAS_VERIFY=2): the leaf whose GPU draw
    // is pending comparison, and that comparison's own counts.
    char leaf[96] = {};
    // The command being replayed was approved for the GPU canvas. Leaves of
    // other commands use the CPU canvas so their own CPU drawing stays ordered.
    bool in_gpu_command = false;
    std::map<std::string, unsigned> flush_reasons;
    uint64_t leaf_differing = 0;
    int leaf_error = 0;
};
std::unique_ptr<GpuCanvasFrame> s_gpu_canvas;

struct GpuCanvasApi {
    decltype(&vox_graphite_canvas_begin) begin = nullptr;
    decltype(&vox_graphite_canvas_upload) upload = nullptr;
    decltype(&vox_graphite_canvas_draw_shadow) draw_shadow = nullptr;
    decltype(&vox_graphite_canvas_draw_shape) draw_shape = nullptr;
    decltype(&vox_graphite_canvas_read) read = nullptr;
    decltype(&vox_graphite_canvas_draw_pixels) draw_pixels = nullptr;
    decltype(&vox_graphite_canvas_draw_path) draw_path = nullptr;
    decltype(&vox_graphite_canvas_draw_image) draw_image = nullptr;
    decltype(&vox_graphite_canvas_end) end = nullptr;
};

GpuCanvasApi const* gpu_canvas_api()
{
    static GpuCanvasApi api = [] {
        GpuCanvasApi value;
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (!library) return value;
        value.begin = reinterpret_cast<decltype(value.begin)>(dlsym(library, "vox_graphite_canvas_begin"));
        value.upload = reinterpret_cast<decltype(value.upload)>(dlsym(library, "vox_graphite_canvas_upload"));
        value.draw_shadow = reinterpret_cast<decltype(value.draw_shadow)>(dlsym(library, "vox_graphite_canvas_draw_shadow"));
        value.draw_shape = reinterpret_cast<decltype(value.draw_shape)>(dlsym(library, "vox_graphite_canvas_draw_shape"));
        value.read = reinterpret_cast<decltype(value.read)>(dlsym(library, "vox_graphite_canvas_read"));
        value.draw_pixels = reinterpret_cast<decltype(value.draw_pixels)>(dlsym(library, "vox_graphite_canvas_draw_pixels"));
        value.draw_path = reinterpret_cast<decltype(value.draw_path)>(dlsym(library, "vox_graphite_canvas_draw_path"));
        value.draw_image = reinterpret_cast<decltype(value.draw_image)>(dlsym(library, "vox_graphite_canvas_draw_image"));
        value.end = reinterpret_cast<decltype(value.end)>(dlsym(library, "vox_graphite_canvas_end"));
        return value;
    }();
    return api.begin && api.upload && api.draw_shadow && api.draw_shape && api.read && api.end
        && api.draw_pixels && api.draw_path && api.draw_image
        ? &api : nullptr;
}

bool gpu_canvas_enabled()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_EXPERIMENT_GPU_CANVAS");
        return value && !std::strcmp(value, "1");
    }();
    return enabled;
}

// Verification draws every canvas leaf on the GPU and through its ordinary
// path; each flush compares the GPU rectangles with the CPU canvas instead of
// replacing it, measuring the pixel difference the GPU canvas would introduce.
bool gpu_canvas_verify()
{
    static bool const enabled = std::getenv("VOX_GPU_CANVAS_VERIFY") != nullptr;
    return enabled;
}

bool gpu_canvas_verify_leaves()
{
    static bool const enabled = [] {
        auto* value = std::getenv("VOX_GPU_CANVAS_VERIFY");
        return value && !std::strcmp(value, "2");
    }();
    return enabled;
}

bool gpu_canvas_text_disabled()
{
    static bool const disabled = std::getenv("VOX_GPU_CANVAS_DISABLE_TEXT") != nullptr;
    return disabled;
}

bool gpu_canvas_diagnostics()
{
    static bool const enabled = std::getenv("VOX_GPU_CANVAS_DIAGNOSTICS") != nullptr;
    return enabled;
}

// Device rows of the CPU bitmap are top-down RGBA; GPU surfaces are BGRA.
void gpu_canvas_flush()
{
    auto* frame = s_gpu_canvas.get();
    if (!frame) return;
    if (frame->cpu_stale) {
        auto* api = gpu_canvas_api();
        auto* data = static_cast<uint8_t*>(CGBitmapContextGetData(frame->destination));
        size_t pitch = CGBitmapContextGetBytesPerRow(frame->destination);
        std::vector<std::vector<uint32_t>> pixels(frame->rects.size());
        std::vector<VoxGraphitePixelRegion> views;
        for (size_t index = 0; index < frame->rects.size(); ++index) {
            auto const& rect = frame->rects[index];
            auto const& tile = frame->tiles[index];
            pixels[index].resize(size_t(rect.width()) * rect.height());
            views.push_back({rect.left() - tile.left(), rect.top() - tile.top(), rect.width(),
                rect.height(), rect.width() * 4, reinterpret_cast<uint8_t*>(pixels[index].data())});
        }
        if (api && data && api->read(views.data(), int(views.size())) && gpu_canvas_verify()) {
            CGContextFlush(frame->destination);
            for (size_t index = 0; index < frame->rects.size(); ++index) {
                auto const& rect = frame->rects[index];
                for (int row = 0; row < rect.height(); ++row) {
                    auto const* cpu = data + size_t(rect.top() + row) * pitch + size_t(rect.left()) * 4;
                    auto const* gpu = reinterpret_cast<uint8_t const*>(pixels[index].data() + size_t(row) * rect.width());
                    for (int column = 0; column < rect.width(); ++column) {
                        int error = 0;
                        int const order[4] {2, 1, 0, 3};
                        for (int channel = 0; channel < 4; ++channel)
                            error = std::max(error, std::abs(int(cpu[column * 4 + channel])
                                - int(gpu[column * 4 + order[channel]])));
                        ++frame->compared;
                        if (error) { ++frame->differing; ++frame->leaf_differing; }
                        frame->max_error = std::max(frame->max_error, error);
                        frame->leaf_error = std::max(frame->leaf_error, error);
                    }
                }
            }
        } else if (api && data && api->read(views.data(), int(views.size()))) {
            CGContextFlush(frame->destination);
            for (size_t index = 0; index < frame->rects.size(); ++index) {
                auto const& rect = frame->rects[index];
                for (int row = 0; row < rect.height(); ++row)
                    swap_red_blue_pixels(data + size_t(rect.top() + row) * pitch + size_t(rect.left()) * 4,
                        reinterpret_cast<uint8_t const*>(pixels[index].data() + size_t(row) * rect.width()),
                        size_t(rect.width()));
            }
        }
        if (gpu_canvas_verify_leaves() && frame->leaf[0] && frame->leaf_differing)
            std::fprintf(stderr, "VOX_GPU_CANVAS_LEAF %s differing=%llu max_error=%d\n", frame->leaf,
                (unsigned long long)frame->leaf_differing, frame->leaf_error);
        frame->leaf[0] = 0;
        frame->leaf_differing = 0;
        frame->leaf_error = 0;
        frame->cpu_stale = false;
        ++frame->flushes;
    }
    // The caller is about to draw on the CPU canvas: the GPU copy goes stale.
    frame->gpu_valid = false;
}

bool gpu_canvas_upload(GpuCanvasFrame& frame)
{
    if (frame.gpu_valid) return true;
    auto* api = gpu_canvas_api();
    auto* data = static_cast<uint8_t const*>(CGBitmapContextGetData(frame.destination));
    if (!api || !data) return false;
    CGContextFlush(frame.destination);
    size_t pitch = CGBitmapContextGetBytesPerRow(frame.destination);
    for (size_t index = 0; index < frame.tiles.size(); ++index) {
        auto const& rect = frame.tiles[index];
        std::vector<uint32_t> pixels(size_t(rect.width()) * rect.height());
        for (int row = 0; row < rect.height(); ++row)
            swap_red_blue_pixels(reinterpret_cast<uint8_t*>(pixels.data() + size_t(row) * rect.width()),
                data + size_t(rect.top() + row) * pitch + size_t(rect.left()) * 4, size_t(rect.width()));
        if (!api->upload(int(index), reinterpret_cast<uint8_t const*>(pixels.data()), rect.width() * 4))
            return false;
    }
    frame.gpu_valid = true;
    ++frame.uploads;
    return true;
}

void gpu_canvas_name_leaf(GpuCanvasFrame& frame, char const* kind, SkRect bounds, int fill, size_t clips)
{
    if (!gpu_canvas_verify_leaves()) return;
    std::snprintf(frame.leaf, sizeof frame.leaf, "%s fill=%d root=%d clips=%zu msaa_grid=%zu bounds=%.0f,%.0f,%.0fx%.0f",
        kind, fill, int(s_raster_layer_is_root), clips, s_msaa_grid_tiles.size(),
        bounds.left(), bounds.top(), bounds.width(), bounds.height());
}

// The canvas for `destination`, ready for a GPU leaf, with its clips in device
// space. Returns null (after flushing) when this leaf must use the CPU canvas.
GpuCanvasFrame* gpu_canvas_for_leaf(CGContextRef destination,
    std::vector<VoxGraphiteCanvasClip>& clips)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame || frame->destination != destination || !frame->in_gpu_command) return nullptr;
    // Compare the previous leaf by itself before this one draws.
    if (gpu_canvas_verify_leaves() && frame->cpu_stale) gpu_canvas_flush();
    auto found = s_shared_clips.find(destination);
    bool clips_supported = true;
    if (found != s_shared_clips.end()) {
        if (found->second.unsupported) clips_supported = false;
        for (auto const& clip : found->second.clips) {
            VoxGraphiteCanvasClip value {};
            auto const& rect = clip.rect.rect();
            float data[12] {rect.x(), rect.y(), rect.width(), rect.height(),
                clip.rect.radii(SkRRect::kUpperLeft_Corner).fX, clip.rect.radii(SkRRect::kUpperLeft_Corner).fY,
                clip.rect.radii(SkRRect::kUpperRight_Corner).fX, clip.rect.radii(SkRRect::kUpperRight_Corner).fY,
                clip.rect.radii(SkRRect::kLowerRight_Corner).fX, clip.rect.radii(SkRRect::kLowerRight_Corner).fY,
                clip.rect.radii(SkRRect::kLowerLeft_Corner).fX, clip.rect.radii(SkRRect::kLowerLeft_Corner).fY};
            std::copy_n(data, 12, value.rect);
            SkMatrix::Concat(SkMatrix::Scale(frame->scale, frame->scale), clip.matrix).get9(value.matrix);
            value.antialias = clip.antialias;
            clips.push_back(value);
        }
    }
    if (!clips_supported || !gpu_canvas_upload(*frame)) {
        ++frame->declined;
        gpu_canvas_flush();
        return nullptr;
    }
    return frame;
}
}

namespace {
void gpu_canvas_decline(CGContextRef destination);
bool gpu_canvas_kind_supported(std::string_view kind, int flags)
{
    // Flags from V: 1 outer_shadow, 2 caret, 4 scrollbar, 8 radius, 16 antialiased,
    // 32 clip_outs, 64 rotated/sheared, 128 underlays_next, 256 no antialias.
    if (kind == "paint_outer_box_shadow" || kind == "fill_rounded_rect"
        || kind == "paint_uniform_border" || kind == "paint_partial_rounded_border"
        || kind == "paint_rounded_border_top" || kind == "paint_rounded_border_right"
        || kind == "paint_rounded_border_bottom" || kind == "paint_rounded_border_left")
        return true;
    if (kind == "fill_rect") return !(flags & (1 | 2 | 4 | 64));
    if (kind == "draw_text") return !gpu_canvas_text_disabled();
    if (kind == "draw_svg_path" || kind == "fill_gradient" || kind == "draw_replaced_image") return true;
    return false;
}

// A solid CoreGraphics fill of an approved command: draw it on the GPU canvas.
int gpu_canvas_defer_rect(CGContextRef destination, float x, float y, float width, float height,
    uint8_t const* rgba)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame || frame->destination != destination) return 0;
    std::vector<VoxGraphiteCanvasClip> clips;
    auto* canvas = gpu_canvas_for_leaf(destination, clips);
    if (!canvas) return 0;
    float canvas_height = CGBitmapContextGetHeight(destination) / canvas->scale;
    float top = canvas_height - y - height;
    // Quartz's antialiasing state for this fill is not observable; only whole
    // device pixels are covered identically with or without it.
    for (float edge : {x, top, x + width, top + height}) {
        float device = edge * canvas->scale;
        if (std::abs(device - std::round(device)) > 0.001f) {
            gpu_canvas_decline(destination);
            return 0;
        }
    }
    VoxGraphiteShape shape {
        .matrix = {}, .rect = {x, top, width, height, 0, 0, 0, 0, 0, 0, 0, 0},
        .thickness = 0, .red = rgba[0], .green = rgba[1], .blue = rgba[2], .alpha = rgba[3],
        .fill = 1, .anti_alias = 1, .force_msaa = 0
    };
    SkMatrix::Scale(canvas->scale, canvas->scale).get9(shape.matrix);
    float bounds[] {x * canvas->scale - 2, top * canvas->scale - 2,
        (x + width) * canvas->scale + 2, (top + height) * canvas->scale + 2};
    if (!gpu_canvas_api()->draw_shape(&shape, bounds, clips.data(), int(clips.size()))) {
        gpu_canvas_flush();
        return 0;
    }
    gpu_canvas_name_leaf(*canvas, "rect", SkRect::MakeLTRB(bounds[0], bounds[1], bounds[2], bounds[3]), 1, clips.size());
    canvas->cpu_stale = true;
    ++canvas->draws;
    return gpu_canvas_verify() ? 0 : 1;
}
}

namespace {
bool gpu_canvas_root_msaa_overlap(CGContextRef destination, RasterRegion const& region,
    float page_x, float page_y, float scroll_y)
{
    if (!s_gpu_canvas || s_gpu_canvas->destination != destination || !s_raster_layer_is_root
        || s_msaa_grid_columns <= 0 || s_msaa_grid_tiles.empty()) return false;
    auto scale = raster_scale_for_context(destination);
    int width = raster_dimension(region.width(), scale), height = raster_dimension(region.height(), scale);
    long first_x = std::lround((region.left - page_x - s_raster_origin_x) * scale);
    long first_y = std::lround((region.top - page_y + scroll_y - s_raster_origin_y + s_root_raster_scroll_y) * scale);
    bool overlap = false;
    vox_chromium_msaa_rects(width, height, first_x, first_y, s_msaa_grid_width, s_msaa_grid_height,
        s_msaa_grid_columns, s_msaa_grid_tiles, [&](int, int, int, int) { overlap = true; });
    return overlap;
}

int gpu_canvas_draw_image(CGContextRef destination, SkMatrix const& matrix,
    VoxGraphiteImage const& descriptor, SkRect device_bounds, RasterRegion const& region,
    float page_x, float page_y, float scroll_y, bool rounded_mask)
{
    if (!s_gpu_canvas || s_gpu_canvas->destination != destination) return 0;
    if (rounded_mask || gpu_canvas_root_msaa_overlap(destination, region, page_x, page_y, scroll_y)) {
        gpu_canvas_decline(destination);
        return 0;
    }
    std::vector<VoxGraphiteCanvasClip> clips;
    auto* frame = gpu_canvas_for_leaf(destination, clips);
    if (!frame) return 0;
    auto scale = SkMatrix::Scale(frame->scale, frame->scale);
    auto gpu = descriptor;
    SkMatrix::Concat(scale, matrix).get9(gpu.matrix);
    auto bounds = scale.mapRect(device_bounds).makeOutset(2, 2);
    float canvas_bounds[] {bounds.left(), bounds.top(), bounds.right(), bounds.bottom()};
    if (!gpu_canvas_api()->draw_image(&gpu, canvas_bounds, clips.data(), int(clips.size()))) {
        gpu_canvas_flush();
        return 0;
    }
    gpu_canvas_name_leaf(*frame, "image", bounds, descriptor.flags, clips.size());
    frame->cpu_stale = true;
    ++frame->draws;
    return gpu_canvas_verify() ? 1 : 2;
}

int gpu_canvas_draw_cpu_raster(CGContextRef destination, int width, int height,
    int region_left, int region_top, char const* name, std::function<bool(uint32_t*)> const& raster)
{
    if (!s_gpu_canvas || s_gpu_canvas->destination != destination) return 0;
    std::vector<VoxGraphiteCanvasClip> clips;
    auto* frame = gpu_canvas_for_leaf(destination, clips);
    if (!frame) return 0;
    std::vector<uint32_t> pixels(size_t(width) * height);
    int device_x = int(std::lround(region_left * frame->scale));
    int device_y = int(std::lround(region_top * frame->scale));
    if (!raster(pixels.data()) || !gpu_canvas_api()->draw_pixels(reinterpret_cast<uint8_t const*>(pixels.data()),
            width, height, width * 4, device_x, device_y, clips.data(), int(clips.size()))) {
        gpu_canvas_flush();
        return 0;
    }
    gpu_canvas_name_leaf(*frame, name, SkRect::MakeXYWH(device_x, device_y, width, height), 0, clips.size());
    frame->cpu_stale = true;
    ++frame->draws;
    return gpu_canvas_verify() ? 1 : 2;
}

// A leaf of an approved command that must draw on the CPU canvas.
void gpu_canvas_decline(CGContextRef destination)
{
    if (!s_gpu_canvas || s_gpu_canvas->destination != destination) return;
    ++s_gpu_canvas->declined;
    gpu_canvas_flush();
}
}

extern "C" int ladybird_v_skia_gpu_canvas_command(char const* kind, int length, int flags)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame) return 0;
    std::string_view name(kind ? kind : "", kind && length > 0 ? size_t(length) : 0);
    frame->in_gpu_command = gpu_canvas_kind_supported(name, flags);
    if (frame->in_gpu_command) return 1;
    if (frame->cpu_stale && gpu_canvas_diagnostics()) ++frame->flush_reasons[std::string(name)];
    gpu_canvas_flush();
    return 0;
}

extern "C" int ladybird_v_skia_gpu_canvas_begin(CGContextRef destination, int const* rects, int count)
{
    s_gpu_canvas.reset();
    auto* api = gpu_canvas_api();
    if (!gpu_canvas_enabled() || !api || !destination || !rects || count <= 0 || count > 8
        || !CGBitmapContextGetData(destination)
        || CGBitmapContextGetBitsPerPixel(destination) != 32
        || CGBitmapContextGetBitmapInfo(destination)
            != (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)) return 0;
    auto frame = std::make_unique<GpuCanvasFrame>();
    frame->destination = destination;
    frame->scale = raster_scale_for_context(destination);
    int width = int(CGBitmapContextGetWidth(destination));
    int height = int(CGBitmapContextGetHeight(destination));
    std::vector<int> device;
    for (int index = 0; index < count; ++index) {
        auto rect = SkIRect::MakeXYWH(rects[index * 4], rects[index * 4 + 1],
            rects[index * 4 + 2], rects[index * 4 + 3]);
        if (!rect.intersect(SkIRect::MakeWH(width, height))) continue;
        // Skia's ordered gradient dither repeats every eight device pixels from
        // the surface origin; leaf rasters align their surfaces the same way.
        auto tile = SkIRect::MakeLTRB(rect.left() - rect.left() % 8, rect.top() - rect.top() % 8,
            rect.right(), rect.bottom());
        frame->rects.push_back(rect);
        frame->tiles.push_back(tile);
        device.insert(device.end(), {tile.x(), tile.y(), tile.width(), tile.height(),
            rect.x(), rect.y(), rect.width(), rect.height()});
    }
    if (frame->rects.empty() || !api->begin(device.data(), int(frame->rects.size()))) return 0;
    s_gpu_canvas = std::move(frame);
    return 1;
}

extern "C" void ladybird_v_skia_gpu_canvas_cpu_access()
{
    if (s_gpu_canvas) {
        if (s_gpu_canvas->cpu_stale && gpu_canvas_diagnostics()) ++s_gpu_canvas->flush_reasons["(layer)"];
        s_gpu_canvas->in_gpu_command = false;
    }
    gpu_canvas_flush();
}

extern "C" void ladybird_v_skia_gpu_canvas_end()
{
    if (!s_gpu_canvas) return;
    gpu_canvas_flush();
    if (gpu_canvas_diagnostics())
        std::fprintf(stderr, "VOX_GPU_CANVAS rects=%zu draws=%u uploads=%u flushes=%u declined=%u compared=%llu differing=%llu max_error=%d\n",
            s_gpu_canvas->rects.size(), s_gpu_canvas->draws, s_gpu_canvas->uploads,
            s_gpu_canvas->flushes, s_gpu_canvas->declined,
            (unsigned long long)s_gpu_canvas->compared, (unsigned long long)s_gpu_canvas->differing,
            s_gpu_canvas->max_error);
    if (gpu_canvas_diagnostics() && !s_gpu_canvas->flush_reasons.empty()) {
        std::string reasons;
        for (auto const& [name, count] : s_gpu_canvas->flush_reasons)
            reasons += " " + name + "=" + std::to_string(count);
        std::fprintf(stderr, "VOX_GPU_CANVAS_REASONS%s\n", reasons.c_str());
    }
    if (auto* api = gpu_canvas_api()) api->end();
    s_gpu_canvas.reset();
}
