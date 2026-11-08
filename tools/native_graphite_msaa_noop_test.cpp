// Compare forced MSAA with a real, disjoint SVG draw in Chromium's Dawn backend.
#include "../native/include/native_graphite_bridge.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkData.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkRRect.h"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <dlfcn.h>
#include <vector>

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto metal = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto dawn = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(metal && dawn);
    auto draw = reinterpret_cast<decltype(&vox_graphite_draw_shape_pixels)>(
        dlsym(metal, "vox_graphite_draw_shape_pixels"));
    auto reference = reinterpret_cast<decltype(&vox_graphite_draw_picture_pixels)>(
        dlsym(dawn, "vox_graphite_draw_picture_pixels"));
    assert(draw && reference);
    int cases = 0;
    for (int logical_width : {320, 1024}) for (int scale : {1, 2})
    for (bool backdrop : {false, true}) for (int alpha : {127, 255})
    for (bool stroke : {false, true}) for (float phase : {0.f, .25f, .5f}) {
        int width = logical_width * scale, height = 256 * scale;
        int pitch = width * 4 + 12;
        uint32_t background = backdrop ? 0xffffffff : 0;
        std::vector<uint32_t> actual(size_t(pitch / 4) * height, 0xa9a9a9a9);
        for (int y = 0; y < height; ++y)
            std::fill_n(actual.data() + size_t(y) * (pitch / 4), width, background);
        auto before = actual;
        float left = (logical_width == 1024 ? 573 : 208) + phase;
        float rect[] {left + (stroke ? .5f : 0), 80 + phase + (stroke ? .5f : 0),
            stroke ? 102.f : 103.f, stroke ? 37.f : 38.f,
            6, 6, 6, 6, 6, 6, 6, 6};
        if (stroke) std::fill_n(rect + 4, 8, 5.5f);
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = scale; shape.matrix[8] = 1;
        std::copy_n(rect, 12, shape.rect);
        shape.red = 27; shape.green = 117; shape.blue = 208; shape.alpha = alpha;
        shape.has_float_color = 1;
        float color[] {.1058f, .46f, .8142f, alpha / 255.f};
        std::copy_n(color, 4, shape.float_color);
        shape.fill = !stroke; shape.thickness = 1; shape.anti_alias = 1;
        shape.force_msaa = 1;
        assert(draw(reinterpret_cast<uint8_t*>(actual.data()), width, height, pitch, 1, &shape));

        SkPictureRecorder recorder;
        auto* canvas = recorder.beginRecording(SkRect::MakeWH(width, height));
        canvas->clear(backdrop ? SK_ColorWHITE : SK_ColorTRANSPARENT);
        canvas->scale(scale, scale);
        // This visible path really requires MSAA. It does not overlap the
        // rounded control, as with Stack Overflow's neighboring filter icon.
        SkPath path;
        path.moveTo(20, 200); path.cubicTo(60, 205, 25, 240, 70, 240);
        path.lineTo(45, 210); path.close();
        SkPaint ink; ink.setAntiAlias(true);
        canvas->drawPath(path, ink);
        SkPaint paint; paint.setAntiAlias(true);
        paint.setColor4f({color[0], color[1], color[2], color[3]});
        if (stroke) { paint.setStyle(SkPaint::kStroke_Style); paint.setStrokeWidth(1); }
        SkRRect rounded;
        rounded.setRectXY(SkRect::MakeXYWH(rect[0], rect[1], rect[2], rect[3]), rect[4], rect[5]);
        canvas->drawRRect(rounded, paint);
        auto bytes = recorder.finishRecordingAsPicture()->serialize();
        assert(bytes);
        std::vector<uint32_t> expected(size_t(width) * height);
        float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
        assert(reference(reinterpret_cast<uint8_t*>(expected.data()), width, height,
            width * 4, bytes->data(), bytes->size(), identity));
        int l = int(std::floor((rect[0] - 2) * scale));
        int t = int(std::floor((rect[1] - 2) * scale));
        int r = int(std::ceil((rect[0] + rect[2] + 2) * scale));
        int b = int(std::ceil((rect[1] + rect[3] + 2) * scale));
        for (int y = 0; y < height; ++y) for (int x = 0; x < pitch / 4; ++x) {
            auto offset = size_t(y) * (pitch / 4) + x;
            auto wanted = x >= l && x < r && y >= t && y < b
                ? expected[size_t(y) * width + x] : before[offset];
            if (actual[offset] == wanted) continue;
            std::fprintf(stderr, "case=%d width=%d scale=%d backdrop=%d alpha=%d stroke=%d phase=%g at=%d,%d actual=%08x expected=%08x\n",
                cases, logical_width, scale, backdrop, alpha, stroke, phase, x, y,
                actual[offset], wanted);
            return 1;
        }
        ++cases;
    }
    std::printf("PASS: %d forced-MSAA controls match disjoint Dawn draws; fringes and row padding are unchanged\n", cases);
}
