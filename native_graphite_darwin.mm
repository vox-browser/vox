#import <Metal/Metal.h>
#include "native_graphite_bridge.h"
#include "native_graphite_raster_cache.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkBlurTypes.h"
#include "include/core/SkColorSpace.h"
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

namespace {
std::mutex gpu_mutex;
VoxGraphiteRasterCache image_cache;
VoxGraphiteRasterCache shape_cache(8 * 1024 * 1024);
std::unique_ptr<skgpu::graphite::Context> gpu_context;
bool gpu_context_attempted = false;
skgpu::graphite::Context* context()
{
    if (!gpu_context_attempted) {
        gpu_context_attempted = true;
        gpu_context = [] {
        skgpu::graphite::MtlBackendContext backend;
        backend.fDevice.reset((CFTypeRef)MTLCreateSystemDefaultDevice());
        if (!backend.fDevice) return std::unique_ptr<skgpu::graphite::Context>();
        backend.fQueue.reset((CFTypeRef)[(id<MTLDevice>)backend.fDevice.get() newCommandQueue]);
        return skgpu::graphite::ContextFactory::MakeMetal(backend, {});
        }();
    }
    return gpu_context.get();
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
void vox_graphite_release_unused_graphics_memory()
{
    if (!pthread_main_np()) return;
    std::lock_guard lock(gpu_mutex);
    image_cache.clear();
    shape_cache.clear();
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
    gpu_context_attempted = false;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shadow_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteShadow const* shadow)
{
    if (!pixels || !shadow || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
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
    SkMatrix matrix;
    matrix.set9(shadow->matrix);
    canvas->setMatrix(matrix);
    canvas->clipRRect(rounded_rect(shadow->content), SkClipOp::kDifference, true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(shadow->alpha, shadow->red, shadow->green, shadow->blue));
    paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, std::max(shadow->blur, 0.0f) / 2.0f));
    canvas->drawRRect(rounded_rect(shadow->shadow), paint);
    return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
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

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_image_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteImage const* image)
{
    if (!pixels || !image || !image->pixels || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4
        || image->width <= 0 || image->height <= 0 || image->pitch <= 0
        || !(image->source[2] > 0) || !(image->source[3] > 0)
        || !(image->destination[2] > 0) || !(image->destination[3] > 0)) return 0;
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
    sk_sp<SkImage> texture;
    float source_scale_x = 1.0f, source_scale_y = 1.0f;
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
    SkImage::RequiredProperties properties{.fMipmapped = needs_mips};
    if (image->flags & 4) {
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
                        SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest))) return 0;
                planes[index] = scaled;
            }
            source_scale_x = static_cast<float>(upload_width) / image->width;
            source_scale_y = static_cast<float>(upload_height) / image->height;
        }
        SkYUVAInfo yuva(SkISize::Make(upload_width, upload_height),
            SkYUVAInfo::PlaneConfig::kY_U_V,
            resized || full_chroma ? SkYUVAInfo::Subsampling::k444 : SkYUVAInfo::Subsampling::k420,
            // JPEG planes use the full BT.601 range; WebP planes are limited.
            (image->flags & 8) ? kJPEG_Full_SkYUVColorSpace : kRec601_SkYUVColorSpace);
        auto pixmaps = SkYUVAPixmaps::FromExternalPixmaps(yuva, planes);
        texture = SkImages::TextureFromYUVAPixmaps(recorder.get(), pixmaps, properties, false,
            SkColorSpace::MakeSRGB());
    } else {
        if (static_cast<size_t>(image->pitch) < static_cast<size_t>(image->width) * 4) return 0;
        auto src_info = SkImageInfo::Make(image->width, image->height,
            kRGBA_8888_SkColorType, (image->flags & 1) ? kPremul_SkAlphaType : kUnpremul_SkAlphaType,
            vox_image_color_space(image));
        SkPixmap pixmap(src_info, image->pixels, image->pitch);
        std::vector<uint8_t> premultiplied;
        if (!(image->flags & 1)) {
            premultiplied.resize(static_cast<size_t>(image->pitch) * image->height);
            src_info = src_info.makeAlphaType(kPremul_SkAlphaType);
            if (!pixmap.readPixels(src_info, premultiplied.data(), image->pitch)) return 0;
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
                    SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kNearest))) return 0;
            pixmap = scaled;
            source_scale_x = static_cast<float>(upload_width) / image->width;
            source_scale_y = static_cast<float>(upload_height) / image->height;
        }
        auto raster = SkImages::RasterFromPixmapCopy(pixmap);
        texture = SkImages::TextureFromImage(recorder.get(), raster, properties);
        // Chromium's GPU image cache converts a tagged upload into an 8-bit
        // sRGB texture before drawing it, so premultiplied texels are quantized
        // before they are filtered and blended.
        if (texture && image->has_color_profile)
            texture = texture->makeColorSpace(recorder.get(), SkColorSpace::MakeSRGB(), properties);
    }
    if (!texture) return 0;
    SkMatrix matrix;
    matrix.set9(image->matrix);
    canvas->setMatrix(matrix);
    auto rect = [](float const* r) { return SkRect::MakeXYWH(r[0], r[1], r[2], r[3]); };
    canvas->clipRRect(rounded_rect(image->clip), true);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setAlphaf(std::clamp(image->opacity, 0.0f, 1.0f));
    auto sampling = SkSamplingOptions(image->nearest ? SkFilterMode::kNearest : SkFilterMode::kLinear,
        needs_mips ? SkMipmapMode::kLinear : SkMipmapMode::kNone);
    auto source_rect = SkRect::MakeXYWH(image->source[0] * source_scale_x,
        image->source[1] * source_scale_y, image->source[2] * source_scale_x,
        image->source[3] * source_scale_y);
    canvas->drawImageRect(texture, source_rect, rect(image->destination), sampling,
        &paint, whole_source && !image->nearest ? SkCanvas::kFast_SrcRectConstraint
                                               : SkCanvas::kStrict_SrcRectConstraint);
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) image_cache.finish(std::move(cached), pixels, pitch);
    return result;
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shape_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteShape const* shape)
{
    if (!pixels || !shape || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
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
    if (shape->force_msaa) {
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
    SkMatrix matrix;
    matrix.set9(shape->matrix);
    canvas->setMatrix(matrix);
    if (shape->has_underlay) {
        SkPaint underlay;
        underlay.setAntiAlias(true);
        underlay.setColor(SkColorSetARGB(shape->underlay_rgba[3], shape->underlay_rgba[0],
            shape->underlay_rgba[1], shape->underlay_rgba[2]));
        canvas->drawRRect(rounded_rect(shape->underlay_rect), underlay);
    }
    for (int index = 0; shape->clip_outs && index < shape->clip_out_count; ++index) {
        float const* clip = shape->clip_outs + index * 4;
        canvas->clipRect(SkRect::MakeLTRB(clip[0], clip[1], clip[2], clip[3]),
            SkClipOp::kDifference, false);
    }
    SkPaint paint;
    paint.setAntiAlias(shape->anti_alias != 0);
    paint.setColor(SkColorSetARGB(shape->alpha, shape->red, shape->green, shape->blue));
    if (!shape->fill) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(std::max(0.0f, shape->thickness));
    }
    canvas->drawRRect(rounded_rect(shape->rect), paint);
    int result = read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
    if (result) shape_cache.finish(std::move(cached), pixels, pitch);
    return result;
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
    matrix.set9(path->matrix);
    canvas->setMatrix(matrix);
    auto geometry = vox_path_from_serialized_segments(path->segments, path->segment_count);
    geometry.setFillType(path->even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColorSetARGB(path->alpha, path->red, path->green, path->blue));
    std::vector<SkColor4f> colors;
    std::vector<float> positions;
    if (path->gradient) {
        if (!path->stops || path->stop_count < 2) return 0;
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
        if (!shader) return 0;
        paint.setShader(std::move(shader));
        // Blink dithers gradient paints.
        paint.setDither(true);
        paint.setAlphaf(std::clamp(path->opacity, 0.0f, 1.0f));
        if (path->linear_color_space)
            paint.setColorFilter(SkColorFilters::LinearToSRGBGamma());
    }
    if (path->stroke) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(path->stroke_width);
        paint.setStrokeCap(path->line_cap == 1 ? SkPaint::kRound_Cap
            : path->line_cap == 2 ? SkPaint::kSquare_Cap : SkPaint::kButt_Cap);
        paint.setStrokeJoin(path->line_join == 1 ? SkPaint::kRound_Join
            : path->line_join == 2 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
        paint.setStrokeMiter(std::max(path->miter_limit, 1.0f));
    }
    canvas->drawPath(geometry, paint);
    return read_pixels(gpu, recorder.get(), surface.get(), info, pixels, pitch);
}
