#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    constexpr int width = 48, height = 48;
    float identity[] {1,0,0,0,1,0,0,0,1};
    float viewport[] {0,0,width,height}, clip[] {0,0,width,height};
    assert(solid_svg_has_standard_samples());
    auto draw = graphite_path_draw(); assert(draw);
    unsigned accepted = 0, rejected = 0;
    float geometries[][6] {{2,27,16,-2,30,27}, {3,3,30,3,3,30},
        {2,2,30,31,31,32}, {-9,18,20,-7,43,43}};
    for (auto const& geometry : geometries) for (int winding = 0; winding < 2; ++winding)
    for (int palette = 0; palette < 8; ++palette)
    for (float scale : {.5f, 1.f, 1.25f})
    for (float phase : {0.f, .125f, .25f, .5f, .875f, 1.f/13}) {
        float segments[4][12] {};
        segments[0][0] = 0; segments[1][0] = segments[2][0] = 1; segments[3][0] = 5;
        for (int i = 0; i < 3; ++i) {
            int vertex = winding ? (3 - i) % 3 : i;
            segments[i][1] = geometry[vertex * 2]; segments[i][2] = geometry[vertex * 2 + 1];
        }
        VoxGraphitePath path {};
        path.segments = segments[0]; path.segment_count = 4;
        std::copy(identity, identity + 9, path.matrix);
        path.matrix[0] = path.matrix[4] = scale; path.matrix[2] = phase;
        path.red = palette * 37; path.green = palette * 73; path.blue = palette * 117;
        path.alpha = 255; path.even_odd = palette % 2;
        std::vector<uint32_t> actual(width * height), expected;
        for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x)
            actual[y * width + x] = 0xff000000 | ((x * 7 + y * 13) % 256) << 16
                | ((x * 19 + y * 3) % 256) << 8 | ((x * 11 + y * 17) % 256);
        expected = actual;
        VoxGraphitePixelRegion view {0,0,width,height,width * 4,reinterpret_cast<uint8_t*>(actual.data())};
        if (!vox_draw_solid_svg_polygons(view, &path, 1, identity, viewport, clip, true)) {
            assert(actual == expected); ++rejected; continue;
        }
        assert(draw(reinterpret_cast<uint8_t*>(expected.data()), width, height, width * 4, 1, &path));
        if (actual != expected) {
            std::fprintf(stderr, "Triangle mismatch palette=%d winding=%d scale=%g phase=%g points=%g,%g %g,%g %g,%g\n",
                palette, winding, scale, phase, geometry[0],geometry[1],geometry[2],geometry[3],geometry[4],geometry[5]);
            return 1;
        }
        ++accepted;
        auto original = actual;
        path.alpha = 254;
        assert(!vox_draw_solid_svg_polygons(view, &path, 1, identity, viewport, clip, true));
        assert(actual == original);
    }
    assert(accepted && rejected);
    std::printf("PASS %u exact direct GPU triangle comparisons, %u transactional ambiguous-edge fallbacks\n", accepted, rejected);
}
