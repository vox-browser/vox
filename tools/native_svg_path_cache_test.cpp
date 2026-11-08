#include "../native/include/native_gg_path.h"
#include <cassert>
#include <thread>

static int draws;
static int render(uint8_t* pixels, int width, int height, int pitch,
    int, VoxGraphitePath const*)
{
    ++draws;
    for (int y = 0; y < height; ++y)
        std::memset(pixels + y * pitch, draws, size_t(width) * 4);
    return 1;
}

int main(int argc, char** argv)
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
    path.stroke = 1; miss_then_hit();
    path.stroke_width = 1.5f; miss_then_hit();
    path.stroke_width = 1.500001f; miss_then_hit();
    path.line_cap = 1; miss_then_hit();
    path.line_join = 2; miss_then_hit();
    path.non_scaling_stroke = 1; miss_then_hit();
    path.miter_limit = 4; miss_then_hit();
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

    for (int* unsupported : {&path.gradient, &path.has_clip, &path.has_ancestor_clip}) {
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

    // Exercise the actual registered GG bridge with an explicit opt-in. A
    // cache hit must avoid the callback while preserving the caller's scope.
    unsetenv("VOX_DISABLE_SMALL_SVG_PATH_CACHE");
    unsetenv("VOX_DISABLE_GITHUB_SVG_PATH_CACHE");
    unsetenv("VOX_SMALL_SVG_PATH_CACHE");
    path.matrix[2] = 0;
    ladybird_v_skia_set_gg_path_draw(render);
    assert(!s_small_svg_path_cache.enabled);
    auto bridge_draw = [&] {
        return gg_draw_path_pixels(pixels.data(), 4, 4, 24, 0, &path);
    };
    calls = draws;
    assert(bridge_draw() && bridge_draw() && draws == calls + 2);
    assert(s_small_svg_path_cache.size() == 0); // No ordinary policy change.
    setenv("VOX_SMALL_SVG_PATH_CACHE", "1", 1);
    calls = draws;
    assert(bridge_draw());
    first = pixels;
    std::fill(pixels.begin(), pixels.end(), 61);
    assert(bridge_draw() && draws == calls + 1);
    assert(pixels[0] == first[0] && pixels[24] == first[24] && pixels[16] == 61);
    assert(!s_small_svg_path_cache.enabled && s_small_svg_path_cache.hits == 1);
    unsetenv("VOX_SMALL_SVG_PATH_CACHE");
    assert(ladybird_v_skia_set_small_svg_path_cache(1) == 0);
    assert(bridge_draw() && draws == calls + 1 && s_small_svg_path_cache.enabled);
    // Both controls bypass reuse, even when the caller explicitly enabled it.
    setenv("VOX_DISABLE_SMALL_SVG_PATH_CACHE", "1", 1);
    assert(bridge_draw() && bridge_draw() && draws == calls + 3);
    assert(s_small_svg_path_cache.enabled);
    unsetenv("VOX_DISABLE_SMALL_SVG_PATH_CACHE");
    setenv("VOX_DISABLE_GITHUB_SVG_PATH_CACHE", "1", 1);
    assert(bridge_draw() && bridge_draw() && draws == calls + 5);
    unsetenv("VOX_DISABLE_GITHUB_SVG_PATH_CACHE");
    assert(ladybird_v_skia_set_small_svg_path_cache(0) == 1);
    setenv("VOX_SMALL_SVG_PATH_CACHE", "1", 1);
    assert(bridge_draw() && draws == calls + 5);
    // Replacing the registered backend must invalidate pixels from the old one.
    ladybird_v_skia_set_gg_path_draw([](uint8_t* p, int w, int h, int stride, int,
            VoxGraphitePath const*) {
        for (int y=0; y<h; ++y) std::memset(p + y * stride, 177, size_t(w) * 4);
        return 1;
    });
    assert(s_small_svg_path_cache.size() == 0);
    assert(bridge_draw() && pixels[0] == 177);
#if defined(__APPLE__)
    auto main_pixels=pixels;
    auto main_hits=s_small_svg_path_cache.hits;
    auto main_entries=s_small_svg_path_cache.size();
    std::thread worker([&] { assert(!bridge_draw()); });
    worker.join();
    assert(pixels==main_pixels && s_small_svg_path_cache.hits==main_hits
        && s_small_svg_path_cache.size()==main_entries);
#endif
    ladybird_v_skia_set_gg_path_draw(nullptr);
    assert(!bridge_draw() && s_small_svg_path_cache.size() == 0);
    if (argc == 2) {
        // The exact byte cache must also agree with real GPU raster output,
        // including strokes whose caps, joins and subpixel phase change.
        void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        assert(library);
        auto backend = reinterpret_cast<VoxGGPathDraw>(
            dlsym(library, "vox_graphite_draw_path_pixels"));
        assert(backend);
        ladybird_v_skia_set_gg_path_draw(backend);
        float geometry[36] {};
        geometry[1]=3.25f; geometry[2]=4.5f;
        geometry[12]=1; geometry[13]=23.75f; geometry[14]=29.125f;
        geometry[24]=1; geometry[25]=35.5f; geometry[26]=6.25f;
        VoxGraphitePath stroke {};
        stroke.segments=geometry; stroke.segment_count=3; stroke.stroke=1;
        stroke.matrix[0]=stroke.matrix[4]=stroke.matrix[8]=1;
        stroke.red=83; stroke.green=147; stroke.blue=211; stroke.alpha=173;
        stroke.stroke_width=2.75f; stroke.miter_limit=3.5f;
        constexpr int width=48, height=48, stride=width*4+16;
        unsigned scenes=0;
        for (int background : {0,1}) for (int cap : {0,1,2})
            for (int join : {0,1,2}) for (int non_scaling : {0,1})
                for (float phase : {.125f,.75f}) {
            stroke.line_cap=cap; stroke.line_join=join;
            stroke.non_scaling_stroke=non_scaling;
            stroke.matrix[2]=phase; stroke.matrix[5]=.25f;
            stroke.matrix[0]=stroke.matrix[4]=non_scaling ? .875f : 1.0f;
            std::vector<uint8_t> input(stride*height,99);
            for (int y=0;y<height;++y) for (int x=0;x<width;++x) {
                auto* p=input.data()+y*stride+x*4;
                p[0]=uint8_t(x*3); p[1]=uint8_t(y*3); p[2]=90; p[3]=255;
            }
            auto expected=input;
            assert(backend(expected.data(),width,height,stride,background,&stroke));
            s_small_svg_path_cache.clear();
            for (int repeat=0;repeat<2;++repeat) {
                auto actual=input; auto before=s_small_svg_path_cache.hits;
                assert(gg_draw_path_pixels(actual.data(),width,height,stride,background,&stroke));
                assert(actual==expected);
                assert(s_small_svg_path_cache.hits==before+unsigned(repeat==1));
            }
            ++scenes;
        }
        ladybird_v_skia_set_gg_path_draw(nullptr);
        dlclose(library);
        std::printf("%u GPU stroke scenes: exact cached/fresh pixels, background and padded rows passed\n",scenes);
    }
    unsetenv("VOX_SMALL_SVG_PATH_CACHE");
    std::puts("Exact SVG cache keys, bounds, opt-in bridge reuse, disable controls, scoped state and backend invalidation passed");
}
