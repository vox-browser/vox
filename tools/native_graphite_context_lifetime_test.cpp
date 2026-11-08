#include "../native/include/native_graphite_bridge.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkPicture.h"
#include "include/core/SkData.h"
#include <cassert>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <thread>
#include <vector>

template<typename T> static T symbol(void* library, char const* name)
{
    auto result = reinterpret_cast<T>(dlsym(library, name));
    assert(result); return result;
}

int main(int argc, char** argv)
{
    assert(argc == 3);
    auto metal = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    auto dawn = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
    assert(metal && dawn);
    auto shape_draw = symbol<decltype(&vox_graphite_draw_shape_pixels)>(metal, "vox_graphite_draw_shape_pixels");
    auto picture_draw = symbol<decltype(&vox_graphite_draw_picture_pixels)>(dawn, "vox_graphite_draw_picture_pixels");
    auto retire_metal = symbol<int (*)()>(metal, "vox_graphite_retire_graphics_context");
    auto retire_dawn = symbol<int (*)()>(dawn, "vox_graphite_picture_retire_graphics_context");
    auto idle_metal = symbol<int (*)()>(metal, "vox_graphite_release_idle_graphics_memory");
    auto idle_dawn = symbol<int (*)()>(dawn, "vox_graphite_picture_release_idle_graphics_memory");
    SkPictureRecorder recorder;
    auto* canvas = recorder.beginRecording(SkRect::MakeWH(64, 48));
    SkPaint paint; paint.setAntiAlias(true); paint.setColor(0xc33da4eb);
    canvas->drawRoundRect(SkRect::MakeXYWH(5.25f, 7.5f, 47.5f, 33.25f), 6, 9, paint);
    auto bytes = recorder.finishRecordingAsPicture()->serialize(); assert(bytes);
    float identity[] {1, 0, 0, 0, 1, 0, 0, 0, 1};
    std::vector<uint8_t> expected_shape, expected_picture;
    // A new paint color on each switch forces the real GPU path past raster
    // caches. Compare against the unchanged policy on the same native libraries.
    for (int i = 0; i < 12; ++i) {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
        shape.rect[0] = 3.25f; shape.rect[1] = 5.5f;
        shape.rect[2] = 53.5f; shape.rect[3] = 39.25f;
        for (int j = 4; j < 12; ++j) shape.rect[j] = 5 + j % 3;
        shape.fill = 1; shape.anti_alias = 1; shape.force_msaa = i % 2;
        shape.red = uint8_t(83 + i); shape.green = 147; shape.blue = 219; shape.alpha = 193;
        std::vector<uint8_t> shape_pixels(64 * 48 * 4, 0), picture_pixels(shape_pixels.size(), 0);
        setenv("VOX_DISABLE_GRAPHICS_CONTEXT_HANDOFF", "1", 1);
        assert(shape_draw(shape_pixels.data(), 64, 48, 64 * 4, 0, &shape));
        assert(picture_draw(picture_pixels.data(), 64, 48, 64 * 4, bytes->data(), bytes->size(), identity));
        expected_shape = shape_pixels; expected_picture = picture_pixels;
        assert(retire_metal() == 1 && retire_dawn() == 1);
        unsetenv("VOX_DISABLE_GRAPHICS_CONTEXT_HANDOFF");
        std::fill(picture_pixels.begin(), picture_pixels.end(), 0);
        assert(picture_draw(picture_pixels.data(), 64, 48, 64 * 4, bytes->data(), bytes->size(), identity));
        assert(picture_pixels == expected_picture && idle_dawn() == -1);
        // The first repeat may still be below the shape-cache admission limit.
        // Change an unused surface byte by using a distinct target extent.
        std::vector<uint8_t> larger(65 * 48 * 4, 0);
        assert(shape_draw(larger.data(), 65, 48, 65 * 4, 0, &shape));
        assert(retire_dawn() == 0 && idle_metal() == -1);
        for (int y = 0; y < 48; ++y)
            assert(!std::memcmp(larger.data() + y * 65 * 4, expected_shape.data() + y * 64 * 4, 64 * 4));
        assert(retire_metal() == 1);
    }
    // Worker calls never acquire a peer's mutex while holding their own. Both
    // independent contexts can coexist there and owner cleanup runs after join.
    std::thread worker([&] {
        VoxGraphiteShape shape {};
        shape.matrix[0] = shape.matrix[4] = shape.matrix[8] = 1;
        shape.rect[2] = 31; shape.rect[3] = 29;
        for (int i = 4; i < 12; ++i) shape.rect[i] = 4;
        shape.fill = 1; shape.anti_alias = 1; shape.alpha = 173;
        std::vector<uint8_t> pixels(64 * 48 * 4, 0);
        assert(shape_draw(pixels.data(), 64, 48, 256, 0, &shape));
        assert(picture_draw(pixels.data(), 64, 48, 256, bytes->data(), bytes->size(), identity));
        assert(retire_metal() == 0 && retire_dawn() == 0);
    });
    worker.join();
    assert(retire_metal() == 1 && retire_dawn() == 1);
    assert(idle_metal() == 0 && idle_dawn() == 0);
    std::cout << "12 alternating GPU cases preserve exact pixels and retire the peer; worker ownership passes\n";
}
