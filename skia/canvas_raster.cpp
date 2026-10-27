// Native ABI adaptation of LibGfx/CanvasCommandPlayer.cpp, PainterSkia.cpp,
// PathSkia.cpp and SkiaUtils.cpp. The source command construction remains V.
#include "canvas_raster.h"
#include "include/core/SkBitmap.h"
#include "include/core/SkBlender.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkColorFilter.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkImage.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkTextBlob.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkShader.h"
#include "include/core/SkSurface.h"
#include "include/effects/SkBlurMaskFilter.h"
#include "include/effects/SkDashPathEffect.h"
#include "include/effects/SkGradientShader.h"
#include "include/effects/SkImageFilters.h"
#include "include/effects/SkRuntimeEffect.h"
#include <cmath>
#include <vector>
#ifdef __APPLE__
#include "include/ports/SkFontMgr_mac_ct.h"
#else
#include "include/ports/SkFontMgr_empty.h"
#endif

static SkPath make_path(VoxCanvasPath const& input)
{
#ifdef __linux__
    SkPathBuilder path;
#else
    SkPath path;
#endif
    for (int i = 0; i < input.count; ++i) {
        auto const* segment = input.segments + i * 12;
        switch (int(segment[0])) {
        case 0:
            path.moveTo(segment[1], segment[2]);
            break;
        case 1:
            path.lineTo(segment[1], segment[2]);
            break;
        case 2:
            path.quadTo(segment[3], segment[4], segment[1], segment[2]);
            break;
        case 3:
            path.cubicTo(segment[3], segment[4], segment[5], segment[6], segment[1], segment[2]);
            break;
        case 4:
#ifdef __linux__
            path.arcTo(SkPoint{segment[7], segment[8]}, segment[9] * 180.0f / float(M_PI), segment[10] ? SkPathBuilder::kLarge_ArcSize : SkPathBuilder::kSmall_ArcSize,
                segment[11] ? SkPathDirection::kCW : SkPathDirection::kCCW, SkPoint{segment[1], segment[2]});
#else
            path.arcTo(segment[7], segment[8], segment[9] * 180.0f / float(M_PI), segment[10] ? SkPath::kLarge_ArcSize : SkPath::kSmall_ArcSize,
                segment[11] ? SkPathDirection::kCW : SkPathDirection::kCCW, segment[1], segment[2]);
#endif
            break;
        case 5:
            path.close();
            break;
        }
    }
    path.setFillType(input.even_odd ? SkPathFillType::kEvenOdd : SkPathFillType::kWinding);
#ifdef __linux__
    return path.detach();
#else
    return path;
#endif
}

static SkMatrix make_matrix(float const* v) { return SkMatrix::MakeAll(v[0], v[2], v[4], v[1], v[3], v[5], 0, 0, 1); }

static sk_sp<SkBlender> make_blender(int operation)
{
    static SkBlendMode const modes[] = { SkBlendMode::kSrcOver, SkBlendMode::kSrcIn, SkBlendMode::kSrcOut, SkBlendMode::kSrcATop, SkBlendMode::kDstOver,
        SkBlendMode::kDstIn, SkBlendMode::kDstOut, SkBlendMode::kDstATop, SkBlendMode::kPlus, SkBlendMode::kSrc, SkBlendMode::kXor, SkBlendMode::kMultiply,
        SkBlendMode::kScreen, SkBlendMode::kOverlay, SkBlendMode::kDarken, SkBlendMode::kLighten, SkBlendMode::kColorDodge, SkBlendMode::kColorBurn,
        SkBlendMode::kHardLight, SkBlendMode::kSoftLight, SkBlendMode::kDifference, SkBlendMode::kExclusion, SkBlendMode::kHue, SkBlendMode::kSaturation,
        SkBlendMode::kColor, SkBlendMode::kLuminosity };
    if (operation >= 0 && operation < 26)
        return SkBlender::Mode(modes[operation]);
    // SkiaUtils.cpp retains the upstream Safari-compatible plus-darker rule.
    auto result = SkRuntimeEffect::MakeForBlender(
        SkString(operation == 26 ? "vec4 main(vec4 source,vec4 destination){return "
                                   "saturate(saturate(destination.a+source.a)-saturate(destination.a-destination)-saturate(source.a-source));}"
                                 : "vec4 main(vec4 source,vec4 destination){return saturate(source+destination);}"));
    return result.effect ? result.effect->makeBlender(nullptr) : nullptr;
}

static bool apply_style(SkPaint& paint, VoxCanvasStyle const& style)
{
    if (style.kind == 0) {
        paint.setColor(style.color);
        return true;
    }
    if (style.kind == 4) {
        auto space = SkColorSpace::MakeSRGB();
        if (style.pattern_color_space == 1)
            space = SkColorSpace::MakeRGB(SkNamedTransferFn::kSRGB, SkNamedGamut::kDisplayP3);
        auto info = SkImageInfo::Make(
            style.pattern_width, style.pattern_height, kRGBA_8888_SkColorType, style.pattern_alpha == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, space);
        SkBitmap bitmap;
        if (!bitmap.installPixels(info, const_cast<uint8_t*>(style.pattern), style.pattern_pitch))
            return false;
        bitmap.setImmutable();
        auto image = bitmap.asImage();
        if (!image)
            return false;
        auto matrix = make_matrix(style.pattern_transform);
        bool repeat_x = style.repetition == 0 || style.repetition == 1;
        bool repeat_y = style.repetition == 0 || style.repetition == 2;
        paint.setShader(image->makeShader(repeat_x ? SkTileMode::kRepeat : SkTileMode::kDecal, repeat_y ? SkTileMode::kRepeat : SkTileMode::kDecal,
            SkSamplingOptions(SkFilterMode::kLinear), &matrix));
        return true;
    }
    std::vector<SkColor4f> colors;
    std::vector<float> positions;
    for (int i = 0; i < style.stop_count; ++i) {
        auto const* stop = style.stops + i * 5;
        positions.push_back(stop[0]);
        colors.push_back({ stop[1], stop[2], stop[3], stop[4] });
    }
    SkGradientShader::Interpolation interpolation;
    sk_sp<SkShader> shader;
    auto matrix = SkMatrix::I();
    if (style.kind == 1) {
        SkPoint points[2] = { { style.x0, style.y0 }, { style.x1, style.y1 } };
        shader = SkGradientShader::MakeLinear(points, colors.data(), nullptr, positions.data(), int(colors.size()), SkTileMode::kClamp, interpolation, &matrix);
    } else if (style.kind == 2) {
        shader = SkGradientShader::MakeTwoPointConical({ style.x0, style.y0 }, style.r0, { style.x1, style.y1 }, style.r1, colors.data(), nullptr,
            positions.data(), int(colors.size()), SkTileMode::kClamp, interpolation, &matrix);
    } else if (style.kind == 3) {
        float degrees = style.angle * 180.0f / float(M_PI);
        shader = SkGradientShader::MakeSweep(style.x0, style.y0, colors.data(), nullptr, positions.data(), int(colors.size()), SkTileMode::kClamp, degrees,
            degrees + 360.0f, interpolation, &matrix);
    }
    // Preserve PainterSkia: a failed/empty shader is installed as returned.
    paint.setShader(shader);
    return true;
}

static sk_sp<SkImageFilter> transparent_filter()
{
    float matrix[20] = {};
    return SkImageFilters::ColorFilter(SkColorFilters::Matrix(matrix), nullptr);
}

static sk_sp<SkImageFilter> make_svg_filter(VoxCanvasFilter const& filter, sk_sp<SkImageFilter> source, SkRect bounds)
{
    std::vector<sk_sp<SkImageFilter>> outputs;
    float scale_x = filter.graph_primitive_bounds ? bounds.width() : 1;
    float scale_y = filter.graph_primitive_bounds ? bounds.height() : 1;
    for (int i = 0; i < filter.graph_count; ++i) {
        auto const& node = filter.graph_nodes[i];
        std::vector<sk_sp<SkImageFilter>> inputs;
        for (int j = 0; j < node.input_count; ++j) {
            int id = node.inputs[j];
            if (id < -1 || id >= i)
                return source;
            inputs.push_back(id == -1 ? source : outputs[id]);
        }
        auto input = inputs.empty() ? source : inputs[0];
        sk_sp<SkImageFilter> result;
        switch (node.kind) {
        case 0:
            // Negative standard deviations disable the primitive.
            if (node.x < 0 || node.y < 0)
                result = input;
            else
                result = SkImageFilters::Blur(node.x * scale_x, node.y * scale_y, SkTileMode::kDecal, input);
            break;
        case 1:
        case 2:
            if (node.x < 0 || node.y < 0)
                result = input;
            else if (node.kind == 1)
                result = SkImageFilters::Erode(node.x * scale_x, node.y * scale_y, input);
            else
                result = SkImageFilters::Dilate(node.x * scale_x, node.y * scale_y, input);
            break;
        case 3:
            result = inputs.empty() ? transparent_filter() : SkImageFilters::Merge(inputs.data(), int(inputs.size()));
            break;
        case 4:
            result = SkImageFilters::Offset(node.x * scale_x, node.y * scale_y, input);
            break;
        case 5:
            result = SkImageFilters::ColorFilter(SkColorFilters::SRGBToLinearGamma(), input);
            break;
        case 6:
            result = SkImageFilters::ColorFilter(SkColorFilters::LinearToSRGBGamma(), input);
            break;
        case 7:
            result = SkImageFilters::ColorFilter(SkColorFilters::Matrix(node.matrix), input);
            break;
        default:
            return source;
        }
        outputs.push_back(std::move(result));
    }
    if (filter.graph_root < -1 || filter.graph_root >= filter.graph_count)
        return source;
    auto result = filter.graph_root == -1 ? source : outputs[filter.graph_root];
    auto const* region = filter.graph_region;
    auto crop = filter.graph_object_bounds
        ? SkRect::MakeXYWH(bounds.x() + region[0] * bounds.width(), bounds.y() + region[1] * bounds.height(),
              region[2] * bounds.width(), region[3] * bounds.height())
        : SkRect::MakeXYWH(region[0], region[1], region[2], region[3]);
    if (crop.isEmpty())
        return transparent_filter();
    return SkImageFilters::Crop(crop, SkTileMode::kDecal, std::move(result));
}

static sk_sp<SkImageFilter> make_filter(VoxCanvasCommand const& command, SkRect bounds)
{
    sk_sp<SkImageFilter> input;
    bool has_svg_reference = false;
    for (int i = 0; i < command.filter_count; ++i) {
        auto const& filter = command.filters[i];
        if (filter.kind == 0)
            input = SkImageFilters::Blur(filter.radius, filter.radius, input);
        else if (filter.kind == 1)
            input = SkImageFilters::DropShadow(filter.offset_x, filter.offset_y, filter.radius, filter.radius, filter.color, input);
        else if (filter.kind == 3) {
            has_svg_reference = true;
            input = make_svg_filter(filter, input, bounds);
        }
        else
            input = SkImageFilters::ColorFilter(
                SkColorFilters::Matrix(filter.matrix, filter.clamp ? SkColorFilters::Clamp::kYes : SkColorFilters::Clamp::kNo), input);
    }
    // Canvas SVG filter coordinates use the output bitmap, independently of
    // the drawing transform. SourceGraphic still receives that transform.
    if (input && has_svg_reference) {
        SkMatrix inverse;
        if (make_matrix(command.transform).invert(&inverse))
            input = input->makeWithLocalMatrix(inverse);
    }
    return input;
}

extern "C" bool vox_skia_canvas_path(uint8_t* pixels, int width, int height, int pitch, int alpha_type, VoxCanvasCommand const* command)
{
    auto source_info
        = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, alpha_type == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto info = source_info.makeAlphaType(kPremul_SkAlphaType);
    auto surface = SkSurfaces::Raster(info);
    if (!surface || !surface->getCanvas()->writePixels(source_info, pixels, pitch, 0, 0))
        return false;
    auto* canvas = surface->getCanvas();
    // Clips were captured in device space by Canvas2DContextBase::clip.
    for (int i = 0; i < command->clip_count; ++i)
        canvas->clipPath(make_path(command->clips[i]), SkClipOp::kIntersect, true);
    canvas->setMatrix(make_matrix(command->transform));
    auto destination_rect = SkRect::MakeXYWH(command->destination[0], command->destination[1], command->destination[2], command->destination[3]);
    if (command->operation == 1) {
        canvas->save();
        canvas->clipRect(destination_rect);
        canvas->clear(command->style.color);
        canvas->restore();
        return surface->readPixels(info, pixels, pitch, 0, 0);
    }
    SkPaint paint;
    if (command->operation == 2) {
        auto const& source = command->style;
        auto space = SkColorSpace::MakeSRGB();
        if (source.pattern_color_space == 1)
            space = SkColorSpace::MakeRGB(SkNamedTransferFn::kSRGB, SkNamedGamut::kDisplayP3);
        auto image_info = SkImageInfo::Make(source.pattern_width, source.pattern_height, kRGBA_8888_SkColorType,
            source.pattern_alpha == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, space);
        SkBitmap bitmap;
        if (!bitmap.installPixels(image_info, const_cast<uint8_t*>(source.pattern), source.pattern_pitch))
            return false;
        bitmap.setImmutable();
        auto image = bitmap.asImage();
        if (!image)
            return false;
        paint.setImageFilter(make_filter(*command, SkRect::MakeWH(width, height)));
        paint.setAlpha(static_cast<uint8_t>(command->global_alpha * 255));
        paint.setBlender(make_blender(command->composite));
        auto source_rect = SkRect::MakeXYWH(command->source[0], command->source[1], command->source[2], command->source[3]);
        auto sampling = command->smoothing ? SkSamplingOptions(SkFilterMode::kLinear, SkMipmapMode::kLinear) : SkSamplingOptions(SkFilterMode::kNearest);
        canvas->drawImageRect(image.get(), source_rect, destination_rect, sampling, &paint, SkCanvas::kStrict_SrcRectConstraint);
        return surface->readPixels(info, pixels, pitch, 0, 0);
    }
    if (!apply_style(paint, command->style))
        return false;
    paint.setAntiAlias(true);
    // CanvasCommandPlayer selects the blurred solid-color overload for shadows.
    if (command->blur > 0 && command->style.kind == 0)
        paint.setMaskFilter(SkMaskFilter::MakeBlur(kNormal_SkBlurStyle, command->blur / 2));
    else {
        paint.setAlphaf(paint.getAlphaf() * command->global_alpha);
        paint.setImageFilter(make_filter(*command, SkRect::MakeWH(width, height)));
    }
    paint.setBlender(make_blender(command->composite));
    if (command->stroke) {
        if (command->width <= 0)
            return true;
        paint.setStyle(SkPaint::kStroke_Style);
        paint.setStrokeWidth(command->width);
        paint.setStrokeCap(command->cap == 0 ? SkPaint::kButt_Cap : command->cap == 1 ? SkPaint::kRound_Cap : SkPaint::kSquare_Cap);
        paint.setStrokeJoin(command->join == 0 ? SkPaint::kRound_Join : command->join == 1 ? SkPaint::kBevel_Join : SkPaint::kMiter_Join);
        paint.setStrokeMiter(command->miter);
        paint.setPathEffect(SkDashPathEffect::Make({ command->dashes, size_t(command->dash_count) }, command->dash_offset));
    }
    canvas->drawPath(make_path(command->path), paint);
    return surface->readPixels(info, pixels, pitch, 0, 0);
}

extern "C" bool vox_skia_canvas_read_pixels(uint8_t const* source, int width, int height, int pitch, int alpha_type, uint8_t* destination, int destination_width, int destination_height, int destination_pitch, int x, int y)
{
    auto source_info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, alpha_type == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto destination_info = SkImageInfo::Make(destination_width, destination_height, kRGBA_8888_SkColorType, kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    SkBitmap bitmap;
    if (!bitmap.installPixels(source_info, const_cast<uint8_t*>(source), pitch))
        return false;
    return bitmap.readPixels(destination_info, destination, destination_pitch, x, y);
}

// CanvasCommandPlayer::DrawGlyphRun -> PainterSkia::draw_text_blob(). The
// resolver uses DisplayListResourceStorage's Unhinted text rasterization mode.
extern "C" bool vox_skia_canvas_glyphs(uint8_t* pixels, int width, int height, int pitch, int alpha_type, VoxCanvasCommand const* command, VoxCanvasGlyphRun const* glyphs)
{
    if (glyphs->count == 0)
        return true;
#ifdef __APPLE__
    static auto manager = SkFontMgr_New_CoreText(nullptr);
#else
    static auto manager = SkFontMgr_New_Custom_Empty();
#endif
    auto face = manager->makeFromFile(glyphs->font_path, glyphs->face_index);
    if (!face)
        return false;
    SkFont font(face, glyphs->font_size);
    font.setSubpixel(true);
    font.setHinting(SkFontHinting::kNone);
    font.setForceAutoHinting(false);
    font.setBaselineSnap(false);
    SkTextBlobBuilder builder;
    auto const& run = builder.allocRunPos(font, glyphs->count);
    for (int i = 0; i < glyphs->count; ++i) {
        run.glyphs[i] = glyphs->glyphs[i];
        run.pos[i * 2] = glyphs->positions[i * 2];
        run.pos[i * 2 + 1] = glyphs->positions[i * 2 + 1];
    }
    auto blob = builder.make();
    if (!blob)
        return true;
    auto source_info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, alpha_type == 2 ? kPremul_SkAlphaType : kUnpremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto info = source_info.makeAlphaType(kPremul_SkAlphaType);
    auto surface = SkSurfaces::Raster(info);
    if (!surface || !surface->getCanvas()->writePixels(source_info, pixels, pitch, 0, 0))
        return false;
    auto& canvas = *surface->getCanvas();
    for (int i = 0; i < command->clip_count; ++i)
        canvas.clipPath(make_path(command->clips[i]), SkClipOp::kIntersect, true);
    canvas.setMatrix(make_matrix(command->transform));
    SkPaint paint;
    if (!apply_style(paint, command->style))
        return false;
    paint.setImageFilter(make_filter(*command, SkRect::MakeWH(width, height)));
    paint.setAlphaf(paint.getAlphaf() * command->global_alpha);
    paint.setBlender(make_blender(command->composite));
    canvas.drawTextBlob(blob.get(), glyphs->translation[0], glyphs->translation[1], paint);
    return surface->readPixels(info, pixels, pitch, 0, 0);
}
