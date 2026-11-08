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

#include "include/core/SkRRect.h"
#include "include/core/SkPath.h"
#include "include/core/SkSurface.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkImage.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPixmap.h"
#include "include/core/SkSamplingOptions.h"

ORACLE void oracle_mipmap(uint8_t const* source, uint8_t* pixels, int const* v) {
    auto info = SkImageInfo::Make(v[0], v[1], kRGBA_8888_SkColorType, kPremul_SkAlphaType);
    auto image = SkImages::RasterFromPixmapCopy(SkPixmap(info, source, v[2]));
    auto surface = SkSurfaces::Raster(SkImageInfo::Make(v[3], v[4], kRGBA_8888_SkColorType, kPremul_SkAlphaType));
    auto canvas = surface->getCanvas();
    canvas->scale(float(v[3])/v[0], float(v[4])/v[1]);
    SkPaint paint; paint.setBlendMode(SkBlendMode::kSrc);
    canvas->drawImage(image.get(), 0, 0, SkSamplingOptions(SkFilterMode::kNearest, SkMipmapMode::kNearest), &paint);
    surface->readPixels(SkImageInfo::Make(v[3], v[4], kRGBA_8888_SkColorType, kPremul_SkAlphaType), pixels, v[3]*4, 0, 0);
}
#include "include/core/SkCanvas.h"

static SkRRect oracle_rrect(float const* f) {
    SkVector radii[4];
    for (int i = 0; i < 4; ++i) radii[i] = {f[4 + i*2], f[5 + i*2]};
    SkRRect r;
    r.setRectRadii(SkRect::MakeLTRB(f[0], f[1], f[2], f[3]), radii);
    return r;
}

ORACLE void oracle_rounded_rect(float const* f, int* info, float* out) {
    auto r = oracle_rrect(f);
    auto b = r.rect();
    out[0] = b.left(); out[1] = b.top(); out[2] = b.right(); out[3] = b.bottom();
    for (int i = 0; i < 4; ++i) {
        auto radius = r.radii(static_cast<SkRRect::Corner>(i));
        out[4 + i*2] = radius.x(); out[5 + i*2] = radius.y();
    }
    auto path = SkPath::RRect(r);
    uint8_t verbs[32];
    SkPoint points[32];
    info[0] = path.getVerbs({verbs, 32});
    info[1] = path.getPoints({points, 32});
    for (int i = 0; i < info[0]; ++i) info[3 + i] = verbs[i];
    for (int i = 0; i < info[1]; ++i) {
        out[12 + i*2] = points[i].x(); out[13 + i*2] = points[i].y();
    }
    int count = 0;
    for (auto weight : path.conicWeights()) out[12 + info[1]*2 + count++] = weight;
    info[2] = count;
}

ORACLE void oracle_difference_clip(uint8_t* pixels, int const* v, float const* f) {
    auto info = SkImageInfo::Make(v[0], v[1], kRGBA_8888_SkColorType, kPremul_SkAlphaType);
    auto surface = SkSurfaces::Raster(info);
    auto canvas = surface->getCanvas();
    for (int i = 0; i < 2; ++i) {
        auto s = f + i*18;
        auto m = s + 12;
        canvas->setMatrix(SkMatrix::MakeAll(m[0], m[2], m[4], m[1], m[3], m[5], 0, 0, 1));
        canvas->clipRRect(oracle_rrect(s), i ? SkClipOp::kDifference : SkClipOp::kIntersect, true);
    }
    canvas->resetMatrix();
    canvas->clear(SK_ColorWHITE);
    surface->readPixels(info, pixels, v[0]*4, 0, 0);
}

#if defined(CPURASTER_FREETYPE_ORACLE) && defined(__APPLE__)
// Keep the original canvas calls while selecting the FreeType face factory
// used on Linux. Include CoreText's declaration before replacing its calls.
#include "include/ports/SkFontMgr_mac_ct.h"
#include "include/ports/SkFontMgr_empty.h"
#define SkFontMgr_New_CoreText(...) SkFontMgr_New_Custom_Empty()
#endif
#include "../../skia/shadow_raster.cpp"

static VoxShadowRect oracle_shadow_rect(float const* f) {
    VoxShadowRect r{};
    for (int i = 0; i < 4; ++i) r.rect[i] = f[i];
    for (int i = 0; i < 8; ++i) r.radii[i] = f[4 + i];
    return r;
}

ORACLE int oracle_outer_shadow(uint8_t* pixels, int const* v, float const* f) {
    VoxShadowCommand command{};
    command.color = uint32_t(v[2]);
    command.outer = oracle_shadow_rect(f);
    command.content = oracle_shadow_rect(f + 12);
    for (int i = 0; i < 6; ++i) command.transform[i] = f[24 + i];
    command.blur = f[30];
    std::vector<VoxShadowClip> clips;
    for (int i = 0; i < v[3]; ++i) {
        auto c = f + 31 + i*18;
        VoxShadowClip clip{};
        clip.shape = oracle_shadow_rect(c);
        for (int j = 0; j < 6; ++j) clip.transform[j] = c[12 + j];
        clips.push_back(clip);
    }
    command.clips = clips.data();
    command.clip_count = int(clips.size());
    return vox_skia_shadow(pixels, v[0], v[1], v[0]*4, &command);
}

ORACLE int oracle_inner_shadow(uint8_t* pixels, int const* v, float const* f) {
    VoxShadowCommand command{};
    command.kind = 1;
    command.color = uint32_t(v[2]);
    command.outer = oracle_shadow_rect(f);
    command.inner = oracle_shadow_rect(f + 12);
    command.content = oracle_shadow_rect(f + 24);
    for (int i = 0; i < 6; ++i) command.transform[i] = f[36 + i];
    command.blur = f[42];
    return vox_skia_shadow(pixels, v[0], v[1], v[0]*4, &command);
}

ORACLE void oracle_inner_shadow_path(float const* f, int* info, float* out) {
    SkPath path;
    Op(SkPath::RRect(shadow_rrect(oracle_shadow_rect(f))),
       SkPath::RRect(shadow_rrect(oracle_shadow_rect(f + 12))),
       SkPathOp::kDifference_SkPathOp, &path);
    uint8_t verbs[64]; SkPoint points[64];
    info[0] = path.getVerbs({verbs, 64});
    info[1] = path.getPoints({points, 64});
    info[2] = int(path.getFillType());
    for (int i = 0; i < info[0]; ++i) info[3+i] = verbs[i];
    for (int i = 0; i < info[1]; ++i) { out[i*2] = points[i].x(); out[i*2+1] = points[i].y(); }
    int n = 0;
    for (auto weight : path.conicWeights()) out[info[1]*2 + n++] = weight;
}

ORACLE int oracle_text_shadow(uint8_t* pixels, int const* v, float const* f, char const* font, uint16_t const* glyphs, float const* positions) {
    VoxShadowCommand command{};
    command.kind = 2;
    command.color = uint32_t(v[2]);
    command.glyph_count = v[3];
    command.font_smoothing = v[4];
    command.face_index = v[5];
    for (int i = 0; i < 6; ++i) command.transform[i] = f[i];
    command.blur = f[6]; command.font_size = f[7];
    command.translation[0] = f[8]; command.translation[1] = f[9];
    command.font_path = font;
    command.glyphs = glyphs; command.positions = positions;
    std::vector<VoxShadowClip> clips;
    for (int i = 0; i < v[6]; ++i) {
        auto c = f + 10 + i*18;
        VoxShadowClip clip{};
        clip.shape = oracle_shadow_rect(c);
        for (int j = 0; j < 6; ++j) clip.transform[j] = c[12+j];
        clips.push_back(clip);
    }
    command.clips = clips.data(); command.clip_count = int(clips.size());
    return vox_skia_shadow(pixels, v[0], v[1], v[0]*4, &command);
}

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
#if defined(__APPLE__)
#include "include/ports/SkFontMgr_mac_ct.h"
#else
#include "include/ports/SkFontMgr_empty.h"
#endif

ORACLE int oracle_font_typeface_is_valid(uint8_t const* bytes, size_t size, int index)
{
#ifdef __APPLE__
    static auto manager = SkFontMgr_New_CoreText(nullptr);
#else
    static auto manager = SkFontMgr_New_Custom_Empty();
#endif
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
static void oracle_draw_path(uint8_t* pixels, int const* a, float const* f, bool anti_alias);

ORACLE void oracle_fill_path(uint8_t* pixels, int const* a, float const* f)
{
    oracle_draw_path(pixels, a, f, true);
}

// The same, without anti-aliasing: SkScan::FillPath.
ORACLE void oracle_fill_path_bw(uint8_t* pixels, int const* a, float const* f)
{
    oracle_draw_path(pixels, a, f, false);
}

static void oracle_draw_path(uint8_t* pixels, int const* a, float const* f, bool anti_alias)
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
    paint.setAntiAlias(anti_alias);
    paint.setColor(SkColor(uint32_t(a[4])));
    canvas->drawPath(builder.detach(), paint);
}

// The production Canvas2D raster path (skia/canvas_raster.cpp).
#include "../../skia/canvas_raster.cpp"

ORACLE void oracle_canvas_path_geometry(float const* segments, int const* args,
                                       uint8_t* verbs, float* points, float* weights, int* info) {
    auto path = make_path(VoxCanvasPath{segments, args[0], args[1]});
    info[0] = path.getVerbs({verbs, args[2]});
    info[1] = path.getPoints({reinterpret_cast<SkPoint*>(points), args[2]});
    info[2] = 0;
    for (float weight : path.conicWeights()) weights[info[2]++] = weight;
}

#include <vector>

static uint8_t const* oracle_pattern_pixels = nullptr;

// The pixels of the next pattern style.
ORACLE void oracle_pattern(uint8_t const* pixels)
{
    oracle_pattern_pixels = pixels;
}

static std::vector<VoxCanvasFilter> oracle_filter_list;

// The canvas filters of the next fill, stroke or glyph run: per filter its
// kind, clamp flag and SkColor in values, and its radius, offsets and 20
// matrix entries in floats.
ORACLE void oracle_filters(int count, int const* values, float const* floats)
{
    oracle_filter_list.clear();
    for (int i = 0; i < count; ++i) {
        VoxCanvasFilter filter {};
        filter.kind = values[i * 3];
        filter.clamp = values[i * 3 + 1];
        filter.color = uint32_t(values[i * 3 + 2]);
        filter.radius = floats[i * 23];
        filter.offset_x = floats[i * 23 + 1];
        filter.offset_y = floats[i * 23 + 2];
        for (int j = 0; j < 20; ++j)
            filter.matrix[j] = floats[i * 23 + 3 + j];
        oracle_filter_list.push_back(filter);
    }
}

// Installs and consumes the pending filters.
static void oracle_take_filters(VoxCanvasCommand& command, std::vector<VoxCanvasFilter>& storage)
{
    storage = std::move(oracle_filter_list);
    oracle_filter_list.clear();
    command.filters = storage.data();
    command.filter_count = int(storage.size());
}

// An optional style after the other arguments: ints are its kind (0 for the
// solid color), then a gradient's stop count, with floats x0, y0, r0, x1,
// y1, r1, the angle and 5 floats per stop, or a pattern's width, height,
// pitch, alpha type, color space and repetition, with its transform.
static void oracle_style(VoxCanvasStyle& style, int const* a, float const* f)
{
    if (a[0] == 0)
        return;
    style.kind = a[0];
    if (a[0] == 4) {
        style.pattern = oracle_pattern_pixels;
        style.pattern_width = a[1];
        style.pattern_height = a[2];
        style.pattern_pitch = a[3];
        style.pattern_alpha = a[4];
        style.pattern_color_space = a[5];
        style.repetition = a[6];
        for (int i = 0; i < 6; ++i)
            style.pattern_transform[i] = f[i];
        return;
    }
    style.stop_count = a[1];
    style.x0 = f[0];
    style.y0 = f[1];
    style.r0 = f[2];
    style.x1 = f[3];
    style.y1 = f[4];
    style.r1 = f[5];
    style.angle = f[6];
    style.stops = f + 7;
}

// Device-space clip paths: ints hold the clip count, then a segment count and
// even-odd flag per clip; floats hold their segments back to back.
// The number of floats the clips' segments take.
static int oracle_clip_floats(int const* a)
{
    int count = 0;
    for (int i = 0; i < a[0]; ++i)
        count += a[1 + i * 2] * 12;
    return count;
}

static std::vector<VoxCanvasPath> oracle_clips(int const* a, float const* f)
{
    std::vector<VoxCanvasPath> clips;
    for (int i = 0; i < a[0]; ++i) {
        clips.push_back({ f, a[1 + i * 2], a[2 + i * 2] });
        f += a[1 + i * 2] * 12;
    }
    return clips;
}

// arguments: width, height, pitch, alpha type, even-odd, segment count,
// SkColor, the clips, the composite operation, then the style's ints.
// floats: the transform, global alpha, 12 floats per segment, the clip
// segments, the shadow blur, then the style's floats.
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
    auto clips = oracle_clips(a + 7, f + 7 + a[5] * 12);
    command.clips = clips.data();
    command.clip_count = int(clips.size());
    command.composite = a[8 + a[7] * 2];
    command.blur = f[7 + a[5] * 12 + oracle_clip_floats(a + 7)];
    oracle_style(command.style, a + 9 + a[7] * 2, f + 8 + a[5] * 12 + oracle_clip_floats(a + 7));
    std::vector<VoxCanvasFilter> filters;
    oracle_take_filters(command, filters);
    return vox_skia_canvas_path(pixels, a[0], a[1], a[2], a[3], &command);
}

// arguments: width, height, pitch, alpha type, segment count, SkColor, cap,
// join, dash count, the clips, the composite operation, then the style's
// ints. floats: the transform, global alpha, line width, miter limit, 12 floats
// per segment, the dash offset and intervals, the clip segments, the shadow
// blur, then the style's floats.
ORACLE int oracle_canvas_stroke(uint8_t* pixels, int const* a, float const* f)
{
    VoxCanvasCommand command {};
    command.operation = 0;
    command.path = { f + 9, a[4], 0 };
    command.dash_offset = f[9 + a[4] * 12];
    command.dashes = f + 10 + a[4] * 12;
    command.dash_count = a[8];
    auto clips = oracle_clips(a + 9, f + 10 + a[4] * 12 + a[8]);
    command.clips = clips.data();
    command.clip_count = int(clips.size());
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
    command.composite = a[10 + a[9] * 2];
    command.blur = f[10 + a[4] * 12 + a[8] + oracle_clip_floats(a + 9)];
    oracle_style(command.style, a + 11 + a[9] * 2, f + 11 + a[4] * 12 + a[8] + oracle_clip_floats(a + 9));
    std::vector<VoxCanvasFilter> filters;
    oracle_take_filters(command, filters);
    return vox_skia_canvas_path(pixels, a[0], a[1], a[2], a[3], &command);
}

// A bitmap command. arguments: width, height, pitch, alpha type, operation,
// smoothing, the clips, the composite operation, the style's SkColor, then
// the image's width (0 for none), height, pitch, alpha type and color space.
// floats: the transform, global alpha, destination and source rects, then
// the clip segments. The image's pixels come from oracle_pattern().
static int oracle_canvas_bitmap_impl(uint8_t* pixels, int const* a, float const* f, bool chromium)
{
    VoxCanvasCommand command {};
    std::vector<VoxCanvasFilter> filters;
    oracle_take_filters(command, filters);
    command.operation = a[4];
    command.smoothing = a[5];
    auto clips = oracle_clips(a + 6, f + 15);
    command.clips = clips.data();
    command.clip_count = int(clips.size());
    int const* rest = a + 7 + a[6] * 2;
    command.composite = rest[0];
    command.style.color = uint32_t(rest[1]);
    if (rest[2] > 0) {
        command.style.kind = 4;
        command.style.pattern = oracle_pattern_pixels;
        command.style.pattern_width = rest[2];
        command.style.pattern_height = rest[3];
        command.style.pattern_pitch = rest[4];
        command.style.pattern_alpha = rest[5];
        command.style.pattern_color_space = rest[6];
    }
    for (int i = 0; i < 6; ++i)
        command.transform[i] = f[i];
    command.global_alpha = f[6];
    for (int i = 0; i < 4; ++i) {
        command.destination[i] = f[7 + i];
        command.source[i] = f[11 + i];
    }
    if (!chromium)
        return vox_skia_canvas_path(pixels, a[0], a[1], a[2], a[3], &command);
    // Exercise the bitmap-space command policy on the pinned CPU reference.
    // This does not stand in for the separate Graphite/Dawn GPU comparison.
    auto source_info = SkImageInfo::Make(a[0], a[1], kRGBA_8888_SkColorType,
        a[3] == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto info = source_info.makeAlphaType(kPremul_SkAlphaType);
    auto surface = SkSurfaces::Raster(info);
    return surface && surface->getCanvas()->writePixels(source_info, pixels, a[2], 0, 0)
        && draw_canvas_command(surface->getCanvas(), a[0], a[1], &command, true)
        && surface->readPixels(info, pixels, a[2], 0, 0);
}

ORACLE int oracle_canvas_bitmap(uint8_t* pixels, int const* a, float const* f) {
    return oracle_canvas_bitmap_impl(pixels, a, f, false);
}

ORACLE int oracle_canvas_bitmap_chromium(uint8_t* pixels, int const* a, float const* f) {
    return oracle_canvas_bitmap_impl(pixels, a, f, true);
}

// A fillText() glyph run. arguments: width, height, pitch, alpha type, the
// style's SkColor, glyph count, face index, the clips, the composite
// operation, then the style's ints. floats: the transform, global alpha,
// font size, the blob's origin, x and y per glyph, the clip segments, then
// the style's floats.
ORACLE int oracle_canvas_glyphs(uint8_t* pixels, char const* font_path, uint16_t const* glyphs, int const* a, float const* f)
{
    VoxCanvasCommand command {};
    command.style.color = uint32_t(a[4]);
    for (int i = 0; i < 6; ++i)
        command.transform[i] = f[i];
    command.global_alpha = f[6];
    int count = a[5];
    float const* positions = f + 10;
    auto clips = oracle_clips(a + 7, positions + count * 2);
    command.clips = clips.data();
    command.clip_count = int(clips.size());
    command.composite = a[8 + a[7] * 2];
    oracle_style(command.style, a + 9 + a[7] * 2, positions + count * 2 + oracle_clip_floats(a + 7));
    VoxCanvasGlyphRun run {};
    run.font_path = font_path;
    run.face_index = a[6];
    run.count = count;
    run.font_size = f[7];
    run.translation[0] = f[8];
    run.translation[1] = f[9];
    run.glyphs = glyphs;
    run.positions = positions;
    std::vector<VoxCanvasFilter> filters;
    oracle_take_filters(command, filters);
    return vox_skia_canvas_glyphs(pixels, a[0], a[1], a[2], a[3], &command, &run);
}

// SkImages::MakeWithFilter() with SkImageFilters::Blur() on a premultiplied
// RGBA_8888 sRGB image. arguments: width, height, then the subset and clip
// rects (left, top, right, bottom). floats: sigma x and y. info receives
// whether a result came back, its width, height and offset; out its rows.
#include "include/core/SkImageFilter.h"
#include "include/effects/SkImageFilters.h"

ORACLE void oracle_image_blur(uint8_t const* pixels, int const* a, float const* f, uint8_t* out, int* info)
{
    auto image_info = SkImageInfo::Make(a[0], a[1], kRGBA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto image = SkImages::RasterFromPixmapCopy(SkPixmap(image_info, pixels, size_t(a[0]) * 4));
    auto filter = SkImageFilters::Blur(f[0], f[1], nullptr);
    info[0] = 0;
    if (!image || !filter)
        return;
    SkIRect out_subset;
    SkIPoint offset;
    auto result = SkImages::MakeWithFilter(image, filter.get(), SkIRect::MakeLTRB(a[2], a[3], a[4], a[5]),
        SkIRect::MakeLTRB(a[6], a[7], a[8], a[9]), &out_subset, &offset);
    if (!result)
        return;
    auto subset = result->makeSubset(nullptr, out_subset, {});
    if (!subset)
        return;
    auto out_info = SkImageInfo::Make(subset->width(), subset->height(), kRGBA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    if (!subset->readPixels(nullptr, out_info, out, size_t(subset->width()) * 4, 0, 0))
        return;
    info[0] = 1;
    info[1] = subset->width();
    info[2] = subset->height();
    info[3] = offset.x();
    info[4] = offset.y();
}
