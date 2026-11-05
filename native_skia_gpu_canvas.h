#pragma once
#include <map>
#include <string_view>
// GPU-resident canvas (on by default; the advanced setting "GPU-accelerated
// scrolling" or VOX_DISABLE_GPU_CANVAS=1 turns it off). During a reused
// scroll frame the repainted device rectangles of the root canvas live on GPU
// surfaces in libVoxGraphite. Eligible leaves draw there with device-space
// matrices and the destination's mirrored rounded clips, instead of rendering
// a private target, reading it back and compositing it on the CPU. Any other
// access to the CPU canvas first reads every rectangle back with one GPU wait
// (flush); the next GPU leaf uploads the CPU pixels again. Chromium draws a
// tile's display items in one GPU pass the same way.
namespace { struct GpuCanvasFrame; }
static void gpu_canvas_native_grid(GpuCanvasFrame&);
namespace {
struct GpuCanvasFrame {
    CGContextRef destination = nullptr;
    float scale = 1;
    std::vector<SkIRect> rects;
    // GPU surfaces: each repainted rectangle widened to the 8-pixel dither grid.
    std::vector<SkIRect> tiles;
    std::vector<SkIRect> dirty;
    // Tile and clip rectangles for vox_graphite_canvas_begin. The GPU surfaces
    // are acquired only when the frame's first GPU leaf needs them.
    std::vector<int> device;
    bool begun = false;
    bool gpu_valid = false;
    bool cpu_stale = false;
    unsigned draws = 0, uploads = 0, flushes = 0, declined = 0, cpu_leaves = 0;
    // Verification: compared pixels, differing pixels and largest channel error.
    uint64_t compared = 0, differing = 0;
    int max_error = 0;
    // Per-leaf verification (VOX_GPU_CANVAS_VERIFY=2): the leaf whose GPU draw
    // is pending comparison, and that comparison's own counts.
    char leaf_worst[96] {};
    char leaf[96] = {};
    // The command being replayed was approved for the GPU canvas. Leaves of
    // other commands use the CPU canvas so their own CPU drawing stays ordered.
    bool in_gpu_command = false;
    bool complete_viewport = false;
    bool native_grid = false;
    int document_top = -1;
    bool video_backdrop_callbacks = false;
    void* frame_surface = nullptr; // Borrowed only for this native paint callback.
    void* frame_surface_pixels = nullptr;
    std::map<std::string, unsigned> flush_reasons;
    // Diagnostics: why GPU-capable leaves still used their own raster path.
    std::map<std::string, unsigned> leaf_misses;
    // Diagnostics: GPU leaves drawn on the canvas by kind, and their device area.
    std::map<std::string, unsigned> leaf_kinds;
    double leaf_area = 0;
    uint64_t leaf_differing = 0;
    int leaf_error = 0;
    std::chrono::steady_clock::time_point command_started;
    char timed_command[96] {};
};
std::unique_ptr<GpuCanvasFrame> s_gpu_canvas;
// A transfer failure loses GPU-only leaves. Reject this replay and use the
// ordinary renderer for subsequent attempts, rather than publishing old rows.
bool s_gpu_canvas_read_failed = false;

struct GpuCanvasApi {
    decltype(&vox_graphite_canvas_begin) begin = nullptr;
    decltype(&vox_graphite_canvas_begin_native_grid) begin_native_grid = nullptr;
    decltype(&vox_graphite_canvas_upload) upload = nullptr;
    decltype(&vox_graphite_canvas_draw_shadow) draw_shadow = nullptr;
    decltype(&vox_graphite_canvas_draw_shape) draw_shape = nullptr;
    decltype(&vox_graphite_canvas_read) read = nullptr;
    decltype(&vox_graphite_canvas_read_direct) read_direct = nullptr;
    decltype(&vox_graphite_canvas_read_iosurface) read_iosurface = nullptr;
    decltype(&vox_graphite_canvas_draw_pixels) draw_pixels = nullptr;
    decltype(&vox_graphite_canvas_draw_layer_pixels) draw_layer_pixels = nullptr;
    decltype(&vox_graphite_canvas_copy_pixels) copy_pixels = nullptr;
    decltype(&vox_graphite_canvas_draw_path) draw_path = nullptr;
    decltype(&vox_graphite_canvas_draw_image) draw_image = nullptr;
    decltype(&vox_graphite_canvas_draw_image_msaa) draw_image_msaa = nullptr;
    decltype(&vox_graphite_canvas_draw_shape_msaa) draw_shape_msaa = nullptr;
    decltype(&vox_graphite_canvas_draw_shape_native_grid) draw_shape_native_grid = nullptr;
    decltype(&vox_graphite_canvas_draw_shape_isolated) draw_shape_isolated = nullptr;
    decltype(&vox_graphite_canvas_draw_picture) draw_picture = nullptr;
    decltype(&vox_graphite_canvas_end) end = nullptr;
};

GpuCanvasApi const* gpu_canvas_api()
{
    static GpuCanvasApi api = [] {
        GpuCanvasApi value;
        void* library = dlopen("@rpath/libVoxGraphite.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (!library) return value;
        value.begin = reinterpret_cast<decltype(value.begin)>(dlsym(library, "vox_graphite_canvas_begin"));
        value.begin_native_grid = reinterpret_cast<decltype(value.begin_native_grid)>(dlsym(library, "vox_graphite_canvas_begin_native_grid"));
        value.upload = reinterpret_cast<decltype(value.upload)>(dlsym(library, "vox_graphite_canvas_upload"));
        value.draw_shadow = reinterpret_cast<decltype(value.draw_shadow)>(dlsym(library, "vox_graphite_canvas_draw_shadow"));
        value.draw_shape = reinterpret_cast<decltype(value.draw_shape)>(dlsym(library, "vox_graphite_canvas_draw_shape"));
        value.read = reinterpret_cast<decltype(value.read)>(dlsym(library, "vox_graphite_canvas_read"));
        value.read_direct = reinterpret_cast<decltype(value.read_direct)>(dlsym(library, "vox_graphite_canvas_read_direct"));
        value.read_iosurface = reinterpret_cast<decltype(value.read_iosurface)>(dlsym(library, "vox_graphite_canvas_read_iosurface"));
        value.draw_pixels = reinterpret_cast<decltype(value.draw_pixels)>(dlsym(library, "vox_graphite_canvas_draw_pixels"));
        value.draw_layer_pixels = reinterpret_cast<decltype(value.draw_layer_pixels)>(dlsym(library, "vox_graphite_canvas_draw_layer_pixels"));
        value.copy_pixels = reinterpret_cast<decltype(value.copy_pixels)>(dlsym(library, "vox_graphite_canvas_copy_pixels"));
        value.draw_path = reinterpret_cast<decltype(value.draw_path)>(dlsym(library, "vox_graphite_canvas_draw_path"));
        value.draw_image = reinterpret_cast<decltype(value.draw_image)>(dlsym(library, "vox_graphite_canvas_draw_image"));
        value.draw_image_msaa = reinterpret_cast<decltype(value.draw_image_msaa)>(dlsym(library, "vox_graphite_canvas_draw_image_msaa"));
        value.draw_shape_msaa = reinterpret_cast<decltype(value.draw_shape_msaa)>(dlsym(library, "vox_graphite_canvas_draw_shape_msaa"));
        value.draw_shape_native_grid = reinterpret_cast<decltype(value.draw_shape_native_grid)>(dlsym(library, "vox_graphite_canvas_draw_shape_native_grid"));
        value.draw_shape_isolated = reinterpret_cast<decltype(value.draw_shape_isolated)>(dlsym(library, "vox_graphite_canvas_draw_shape_isolated"));
        value.draw_picture = reinterpret_cast<decltype(value.draw_picture)>(dlsym(library, "vox_graphite_canvas_draw_picture"));
        value.end = reinterpret_cast<decltype(value.end)>(dlsym(library, "vox_graphite_canvas_end"));
        return value;
    }();
    return api.begin && api.upload && api.draw_shadow && api.draw_shape && api.read && api.end
        && api.draw_pixels && api.draw_path && api.draw_image && api.draw_shape_msaa
        ? &api : nullptr;
}

// The browser consults the user's setting before beginning a frame; the
// environment switch keeps a same-binary control arm for measurements.
bool gpu_canvas_enabled()
{
    static bool const enabled = !std::getenv("VOX_DISABLE_GPU_CANVAS");
    return enabled && !s_gpu_canvas_read_failed;
}

bool gpu_canvas_isolated_shapes_enabled()
{
    return !std::getenv("VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES")
        && gpu_canvas_api() && gpu_canvas_api()->draw_shape_isolated;
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

bool gpu_canvas_partial_readback()
{
    return std::getenv("VOX_GPU_CANVAS_PARTIAL_READBACK")!=nullptr;
}

// Separate diagnostic runs only: time the interval between native command
// boundaries, including any CPU fallback and GPU wait in that interval.
void gpu_canvas_time_command(char const* name, int length)
{
    static bool const enabled=std::getenv("VOX_GPU_CANVAS_COMMAND_TIMES")!=nullptr;
    if (!enabled || !s_gpu_canvas) return;
    auto& frame=*s_gpu_canvas;
    auto now=std::chrono::steady_clock::now();
    if(frame.timed_command[0]) {
        auto us=std::chrono::duration_cast<std::chrono::microseconds>(now-frame.command_started).count();
        if(us>=2000) std::fprintf(stderr,"Vox GPU command time: kind=%s us=%lld scroll_y=%.2f\n",
            frame.timed_command,(long long)us,s_root_raster_scroll_y);
    }
    std::snprintf(frame.timed_command,sizeof(frame.timed_command),"%.*s",length,name ? name : "");
    frame.command_started=now;
}

// Device rows of the CPU bitmap are top-down RGBA; GPU surfaces are BGRA.
void gpu_canvas_flush()
{
    auto* frame = s_gpu_canvas.get();
    if (!frame) return;
    if (frame->cpu_stale) {
        auto read_rects=frame->rects;
        size_t full_area=0,read_area=0;
        for(size_t index=0;index<read_rects.size();++index) {
            full_area+=size_t(read_rects[index].width())*read_rects[index].height();
            if(gpu_canvas_partial_readback() && !gpu_canvas_verify()) read_rects[index]=frame->dirty[index];
            read_area+=size_t(read_rects[index].width())*read_rects[index].height();
        }
        bool verify_partial=std::getenv("VOX_GPU_CANVAS_PARTIAL_READBACK_VERIFY")!=nullptr;
        // Diagnostic checks need the full GPU output to prove no changed pixel
        // lies outside the proposed dirty bounds.
        if(verify_partial) read_rects=frame->rects;
        auto* api = gpu_canvas_api();
        auto* data = static_cast<uint8_t*>(CGBitmapContextGetData(frame->destination));
        size_t pitch = CGBitmapContextGetBytesPerRow(frame->destination);
        if (api && api->read_iosurface && frame->frame_surface && data
            && data == frame->frame_surface_pixels && !gpu_canvas_verify()
            && !gpu_canvas_partial_readback()
            && std::getenv("VOX_GPU_CANVAS_IOSURFACE_READBACK")) {
            CGContextFlush(frame->destination);
            int result = api->read_iosurface(frame->frame_surface,
                int(CGBitmapContextGetWidth(frame->destination)), int(CGBitmapContextGetHeight(frame->destination)));
            if (result) {
                // Diagnostic transport check: compare the new frame storage
                // with the established reader on the same GPU pixels. Ordinary
                // CPU/GPU leaf verification remains a separate diagnostic.
                if (result > 0 && std::getenv("VOX_GPU_CANVAS_IOSURFACE_READBACK_VERIFY")) {
                    std::vector<std::vector<uint32_t>> pixels(frame->rects.size());
                    std::vector<VoxGraphitePixelRegion> views;
                    for (size_t index=0; index<frame->rects.size(); ++index) {
                        auto const& rect=frame->rects[index]; auto const& tile=frame->tiles[index];
                        pixels[index].resize(size_t(rect.width())*rect.height());
                        views.push_back({rect.left()-tile.left(),rect.top()-tile.top(),rect.width(),rect.height(),
                            rect.width()*4,reinterpret_cast<uint8_t*>(pixels[index].data())});
                    }
                    bool read=api->read(views.data(),int(views.size()));
                    int error=0; size_t compared=0;
                    if (read) for (size_t index=0; index<frame->rects.size(); ++index) {
                        auto const& rect=frame->rects[index];
                        for(int y=0;y<rect.height();++y) for(int x=0;x<rect.width();++x) {
                            auto* actual=data+size_t(rect.top()+y)*pitch+size_t(rect.left()+x)*4;
                            auto* expected=reinterpret_cast<uint8_t*>(pixels[index].data())+(size_t(y)*rect.width()+x)*4;
                            int const order[]={2,1,0,3};
                            for(int channel=0;channel<4;++channel)
                                error=std::max(error,std::abs(int(actual[channel])-int(expected[order[channel]])));
                            ++compared;
                        }
                    }
                    std::fprintf(stderr,"Vox GPU IOSurface verify: read=%d pixels=%zu max_error=%d\n",int(read),compared,error);
                    if (!read || error) result=-1;
                }
                if (result < 0) {
                    s_gpu_canvas_read_failed = true;
                    s_deferred_layer_frame_failed = true;
                }
                if (gpu_canvas_diagnostics())
                    std::fprintf(stderr,"Vox GPU IOSurface readback: result=%d rects=%zu\n",result,frame->rects.size());
                frame->cpu_stale = false;
                frame->gpu_valid = false;
                ++frame->flushes;
                return;
            }
        }
        if (api && api->read_direct && data && !gpu_canvas_verify()
            && std::getenv("VOX_GPU_CANVAS_DIRECT_READBACK") && pitch <= INT_MAX
            && !gpu_canvas_partial_readback() && !verify_partial) {
            std::vector<VoxGraphitePixelRegion> direct;
            for (size_t index = 0; index < frame->rects.size(); ++index) {
                auto const& rect = frame->rects[index];
                auto const& tile = frame->tiles[index];
                direct.push_back({rect.left() - tile.left(), rect.top() - tile.top(), rect.width(),
                    rect.height(), int(pitch), data + size_t(rect.top()) * pitch + size_t(rect.left()) * 4});
            }
            CGContextFlush(frame->destination);
            if (api->read_direct(direct.data(), int(direct.size()))) {
                if (gpu_canvas_diagnostics())
                    std::fprintf(stderr, "VOX_GPU_CANVAS_DIRECT_READBACK rects=%zu\n", direct.size());
                for (auto const& view : direct)
                    for (int row = 0; row < view.height; ++row) {
                        auto* pixels = view.pixels + size_t(row) * view.pitch;
                        swap_red_blue_pixels(pixels, pixels, size_t(view.width));
                    }
                frame->cpu_stale = false;
                frame->gpu_valid = false;
                ++frame->flushes;
                return;
            }
        }
        std::vector<std::vector<uint32_t>> pixels(read_rects.size());
        std::vector<VoxGraphitePixelRegion> views;
        for (size_t index = 0; index < read_rects.size(); ++index) {
            auto const& rect = read_rects[index];
            auto const& tile = frame->tiles[index];
            int width=rect.isEmpty()?1:rect.width(),height=rect.isEmpty()?1:rect.height();
            pixels[index].resize(size_t(width)*height);
            views.push_back({rect.isEmpty()?0:rect.left()-tile.left(),rect.isEmpty()?0:rect.top()-tile.top(),
                width,height,width*4,reinterpret_cast<uint8_t*>(pixels[index].data())});
        }
        bool read = api && data && api->read(views.data(), int(views.size()));
        // Retry a failed transfer, but never repeat a successful synchronous
        // read just because this frame is not running pixel verification.
        if (!read && api && data) read = api->read(views.data(), int(views.size()));
        if (!read) {
            s_gpu_canvas_read_failed = true;
            s_deferred_layer_frame_failed = true;
        }
        if(read && verify_partial) {
            int error=0;size_t outside=0;
            for(size_t index=0;index<read_rects.size();++index) {
                auto const& rect=read_rects[index];auto const& dirty=frame->dirty[index];
                for(int y=rect.top();y<rect.bottom();++y) for(int x=rect.left();x<rect.right();++x) {
                    if(dirty.contains(x,y)) continue;
                    auto* cpu=data+size_t(y)*pitch+size_t(x)*4;
                    auto* gpu=reinterpret_cast<uint8_t*>(pixels[index].data())
                        +(size_t(y-rect.top())*rect.width()+x-rect.left())*4;
                    int const order[]={2,1,0,3};
                    for(int channel=0;channel<4;++channel) error=std::max(error,std::abs(int(cpu[channel])-int(gpu[order[channel]])));
                    ++outside;
                }
            }
            std::fprintf(stderr,"Vox GPU partial readback verify: outside=%zu max_error=%d read_pixels=%zu full_pixels=%zu\n",
                outside,error,read_area,full_area);
        }
        if (read && gpu_canvas_verify()) {
            CGContextFlush(frame->destination);
            for (size_t index = 0; index < read_rects.size(); ++index) {
                auto const& rect = read_rects[index];
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
                        if (error > 20 && gpu_canvas_verify_leaves() && error > frame->leaf_error)
                            std::snprintf(frame->leaf_worst, sizeof frame->leaf_worst,
                                " worst=%d,%d cpu=%d,%d,%d,%d gpu=%d,%d,%d,%d", rect.left() + column,
                                rect.top() + row, cpu[column * 4], cpu[column * 4 + 1], cpu[column * 4 + 2],
                                cpu[column * 4 + 3], gpu[column * 4 + 2], gpu[column * 4 + 1],
                                gpu[column * 4], gpu[column * 4 + 3]);
                        if (error) { ++frame->differing; ++frame->leaf_differing; }
                        frame->max_error = std::max(frame->max_error, error);
                        frame->leaf_error = std::max(frame->leaf_error, error);
                    }
                }
            }
        } else if (read) {
            CGContextFlush(frame->destination);
            for (size_t index = 0; index < read_rects.size(); ++index) {
                auto const& rect = read_rects[index];
                for (int row = 0; row < rect.height(); ++row)
                    swap_red_blue_pixels(data + size_t(rect.top() + row) * pitch + size_t(rect.left()) * 4,
                        reinterpret_cast<uint8_t const*>(pixels[index].data() + size_t(row) * rect.width()),
                        size_t(rect.width()));
            }
        }
        if (gpu_canvas_verify_leaves() && frame->leaf[0] && frame->leaf_differing)
            std::fprintf(stderr, "VOX_GPU_CANVAS_LEAF %s differing=%llu max_error=%d%s\n", frame->leaf,
                (unsigned long long)frame->leaf_differing, frame->leaf_error, frame->leaf_worst);
        frame->leaf_worst[0] = 0;
        frame->leaf[0] = 0;
        frame->leaf_differing = 0;
        frame->leaf_error = 0;
        frame->cpu_stale = false;
        for(auto& dirty:frame->dirty) dirty.setEmpty();
        if(gpu_canvas_partial_readback() && gpu_canvas_diagnostics())
            std::fprintf(stderr,"Vox GPU partial readback: pixels=%zu full_pixels=%zu\n",read_area,full_area);
        ++frame->flushes;
    }
    // The caller is about to draw on the CPU canvas: the GPU copy goes stale.
    frame->gpu_valid = false;
}

bool gpu_canvas_upload(GpuCanvasFrame& frame)
{
    if (s_gpu_canvas_read_failed) return false;
    if (frame.gpu_valid) return true;
    auto* api = gpu_canvas_api();
    auto* data = static_cast<uint8_t const*>(CGBitmapContextGetData(frame.destination));
    if (!api || !data) return false;
    if (!frame.begun) {
        gpu_canvas_native_grid(frame);
        auto begin = frame.native_grid ? api->begin_native_grid : api->begin;
        if (!begin(frame.device.data(), int(frame.tiles.size()))) return false;
        frame.begun = true;
    }
    CGContextFlush(frame.destination);
    size_t pitch = CGBitmapContextGetBytesPerRow(frame.destination);
    for (size_t index = 0; index < frame.tiles.size(); ++index) {
        auto const& rect = frame.tiles[index];
        std::vector<uint32_t> pixels(size_t(rect.width()) * rect.height());
        auto visible = rect;
        if (visible.intersect(SkIRect::MakeWH(int(CGBitmapContextGetWidth(frame.destination)),
                int(CGBitmapContextGetHeight(frame.destination))))) {
            for (int row = visible.top(); row < visible.bottom(); ++row)
                swap_red_blue_pixels(reinterpret_cast<uint8_t*>(pixels.data()
                        + size_t(row - rect.top()) * rect.width() + visible.left() - rect.left()),
                    data + size_t(row) * pitch + size_t(visible.left()) * 4, size_t(visible.width()));
        }
        if (!api->upload(int(index), reinterpret_cast<uint8_t const*>(pixels.data()), rect.width() * 4))
            return false;
    }
    frame.gpu_valid = true;
    ++frame.uploads;
    return true;
}

void gpu_canvas_name_leaf(GpuCanvasFrame& frame, char const* kind, SkRect bounds, int fill, size_t clips)
{
    // These conservative device bounds are also supplied to the GPU draw.
    // Unknown extents retain the complete damage rectangle.
    for(size_t index=0;index<frame.rects.size();++index) {
        auto dirty=frame.rects[index];
        if(bounds.isFinite()) { bounds.roundOut(&dirty); if(!dirty.intersect(frame.rects[index])) continue; }
        frame.dirty[index].join(dirty);
    }
    if (gpu_canvas_diagnostics()) {
        ++frame.leaf_kinds[kind];
        frame.leaf_area += double(bounds.width()) * bounds.height();
    }
    if (!gpu_canvas_verify_leaves()) return;
    std::snprintf(frame.leaf, sizeof frame.leaf, "%s fill=%d root=%d clips=%zu msaa_grid=%zu bounds=%.0f,%.0f,%.0fx%.0f",
        kind, fill, int(s_raster_layer_is_root), clips, s_msaa_grid_tiles.size(),
        bounds.left(), bounds.top(), bounds.width(), bounds.height());
}

void gpu_canvas_note_miss(CGContextRef destination, char const* leaf, bool msaa)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame || !gpu_canvas_diagnostics()) return;
    char const* reason = frame->destination != destination ? "offscreen"
        : msaa ? "msaa" : !frame->in_gpu_command ? "unapproved" : "other";
    ++frame->leaf_misses[std::string(leaf) + ":" + reason];
}

// Whether leaves on `destination` are being recorded into a shared compositor
// picture (or would start one). That picture reaches the CPU canvas later, in
// one publication; a GPU leaf drawn meanwhile would land beneath recorded leaves
// that precede it, and the next readback would erase the publication.
bool gpu_canvas_shared_recording(CGContextRef destination)
{
    if (s_shared_root_recording && s_shared_root_recording->destination == destination) return true;
    if (s_isolated_input_recordings.count(destination)) return true;
    return s_chromium_painting && (s_speculative_layer_enabled
        || (s_raster_layer_is_root ? s_shared_root_enabled : s_shared_layer_enabled));
}

// The canvas for `destination`, ready for a GPU leaf, with its clips in device
// space. Returns null (after flushing) when this leaf must use the CPU canvas.
GpuCanvasFrame* gpu_canvas_for_leaf(CGContextRef destination,
    std::vector<VoxGraphiteCanvasClip>& clips)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame || s_gpu_canvas_read_failed || frame->destination != destination || !frame->in_gpu_command) return nullptr;
    if (gpu_canvas_shared_recording(destination)) {
        if (gpu_canvas_diagnostics()) ++frame->flush_reasons["(shared-recording)"];
        frame->in_gpu_command = false;
        gpu_canvas_flush();
        ++frame->declined;
        return nullptr;
    }
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
    // A complete viewport exposes MSAA corner coverage that a narrow scroll
    // strip need not touch. Keep shapes on their established per-tile path
    // until the full-surface resolve matches that coverage as well.
    if (s_gpu_canvas && s_gpu_canvas->complete_viewport
        && !gpu_canvas_isolated_shapes_enabled()
        && (kind == "fill_rounded_rect" || kind == "stroke_rounded_rect"
            || kind == "fill_ellipse" || kind == "stroke_ellipse"
            || kind == "paint_uniform_border" || kind == "paint_partial_rounded_border"
            || kind == "paint_rounded_border_top" || kind == "paint_rounded_border_right"
            || kind == "paint_rounded_border_bottom" || kind == "paint_rounded_border_left"))
        return false;
    // Flags from V: 1 outer_shadow, 2 caret, 4 scrollbar, 8 radius, 16 antialiased,
    // 32 clip_outs, 64 rotated/sheared, 128 underlays_next, 256 no antialias,
    // 512 polygon points.
    if (kind == "paint_outer_box_shadow" || kind == "fill_rounded_rect"
        || kind == "paint_uniform_border" || kind == "paint_partial_rounded_border"
        || kind == "paint_rounded_border_top" || kind == "paint_rounded_border_right"
        || kind == "paint_rounded_border_bottom" || kind == "paint_rounded_border_left")
        return true;
    if (kind == "fill_rect") return !(flags & (1 | 2 | 4 | 64));
    // Outlines and ellipses are rounded rectangles of the same native shape.
    static bool const outlines = !std::getenv("VOX_GPU_CANVAS_DISABLE_OUTLINES");
    if (kind == "stroke_rounded_rect") return outlines && !(flags & 512);
    if (kind == "fill_ellipse" || kind == "stroke_ellipse") return outlines;
    if (kind == "draw_text") return !gpu_canvas_text_disabled();
    if (kind == "draw_video") return s_gpu_canvas && s_gpu_canvas->video_backdrop_callbacks
        && std::getenv("VOX_GPU_CANVAS_VIDEO_BACKDROP") && gpu_canvas_api()->copy_pixels;
    if (kind == "draw_svg_path" || kind == "fill_gradient" || kind == "draw_replaced_image") return true;
    if (kind == "begin_css_filter_layer" || kind == "end_css_filter_layer")
        return std::getenv("VOX_GPU_CANVAS_FILTER_LAYERS") || std::getenv("VOX_GPU_CANVAS_OFFSCREEN_LAYERS");
    if (kind == "begin_css_effect_layer" || kind == "end_css_effect_layer")
        return std::getenv("VOX_GPU_CANVAS_OFFSCREEN_LAYERS") && gpu_canvas_api()->draw_layer_pixels;
    static bool const insets = !std::getenv("VOX_GPU_CANVAS_DISABLE_INSET");
    if (kind == "paint_inner_box_shadow") return insets && gpu_canvas_api()->draw_picture;
    return false;
}

bool gpu_canvas_cpu_leaf_stays_on_cpu(CGContextRef destination);

// A solid CoreGraphics fill of an approved command: draw it on the GPU canvas.
int gpu_canvas_defer_rect(CGContextRef destination, float x, float y, float width, float height,
    uint8_t const* rgba)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame || frame->destination != destination) return 0;
    if (gpu_canvas_cpu_leaf_stays_on_cpu(destination)) return 0;
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

std::vector<int> gpu_canvas_image_msaa_rects(CGContextRef destination, RasterRegion const& region,
    float page_x, float page_y, float scroll_y)
{
    auto scale = raster_scale_for_context(destination);
    int width = raster_dimension(region.width(), scale), height = raster_dimension(region.height(), scale);
    long first_x = std::lround((region.left - page_x - s_raster_origin_x) * scale);
    long first_y = std::lround((region.top - page_y + scroll_y - s_raster_origin_y + s_root_raster_scroll_y) * scale);
    int left = int(std::lround(region.left * scale)), top = int(std::lround(region.top * scale));
    std::vector<int> rects;
    vox_chromium_msaa_rects(width, height, first_x, first_y, s_msaa_grid_width, s_msaa_grid_height,
        s_msaa_grid_columns, s_msaa_grid_tiles, [&](int x, int y, int w, int h) {
            rects.insert(rects.end(), {left + x, top + y, w, h});
        });
    return rects;
}

int gpu_canvas_draw_image(CGContextRef destination, SkMatrix const& matrix,
    VoxGraphiteImage const& descriptor, SkRect device_bounds, RasterRegion const& region,
    float page_x, float page_y, float scroll_y, bool rounded_mask)
{
    if (!s_gpu_canvas || s_gpu_canvas->destination != destination) return 0;
    bool msaa = gpu_canvas_root_msaa_overlap(destination, region, page_x, page_y, scroll_y);
    char const* leaf = descriptor.flags & VOX_GRAPHITE_IMAGE_VIDEO_FRAME ? "video" : "image";
    static bool const disable_video = std::getenv("VOX_GPU_CANVAS_DISABLE_VIDEO") != nullptr;
    bool video = (descriptor.flags & VOX_GRAPHITE_IMAGE_VIDEO_FRAME) && !disable_video
        && gpu_canvas_api()->draw_image_msaa;
    if (rounded_mask || (msaa && !video)) {
        gpu_canvas_note_miss(destination, leaf, msaa);
        gpu_canvas_decline(destination);
        return 0;
    }
    // draw_video stays an unapproved command so its CPU backdrop is restored
    // after a flush. Only the actual frame image rejoins the GPU pass here.
    if (video) s_gpu_canvas->in_gpu_command = true;
    std::vector<VoxGraphiteCanvasClip> clips;
    auto* frame = gpu_canvas_for_leaf(destination, clips);
    if (!frame) {
        gpu_canvas_note_miss(destination, leaf, false);
        return 0;
    }
    auto scale = SkMatrix::Scale(frame->scale, frame->scale);
    auto gpu = descriptor;
    SkMatrix::Concat(scale, matrix).get9(gpu.matrix);
    auto bounds = scale.mapRect(device_bounds).makeOutset(2, 2);
    float canvas_bounds[] {bounds.left(), bounds.top(), bounds.right(), bounds.bottom()};
    auto msaa_rects = msaa ? gpu_canvas_image_msaa_rects(destination, region, page_x, page_y, scroll_y)
        : std::vector<int>{};
    int drawn = msaa ? gpu_canvas_api()->draw_image_msaa(&gpu, canvas_bounds, clips.data(),
        int(clips.size()), msaa_rects.data(), int(msaa_rects.size() / 4))
        : gpu_canvas_api()->draw_image(&gpu, canvas_bounds, clips.data(), int(clips.size()));
    if (!drawn) {
        gpu_canvas_flush();
        return 0;
    }
    gpu_canvas_name_leaf(*frame, video ? (msaa ? "video-msaa" : "video") : "image",
        bounds, descriptor.flags, clips.size());
    frame->cpu_stale = true;
    ++frame->draws;
    return gpu_canvas_verify() ? 1 : 2;
}

int gpu_canvas_draw_cpu_raster(CGContextRef destination, int width, int height,
    int region_left, int region_top, char const* name, std::function<bool(uint32_t*)> const& raster)
{
    if (!s_gpu_canvas || s_gpu_canvas->destination != destination) return 0;
    if (gpu_canvas_cpu_leaf_stays_on_cpu(destination)) return 0;
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

// Text and solid rectangles need no GPU round trip on the CPU canvas. While no
// GPU work is pending, draw them there and leave the GPU canvas idle: a frame
// of only such leaves (most of a text page) then costs nothing extra. Once a
// GPU leaf has drawn, they join the canvas so paint order holds without a read.
bool gpu_canvas_cpu_leaf_stays_on_cpu(CGContextRef destination)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame || frame->destination != destination || !frame->in_gpu_command || frame->cpu_stale)
        return false;
    // The CPU canvas changes underneath any uploaded copy.
    frame->gpu_valid = false;
    ++frame->cpu_leaves;
    return true;
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
    gpu_canvas_time_command(kind,kind && length>0 ? length : 0);
    auto* frame = s_gpu_canvas.get();
    if (!frame) return 0;
    std::string_view name(kind ? kind : "", kind && length > 0 ? size_t(length) : 0);
    frame->in_gpu_command = !s_gpu_canvas_read_failed && gpu_canvas_kind_supported(name, flags);
    if (frame->in_gpu_command) return 1;
    if (frame->cpu_stale && gpu_canvas_diagnostics()) ++frame->flush_reasons[std::string(name)];
    gpu_canvas_flush();
    return 0;
}

// The host supplies the document's device origin at begin. Layer selection
// installs the root grid later, so configure its surfaces at the first leaf.
static void gpu_canvas_native_grid(GpuCanvasFrame& frame)
{
    auto* api = gpu_canvas_api();
    if (frame.native_grid || frame.begun || frame.document_top < 0 || !s_raster_layer_is_root
        || !std::getenv("VOX_GPU_CANVAS_NATIVE_GRID") || !api || !api->draw_shape_native_grid
        || !api->begin_native_grid || s_msaa_grid_columns <= 0
        || s_msaa_grid_width < 16 || s_msaa_grid_width > 1024
        || s_msaa_grid_height < 16 || s_msaa_grid_height > 1024
        || frame.scale < 1 || frame.scale != std::floor(frame.scale) || s_shared_viewport_height <= 0) return;
    double scroll = s_root_raster_scroll_y * frame.scale;
    double content = std::ceil(std::max(double(s_shared_viewport_height), s_raster_layer_height) * frame.scale);
    if (!std::isfinite(scroll) || std::abs(scroll) > INT_MAX || scroll != std::round(scroll)
        || !std::isfinite(content) || content > INT_MAX) return;
    int rows = int(std::max(1L, (long(content) - 2 + s_msaa_grid_height - 3) / (s_msaa_grid_height - 2)));
    VoxChromiumRasterGrid grid {s_msaa_grid_width, s_msaa_grid_height, s_msaa_grid_columns, rows};
    long shift = frame.document_top - long(std::lround(scroll));
    long extent_x = long(grid.columns) * (grid.width - 2) + 2;
    long extent_y = long(grid.rows) * (grid.height - 2) + 2;
    std::vector<SkIRect> patches, tiles;
    std::vector<int> device;
    size_t pixels = 0;
    for (auto patch : frame.rects) {
        long first_y = patch.top() - shift, last_y = patch.bottom() - 1 - shift;
        if (patch.left() < 0 || patch.right() > extent_x || first_y < 0 || last_y >= extent_y) return;
        long first_row = grid.owner(first_y, grid.height, grid.rows);
        long last_row = grid.owner(last_y, grid.height, grid.rows);
        long first_column = grid.owner(patch.left(), grid.width, grid.columns);
        long last_column = grid.owner(patch.right() - 1, grid.width, grid.columns);
        for (long row = first_row; row <= last_row; ++row) {
            for (long column = first_column; column <= last_column; ++column) {
                int x = int(column * (grid.width - 2)), y = int(row * (grid.height - 2) + shift);
                auto tile = SkIRect::MakeXYWH(x, y, grid.width, grid.height);
                auto owned = SkIRect::MakeLTRB(x + (column > 0), y + (row > 0),
                    x + grid.width - (column + 1 < grid.columns), y + grid.height - (row + 1 < grid.rows));
                auto clipped = patch;
                if (!clipped.intersect(owned)) continue;
                pixels += size_t(tile.width()) * tile.height();
                if (tiles.size() >= 64 || pixels > 64 * 1024 * 1024 / 4) return;
                tiles.push_back(tile);
                patches.push_back(clipped);
                device.insert(device.end(), {tile.x(), tile.y(), tile.width(), tile.height(),
                    clipped.x(), clipped.y(), clipped.width(), clipped.height()});
            }
        }
    }
    frame.rects = std::move(patches);
    frame.tiles = std::move(tiles);
    frame.device = std::move(device);
    frame.dirty.assign(frame.rects.size(), SkIRect::MakeEmpty());
    frame.native_grid = true;
    if (gpu_canvas_diagnostics())
        std::fprintf(stderr, "Vox GPU native grid: tiles=%zu shift_y=%ld size=%dx%d\n",
            frame.tiles.size(), shift, s_msaa_grid_width, s_msaa_grid_height);
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
        frame->dirty.push_back(SkIRect::MakeEmpty());
        frame->tiles.push_back(tile);
        device.insert(device.end(), {tile.x(), tile.y(), tile.width(), tile.height(),
            rect.x(), rect.y(), rect.width(), rect.height()});
    }
    if (frame->rects.empty()) return 0;
    frame->complete_viewport = frame->rects.size() == 1
        && s_shared_viewport_width > 0 && s_shared_viewport_height > 0
        && frame->rects[0].width() == std::lround(s_shared_viewport_width * frame->scale)
        && frame->rects[0].height() == std::lround(s_shared_viewport_height * frame->scale);
    frame->device = std::move(device);
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

extern "C" int ladybird_v_skia_gpu_canvas_defer_filters()
{
    return s_gpu_canvas && !s_gpu_canvas_read_failed
        && (std::getenv("VOX_GPU_CANVAS_FILTER_LAYERS") || std::getenv("VOX_GPU_CANVAS_OFFSCREEN_LAYERS"));
}

extern "C" void ladybird_v_skia_gpu_canvas_context_access(CGContextRef destination)
{
    if (s_gpu_canvas && s_gpu_canvas->destination == destination) ladybird_v_skia_gpu_canvas_cpu_access();
}

extern "C" int ladybird_v_skia_gpu_canvas_defer_layers()
{
    return s_gpu_canvas && !s_gpu_canvas_read_failed && std::getenv("VOX_GPU_CANVAS_OFFSCREEN_LAYERS")
        && gpu_canvas_api()->draw_layer_pixels;
}

extern "C" int ladybird_v_skia_gpu_canvas_layer_pixels(CGContextRef destination,
    uint8_t const* rgba, int width, int height, int pitch, int x, int y, float opacity, int blend_mode)
{
    if (!ladybird_v_skia_gpu_canvas_defer_layers() || s_gpu_canvas->destination != destination
        || !s_gpu_canvas->in_gpu_command || !rgba || width <= 0 || height <= 0
        || width > 16384 || height > 16384 || pitch < width * 4
        || size_t(width) * height > 16 * 1024 * 1024 / 4
        || !std::isfinite(opacity) || opacity < 0 || opacity > 1 || (blend_mode != 0 && blend_mode != 3)) return 0;
    std::vector<VoxGraphiteCanvasClip> clips;
    auto* frame = gpu_canvas_for_leaf(destination, clips);
    if (!frame) return 0;
    std::vector<uint32_t> pixels(size_t(width) * height);
    for (int row = 0; row < height; ++row)
        swap_red_blue_pixels(reinterpret_cast<uint8_t*>(pixels.data() + size_t(row) * width),
            rgba + size_t(row) * pitch, width);
    if (!gpu_canvas_api()->draw_layer_pixels(reinterpret_cast<uint8_t const*>(pixels.data()), width, height,
            width * 4, x, y, clips.data(), int(clips.size()), opacity, blend_mode)) {
        gpu_canvas_flush();
        return 0;
    }
    gpu_canvas_name_leaf(*frame, blend_mode == 3 ? "screen-layer" : "opacity-layer",
        SkRect::MakeXYWH(x, y, width, height), blend_mode, clips.size());
    frame->cpu_stale = true;
    ++frame->draws;
    return gpu_canvas_verify() ? 2 : 1;
}

// Core Image's pointwise result maps one-to-one to device pixels. Keep its
// transparent CPU raster independent of the pending root GPU destination.
extern "C" int ladybird_v_skia_gpu_canvas_filter_image(CGContextRef destination, CGImageRef image,
    float x, float y, float width, float height, float canvas_height)
{
    if (!ladybird_v_skia_gpu_canvas_defer_filters() || !image || s_gpu_canvas->destination != destination
        || !s_gpu_canvas->in_gpu_command || CGImageGetBitsPerComponent(image) != 8
        || CGImageGetBitsPerPixel(image) != 32 || CGImageGetDecode(image)) return 0;
    auto info = CGImageGetBitmapInfo(image);
    bool rgba = info == (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    bool bgra = info == (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    auto ctm = CGContextGetCTM(destination);
    auto scale = s_gpu_canvas->scale;
    if ((!rgba && !bgra) || ctm.a != scale || ctm.d != scale || ctm.b || ctm.c || ctm.tx || ctm.ty) return 0;
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    bool srgb = color && CGImageGetColorSpace(image) && CFEqual(color, CGImageGetColorSpace(image));
    if (color) CGColorSpaceRelease(color);
    if (!srgb) return 0;
    double left = double(x) * scale, top = double(canvas_height - y - height) * scale;
    auto w = CGImageGetWidth(image), h = CGImageGetHeight(image), pitch = CGImageGetBytesPerRow(image);
    if (!std::isfinite(left) || !std::isfinite(top) || left != std::round(left) || top != std::round(top)
        || std::abs(left) > INT_MAX / 2 || std::abs(top) > INT_MAX / 2
        || width * scale != w || height * scale != h || !w || !h || w > 16384 || h > 16384
        || pitch < w * 4 || pitch > 16 * 1024 * 1024 / h) return 0;
    auto data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    if (!data || size_t(CFDataGetLength(data)) != pitch * h) {
        if (data) CFRelease(data);
        return 0;
    }
    std::vector<VoxGraphiteCanvasClip> clips;
    auto* frame = gpu_canvas_for_leaf(destination, clips);
    if (!frame) { CFRelease(data); return 0; }
    std::vector<uint32_t> pixels(w * h);
    for (size_t row = 0; row < h; ++row) {
        auto* output = reinterpret_cast<uint8_t*>(pixels.data() + row * w);
        auto* input = CFDataGetBytePtr(data) + row * pitch;
        if (rgba) swap_red_blue_pixels(output, input, w);
        else std::memcpy(output, input, w * 4);
    }
    CFRelease(data);
    if (!gpu_canvas_api()->draw_pixels(reinterpret_cast<uint8_t const*>(pixels.data()), int(w), int(h), int(w * 4),
            int(left), int(top), clips.data(), int(clips.size()))) {
        gpu_canvas_flush();
        return 0;
    }
    gpu_canvas_name_leaf(*frame, "css-color-filter", SkRect::MakeXYWH(left, top, w, h), 0, clips.size());
    frame->cpu_stale = true;
    ++frame->draws;
    return gpu_canvas_verify() ? 2 : 1;
}

extern "C" void ladybird_v_skia_gpu_canvas_video_backdrop_callbacks(int enabled)
{
    if (s_gpu_canvas) s_gpu_canvas->video_backdrop_callbacks = enabled != 0;
}

extern "C" void ladybird_v_skia_gpu_canvas_document_top(int top)
{
    if (s_gpu_canvas && !s_gpu_canvas->begun && top >= 0
        && size_t(top) < CGBitmapContextGetHeight(s_gpu_canvas->destination)) s_gpu_canvas->document_top = top;
}

extern "C" void ladybird_v_skia_gpu_canvas_frame_surface(void* surface)
{
    if (s_gpu_canvas) {
        s_gpu_canvas->frame_surface = surface;
        s_gpu_canvas->frame_surface_pixels = CGBitmapContextGetData(s_gpu_canvas->destination);
    }
}

extern "C" int ladybird_v_skia_gpu_canvas_restore_video_backdrop(CGContextRef destination,
    uint8_t const* rgba, int width, int height, int pitch, int x, int y)
{
    auto* frame = s_gpu_canvas.get();
    if (!frame || frame->destination != destination || !frame->video_backdrop_callbacks
        || !std::getenv("VOX_GPU_CANVAS_VIDEO_BACKDROP") || !gpu_canvas_api()->copy_pixels
        || (!frame->cpu_stale && !gpu_canvas_verify()) || gpu_canvas_shared_recording(destination)
        || !rgba || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || pitch < width * 4 || size_t(width) * height > 32 * 1024 * 1024 / 4
        || x < 0 || y < 0 || size_t(x) + width > CGBitmapContextGetWidth(destination)
        || size_t(y) + height > CGBitmapContextGetHeight(destination)) return 0;
    if (gpu_canvas_verify_leaves() && frame->cpu_stale) gpu_canvas_flush();
    if (!gpu_canvas_upload(*frame)) return 0;
    std::vector<uint32_t> pixels(size_t(width) * height);
    for (int row = 0; row < height; ++row)
        swap_red_blue_pixels(reinterpret_cast<uint8_t*>(pixels.data() + size_t(row) * width),
            rgba + size_t(row) * pitch, size_t(width));
    if (!gpu_canvas_api()->copy_pixels(reinterpret_cast<uint8_t const*>(pixels.data()),
            width, height, width * 4, x, y)) return 0;
    gpu_canvas_name_leaf(*frame, "video-backdrop", SkRect::MakeXYWH(x, y, width, height), 0, 0);
    frame->cpu_stale = true;
    frame->in_gpu_command = true;
    ++frame->draws;
    if (std::getenv("VOX_GPU_CANVAS_VIDEO_BACKDROP_DIAGNOSTICS"))
        std::fprintf(stderr, "Vox GPU video backdrop: restored=%dx%d verify=%d\n", width, height, int(gpu_canvas_verify()));
    // Verification also executes the ordinary CPU replacement before the
    // next leaf compares the two surfaces.
    return gpu_canvas_verify() ? 2 : 1;
}

extern "C" void ladybird_v_skia_gpu_canvas_end()
{
    if (!s_gpu_canvas) return;
    gpu_canvas_flush();
    gpu_canvas_time_command(nullptr,0);
    if (gpu_canvas_diagnostics())
        std::fprintf(stderr, "VOX_GPU_CANVAS rects=%zu draws=%u uploads=%u flushes=%u declined=%u cpu_leaves=%u compared=%llu differing=%llu max_error=%d\n",
            s_gpu_canvas->rects.size(), s_gpu_canvas->draws, s_gpu_canvas->uploads,
            s_gpu_canvas->flushes, s_gpu_canvas->declined, s_gpu_canvas->cpu_leaves,
            (unsigned long long)s_gpu_canvas->compared, (unsigned long long)s_gpu_canvas->differing,
            s_gpu_canvas->max_error);
    if (gpu_canvas_diagnostics() && !s_gpu_canvas->leaf_misses.empty()) {
        std::string misses;
        for (auto const& [name, count] : s_gpu_canvas->leaf_misses)
            misses += " " + name + "=" + std::to_string(count);
        std::fprintf(stderr, "VOX_GPU_CANVAS_MISSES%s\n", misses.c_str());
    }
    if (gpu_canvas_diagnostics() && !s_gpu_canvas->leaf_kinds.empty()) {
        std::string kinds;
        for (auto const& [name, count] : s_gpu_canvas->leaf_kinds)
            kinds += " " + name + "=" + std::to_string(count);
        std::fprintf(stderr, "VOX_GPU_CANVAS_LEAVES%s area=%.0f\n", kinds.c_str(), s_gpu_canvas->leaf_area);
    }
    if (gpu_canvas_diagnostics() && !s_gpu_canvas->flush_reasons.empty()) {
        std::string reasons;
        for (auto const& [name, count] : s_gpu_canvas->flush_reasons)
            reasons += " " + name + "=" + std::to_string(count);
        std::fprintf(stderr, "VOX_GPU_CANVAS_REASONS%s\n", reasons.c_str());
    }
    if (auto* api = gpu_canvas_api()) api->end();
    s_gpu_canvas.reset();
}
