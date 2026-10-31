// Compare Metal gradients with independent complete Dawn pictures.
#include "../native_graphite_bridge.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkData.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/effects/SkGradient.h"
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <dlfcn.h>
#include <vector>

static decltype(&vox_graphite_draw_picture_pixels) picture_draw;

static std::vector<uint32_t> reference(VoxGraphitePath const& path, bool premul)
{
    SkColor4f colors[] {{186.f / 255, 213.f / 255, 246.f / 255, 160.f / 255},
                       {186.f / 255, 213.f / 255, 246.f / 255, 0}};
    float offsets[] {0, 1};
    SkGradient::Interpolation interpolation;
    interpolation.fInPremul = premul ? SkGradient::Interpolation::InPremul::kYes
                                   : SkGradient::Interpolation::InPremul::kNo;
    auto const* p = path.gradient_points;
    SkPoint ends[] {{p[0], p[1]}, {p[2], p[3]}};
    SkGradient gradient(SkGradient::Colors(colors, offsets, SkTileMode::kClamp), interpolation);
    auto shader = path.gradient == 1
        ? SkShaders::LinearGradient(ends, gradient)
        : SkShaders::TwoPointConicalGradient({p[0], p[1]}, p[2], {p[3], p[4]}, p[5], gradient);
    assert(shader);
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(512, 256));
    canvas->clear(SkColorSetRGB(9, 11, 15));
    SkPaint paint;
    paint.setAntiAlias(true);
    paint.setDither(true);
    paint.setShader(std::move(shader));
    SkPathBuilder geometry;
    geometry.moveTo(0, 0).lineTo(512, 0).lineTo(512, 256).lineTo(0, 256).close();
    canvas->drawPath(geometry.detach(), paint);
    auto bytes = recorder.finishRecordingAsPicture()->serialize();
    std::vector<uint32_t> pixels(512 * 256);
    float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
    assert(picture_draw(reinterpret_cast<uint8_t*>(pixels.data()), 512, 256,
        512 * 4, bytes->data(), bytes->size(), identity));
    return pixels;
}

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto metal = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto dawn = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(metal && dawn);
    auto path_draw = reinterpret_cast<decltype(&vox_graphite_draw_path_pixels)>(
        dlsym(metal, "vox_graphite_draw_path_pixels"));
    picture_draw = reinterpret_cast<decltype(picture_draw)>(dlsym(dawn, "vox_graphite_draw_picture_pixels"));
    assert(path_draw && picture_draw);
    float segments[5 * 12] {};
    segments[12] = segments[24] = segments[36] = 1;
    segments[13] = segments[25] = 512;
    segments[26] = segments[38] = 256;
    segments[48] = 5;
    float stops[] {186.f / 255, 213.f / 255, 246.f / 255, 160.f / 255, 0,
                  186.f / 255, 213.f / 255, 246.f / 255, 0, 1};
    int different_interpolations = 0;
    for (int kind : {1, 2}) {
        VoxGraphitePath path {};
        path.segments = segments;
        path.segment_count = 5;
        path.matrix[0] = path.matrix[4] = path.matrix[8] = 1;
        path.gradient_matrix[0] = path.gradient_matrix[4] = path.gradient_matrix[8] = 1;
        path.gradient = kind;
        path.stop_count = 2;
        path.stops = stops;
        path.opacity = 1;
        float linear[] {-21, -12, 397, 276, 0, 0};
        float radial[] {369, 41, 0, 369, 41, 357};
        std::copy_n(kind == 1 ? linear : radial, 6, path.gradient_points);
        auto svg = reference(path, false);
        auto css = reference(path, true);
        different_interpolations += svg != css;
        for (int premul : {0, 1}) {
            path.gradient_premul = premul;
            auto const& expected = premul ? css : svg;
            std::vector<uint32_t> actual(512 * 256, 0xff090b0f);
            assert(path_draw(reinterpret_cast<uint8_t*>(actual.data()),
                512, 256, 512 * 4, 1, &path));
            size_t differences = 0;
            for (size_t i = 0; i < actual.size(); ++i) differences += actual[i] != expected[i];
            std::fprintf(stderr, "kind=%d premul=%d leaf differences=%zu\n", kind, premul, differences);
            assert(actual == expected);
        }
    }
    assert(different_interpolations > 0);
    std::puts("CSS premultiplied and SVG straight gradient replay: 4 exact GPU comparisons");
}
