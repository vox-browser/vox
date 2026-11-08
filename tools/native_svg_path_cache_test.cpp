#include "../native_svg_path_cache.h"
#include <cassert>

static int draws;
static int render(uint8_t* pixels, int width, int height, int pitch,
    int, VoxGraphitePath const*)
{
    ++draws;
    for (int y = 0; y < height; ++y)
        std::memset(pixels + y * pitch, draws, size_t(width) * 4);
    return 1;
}

int main()
{
    VoxSmallSvgPathCache cache;
    float segments[24] {};
    VoxGraphitePath path {};
    path.matrix[0] = path.matrix[4] = path.matrix[8] = 1;
    path.segments = segments; path.segment_count = 2; path.alpha = 255;
    std::vector<uint8_t> pixels(24 * 4, 17);
    auto draw = [&](int background = 0) {
        return cache.draw(render, pixels.data(), 4, 4, 24, background, &path);
    };
    draw(); draw();
    assert(draws == 2 && cache.size() == 0);
    cache.enabled = true;
    draw(); auto first = pixels; int calls = draws;
    std::fill(pixels.begin(), pixels.end(), 91);
    draw();
    assert(draws == calls && cache.hits == 1 && pixels[0] == first[0]);
    assert(pixels[16] == 91 && pixels[24] == first[24]); // Leave row padding alone.

    auto miss_then_hit = [&] {
        int before = draws; draw(); assert(draws == before + 1);
        draw(); assert(draws == before + 1);
    };
    path.matrix[2] = .25f; miss_then_hit();
    segments[1] = .125f; miss_then_hit();
    path.even_odd = 1; miss_then_hit();
    path.red = 29; miss_then_hit();
    path.green = 30; miss_then_hit();
    path.blue = 31; miss_then_hit();
    path.alpha = 127; miss_then_hit();
    path.has_float_color = 1; miss_then_hit();
    path.float_color[0] = .123456f; miss_then_hit();
    path.has_float_alpha = 1; miss_then_hit();
    path.opacity = .456789f; miss_then_hit();
    path.float_color[3] = .75f; miss_then_hit();
    float equal_segments[24]; std::memcpy(equal_segments, segments, sizeof(segments));
    path.segments = equal_segments;
    calls = draws; draw(); assert(draws == calls); // Content, not source pointer.
    std::vector<uint8_t> tight(4 * 4 * 4);
    assert(cache.draw(render, tight.data(), 4, 4, 16, 0, &path) == 1 && draws == calls);
    assert(tight[0] == pixels[0] && tight[16] == pixels[24]);
    cache.draw(render, tight.data(), 2, 4, 16, 0, &path);
    assert(draws == calls + 1);
    cache.draw(render, tight.data(), 4, 2, 16, 0, &path);
    assert(draws == calls + 2);

    std::fill(pixels.begin(), pixels.end(), 42);
    auto backdrop = pixels;
    draw(1); auto result = pixels; calls = draws;
    pixels = backdrop; draw(1); assert(draws == calls && pixels == result);
    pixels = backdrop; pixels[24 + 3] = 43;
    draw(1); assert(draws == calls + 1);
    pixels = backdrop; pixels[16] = 99; // Padding does not belong to the backdrop.
    draw(1); assert(draws == calls + 1 && pixels[16] == 99);

    for (int* unsupported : {&path.stroke, &path.gradient, &path.has_clip, &path.has_ancestor_clip}) {
        *unsupported = 1; calls = draws; draw(); draw();
        assert(draws == calls + 2); *unsupported = 0;
    }
    auto fail = [](uint8_t*, int, int, int, int, VoxGraphitePath const*) { return 0; };
    cache.clear(); assert(cache.size() == 0 && cache.bytes() == 0);
    assert(cache.draw(fail, pixels.data(), 4, 4, 24, 0, &path) == 0 && cache.size() == 0);
    for (int i = 0; i < 200; ++i) {
        path.matrix[2] = float(i); draw();
        assert(cache.size() <= 64 && cache.bytes() <= 8u * 1024 * 1024);
    }
    cache.clear();
    assert(cache.size() == 0 && cache.bytes() == 0);
    std::vector<uint8_t> large(128 * 128 * 4, 0);
    for (int i = 0; i < 100; ++i) {
        path.matrix[2] = float(i);
        cache.draw(render, large.data(), 128, 128, 128 * 4, 1, &path);
        assert(cache.size() <= 64 && cache.bytes() <= 8u * 1024 * 1024);
    }
    assert(cache.size() < 64); // Exercise the byte budget as well as the entry limit.
}
