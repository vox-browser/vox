// Optional gg.canvas glyph rasterizer. With VOX_GG_TEXT=1 the browser
// registers gg.canvas' CPU text renderer here so it replaces Skia's raster
// drawTextBlob() for BGRA8 premultiplied sRGB surfaces; comparing captures
// with and without it validates the Skia migration in place. A run the
// renderer cannot reproduce exactly returns 0, and Skia draws it instead.
#pragma once

#include "include/core/SkFont.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkSurfaceProps.h"
#include "include/core/SkTextBlob.h"
#include "include/ports/SkTypeface_mac.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <vector>

// Flags passed with a run, mirroring the SkFont flags.
enum : int {
    VoxGGTextSubpixel = 1,
    VoxGGTextLinearMetrics = 2,
    VoxGGTextEmbolden = 4,
    VoxGGTextBaselineSnap = 8,
    VoxGGTextEmbeddedBitmaps = 16,
};

using VoxGGGlyphRun = int (*)(uint32_t* pixels, int width, int height, int row_pixels,
    void const* ct_font, float size, float scale_x, float skew_x, int edging, int hinting,
    int flags, uint16_t const* glyphs, float const* positions, int count, float origin_x,
    float origin_y, float const* matrix, uint32_t color, float text_contrast, float text_gamma);

static VoxGGGlyphRun s_gg_glyph_run = nullptr;

extern "C" void ladybird_v_skia_set_gg_glyph_run(VoxGGGlyphRun run)
{
    s_gg_glyph_run = run;
}

// Draws a single-run, fully positioned blob (as the bridge builds them) into
// BGRA8 premultiplied sRGB pixels like SkCanvas::drawTextBlob(). Returns false
// without touching the pixels when no gg renderer is registered or it cannot
// reproduce the draw.
static bool gg_draw_text_blob(uint32_t* pixels, int width, int height, size_t row_bytes,
    SkMatrix const& matrix, SkTextBlob const* blob, float x, float y, SkPaint const& paint,
    SkSurfaceProps const* properties, SkIRect const* device_clip = nullptr)
{
    if (!s_gg_glyph_run || !blob || !pixels || width <= 0 || height <= 0
        || row_bytes % 4 || row_bytes < size_t(width) * 4
        || row_bytes / 4 > size_t(std::numeric_limits<int>::max())
        || row_bytes > SIZE_MAX / size_t(height) || matrix.hasPerspective())
        return false;
    if (paint.getShader() || paint.getMaskFilter() || paint.getColorFilter()
        || paint.getPathEffect() || paint.getImageFilter() || !paint.isSrcOver()
        || paint.getStyle() != SkPaint::kFill_Style
        || paint.getColor4f() != SkColor4f::FromColor(paint.getColor()))
        return false;
    SkTextBlob::Iter iter(*blob);
    SkTextBlob::Iter::ExperimentalRun run;
    if (!iter.experimentalNext(&run) || iter.experimentalNext(nullptr) || run.count <= 0
        || !run.positions)
        return false;
    auto const& font = run.font;
    auto* typeface = font.getTypeface();
    if (!typeface)
        return false;
    int flags = (font.isSubpixel() ? VoxGGTextSubpixel : 0)
        | (font.isLinearMetrics() ? VoxGGTextLinearMetrics : 0)
        | (font.isEmbolden() ? VoxGGTextEmbolden : 0)
        | (font.isBaselineSnap() ? VoxGGTextBaselineSnap : 0)
        | (font.isEmbeddedBitmaps() ? VoxGGTextEmbeddedBitmaps : 0);
    std::vector<float> positions(size_t(run.count) * 2);
    for (int i = 0; i < run.count; ++i) {
        positions[size_t(i) * 2] = run.positions[i].fX;
        positions[size_t(i) * 2 + 1] = run.positions[i].fY;
    }
    float values[9];
    matrix.get9(values);
    SkSurfaceProps defaults;
    auto const& props = properties ? *properties : defaults;
    if (props.pixelGeometry() != kUnknown_SkPixelGeometry)
        return false;

    auto visible = SkIRect::MakeWH(width, height);
    if (device_clip && !visible.intersect(*device_clip))
        return true;
    bool const bounded = visible != SkIRect::MakeWH(width, height);
    // Retain the original raster dimensions and device matrix. Cropping the
    // surface and translating its matrix changes fractional glyph rounding.
    // Shade the same pixels on a private backdrop, then publish only the clip.
    std::vector<uint32_t> staged;
    auto* target = pixels;
    int stride = int(row_bytes / 4);
    if (bounded) {
        if (size_t(width) * size_t(height) > 64u * 1024 * 1024)
            return false;
        staged.resize(size_t(width) * height);
        for (int row = 0; row < height; ++row)
            std::memcpy(staged.data() + size_t(row) * width,
                reinterpret_cast<uint8_t const*>(pixels) + size_t(row) * row_bytes,
                size_t(width) * 4);
        target = staged.data();
        stride = width;
    }
    bool const drawn = s_gg_glyph_run(target, width, height, stride,
               SkTypeface_GetCTFontRef(typeface), font.getSize(), font.getScaleX(),
               font.getSkewX(), int(font.getEdging()), int(font.getHinting()), flags,
               run.glyphs, positions.data(), run.count, x, y, values, paint.getColor(),
               props.textContrast(), props.textGamma())
        != 0;
    if (drawn && bounded)
        for (int row = visible.top(); row < visible.bottom(); ++row)
            std::memcpy(reinterpret_cast<uint8_t*>(pixels) + size_t(row) * row_bytes
                    + size_t(visible.left()) * 4,
                staged.data() + size_t(row) * width + visible.left(), size_t(visible.width()) * 4);
    auto* diagnostics = std::getenv("VOX_GG_DIAGNOSTICS");
    if (diagnostics && std::strcmp(diagnostics, "1") == 0)
        std::fprintf(stderr, "VOX_GG text device_clip=%d drawn=%d\n", device_clip != nullptr, drawn);
    return drawn;
}
