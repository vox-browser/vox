// Runs the canonical borrowed-frame adapter against its original CPU Skia path.
#include "include/core/SkCanvas.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkData.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkFontStyle.h"
#include "include/core/SkStream.h"
#include "include/core/SkSurface.h"
#include "include/core/SkShader.h"
#include "include/ports/SkFontMgr_mac_ct.h"
#include <CoreGraphics/CoreGraphics.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include "../../native/include/native_gg_text.h"
#include "../../native/include/native_parallel_pixels.h"

static bool rgba_bitmap(CGContextRef context)
{
    return CGBitmapContextGetBitsPerPixel(context) == 32
        && CGBitmapContextGetAlphaInfo(context) == kCGImageAlphaPremultipliedLast
        && (CGBitmapContextGetBitmapInfo(context) & kCGBitmapByteOrderMask) == kCGBitmapByteOrder32Big;
}

static void swap_red_blue_pixels(uint8_t* destination, uint8_t const* source, size_t count)
{
    vox_swap_red_blue_pixels(destination, source, count);
}

#include "../../native/include/native_glyph_bitmap_surface.h"

namespace {
constexpr int frame_width = 128, frame_height = 80, row_pixels = 137;
constexpr int tile_width = 96, tile_height = 48, left = 8, top = 12;
VoxGGGlyphRun callback;
int attempts, drawn;
bool corrupt_then_decline;

int counted_run(uint32_t* pixels, int width, int height, int stride, void const* font,
    float size, float scale_x, float skew_x, int edging, int hinting, int flags,
    uint16_t const* glyphs, float const* positions, int count, float x, float y,
    float const* matrix, uint32_t color, float contrast, float gamma)
{
    ++attempts;
    if (corrupt_then_decline) {
        for (int row = 0; row < height; ++row)
            std::fill_n(pixels + size_t(row) * stride, width, 0xffffffffu);
        return 0;
    }
    int result = callback(pixels, width, height, stride, font, size, scale_x, skew_x,
        edging, hinting, flags, glyphs, positions, count, x, y, matrix, color, contrast, gamma);
    drawn += result != 0;
    return result;
}

std::vector<uint8_t> backdrop(int index)
{
    std::vector<uint8_t> pixels(size_t(row_pixels) * frame_height * 4, 0xa7);
    for (int y = 0; y < frame_height; ++y) {
        for (int x = 0; x < frame_width; ++x) {
            auto* p = pixels.data() + (size_t(y) * row_pixels + x) * 4;
            int a = index % 3 == 0 ? 0 : index % 3 == 1 ? 255 : 128 + (x * 3 + y * 7) % 128;
            p[0] = uint8_t(x * 11 % (a + 1));
            p[1] = uint8_t(y * 17 % (a + 1));
            p[2] = uint8_t((x + y) * 5 % (a + 1));
            p[3] = uint8_t(a);
        }
    }
    return pixels;
}

bool render(std::vector<uint8_t> const& input, std::vector<uint8_t>& output,
    SkMatrix const& matrix, SkTextBlob const* blob, SkPaint const& paint,
    SkSurfaceProps const& props, SkIRect local_clip, bool gg, double scale)
{
    auto pixels = input;
    auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(pixels.data(), frame_width, frame_height, 8,
        row_pixels * 4, color, CGBitmapInfo(kCGBitmapByteOrder32Big) | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(color);
    if (!context) return false;
    CGContextScaleCTM(context, scale, scale);
    auto clip = local_clip.makeOffset(left, top);
    CGContextClipToRect(context, CGRectMake(double(clip.left()) / scale,
        double(frame_height - clip.bottom()) / scale, double(clip.width()) / scale,
        double(clip.height()) / scale));
    // Keep an immutable snapshot alive while the actual adapter detaches the frame.
    auto snapshot = CGBitmapContextCreateImage(context);
    ladybird_v_skia_set_gg_glyph_run(gg ? counted_run : nullptr);
    bool ok = draw_glyph_bitmap_surface(context, tile_width, tile_height,
        CGRectMake(double(left) / scale, double(frame_height - top - tile_height) / scale,
            double(tile_width) / scale, double(tile_height) / scale),
        matrix, blob, 3.25f, 28.5f, paint, &props, &clip);
    CGContextFlush(context);
    auto* data = static_cast<uint8_t*>(CGBitmapContextGetData(context));
    if (ok && data) output.assign(data, data + input.size());
    else ok = false;
    if (snapshot) {
        auto bytes = CGDataProviderCopyData(CGImageGetDataProvider(snapshot));
        if (!bytes || size_t(CFDataGetLength(bytes)) < input.size()
            || std::memcmp(CFDataGetBytePtr(bytes), input.data(), input.size())) {
            std::fprintf(stderr, "immutable frame snapshot changed\n");
            ok = false;
        }
        if (bytes) CFRelease(bytes);
        CGImageRelease(snapshot);
    } else ok = false;
    CGContextRelease(context);
    return ok;
}
}

extern "C" int vox_check_clipped_gg_text(VoxGGGlyphRun run, int count)
{
    callback = run;
    auto manager = SkFontMgr_New_CoreText(nullptr);
    std::vector<sk_sp<SkTypeface>> typefaces;
    for (auto* path : {"/System/Library/Fonts/Supplemental/Arial.ttf",
             "/System/Library/Fonts/Supplemental/Georgia.ttf", "/System/Library/Fonts/Geneva.ttf"}) {
        auto data = SkData::MakeFromFileName(path);
        if (!data) return 2;
        auto typeface = manager->makeFromStream(std::make_unique<SkMemoryStream>(data));
        if (!typeface) return 2;
        typefaces.push_back(std::move(typeface));
    }
    SkIRect clips[] {SkIRect::MakeLTRB(10, 0, 40, 48), SkIRect::MakeLTRB(0, 16, 96, 30),
        SkIRect::MakeLTRB(-5, -4, 50, 40), SkIRect::MakeWH(96, 48),
        SkIRect::MakeLTRB(-100, -100, 500, 500), SkIRect::MakeLTRB(13, 24, 14, 25),
        SkIRect::MakeLTRB(20, 20, 20, 20), SkIRect::MakeLTRB(200, 100, 240, 120)};
    SkMatrix matrices[] {SkMatrix::I(), SkMatrix::Translate(.375f, -.625f),
        SkMatrix::MakeAll(1.2f, .15f, -8.25f, .1f, .8f, 1.125f, 0, 0, 1),
        SkMatrix::MakeAll(.991236f, -.1321f, 8.841f, .1321f, .991236f, 2.488f, 0, 0, 1)};
    int total_attempts = 0, total_drawn = 0, fully_clipped = 0, fallbacks = 0, changed = 0;
    for (int i = 0; i < count; ++i) {
        SkFont font(typefaces[(i / 128) % typefaces.size()],
            8.f + float(i * 17 % 65) + float((i / 16) % 4) * .125f);
        font.setSubpixel(true);
        font.setLinearMetrics(true);
        bool unhinted = (i / 64) % 2;
        bool bold = i % 31 == 30, aliased = i % 37 == 36;
        font.setEdging(aliased ? SkFont::Edging::kAlias : unhinted
                ? SkFont::Edging::kAntiAlias : SkFont::Edging::kSubpixelAntiAlias);
        font.setHinting(unhinted ? SkFontHinting::kNone : SkFontHinting::kSlight);
        // Exercise real GG declines and a callback that writes before declining.
        bool unsupported = bold || aliased;
        font.setEmbolden(bold);
        corrupt_then_decline = i % 47 == 46;
        auto clip = corrupt_then_decline ? clips[0] : clips[i % 8];
        auto visible = SkIRect::MakeWH(tile_width, tile_height);
        bool empty = !visible.intersect(clip);
        SkTextBlobBuilder builder;
        auto const& buffer = builder.allocRunPos(font, 5);
        for (int g = 0; g < 5; ++g) {
            buffer.glyphs[g] = uint16_t(36 + (g + i) % 25);
            buffer.pos[g * 2] = float(g) * (7.25f + float(i % 7));
            buffer.pos[g * 2 + 1] = float(g % 2) * .3125f;
        }
        auto blob = builder.make();
        SkPaint paint;
        paint.setColor(SkColorSetARGB(i % 4 == 0 ? 128 : 255, (i * 29) % 256,
            (i * 11) % 256, (i * 53) % 256));
        bool shader = i % 43 == 42, float_color = i % 59 == 58;
        bool perspective = i % 61 == 60, lcd_geometry = i % 67 == 66;
        if (shader) paint.setShader(SkShaders::Color(SK_ColorGREEN));
        if (float_color) paint.setColor(SkColor4f{.1f, .2f, .3f, 1.f}, nullptr);
        SkSurfaceProps props(0, lcd_geometry ? kRGB_H_SkPixelGeometry : kUnknown_SkPixelGeometry,
            0, unhinted ? 1.f : 0.f);
        auto original = backdrop(i);
        std::vector<uint8_t> expected, actual;
        auto matrix = matrices[(i / 8) % 4];
        if (perspective) matrix.setPerspX(.0003f);
        bool native_reject = shader || float_color || perspective || lcd_geometry;
        double scale = (i / 32) % 2 ? 2 : 1;
        if (!render(original, expected, matrix, blob.get(), paint, props, clip, false, scale))
            return 3;
        attempts = drawn = 0;
        if (!render(original, actual, matrix, blob.get(), paint, props, clip, true, scale))
            return 3;
        bool fallback = unsupported || corrupt_then_decline || native_reject;
        if (expected != actual || attempts != int(!empty && !native_reject)
            || drawn != int(!empty && !fallback)) {
            std::fprintf(stderr, "case %d failed: pixels=%s attempts=%d drawn=%d empty=%d fallback=%d\n",
                i, expected == actual ? "equal" : "different", attempts, drawn, empty,
                fallback);
            return 1;
        }
        total_attempts += attempts;
        total_drawn += drawn;
        fully_clipped += empty;
        fallbacks += !empty && fallback;
        changed += original != actual;
    }
    if (!total_drawn || !changed) return 4;
    std::printf("clipped glyphs: %d exact, %d GG attempts, %d GG drawn, %d fallbacks, %d fully clipped, %d changed tiles\n",
        count, total_attempts, total_drawn, fallbacks, fully_clipped, changed);
    return 0;
}
