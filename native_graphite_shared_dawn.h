#pragma once

#include <IOSurface/IOSurface.h>
#include <Metal/Metal.h>
#include "dawn/native/MetalBackend.h"
#include "include/gpu/graphite/BackendTexture.h"
#include "include/gpu/graphite/dawn/DawnGraphiteTypes.h"
#include "src/gpu/graphite/RecorderPriv.h"
#include "src/gpu/graphite/dawn/DawnSharedContext.h"

// Keep Dawn's rasterization, shader precision and font policy. Only immutable
// uploads and synchronous CPU readback use IOSurface's shared allocation.
class VoxDawnSharedPixels {
    IOSurfaceRef surface_ = nullptr;
    wgpu::Instance instance_;
    wgpu::Device device_;
    wgpu::SharedTextureMemory memory_;
    wgpu::Texture texture_;
    bool active_ = false;
public:
    ~VoxDawnSharedPixels() {
        if (active_) {
            wgpu::SharedTextureMemoryEndAccessState state;
            memory_.EndAccess(texture_, &state);
        }
        // Skia's release callback retires our imported allocation. Dawn bind
        // group caches may still retain views; dropping references alone would
        // keep their IOSurfaces alive until the entire context is destroyed.
        if (texture_) texture_.Destroy();
        if (surface_) CFRelease(surface_);
    }
    static std::shared_ptr<VoxDawnSharedPixels> Make(skgpu::graphite::Recorder* recorder,
        SkImageInfo const& info) { @autoreleasepool {
        if (!recorder || recorder->backend() != skgpu::BackendApi::kDawn
            || std::getenv("VOX_DISABLE_SHARED_DAWN_PIXELS") || info.isEmpty()
            || info.width() > recorder->priv().caps()->maxTextureSize()
            || info.height() > recorder->priv().caps()->maxTextureSize()
            || (info.colorType() != kBGRA_8888_SkColorType
                && info.colorType() != kRGBA_8888_SkColorType)
            || (info.alphaType() != kPremul_SkAlphaType && info.alphaType() != kOpaque_SkAlphaType))
            return nullptr;
        auto* shared = static_cast<skgpu::graphite::DawnSharedContext*>(
            recorder->priv().resourceProvider()->sharedContext());
        if (!shared->device().HasFeature(wgpu::FeatureName::SharedTextureMemoryIOSurface)
            || !shared->device().HasFeature(wgpu::FeatureName::SharedFenceMTLSharedEvent)
            || !dawn::native::metal::GetMTLDevice(shared->device().Get()).hasUnifiedMemory)
            return nullptr;
        auto owner = std::make_shared<VoxDawnSharedPixels>();
        owner->instance_ = shared->instance();
        owner->device_ = shared->device();
        bool bgra = info.colorType() == kBGRA_8888_SkColorType;
        NSDictionary* properties = @{
            (id)kIOSurfaceWidth: @(info.width()), (id)kIOSurfaceHeight: @(info.height()),
            (id)kIOSurfaceBytesPerElement: @4,
            (id)kIOSurfacePixelFormat: @(bgra ? uint32_t('BGRA') : uint32_t('RGBA')),
        };
        owner->surface_ = IOSurfaceCreate((CFDictionaryRef)properties);
        if (!owner->surface_) return nullptr;
        wgpu::SharedTextureMemoryIOSurfaceDescriptor io;
        io.ioSurface = owner->surface_;
        io.allowStorageBinding = false;
        wgpu::SharedTextureMemoryDescriptor descriptor;
        descriptor.nextInChain = &io;
        owner->memory_ = owner->device_.ImportSharedTextureMemory(&descriptor);
        wgpu::SharedTextureMemoryProperties imported;
        if (!owner->memory_ || owner->memory_.GetProperties(&imported) != wgpu::Status::Success
            || imported.size.width != unsigned(info.width())
            || imported.size.height != unsigned(info.height())) return nullptr;
        wgpu::TextureDescriptor texture;
        texture.size = {unsigned(info.width()), unsigned(info.height()), 1};
        texture.format = bgra ? wgpu::TextureFormat::BGRA8Unorm : wgpu::TextureFormat::RGBA8Unorm;
        texture.usage = wgpu::TextureUsage::TextureBinding | wgpu::TextureUsage::RenderAttachment
            | wgpu::TextureUsage::CopySrc | wgpu::TextureUsage::CopyDst;
        owner->texture_ = owner->memory_.CreateTexture(&texture);
        if (!owner->texture_) return nullptr;
        if (std::getenv("VOX_SHARED_DAWN_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_SHARED_DAWN width=%d height=%d\n", info.width(), info.height());
        return owner;
    } }
    bool begin(bool initialized) {
        wgpu::SharedTextureMemoryBeginAccessDescriptor descriptor;
        descriptor.initialized = initialized;
        active_ = memory_.BeginAccess(texture_, &descriptor) == wgpu::Status::Success;
        return active_;
    }
    bool resume_initialized() { return active_ || begin(true); }
    bool end_and_wait() {
        if (!active_) return false;
        wgpu::SharedTextureMemoryEndAccessState state;
        bool ended = memory_.EndAccess(texture_, &state) == wgpu::Status::Success;
        if (!ended) return false;
        active_ = false;
        // EndAccess can flush additional work. Wait on the queue after it, not
        // just on Skia's preceding submit, before acquiring CPU ownership.
        auto status = std::make_shared<wgpu::QueueWorkDoneStatus>(wgpu::QueueWorkDoneStatus::Error);
        auto future = device_.GetQueue().OnSubmittedWorkDone(wgpu::CallbackMode::WaitAnyOnly,
            [status](wgpu::QueueWorkDoneStatus result, wgpu::StringView) { *status = result; });
        wgpu::FutureWaitInfo wait {future};
        return instance_.WaitAny(1, &wait, UINT64_MAX) == wgpu::WaitStatus::Success
            && *status == wgpu::QueueWorkDoneStatus::Success;
    }
    bool copy(SkIRect rect, void* bytes, size_t pitch, bool write) {
        if (active_ || !bytes || rect.isEmpty() || rect.x() < 0 || rect.y() < 0
            || size_t(rect.right()) > IOSurfaceGetWidth(surface_)
            || size_t(rect.bottom()) > IOSurfaceGetHeight(surface_)
            || pitch < size_t(rect.width()) * 4 || pitch > SIZE_MAX / size_t(rect.height()))
            return false;
        auto flags = write ? IOSurfaceLockOptions(0) : kIOSurfaceLockReadOnly;
        if (IOSurfaceLock(surface_, flags, nullptr) != kIOReturnSuccess) return false;
        auto* base = static_cast<uint8_t*>(IOSurfaceGetBaseAddress(surface_));
        size_t stride = IOSurfaceGetBytesPerRow(surface_);
        bool valid = base && stride >= size_t(rect.right()) * 4;
        if (valid) for (int y = 0; y < rect.height(); ++y) {
            auto* local = static_cast<uint8_t*>(bytes) + size_t(y) * pitch;
            auto* shared = base + size_t(rect.y() + y) * stride + size_t(rect.x()) * 4;
            std::memcpy(write ? shared : local, write ? local : shared, size_t(rect.width()) * 4);
        }
        return IOSurfaceUnlock(surface_, flags, nullptr) == kIOReturnSuccess && valid;
    }
    skgpu::graphite::BackendTexture backend() const {
        return skgpu::graphite::BackendTextures::MakeDawn(texture_.Get());
    }
    static void Release(void* value) {
        delete static_cast<std::shared_ptr<VoxDawnSharedPixels>*>(value);
    }
};

struct VoxDawnSharedSurface {
    std::shared_ptr<VoxDawnSharedPixels> pixels;
    sk_sp<SkSurface> surface;
    static VoxDawnSharedSurface Make(skgpu::graphite::Recorder* recorder, SkImageInfo const& info) {
        VoxDawnSharedSurface result;
        if (info.colorType() == kBGRA_8888_SkColorType && info.alphaType() == kPremul_SkAlphaType)
            result.pixels = VoxDawnSharedPixels::Make(recorder, info);
        if (result.pixels && result.pixels->begin(false)) {
            result.surface = SkSurfaces::WrapBackendTexture(recorder, result.pixels->backend(),
                info.refColorSpace(), nullptr, VoxDawnSharedPixels::Release,
                new std::shared_ptr<VoxDawnSharedPixels>(result.pixels));
        }
        if (!result.surface) {
            result.pixels.reset();
            result.surface = SkSurfaces::RenderTarget(recorder, info);
        }
        return result;
    }
    // The caller retires this surface immediately after the read. Leave GPU
    // access ended and copy into its owned destination, avoiding a second
    // full-size CPU allocation. Batch targets use read() to resume GPU access.
    bool read_final(skgpu::graphite::Context* gpu, SkIRect rect, void* out, size_t pitch) {
        if (!pixels || !out || rect.isEmpty() || pitch < size_t(rect.width()) * 4
            || pitch > SIZE_MAX / size_t(rect.height())) return false;
        if (!gpu || !gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))
            || !pixels->end_and_wait()) return false;
        return pixels->copy(rect, out, pitch, false);
    }
    bool read(skgpu::graphite::Context* gpu, SkIRect rect, std::vector<uint8_t>& out) {
        if (!pixels || !gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))
            || !pixels->end_and_wait()) return false;
        out.resize(size_t(rect.width()) * rect.height() * 4);
        bool copied = pixels->copy(rect, out.data(), size_t(rect.width()) * 4, false);
        return pixels->begin(true) && copied;
    }
    bool write(skgpu::graphite::Context* gpu, SkPixmap const& source, int x, int y) {
        // The target's clear can still be in the recorder. Publish it before
        // CPU backdrop bytes so it cannot later overwrite those bytes.
        auto recording = surface->recorder()->snap();
        if (recording) {
            skgpu::graphite::InsertRecordingInfo insertion;
            insertion.fRecording = recording.get();
            if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return false;
        }
        if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))
            || !pixels->end_and_wait()) return false;
        bool copied = pixels->copy(SkIRect::MakeXYWH(x, y, source.width(), source.height()),
            const_cast<void*>(source.addr()), source.rowBytes(), true);
        return pixels->begin(true) && copied;
    }
};

static sk_sp<SkImage> vox_dawn_shared_image(skgpu::graphite::Recorder* recorder,
    SkImage const* image, SkImage::RequiredProperties properties)
{
    SkPixmap source;
    if (image && !properties.fMipmapped && image->peekPixels(&source)
        && source.addr() && source.info().validRowBytes(source.rowBytes())) {
        auto owner = VoxDawnSharedPixels::Make(recorder, source.info());
        if (owner && owner->copy(SkIRect::MakeSize(source.dimensions()),
            const_cast<void*>(source.addr()), source.rowBytes(), true) && owner->begin(true)) {
            auto wrapped = SkImages::WrapTexture(recorder, owner->backend(), source.alphaType(),
                source.info().refColorSpace(), VoxDawnSharedPixels::Release,
                new std::shared_ptr<VoxDawnSharedPixels>(owner));
            if (wrapped) return wrapped;
        }
    }
    return SkImages::TextureFromImage(recorder, image, properties);
}
