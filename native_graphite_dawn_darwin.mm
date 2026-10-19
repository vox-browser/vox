// Chromium's Dawn/Metal raster context. Serialized pictures and plain pixels
// cross the boundary; this library owns its revision-pinned Skia and Dawn ABI.
#include "native_graphite_bridge.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkImage.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPixmap.h"
#include "include/core/SkSerialProcs.h"
#include "include/core/SkSurface.h"
#include "include/gpu/graphite/Context.h"
#include "include/gpu/graphite/ContextOptions.h"
#include "include/gpu/graphite/Image.h"
#include "include/gpu/graphite/ImageProvider.h"
#include "include/gpu/graphite/Recorder.h"
#include "include/gpu/graphite/Recording.h"
#include "include/gpu/graphite/Surface.h"
#include "include/gpu/graphite/dawn/DawnBackendContext.h"
#include "dawn/native/DawnNative.h"
#include <cmath>
#include <cstdio>
#include <cstring>
#include <memory>
#include <mutex>
#include <pthread.h>
#include <vector>

namespace {
std::mutex gpu_mutex;
std::unique_ptr<skgpu::graphite::Context> gpu_context;
bool gpu_context_attempted = false;
skgpu::graphite::Context* context()
{
    if (!gpu_context_attempted) {
        gpu_context_attempted = true;
        gpu_context = [] {
        static std::unique_ptr<dawn::native::Instance> instance;
        if (!instance) {
            static const char* unsafe[] {"allow_unsafe_apis"};
            wgpu::DawnTogglesDescriptor toggles;
            toggles.enabledToggleCount = 1;
            toggles.enabledToggles = unsafe;
            wgpu::InstanceFeatureName timed = wgpu::InstanceFeatureName::TimedWaitAny;
            wgpu::InstanceDescriptor desc;
            desc.requiredFeatureCount = 1;
            desc.requiredFeatures = &timed;
            desc.nextInChain = &toggles;
            instance = std::make_unique<dawn::native::Instance>(&desc);
        }
        static const char* enabled[] {"disable_robustness", "skip_validation",
            "disable_lazy_clear_for_mapped_at_creation_buffer"};
        wgpu::DawnTogglesDescriptor toggles;
        toggles.enabledToggleCount = std::size(enabled);
        toggles.enabledToggles = enabled;
        wgpu::RequestAdapterOptions options;
        options.backendType = wgpu::BackendType::Metal;
        options.powerPreference = wgpu::PowerPreference::LowPower;
        options.nextInChain = &toggles;
        auto adapters = instance->EnumerateAdapters(&options);
        if (adapters.empty()) return std::unique_ptr<skgpu::graphite::Context>();
        wgpu::Adapter adapter(adapters.front().Get());
        std::vector<wgpu::FeatureName> features;
        constexpr wgpu::FeatureName desired[] {
            wgpu::FeatureName::DawnInternalUsages,
            wgpu::FeatureName::ImplicitDeviceSynchronization,
            wgpu::FeatureName::BGRA8UnormStorage,
            wgpu::FeatureName::BufferMapExtendedUsages,
            wgpu::FeatureName::DawnAllowUndefinedLoadStoreOp,
            wgpu::FeatureName::DawnMultiPlanarFormats,
            wgpu::FeatureName::DualSourceBlending,
            wgpu::FeatureName::FramebufferFetch,
            wgpu::FeatureName::MultiPlanarFormatExtendedUsages,
            wgpu::FeatureName::MultiPlanarFormatNv16,
            wgpu::FeatureName::MultiPlanarFormatNv24,
            wgpu::FeatureName::MultiPlanarFormatP010,
            wgpu::FeatureName::MultiPlanarFormatP210,
            wgpu::FeatureName::MultiPlanarFormatP410,
            wgpu::FeatureName::MultiPlanarFormatNv12a,
            wgpu::FeatureName::MultiPlanarRenderTargets,
            wgpu::FeatureName::Unorm16TextureFormats,
            wgpu::FeatureName::SharedTextureMemoryIOSurface,
            wgpu::FeatureName::SharedFenceMTLSharedEvent,
            wgpu::FeatureName::TransientAttachments,
            wgpu::FeatureName::DawnTexelCopyBufferRowAlignment,
            wgpu::FeatureName::FlexibleTextureViews,
        };
        for (auto feature : desired) if (adapter.HasFeature(feature)) features.push_back(feature);
        if (adapter.HasFeature(wgpu::FeatureName::MSAARenderToSingleSampled))
            features.push_back(wgpu::FeatureName::MSAARenderToSingleSampled);
        else if (adapter.HasFeature(wgpu::FeatureName::DawnLoadResolveTexture)) {
            features.push_back(wgpu::FeatureName::DawnLoadResolveTexture);
            if (adapter.HasFeature(wgpu::FeatureName::DawnPartialLoadResolveTexture))
                features.push_back(wgpu::FeatureName::DawnPartialLoadResolveTexture);
        }
        wgpu::Limits limits;
        adapter.GetLimits(&limits);
        wgpu::DeviceDescriptor desc;
        desc.requiredFeatures = features.data();
        desc.requiredFeatureCount = features.size();
        desc.requiredLimits = &limits;
        desc.nextInChain = &toggles;
        desc.SetUncapturedErrorCallback([](const wgpu::Device&, wgpu::ErrorType, wgpu::StringView message) {
            std::fprintf(stderr, "Dawn error: %.*s\n", int(message.length), message.data);
        });
        auto device = adapter.CreateDevice(&desc);
        if (!device) return std::unique_ptr<skgpu::graphite::Context>();
        skgpu::graphite::DawnBackendContext backend;
        backend.fInstance = wgpu::Instance(instance->Get());
        backend.fDevice = device;
        backend.fQueue = device.GetQueue();
        return skgpu::graphite::ContextFactory::MakeDawn(backend, {});
        }();
    }
    return gpu_context.get();
}

class PictureImageProvider final : public skgpu::graphite::ImageProvider {
    sk_sp<SkImage> findOrCreate(skgpu::graphite::Recorder* recorder, SkImage const* image,
        SkImage::RequiredProperties properties) override
    {
        return SkImages::TextureFromImage(recorder, image, properties);
    }
};

sk_sp<SkImage> decode_picture_image(void const* bytes, size_t size,
    std::optional<SkAlphaType>, void*)
{
    int dimensions[2];
    if (size < sizeof(dimensions)) return nullptr;
    std::memcpy(dimensions, bytes, sizeof(dimensions));
    int width = dimensions[0], height = dimensions[1];
    if (width <= 0 || height <= 0 || width > 16384 || height > 16384
        || size != sizeof(dimensions) + size_t(width) * height * 4) return nullptr;
    auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    return SkImages::RasterFromPixmapCopy(SkPixmap(info,
        static_cast<char const*>(bytes) + sizeof(dimensions), size_t(width) * 4));
}
}

extern "C" __attribute__((visibility("default")))
int vox_graphite_draw_picture_pixels(uint8_t* pixels, int width, int height,
    int pitch, void const* bytes, size_t size, float const* matrix)
{
    if (!pixels || !bytes || !matrix || !size || size > 64 * 1024 * 1024
        || width <= 0 || height <= 0 || width > 16384 || height > 16384
        || size_t(width) * height > 8 * 1024 * 1024 || pitch < width * 4)
        return 0;
    for (int index = 0; index < 9; ++index)
        if (!std::isfinite(matrix[index])) return 0;
    SkDeserialProcs procs;
    procs.fImageProc = decode_picture_image;
    procs.fAllowSkSL = false;
    auto picture = SkPicture::MakeFromData(bytes, size, &procs);
    if (!picture) return 0;
    std::lock_guard lock(gpu_mutex);
    auto* gpu = context();
    if (!gpu) return 0;
    skgpu::graphite::RecorderOptions options;
    options.fImageProvider = sk_make_sp<PictureImageProvider>();
    auto recorder = gpu->makeRecorder(options);
    auto info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::RenderTarget(recorder.get(), info);
    if (!surface) return 0;
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    SkMatrix transform;
    transform.set9(matrix);
    canvas->setMatrix(transform);
    canvas->drawPicture(picture);
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
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes)) || !result)
        return 0;
    for (int row = 0; row < height; ++row)
        std::memcpy(pixels + size_t(row) * pitch,
            static_cast<uint8_t const*>(result->data(0)) + size_t(row) * result->rowBytes(0),
            size_t(width) * 4);
    return 1;
}

extern "C" __attribute__((visibility("default")))
void vox_graphite_picture_release_unused_graphics_memory()
{
    if (!pthread_main_np()) return;
    std::lock_guard lock(gpu_mutex);
    if (gpu_context) gpu_context->freeGpuResources();
}
