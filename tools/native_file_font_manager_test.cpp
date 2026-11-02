#include "../native_skia_text_darwin.cpp"
#include "include/core/SkFontMetrics.h"
#include <cassert>
#include <cstdio>

int main()
{
    auto reference_manager = font_manager(); assert(reference_manager);
    int cases = 0;
    for (auto path : {"/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/Apple Color Emoji.ttc"}) {
        auto data = SkData::MakeFromFileName(path); assert(data);
        auto candidate_manager = file_font_manager(data.get()); assert(candidate_manager);
        assert(candidate_manager->countFamilies() == 1);
        for (int index : {0, 1}) {
            SkFontArguments arguments; arguments.setCollectionIndex(index);
            auto reference = reference_manager->makeFromStream(std::make_unique<SkMemoryStream>(data), arguments);
            auto candidate = candidate_manager->makeFromStream(std::make_unique<SkMemoryStream>(data), arguments);
            assert(bool(reference) == bool(candidate));
            if (!reference) { ++cases; continue; }
            assert(reference->countGlyphs() == candidate->countGlyphs());
            assert(reference->getUnitsPerEm() == candidate->getUnitsPerEm());
            assert(reference->fontStyle() == candidate->fontStyle());
            // Compare the complete BMP mapping, not just the ASCII metrics
            // needed by the Hacker News workload.
            for (int codepoint = 0; codepoint < 65536; ++codepoint)
                assert(reference->unicharToGlyph(codepoint) == candidate->unicharToGlyph(codepoint));
            for (float size : {8.f, 16.f, 23.5f}) {
                SkFont first(reference, size), second(candidate, size);
                SkFontMetrics a {}, b {}; first.getMetrics(&a); second.getMetrics(&b);
                assert(!std::memcmp(&a, &b, sizeof(a)));
                auto info = SkImageInfo::MakeN32Premul(400, 100);
                auto expected = SkSurfaces::Raster(info), actual = SkSurfaces::Raster(info);
                assert(expected && actual);
                expected->getCanvas()->clear(SK_ColorWHITE); actual->getCanvas()->clear(SK_ColorWHITE);
                SkPaint paint; paint.setColor(SK_ColorBLACK); paint.setAntiAlias(true);
                char const* text = "Arial Aagj 123 — Привет Ελληνικά 😀";
                expected->getCanvas()->drawString(text, 4, 45, first, paint);
                actual->getCanvas()->drawString(text, 4, 45, second, paint);
                SkPixmap ep, ap; assert(expected->peekPixels(&ep) && actual->peekPixels(&ap));
                for (int y = 0; y < 100; ++y) assert(!std::memcmp(ep.addr(0, y), ap.addr(0, y), 400 * 4));
                ++cases;
            }
        }
    }
    auto invalid = SkData::MakeWithCopy("bad", 3);
    auto manager = file_font_manager(invalid.get()); assert(manager);
    assert(!manager->makeFromData(invalid));
    assert(file_font_manager(nullptr).get() == reference_manager.get());
    setenv("VOX_DISABLE_FILE_FONT_MANAGER", "1", 1);
    assert(file_font_manager(invalid.get()).get() == reference_manager.get());
    unsetenv("VOX_DISABLE_FILE_FONT_MANAGER");
    setenv("LADYBIRD_LAYOUT_TEST_FONT", "fixture", 1);
    assert(file_font_manager(invalid.get()).get() == reference_manager.get());
    unsetenv("LADYBIRD_LAYOUT_TEST_FONT");
    std::printf("PASS %d font stream/glyph/metrics/raster comparisons and manager fallback guards\n", cases);
}
