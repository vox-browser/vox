// ABI adaptation of DisplayListPlayerSkia.cpp:737-798 and
// DisplayListResourceStorage.cpp::make_text_blob(). Command construction is V.
#include "shadow_raster.h"
#include "shadow_typeface_cache.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkColorFilter.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkPaint.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTextBlob.h"
#include "include/effects/SkBlurMaskFilter.h"
#include "include/effects/SkImageFilters.h"
#include "include/pathops/SkPathOps.h"
#include "include/core/SkPathBuilder.h"
#include <cmath>
#include <numbers>
#ifdef __APPLE__
#include "include/ports/SkFontMgr_mac_ct.h"
#elif defined(_WIN32)
#include "include/ports/SkTypeface_win.h"
#else
#include "include/ports/SkFontMgr_empty.h"
#endif

static SkMatrix shadow_matrix(float const* v)
{
    return SkMatrix::MakeAll(v[0], v[2], v[4], v[1], v[3], v[5], 0, 0, 1);
}

static SkRRect shadow_rrect(VoxShadowRect const& shape)
{
    SkVector radii[4];
    for (int i = 0; i < 4; ++i)
        radii[i] = { shape.radii[i * 2], shape.radii[i * 2 + 1] };
    SkRRect rrect;
    rrect.setRectRadii(SkRect::MakeXYWH(shape.rect[0], shape.rect[1], shape.rect[2], shape.rect[3]), radii);
    return rrect;
}

static sk_sp<SkFontMgr> shadow_font_manager()
{
#ifdef __APPLE__
    static auto manager = SkFontMgr_New_CoreText(nullptr);
#elif defined(_WIN32)
    static auto manager = SkFontMgr_New_DirectWrite();
#else
    static auto manager = SkFontMgr_New_Custom_Empty();
#endif
    return manager;
}

static sk_sp<SkTypeface> shadow_typeface(char const* path, int face_index)
{
    thread_local VoxShadowTypefaceCache cache;
    return cache.get(path, face_index, [](char const* file, int index) {
        return shadow_font_manager()->makeFromFile(file, index);
    });
}

static SkPath shadow_clip_path(VoxCanvasPath const& input)
{
#if defined(__linux__) || defined(_WIN32)
    SkPathBuilder path;
#else
    SkPath path;
#endif
    for (int i = 0; i < input.count; ++i) {
        auto const* segment = input.segments + i * 12;
        switch (int(segment[0])) {
        case 0: path.moveTo(segment[1], segment[2]); break;
        case 1: path.lineTo(segment[1], segment[2]); break;
        case 2: path.quadTo(segment[3], segment[4], segment[1], segment[2]); break;
        case 3: path.cubicTo(segment[3], segment[4], segment[5], segment[6], segment[1], segment[2]); break;
        case 4:
#if defined(__linux__) || defined(_WIN32)
            path.arcTo(SkPoint{segment[7], segment[8]}, segment[9] * 180.0f / std::numbers::pi_v<float>, segment[10] ? SkPathBuilder::kLarge_ArcSize : SkPathBuilder::kSmall_ArcSize,
                segment[11] ? SkPathDirection::kCW : SkPathDirection::kCCW, SkPoint{segment[1], segment[2]});
#else
            path.arcTo(segment[7], segment[8], segment[9] * 180.0f / std::numbers::pi_v<float>, segment[10] ? SkPath::kLarge_ArcSize : SkPath::kSmall_ArcSize,
                segment[11] ? SkPathDirection::kCW : SkPathDirection::kCCW, segment[1], segment[2]);
#endif
            break;
        case 5: path.close(); break;
        }
    }
    path.setFillType(input.even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
#if defined(__linux__) || defined(_WIN32)
    return path.detach();
#else
    return path;
#endif
}

extern "C" bool vox_skia_shadow(uint8_t* pixels, int width, int height, int pitch, VoxShadowCommand const* command)
{
    auto info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto surface = SkSurfaces::Raster(info);
    if (!surface)
        return false;
    auto& canvas = *surface->getCanvas();
    canvas.clear(SK_ColorTRANSPARENT);
    for (int i = 0; i < command->clip_count; ++i) {
        canvas.setMatrix(shadow_matrix(command->clips[i].transform));
        if (command->clips[i].is_path)
            canvas.clipPath(shadow_clip_path(command->clips[i].path), true);
        else
            canvas.clipRRect(shadow_rrect(command->clips[i].shape), true);
    }
    canvas.setMatrix(shadow_matrix(command->transform));
    if (command->kind == 0) {
        canvas.save();
        canvas.clipRRect(shadow_rrect(command->content), SkClipOp::kDifference, true);
        SkPaint paint;
        paint.setAntiAlias(true);
        paint.setColor(command->color);
        paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, command->blur / 2));
        canvas.drawRRect(shadow_rrect(command->outer), paint);
        canvas.restore();
    } else if (command->kind == 1) {
        auto outer = SkPath::RRect(shadow_rrect(command->outer));
        auto inner = SkPath::RRect(shadow_rrect(command->inner));
        SkPath difference;
        if (!Op(outer, inner, SkPathOp::kDifference_SkPathOp, &difference))
            return false;
        SkPaint paint;
        paint.setAntiAlias(true);
        paint.setColor(command->color);
        paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, command->blur / 2));
        canvas.save();
        canvas.clipRRect(shadow_rrect(command->content), true);
        canvas.drawPath(difference, paint);
        canvas.restore();
    } else {
        auto face = shadow_typeface(command->font_path, command->face_index);
        if (!face)
            return false;
        SkFont font(face, command->font_size);
        font.setSubpixel(true);
#ifdef __APPLE__
        switch (command->font_smoothing) {
        case 1: font.setEdging(SkFont::Edging::kAlias); break;
        case 2: font.setEdging(SkFont::Edging::kAntiAlias); font.setHinting(SkFontHinting::kNone); break;
        case 3: font.setEdging(SkFont::Edging::kSubpixelAntiAlias); break;
        }
#endif
        SkTextBlobBuilder builder;
        auto const& run = builder.allocRunPos(font, command->glyph_count);
        for (int i = 0; i < command->glyph_count; ++i) {
            run.glyphs[i] = command->glyphs[i];
            // V's retained positions already use the baseline (source adds
            // ascent to its top-relative positions in make_text_blob).
            run.pos[i * 2] = command->positions[i * 2];
            run.pos[i * 2 + 1] = command->positions[i * 2 + 1];
        }
        auto blob = builder.make();
        if (blob) {
            SkPaint blur;
            blur.setImageFilter(SkImageFilters::Blur(command->blur / 2, command->blur / 2, nullptr));
            blur.setColorFilter(SkColorFilters::Blend(command->color, SkBlendMode::kSrcIn));
            canvas.saveLayer(SkCanvas::SaveLayerRec(nullptr, &blur, nullptr, 0));
            SkPaint opaque;
            opaque.setColor(command->color | 0xff000000);
            canvas.drawTextBlob(blob.get(), command->translation[0], command->translation[1], opaque);
            canvas.restore();
        }
    }
    // Sokol's existing source-alpha pipeline accepts straight RGBA. Keep the
    // Skia surface premultiplied and ask Skia to convert at this ABI boundary.
    return surface->readPixels(info.makeAlphaType(kUnpremul_SkAlphaType), pixels, pitch, 0, 0);
}
