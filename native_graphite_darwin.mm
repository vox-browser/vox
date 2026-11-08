// The pinned Graphite archive uses release layouts, including private records.
#ifndef SK_RELEASE
#define SK_RELEASE
#endif
#import <Metal/Metal.h>
#include "native_frame_metal_queue.h"
#include "native_graphite_bridge.h"
#include "native_graphite_context_lifetime.h"
#include "native_chromium_image_decode_cache.h"
#include "native_graphite_raster_cache.h"
#include "native_graphite_image_upload_cache.h"
#include "native_graphite_solid_rect.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkBlurTypes.h"
#include "include/core/SkColorSpace.h"
#include "modules/skcms/skcms.h"
#include "native_skia_image_color_space.h"
#include "native_webp_color_profile.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMaskFilter.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPicture.h"
#include "include/core/SkSerialProcs.h"
#include "include/core/SkStream.h"
#include "include/core/SkTypeface.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkShader.h"
#include "include/core/SkColorFilter.h"
#include "include/effects/SkGradient.h"
#include "include/effects/SkDashPathEffect.h"
#include "include/core/SkRRect.h"
#include "native_rounded_single_border.h"
#include "include/core/SkSurface.h"
#include "include/core/SkYUVAPixmaps.h"
#include "include/gpu/graphite/Context.h"
#include "include/gpu/graphite/ContextOptions.h"
#include "include/gpu/graphite/Image.h"
#include "include/gpu/graphite/Recorder.h"
#include "include/gpu/graphite/Recording.h"
#include "include/gpu/graphite/Surface.h"
#include "include/gpu/graphite/mtl/MtlBackendContext.h"
#include "native_svg_path_segments.h"
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>
#include <memory>
#include <list>
#include <mutex>
#include <pthread.h>
#include <vector>
#include <chrono>
#include <unistd.h>

#include "native_graphite_shared_metal.h"
#include "native_graphite_shared_yuva_metal.h"

namespace {
std::mutex gpu_mutex;
// Shared sprite sources leave room for many small, distinct draw results.
VoxGraphiteRasterCache image_cache(32 * 1024 * 1024, 2048);
VoxGraphiteImageUploadCache<sk_sp<SkImage>> image_upload_cache;
// Immutable premultiplied filter outputs have a separate key domain and a
// bounded texture-only budget. They never alias decoded straight-RGBA images.
VoxGraphiteImageUploadCache<sk_sp<SkImage>> cached_pixel_uploads(32 * 1024 * 1024, 32);
VoxGraphiteRasterCache path_cache(8 * 1024 * 1024, 512, true);
VoxGraphiteRasterCache shape_cache(16 * 1024 * 1024, 512, true);
VoxGraphiteRasterCache shadow_cache(8 * 1024 * 1024, 128, true);
// Reuse only the target allocation; every draw still clears, paints and reads
// the same full GPU coordinates. Keep the recorder alive with its surfaces.
struct RegionTarget {
    int width, height;
    sk_sp<SkSurface> surface;
};
std::unique_ptr<skgpu::graphite::Recorder> region_recorder;
// Preserve the bounded GPU resource cache across large-shape cache misses.
// Access and context teardown are serialized by gpu_mutex.
std::unique_ptr<skgpu::graphite::Recorder> rounded_recorder;
std::unique_ptr<skgpu::graphite::Recorder> full_draw_recorder;

// Synchronous full-surface draws can share a bounded recorder resource cache.
// A fresh surface still owns every draw's matrix, clip and pixels. The mutex
// enclosing each public draw also serializes this lease and context teardown.
class FullDrawRecorder {
    std::unique_ptr<skgpu::graphite::Recorder> temporary_;
    skgpu::graphite::Recorder* recorder_ = nullptr;
    bool borrowed_ = false;
public:
    explicit FullDrawRecorder(skgpu::graphite::Context* gpu) {
        static bool enabled = !std::getenv("VOX_DISABLE_FULL_RECORDER_REUSE");
        if (enabled) {
            bool reused = bool(full_draw_recorder);
            if (!full_draw_recorder) {
                skgpu::graphite::RecorderOptions options;
                options.fGpuBudgetInBytes = 16 * 1024 * 1024;
                full_draw_recorder = gpu->makeRecorder(options);
            }
            recorder_ = full_draw_recorder.get();
            borrowed_ = recorder_ != nullptr;
            if (recorder_ && std::getenv("VOX_RECORDER_DIAGNOSTICS"))
                std::fprintf(stderr, "VOX_FULL_RECORDER reused=%d\n", reused);
        } else {
            temporary_ = gpu->makeRecorder();
            recorder_ = temporary_.get();
        }
    }
    ~FullDrawRecorder() {
        // Early failures can leave unsubmitted operations. Discard them before
        // the next draw borrows the recorder; successful readback already snaps.
        if (borrowed_) recorder_->snap();
    }
    skgpu::graphite::Recorder* get() const { return recorder_; }
};
std::list<RegionTarget> region_targets;
size_t region_target_bytes = 0;
constexpr size_t region_target_limit = 64 * 1024 * 1024;

void canvas_reset();
bool canvas_finish_submission(bool synchronous);
void clear_region_targets()
{
    canvas_reset();
    region_targets.clear();
    region_target_bytes = 0;
    region_recorder.reset();
    rounded_recorder.reset();
    full_draw_recorder.reset();
}

SkSurface* region_target(skgpu::graphite::Context* gpu, SkImageInfo const& info)
{
    size_t cost = size_t(info.width()) * size_t(info.height()) * 4;
    if (cost > region_target_limit) return nullptr;
    for (auto i = region_targets.begin(); i != region_targets.end(); ++i) {
        if (i->width == info.width() && i->height == info.height()) {
            region_targets.splice(region_targets.begin(), region_targets, i);
            return region_targets.front().surface.get();
        }
    }
    if (!region_recorder) {
        skgpu::graphite::RecorderOptions options;
        options.fGpuBudgetInBytes = 16 * 1024 * 1024;
        region_recorder = gpu->makeRecorder(options);
    }
    if (!region_recorder) return nullptr;
    while (!region_targets.empty() && (region_targets.size() >= 32
        || region_target_bytes + cost > region_target_limit)) {
        auto const& old = region_targets.back();
        region_target_bytes -= size_t(old.width) * size_t(old.height) * 4;
        region_targets.pop_back();
    }
    auto surface = vox_shared_surface(region_recorder.get(), info);
    if (!surface) return nullptr;
    region_targets.push_front({info.width(), info.height(), std::move(surface)});
    region_target_bytes += cost;
    return region_targets.front().surface.get();
}

std::unique_ptr<skgpu::graphite::Context> gpu_context;
VoxFrameMetalQueue* gpu_frame_queue;
bool gpu_context_attempted = false;
bool gpu_context_idle = false;
std::chrono::steady_clock::time_point gpu_context_last_use;
skgpu::graphite::Context* context()
{
    gpu_context_idle = false;
    gpu_context_last_use = std::chrono::steady_clock::now();
    if (!gpu_context_attempted) {
        // Only retire the peer backend once it has gone idle. A frame that
        // interleaves shadows (this backend) with pictures/gradients (the
        // Dawn backend) otherwise destroys and recreates a Metal device on
        // every switch; its worker-thread-pool teardown blocks the frame.
        vox_retire_other_graphite_context("@rpath/libVoxGraphiteDawn.dylib",
            "vox_graphite_picture_release_idle_graphics_memory");
        gpu_context_attempted = true;
        gpu_context = [] {
        skgpu::graphite::MtlBackendContext backend;
        backend.fDevice.reset((CFTypeRef)MTLCreateSystemDefaultDevice());
        if (!backend.fDevice) return std::unique_ptr<skgpu::graphite::Context>();
        auto* queue = [[VoxFrameMetalQueue alloc] initWithDevice:(id<MTLDevice>)backend.fDevice.get()];
        backend.fQueue.reset((CFTypeRef)queue);
        skgpu::graphite::ContextOptions options;
        options.fGpuBudgetInBytes = 64 * 1024 * 1024;
        if (std::getenv("VOX_GRAPHICS_PIPELINE_DIAGNOSTICS"))
            options.fPipelineCachingCallback = [](void*, skgpu::graphite::ContextOptions::PipelineCacheOp op,
                std::string const& label, uint32_t hash, bool precompiled, sk_sp<SkData>) {
                if (op == skgpu::graphite::ContextOptions::PipelineCacheOp::kAddingPipeline)
                    std::fprintf(stderr,"VOX_GRAPHICS_PIPELINE time=%.6f hash=%u precompiled=%d label=%s\n",
                        std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count(),
                        hash, precompiled, label.c_str());
            };
        auto result = skgpu::graphite::ContextFactory::MakeMetal(backend, options);
        if (result) gpu_frame_queue = queue;
        return result;
        }();
    }
    return gpu_context.get();
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_supports_yuv422(void) { return 1; }

extern "C" __attribute__((visibility("default")))
int vox_graphite_prepare_webp_icc_rgba(uint8_t* pixels, int count,
    uint8_t const* profile, int profile_size, float* color_profile)
{
    return vox_prepare_webp_icc_rgba(pixels, count, profile, profile_size, color_profile);
}

SkRRect rounded_rect(float const* data)
{
    SkVector radii[4] {{data[4], data[5]}, {data[6], data[7]},
        {data[8], data[9]}, {data[10], data[11]}};
    SkRRect result;
    result.setRectRadii(SkRect::MakeXYWH(data[0], data[1], data[2], data[3]), radii);
    return result;
}

int read_pixels(skgpu::graphite::Context* gpu, skgpu::graphite::Recorder* recorder,
    SkSurface* surface, SkImageInfo const& info, uint8_t* pixels, int pitch)
{
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface, info, SkIRect::MakeWH(info.width(), info.height()),
        SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
        [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
        }, &result);
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result) return 0;
    for (int row = 0; row < info.height(); ++row) {
        std::memcpy(pixels + static_cast<size_t>(row) * pitch,
            static_cast<uint8_t const*>(result->data(0)) + static_cast<size_t>(row) * result->rowBytes(0),
            static_cast<size_t>(info.width()) * 4);
    }
    return 1;
}
}

extern "C" __attribute__((visibility("default")))
void vox_graphite_finish_frame()
{
    if (!pthread_main_np()) return;
    std::lock_guard lock(gpu_mutex);
    if (!gpu_context || !gpu_frame_queue) return;
    // Resident exports stay asynchronous until the real queue retires. All
    // other public paths preserve their synchronous CPU-pixel boundary.
    bool synchronous = canvas_finish_submission([gpu_frame_queue willRetireAfterFrame]);
    gpu_context->submit(skgpu::graphite::SubmitInfo(synchronous
        ? skgpu::graphite::SyncToCpu::kYes : skgpu::graphite::SyncToCpu::kNo));
    gpu_context->checkAsyncWorkCompletion();
    if ([gpu_frame_queue finishCompletedFrame])
        gpu_context_last_use = std::chrono::steady_clock::now();
}

static int retire_graphics_context_locked()
{
    if (!gpu_context) return 0;
    // CPU raster results remain reusable after the unused upload/context die.
    image_upload_cache.clear();
    cached_pixel_uploads.clear();
    gpu_context->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes));
    gpu_context->checkAsyncWorkCompletion();
    clear_region_targets();
    gpu_context.reset();
    gpu_frame_queue = nil;
    gpu_context_attempted = false;
    return 1;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_retire_graphics_context()
{
    if (!pthread_main_np()) return 0;
    std::lock_guard lock(gpu_mutex);
    return retire_graphics_context_locked();
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_release_idle_graphics_memory()
{
    if (!pthread_main_np()) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!gpu_context || gpu_context_idle) return 0;
    if (std::chrono::steady_clock::now() - gpu_context_last_use < std::chrono::seconds(2)) return -1;
    if (!std::getenv("VOX_DISABLE_IDLE_PIPELINE_RETENTION")) {
        // Release the large recorder/texture allocations while retaining the
        // bounded shader dictionary and compiled pipeline cache. Destroying
        // them after every short pause forces synchronous Metal compilation
        // when the next wheel exposes a different clip/render-step variant.
        image_upload_cache.clear();
        cached_pixel_uploads.clear();
        gpu_context->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes));
        gpu_context->checkAsyncWorkCompletion();
        clear_region_targets();
        gpu_context->freeGpuResources();
        gpu_context_idle = true;
        return 1;
    }
    return retire_graphics_context_locked();
}

extern "C" __attribute__((visibility("default")))
void vox_graphite_release_unused_graphics_memory()
{
    if (!pthread_main_np()) return;
    std::lock_guard lock(gpu_mutex);
    image_cache.clear();
    image_upload_cache.clear();
    cached_pixel_uploads.clear();
    shape_cache.clear();
    shadow_cache.clear();
    path_cache.clear();
    if (!gpu_context) return;
    // Draw wrappers already synchronously read their pixels. Submit/wait also
    // covers a previous early-return path before dropping unused cache refs.
    gpu_context->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes));
    gpu_context->checkAsyncWorkCompletion();
    // Only owned CPU pixels cross this backend's public boundary. Draw-local
    // resources are gone; discard the retained region targets and recorder
    // below before destroying their Context.
    // Dropping cache entries alone leaves Metal's per-context driver storage
    // resident. Release the Context and queue; the next draw recreates them.
    clear_region_targets();
    gpu_context.reset();
    gpu_frame_queue = nil;
    gpu_context_attempted = false;
}

static void draw_shadow_on_canvas(SkCanvas* canvas, VoxGraphiteShadow const& shadow)
{
    SkMatrix matrix;
    matrix.set9(shadow.matrix);
    canvas->setMatrix(matrix);
    canvas->clipRRect(rounded_rect(shadow.content), SkClipOp::kDifference, true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(shadow.alpha, shadow.red, shadow.green, shadow.blue));
    if (shadow.has_float_color)
        paint.setColor4f({shadow.float_color[0], shadow.float_color[1],
            shadow.float_color[2], shadow.float_color[3]}, nullptr);
    paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, std::max(shadow.blur, 0.0f) / 2.0f));
    canvas->drawRRect(rounded_rect(shadow.shadow), paint);
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shadow_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteShadow const* shadow)
{
    if (!pixels || !shadow || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
    std::lock_guard lock(gpu_mutex);
    auto cached = shadow_cache.prepare(*shadow, width, height, pitch, has_background, pixels);
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    draw_shadow_on_canvas(canvas, *shadow);
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) shadow_cache.finish(std::move(cached), pixels, pitch);
    return result;
}

// The complete shadow target, so its analytic blur interpolates exactly as in
// vox_graphite_draw_shadow_pixels, while only the caller's view is transferred.
// The remainder of the input backdrop is transparent.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shadow_region_pixels(VoxGraphitePixelRegion const* region,
    int width, int height, int has_background, VoxGraphiteShadow const* shadow)
{
    if (!region || !region->pixels || !shadow
        || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || region->x < 0 || region->y < 0 || region->width <= 0 || region->height <= 0
        || region->width > width || region->height > height || region->pitch <= 0
        || region->x > width - region->width || region->y > height - region->height
        || size_t(region->pitch) < size_t(region->width) * 4) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
    sk_sp<SkSurface> temporary_surface;
    auto* surface = region_target(gpu, info);
    auto* recorder = region_recorder.get();
    if (!surface) {
        temporary_recorder = gpu->makeRecorder();
        recorder = temporary_recorder.get();
        temporary_surface = vox_shared_surface(recorder, info);
        surface = temporary_surface.get();
    }
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    SkAutoCanvasRestore state(canvas, true);
    canvas->clear(SK_ColorTRANSPARENT);
    auto view_info = info.makeWH(region->width, region->height);
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(view_info, region->pixels,
            region->pitch), region->x, region->y);
    draw_shadow_on_canvas(canvas, *shadow);
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface, view_info,
        SkIRect::MakeXYWH(region->x, region->y, region->width, region->height),
        SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
        [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
        }, &result);
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result) return 0;
    for (int row = 0; row < region->height; ++row)
        std::memcpy(region->pixels + size_t(row) * region->pitch,
            static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0),
            size_t(region->width) * 4);
    return 1;
}

// A PNG tagged by its gAMA and cHRM chunks keeps that color space until the
// GPU converts it to sRGB, as Chromium's raster does.
static sk_sp<SkColorSpace> vox_image_color_space(VoxGraphiteImage const* image)
{
    return vox_image_color_space_from_profile(image->has_color_profile ? image->color_profile : nullptr);
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_resize_rgba_pixels(VoxGraphiteImage const* image,
    uint8_t* pixels, int width, int height, int pitch)
{
    if (!image || !image->pixels || !pixels || !(image->flags & 1) || (image->flags & 4)
        || image->width <= 0 || image->height <= 0 || width <= 0 || height <= 0
        || image->width > 16384 || image->height > 16384
        || width > image->width || height > image->height
        || size_t(image->width) * image->height > 8 * 1024 * 1024
        || image->pitch < image->width * 4 || pitch < width * 4)
        return 0;
    auto info = SkImageInfo::Make(image->width, image->height,
        kRGBA_8888_SkColorType, kPremul_SkAlphaType, vox_image_color_space(image));
    SkPixmap source(info, image->pixels, image->pitch);
    SkPixmap resized(info.makeWH(width, height), pixels, pitch);
    return source.scalePixels(resized,
        SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest));
}

static void force_msaa_render_pass(SkCanvas* canvas, int, int)
{
    // A path selects a multisampled pass. Even a transparent tile-sized path
    // changes subsequent rrect coverage. Keep its bounds below a sample,
    // selecting 4x MSAA without covering a sample or changing the backdrop.
    SkPaint noop;
    noop.setAntiAlias(true);
    noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
    SkPathBuilder path;
    path.moveTo(0, 0);
    path.cubicTo(.01f, .001f, 0, .01f, .01f, .01f);
    path.lineTo(.005f, .002f);
    path.close();
    canvas->drawPath(path.detach(), noop);
}

namespace {
// The upload, sampling and source scale of one image draw, and the texture it
// samples once prepared.
struct PreparedImageDraw {
    int upload_width = 0, upload_height = 0;
    float source_scale_x = 1.0f, source_scale_y = 1.0f;
    bool whole_source = false, needs_mips = false;
    sk_sp<SkImage> texture;
    decltype(image_upload_cache)::Request upload;
};
}

static bool image_draw_is_valid(VoxGraphiteImage const* image)
{
    return image && image->pixels && image->width > 0 && image->height > 0 && image->pitch > 0
        && image->source[2] > 0 && image->source[3] > 0
        && image->destination[2] > 0 && image->destination[3] > 0;
}

static void plan_image_draw(VoxGraphiteImage const* image, PreparedImageDraw& prepared)
{
    int upload_width = image->width, upload_height = image->height;
    bool whole_source = image->source[0] == 0 && image->source[1] == 0
        && image->source[2] == image->width && image->source[3] == image->height;
    float sx = std::hypot(image->matrix[0], image->matrix[3])
        * image->destination[2] / image->source[2];
    float sy = std::hypot(image->matrix[1], image->matrix[4])
        * image->destination[3] / image->source[3];
    bool planar_nearest = image->nearest && (image->flags & 4);
    bool video_frame = image->flags & VOX_GRAPHITE_IMAGE_VIDEO_FRAME;
    int decode_level = image->nearest && !planar_nearest ? 0 : vox_image_decode_level(image->flags);
    if (video_frame) {
        // Upload the complete frame and filter it once on the GPU, without a
        // CPU resize or a mip chain for every new frame.
    } else if (decode_level >= 0) {
        upload_width = vox_image_decode_axis(image->width, decode_level);
        upload_height = vox_image_decode_axis(image->height, decode_level);
    } else if (!image->nearest || planar_nearest) {
        int target_width = std::max(1, static_cast<int>(std::ceil(image->width * sx)));
        int target_height = std::max(1, static_cast<int>(std::ceil(image->height * sy)));
        for (int level = 1; level < 31; ++level) {
            int64_t divisor = int64_t(1) << level;
            int next_width = static_cast<int>((image->width + divisor - 1) / divisor);
            int next_height = static_cast<int>((image->height + divisor - 1) / divisor);
            if (next_width < target_width || next_height < target_height
                || (upload_width == 1 && upload_height == 1)) break;
            upload_width = next_width;
            upload_height = next_height;
        }
    }
    // Chromium generates mips when the draw is smaller than its decoded
    // upload in both axes. Exact mip-sized and nearest-neighbor draws do not
    // need them. Chromium serializes the decode request with the complete
    // image bounds, including when the eventual draw crops the source.
    // Cropped draws retain strict source bounds below.
    bool needs_mips = !image->nearest && !video_frame
        && image->width * sx < upload_width && image->height * sy < upload_height;
    prepared.upload_width = upload_width;
    prepared.upload_height = upload_height;
    prepared.whole_source = whole_source;
    prepared.needs_mips = needs_mips;
    if (upload_width != image->width || upload_height != image->height) {
        prepared.source_scale_x = static_cast<float>(upload_width) / image->width;
        prepared.source_scale_y = static_cast<float>(upload_height) / image->height;
    }
}

// The texture a planned draw samples, from the upload cache or a new upload.
// The caller finishes the upload once its draw has been read back.
struct VoxImmutableImageSource {
    uint64_t key;
    uint8_t const* pixels;
    int width, height, pitch;
};
static thread_local VoxImmutableImageSource immutable_image_source {};

// A caller-scoped decoded-resource generation. No image ABI or source lifetime
// changes: prepare copies/uploads the bytes before the scope ends as usual.
extern "C" __attribute__((visibility("default")))
void vox_graphite_set_image_immutable_source(uint64_t key, uint8_t const* pixels, int width, int height, int pitch)
{
    immutable_image_source={key,pixels,width,height,pitch};
}

static bool prepare_image_texture(skgpu::graphite::Recorder* recorder,
    VoxGraphiteImage const* image, PreparedImageDraw& prepared)
{
    int upload_width = prepared.upload_width, upload_height = prepared.upload_height;
    SkImage::RequiredProperties properties{.fMipmapped = prepared.needs_mips};
    auto content_image = *image;
    content_image.flags &= ~VOX_GRAPHITE_IMAGE_FORCE_MSAA;
    auto const& identity=immutable_image_source;
    bool trusted_kind=image->flags & VOX_GRAPHITE_IMAGE_VIDEO_FRAME
        ? std::getenv("VOX_GPU_VIDEO_UPLOAD_KEYS") : std::getenv("VOX_IMMUTABLE_IMAGE_UPLOADS");
    trusted_kind = trusted_kind && bool(identity.key >> 63) == bool(image->flags & VOX_GRAPHITE_IMAGE_VIDEO_FRAME);
    uint64_t key=trusted_kind && identity.pixels==image->pixels
        && identity.width==image->width && identity.height==image->height && identity.pitch==image->pitch
        && !(image->flags & 4) ? identity.key : 0;
    auto upload = image_upload_cache.prepare(content_image, upload_width, upload_height, prepared.needs_mips,key);
    if (std::getenv("VOX_IMAGE_UPLOAD_DIAGNOSTICS")) {
        using Clock = double (*)();
        static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
        std::fprintf(stderr, "VOX_IMAGE_UPLOAD width=%d height=%d upload_width=%d upload_height=%d reused=%d pending=%d upgrade=%d digested=%d immutable=%d identity_hit=%d t_us=%.3f\n",
            image->width, image->height, upload_width, upload_height, bool(upload.texture),
            bool(upload.pending), upload.needs_mipmaps, upload.verified_by_digest, upload.verified_by_identity, upload.identity_hit, clock ? clock() : -1.0);
    }
    sk_sp<SkImage> texture = upload.texture;
    if (upload.needs_mipmaps) {
        texture = vox_shared_image(recorder, texture, properties);
        if (!texture) return false;
        // Reusing an uploaded image matches Chromium's mip upgrade: the
        // GPU generates its levels instead of uploading a fresh CPU chain.
    }
    if (!texture && (image->flags & 4)) {
        // Flag 16 marks full-resolution 4:4:4 chroma planes.
        bool full_chroma = image->flags & 16;
        int uv_width = full_chroma ? image->width : (image->width + 1) / 2;
        bool horizontal_chroma = image->flags & VOX_GRAPHITE_IMAGE_YUV422;
        int uv_height = full_chroma || horizontal_chroma ? image->height : (image->height + 1) / 2;
        size_t y_size = static_cast<size_t>(image->width) * image->height;
        size_t uv_size = static_cast<size_t>(uv_width) * uv_height;
        bool has_alpha = image->flags & VOX_GRAPHITE_IMAGE_YUVA_ALPHA;
        SkPixmap planes[4] {
            SkPixmap(SkImageInfo::Make(image->width, image->height, kGray_8_SkColorType,
                kOpaque_SkAlphaType), image->pixels, image->width),
            SkPixmap(SkImageInfo::Make(uv_width, uv_height, kGray_8_SkColorType,
                kOpaque_SkAlphaType), image->pixels + y_size, uv_width),
            SkPixmap(SkImageInfo::Make(uv_width, uv_height, kGray_8_SkColorType,
                kOpaque_SkAlphaType), image->pixels + y_size + uv_size, uv_width), {}
        };
        if (has_alpha)
            planes[3] = SkPixmap(SkImageInfo::Make(image->width, image->height,
                kGray_8_SkColorType, kOpaque_SkAlphaType),
                image->pixels + y_size + 2 * uv_size, image->width);
        bool resized = upload_width != image->width || upload_height != image->height;
        std::vector<uint8_t> scaled_planes;
        if (resized) {
            size_t plane_size = static_cast<size_t>(upload_width) * upload_height;
            scaled_planes.resize(plane_size * (has_alpha ? 4 : 3));
            // Chromium's GPU decode cache scales each decoded plane on the CPU
            // and promotes the result to 4:4:4 before uploading it. Scaling the
            // original 4:2:0 textures on the GPU produces different texels.
            for (int index = 0; index < (has_alpha ? 4 : 3); ++index) {
                SkPixmap scaled(SkImageInfo::Make(upload_width, upload_height,
                    kGray_8_SkColorType, kOpaque_SkAlphaType),
                    scaled_planes.data() + plane_size * index, upload_width);
                if (!planes[index].scalePixels(scaled,
                        image->nearest ? SkSamplingOptions(SkFilterMode::kNearest)
                            : SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest))) return false;
                planes[index] = scaled;
            }
            prepared.source_scale_x = static_cast<float>(upload_width) / image->width;
            prepared.source_scale_y = static_cast<float>(upload_height) / image->height;
        }
        SkYUVAInfo yuva(SkISize::Make(upload_width, upload_height),
            has_alpha ? SkYUVAInfo::PlaneConfig::kY_U_V_A : SkYUVAInfo::PlaneConfig::kY_U_V,
            resized || full_chroma ? SkYUVAInfo::Subsampling::k444
                : horizontal_chroma ? SkYUVAInfo::Subsampling::k422 : SkYUVAInfo::Subsampling::k420,
            // JPEG planes use the full BT.601 range; WebP planes are limited.
            (image->flags & 8) ? kJPEG_Full_SkYUVColorSpace : kRec601_SkYUVColorSpace);
        auto pixmaps = SkYUVAPixmaps::FromExternalPixmaps(yuva, planes);
        texture = vox_shared_yuva_image(recorder, pixmaps, properties,
            SkColorSpace::MakeSRGB(), upload.needs_planar_mipmaps);
    } else if (!texture) {
        if (static_cast<size_t>(image->pitch) < static_cast<size_t>(image->width) * 4) return false;
        auto src_info = SkImageInfo::Make(image->width, image->height,
            kRGBA_8888_SkColorType, (image->flags & 1) ? kPremul_SkAlphaType : kUnpremul_SkAlphaType,
            vox_image_color_space(image));
        SkPixmap pixmap(src_info, image->pixels, image->pitch);
        std::vector<uint8_t> premultiplied;
        if (!(image->flags & 1)) {
            premultiplied.resize(static_cast<size_t>(image->pitch) * image->height);
            src_info = src_info.makeAlphaType(kPremul_SkAlphaType);
            if (!pixmap.readPixels(src_info, premultiplied.data(), image->pitch)) return false;
            pixmap = SkPixmap(src_info, premultiplied.data(), image->pitch);
        }
        std::vector<uint8_t> scaled_pixels;
        if (upload_width != image->width || upload_height != image->height) {
            size_t row_bytes = static_cast<size_t>(upload_width) * 4;
            scaled_pixels.resize(row_bytes * upload_height);
            SkPixmap scaled(pixmap.info().makeWH(upload_width, upload_height),
                scaled_pixels.data(), row_bytes);
            // Match the CPU upload resize in Chromium's GPU image decode cache.
            // Generating only GPU mip levels can choose a smaller level and
            // uses different rounding from this decoded-pixel resize.
            if (!pixmap.scalePixels(scaled,
                    SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest))) return false;
            pixmap = scaled;
            prepared.source_scale_x = static_cast<float>(upload_width) / image->width;
            prepared.source_scale_y = static_cast<float>(upload_height) / image->height;
        }
        auto raster = SkImages::RasterFromPixmapCopy(pixmap);
        texture = vox_shared_image(recorder, raster, properties);
        // Chromium's GPU image cache converts a tagged upload into an 8-bit
        // sRGB texture before drawing it, so premultiplied texels are quantized
        // before they are filtered and blended.
        if (texture && image->has_color_profile)
            texture = texture->makeColorSpace(recorder, SkColorSpace::MakeSRGB(), properties);
    }
    if (!texture) return false;
    prepared.texture = std::move(texture);
    prepared.upload = std::move(upload);
    return true;
}

static void draw_prepared_image(SkCanvas* canvas, VoxGraphiteImage const* image,
    PreparedImageDraw const& prepared)
{
    auto const& texture = prepared.texture;
    float source_scale_x = prepared.source_scale_x, source_scale_y = prepared.source_scale_y;
    bool whole_source = prepared.whole_source, needs_mips = prepared.needs_mips;
    SkMatrix matrix;
    matrix.set9(image->matrix);
    canvas->setMatrix(matrix);
    auto rect = [](float const* r) { return SkRect::MakeXYWH(r[0], r[1], r[2], r[3]); };
    bool rounded_mask = image->flags & VOX_GRAPHITE_IMAGE_ROUNDED_ALPHA_MASK;
    if (rounded_mask) canvas->saveLayer(rect(image->clip), nullptr);
    canvas->save();
    // An image already covers its destination rectangle. An identical square
    // clip is redundant, and changes Graphite's image shader interpolation.
    // Retain actual cropping and rounded corners.
    bool clips_destination = (image->flags & VOX_GRAPHITE_IMAGE_EXPLICIT_RECT_CLIP)
        || std::memcmp(image->clip, image->destination,
        sizeof(image->destination)) != 0
        || std::any_of(image->clip + 4, image->clip + 12,
            [](float radius) { return radius != 0; });
    if (clips_destination) canvas->clipRRect(rounded_rect(image->clip), true);
    if (image->has_background_color) {
        SkPaint background;
        background.setAntiAlias(true);
        auto const* rgba = image->background_rgba;
        background.setColor(SkColorSetARGB(rgba[3], rgba[0], rgba[1], rgba[2]));
        canvas->drawRect(rect(image->clip), background);
    }
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(std::clamp(image->opacity, 0.0f, 1.0f));
    auto sampling = SkSamplingOptions(image->nearest ? SkFilterMode::kNearest : SkFilterMode::kLinear,
        needs_mips ? SkMipmapMode::kLinear : SkMipmapMode::kNone);
    auto source_rect = SkRect::MakeXYWH(image->source[0] * source_scale_x,
        image->source[1] * source_scale_y, image->source[2] * source_scale_x,
        image->source[3] * source_scale_y);
    // Blink records a full image in natural coordinates and puts its scale
    // on the canvas. Keep that operation order: folding it into destination
    // geometry changes fractional GPU sampling even with the same outer bounds.
    if (image->flags & (VOX_GRAPHITE_IMAGE_REPEAT_X | VOX_GRAPHITE_IMAGE_REPEAT_Y)) {
        auto local_matrix = SkMatrix::RectToRect(source_rect, rect(image->destination));
        paint.setShader(texture->makeShader(
            image->flags & VOX_GRAPHITE_IMAGE_REPEAT_X ? SkTileMode::kRepeat : SkTileMode::kClamp,
            image->flags & VOX_GRAPHITE_IMAGE_REPEAT_Y ? SkTileMode::kRepeat : SkTileMode::kClamp,
            sampling, &local_matrix));
        canvas->drawRect(rect(image->destination), paint);
    } else if (whole_source && !(image->flags & VOX_GRAPHITE_IMAGE_UNCLAMPED_SOURCE)) {
        auto natural = rect(image->source);
        canvas->concat(SkMatrix::RectToRect(natural, rect(image->destination)));
        if (needs_mips && source_rect.contains(SkRect::MakeWH(texture->width(), texture->height()))) {
            // Chromium replays a complete mipmapped source in decoded pixels.
            // Keeping this scale inside drawImageRect changes edge sampling.
            canvas->concat(SkMatrix::RectToRect(source_rect, natural));
            canvas->drawImage(texture, 0, 0, sampling, &paint);
        } else {
            canvas->drawImageRect(texture, source_rect, natural, sampling, &paint,
                (image->nearest || needs_mips) && !(image->flags & VOX_GRAPHITE_IMAGE_UNCLAMPED_SOURCE)
                    ? SkCanvas::kStrict_SrcRectConstraint : SkCanvas::kFast_SrcRectConstraint);
        }
    } else {
        canvas->drawImageRect(texture, source_rect, rect(image->destination), sampling,
            &paint, image->flags & VOX_GRAPHITE_IMAGE_UNCLAMPED_SOURCE
                ? SkCanvas::kFast_SrcRectConstraint : SkCanvas::kStrict_SrcRectConstraint);
    }
    canvas->restore();
    if (rounded_mask) {
        // Content clips share coverage; the CSS mask is an independent stage.
        SkPaint mask;
        mask.setBlendMode(SkBlendMode::kDstIn);
        canvas->saveLayer(rect(image->clip), &mask);
        mask.setBlendMode(SkBlendMode::kSrcOver);
        mask.setAntiAlias(true);
        mask.setColor(SK_ColorWHITE);
        canvas->drawRRect(rounded_rect(image->clip), mask);
        canvas->restore();
        canvas->restore();
    }
    if (image->border_width > 0) {
        SkPaint border;
        border.setAntiAlias(true);
        border.setStyle(SkPaint::kStroke_Style);
        border.setStrokeWidth(image->border_width);
        auto const* rgba = image->border_rgba;
        border.setColor(SkColorSetARGB(rgba[3], rgba[0], rgba[1], rgba[2]));
        canvas->drawRRect(rounded_rect(image->border_rect), border);
    }
}

#include "native_direct_image_draw.h"
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_direct_image_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteImage const* image)
{
    if (!pixels || !image_draw_is_valid(image) || pitch < int64_t(width) * 4) return 0;
    auto plan = vox_direct_image_raster_plan(*image, width, height);
    if (!plan) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context(); if (!gpu) return 0;
    FullDrawRecorder recorder(gpu); if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info); if (!surface) return 0;
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else surface->getCanvas()->clear(SK_ColorTRANSPARENT);
    PreparedImageDraw prepared;
    prepared.upload_width = image->width; prepared.upload_height = image->height;
    prepared.whole_source = true;
    if (!prepare_image_texture(recorder.get(), image, prepared)
        || !draw_direct_image(surface->getCanvas(), recorder.get(), *image, prepared, *plan, width, height)) return 0;
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) image_upload_cache.finish(std::move(prepared.upload), prepared.texture);
    return result;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_image_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteImage const* image)
{
    if (!pixels || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4
        || !image_draw_is_valid(image)) return 0;
    std::lock_guard lock(gpu_mutex);
    auto cached = image_cache.prepare(*image, width, height, pitch, has_background != 0, pixels);
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    PreparedImageDraw prepared;
    plan_image_draw(image, prepared);
    if (!prepare_image_texture(recorder.get(), image, prepared)) return 0;
    if (image->flags & VOX_GRAPHITE_IMAGE_FORCE_MSAA) force_msaa_render_pass(canvas, width, height);
    draw_prepared_image(canvas, image, prepared);
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) {
        image_upload_cache.finish(std::move(prepared.upload), prepared.texture);
        image_cache.finish(std::move(cached), pixels, pitch);
    }
    return result;
}

// Preserve the original tile extent and image interpolation, but transfer and
// cache only its visible CPU view. Pixels outside the view are transparent,
// just as in the full tile assembled by the root raster grid.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_image_region_pixels(VoxGraphitePixelRegion const* region,
    int width, int height, int has_background, VoxGraphiteImage const* image)
{
    if (!region || !region->pixels || !image_draw_is_valid(image)
        || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || region->x < 0 || region->y < 0 || region->width <= 0 || region->height <= 0
        || region->width > width || region->height > height || region->pitch <= 0
        || region->x > width - region->width || region->y > height - region->height
        || size_t(region->pitch) < size_t(region->width) * 4) return 0;
    std::lock_guard lock(gpu_mutex);
    auto cached = image_cache.prepare_region(*image, width, height, *region, has_background != 0);
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;

    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
    sk_sp<SkSurface> temporary_surface;
    auto* surface = region_target(gpu, info);
    auto* recorder = region_recorder.get();
    if (!surface) {
        temporary_recorder = gpu->makeRecorder();
        recorder = temporary_recorder.get();
        if (!recorder) return 0;
        temporary_surface = vox_shared_surface(recorder, info);
        surface = temporary_surface.get();
    }
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    SkAutoCanvasRestore state(canvas, true);
    canvas->clear(SK_ColorTRANSPARENT);
    auto view_info = info.makeWH(region->width, region->height);
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(view_info, region->pixels,
        region->pitch), region->x, region->y);
    PreparedImageDraw prepared;
    plan_image_draw(image, prepared);
    if (!prepare_image_texture(recorder, image, prepared)) return 0;
    if (image->flags & VOX_GRAPHITE_IMAGE_FORCE_MSAA) force_msaa_render_pass(canvas, width, height);
    draw_prepared_image(canvas, image, prepared);
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface, view_info,
        SkIRect::MakeXYWH(region->x, region->y, region->width, region->height),
        SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
        [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
        }, &result);
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result) return 0;
    for (int row = 0; row < region->height; ++row)
        std::memcpy(region->pixels + size_t(row) * region->pitch,
            static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0),
            size_t(region->width) * 4);
    image_upload_cache.finish(std::move(prepared.upload), prepared.texture);
    image_cache.finish(std::move(cached), region->pixels, region->pitch);
    return 1;
}

#include "native_graphite_image_batch.h"

// Placements of images drawn in turn over one raster, as Chromium draws a
// background's tiles in one GPU pass: one backdrop upload and one readback
// replace one of each per placement. Each placement draws exactly as
// vox_graphite_draw_image_pixels() would over the pixels before it.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_image_tiles(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteImage const* images, int count)
{
    if (!pixels || !images || count <= 0 || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
    for (int index = 0; index < count; ++index)
        if (!image_draw_is_valid(&images[index])) return 0;
    std::lock_guard lock(gpu_mutex);
    auto cached = image_cache.prepare_tiles(images, count, width, height, pitch,
        has_background != 0, pixels);
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    std::vector<PreparedImageDraw> prepared(static_cast<size_t>(count));
    for (int index = 0; index < count; ++index) {
        auto const* image = &images[index];
        auto& draw = prepared[static_cast<size_t>(index)];
        plan_image_draw(image, draw);
        // Placements of one source share its upload.
        for (int prior = 0; prior < index && !draw.texture; ++prior) {
            auto const& earlier = prepared[static_cast<size_t>(prior)];
            auto const* source = &images[prior];
            if (source->pixels == image->pixels && source->width == image->width
                && source->height == image->height && source->pitch == image->pitch
                && source->flags == image->flags && source->has_color_profile == image->has_color_profile
                && !std::memcmp(source->color_profile, image->color_profile, sizeof(image->color_profile))
                && earlier.upload_width == draw.upload_width && earlier.upload_height == draw.upload_height
                && earlier.needs_mips == draw.needs_mips)
                draw.texture = earlier.texture;
        }
        if (!draw.texture && !prepare_image_texture(recorder.get(), image, draw)) return 0;
    }
    if (std::any_of(images, images + count, [](auto const& image) { return image.flags & VOX_GRAPHITE_IMAGE_FORCE_MSAA; }))
        force_msaa_render_pass(canvas, width, height);
    for (int index = 0; index < count; ++index) {
        canvas->save();
        draw_prepared_image(canvas, &images[index], prepared[static_cast<size_t>(index)]);
        canvas->restore();
    }
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) {
        for (auto& draw : prepared)
            image_upload_cache.finish(std::move(draw.upload), draw.texture);
        image_cache.finish(std::move(cached), pixels, pitch);
    }
    return result;
}

static void draw_shape_on_canvas(SkCanvas* canvas, VoxGraphiteShape const& shape, int width, int height)
{
    if (shape.force_msaa) force_msaa_render_pass(canvas, width, height);
    SkMatrix matrix;
    matrix.set9(shape.matrix);
    canvas->setMatrix(matrix);
    for (int index = 0; shape.clip_outs && index < shape.clip_out_count; ++index) {
        float const* clip = shape.clip_outs + index * 4;
        canvas->clipRect(SkRect::MakeLTRB(clip[0], clip[1], clip[2], clip[3]),
            SkClipOp::kDifference, false);
    }
    SkPaint underlay;
    if (shape.has_underlay) {
        underlay.setAntiAlias(shape.anti_alias != 0);
        underlay.setColor(SkColorSetARGB(shape.underlay_rgba[3], shape.underlay_rgba[0],
            shape.underlay_rgba[1], shape.underlay_rgba[2]));
        if (shape.has_float_underlay_color)
            underlay.setColor4f({shape.underlay_float_color[0], shape.underlay_float_color[1],
                shape.underlay_float_color[2], shape.underlay_float_color[3]});
        if (shape.fill < 2 || shape.fill == 6)
            canvas->drawRRect(rounded_rect(shape.underlay_rect), underlay);
    }
    SkPaint paint;
    paint.setAntiAlias(shape.anti_alias != 0);
    if (shape.has_float_color)
        paint.setColor4f({shape.float_color[0], shape.float_color[1], shape.float_color[2], shape.float_color[3]});
    else
        paint.setColor(SkColorSetARGB(shape.alpha, shape.red, shape.green, shape.blue));
    if (!shape.fill || shape.fill == 6) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(std::max(0.0f, shape.thickness));
    }
    if (shape.fill >= 2)
        vox_draw_rounded_single_border(canvas, rounded_rect(shape.rect), paint, shape.fill,
            shape.border_widths, shape.has_underlay ? &underlay : nullptr);
    else
        canvas->drawRRect(rounded_rect(shape.rect), paint);
}

// Read back only the border of large rounded shapes. Opaque fills have a flat
// interior; the original GPU draw supplies fractional edges, corners and
// strokes, including their backdrop and MSAA mode. Cache only those patches,
// retaining the original surface geometry as part of their identity.
static bool draw_large_rounded_shape(uint8_t* pixels, int width, int height,
    int pitch, bool has_background, VoxGraphiteShape const& shape)
{
    if (size_t(width) * height < 8192 || width > 16384 || height > 16384) return false;
    float edges[4];
    auto solid = shape;
    solid.fill = 1;
    if (shape.fill >= 2 || shape.has_underlay || shape.clip_out_count || (shape.fill && shape.alpha != 255)
        || !vox_axis_aligned_rect(solid, edges)) return false;
    float half_x = shape.fill ? 0 : shape.thickness * shape.matrix[0] / 2;
    float half_y = shape.fill ? 0 : shape.thickness * shape.matrix[4] / 2;
    if (!shape.fill && (!(half_x > 0 && half_y > 0) || !std::isfinite(half_x)
            || !std::isfinite(half_y)))
        return false;
    float rx = 0, ry = 0;
    for (int i = 4; i < 12; i += 2) {
        if (shape.rect[i] < 0 || shape.rect[i + 1] < 0
            || !std::isfinite(shape.rect[i]) || !std::isfinite(shape.rect[i + 1])) return false;
        rx = std::max(rx, shape.rect[i]); ry = std::max(ry, shape.rect[i + 1]);
    }
    float corner_width = std::ceil(rx * shape.matrix[0] + half_x) + 2;
    float corner_height = std::ceil(ry * shape.matrix[4] + half_y) + 2;
    if (corner_width * 2 >= edges[2] - edges[0] || corner_height * 2 >= edges[3] - edges[1]
        || corner_width * corner_height > 4096) return false;
    struct Patch { int left, top, width, height; size_t offset; };
    std::vector<Patch> patches;
    size_t patch_bytes = 0;
    auto patch = [&](double left, double top, double right, double bottom) {
        int l = int(std::clamp(left, 0.0, double(width)));
        int t = int(std::clamp(top, 0.0, double(height)));
        int r = int(std::clamp(right, 0.0, double(width)));
        int b = int(std::clamp(bottom, 0.0, double(height)));
        if (l >= r || t >= b) return;
        patches.push_back({l, t, r - l, b - t, patch_bytes});
        patch_bytes += size_t(r - l) * (b - t) * 4;
    };
    double outer_left = std::floor(edges[0] - half_x) - 2;
    double outer_top = std::floor(edges[1] - half_y) - 2;
    double outer_right = std::ceil(edges[2] + half_x) + 2;
    double outer_bottom = std::ceil(edges[3] + half_y) + 2;
    double left_cut = std::ceil(edges[0] + corner_width);
    double top_cut = std::ceil(edges[1] + corner_height);
    double right_cut = std::floor(edges[2] - corner_width);
    double bottom_cut = std::floor(edges[3] - corner_height);
    patch(outer_left, outer_top, left_cut, top_cut);
    patch(right_cut, outer_top, outer_right, top_cut);
    patch(outer_left, bottom_cut, left_cut, outer_bottom);
    patch(right_cut, bottom_cut, outer_right, outer_bottom);
    // Integer-aligned opaque edges have full coverage. Only their rounded
    // corners need GPU pixels; offscreen corners need no readback at all.
    bool aligned_fill = shape.fill;
    for (auto edge : edges) aligned_fill = aligned_fill && edge == std::floor(edge);
    bool aligned_stroke = !shape.fill && shape.alpha == 255;
    for (int i = 0; i < 4; ++i) {
        float half = i % 2 ? half_y : half_x;
        aligned_stroke = aligned_stroke && edges[i] - half == std::floor(edges[i] - half)
            && edges[i] + half == std::floor(edges[i] + half);
    }
    // Fractional straight edges and strokes retain the original GPU coverage.
    if (!aligned_fill && !aligned_stroke) {
        patch(left_cut, outer_top, right_cut, std::ceil(edges[1] + half_y) + 2);
        patch(left_cut, std::floor(edges[3] - half_y) - 2, right_cut, outer_bottom);
        patch(outer_left, top_cut, std::ceil(edges[0] + half_x) + 2, bottom_cut);
        patch(std::floor(edges[2] - half_x) - 2, top_cut, outer_right, bottom_cut);
    }
    if (patch_bytes > 256 * 1024) return false;
    std::vector<uint8_t> packed(patch_bytes);
    if (has_background) for (auto const& patch : patches) for (int y = 0; y < patch.height; ++y)
        std::memcpy(packed.data() + patch.offset + size_t(y) * patch.width * 4,
            pixels + size_t(patch.top + y) * pitch + size_t(patch.left) * 4, size_t(patch.width) * 4);
    if (!patches.empty()) {
        std::lock_guard lock(gpu_mutex);
        auto cached = shape_cache.prepare_patches(shape, width, height,
            int(patch_bytes / 4), has_background, packed.data());
        if (!cached.hit) {
            auto* gpu = context();
            if (!gpu) return false;
            if (!rounded_recorder) {
                skgpu::graphite::RecorderOptions options;
                options.fGpuBudgetInBytes = 16 * 1024 * 1024;
                rounded_recorder = gpu->makeRecorder(options);
            }
            auto* recorder = rounded_recorder.get();
            if (!recorder) return false;
            auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
                kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
            auto surface = vox_shared_surface(recorder, info);
            if (!surface) return false;
            auto* canvas = surface->getCanvas();
            canvas->clear(SK_ColorTRANSPARENT);
            if (has_background) for (auto const& patch : patches)
                vox_shared_write(gpu, surface, SkPixmap(info.makeWH(patch.width, patch.height),
                    packed.data() + patch.offset, size_t(patch.width) * 4), patch.left, patch.top);
            draw_shape_on_canvas(canvas, shape, width, height);
            auto recording = recorder->snap();
            skgpu::graphite::InsertRecordingInfo insertion;
            insertion.fRecording = recording.get();
            if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return false;
            // Keep the original surface origin and extent. Translating a corner
            // into a smaller surface changes GPU coverage rounding by one byte.
            std::vector<std::unique_ptr<const SkImage::AsyncReadResult>> results(patches.size());
            for (size_t i = 0; i < patches.size(); ++i) {
                auto const& patch = patches[i];
                vox_shared_readback(gpu, surface.get(), info.makeWH(patch.width, patch.height),
                    SkIRect::MakeXYWH(patch.left, patch.top, patch.width, patch.height),
                    SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
                    [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                        *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
                    }, &results[i]);
            }
            if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) return false;
            for (size_t i = 0; i < patches.size(); ++i) {
                if (!results[i]) return false;
                auto const& patch = patches[i];
                for (int y = 0; y < patch.height; ++y)
                    std::memcpy(packed.data() + patch.offset + size_t(y) * patch.width * 4,
                        static_cast<uint8_t const*>(results[i]->data(0)) + size_t(y) * results[i]->rowBytes(0),
                        size_t(patch.width) * 4);
            }
            shape_cache.finish(std::move(cached), packed.data(), int(patch_bytes));
        }
    }
    if (!has_background) for (int y = 0; y < height; ++y)
        std::memset(pixels + size_t(y) * pitch, 0, size_t(width) * 4);
    if (shape.fill) {
        std::fill_n(solid.rect + 4, 8, 0.0f);
        std::fill_n(solid.matrix, 9, 0.0f);
        solid.matrix[0] = solid.matrix[4] = solid.matrix[8] = 1;
        solid.rect[0] = float(std::ceil(edges[0])); solid.rect[1] = float(std::ceil(edges[1]));
        solid.rect[2] = float(std::floor(edges[2])) - solid.rect[0];
        solid.rect[3] = float(std::floor(edges[3])) - solid.rect[1];
        vox_draw_solid_rect(pixels, width, height, pitch, true, solid);
    } else if (aligned_stroke) {
        // Straight, opaque stroke edges cover whole device pixels. Paint the
        // rectangular strips, then restore the original GPU corner patches,
        // including their untouched backdrop outside the rounded contour.
        auto stroke = shape;
        std::fill_n(stroke.rect + 4, 8, 0.0f);
        // Very large coordinates can round a strip's inner and outer edge
        // together. The helper rejects them before touching the backdrop.
        if (!vox_draw_solid_stroke(pixels, width, height, pitch, true, stroke)) return false;
    }
    for (auto const& patch : patches) for (int y = 0; y < patch.height; ++y)
        std::memcpy(pixels + size_t(patch.top + y) * pitch + size_t(patch.left) * 4,
            packed.data() + patch.offset + size_t(y) * patch.width * 4, size_t(patch.width) * 4);
    return true;
}

// Copy between a packed patch and a CPU view without materializing the rest
// of its GPU tile. An absent backdrop texel is transparent, as in the full tile.
static void copy_shape_patch(VoxGraphitePixelRegion const& region, uint8_t* patch,
    int left, int top, int width, int height, bool to_region)
{
    int l = std::max(left, region.x), t = std::max(top, region.y);
    int r = std::min(left + width, region.x + region.width);
    int b = std::min(top + height, region.y + region.height);
    if (l >= r || t >= b) return;
    for (int y = t; y < b; ++y) {
        auto* view_row = region.pixels + size_t(y - region.y) * region.pitch + size_t(l - region.x) * 4;
        auto* patch_row = patch + size_t(y - top) * width * 4 + size_t(l - left) * 4;
        if (to_region) std::memcpy(view_row, patch_row, size_t(r - l) * 4);
        else std::memcpy(patch_row, view_row, size_t(r - l) * 4);
    }
}

static void clear_shape_region(VoxGraphitePixelRegion const& region)
{
    for (int y = 0; y < region.height; ++y)
        std::memset(region.pixels + size_t(y) * region.pitch, 0, size_t(region.width) * 4);
}

static bool draw_rounded_parts(VoxGraphitePixelRegion const* regions, int count, int width, int height,
    bool has_background, VoxGraphiteShape const& shape)
{
    if (width > 16384 || height > 16384) return false;
    float edges[4];
    auto solid = shape;
    solid.fill = 1;
    if (shape.fill >= 2 || shape.has_underlay || shape.clip_out_count || (shape.fill && shape.alpha != 255)
        || !vox_axis_aligned_rect(solid, edges)) return false;
    float half_x = shape.fill ? 0 : shape.thickness * shape.matrix[0] / 2;
    float half_y = shape.fill ? 0 : shape.thickness * shape.matrix[4] / 2;
    if (!shape.fill && (!(half_x > 0 && half_y > 0) || !std::isfinite(half_x)
            || !std::isfinite(half_y)))
        return false;
    float rx = 0, ry = 0;
    for (int i = 4; i < 12; i += 2) {
        if (shape.rect[i] < 0 || shape.rect[i + 1] < 0
            || !std::isfinite(shape.rect[i]) || !std::isfinite(shape.rect[i + 1])) return false;
        rx = std::max(rx, shape.rect[i]); ry = std::max(ry, shape.rect[i + 1]);
    }
    float corner_width = std::ceil(rx * shape.matrix[0] + half_x) + 2;
    float corner_height = std::ceil(ry * shape.matrix[4] + half_y) + 2;
    if (corner_width * 2 >= edges[2] - edges[0] || corner_height * 2 >= edges[3] - edges[1]
        || corner_width * corner_height > 4096) return false;
    struct Patch { int left, top, width, height; size_t offset; };
    std::vector<Patch> patches;
    size_t patch_bytes = 0;
    auto patch = [&](double left, double top, double right, double bottom) {
        int l = int(std::clamp(left, 0.0, double(width)));
        int t = int(std::clamp(top, 0.0, double(height)));
        int r = int(std::clamp(right, 0.0, double(width)));
        int b = int(std::clamp(bottom, 0.0, double(height)));
        if (l >= r || t >= b) return;
        patches.push_back({l, t, r - l, b - t, patch_bytes});
        patch_bytes += size_t(r - l) * (b - t) * 4;
    };
    double outer_left = std::floor(edges[0] - half_x) - 2;
    double outer_top = std::floor(edges[1] - half_y) - 2;
    double outer_right = std::ceil(edges[2] + half_x) + 2;
    double outer_bottom = std::ceil(edges[3] + half_y) + 2;
    double left_cut = std::ceil(edges[0] + corner_width);
    double top_cut = std::ceil(edges[1] + corner_height);
    double right_cut = std::floor(edges[2] - corner_width);
    double bottom_cut = std::floor(edges[3] - corner_height);
    patch(outer_left, outer_top, left_cut, top_cut);
    patch(right_cut, outer_top, outer_right, top_cut);
    patch(outer_left, bottom_cut, left_cut, outer_bottom);
    patch(right_cut, bottom_cut, outer_right, outer_bottom);
    // Integer-aligned opaque edges have full coverage. Only their rounded
    // corners need GPU pixels; offscreen corners need no readback at all.
    bool aligned_fill = shape.fill;
    for (auto edge : edges) aligned_fill = aligned_fill && edge == std::floor(edge);
    bool aligned_stroke = !shape.fill && shape.alpha == 255;
    for (int i = 0; i < 4; ++i) {
        float half = i % 2 ? half_y : half_x;
        aligned_stroke = aligned_stroke && edges[i] - half == std::floor(edges[i] - half)
            && edges[i] + half == std::floor(edges[i] + half);
    }
    if (!shape.fill) {
#ifdef VOX_DISABLE_PLAIN_RECT_STRIPS
        if (!aligned_stroke) return false;
#endif
        if (edges[2] - edges[0] <= half_x * 2
            || edges[3] - edges[1] <= half_y * 2) return false;
        for (int i = 0; i < 4; ++i) {
            float half = i % 2 ? half_y : half_x;
            if (!std::isfinite(edges[i] - half) || !std::isfinite(edges[i] + half)) return false;
        }
    }
    // Fractional straight edges and strokes retain the original GPU coverage.
    if (!aligned_fill && !aligned_stroke) {
        patch(left_cut, outer_top, right_cut, std::ceil(edges[1] + half_y) + 2);
        patch(left_cut, std::floor(edges[3] - half_y) - 2, right_cut, outer_bottom);
        patch(outer_left, top_cut, std::ceil(edges[0] + half_x) + 2, bottom_cut);
        patch(std::floor(edges[2] - half_x) - 2, top_cut, outer_right, bottom_cut);
    }
    if (patch_bytes > 256 * 1024) return false;
    std::vector<uint8_t> packed(patch_bytes);
    if (has_background) for (auto const& patch : patches)
        for (int i = 0; i < count; ++i) copy_shape_patch(regions[i], packed.data() + patch.offset,
            patch.left, patch.top, patch.width, patch.height, false);
    if (!patches.empty()) {
        std::lock_guard lock(gpu_mutex);
        auto cached = shape_cache.prepare_patches(shape, width, height,
            int(patch_bytes / 4), has_background, packed.data());
        if (!cached.hit) {
            auto* gpu = context();
            if (!gpu) return false;

            auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
                kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
            std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
            sk_sp<SkSurface> temporary_surface;
            auto* surface = region_target(gpu, info);
            auto* recorder = region_recorder.get();
            if (!surface) {
                temporary_recorder = gpu->makeRecorder();
                recorder = temporary_recorder.get();
                if (!recorder) return false;
                temporary_surface = vox_shared_surface(recorder, info);
                surface = temporary_surface.get();
            }
            if (!surface) return false;
            auto* canvas = surface->getCanvas();
            SkAutoCanvasRestore state(canvas, true);
            canvas->clear(SK_ColorTRANSPARENT);
            if (has_background) for (auto const& patch : patches)
                vox_shared_write(gpu, surface, SkPixmap(info.makeWH(patch.width, patch.height),
                    packed.data() + patch.offset, size_t(patch.width) * 4), patch.left, patch.top);
            draw_shape_on_canvas(canvas, shape, width, height);
            auto recording = recorder->snap();
            skgpu::graphite::InsertRecordingInfo insertion;
            insertion.fRecording = recording.get();
            if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return false;
            // Keep the original surface origin and extent. Translating a corner
            // into a smaller surface changes GPU coverage rounding by one byte.
            std::vector<std::unique_ptr<const SkImage::AsyncReadResult>> results(patches.size());
            for (size_t i = 0; i < patches.size(); ++i) {
                auto const& patch = patches[i];
                vox_shared_readback(gpu, surface, info.makeWH(patch.width, patch.height),
                    SkIRect::MakeXYWH(patch.left, patch.top, patch.width, patch.height),
                    SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
                    [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                        *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
                    }, &results[i]);
            }
            if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) return false;
            for (size_t i = 0; i < patches.size(); ++i) {
                if (!results[i]) return false;
                auto const& patch = patches[i];
                for (int y = 0; y < patch.height; ++y)
                    std::memcpy(packed.data() + patch.offset + size_t(y) * patch.width * 4,
                        static_cast<uint8_t const*>(results[i]->data(0)) + size_t(y) * results[i]->rowBytes(0),
                        size_t(patch.width) * 4);
            }
            shape_cache.finish(std::move(cached), packed.data(), int(patch_bytes));
        }
    }
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        if (!has_background) clear_shape_region(view);
        uint32_t color = 0xff000000u | uint32_t(shape.red) << 16 | uint32_t(shape.green) << 8 | shape.blue;
        auto strip = [&](double l, double t, double r, double b) {
            int left = int(std::clamp(l, double(view.x), double(view.x + view.width)));
            int top = int(std::clamp(t, double(view.y), double(view.y + view.height)));
            int right = int(std::clamp(r, double(view.x), double(view.x + view.width)));
            int bottom = int(std::clamp(b, double(view.y), double(view.y + view.height)));
            for (int y = top; y < bottom; ++y) for (int x = left; x < right; ++x)
                std::memcpy(view.pixels + size_t(y - view.y) * view.pitch + size_t(x - view.x) * 4, &color, 4);
        };
        if (shape.fill) strip(std::ceil(edges[0]), std::ceil(edges[1]),
            std::floor(edges[2]), std::floor(edges[3]));
        else {
            strip(edges[0] - half_x, edges[1] - half_y, edges[2] + half_x, edges[1] + half_y);
            strip(edges[0] - half_x, edges[3] - half_y, edges[2] + half_x, edges[3] + half_y);
            strip(edges[0] - half_x, edges[1] + half_y, edges[0] + half_x, edges[3] - half_y);
            strip(edges[2] - half_x, edges[1] + half_y, edges[2] + half_x, edges[3] - half_y);
        }
        for (auto const& patch : patches)
            copy_shape_patch(view, packed.data() + patch.offset,
                patch.left, patch.top, patch.width, patch.height, true);
    }
    return true;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_rounded_parts_pixels(VoxGraphitePixelRegion const* regions, int count,
    int width, int height, int has_background, VoxGraphiteShape const* shape)
{
    if (!regions || count <= 0 || count > 4 || !shape || shape->alpha != 255
        || width <= 0 || height <= 0 || width > 16384 || height > 16384) return 0;
    if (shape->has_float_color) {
        auto color = SkColor4f::FromColor(SkColorSetARGB(shape->alpha, shape->red, shape->green, shape->blue));
        if (!std::equal(shape->float_color, shape->float_color + 4, color.vec())) return 0;
    }
    size_t area = 0;
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.pitch <= 0 || view.width > width || view.height > height
            || view.x > width - view.width || view.y > height - view.height
            || size_t(view.pitch) < size_t(view.width) * 4) return 0;
        area += size_t(view.width) * view.height;
        for (int j = 0; j < i; ++j) {
            auto const& prior = regions[j];
            if (view.x < prior.x + prior.width && prior.x < view.x + view.width
                && view.y < prior.y + prior.height && prior.y < view.y + view.height) return 0;
        }
    }
    if (area > 65536) return 0;
    return draw_rounded_parts(regions, count, width, height, has_background != 0, *shape);
}

// Small controls still rasterize in their original Chromium tile: changing
// the surface extent changes GPU coverage rounding. Only the conservative
// affected rectangle needs a backdrop, readback or retained cache entry.
struct SmallShapePatchBounds { int left, top, width, height; };
static bool compound_shape_patches_disabled()
{
    static bool disabled = [] {
        auto* value = std::getenv("VOX_DISABLE_COMPOUND_SHAPE_PATCHES");
        return value && *value;
    }();
    return disabled;
}

static bool small_shape_patch_bounds(VoxGraphiteShape const& shape, int width, int height,
    SmallShapePatchBounds& patch, bool bounded = true)
{
    if (width > 16384 || height > 16384 || shape.clip_out_count < 0
        || shape.clip_out_count > 4096 || (shape.clip_out_count && !shape.clip_outs)
        || ((shape.has_underlay || shape.clip_out_count) && compound_shape_patches_disabled()))
        return false;
    // Difference clips cannot expand the affected area. Their bytes still
    // belong to the cache key, rather than the caller's borrowed pointer.
    for (int i = 0; i < shape.clip_out_count * 4; ++i)
        if (!std::isfinite(shape.clip_outs[i]) || std::abs(shape.clip_outs[i]) > 65536) return false;
    auto const* m = shape.matrix;
    if ((m[0] != 1 && m[0] != 2) || (m[4] != 1 && m[4] != 2)
        || m[1] != 0 || m[3] != 0 || m[6] != 0 || m[7] != 0 || m[8] != 1)
        return false;
    for (float value : shape.matrix)
        if (!std::isfinite(value) || std::abs(value) > 65536) return false;
    for (float value : shape.rect)
        if (!std::isfinite(value) || std::abs(value) > 32768) return false;
    if (!(shape.rect[2] > 0 && shape.rect[3] > 0)
        || !std::isfinite(shape.thickness) || std::abs(shape.thickness) > 4096)
        return false;
    SkPaint paint;
    if (!shape.fill || shape.fill == 6) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(std::max(0.0f, shape.thickness));
    }
    SkRect storage;
    auto local = paint.computeFastBounds(rounded_rect(shape.rect).rect(), &storage);
    if (shape.has_underlay) {
        for (float value : shape.underlay_rect)
            if (!std::isfinite(value) || std::abs(value) > 32768) return false;
        if (!(shape.underlay_rect[2] > 0 && shape.underlay_rect[3] > 0)) return false;
        // A control's background can extend beyond its foreground stroke.
        // Single-side borders clip their underlay to the outer border, but
        // including the whole underlay remains conservative for those draws.
        local.join(rounded_rect(shape.underlay_rect).rect());
    }
    SkMatrix matrix;
    matrix.set9(m);
    auto bounds = matrix.mapRect(local);
    if (!bounds.isFinite()) return false;
    auto bound = [](double value, int limit) {
        return int(std::clamp(value, 0.0, double(limit)));
    };
    int left = bound(std::floor(bounds.left()) - 2, width);
    int top = bound(std::floor(bounds.top()) - 2, height);
    int right = bound(std::ceil(bounds.right()) + 2, width);
    int bottom = bound(std::ceil(bounds.bottom()) + 2, height);
    int patch_width = right - left, patch_height = bottom - top;
    size_t count = size_t(patch_width) * patch_height;
    // Overlay scrollbars can span almost the full viewport. Keep their thin
    // fills and outlines compact too, with at most 256 KiB per staged patch.
    bool thin = std::min(patch_width, patch_height) <= 32;
    if (bounded && (count > (thin ? 65536u : 16384u)
            || count * 4 >= size_t(width) * height)) return false;
    patch = {left, top, patch_width, patch_height};
    return true;
}

static void diagnose_compound_shape_patch(VoxGraphiteShape const& shape,
    SmallShapePatchBounds const& bounds, int width, int height, char const* route)
{
    static bool diagnostic = [] {
        auto* value = std::getenv("VOX_COMPOUND_SHAPE_PATCH_DIAGNOSTIC");
        return value && *value;
    }();
    if (!diagnostic || (!shape.has_underlay && !shape.clip_out_count)) return;
    static std::atomic<unsigned> samples[2];
    auto* marker = std::getenv("VOX_POL_INPUT_MARKER");
    int input = marker && access(marker, F_OK) == 0;
    if (samples[input].fetch_add(1, std::memory_order_relaxed) < 16) {
        Dl_info image {};
        dladdr(reinterpret_cast<void*>(&diagnose_compound_shape_patch), &image);
        std::fprintf(stderr, "VOX_COMPOUND_SHAPE_PATCH_EXECUTED input=%d route=%s underlay=%d clips=%d patch_pixels=%d tile_pixels=%d image=%s\n",
            input, route, shape.has_underlay, shape.clip_out_count,
            bounds.width * bounds.height, width * height, image.dli_fname ? image.dli_fname : "unknown");
    }
}

static bool draw_small_shape_patch(VoxGraphitePixelRegion const& region, int width, int height,
    bool has_background, VoxGraphiteShape const& shape)
{
    SmallShapePatchBounds bounds;
    if (!small_shape_patch_bounds(shape, width, height, bounds)) return false;
    auto [left, top, patch_width, patch_height] = bounds;
    size_t count = size_t(patch_width) * patch_height;
    if (!count) {
        if (!has_background) clear_shape_region(region);
        return true;
    }
    std::vector<uint8_t> patch(count * 4);
    if (has_background) copy_shape_patch(region, patch.data(), left, top, patch_width, patch_height, false);
    if (count) {
        std::lock_guard lock(gpu_mutex);
        auto cached = shape_cache.prepare_patches(shape, width, height,
            int(count), has_background, patch.data());
        if (!cached.hit) {
            auto* gpu = context();
            if (!gpu) return false;

            auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
                kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
            std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
            sk_sp<SkSurface> temporary_surface;
            auto* surface = region_target(gpu, info);
            auto* recorder = region_recorder.get();
            if (!surface) {
                temporary_recorder = gpu->makeRecorder();
                recorder = temporary_recorder.get();
                if (!recorder) return false;
                temporary_surface = vox_shared_surface(recorder, info);
                surface = temporary_surface.get();
            }
            if (!surface) return false;
            auto* canvas = surface->getCanvas();
            SkAutoCanvasRestore state(canvas, true);
            canvas->clear(SK_ColorTRANSPARENT);
            if (has_background)
                vox_shared_write(gpu, surface, SkPixmap(info.makeWH(patch_width, patch_height),
                    patch.data(), size_t(patch_width) * 4), left, top);
            draw_shape_on_canvas(canvas, shape, width, height);
            auto recording = recorder->snap();
            skgpu::graphite::InsertRecordingInfo insertion;
            insertion.fRecording = recording.get();
            if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess)
                return false;
            std::unique_ptr<const SkImage::AsyncReadResult> result;
            vox_shared_readback(gpu, surface, info.makeWH(patch_width, patch_height),
                SkIRect::MakeXYWH(left, top, patch_width, patch_height),
                SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
                [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                    *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
                }, &result);
            if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result)
                return false;
            for (int y = 0; y < patch_height; ++y)
                std::memcpy(patch.data() + size_t(y) * patch_width * 4,
                    static_cast<uint8_t const*>(result->data(0)) + size_t(y) * result->rowBytes(0),
                    size_t(patch_width) * 4);
            shape_cache.finish(std::move(cached), patch.data(), int(count * 4));
        }
    }
    if (!has_background) clear_shape_region(region);
    copy_shape_patch(region, patch.data(), left, top, patch_width, patch_height, true);
    diagnose_compound_shape_patch(shape, bounds, width, height, "single");
    return true;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shape_region_pixels(VoxGraphitePixelRegion const* region,
    int width, int height, int has_background, VoxGraphiteShape const* shape)
{
    if (!region || !region->pixels || !shape || width <= 0 || height <= 0
        || width > 16384 || height > 16384 || region->x < 0 || region->y < 0
        || region->width <= 0 || region->height <= 0 || region->pitch <= 0
        || region->width > width || region->height > height
        || region->x > width - region->width || region->y > height - region->height
        || size_t(region->pitch) < size_t(region->width) * 4) return 0;
    return draw_small_shape_patch(*region, width, height, has_background != 0, *shape);
}

#include "native_graphite_shape_batch.h"

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shape_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteShape const* shape)
{
    if (!pixels || !shape || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
    // CSS retains unrounded colors even for ordinary byte-valued sRGB. When
    // both SkPaint setters produce exactly the same components, these draws
    // can use the opaque rectangle and rounded-border paths too. Comparing
    // bytes after quantization would lose coverage/blending precision.
    bool byte_color = !shape->has_float_color;
    if (!byte_color) {
        auto color = SkColor4f::FromColor(SkColorSetARGB(shape->alpha,
            shape->red, shape->green, shape->blue));
        byte_color = std::equal(shape->float_color, shape->float_color + 4, color.vec());
    }
    if (byte_color) {
        if (vox_draw_solid_rect(pixels, width, height, pitch, has_background != 0, *shape)) return 1;
        if (vox_draw_solid_stroke(pixels, width, height, pitch, has_background != 0, *shape)) return 1;
        if (draw_large_rounded_shape(pixels, width, height, pitch, has_background != 0, *shape)) return 1;
    }
    if (draw_small_shape_patch({0, 0, width, height, pitch, pixels}, width, height,
            has_background != 0, *shape)) return 1;
    std::lock_guard lock(gpu_mutex);
    auto cached = shape_cache.prepare(*shape, width, height, pitch, has_background != 0, pixels);
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    draw_shape_on_canvas(canvas, *shape, width, height);
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) shape_cache.finish(std::move(cached), pixels, pitch);
    return result;
}

static bool draw_path_on_canvas(SkCanvas* canvas, VoxGraphitePath const* path,
    SkM44 const* parent = nullptr, SkPathEffect* path_effect = nullptr)
{
    SkAutoCanvasRestore clip_scope(canvas, path->has_clip || path->has_ancestor_clip);
    SkMatrix matrix;
    matrix.set9(path->matrix);
    if (parent) {
        canvas->setMatrix(*parent);
        canvas->concat(SkM44(matrix));
    } else canvas->setMatrix(matrix);
    if (path->has_clip) canvas->clipRRect(rounded_rect(path->clip), SkClipOp::kIntersect, true);
    if (path->has_ancestor_clip) canvas->clipRRect(rounded_rect(path->ancestor_clip), SkClipOp::kIntersect, true);
    auto geometry = vox_path_from_serialized_segments(path->segments, path->segment_count);
    geometry.setFillType(path->even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(path->alpha, path->red, path->green, path->blue));
    if (path->has_float_color)
        paint.setColor4f({path->float_color[0], path->float_color[1], path->float_color[2], path->float_color[3]});
    if (path->has_float_alpha) paint.setAlphaf(path->opacity);
    std::vector<SkColor4f> colors;
    std::vector<float> positions;
    if (path->gradient) {
        if (!path->stops || path->stop_count < 2) return false;
        for (int index = 0; index < path->stop_count; ++index) {
            auto const* stop = path->stops + index * 5;
            colors.push_back({stop[0], stop[1], stop[2], stop[3]});
            positions.push_back(stop[4]);
        }
        SkMatrix local;
        local.set9(path->gradient_matrix);
        SkGradient::Interpolation interpolation;
        if (path->gradient_premul)
            interpolation.fInPremul = SkGradient::Interpolation::InPremul::kYes;
        SkGradient gradient(SkGradient::Colors(SkSpan<const SkColor4f>(colors),
            SkSpan<const float>(positions), static_cast<SkTileMode>(path->tile_mode)), interpolation);
        auto const* points = path->gradient_points;
        sk_sp<SkShader> shader;
        if (path->gradient == 1) {
            SkPoint ends[] {{points[0], points[1]}, {points[2], points[3]}};
            shader = SkShaders::LinearGradient(ends, gradient, &local);
        } else {
            shader = SkShaders::TwoPointConicalGradient({points[0], points[1]}, points[2],
                {points[3], points[4]}, points[5], gradient, &local);
        }
        if (!shader) return false;
        paint.setShader(std::move(shader));
        // Blink dithers gradient paints.
        paint.setDither(true);
        paint.setAlphaf(std::clamp(path->opacity, 0.0f, 1.0f));
        if (path->linear_color_space)
            paint.setColorFilter(SkColorFilters::LinearToSRGBGamma());
    }
    if (path->stroke) {
        if (path->non_scaling_stroke) {
            geometry = geometry.makeTransform(matrix);
            if (parent) {
                SkMatrix inverse;
                if (!matrix.invert(&inverse)) return true;
                canvas->concat(SkM44(inverse));
            } else canvas->resetMatrix();
        }
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(path->stroke_width);
        paint.setStrokeCap(path->line_cap == 1 ? SkPaint::kRound_Cap
            : path->line_cap == 2 ? SkPaint::kSquare_Cap : SkPaint::kButt_Cap);
        paint.setStrokeJoin(path->line_join == 1 ? SkPaint::kRound_Join
            : path->line_join == 2 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
        paint.setStrokeMiter(std::max(path->miter_limit, 1.0f));
        if (path_effect) paint.setPathEffect(sk_ref_sp(path_effect));
    }
    canvas->drawPath(geometry, paint);
    return true;
}

#include "native_graphite_canvas.h"

// Chromium draws SVG paths through its GPU rasterizer, whose multisampled
// coverage differs from Skia's CPU analytic antialiasing on complex outlines.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_path_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphitePath const* path)
{
    if (!pixels || !path || !path->segments || path->segment_count <= 0 || width <= 0
        || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
    std::lock_guard lock(gpu_mutex);
    auto cached = path_cache.prepare(*path, width, height, pitch, has_background != 0, pixels);
    static bool const trace = std::getenv("VOX_PATH_CACHE_DIAGNOSTICS");
    if (trace) {
        using Clock = double (*)();
        static auto clock = reinterpret_cast<Clock>(dlsym(RTLD_DEFAULT, "vox_precise_scroll_diagnostic_time"));
        std::fprintf(stderr, "VOX_PATH_CACHE canonical=%d hit=%d pending=%d width=%d height=%d gradient=%d t_us=%.3f\n",
            vox_canonical_path_admission_enabled(), cached.hit, bool(cached.pending),
            width, height, path->gradient, clock ? clock() : -1);
    }
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    if (!draw_path_on_canvas(canvas, path)) return 0;
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) path_cache.finish(std::move(cached), pixels, pitch);
    return result;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_dashed_path_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphitePath const* path,
    float const* intervals, int interval_count, float phase)
{
    if (!pixels || !path || !path->segments || path->segment_count <= 0 || !path->stroke
        || width <= 0 || height <= 0 || pitch <= 0 || size_t(pitch) < size_t(width) * 4
        || !intervals || interval_count <= 0 || interval_count % 2 || !std::isfinite(phase)) return 0;
    for (int i = 0; i < interval_count; ++i)
        if (!std::isfinite(intervals[i]) || intervals[i] <= 0) return 0;
    auto effect = SkDashPathEffect::Make({intervals, size_t(interval_count)}, phase);
    if (!effect) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    if (!draw_path_on_canvas(canvas, path, nullptr, effect.get())) return 0;
    return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
}

// Preserve the GPU surface and shader coordinates while transferring only the
// caller-visible pixels. The remainder of the input backdrop is transparent.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_path_region_pixels(VoxGraphitePixelRegion const* region,
    int width, int height, int has_background, VoxGraphitePath const* path)
{
    if (!region || !region->pixels || !path || !path->segments || path->segment_count <= 0
        || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || region->x < 0 || region->y < 0 || region->width <= 0 || region->height <= 0
        || region->width > width || region->height > height || region->pitch <= 0
        || region->x > width - region->width || region->y > height - region->height
        || size_t(region->pitch) < size_t(region->width) * 4) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
    sk_sp<SkSurface> temporary_surface;
    auto* surface = region_target(gpu, info);
    auto* recorder = region_recorder.get();
    if (!surface) {
        temporary_recorder = gpu->makeRecorder();
        recorder = temporary_recorder.get();
        temporary_surface = vox_shared_surface(recorder, info);
        surface = temporary_surface.get();
    }
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    SkAutoCanvasRestore state(canvas, true);
    canvas->clear(SK_ColorTRANSPARENT);
    auto view_info = info.makeWH(region->width, region->height);
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(view_info, region->pixels,
            region->pitch), region->x, region->y);
    if (!draw_path_on_canvas(canvas, path)) return 0;
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface, view_info,
        SkIRect::MakeXYWH(region->x, region->y, region->width, region->height),
        SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
        [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
        }, &result);
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result) return 0;
    for (int row = 0; row < region->height; ++row)
        std::memcpy(region->pixels + size_t(row) * region->pitch,
            static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0),
            size_t(region->width) * 4);
    return 1;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_path_parts_pixels(VoxGraphitePixelRegion const* regions, int count,
    int width, int height, int has_background, VoxGraphitePath const* path)
{
    if (!regions || count <= 0 || count > 32 || !path || !path->segments
        || path->segment_count <= 0 || path->gradient || path->stop_count || path->stroke
        || width <= 0 || height <= 0 || width > 16384 || height > 16384) return 0;
    size_t area = 0;
    std::vector<int> rectangles;
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        if (!view.pixels || view.x < 0 || view.y < 0 || view.width <= 0 || view.height <= 0
            || view.width > width || view.height > height || view.pitch <= 0
            || view.x > width - view.width || view.y > height - view.height
            || size_t(view.pitch) < size_t(view.width) * 4) return 0;
        for (int j = 0; j < i; ++j) {
            auto const& prior = regions[j];
            if (view.x < prior.x + prior.width && prior.x < view.x + view.width
                && view.y < prior.y + prior.height && prior.y < view.y + view.height) return 0;
        }
        area += size_t(view.width) * view.height;
        rectangles.insert(rectangles.end(), {view.x, view.y, view.width, view.height});
    }
    if (area > 65536) return 0;
    std::vector<uint8_t> packed(area * 4);
    size_t offset = 0;
    if (has_background) for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        for (int y = 0; y < view.height; ++y)
            std::memcpy(packed.data() + offset + size_t(y) * view.width * 4,
                view.pixels + size_t(y) * view.pitch, size_t(view.width) * 4);
        offset += size_t(view.width) * view.height * 4;
    }
    std::lock_guard lock(gpu_mutex);
    auto cached = path_cache.prepare_path_patches(*path, width, height,
        int(area), has_background != 0, packed.data(), rectangles);
    if (!cached.hit) {
        auto* gpu = context();
        if (!gpu) return 0;
        auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
            kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
        std::unique_ptr<skgpu::graphite::Recorder> temporary_recorder;
        sk_sp<SkSurface> temporary_surface;
        auto* surface = region_target(gpu, info);
        auto* recorder = region_recorder.get();
        if (!surface) {
            temporary_recorder = gpu->makeRecorder();
            recorder = temporary_recorder.get();
            if (!recorder) return 0;
            temporary_surface = vox_shared_surface(recorder, info);
            surface = temporary_surface.get();
        }
        if (!surface) return 0;
        auto* canvas = surface->getCanvas();
        canvas->clear(SK_ColorTRANSPARENT);
        offset = 0;
        if (has_background) for (int i = 0; i < count; ++i) {
            auto const& view = regions[i];
            vox_shared_write(gpu, surface, SkPixmap(info.makeWH(view.width, view.height),
                packed.data() + offset, size_t(view.width) * 4), view.x, view.y);
            offset += size_t(view.width) * view.height * 4;
        }
        if (!draw_path_on_canvas(canvas, path)) return 0;
        auto recording = recorder->snap();
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
        std::vector<std::unique_ptr<const SkImage::AsyncReadResult>> results(count);
        for (int i = 0; i < count; ++i) {
            auto const& view = regions[i];
            vox_shared_readback(gpu, surface, info.makeWH(view.width, view.height),
                SkIRect::MakeXYWH(view.x, view.y, view.width, view.height),
                SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
                [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
                    *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
                }, &results[i]);
        }
        if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) return 0;
        for (auto const& result : results) if (!result) return 0;
        offset = 0;
        for (int i = 0; i < count; ++i) {
            auto const& view = regions[i];
            for (int y = 0; y < view.height; ++y)
                std::memcpy(packed.data() + offset + size_t(y) * view.width * 4,
                    static_cast<uint8_t const*>(results[i]->data(0)) + size_t(y) * results[i]->rowBytes(0),
                    size_t(view.width) * 4);
            offset += size_t(view.width) * view.height * 4;
        }
        path_cache.finish(std::move(cached), packed.data(), int(area * 4));
    }
    offset = 0;
    for (int i = 0; i < count; ++i) {
        auto const& view = regions[i];
        for (int y = 0; y < view.height; ++y)
            std::memcpy(view.pixels + size_t(y) * view.pitch,
                packed.data() + offset + size_t(y) * view.width * 4, size_t(view.width) * 4);
        offset += size_t(view.width) * view.height * 4;
    }
    return 1;
}

// An SVG image is one recording. Resolve multisample coverage after its last
// path, so adjacent fills and non-scaling strokes share the same samples.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_path_batch_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphitePath const* paths, int count)
{
    if (!pixels || !paths || count <= 0 || count > 65536 || width <= 0 || height <= 0
        || pitch <= 0 || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4)
        return 0;
    for (int index = 0; index < count; ++index)
        if (!paths[index].segments || paths[index].segment_count <= 0) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    for (int index = 0; index < count; ++index)
        if (!draw_path_on_canvas(canvas, paths + index)) return 0;
    return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
}

// Keep the SVG's user-space transform separate from its embedding transform.
// A non-scaling stroke cancels the former while retaining the latter, including
// device scale and the raster tile's translation.
static int draw_svg_image_pixels(uint8_t* pixels, int width, int height,
    int pitch, int flags, VoxGraphitePath const* paths, int count,
    float const* parent_values, float const* viewport, float const* rounded_clip,
    VoxGraphitePixelRegion const* region)
{
    if (!pixels || !paths || !parent_values || !viewport || count <= 0 || count > 65536
        || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(region ? region->width : width) * 4) return 0;
    for (int index = 0; index < count; ++index)
        if (!paths[index].segments || paths[index].segment_count <= 0) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    FullDrawRecorder recorder(gpu);
    if (!recorder.get()) return 0;
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = vox_shared_surface(recorder.get(), info);
    if (!surface) return 0;
    if (region) {
        surface->getCanvas()->clear(SK_ColorTRANSPARENT);
        if (flags & VOX_GRAPHITE_SVG_BACKDROP)
            vox_shared_write(gpu, surface, SkPixmap(info.makeWH(region->width, region->height), pixels, pitch), region->x, region->y);
    } else if (flags & VOX_GRAPHITE_SVG_BACKDROP) vox_shared_write(gpu, surface, SkPixmap(info, pixels, pitch), 0, 0);
    else surface->getCanvas()->clear(SK_ColorTRANSPARENT);
    SkMatrix matrix;
    matrix.set9(parent_values);
    SkM44 parent(matrix);
    auto* canvas = surface->getCanvas();
    // Analytic primitives and paths inside the SVG's saveLayer do not select
    // MSAA for the parent pass. Use the owning raster tile's mode instead.
    if (flags & VOX_GRAPHITE_SVG_FORCE_MSAA) force_msaa_render_pass(canvas, width, height);
    canvas->setMatrix(parent);
    canvas->clipRect(SkRect::MakeXYWH(viewport[0], viewport[1], viewport[2], viewport[3]), true);
    if (rounded_clip) {
        canvas->clipRRect(rounded_rect(rounded_clip), SkClipOp::kIntersect, true);
        canvas->saveLayer(nullptr, nullptr);
    }
    for (int index = 0; index < count; ++index)
        if (!draw_path_on_canvas(canvas, paths + index, &parent)) return 0;
    if (rounded_clip) canvas->restore();
    if (!region) return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    auto recording = recorder.get()->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    vox_shared_readback(gpu, surface.get(), info.makeWH(region->width, region->height),
        SkIRect::MakeXYWH(region->x, region->y, region->width, region->height),
        SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
        [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
        }, &result);
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result) return 0;
    for (int row = 0; row < region->height; ++row)
        std::memcpy(pixels + size_t(row) * pitch,
            static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0), size_t(region->width) * 4);
    return 1;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_svg_image_pixels(uint8_t* pixels, int width, int height,
    int pitch, int flags, VoxGraphitePath const* paths, int count,
    float const* parent, float const* viewport, float const* rounded_clip)
{
    return draw_svg_image_pixels(pixels, width, height, pitch, flags, paths, count, parent, viewport, rounded_clip, nullptr);
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_svg_image_region_pixels(VoxGraphitePixelRegion const* region,
    int width, int height, int flags, VoxGraphitePath const* paths, int count,
    float const* parent, float const* viewport, float const* rounded_clip)
{
    if (!region || !region->pixels || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || region->x < 0 || region->y < 0 || region->width <= 0 || region->height <= 0
        || region->width > width || region->height > height || region->pitch <= 0
        || region->x > width - region->width || region->y > height - region->height
        || size_t(region->pitch) < size_t(region->width) * 4) return 0;
    return draw_svg_image_pixels(region->pixels, width, height, region->pitch, flags,
        paths, count, parent, viewport, rounded_clip, region);
}

#include "native_graphite_svg_pattern.h"
