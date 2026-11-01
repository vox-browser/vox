// Compare mask-equivalent fractional scroll positions with the original raster.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

int main()
{
    auto path = std::getenv("VOX_SKIA_REFERENCE_LIBRARY"); assert(path);
    auto library = dlopen(path, RTLD_NOW | RTLD_LOCAL); assert(library);
    auto reference = reinterpret_cast<decltype(&ladybird_v_skia_draw_glyph_run)>(
        dlsym(library, "ladybird_v_skia_draw_glyph_run")); assert(reference);
    uint16_t glyphs[] {36, 37, 38, 39, 40, 41};
    double positions[] {0, 0, 11.375, .125, 22.5, -.125, 34.25, 0, 46, .5, 57.5, -.5};
    int comparisons = 0;
    for (int scale : {1, 2}) for (float size : {8.5f, 14.f, 24.25f, 65.f})
    for (int clip : {0, 1, 2}) for (int smoothing : {16, 17, 18, 48, 50, 80}) {
        int width = 128 * scale, height = 96 * scale, pitch = width * 4 + 16;
        std::vector<uint8_t> expected(size_t(pitch) * height), actual(expected.size());
        auto color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        auto make = [&](auto& pixels) {
            auto context = CGBitmapContextCreate(pixels.data(), width, height, 8, pitch, color,
                CGBitmapInfo(kCGImageAlphaPremultipliedLast) | kCGBitmapByteOrder32Big);
            assert(context); CGContextScaleCTM(context, scale, scale);
            if (clip == 1) CGContextClipToRect(context, CGRectMake(14.25, 22.5, 53.75, 31.25));
            if (clip == 2) { CGContextAddEllipseInRect(context, CGRectMake(12.25, 20.5, 60.75, 37.25)); CGContextClip(context); }
            return context;
        };
        auto before = make(expected), after = make(actual); CGColorSpaceRelease(color);
        GlyphRasterCache warm;
        for (int step = 0; step < 72; ++step) {
            // Include tiny float drift, quarter-mask transitions, baseline-snap
            // transitions, clipping changes and both directions of travel.
            float scroll = step < 36 ? float(step) * .2f : float(71 - step) * .2f + .00001f;
            for (auto* pixels : {&expected, &actual})
                for (size_t i = 0; i < pixels->size(); i += 4) {
                    (*pixels)[i] = 43; (*pixels)[i + 1] = 67;
                    (*pixels)[i + 2] = 89; (*pixels)[i + 3] = 255;
                }
            auto draw = [&](auto context, auto function) {
                return function(context, "/System/Library/Fonts/HelveticaNeue.ttc", 0,
                    glyphs, positions, 6, size, 400, 0, 15.375, 46.25,
                    1, 0, 0, 1, float(step % 18) * .05f + (step >= 36 ? .00001f : 0), 0,
                    0, 0, scroll, 128, 96, 197, 37, 83, 201, smoothing);
            };
            s_glyph_raster_cache.clear(); assert(draw(before, reference));
            std::swap(s_glyph_raster_cache, warm); assert(draw(after, &ladybird_v_skia_draw_glyph_run));
            std::swap(s_glyph_raster_cache, warm);
            CGContextFlush(before); CGContextFlush(after);
            if (expected != actual) {
                std::fprintf(stderr, "mask key differs scale=%d size=%g clip=%d smoothing=%d step=%d scroll=%g\n",
                    scale, size, clip, smoothing, step, scroll); return 1;
            }
            ++comparisons;
        }
        CGContextRelease(before); CGContextRelease(after);
    }
    auto* face = select_typeface("/System/Library/Fonts/HelveticaNeue.ttc", 0, 400, 0); assert(face);
    SkFont font(sk_ref_sp(face), 14); font.setSubpixel(true); font.setEmbeddedBitmaps(false);
    std::vector<uint8_t> first, same, next;
    auto matrix = SkMatrix::I(); auto bounds = SkRect::MakeWH(80, 20);
    assert(append_cpu_mask_positions(first, font, matrix, bounds, 10, 20.00001f, glyphs, positions, 6));
    assert(append_cpu_mask_positions(same, font, matrix, bounds, 10, 20.00002f, glyphs, positions, 6));
    assert(append_cpu_mask_positions(next, font, matrix, bounds, 10, 20.75f, glyphs, positions, 6));
    assert(first == same && first != next);
    font.setBaselineSnap(false);
    std::vector<uint8_t> rejected;
    assert(!append_cpu_mask_positions(rejected, font, matrix, bounds, 10, 20, glyphs, positions, 6));
    assert(rejected.empty());
    font.setBaselineSnap(true); font.setEmbeddedBitmaps(true);
    assert(!append_cpu_mask_positions(rejected, font, matrix, bounds, 10, 20, glyphs, positions, 6));
    font.setEmbeddedBitmaps(false);
    auto skewed = SkMatrix::MakeAll(1, .125f, 0, 0, 1, 0, 0, 0, 1);
    assert(!append_cpu_mask_positions(rejected, font, skewed, bounds, 10, 20, glyphs, positions, 6));
    font.setSize(129);
    assert(!append_cpu_mask_positions(rejected, font, matrix, bounds, 10, 20, glyphs, positions, 6));
    assert(rejected.empty());
    std::printf("CPU mask cache: %d exact fractional replay comparisons; equivalent and distinct keys checked\n", comparisons);
}
