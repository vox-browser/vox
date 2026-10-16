#import <Metal/Metal.h>
#include "native_graphite_bridge.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkBlurTypes.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMaskFilter.h"
#include "include/core/SkPaint.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSurface.h"
#include "include/gpu/graphite/Context.h"
#include "include/gpu/graphite/ContextOptions.h"
#include "include/gpu/graphite/Recorder.h"
#include "include/gpu/graphite/Recording.h"
#include "include/gpu/graphite/Surface.h"
#include "include/gpu/graphite/mtl/MtlBackendContext.h"
#include <algorithm>
#include <cstring>
#include <memory>
#include <mutex>

namespace {
skgpu::graphite::Context* context()
{
    static auto instance = [] {
        skgpu::graphite::MtlBackendContext backend;
        backend.fDevice.reset((CFTypeRef)MTLCreateSystemDefaultDevice());
        if (!backend.fDevice) return std::unique_ptr<skgpu::graphite::Context>();
        backend.fQueue.reset((CFTypeRef)[(id<MTLDevice>)backend.fDevice.get() newCommandQueue]);
        return skgpu::graphite::ContextFactory::MakeMetal(backend, {});
    }();
    return instance.get();
}

SkRRect rounded_rect(float const* data)
{
    SkVector radii[4] {{data[4], data[5]}, {data[6], data[7]},
        {data[8], data[9]}, {data[10], data[11]}};
    SkRRect result;
    result.setRectRadii(SkRect::MakeXYWH(data[0], data[1], data[2], data[3]), radii);
    return result;
}
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_shadow_pixels(uint8_t* pixels, int width, int height,
    int pitch, int has_background, VoxGraphiteShadow const* shadow)
{
    if (!pixels || !shadow || width <= 0 || height <= 0 || pitch <= 0
        || static_cast<size_t>(pitch) < static_cast<size_t>(width) * 4) return 0;
    static std::mutex mutex;
    std::lock_guard lock(mutex);
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
    auto recording = recorder->snap();
    skgpu::graphite::InsertRecordingInfo insertion;
    insertion.fRecording = recording.get();
    if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return 0;
    std::unique_ptr<const SkImage::AsyncReadResult> result;
    gpu->asyncRescaleAndReadPixels(surface.get(), info, SkIRect::MakeWH(width, height),
        SkImage::RescaleGamma::kSrc, SkImage::RescaleMode::kNearest,
        [](void* target, std::unique_ptr<const SkImage::AsyncReadResult> data) {
            *static_cast<std::unique_ptr<const SkImage::AsyncReadResult>*>(target) = std::move(data);
        }, &result);
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result) return 0;
    for (int row = 0; row < height; ++row) {
        std::memcpy(pixels + static_cast<size_t>(row) * pitch,
            static_cast<uint8_t const*>(result->data(0)) + static_cast<size_t>(row) * result->rowBytes(0),
            static_cast<size_t>(width) * 4);
    }
    return 1;
}
