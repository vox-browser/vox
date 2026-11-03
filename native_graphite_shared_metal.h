#ifndef VOX_NATIVE_GRAPHITE_SHARED_METAL_H
#define VOX_NATIVE_GRAPHITE_SHARED_METAL_H

#include "include/gpu/graphite/mtl/MtlGraphiteTypes_cpp.h"
#include "src/gpu/graphite/RecorderPriv.h"
#include "src/gpu/graphite/Surface_Graphite.h"
#include "src/gpu/graphite/mtl/MtlSharedContext.h"
#include "src/gpu/graphite/mtl/MtlTexture.h"

// These synchronous native targets export owned CPU pixels, never GPU image
// snapshots. Unified-memory Metal can copy their bytes through the CPU instead
// of starting a separate GPU transfer engine for every upload and readback.
static id<MTLDevice> vox_shared_metal_device(skgpu::graphite::Recorder* recorder)
{
    if (!recorder || recorder->backend() != skgpu::BackendApi::kMetal) return nil;
    auto* shared = static_cast<skgpu::graphite::MtlSharedContext*>(recorder->priv().resourceProvider()->sharedContext());
    id<MTLDevice> device = shared->device();
    return device.hasUnifiedMemory ? device : nil;
}

static sk_sp<SkSurface> vox_shared_surface(skgpu::graphite::Recorder* recorder,
    SkImageInfo const& info)
{ @autoreleasepool {
    id<MTLDevice> device = vox_shared_metal_device(recorder);
    if (!device || info.colorType() != kBGRA_8888_SkColorType
        || info.alphaType() != kPremul_SkAlphaType || info.isEmpty()
        || info.width() > recorder->priv().caps()->maxTextureSize()
        || info.height() > recorder->priv().caps()->maxTextureSize())
        return SkSurfaces::RenderTarget(recorder, info);
    auto* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
        width:info.width() height:info.height() mipmapped:NO];
    desc.storageMode = MTLStorageModeShared;
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    id<MTLTexture> texture = [device newTextureWithDescriptor:desc];
    if (!texture) return SkSurfaces::RenderTarget(recorder, info);
    auto backend = skgpu::graphite::BackendTextures::MakeMetal(info.dimensions(), (CFTypeRef)texture);
    auto surface = SkSurfaces::WrapBackendTexture(recorder, backend, info.refColorSpace(), nullptr);
    [texture release]; // The wrapped Skia texture owns its own reference.
    return surface ? std::move(surface) : SkSurfaces::RenderTarget(recorder, info);
} }

static id<MTLTexture> vox_shared_metal_texture(SkSurface* surface)
{
    if (!surface || !vox_shared_metal_device(surface->recorder())) return nil;
    auto* target = static_cast<skgpu::graphite::Surface*>(surface);
    auto* proxy = target->target().proxy();
    auto* resource = proxy && proxy->isInstantiated() ? proxy->texture() : nullptr;
    id<MTLTexture> texture = resource
        ? static_cast<skgpu::graphite::MtlTexture*>(resource)->mtlTexture() : nil;
    return texture.storageMode == MTLStorageModeShared
        && texture.pixelFormat == MTLPixelFormatBGRA8Unorm ? texture : nil;
}

static bool vox_shared_read_compatible(SkSurface* surface, SkImageInfo const& info,
    SkIRect rect, SkImage::RescaleGamma gamma, SkImage::RescaleMode mode)
{
    return surface && !info.isEmpty() && !rect.isEmpty()
        && SkIRect::MakeWH(surface->width(), surface->height()).contains(rect)
        && rect.size() == info.dimensions() && info.colorType() == kBGRA_8888_SkColorType
        && info.alphaType() == surface->imageInfo().alphaType()
        && SkColorSpace::Equals(info.colorSpace(), surface->imageInfo().colorSpace())
        && info.computeMinByteSize() != SIZE_MAX
        && gamma == SkImage::RescaleGamma::kSrc && mode == SkImage::RescaleMode::kNearest;
}

class VoxSharedReadResult final : public SkImage::AsyncReadResult {
    std::vector<uint8_t> pixels_;
    size_t pitch_;
public:
    explicit VoxSharedReadResult(SkImageInfo const& info)
        : pixels_(info.computeMinByteSize()), pitch_(info.minRowBytes()) {}
    int count() const override { return 1; }
    const void* data(int) const override { return pixels_.data(); }
    size_t rowBytes(int) const override { return pitch_; }
    void* writable() { return pixels_.data(); }
};

static void vox_shared_readback(skgpu::graphite::Context* gpu, SkSurface* surface,
    SkImageInfo const& info, SkIRect rect, SkImage::RescaleGamma gamma,
    SkImage::RescaleMode mode, SkImage::ReadPixelsCallback callback, void* context)
{ @autoreleasepool {
    id<MTLTexture> texture = vox_shared_metal_texture(surface);
    if (!texture || !vox_shared_read_compatible(surface, info, rect, gamma, mode)) {
        gpu->asyncRescaleAndReadPixels(surface, info, rect, gamma, mode, callback, context);
        return;
    }
    // Callers insert their snapped recording before requesting readback. A CPU
    // read must wait for every queued writer, including earlier target reuse.
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) {
        callback(context, nullptr);
        return;
    }
    auto result = std::make_unique<VoxSharedReadResult>(info);
    [texture getBytes:result->writable() bytesPerRow:result->rowBytes(0)
        fromRegion:MTLRegionMake2D(rect.x(), rect.y(), rect.width(), rect.height()) mipmapLevel:0];
    callback(context, std::move(result));
} }

static SkSurface* vox_surface_ptr(SkSurface* surface) { return surface; }
static SkSurface* vox_surface_ptr(sk_sp<SkSurface> const& surface) { return surface.get(); }
template<typename SurfacePtr>
static void vox_shared_write(skgpu::graphite::Context* gpu, SurfacePtr const& value,
    SkPixmap const& pixels, int x, int y)
{ @autoreleasepool {
    auto* surface = vox_surface_ptr(value);
    id<MTLTexture> texture = vox_shared_metal_texture(surface);
    if (!texture || pixels.colorType() != kBGRA_8888_SkColorType
        || pixels.alphaType() != kPremul_SkAlphaType || !pixels.addr() || pixels.info().isEmpty()
        || !pixels.info().validRowBytes(pixels.rowBytes())
        || !SkColorSpace::Equals(pixels.colorSpace(), surface->imageInfo().colorSpace())
        || x < 0 || y < 0 || x > surface->width() || y > surface->height()
        || pixels.width() > surface->width() - x || pixels.height() > surface->height() - y) {
        surface->writePixels(pixels, x, y);
        return;
    }
    // A clear or earlier draw may still be in the Recorder, not the Context.
    auto recording = surface->recorder()->snap();
    if (recording) {
        skgpu::graphite::InsertRecordingInfo insertion;
        insertion.fRecording = recording.get();
        if (gpu->insertRecording(insertion) != skgpu::graphite::InsertStatus::kSuccess) return;
    }
    if (!gpu->submit(skgpu::graphite::SubmitInfo(skgpu::graphite::SyncToCpu::kYes))) return;
    [texture replaceRegion:MTLRegionMake2D(x, y, pixels.width(), pixels.height()) mipmapLevel:0
        withBytes:pixels.addr() bytesPerRow:pixels.rowBytes()];
} }

static sk_sp<SkImage> vox_shared_image(skgpu::graphite::Recorder* recorder,
    sk_sp<SkImage> const& image, SkImage::RequiredProperties properties)
{ @autoreleasepool {
    SkPixmap pixels;
    id<MTLDevice> device = vox_shared_metal_device(recorder);
    if (device && !properties.fMipmapped && image && image->peekPixels(&pixels)
        && (pixels.alphaType() == kPremul_SkAlphaType || pixels.alphaType() == kOpaque_SkAlphaType)
        && (pixels.colorType() == kBGRA_8888_SkColorType || pixels.colorType() == kRGBA_8888_SkColorType)
        && !pixels.info().isEmpty() && pixels.addr() && pixels.info().validRowBytes(pixels.rowBytes())
        && pixels.width() <= recorder->priv().caps()->maxTextureSize()
        && pixels.height() <= recorder->priv().caps()->maxTextureSize()) {
        auto* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:
            pixels.colorType() == kBGRA_8888_SkColorType ? MTLPixelFormatBGRA8Unorm : MTLPixelFormatRGBA8Unorm
            width:pixels.width() height:pixels.height() mipmapped:NO];
        desc.storageMode = MTLStorageModeShared;
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
        id<MTLTexture> texture = [device newTextureWithDescriptor:desc];
        if (texture) {
            [texture replaceRegion:MTLRegionMake2D(0, 0, pixels.width(), pixels.height()) mipmapLevel:0
                withBytes:pixels.addr() bytesPerRow:pixels.rowBytes()];
            auto backend = skgpu::graphite::BackendTextures::MakeMetal(pixels.dimensions(), (CFTypeRef)texture);
            auto wrapped = SkImages::WrapTexture(recorder, backend, pixels.alphaType(), pixels.info().refColorSpace());
            [texture release];
            if (wrapped) return wrapped;
        }
    }
    return SkImages::TextureFromImage(recorder, image, properties);
} }
#endif
