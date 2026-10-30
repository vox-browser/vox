#include <CoreText/CoreText.h>
#include <hb.h>
#include <hb-ot.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

static unsigned data_copies, payload_releases;
static void *watched_payload;
static CFDataRef tracked_data(CFAllocatorRef allocator, const UInt8 *bytes, CFIndex length) {
    ++data_copies;
    return CFDataCreate(allocator, bytes, length);
}
static void tracked_free(void *pointer) {
    if (pointer == watched_payload) {
        ++payload_releases;
        watched_payload = NULL;
    }
    free(pointer);
}
#define CFDataCreate tracked_data
#define free tracked_free
#include "platform/harfbuzz_coretext_macos.h"
#undef free
#undef CFDataCreate

static hb_font_t *scaled(hb_face_t *face, unsigned size) {
    hb_font_t *font = hb_font_create(face);
    hb_ot_font_set_funcs(font);
    hb_font_set_scale(font, size * 64, size * 64);
    hb_font_set_ptem(font, size);
    return font;
}

static void check_face(const char *path, unsigned index, int expect_synthesized) {
    hb_blob_t *blob = hb_blob_create_from_file_or_fail(path);
    assert(blob && hb_blob_get_length(blob));
    hb_face_t *face = hb_face_create(blob, index);
    hb_font_t *oracle = scaled(face, 12);
    CTFontRef native = vox_hb_coretext_font(face);
    assert(native);
    hb_codepoint_t expected[2] = { 0, 0 };
    int missing = 0, synthesized = 0;
    for (unsigned i = 0; i < 2; ++i) {
        if (!hb_font_get_nominal_glyph(oracle, 0x2010 + i, &expected[i]) || !expected[i]) {
            ++missing;
            UniChar character = 0x2010 + i;
            CGGlyph glyph = 0;
            if (CTFontGetGlyphsForCharacters(native, &character, &glyph, 1))
                expected[i] = glyph;
            if (expected[i]) ++synthesized;
        }
    }
    CFRelease(native);
    hb_font_destroy(oracle);
    assert(missing);
    assert((synthesized != 0) == expect_synthesized);
    unsigned copies_before = data_copies;
    assert(!hb_face_get_user_data(face, &vox_hb_coretext_hyphens_key));
    for (unsigned size = 5; size <= 36; ++size) {
        hb_font_t *parent = scaled(face, size);
        hb_font_t *mapped = vox_hb_with_coretext_hyphens(parent);
        assert(mapped);
        hb_font_t *result = mapped ? mapped : parent;
        // Creating scaled fonts and looking up ordinary/missing characters
        // must not open CoreText's full backing collection for hyphen fallback.
        for (unsigned character = 32; character < 127; ++character) {
            hb_codepoint_t original = 0, actual = 0;
            hb_font_get_nominal_glyph(parent, character, &original);
            hb_font_get_nominal_glyph(result, character, &actual);
            assert(actual == original);
        }
        hb_codepoint_t absent = 0;
        assert(!hb_font_get_nominal_glyph(result, 0x10ffff, &absent));
        assert(data_copies == copies_before + (size > 5));
        for (unsigned i = 0; i < 2; ++i) {
            hb_codepoint_t glyph = 0;
            hb_font_get_nominal_glyph(result, 0x2010 + i, &glyph);
            assert(glyph == expected[i]);
            if (glyph)
                assert(hb_font_get_glyph_h_advance(result, glyph)
                    == hb_font_get_glyph_h_advance(parent, glyph));
        }
        hb_codepoint_t original = 0, actual = 0;
        hb_font_get_nominal_glyph(parent, 'A', &original);
        hb_font_get_nominal_glyph(result, 'A', &actual);
        assert(actual == original);
        if (mapped) hb_font_destroy(mapped);
        hb_font_destroy(parent);
        assert(data_copies == copies_before + 1);
    }
    watched_payload = hb_face_get_user_data(face, &vox_hb_coretext_hyphens_key);
    assert(watched_payload);
    unsigned released_before = payload_releases;
    hb_face_destroy(face);
    assert(payload_releases == released_before + 1 && !watched_payload);
    // Reopening the same source must create a fresh face-owned cache.
    face = hb_face_create(blob, index);
    hb_font_t *parent = scaled(face, 18);
    hb_font_t *mapped = vox_hb_with_coretext_hyphens(parent);
    assert(mapped && data_copies == copies_before + 1);
    hb_codepoint_t glyph = 0;
    hb_font_get_nominal_glyph(mapped, 0x2011, &glyph);
    assert(glyph == expected[1]);
    assert(data_copies == copies_before + 2);
    if (mapped) hb_font_destroy(mapped);
    hb_font_destroy(parent);
    hb_face_destroy(face);
    hb_blob_destroy(blob);
    printf("PASS %s[%u]: lazy native probe across 32 sizes; glyphs, advances and retirement\n", path, index);
}

int main(void) {
    check_face("/System/Library/Fonts/Supplemental/Arial.ttf", 0, 1);
    check_face("/System/Library/Fonts/Supplemental/Times New Roman.ttf", 0, 1);
    check_face("/System/Library/Fonts/Apple Color Emoji.ttc", 0, 0);
    return 0;
}
