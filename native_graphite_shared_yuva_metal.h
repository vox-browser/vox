#pragma once

#include <array>

// YUV planes keep Skia's original conversion matrix and sampling. Only their
// immutable upload changes: unified-memory Metal can read the CPU's bytes
// without opening a GPU blit encoder for three small luminance textures.
static sk_sp<SkImage> vox_shared_yuva_image(skgpu::graphite::Recorder* recorder,
    SkYUVAPixmaps const& pixmaps, SkImage::RequiredProperties properties,
    sk_sp<SkColorSpace> color_space, bool generate_gpu_mips = false)
{ @autoreleasepool {
    auto fallback = [&] {
        return SkImages::TextureFromYUVAPixmaps(recorder, pixmaps, properties, false,
            color_space);
    };
    if (generate_gpu_mips && properties.fMipmapped && pixmaps.isValid()
        && pixmaps.yuvaInfo().planeConfig() == SkYUVAInfo::PlaneConfig::kY_U_V
        && pixmaps.numPlanes() == 3) {
        // Chromium upgrades the separate uploaded planes on the GPU. Fresh
        // CPU mipmaps filter and round differently. Recreate the validated
        // base uploads, then retain YUVA conversion until final sampling.
        std::array<sk_sp<SkImage>, 3> planes;
        for (int index = 0; index < 3; ++index) {
            auto raster = SkImages::RasterFromPixmapCopy(pixmaps.plane(index));
            auto base = SkImages::TextureFromImage(recorder, raster, {false});
            if (!base) return nullptr;
            planes[index] = SkImages::TextureFromImage(recorder, base, properties);
            if (!planes[index]) return nullptr;
        }
        return SkImages::TextureFromYUVAImages(recorder, pixmaps.yuvaInfo(),
            SkSpan<const sk_sp<SkImage>>(planes.data(), planes.size()), color_space);
    }
    id<MTLDevice> device = vox_shared_metal_device(recorder);
    if (!device || properties.fMipmapped || !pixmaps.isValid()
        || pixmaps.yuvaInfo().planeConfig() != SkYUVAInfo::PlaneConfig::kY_U_V
        || pixmaps.numPlanes() != 3 || std::getenv("VOX_DISABLE_SHARED_YUVA_UPLOADS"))
        return fallback();
    for (int index = 0; index < 3; ++index) {
        auto const& plane = pixmaps.plane(index);
        if (plane.colorType() != kGray_8_SkColorType
            || plane.alphaType() != kOpaque_SkAlphaType || !plane.addr()
            || plane.info().isEmpty() || !plane.info().validRowBytes(plane.rowBytes())
            || plane.rowBytes() > SIZE_MAX / size_t(plane.height())
            || plane.width() > recorder->priv().caps()->maxTextureSize()
            || plane.height() > recorder->priv().caps()->maxTextureSize())
            return fallback();
    }
    std::array<sk_sp<SkImage>, 3> planes;
    for (int index = 0; index < 3; ++index) {
        auto const& plane = pixmaps.plane(index);
        auto* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
            width:plane.width() height:plane.height() mipmapped:NO];
        descriptor.storageMode = MTLStorageModeShared;
        descriptor.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
        if (!texture) return fallback();
        [texture replaceRegion:MTLRegionMake2D(0, 0, plane.width(), plane.height()) mipmapLevel:0
            withBytes:plane.addr() bytesPerRow:plane.rowBytes()];
        auto backend = skgpu::graphite::BackendTextures::MakeMetal(plane.dimensions(), (CFTypeRef)texture);
        // Opaque R8 is red data, not an alpha mask. The YUVA factory accepts
        // red-only plane images and retains their underlying texture proxies.
        planes[index] = SkImages::WrapTexture(recorder, backend, kOpaque_SkAlphaType, nullptr);
        [texture release];
        if (!planes[index]) return fallback();
    }
    auto image = SkImages::TextureFromYUVAImages(recorder, pixmaps.yuvaInfo(),
        SkSpan<const sk_sp<SkImage>>(planes.data(), planes.size()), color_space);
    if (!image) return fallback();
    if (std::getenv("VOX_SHARED_YUVA_DIAGNOSTICS"))
        std::fprintf(stderr, "VOX_SHARED_YUVA planes=3 width=%d height=%d\n",
            pixmaps.yuvaInfo().width(), pixmaps.yuvaInfo().height());
    return image;
} }
