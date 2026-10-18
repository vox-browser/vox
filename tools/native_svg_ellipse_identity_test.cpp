// Explicit SVG primitive identity must survive the serialized native boundary.
#include "native_svg_path_segments.h"
#include <array>
#include <cassert>
#include <limits>
#include <cstdio>
int main()
{
    int checks = 0;
    for (int i = 0; i < 128; ++i) {
        const float x = i * .125f - 8, y = i * .25f - 16;
        const float w = (i + 1) * .25f, h = (129 - i) * .125f;
        std::array<float, 12> data {6, x, y, x+w, y+h};
        SkRect bounds;
        auto oval = vox_path_from_serialized_segments(data.data(), 1);
        assert(oval.isOval(&bounds));
        assert(bounds == SkRect::MakeLTRB(x, y, x+w, y+h));
        ++checks;
    }
    // The exact four-arc outline of a circle remains an ordinary authored path.
    std::array<float, 60> arcs {};
    arcs[1] = 8; arcs[2] = 4;
    float ends[] {4, 8, 0, 4, 4, 0, 8, 4};
    SkPathBuilder reference;
    reference.moveTo(8, 4);
    for (int i = 0; i < 4; ++i) {
        auto* a = arcs.data() + (i+1)*12;
        a[0] = 4; a[1] = ends[2*i]; a[2] = ends[2*i+1];
        a[7] = a[8] = 4; a[11] = 1;
        reference.arcTo({4, 4}, 0, SkPathBuilder::kSmall_ArcSize,
            SkPathDirection::kCW, {a[1], a[2]});
    }
    auto path = vox_path_from_serialized_segments(arcs.data(), 5);
    assert(path == reference.detach());
    assert(!path.isOval(nullptr)); ++checks;
    for (int coordinate = 1; coordinate <= 4; ++coordinate) {
        for (float bad : {std::numeric_limits<float>::infinity(),
                -std::numeric_limits<float>::infinity(),
                std::numeric_limits<float>::quiet_NaN()}) {
            std::array<float, 12> data {6, 0, 0, 8, 8};
            data[coordinate] = bad;
            assert(vox_path_from_serialized_segments(data.data(), 1).isEmpty());
            ++checks;
        }
    }
    for (auto data : {std::array<float,12>{6,0,0,0,8},
            std::array<float,12>{6,0,0,8,0}, std::array<float,12>{6,8,8,0,0}}) {
        assert(vox_path_from_serialized_segments(data.data(), 1).isEmpty()); ++checks;
    }
    assert(vox_path_from_serialized_segments(nullptr, 1).isEmpty()); ++checks;
    std::printf("{\"checks\":%d,\"passed\":true}\n", checks);
}
