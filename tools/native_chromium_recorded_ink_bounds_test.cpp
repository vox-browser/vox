#include "../native/include/native_chromium_recorded_ink_bounds.h"
#include <cassert>
#include <cstdio>
#include <limits>

int main()
{
    auto ink = SkRect::MakeLTRB(-12, -4, 112, 84);
    auto clip = SkRRect::MakeRect(SkRect::MakeWH(100, 80));
    auto identity = SkMatrix::I();
    for (float scale : {1.f, 2.f}) {
        assert(vox_chromium_clip_recorded_ink(ink, clip, identity, scale) == clip.rect());
        auto inside = SkRect::MakeLTRB(4, 8, 92, 72);
        assert(vox_chromium_clip_recorded_ink(inside, clip, identity, scale) == inside);
        assert(vox_chromium_clip_recorded_ink(SkRect::MakeXYWH(104, 0, 8, 8),
            clip, identity, scale).isEmpty());
    }
    // Half a CSS pixel is an exact clip edge only at density two.
    auto half = SkMatrix::Translate(.5f, .5f);
    assert(vox_chromium_clip_recorded_ink(ink, clip, half, 1) == ink);
    assert(vox_chromium_clip_recorded_ink(ink, clip, half, 2)
        == SkRect::MakeLTRB(.5f, .5f, 100.5f, 80.5f));
    auto rounded = SkRRect::MakeRectXY(clip.rect(), 8, 8);
    assert(vox_chromium_clip_recorded_ink(ink, rounded, identity, 2) == ink);
    auto skew = SkMatrix::Skew(.25f, 0);
    assert(vox_chromium_clip_recorded_ink(ink, clip, skew, 2) == ink);
    auto fractional = SkMatrix::Scale(.333f, 1);
    assert(vox_chromium_clip_recorded_ink(ink, clip, fractional, 2) == ink);
    for (float scale : {0.f, -1.f, std::numeric_limits<float>::infinity()})
        assert(vox_chromium_clip_recorded_ink(ink, clip, identity, scale) == ink);
    auto invalid = ink;
    invalid.fLeft = std::numeric_limits<float>::infinity();
    assert(!vox_chromium_clip_recorded_ink(invalid, clip, identity, 2).isFinite());
    // The second clip can further constrain the first, while a rounded clip
    // alone cannot discard the conservative bounds of a shadow.
    auto first = vox_chromium_clip_recorded_ink(ink, rounded, identity, 2);
    assert(vox_chromium_clip_recorded_ink(first, clip, identity, 2) == clip.rect());
    std::puts("Recorded ink: aligned clips, density, disjoint ink and conservative fallbacks passed");
}
