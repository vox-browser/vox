#import <Metal/Metal.h>
#include "native_frame_metal_queue.h"
#include "native_graphite_bridge.h"
#include "native_graphite_raster_cache.h"
#include "native_graphite_image_upload_cache.h"
#include "native_graphite_solid_rect.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkBlurTypes.h"
#include "include/core/SkColorSpace.h"
#include "modules/skcms/skcms.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMaskFilter.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkShader.h"
#include "include/core/SkColorFilter.h"
#include "include/effects/SkGradient.h"
#include "include/core/SkRRect.h"
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
#include <cmath>
#include <cstring>
#include <memory>
#include <mutex>
#include <pthread.h>
#include <vector>
#include <chrono>

namespace {
std::mutex gpu_mutex;
// Shared sprite sources leave room for many small, distinct draw results.
VoxGraphiteRasterCache image_cache(32 * 1024 * 1024, 2048);
VoxGraphiteImageUploadCache<sk_sp<SkImage>> image_upload_cache;
VoxGraphiteRasterCache path_cache(8 * 1024 * 1024);
VoxGraphiteRasterCache shape_cache(16 * 1024 * 1024);
VoxGraphiteRasterCache shadow_cache(8 * 1024 * 1024, 128);
std::unique_ptr<skgpu::graphite::Context> gpu_context;
VoxFrameMetalQueue* gpu_frame_queue;
bool gpu_context_attempted = false;
std::chrono::steady_clock::time_point gpu_context_last_use;
skgpu::graphite::Context* context()
{
    gpu_context_last_use = std::chrono::steady_clock::now();
    if (!gpu_context_attempted) {
        gpu_context_attempted = true;
        gpu_context = [] {
        skgpu::graphite::MtlBackendContext backend;
        backend.fDevice.reset((CFTypeRef)MTLCreateSystemDefaultDevice());
        if (!backend.fDevice) return std::unique_ptr<skgpu::graphite::Context>();
        auto* queue = [[VoxFrameMetalQueue alloc] initWithDevice:(id<MTLDevice>)backend.fDevice.get()];
        backend.fQueue.reset((CFTypeRef)queue);
        skgpu::graphite::ContextOptions options;
        options.fGpuBudgetInBytes = 64 * 1024 * 1024;
        auto result = skgpu::graphite::ContextFactory::MakeMetal(backend, options);
        if (result) gpu_frame_queue = queue;
        return result;
        }();
    }
    return gpu_context.get();
}

// Chromium performs WebP ICC conversion while pixels are still straight,
// then premultiplies in the destination's encoded sRGB space.
extern "C" __attribute__((visibility("default")))
int vox_graphite_convert_icc_rgba(uint8_t* pixels, int count,
    uint8_t const* profile, int profile_size)
{
    if (!pixels || count <= 0 || !profile || profile_size <= 0) return 0;
    skcms_ICCProfile source;
    if (!skcms_Parse(profile, profile_size, &source)) return 0;
    // An sRGB tag does not require a decode-time transform in Chromium. Its
    // WebP decoder still selects MODE_rgbA, whose multiplication truncates.
    if (skcms_ApproximatelyEqualProfiles(&source, skcms_sRGB_profile())) {
        for (int i = 0; i < count; ++i)
            for (int channel = 0; channel < 3; ++channel)
                pixels[i * 4 + channel] = pixels[i * 4 + channel] * pixels[i * 4 + 3] / 255;
        return 1;
    }
    return skcms_Transform(pixels, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul,
        &source, pixels, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_PremulAsEncoded,
        skcms_sRGB_profile(), count);
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
    gpu->asyncRescaleAndReadPixels(surface, info, SkIRect::MakeWH(info.width(), info.height()),
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
    // All public draws synchronously return owned CPU pixels. Finish any work
    // remaining after an early return before detaching the underlying queue.
    gpu_context->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes));
    gpu_context->checkAsyncWorkCompletion();
    if ([gpu_frame_queue retireCompletedQueue])
        gpu_context_last_use = std::chrono::steady_clock::now();
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_release_idle_graphics_memory()
{
    if (!pthread_main_np()) return 0;
    std::lock_guard lock(gpu_mutex);
    if (!gpu_context) return 0;
    if (std::chrono::steady_clock::now() - gpu_context_last_use < std::chrono::seconds(2)) return -1;
    // CPU raster results remain reusable after the unused upload/context die.
    image_upload_cache.clear();
    gpu_context->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes));
    gpu_context->checkAsyncWorkCompletion();
    gpu_context.reset();
    gpu_frame_queue = nil;
    gpu_context_attempted = false;
    return 1;
}

extern "C" __attribute__((visibility("default")))
void vox_graphite_release_unused_graphics_memory()
{
    if (!pthread_main_np()) return;
    std::lock_guard lock(gpu_mutex);
    image_cache.clear();
    image_upload_cache.clear();
    shape_cache.clear();
    shadow_cache.clear();
    path_cache.clear();
    if (!gpu_context) return;
    // Draw wrappers already synchronously read their pixels. Submit/wait also
    // covers a previous early-return path before dropping unused cache refs.
    gpu_context->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes));
    gpu_context->checkAsyncWorkCompletion();
    // Only owned CPU pixels cross this backend's public boundary. All draw
    // wrappers have destroyed their recorders, surfaces and readbacks before
    // this idle call, so no external GPU resource depends on this Context.
    // Dropping cache entries alone leaves Metal's per-context driver storage
    // resident. Release the Context and queue; the next draw recreates them.
    gpu_context.reset();
    gpu_frame_queue = nil;
    gpu_context_attempted = false;
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
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    SkMatrix matrix;
    matrix.set9(shadow->matrix);
    canvas->setMatrix(matrix);
    canvas->clipRRect(rounded_rect(shadow->content), SkClipOp::kDifference, true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(shadow->alpha, shadow->red, shadow->green, shadow->blue));
    paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, std::max(shadow->blur, 0.0f) / 2.0f));
    canvas->drawRRect(rounded_rect(shadow->shadow), paint);
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) shadow_cache.finish(std::move(cached), pixels, pitch);
    return result;
}

// A PNG tagged by its gAMA and cHRM chunks keeps that color space until the
// GPU converts it to sRGB, as Chromium's raster does.
static sk_sp<SkColorSpace> vox_image_color_space(VoxGraphiteImage const* image)
{
    if (!image->has_color_profile) return SkColorSpace::MakeSRGB();
    float const* profile = image->color_profile;
    skcms_TransferFunction transfer { profile[0], 1, 0, 0, 0, 0, 0 };
    skcms_Matrix3x3 gamut = SkNamedGamut::kSRGB;
    if (profile[1] != 0 && !skcms_PrimariesToXYZD50(profile[2], profile[3], profile[4],
            profile[5], profile[6], profile[7], profile[8], profile[9], &gamut))
        return SkColorSpace::MakeSRGB();
    auto space = SkColorSpace::MakeRGB(transfer, gamut);
    return space ? space : SkColorSpace::MakeSRGB();
}

static void force_msaa_render_pass(SkCanvas* canvas, int width, int height)
{
    // Graphite multisamples a render pass that contains a path. A
    // transparent one changes no pixel.
    SkPaint noop;
    noop.setAntiAlias(true);
    noop.setShader(SkShaders::Color(SK_ColorTRANSPARENT));
    SkPathBuilder path;
    path.moveTo(0, 0);
    path.cubicTo(width, height * 0.1f, 0, height, width, height);
    path.lineTo(width * 0.5f, height * 0.2f);
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
    if (!image->nearest && whole_source) {
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
    // need them. Cropped draws retain strict source bounds below.
    bool needs_mips = !image->nearest && whole_source
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
static bool prepare_image_texture(skgpu::graphite::Recorder* recorder,
    VoxGraphiteImage const* image, PreparedImageDraw& prepared)
{
    int upload_width = prepared.upload_width, upload_height = prepared.upload_height;
    SkImage::RequiredProperties properties{.fMipmapped = prepared.needs_mips};
    auto content_image = *image;
    content_image.flags &= ~VOX_GRAPHITE_IMAGE_FORCE_MSAA;
    auto upload = image_upload_cache.prepare(content_image, upload_width, upload_height, prepared.needs_mips);
    sk_sp<SkImage> texture = upload.texture;
    if (!texture && (image->flags & 4)) {
        // Flag 16 marks full-resolution 4:4:4 chroma planes.
        bool full_chroma = image->flags & 16;
        int uv_width = full_chroma ? image->width : (image->width + 1) / 2;
        int uv_height = full_chroma ? image->height : (image->height + 1) / 2;
        size_t y_size = static_cast<size_t>(image->width) * image->height;
        size_t uv_size = static_cast<size_t>(uv_width) * uv_height;
        SkPixmap planes[4] {
            SkPixmap(SkImageInfo::Make(image->width, image->height, kGray_8_SkColorType,
                kOpaque_SkAlphaType), image->pixels, image->width),
            SkPixmap(SkImageInfo::Make(uv_width, uv_height, kGray_8_SkColorType,
                kOpaque_SkAlphaType), image->pixels + y_size, uv_width),
            SkPixmap(SkImageInfo::Make(uv_width, uv_height, kGray_8_SkColorType,
                kOpaque_SkAlphaType), image->pixels + y_size + uv_size, uv_width), {}
        };
        bool resized = upload_width != image->width || upload_height != image->height;
        std::vector<uint8_t> scaled_planes;
        if (resized) {
            size_t plane_size = static_cast<size_t>(upload_width) * upload_height;
            scaled_planes.resize(plane_size * 3);
            // Chromium's GPU decode cache scales each decoded plane on the CPU
            // and promotes the result to 4:4:4 before uploading it. Scaling the
            // original 4:2:0 textures on the GPU produces different texels.
            for (int index = 0; index < 3; ++index) {
                SkPixmap scaled(SkImageInfo::Make(upload_width, upload_height,
                    kGray_8_SkColorType, kOpaque_SkAlphaType),
                    scaled_planes.data() + plane_size * index, upload_width);
                if (!planes[index].scalePixels(scaled,
                        SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest))) return false;
                planes[index] = scaled;
            }
            prepared.source_scale_x = static_cast<float>(upload_width) / image->width;
            prepared.source_scale_y = static_cast<float>(upload_height) / image->height;
        }
        SkYUVAInfo yuva(SkISize::Make(upload_width, upload_height),
            SkYUVAInfo::PlaneConfig::kY_U_V,
            resized || full_chroma ? SkYUVAInfo::Subsampling::k444 : SkYUVAInfo::Subsampling::k420,
            // JPEG planes use the full BT.601 range; WebP planes are limited.
            (image->flags & 8) ? kJPEG_Full_SkYUVColorSpace : kRec601_SkYUVColorSpace);
        auto pixmaps = SkYUVAPixmaps::FromExternalPixmaps(yuva, planes);
        texture = SkImages::TextureFromYUVAPixmaps(recorder, pixmaps, properties, false,
            SkColorSpace::MakeSRGB());
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
        texture = SkImages::TextureFromImage(recorder, raster, properties);
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
    // An image already covers its destination rectangle. An identical square
    // clip is redundant, and changes Graphite's image shader interpolation.
    // Retain actual cropping and rounded corners.
    bool clips_destination = std::memcmp(image->clip, image->destination,
        sizeof(image->destination)) != 0
        || std::any_of(image->clip + 4, image->clip + 12,
            [](float radius) { return radius != 0; });
    if (clips_destination) canvas->clipRRect(rounded_rect(image->clip), true);
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
    if (whole_source) {
        auto natural = rect(image->source);
        canvas->concat(SkMatrix::RectToRect(natural, rect(image->destination)));
        canvas->drawImageRect(texture, source_rect, natural, sampling, &paint,
            !image->nearest ? SkCanvas::kFast_SrcRectConstraint : SkCanvas::kStrict_SrcRectConstraint);
    } else {
        canvas->drawImageRect(texture, source_rect, rect(image->destination), sampling,
            &paint, SkCanvas::kStrict_SrcRectConstraint);
    }
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
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
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
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
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
    if (shape.has_underlay) {
        SkPaint underlay;
        underlay.setAntiAlias(true);
        underlay.setColor(SkColorSetARGB(shape.underlay_rgba[3], shape.underlay_rgba[0],
            shape.underlay_rgba[1], shape.underlay_rgba[2]));
        canvas->drawRRect(rounded_rect(shape.underlay_rect), underlay);
    }
    for (int index = 0; shape.clip_outs && index < shape.clip_out_count; ++index) {
        float const* clip = shape.clip_outs + index * 4;
        canvas->clipRect(SkRect::MakeLTRB(clip[0], clip[1], clip[2], clip[3]),
            SkClipOp::kDifference, false);
    }
    SkPaint paint;
    paint.setAntiAlias(shape.anti_alias != 0);
    if (shape.has_float_color)
        paint.setColor4f({shape.float_color[0], shape.float_color[1], shape.float_color[2], shape.float_color[3]});
    else
        paint.setColor(SkColorSetARGB(shape.alpha, shape.red, shape.green, shape.blue));
    if (!shape.fill) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(std::max(0.0f, shape.thickness));
    }
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
    if (shape.has_underlay || shape.clip_out_count || (shape.fill && shape.alpha != 255)
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
            auto recorder = gpu->makeRecorder();
            auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
                kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
            auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
            if (!surface) return false;
            auto* canvas = surface->getCanvas();
            canvas->clear(SK_ColorTRANSPARENT);
            if (has_background) for (auto const& patch : patches)
                surface->writePixels(SkPixmap(info.makeWH(patch.width, patch.height),
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
                gpu->asyncRescaleAndReadPixels(surface.get(), info.makeWH(patch.width, patch.height),
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
    std::lock_guard lock(gpu_mutex);
    auto cached = shape_cache.prepare(*shape, width, height, pitch, has_background != 0, pixels);
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    draw_shape_on_canvas(canvas, *shape, width, height);
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) shape_cache.finish(std::move(cached), pixels, pitch);
    return result;
}

static bool draw_path_on_canvas(SkCanvas* canvas, VoxGraphitePath const* path,
    SkM44 const* parent = nullptr)
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
        SkGradient gradient(SkGradient::Colors(SkSpan<const SkColor4f>(colors),
            SkSpan<const float>(positions), static_cast<SkTileMode>(path->tile_mode)), {});
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
    }
    canvas->drawPath(geometry, paint);
    return true;
}

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
    if (cached.hit) return 1;
    auto* gpu = context();
    if (!gpu) return 0;
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    if (!draw_path_on_canvas(canvas, path)) return 0;
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) path_cache.finish(std::move(cached), pixels, pitch);
    return result;
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
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
    else canvas->clear(SK_ColorTRANSPARENT);
    for (int index = 0; index < count; ++index)
        if (!draw_path_on_canvas(canvas, paths + index)) return 0;
    return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
}

// Keep the SVG's user-space transform separate from its embedding transform.
// A non-scaling stroke cancels the former while retaining the latter, including
// device scale and the raster tile's translation.
extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_svg_image_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphitePath const* paths, int count,
    float const* parent_values, float const* viewport)
{
    if (!pixels || !paths || !parent_values || !viewport || count <= 0 || count > 65536
        || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
    for (int index = 0; index < count; ++index)
        if (!paths[index].segments || paths[index].segment_count <= 0) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    auto recorder = gpu->makeRecorder();
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    if (has_background) surface->writePixels(SkPixmap(info, pixels, pitch), 0, 0);
    else surface->getCanvas()->clear(SK_ColorTRANSPARENT);
    SkMatrix matrix;
    matrix.set9(parent_values);
    SkM44 parent(matrix);
    auto* canvas = surface->getCanvas();
    canvas->setMatrix(parent);
    canvas->clipRect(SkRect::MakeXYWH(viewport[0], viewport[1], viewport[2], viewport[3]), true);
    for (int index = 0; index < count; ++index)
        if (!draw_path_on_canvas(canvas, paths + index, &parent)) return 0;
    return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
}
