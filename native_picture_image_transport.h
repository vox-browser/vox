#pragma once

#include "native_skia_image_color_space.h"
#include "include/core/SkData.h"
#include "include/core/SkImage.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkPixmap.h"
#include <cmath>
#include <cstdint>
#include <cstring>

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

static sk_sp<SkImage> vox_decode_picture_image(void const* bytes, size_t size)
{
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
    return SkImages::RasterFromPixmapCopy(SkPixmap(info,
        static_cast<uint8_t const*>(bytes) + header, size_t(width) * 4));
}
