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

// skia/bitmap_export.cpp: vox_skia_bitmap_export().
#include "include/core/SkCanvas.h"
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

static int bitmap_export(uint8_t const* pixels, int source_width, int source_height, int source_pitch, int source_layout, int source_alpha, int source_color_space, int format, int flags, int width, int height, uint8_t* output)
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

// arguments: source width, height, pitch, layout, alpha type, color space,
// format, flags, width, height.
ORACLE int oracle_bitmap_export(uint8_t const* pixels, uint8_t* output, int const* a)
{
    return bitmap_export(pixels, a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], output);
}

// Canvas2D solid path fills (skia/canvas_raster.cpp draw_canvas_command() with
// a solid style): SkCanvas::drawPath() with an anti-aliased solid paint into
// premultiplied RGBA_8888 sRGB pixels.
#include "include/core/SkPaint.h"
#include "include/core/SkPathBuilder.h"

// arguments: width, height, even-odd, op count, SkColor. floats: the affine
// matrix (a b c d e f), then 7 floats per op: kind (0 move, 1 line, 2 quad,
// 3 conic, 4 cubic, 5 close) and its coordinates (conic weight last).
ORACLE void oracle_fill_path(uint8_t* pixels, int const* a, float const* f)
{
    SkPathBuilder builder;
    float const* op = f + 6;
    for (int i = 0; i < a[3]; ++i, op += 7) {
        switch (int(op[0])) {
        case 0: builder.moveTo(op[1], op[2]); break;
        case 1: builder.lineTo(op[1], op[2]); break;
        case 2: builder.quadTo(op[1], op[2], op[3], op[4]); break;
        case 3: builder.conicTo(op[1], op[2], op[3], op[4], op[5]); break;
        case 4: builder.cubicTo(op[1], op[2], op[3], op[4], op[5], op[6]); break;
        case 5: builder.close(); break;
        }
    }
    builder.setFillType(a[2] ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    auto info = SkImageInfo::Make(a[0], a[1], kRGBA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(info, pixels, size_t(a[0]) * 4);
    auto* canvas = surface->getCanvas();
    canvas->setMatrix(SkMatrix::MakeAll(f[0], f[2], f[4], f[1], f[3], f[5], 0, 0, 1));
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setColor(SkColor(uint32_t(a[4])));
    canvas->drawPath(builder.detach(), paint);
}

// The production Canvas2D raster path (skia/canvas_raster.cpp).
#include "../../skia/canvas_raster.cpp"

// arguments: width, height, pitch, alpha type, even-odd, segment count,
// SkColor. floats: the transform, global alpha, then 12 floats per segment.
ORACLE int oracle_canvas_fill(uint8_t* pixels, int const* a, float const* f)
{
    VoxCanvasCommand command {};
    command.operation = 0;
    command.path = { f + 7, a[5], a[4] };
    command.style.kind = 0;
    command.style.color = uint32_t(a[6]);
    for (int i = 0; i < 6; ++i)
        command.transform[i] = f[i];
    command.global_alpha = f[6];
    return vox_skia_canvas_path(pixels, a[0], a[1], a[2], a[3], &command);
}

// arguments: width, height, pitch, alpha type, segment count, SkColor, cap,
// join. floats: the transform, global alpha, line width, miter limit, then
// 12 floats per segment.
ORACLE int oracle_canvas_stroke(uint8_t* pixels, int const* a, float const* f)
{
    VoxCanvasCommand command {};
    command.operation = 0;
    command.path = { f + 9, a[4], 0 };
    command.style.kind = 0;
    command.style.color = uint32_t(a[5]);
    for (int i = 0; i < 6; ++i)
        command.transform[i] = f[i];
    command.global_alpha = f[6];
    command.stroke = 1;
    command.width = f[7];
    command.miter = f[8];
    command.cap = a[6];
    command.join = a[7];
    return vox_skia_canvas_path(pixels, a[0], a[1], a[2], a[3], &command);
}
