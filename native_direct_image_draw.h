#pragma once
#include "native_direct_image_raster.h"

// Chromium samples a directly composited image twice: once into its uniform
// raster scale, then through the display compositor's image quads. Keep the
// fractional visible quad bounds; rounding them changes interior texels too.
static bool draw_direct_image(SkCanvas* canvas, skgpu::graphite::Recorder* recorder,
    VoxGraphiteImage const& image, PreparedImageDraw const& source,
    VoxDirectImageRasterPlan const& plan, int viewport_width, int viewport_height)
{
    float left = std::max({0.f, image.clip[0] - image.destination[0],
        -image.matrix[2] - image.destination[0]}) * plan.scale;
    float top = std::max({0.f, image.clip[1] - image.destination[1],
        -image.matrix[5] - image.destination[1]}) * plan.scale;
    float right = std::min({image.destination[2], image.clip[0] + image.clip[2] - image.destination[0],
        viewport_width - image.matrix[2] - image.destination[0]}) * plan.scale;
    float bottom = std::min({image.destination[3], image.clip[1] + image.clip[3] - image.destination[1],
        viewport_height - image.matrix[5] - image.destination[1]}) * plan.scale;
    if (!(right > left && bottom > top)) return true;
    SkAutoCanvasRestore restore(canvas, true);
    SkMatrix transform; transform.set9(image.matrix);
    canvas->setMatrix(transform);
    canvas->clipRRect(rounded_rect(image.clip), true);
    canvas->translate(image.destination[0], image.destination[1]);
    canvas->scale(1.f / plan.scale, 1.f / plan.scale);
    SkPaint paint; paint.setAlphaf(image.opacity);
    for (int row = 0; row < plan.rows; ++row) {
        int y = row * (plan.tile_height - 2);
        float quad_top = std::max(top, float(y + (row > 0 ? 1 : 0)));
        float quad_bottom = std::min(bottom, float(y + plan.tile_height - (row + 1 < plan.rows ? 1 : 0)));
        if (!(quad_bottom > quad_top)) continue;
        for (int column = 0; column < plan.columns; ++column) {
            int x = column * (plan.tile_width - 2);
            float quad_left = std::max(left, float(x + (column > 0 ? 1 : 0)));
            float quad_right = std::min(right, float(x + plan.tile_width - (column + 1 < plan.columns ? 1 : 0)));
            if (!(quad_right > quad_left)) continue;
            auto info = SkImageInfo::Make(plan.tile_width, plan.tile_height,
                kBGRA_8888_SkColorType, kPremul_SkAlphaType, SkColorSpace::MakeSRGB());
            auto tile = SkSurfaces::RenderTarget(recorder, info);
            if (!tile) return false;
            auto stage = image;
            std::fill_n(stage.matrix, 9, 0.f);
            stage.matrix[0] = stage.matrix[4] = plan.scale; stage.matrix[8] = 1;
            stage.matrix[2] = -x; stage.matrix[5] = -y;
            stage.destination[0] = stage.destination[1] = 0;
            std::copy_n(stage.destination, 4, stage.clip);
            std::fill_n(stage.clip + 4, 8, 0.f);
            stage.opacity = 1;
            PreparedImageDraw first;
            first.texture = source.texture; first.whole_source = true;
            tile->getCanvas()->clear(SK_ColorTRANSPARENT);
            draw_prepared_image(tile->getCanvas(), &stage, first);
            auto raster = tile->makeImageSnapshot();
            if (!raster) return false;
            SkCanvas::ImageSetEntry entry(raster,
                SkRect::MakeLTRB(quad_left - x, quad_top - y, quad_right - x, quad_bottom - y),
                SkRect::MakeLTRB(quad_left, quad_top, quad_right, quad_bottom),
                1.f, SkCanvas::kNone_QuadAAFlags);
            canvas->experimental_DrawEdgeAAImageSet(&entry, 1, nullptr, nullptr,
                SkSamplingOptions(SkFilterMode::kLinear), &paint, SkCanvas::kFast_SrcRectConstraint);
        }
    }
    return true;
}
