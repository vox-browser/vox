// Keep private Graphite records compatible with the release Skia archive.
#include "include/private/SkASAN.h"
#undef SK_SANITIZE_ADDRESS
#define VOX_TEST_CANVAS_BLIT_FAILURE
#include "../native_graphite_darwin.mm"
#include <cassert>
#include <tuple>

static std::vector<std::vector<uint8_t>> render(int width, int height, int count,
    bool blit, int frame, bool staged, bool linear)
{
    canvas_reset();
    unsigned calls = vox_test_canvas_blit_calls;
    if (blit) setenv("VOX_GPU_CANVAS_BLIT_READBACK", "1", 1);
    else unsetenv("VOX_GPU_CANVAS_BLIT_READBACK");
    if (staged) setenv("VOX_GPU_CANVAS_STAGED_UPLOAD", "1", 1);
    else unsetenv("VOX_GPU_CANVAS_STAGED_UPLOAD");
    if (linear) setenv("VOX_GPU_CANVAS_LINEAR_TEXTURES", "1", 1);
    else unsetenv("VOX_GPU_CANVAS_LINEAR_TEXTURES");
    std::vector<int> rects;
    for (int index = 0; index < count; ++index)
        rects.insert(rects.end(), {index * 13, index * 7, width, height,
            index * 13 + 1, index * 7 + 2, width - 3, height - 4});
    assert(vox_graphite_canvas_begin(rects.data(), count));
    std::vector<std::vector<uint8_t>> outputs(count);
    std::vector<VoxGraphitePixelRegion> views;
    for (int index = 0; index < count; ++index) {
        auto const& tile = canvas_tiles[size_t(index)];
        int pitch = (width + 5) * 4;
        std::vector<uint32_t> source(size_t(width + 5) * height);
        for (int y = 0; y < height; ++y) for (int x = 0; x < width + 5; ++x) {
            unsigned a = 31 + (x + y + frame * 19) % 225;
            source[size_t(y) * (width + 5) + x] = (a << 24)
                | ((unsigned(x + index * 7) % a) << 16)
                | ((unsigned(y + frame * 11) % a) << 8) | (unsigned(x + y) % a);
        }
        assert(vox_graphite_canvas_upload(index, reinterpret_cast<uint8_t const*>(source.data()), pitch));
        std::fill(source.begin(), source.end(), 0xdeadbeef);
        auto* canvas = tile.surface->getCanvas();
        SkPaint paint; paint.setAntiAlias(true); paint.setColor(0x9070a030 + frame);
        canvas->drawRoundRect(SkRect::MakeXYWH(.375f, .25f, width - 3.75f, height - 2.5f), 5, 7, paint);
        canvas->save();
        canvas->clipRect(SkRect::MakeXYWH(2, 3, width - 5, height - 6));
        paint.setColor(0xb0102050); canvas->drawCircle(width / 2.f, height / 2.f, height / 3.f, paint);
        canvas->restore();
        outputs[index].assign(size_t(pitch) * (height - 4), 0xa7);
        views.push_back({1, 2, width - 3, height - 4, pitch, outputs[index].data()});
    }
    if (count > 1) {
        auto invalid = views;
        invalid.back().x = INT_MAX;
        assert(!vox_graphite_canvas_read(invalid.data(), count));
        invalid = views; invalid.back().pitch = (width - 3) * 4 - 1;
        assert(!vox_graphite_canvas_read(invalid.data(), count));
        for (auto const& output : outputs)
            for (auto byte : output) assert(byte == 0xa7);
    }
    assert(vox_graphite_canvas_read(views.data(), count));
    assert(vox_test_canvas_blit_calls == calls + unsigned(blit && vox_test_canvas_blit_fail_after < 0));
    // Both readers own their results independently of subsequent GPU writes.
    for (auto const& tile : canvas_tiles) tile.surface->getCanvas()->clear(SK_ColorRED);
    std::vector<std::vector<uint8_t>> later = outputs;
    for (int index = 0; index < count; ++index) views[index].pixels = later[index].data();
    assert(vox_graphite_canvas_read(views.data(), count));
    assert(vox_test_canvas_blit_calls == calls + 2 * unsigned(blit && vox_test_canvas_blit_fail_after < 0));
    assert(later != outputs);
    for (auto const& output : outputs) for (int row = 0; row < height - 4; ++row)
        for (int byte = (width - 3) * 4; byte < (width + 5) * 4; ++byte)
            assert(output[size_t(row) * (width + 5) * 4 + byte] == 0xa7);
    vox_graphite_canvas_end();
    return outputs;
}

int main() { @autoreleasepool {
    unsigned cases = 0;
    for (bool staged : {false, true}) for (bool linear : {false, true})
        for (auto [width, height, count] : {std::tuple{37, 29, 8}, {515, 259, 2}, {3416, 1906, 1}})
            for (int frame = 0; frame < 2; ++frame) {
                auto expected = render(width, height, count, false, frame, staged, linear);
                auto actual = render(width, height, count, true, frame, staged, linear);
                assert(expected == actual); ++cases;
            }
    // Allocation failure after preparing an earlier region leaves all source
    // draws queued for the ordinary reader; no partial output can escape.
    for (int failure : {0, 1}) {
        auto expected = render(37, 29, 2, false, 3, false, false);
        vox_test_canvas_blit_fail_after = failure;
        auto actual = render(37, 29, 2, true, 3, false, false);
        assert(expected == actual); ++cases;
    }
    std::printf("Blit readback: %u exact cases, pending writers, alpha, padding, invalid later regions and allocation fallback pass\n", cases);
} }
