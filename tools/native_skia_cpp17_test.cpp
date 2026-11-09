// Compile the actual bridge sources, so local .o files cannot hide a clean-build failure.
#ifdef NDEBUG
#error "This regression test requires assertions"
#endif
#include "skia/canvas_raster.cpp"
#include "skia/shadow_raster.cpp"
#include <algorithm>
#include <cassert>
#include <cstdio>

int main()
{
    // The C++17 Skia constant must retain the exact float used by pi_v<float>.
    static_assert(SK_ScalarPI == 0x1.921fb6p+1f);
    float segments[] {
        0, 8, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        4, 24, 16, 0, 0, 0, 0, 12, 6, SK_ScalarPI / 4, 0, 1,
        5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    VoxCanvasPath input { segments, 3, 0 };
    SkPath expected;
    expected.moveTo(8, 16);
    expected.arcTo(12, 6, 45, SkPath::kSmall_ArcSize, SkPathDirection::kCW, 24, 16);
    expected.close();
    assert(make_path(input) == expected);
    assert(shadow_clip_path(input) == expected);

    constexpr int width = 32, height = 32, pitch = width * 4;
    std::vector<uint8_t> canvas_pixels(height * pitch), shadow_pixels(height * pitch), reference_pixels(height * pitch);
    VoxCanvasCommand command {};
    command.path = input;
    command.style.color = 0xffff0000;
    command.global_alpha = 1;
    command.transform[0] = command.transform[3] = 1;
    assert(vox_skia_canvas_path(canvas_pixels.data(), width, height, pitch, 2, &command));
    auto rgba_info = SkImageInfo::Make(width, height, kRGBA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
    auto canvas_reference = SkSurfaces::Raster(rgba_info);
    assert(canvas_reference);
    SkPaint red;
    red.setColor(command.style.color);
    red.setAntiAlias(true);
    canvas_reference->getCanvas()->clear(SK_ColorTRANSPARENT);
    canvas_reference->getCanvas()->drawPath(expected, red);
    assert(canvas_reference->readPixels(rgba_info, reference_pixels.data(), pitch, 0, 0));
    assert(canvas_pixels == reference_pixels);

    VoxShadowClip clip {};
    clip.is_path = 1;
    clip.path = input;
    clip.transform[0] = clip.transform[3] = 1;
    VoxShadowCommand shadow {};
    shadow.color = command.style.color;
    shadow.transform[0] = shadow.transform[3] = 1;
    shadow.outer.rect[2] = width;
    shadow.outer.rect[3] = height;
    shadow.clips = &clip;
    shadow.clip_count = 1;
    assert(vox_skia_shadow(shadow_pixels.data(), width, height, pitch, &shadow));
    auto shadow_reference = SkSurfaces::Raster(rgba_info);
    assert(shadow_reference);
    shadow_reference->getCanvas()->clear(SK_ColorTRANSPARENT);
    shadow_reference->getCanvas()->clipPath(expected, true);
    shadow_reference->getCanvas()->drawRect(SkRect::MakeWH(width, height), red);
    assert(shadow_reference->readPixels(rgba_info.makeAlphaType(kUnpremul_SkAlphaType), reference_pixels.data(), pitch, 0, 0));
    assert(shadow_pixels == reference_pixels);
    assert(std::any_of(canvas_pixels.begin(), canvas_pixels.end(), [](uint8_t value) { return value != 0; }));

    // Exercise the third conversion site: conic-gradient start angles.
    float stops[] { 0, 1, 0, 0, 1, 1, 0, 0, 1, 1 };
    VoxCanvasStyle style {};
    style.kind = 3;
    style.x0 = style.y0 = 16;
    style.angle = SK_ScalarPI / 2;
    style.stops = stops;
    style.stop_count = 2;
    SkPaint actual_paint, expected_paint;
    assert(apply_style(actual_paint, style));
    SkColor4f colors[] { { 1, 0, 0, 1 }, { 0, 0, 1, 1 } };
    float positions[] { 0, 1 };
    auto matrix = SkMatrix::I();
    expected_paint.setShader(SkGradientShader::MakeSweep(16, 16, colors, nullptr, positions, 2,
        SkTileMode::kClamp, 90, 450, SkGradientShader::Interpolation {}, &matrix));
    auto info = SkImageInfo::MakeN32Premul(width, height);
    auto actual = SkSurfaces::Raster(info), reference = SkSurfaces::Raster(info);
    assert(actual && reference);
    actual->getCanvas()->drawPaint(actual_paint);
    reference->getCanvas()->drawPaint(expected_paint);
    assert(actual->readPixels(info, canvas_pixels.data(), pitch, 0, 0));
    assert(reference->readPixels(info, shadow_pixels.data(), pitch, 0, 0));
    assert(canvas_pixels == shadow_pixels);
    std::puts("Fresh C++17 canvas arcs, shadow clips and conic gradients pass");
}
