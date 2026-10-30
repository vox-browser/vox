#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <limits>

int main()
{
    uint32_t tag = 0x6f70737a; // opsz
    float coordinate = 17;
    auto path = "/System/Library/Fonts/SFNS.ttf";
    assert(ladybird_v_skia_register_system_face("ink-regular", path,
        ".SFNS-Regular", &tag, &coordinate, 1));
    assert(ladybird_v_skia_register_system_face("ink-bold", path,
        ".SFNS-Bold", &tag, &coordinate, 1));
    float regular[2] {}, bold[2] {};
    for (auto key : {"ink-regular", "ink-bold"}) {
        auto face = select_typeface(key, 0, 400, 0);
        assert(face);
        uint16_t glyph = face->unicharToGlyph('p');
        float xy[2] {};
        auto output = key == std::string("ink-bold") ? bold : regular;
        assert(ladybird_v_skia_glyph_intercepts(key, 0, 11, 400, 0, 0,
            &glyph, xy, 1, 1.625, 1.725, output, 2) == 2);
        assert(output[0] < output[1]);
        float shifted_xy[2] {11, 2}, shifted[2] {};
        assert(ladybird_v_skia_glyph_intercepts(key, 0, 11, 400, 0, 0,
            &glyph, shifted_xy, 1, 3.625, 3.725, shifted, 2) == 2);
        for (int i = 0; i < 2; ++i) assert(std::abs(shifted[i] - output[i] - 11) < .0001);
        float doubled[2] {};
        assert(ladybird_v_skia_glyph_intercepts(key, 0, 22, 400, 0, 0,
            &glyph, xy, 1, 3.25, 3.45, doubled, 2) == 2);
        for (int i = 0; i < 2; ++i) assert(std::abs(doubled[i] - output[i] * 2) < .0001);
        float canary[2] {81, 82};
        assert(ladybird_v_skia_glyph_intercepts(key, 0, 11, 400, 0, 0,
            &glyph, xy, 1, 1.625, 1.725, canary, 1) == -1);
        assert(canary[0] == 81 && canary[1] == 82);
        xy[0] = std::numeric_limits<float>::infinity();
        assert(ladybird_v_skia_glyph_intercepts(key, 0, 11, 400, 0, 0,
            &glyph, xy, 1, 1.625, 1.725, canary, 2) == -1);
        assert(canary[0] == 81 && canary[1] == 82);
    }
    // Both instances have the same raw TrueType outline. Their instantiated
    // stem widths must differ, or bold text keeps the regular face's ink gap.
    assert(bold[1] - bold[0] > regular[1] - regular[0] + .25);
    assert(ladybird_v_skia_glyph_intercepts("ink-bold", 0, 11, 400, 0, 0,
        nullptr, nullptr, 0, 1, 2, nullptr, 0) == 0);
    assert(ladybird_v_skia_glyph_intercepts("ink-bold", 0, 11, 400, 0, 0,
        nullptr, nullptr, 32769, 1, 2, nullptr, 0) == -1);
}
