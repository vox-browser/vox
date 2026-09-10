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
#include "include/core/SkPath.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTextBlob.h"
#include "include/core/SkTypeface.h"
#include "include/ports/SkFontMgr_mac_ct.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>
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
std::unordered_map<std::string, sk_sp<SkTypeface>> s_path_typefaces;

SkTypeface* select_typeface(char const* path, int face_index, int font_weight, int emoji_face)
{
    if (path && *path) {
        auto key = std::string(path) + "#" + std::to_string(face_index);
        if (auto found = s_path_typefaces.find(key); found != s_path_typefaces.end())
            return found->second.get();
        if (!s_font_manager)
            s_font_manager = SkFontMgr_New_CoreText(nullptr);
        if (s_font_manager) {
            char const* collection_family = nullptr;
            if (std::strcmp(path, "/System/Library/Fonts/HelveticaNeue.ttc") == 0)
                collection_family = "Helvetica Neue";
            else if (std::strcmp(path, "/System/Library/Fonts/LucidaGrande.ttc") == 0)
                collection_family = "Lucida Grande";
            else if (std::strcmp(path, "/System/Library/Fonts/Supplemental/GillSans.ttc") == 0)
                collection_family = "Gill Sans";

            // Keep the collection index attached to the font data explicitly.
            // The CoreText file helper can reopen a TTC as its default face,
            // which makes retained glyph IDs from another face render as
            // unrelated characters (most visibly for Helvetica Neue Bold).
            // CoreText can also silently return the collection's default face
            // for a valid non-zero index. Resolve the three macOS collections
            // emitted by platform::Font through the system manager first.
            auto typeface = collection_family && face_index != 0
                ? s_font_manager->matchFamilyStyle(collection_family, SkFontStyle::Bold())
                : nullptr;
            if (!typeface) {
                auto data = SkData::MakeFromFileName(path);
                typeface = data ? s_font_manager->makeFromData(std::move(data), face_index) : nullptr;
            }
            if (typeface) {
                auto* result = typeface.get();
                s_path_typefaces.emplace(std::move(key), std::move(typeface));
                return result;
            }
        }
    }
    auto slot = emoji_face ? EmojiFont : (font_weight >= 600 ? BoldFont : RegularFont);
    if (!s_typefaces[slot] && slot == BoldFont)
        slot = RegularFont;
    return s_typefaces[slot].get();
}

int composite_pixels(CGContextRef destination, std::vector<uint32_t> const& pixels,
    int width, int height, float destination_x, float destination_y,
    float destination_width, float destination_height)
{
    // A drawRect: CGContext may retain the image in a display list and replay it
    // later during the Core Animation transaction. Give the provider its own
    // copy instead of pointing it at a vector which dies when this call returns.
    auto data = CFDataCreate(kCFAllocatorDefault,
        reinterpret_cast<UInt8 const*>(pixels.data()),
        static_cast<CFIndex>(pixels.size() * sizeof(uint32_t)));
    if (!data)
        return 0;
    auto provider = CGDataProviderCreateWithCFData(data);
    CFRelease(data);
    if (!provider)
        return 0;
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
    CGContextDrawImage(destination,
        CGRectMake(destination_x, destination_y, destination_width, destination_height), image);
    CGContextRestoreGState(destination);
    CGImageRelease(image);
    return 1;
}

int composite_canvas_pixels(CGContextRef destination, std::vector<uint32_t> const& pixels,
    int width, int height, float canvas_width, float canvas_height)
{
    return composite_pixels(destination, pixels, width, height,
        0.0f, 0.0f, canvas_width, canvas_height);
}

SkPath path_from_serialized_segments(float const* data, int segment_count)
{
    SkPath path;
    if (!data || segment_count <= 0)
        return path;

    float last_move_x = 0.0f;
    float last_move_y = 0.0f;
    bool has_move = false;
    for (int index = 0; index < segment_count; ++index) {
        auto const* segment = data + index * 12;
        switch (static_cast<int>(segment[0])) {
        case 0:
            path.moveTo(segment[1], segment[2]);
            last_move_x = segment[1];
            last_move_y = segment[2];
            has_move = true;
            break;
        case 1:
            path.lineTo(segment[1], segment[2]);
            break;
        case 2:
            path.quadTo(segment[3], segment[4], segment[1], segment[2]);
            break;
        case 3:
            path.cubicTo(segment[3], segment[4], segment[5], segment[6],
                segment[1], segment[2]);
            break;
        case 4:
            path.arcTo(std::abs(segment[7]), std::abs(segment[8]),
                segment[9] * 180.0f / static_cast<float>(M_PI),
                segment[10] != 0.0f ? SkPath::kLarge_ArcSize : SkPath::kSmall_ArcSize,
                segment[11] != 0.0f ? SkPathDirection::kCW : SkPathDirection::kCCW,
                segment[1], segment[2]);
            break;
        case 5:
            path.close();
            // Gfx::PathImplSkia starts a fresh contour at the last move point
            // after close(), so retain the same behavior for subsequent segments.
            if (has_move)
                path.moveTo(last_move_x, last_move_y);
            break;
        default:
            break;
        }
    }
    return path;
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
    char const* font_path, int face_index, uint16_t const* glyphs, double const* packed_positions, int glyph_count,
    float font_size, int font_weight, int emoji_face, float baseline_x,
    float baseline_y, float transform_a, float transform_b, float transform_c,
    float transform_d, float transform_e, float transform_f, float page_x,
    float page_y, float scroll_y, float canvas_width, float canvas_height,
    uint8_t red, uint8_t green, uint8_t blue, uint8_t alpha)
{
    auto* typeface = select_typeface(font_path, face_index, font_weight, emoji_face);
    if (!destination || !typeface || !glyphs || !packed_positions || glyph_count <= 0
        || canvas_width <= 0 || canvas_height <= 0)
        return 0;

    SkFont font(sk_ref_sp(typeface), std::max(font_size, 0.0f));
    // This is the only non-default setting in Gfx::Font::skia_font().
    font.setSubpixel(true);
    // The generic-serif cascade deliberately retains Times New Roman's regular
    // advances for bold text. Give only that regular face synthetic weight;
    // some file-backed real bold faces do not report their weight through the
    // CoreText SkTypeface and must not be emboldened a second time.
    if (!emoji_face && font_weight >= 600 && font_path
        && std::strcmp(font_path, "/System/Library/Fonts/Supplemental/Times New Roman.ttf") == 0)
        font.setEmbolden(true);

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
    auto matrix = SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f);

    // The old bridge allocated and recorded one canvas-sized transparent image
    // for every glyph run. A text-heavy page consequently made AppKit replay
    // hundreds of full-window images before its first composited frame. Keep
    // Skia's raster origin integer-aligned, but restrict the surface to the
    // transformed run bounds (plus an antialiasing guard pixel).
    auto local_bounds = blob->bounds();
    local_bounds.offset(baseline_x, baseline_y);
    auto device_bounds = matrix.mapRect(local_bounds);
    constexpr float antialiasing_guard = 2.0f;
    auto left = std::max(0, static_cast<int>(std::floor(device_bounds.left() - antialiasing_guard)));
    auto top = std::max(0, static_cast<int>(std::floor(device_bounds.top() - antialiasing_guard)));
    auto right = std::min(static_cast<int>(std::ceil(canvas_width)),
        static_cast<int>(std::ceil(device_bounds.right() + antialiasing_guard)));
    auto bottom = std::min(static_cast<int>(std::ceil(canvas_height)),
        static_cast<int>(std::ceil(device_bounds.bottom() + antialiasing_guard)));
    auto width = right - left;
    auto height = bottom - top;
    if (width <= 0 || height <= 0)
        return 1;

    std::vector<uint32_t> pixels(static_cast<size_t>(width) * static_cast<size_t>(height));
    auto image_info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto row_bytes = static_cast<size_t>(width) * sizeof(uint32_t);
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(), row_bytes);
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    matrix.setTranslateX(matrix.getTranslateX() - static_cast<float>(left));
    matrix.setTranslateY(matrix.getTranslateY() - static_cast<float>(top));
    canvas->setMatrix(matrix);
    canvas->drawTextBlob(blob, baseline_x, baseline_y, paint);
    return composite_pixels(destination, pixels, width, height,
        static_cast<float>(left), canvas_height - static_cast<float>(bottom),
        static_cast<float>(width), static_cast<float>(height));
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
    return composite_canvas_pixels(destination, pixels, width, height, canvas_width, canvas_height);
}

extern "C" int ladybird_v_skia_draw_rounded_rect(CGContextRef destination,
    float x, float y, float rect_width, float rect_height, float top_left_x,
    float top_left_y, float top_right_x, float top_right_y, float bottom_right_x,
    float bottom_right_y, float bottom_left_x, float bottom_left_y,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height, uint8_t red,
    uint8_t green, uint8_t blue, uint8_t alpha, int fill, float thickness,
    int anti_alias)
{
    if (!destination || rect_width <= 0 || rect_height <= 0 || canvas_width <= 0
        || canvas_height <= 0 || (!fill && thickness <= 0))
        return 0;
    auto width = static_cast<int>(std::ceil(canvas_width));
    auto height = static_cast<int>(std::ceil(canvas_height));
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
    SkVector radii[4] {
        { std::max(top_left_x, 0.0f), std::max(top_left_y, 0.0f) },
        { std::max(top_right_x, 0.0f), std::max(top_right_y, 0.0f) },
        { std::max(bottom_right_x, 0.0f), std::max(bottom_right_y, 0.0f) },
        { std::max(bottom_left_x, 0.0f), std::max(bottom_left_y, 0.0f) },
    };
    SkRRect rounded_rect;
    rounded_rect.setRectRadii(SkRect::MakeXYWH(x, y, rect_width, rect_height), radii);
    SkPaint paint;
    paint.setColor(SkColorSetARGB(alpha, red, green, blue));
    paint.setAntiAlias(anti_alias != 0);
    if (!fill) {
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(thickness);
    }
    canvas->drawRRect(rounded_rect, paint);
    return composite_canvas_pixels(destination, pixels, width, height, canvas_width, canvas_height);
}

extern "C" int ladybird_v_skia_draw_svg_path(CGContextRef destination,
    float const* data, int segment_count, int even_odd,
    float transform_a, float transform_b, float transform_c, float transform_d,
    float transform_e, float transform_f, float page_x, float page_y,
    float scroll_y, float canvas_width, float canvas_height,
    uint8_t fill_red, uint8_t fill_green, uint8_t fill_blue, uint8_t fill_alpha,
    int has_fill, uint8_t stroke_red, uint8_t stroke_green, uint8_t stroke_blue,
    uint8_t stroke_alpha, int has_stroke, float stroke_width, int line_cap,
    int line_join, float miter_limit)
{
    if (!destination || !data || segment_count <= 0 || (!has_fill && !has_stroke)
        || canvas_width <= 0 || canvas_height <= 0)
        return 0;

    auto width = static_cast<int>(std::ceil(canvas_width));
    auto height = static_cast<int>(std::ceil(canvas_height));
    std::vector<uint32_t> pixels(static_cast<size_t>(width) * static_cast<size_t>(height));
    auto image_info = SkImageInfo::Make(width, height, kBGRA_8888_SkColorType,
        kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::WrapPixels(image_info, pixels.data(),
        static_cast<size_t>(width) * sizeof(uint32_t));
    if (!surface)
        return 0;

    auto* canvas = surface->getCanvas();
    canvas->clear(SK_ColorTRANSPARENT);
    canvas->setMatrix(SkMatrix::MakeAll(
        transform_a, transform_c, page_x + transform_e,
        transform_b, transform_d, page_y - scroll_y + transform_f,
        0.0f, 0.0f, 1.0f));

    auto path = path_from_serialized_segments(data, segment_count);
    path.setFillType(even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
    if (has_fill) {
        SkPaint paint;
        paint.setAntiAlias(true);
        paint.setColor(SkColorSetARGB(fill_alpha, fill_red, fill_green, fill_blue));
        canvas->drawPath(path, paint);
    }
    if (has_stroke && stroke_width > 0.0f) {
        SkPaint paint;
        paint.setAntiAlias(true);
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(stroke_width);
        paint.setColor(SkColorSetARGB(stroke_alpha, stroke_red, stroke_green, stroke_blue));
        paint.setStrokeCap(line_cap == 1 ? SkPaint::kRound_Cap
            : line_cap == 2 ? SkPaint::kSquare_Cap : SkPaint::kButt_Cap);
        paint.setStrokeJoin(line_join == 1 ? SkPaint::kRound_Join
            : line_join == 2 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
        paint.setStrokeMiter(std::max(miter_limit, 1.0f));
        canvas->drawPath(path, paint);
    }

    return composite_canvas_pixels(destination, pixels, width, height, canvas_width, canvas_height);
}
