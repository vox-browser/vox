#include "../native/include/native_glyph_text_blob_cache.h"
#include "include/core/SkFontMgr.h"
#include "include/ports/SkFontMgr_mac_ct.h"
#include <cassert>
#include <iostream>

int main() {
    auto manager = SkFontMgr_New_CoreText(nullptr);
    auto face = manager->makeFromFile("/System/Library/Fonts/HelveticaNeue.ttc");
    assert(face);
    SkFont font(face, 14);
    uint16_t glyphs[] {36, 37, 38};
    double positions[] {0, 0, 11.25, 0, 23.5, 0};
    VoxGlyphTextBlobCache cache;
    auto original = cache.get(font, glyphs, positions, 3);
    assert(original && cache.get(font, glyphs, positions, 3) == original);
    // Owned input values, not the address of a run, determine identity.
    glyphs[1] = 39;
    assert(cache.get(font, glyphs, positions, 3) != original);
    glyphs[1] = 37;
    assert(cache.get(font, glyphs, positions, 3) == original);
    positions[2] = 11.5;
    assert(cache.get(font, glyphs, positions, 3) != original);
    positions[2] = 11.25;
    assert(cache.get(font, glyphs, positions, 3) == original);
    positions[2] += 1e-12; // The renderer consumes SkScalar positions.
    assert(cache.get(font, glyphs, positions, 3) == original);
    positions[2] = 11.25;
    for (int option = 0; option < 9; ++option) {
        auto changed = font;
        switch (option) {
        case 0: changed.setSize(15); break;
        case 1: changed.setScaleX(.9); break;
        case 2: changed.setSkewX(.2); break;
        case 3: changed.setEmbolden(!font.isEmbolden()); break;
        case 4: changed.setSubpixel(!font.isSubpixel()); break;
        case 5: changed.setLinearMetrics(!font.isLinearMetrics()); break;
        case 6: changed.setEmbeddedBitmaps(!font.isEmbeddedBitmaps()); break;
        case 7: changed.setEdging(SkFont::Edging::kAlias); break;
        case 8: changed.setHinting(SkFontHinting::kNone); break;
        }
        assert(changed != font);
        auto blob = cache.get(changed, glyphs, positions, 3);
        assert(blob && blob != original);
        assert(cache.get(changed, glyphs, positions, 3) == blob);
        assert(cache.get(font, glyphs, positions, 3) == original);
    }
    auto bounds = original->bounds();
    cache.clear();
    assert(cache.size() == 0 && cache.charged_bytes() == 0);
    assert(original->bounds() == bounds); // Returned blobs survive cache release.
    assert(cache.get(font, glyphs, positions, 3) != original);
    VoxGlyphTextBlobCache limited(4200, 1);
    auto first = limited.get(font, glyphs, positions, 3);
    glyphs[0] = 40;
    auto second = limited.get(font, glyphs, positions, 3);
    assert(first && second && first != second && limited.size() == 1);
    assert(limited.charged_bytes() <= 4200);
    glyphs[0] = 36;
    assert(limited.get(font, glyphs, positions, 3) != first);
    // The byte budget also evicts independently of the entry limit, honoring
    // recent use rather than the order in which runs were constructed.
    VoxGlyphTextBlobCache bytes_limited(8400, 10);
    first = bytes_limited.get(font, glyphs, positions, 3);
    glyphs[0] = 40;
    second = bytes_limited.get(font, glyphs, positions, 3);
    glyphs[0] = 36;
    assert(bytes_limited.get(font, glyphs, positions, 3) == first);
    glyphs[0] = 41;
    assert(bytes_limited.get(font, glyphs, positions, 3));
    assert(bytes_limited.size() == 2 && bytes_limited.charged_bytes() <= 8400);
    glyphs[0] = 36;
    assert(bytes_limited.get(font, glyphs, positions, 3) == first);
    glyphs[0] = 40;
    assert(bytes_limited.get(font, glyphs, positions, 3) != second);
    VoxGlyphTextBlobCache disabled(0);
    assert(disabled.get(font, glyphs, positions, 3));
    assert(disabled.size() == 0 && disabled.charged_bytes() == 0);
    assert(!disabled.get(font, nullptr, positions, 3));
    assert(!disabled.get(font, glyphs, nullptr, 3));
    assert(!disabled.get(font, glyphs, positions, 0));
    // Large one-off runs are still rendered but cannot evict the warm cache.
    std::vector<uint16_t> many_glyphs(4097, 36);
    std::vector<double> many_positions(8194);
    assert(cache.get(font, many_glyphs.data(), many_positions.data(), 4097));
    assert(cache.size() == 1);
    std::cout << "PASS positioned text blob identity, ownership, font state and bounded eviction\n";
}
