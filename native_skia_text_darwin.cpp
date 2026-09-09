// A deliberately narrow bridge to the same Skia text rasterizer that Ladybird
// uses for DisplayListPlayerSkia. V continues to shape and position every glyph;
// this file only turns the retained glyph IDs into the final antialiased pixels.

#include <CoreGraphics/CoreGraphics.h>

#include "include/core/SkCanvas.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkData.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTextBlob.h"
#include "include/core/SkTypeface.h"
#include "include/ports/SkFontMgr_mac_ct.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <utility>
#include <vector>

namespace {

enum FontSlot {
    RegularFont = 0,
    BoldFont = 1,
    EmojiFont = 2,
    FontSlotCount = 3,
};

sk_sp<SkFontMgr> s_font_manager;
sk_sp<SkTypeface> s_typefaces[FontSlotCount];

SkTypeface* select_typeface(int font_weight, int emoji_face)
{
    auto slot = emoji_face ? EmojiFont : (font_weight >= 600 ? BoldFont : RegularFont);
    if (!s_typefaces[slot] && slot == BoldFont)
        slot = RegularFont;
    return s_typefaces[slot].get();
}

int composite_pixels(CGContextRef destination, std::vector<uint32_t> const& pixels,
    int width, int height, float canvas_width, float canvas_height)
{
    auto provider = CGDataProviderCreateWithData(nullptr, pixels.data(),
        pixels.size() * sizeof(uint32_t), nullptr);
    auto color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto image = CGImageCreate(static_cast<size_t>(width), static_cast<size_t>(height),
        8, 32, static_cast<size_t>(width) * sizeof(uint32_t), color_space,
        static_cast<CGBitmapInfo>(kCGImageAlphaPremultipliedFirst)
            | static_cast<CGBitmapInfo>(kCGBitmapByteOrder32Little),
        provider, nullptr, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(color_space);
    CGDataProviderRelease(provider);
    if (!image)
        return 0;

    CGContextSaveGState(destination);
    CGContextSetInterpolationQuality(destination, kCGInterpolationNone);
    CGContextDrawImage(destination, CGRectMake(0.0, 0.0, canvas_width, canvas_height), image);
    CGContextRestoreGState(destination);
    CGImageRelease(image);
    return 1;
}

} // namespace

extern "C" int ladybird_v_skia_configure_font(char const* path, int slot)
{
    if (!path || slot < 0 || slot >= FontSlotCount)
        return 0;
    auto data = SkData::MakeFromFileName(path);
    if (!data)
        return 0;
    if (!s_font_manager)
        s_font_manager = SkFontMgr_New_CoreText(nullptr);
    if (!s_font_manager)
        return 0;
    auto typeface = s_font_manager->makeFromData(std::move(data), 0);
    if (!typeface)
        return 0;
    s_typefaces[slot] = std::move(typeface);
    return 1;
}

extern "C" int ladybird_v_skia_draw_glyph_run(CGContextRef destination,
    uint16_t const* glyphs, double const* packed_positions, int glyph_count,
    float font_size, int font_weight, int emoji_face, float baseline_x,
    float baseline_y, float transform_a, float transform_b, float transform_c,
    float transform_d, float transform_e, float transform_f, float page_x,
    float page_y, float scroll_y, float canvas_width, float canvas_height,
    uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha)
{
    auto* typeface = select_typeface(font_weight, emoji_face);
    if (!destination || !typeface || !glyphs || !packed_positions || glyph_count <= 0
        || canvas_width <= 0 || canvas_height <= 0)
        return 0;

    auto width = static_cast<int>(std::ceil(canvas_width));
    auto height = static_cast<int>(std::ceil(canvas_height));
    if (width <= 0 || height <= 0)
        return 0;

    SkFont font(sk_ref_sp(typeface), std::max(font_size, 0.0f));
    // This is the only non-default setting in Gfx::Font::skia_font().
    font.setSubpixel(true);

    SkTextBlobBuilder builder;
    auto const& run = builder.allocRunPos(font, glyph_count);
    for (int index = 0; index < glyph_count; ++index) {
        run.glyphs[index] = glyphs[index];
        run.pos[index * 2] = static_cast<SkScalar>(packed_positions[index * 2]);
        run.pos[index * 2 + 1] = static_cast<SkScalar>(packed_positions[index * 2 + 1]);
    }
    auto blob = builder.make();
    if (!blob)
        return 0;

    SkPaint paint;
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    std::vector<uint32_t> pixels(static_cast<size_t>(width) * static_cast<size_t>(height));
    auto image_info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto row_bytes = static_cast<size_t>(width) * sizeof(uint32_t);
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(), row_bytes);
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);
    canvas->setMatrix(matrix);
    canvas->drawTextBlob(blob, baseline_x, baseline_y, paint);
    return composite_pixels(destination, pixels, width, height, canvas_width, canvas_height);
}

extern "C" int ladybird_v_skia_draw_solid_line(CGContextRef destination,
    float from_x, float from_y, float to_x, float to_y, float thickness,
    float canvas_width, float canvas_height, uint8_t red, uint8_t green,
    uint8_t blue, uint8_t alpha)
{
    if (!destination || thickness <= 0 || canvas_width <= 0 || canvas_height <= 0)
        return 0;
    auto width = static_cast<int>(std::ceil(canvas_width));
    auto height = static_cast<int>(std::ceil(canvas_height));
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setStrokeWidth(thickness);
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    std::vector<uint32_t> pixels(static_cast<size_t>(width) * static_cast<size_t>(height));
    auto image_info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto row_bytes = static_cast<size_t>(width) * sizeof(uint32_t);
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(), row_bytes);
    if (!surface)
        return 0;
    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    canvas->drawLine(from_x, from_y, to_x, to_y, paint);
    return composite_pixels(destination, pixels, width, height, canvas_width, canvas_height);
}
