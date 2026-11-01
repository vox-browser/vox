// A tight glyph surface must retain the subpixel phase of a full document draw.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto* face = select_typeface("/System/Library/Fonts/HelveticaNeue.ttc", 0, 400, 0);
    assert(face);
    SkFont font(sk_ref_sp(face), 15);
    font.setSubpixel(true);
    font.setEdging(SkFont::Edging::kAntiAlias);
    font.setHinting(SkFontHinting::kNone);
    font.setEmbeddedBitmaps(false);
    font.setLinearMetrics(true);
    uint16_t glyph = face->unicharToGlyph('m');
    double positions[2] {};
    SkSurfaceProps props(0, kUnknown_SkPixelGeometry, 0.f, 1.f);
    SkPaint paint;
    paint.setColor(0xffaac6e8);
    VoxGlyphTextBlobCache cache;
    int cases = 0;
    for (int scale : {1, 2}) for (float x : {17.5f, 193.5f, 449.5f, 705.5f, 961.5f})
    for (int side : {-1, 0, 1}) {
        // A fixed-point advance can leave the glyph just below a quarter-mask
        // boundary. Do not change that advance to compensate for the crop.
        positions[0] = side < 0 ? std::nextafter(16.875f, 0.f)
            : side > 0 ? std::nextafter(16.875f, 100.f) : 16.875f;
        int crop = int(x) - 2, width = 48 * scale, height = 40 * scale;
        int document_width = 1100 * scale;
        std::vector<uint32_t> document(size_t(document_width) * height, 0xff0f0b09);
        std::vector<uint32_t> leaf(size_t(width) * height, 0xff0f0b09);
        auto info = SkImageInfo::MakeN32Premul(document_width, height, SkColorSpace::MakeSRGB());
        auto full_surface = SkSurfaces::WrapPixels(info, document.data(), document_width * 4, &props);
        auto leaf_surface = SkSurfaces::WrapPixels(info.makeWH(width, height), leaf.data(), width * 4, &props);
        assert(full_surface && leaf_surface);
        auto relative = cache.get(font, &glyph, positions, 1);
        auto positioned = cache.get(font, &glyph, positions, 1, {x, 24});
        // Independent oracle: the original relative run on an uncropped canvas.
        full_surface->getCanvas()->scale(scale, scale);
        full_surface->getCanvas()->drawTextBlob(relative, x, 24, paint);
        leaf_surface->getCanvas()->scale(scale, scale);
        leaf_surface->getCanvas()->translate(-crop, 0);
        leaf_surface->getCanvas()->drawTextBlob(positioned, 0, 0, paint);
        for (int y = 0; y < height; ++y) for (int column = 0; column < width; ++column)
            assert(leaf[size_t(y) * width + column]
                == document[size_t(y) * document_width + crop * scale + column]);
        assert(cache.get(font, &glyph, positions, 1, {x, 24}) == positioned);
        assert(cache.get(font, &glyph, positions, 1, {x + 1, 24}) != positioned);
        assert(cache.get(font, &glyph, positions, 1, {x, 25}) != positioned);
        ++cases;
    }

    // Two locally equivalent masks can differ after adding the document origin.
    // The compact raster-cache key must describe the positioned blob too.
    auto bounds = SkRect::MakeWH(80, 20);
    auto matrix = SkMatrix::Translate(-960, 0);
    std::vector<uint8_t> local_first, local_second, document_first, document_second;
    positions[0] = 16.87496f;
    assert(append_cpu_mask_positions(local_first, font, matrix, bounds, 961.5, 24,
        &glyph, positions, 1));
    assert(append_cpu_mask_positions(document_first, font, matrix, bounds, 961.5, 24,
        &glyph, positions, 1, true));
    positions[0] = 16.8749847412109375;
    assert(append_cpu_mask_positions(local_second, font, matrix, bounds, 961.5, 24,
        &glyph, positions, 1));
    assert(append_cpu_mask_positions(document_second, font, matrix, bounds, 961.5, 24,
        &glyph, positions, 1, true));
    assert(local_first == local_second);
    assert(document_first != document_second);
    std::printf("Glyph origins: %d exact cropped/full-canvas comparisons; positioned blob and mask keys checked\n", cases);
}
