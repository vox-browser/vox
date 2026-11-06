// A scroll/damage clip is a union, whose bounding rectangle can contain holes.
#include "../native_skia_text_darwin.cpp"
#include <cassert>
#include <cstdio>

static CGContextRef frame()
{
    auto space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    auto context = CGBitmapContextCreate(nullptr, 1024, 852, 8, 4096, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    assert(context);
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 1024, 852));
    return context;
}

int main()
{
    char const* path = "/System/Library/Fonts/HelveticaNeue.ttc";
    auto* face = select_typeface(path, 0, 400, 0);
    assert(face);
    SkFont font(sk_ref_sp(face), 65);
    char const text[] = "Partial repaint keeps retained text";
    int count = font.countText(text, sizeof(text) - 1, SkTextEncoding::kUTF8);
    std::vector<uint16_t> glyphs(count);
    assert(font.textToGlyphs(text, sizeof(text) - 1, SkTextEncoding::kUTF8,
        SkSpan<SkGlyphID>(glyphs.data(), count)) == count);
    std::vector<float> widths(count);
    font.getWidths(SkSpan<SkGlyphID const>(glyphs.data(), count), widths);
    std::vector<double> positions(size_t(count) * 2);
    double advance = 0;
    for (int i = 0; i < count; ++i) {
        positions[size_t(i) * 2] = advance;
        advance += widths[i];
    }
    auto draw = [&](CGContextRef context, bool direct) {
        assert(ladybird_v_skia_draw_glyph_run(context, path, 0, glyphs.data(),
            positions.data(), count, 65, 400, 0, 284, 714, 1, 0, 0, 1, 0, 0,
            0, 60, 0, 1024, 852, 19, 19, 19, 255,
            16 | 32 | 2 | (direct ? VOX_GLYPH_PRIVATE_BITMAP : 0)));
    };
    unsigned cases = 0;
    for (bool tracked_rect : {false, true}) for (bool copy_only : {false, true}) {
        auto actual = frame(), expected = frame();
        // Seed the retained text. Only the left part will be damaged below.
        draw(actual, false); draw(expected, false);
        CGRect clips[] {CGRectMake(0, 24, 400, 701), CGRectMake(0, 700, 1024, 25)};
        float damage[] {0, 127, 400, 701, 0, 127, 1024, 25};
        for (auto context : {actual, expected}) {
            CGContextSaveGState(context);
            CGContextClipToRects(context, clips, 2);
            CGContextSetRGBFillColor(context, 1, 1, 1, 1);
            CGContextFillRect(context, CGRectMake(0, 0, 1024, 852));
            if (tracked_rect) {
                ladybird_v_skia_save_shared_clip(context);
                float rect[] {0, 127, 1024, 701, 0, 0, 0, 0, 0, 0, 0, 0};
                float matrix[] {1, 0, 0, 1, 0, 0};
                ladybird_v_skia_add_shared_rounded_clip(context, rect, matrix);
            }
        }
        if (copy_only) setenv("VOX_DISABLE_DIRECT_GLYPH_SURFACE", "1", 1);
        else unsetenv("VOX_DISABLE_DIRECT_GLYPH_SURFACE");
        ladybird_v_skia_set_scroll_damage_rects(actual, damage, 2);
        assert(!glyph_bitmap_clip_is_rectangular(actual));
        assert(glyph_bitmap_clip_is_rectangular(expected) == !tracked_rect);
        SkIRect device_clip;
        assert(!glyph_bitmap_device_clip(actual, 1, 852, device_clip));
        draw(actual, true);
        ladybird_v_skia_set_scroll_damage_rects(expected, damage, 2);
        draw(expected, false);
        ladybird_v_skia_set_scroll_damage_rects(nullptr, nullptr, 0);
        for (auto context : {actual, expected}) {
            if (tracked_rect) ladybird_v_skia_restore_shared_clip(context);
            CGContextRestoreGState(context);
            CGContextFlush(context);
            assert(glyph_bitmap_clip_is_rectangular(context));
        }
        auto* a = static_cast<uint8_t*>(CGBitmapContextGetData(actual));
        auto* b = static_cast<uint8_t*>(CGBitmapContextGetData(expected));
        size_t differing = 0;
        for (size_t i = 0; i < 1024 * 852; ++i)
            differing += std::memcmp(a + i * 4, b + i * 4, 4) != 0;
        std::printf("Glyph damage clip: tracked=%d copy=%d differing=%zu\n",
            tracked_rect, copy_only, differing);
        std::fflush(stdout);
        assert(differing == 0);
        CGContextRelease(actual); CGContextRelease(expected);
        ++cases;
    }
    unsetenv("VOX_DISABLE_DIRECT_GLYPH_SURFACE");
    std::printf("PASS %u disjoint damage clips preserve retained text\n", cases);
}
