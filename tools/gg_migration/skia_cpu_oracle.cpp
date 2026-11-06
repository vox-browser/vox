// The original LibWeb Skia implementations of the operations moved to the
// Skia-free cpuraster module, kept verbatim so test_cpu_raster.sh can compare
// every byte against the pinned Skia build.
#include "include/core/SkBitmap.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkImageInfo.h"

#include <cstdint>

// V calls these through unprototyped function pointers, which pass stack
// arguments in 8-byte slots on Apple arm64. Integer arguments therefore travel
// in one array.
#define ORACLE extern "C" __attribute__((visibility("default")))

// skia/canvas_raster.cpp: vox_skia_canvas_read_pixels().
static bool read_pixels(uint8_t const* source, int width, int height, int pitch, int alpha_type, uint8_t* destination, int destination_width, int destination_height, int destination_pitch, int x, int y)
{
    auto source_info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, alpha_type == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto destination_info = SkImageInfo::Make(destination_width, destination_height, kRGBA_8888_SkColorType, kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    SkBitmap bitmap;
    if (!bitmap.installPixels(source_info, const_cast<uint8_t*>(source), pitch))
        return false;
    return bitmap.readPixels(destination_info, destination, destination_pitch, x, y);
}

// arguments: width, height, pitch, alpha_type, destination_width,
// destination_height, destination_pitch, x, y.
ORACLE int oracle_read_pixels(uint8_t const* source, uint8_t* destination, int const* arguments)
{
    auto const* a = arguments;
    return read_pixels(source, a[0], a[1], a[2], a[3], destination, a[4], a[5], a[6], a[7], a[8]);
}

// skia/font_typeface.cpp: vox_skia_font_typeface_is_valid().
#include "include/core/SkData.h"
#include "include/core/SkFontArguments.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkStream.h"
#include "include/core/SkTypeface.h"
#include "include/ports/SkFontMgr_mac_ct.h"

ORACLE int oracle_font_typeface_is_valid(uint8_t const* bytes, size_t size, int index)
{
    static auto manager = SkFontMgr_New_CoreText(nullptr);
    auto data = SkData::MakeWithoutCopy(bytes, size);
    SkFontArguments arguments;
    arguments.setCollectionIndex(index);
    auto stream = std::make_unique<SkMemoryStream>(data);
    return manager->makeFromStream(std::move(stream), arguments) != nullptr;
}
