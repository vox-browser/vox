// Native ABI adaptation of LibGfx/BitmapExport.cpp and SkiaUtils::sk_image_from_bitmap.
#include "bitmap_export.h"
#include "include/core/SkBitmap.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkImage.h"
#include "include/core/SkSurface.h"

static int export_bytes_per_pixel(int format)
{
    switch (format) {
    case 0: case 1: return 1;
    case 2: case 3: case 4: return 2;
    case 5: return 3;
    case 6: return 4;
    default: return 0;
    }
}

static SkColorType export_color_type(int format)
{
    switch (format) {
    case 0: return kGray_8_SkColorType;
    case 1: return kAlpha_8_SkColorType;
    case 2: return kRGB_565_SkColorType;
    // The current upstream export does not support RGBA5551.
    case 3: return kUnknown_SkColorType;
    case 4: return kARGB_4444_SkColorType;
    case 6: return kRGBA_8888_SkColorType;
    default: return kUnknown_SkColorType;
    }
}

extern "C" int vox_skia_bitmap_export(uint8_t const* pixels, int source_width, int source_height, int source_pitch, int source_layout, int source_alpha, int source_color_space, int format, int flags, int width, int height, uint8_t* output)
{
    if (width == 0 || height == 0)
        return 1;
    int pitch = width * export_bytes_per_pixel(format);
    if (format == 5) {
        // Source RGB888 export uses raw Bitmap::get_pixel and does not scale.
        for (int y = 0; y < height; ++y) {
            int target_y = flags & 2 ? height - y - 1 : y;
            for (int x = 0; x < width; ++x) {
                auto const* pixel = pixels + y * source_pitch + x * 4;
                auto* destination = output + target_y * pitch + x * 3;
                destination[0] = pixel[source_layout == 1 || source_layout == 3 ? 2 : 0];
                destination[1] = pixel[1];
                destination[2] = pixel[source_layout == 1 || source_layout == 3 ? 0 : 2];
            }
        }
        return 1;
    }
    auto space = source_color_space == 1
        ? SkColorSpace::MakeRGB(SkNamedTransferFn::kSRGB, SkNamedGamut::kDisplayP3)
        : SkColorSpace::MakeSRGB();
    auto color_type = source_layout == 1 || source_layout == 3 ? kBGRA_8888_SkColorType : source_layout == 2 ? kRGB_888x_SkColorType : kRGBA_8888_SkColorType;
    auto alpha_type = source_layout == 2 || source_layout == 3 ? kOpaque_SkAlphaType : source_alpha == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType;
    auto source_info = SkImageInfo::Make(source_width, source_height, color_type, alpha_type, space);
    SkBitmap bitmap;
    if (!bitmap.installPixels(source_info, const_cast<uint8_t*>(pixels), source_pitch))
        return 0;
    bitmap.setImmutable();
    auto image = bitmap.asImage();
    if (!image)
        return 0;
    auto skia_format = export_color_type(format);
    if (skia_format == kUnknown_SkColorType)
        return 0;
    auto image_info = SkImageInfo::Make(width, height, skia_format, flags & 1 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(image_info, output, pitch);
    if (!surface)
        return 0;
    auto* canvas = surface->getCanvas();
    auto destination = SkRect::MakeWH(width, height);
    if (flags & 2) {
        canvas->translate(0, destination.height());
        canvas->scale(1, -1);
    }
    canvas->drawImageRect(image.get(), destination, SkSamplingOptions(SkFilterMode::kNearest));
    return 1;
}
