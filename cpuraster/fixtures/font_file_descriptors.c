#include <CoreText/CoreText.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int descriptor_parses;
static CFArrayRef counted_descriptors_from_url(CFURLRef url) {
    ++descriptor_parses;
    return CTFontManagerCreateFontDescriptorsFromURL(url);
}
#define CTFontManagerCreateFontDescriptorsFromURL counted_descriptors_from_url
#include "../glyph_coretext.h"
#undef CTFontManagerCreateFontDescriptorsFromURL

#define CHECK(test) do { if (!(test)) { fprintf(stderr, "line %d: %s\n", __LINE__, #test); return 1; } } while (0)

// Keys for one font file share its parsed descriptors; each still resolves
// to a face that draws the same glyph.
int main(int argc, char** argv) {
    CHECK(argc == 2);
    const char* path = argv[1];
    const char* keys[] = { "file-descriptors-400", "file-descriptors-700", "file-descriptors-900" };
    float weights[] = { 400, 700, 900 };
    uint32_t tag = 0x77676874; // wght
    for (int i = 0; i < 3; ++i)
        CHECK(cpuraster_ct_register_face(keys[i], path, "", &tag, &weights[i], 1));
    const char* disabled = getenv("VOX_DISABLE_FONT_FILE_DESCRIPTOR_CACHE");
    int expected = disabled && *disabled ? 3 : 1;
    CHECK(descriptor_parses == expected);
    for (int i = 0; i < 3; ++i) {
        int flags = -1;
        CTFontRef font = cpuraster_ct_font_for_face(keys[i], 0, &flags);
        CHECK(font);
        UniChar text = 'A';
        CGGlyph glyph = 0;
        CHECK(CTFontGetGlyphsForCharacters(font, &text, &glyph, 1) && glyph);
        CFRelease(font);
    }
    printf("%d descriptor parses for 3 keys\n", descriptor_parses);
    return 0;
}
