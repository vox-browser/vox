#pragma once

#include "native_skia_image_color_space.h"
#include "native_shared_picture_pixels.h"
#include <dlfcn.h>
#include "include/core/SkData.h"
#include "include/core/SkImage.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkPixmap.h"
#include <cmath>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <cstdlib>

// Pictures cross two independently linked Skia revisions. Keep source pixels
// and numerical color-space values in the payload. The receiving GPU converts
// the decoded upload to sRGB before filtering, retaining GPU rounding.
// Ordinary sRGB images retain the original two-integer payload.
static sk_sp<SkData> vox_encode_picture_image(SkImage* image)
{
    if (!image || image->width() <= 0 || image->height() <= 0
        || image->width() > 16384 || image->height() > 16384) return nullptr;
    auto space = image->refColorSpace();
    float profile[VOX_IMAGE_COLOR_PROFILE_VALUES] {};
    bool tagged = space && !space->isSRGB() && vox_store_image_color_space(space.get(), profile);
    int32_t dimensions[] {tagged ? -1 : image->width(),
        tagged ? image->width() : image->height(), image->height()};
    size_t header = tagged ? sizeof(dimensions) + sizeof(profile) : sizeof(int32_t) * 2;
    size_t pitch = size_t(image->width()) * 4;
    auto bytes = SkData::MakeUninitialized(header + pitch * image->height());
    if (!bytes) return nullptr;
    auto* data = static_cast<uint8_t*>(bytes->writable_data());
    std::memcpy(data, dimensions, tagged ? sizeof(dimensions) : sizeof(int32_t) * 2);
    if (tagged) std::memcpy(data + sizeof(dimensions), profile, sizeof(profile));
    auto info = SkImageInfo::Make(image->width(), image->height(), kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, tagged ? space : SkColorSpace::MakeSRGB());
    if (!image->readPixels(nullptr, info, data + header, pitch, 0, 0)) return nullptr;
    return bytes;
}

struct VoxPicturePixelLeaseOwner {
    VoxSharedPicturePixelsLease lease;
    ~VoxPicturePixelLeaseOwner() { if (lease.release) lease.release(lease.owner); }
};

static sk_sp<SkImage> vox_decode_picture_image_view(void const* bytes, size_t size,
    VoxSharedPicturePixelsLease lease = {})
{
    VoxPicturePixelLeaseOwner input_owner {lease};
    int32_t dimensions[3] {};
    if (!bytes || size < sizeof(int32_t) * 2) return nullptr;
    std::memcpy(dimensions, bytes, sizeof(int32_t) * 2);
    bool tagged = dimensions[0] == -1;
    float profile[VOX_IMAGE_COLOR_PROFILE_VALUES];
    size_t header = sizeof(int32_t) * 2;
    if (tagged) {
        header = sizeof(dimensions) + sizeof(profile);
        if (size < header) return nullptr;
        std::memcpy(dimensions, bytes, sizeof(dimensions));
        std::memcpy(profile, static_cast<uint8_t const*>(bytes) + sizeof(dimensions), sizeof(profile));
        if (profile[0] != -1) return nullptr;
        for (float value : profile) if (!std::isfinite(value)) return nullptr;
    }
    int width = dimensions[tagged ? 1 : 0], height = dimensions[tagged ? 2 : 1];
    if (width <= 0 || height <= 0 || width > 16384 || height > 16384
        || size != header + size_t(width) * height * 4) return nullptr;
    auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType,
        kPremul_SkAlphaType, vox_image_color_space_from_profile(tagged ? profile : nullptr));
    if (input_owner.lease.owner && input_owner.lease.release) {
        auto owner = std::make_unique<VoxPicturePixelLeaseOwner>();
        std::swap(owner->lease, input_owner.lease);
        auto data = SkData::MakeWithProc(static_cast<uint8_t const*>(bytes) + header,
            size - header, [](void const*, void* context) {
                delete static_cast<VoxPicturePixelLeaseOwner*>(context);
            }, owner.get());
        if (!data) return nullptr;
        owner.release();
        return SkImages::RasterFromData(info, std::move(data), size_t(width) * 4);
    }
    return SkImages::RasterFromPixmapCopy(SkPixmap(info,
        static_cast<uint8_t const*>(bytes) + header, size_t(width) * 4));
}

struct VoxSharedPicturePixelsToken {
    int32_t tag = -2;
    uint32_t version = 1;
    uint64_t token = 0;
};
static_assert(sizeof(VoxSharedPicturePixelsToken) == 16);

static sk_sp<SkImage> vox_decode_picture_image(void const* bytes, size_t size)
{
    int32_t tag = 0;
    if (!bytes || size < sizeof(tag)) return nullptr;
    std::memcpy(&tag, bytes, sizeof(tag));
    if (tag != -2) return vox_decode_picture_image_view(bytes, size);
    if (size != sizeof(VoxSharedPicturePixelsToken)) return nullptr;
    VoxSharedPicturePixelsToken payload;
    std::memcpy(&payload, bytes, sizeof(payload));
    if (payload.version != 1 || !payload.token) return nullptr;
    static auto acquire = reinterpret_cast<VoxAcquireSharedPicturePixels>(
        dlsym(RTLD_DEFAULT, "vox_picture_pixels_acquire"));
    VoxSharedPicturePixelsLease lease;
    if (!acquire || !acquire(payload.token, &lease)) return nullptr;
    if (std::getenv("VOX_SHARED_PICTURE_PIXELS_DIAGNOSTICS"))
        std::fprintf(stderr, "VOX_SHARED_PICTURE_PIXELS_DECODE bytes=%zu\n", lease.size);
    return vox_decode_picture_image_view(lease.bytes, lease.size, lease);
}
