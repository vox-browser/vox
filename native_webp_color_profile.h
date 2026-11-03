#ifndef VOX_NATIVE_WEBP_COLOR_PROFILE_H
#define VOX_NATIVE_WEBP_COLOR_PROFILE_H

#include "native_skia_image_color_space.h"

// Preserve a representable ICC tag through the GPU upload. Converting first
// with skcms quantizes different colors from Chromium's tagged texture upload.
static int vox_prepare_webp_icc_rgba(uint8_t* pixels, int count,
    uint8_t const* bytes, int length, float* color_profile)
{
    if (!color_profile) return 0;
    std::fill_n(color_profile, VOX_IMAGE_COLOR_PROFILE_VALUES, 0);
    if (!pixels || count <= 0 || !bytes || length <= 0) return 0;
    skcms_ICCProfile source;
    if (!skcms_Parse(bytes, length, &source)) return 0;
    bool srgb = skcms_ApproximatelyEqualProfiles(&source, skcms_sRGB_profile());
    auto space = srgb || source.has_A2B ? nullptr : SkColorSpace::Make(source);
    if (srgb || vox_store_image_color_space(space.get(), color_profile)) {
        // With no decode-time conversion, libwebp's MODE_rgbA truncates.
        for (int i = 0; i < count; ++i)
            for (int channel = 0; channel < 3; ++channel)
                pixels[i * 4 + channel] = pixels[i * 4 + channel] * pixels[i * 4 + 3] / 255;
        return 1;
    }
    // Separate channel curves and LUT transforms cannot travel in the compact
    // numerical profile. Keep the original-profile decode-time conversion.
    return skcms_Transform(pixels, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_Unpremul,
        &source, pixels, skcms_PixelFormat_RGBA_8888, skcms_AlphaFormat_PremulAsEncoded,
        skcms_sRGB_profile(), count);
}

#endif
