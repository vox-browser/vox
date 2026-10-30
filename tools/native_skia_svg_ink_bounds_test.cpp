// Shared pictures need painted bounds, separately from the raster safety fringe.
#include "../native_skia_text_darwin.cpp"
#include <array>
#include <cassert>
#include <cstdio>

static std::array<float, 60> rectangle(float x, float y, float width, float height)
{
    std::array<float, 60> segments {};
    float points[][2] {{x, y}, {x + width, y}, {x + width, y + height}, {x, y + height}};
    for (int i = 0; i < 4; ++i) {
        segments[i * 12] = i ? 1 : 0;
        segments[i * 12 + 1] = points[i][0];
        segments[i * 12 + 2] = points[i][1];
    }
    segments[48] = 5;
    return segments;
}

static VoxGraphitePath path(float const* segments)
{
    VoxGraphitePath result {};
    result.matrix[0] = result.matrix[4] = result.matrix[8] = 1;
    result.segments = segments;
    result.segment_count = 5;
    result.alpha = 255;
    return result;
}

static SkRect ink(VoxGraphitePath const* paths, int count, SkMatrix matrix, SkRect viewport)
{
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(2048, 2048);
    SkRect bounds;
    assert(record_chromium_svg_path_batch(canvas, paths, count, matrix, viewport, nullptr, &bounds));
    assert(recorder.finishRecordingAsPicture());
    return bounds;
}

int main()
{
    auto top = rectangle(0, 0, 1024, 3);
    auto bottom = rectangle(0, 55, 1024, 1);
    VoxGraphitePath bars[] {path(top.data()), path(bottom.data())};
    auto viewport = SkRect::MakeXYWH(-1, -1, 1026, 58);
    auto bounds = ink(bars, 2, SkMatrix::Translate(0, 60), viewport);
    assert(bounds == SkRect::MakeXYWH(0, 60, 1024, 56));

    auto small = rectangle(2, 3, 10, 12);
    auto transformed = path(small.data());
    transformed.matrix[0] = 2;
    transformed.matrix[4] = 3;
    transformed.matrix[2] = 7;
    transformed.matrix[5] = 11;
    bounds = ink(&transformed, 1, SkMatrix::Translate(20, 30), SkRect::MakeWH(100, 100));
    assert(bounds == SkRect::MakeXYWH(31, 50, 20, 36));

    auto clipped = path(small.data());
    bounds = ink(&clipped, 1, SkMatrix::I(), SkRect::MakeXYWH(5, 6, 2, 3));
    assert(bounds == SkRect::MakeXYWH(5, 6, 2, 3));
    assert(ink(&clipped, 1, SkMatrix::I(), SkRect::MakeXYWH(100, 100, 2, 2)).isEmpty());

    auto stroked = path(small.data());
    stroked.stroke = 1;
    stroked.stroke_width = 4;
    stroked.miter_limit = 4;
    bounds = ink(&stroked, 1, SkMatrix::I(), SkRect::MakeXYWH(-100, -100, 500, 500));
    assert(bounds.contains(SkRect::MakeXYWH(0, 1, 14, 16)));
    stroked.non_scaling_stroke = 1;
    stroked.matrix[0] = stroked.matrix[4] = 3;
    bounds = ink(&stroked, 1, SkMatrix::I(), SkRect::MakeXYWH(-100, -100, 500, 500));
    assert(bounds.contains(SkRect::MakeXYWH(4, 7, 34, 40)));

    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(100, 100);
    bars[1].gradient = 1; // A missing gradient must reject the complete batch.
    auto sentinel = SkRect::MakeXYWH(7, 8, 9, 10);
    bounds = sentinel;
    assert(!record_chromium_svg_path_batch(canvas, bars, 2, SkMatrix::I(), viewport, nullptr, &bounds));
    assert(bounds == sentinel);
    assert(recorder.finishRecordingAsPicture()->approximateOpCount() == 0);
    std::puts("PASS: SVG shared-picture ink, raster fringe, transforms, clipping, strokes and rejected batches");
}
