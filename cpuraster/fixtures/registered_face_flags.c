#include <CoreText/CoreText.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>

static atomic_int axes_queries;
static CFArrayRef counted_variation_axes(CTFontRef font) {
    atomic_fetch_add(&axes_queries, 1);
    return CTFontCopyVariationAxes(font);
}
#define CTFontCopyVariationAxes counted_variation_axes
#include "../glyph_coretext.h"
#undef CTFontCopyVariationAxes

#define CHECK(test) do { if (!(test)) { fprintf(stderr, "line %d: %s\n", __LINE__, #test); return 1; } } while (0)

static int expected_flags(CTFontRef font) {
    int flags = (CTFontGetSymbolicTraits(font) & kCTFontColorGlyphsTrait) ? 1 : 0;
    CFArrayRef axes = CTFontCopyVariationAxes(font);
    if (axes) {
        if (CFArrayGetCount(axes)) flags |= 2;
        CFRelease(axes);
    }
    return flags;
}

static int draw_face(CTFontRef font, CGGlyph glyph, unsigned char* pixels) {
    memset(pixels, 0, 48 * 48 * 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 48, 48, 8, 48 * 4,
        space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CHECK(context);
    CGContextSetRGBFillColor(context, 0.1, 0.2, 0.3, 1);
    CGPoint position = CGPointMake(10, 15);
    CTFontDrawGlyphs(font, &glyph, &position, 1, context);
    CGContextRelease(context);
    int ink = 0;
    for (int i = 3; i < 48 * 48 * 4; i += 4) ink |= pixels[i];
    CHECK(ink);
    return 0;
}

static int check_registered_face(const char* key, CTFontRef source, float weight) {
    CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(source);
    CFURLRef url = (CFURLRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute);
    CFStringRef name = CTFontCopyPostScriptName(source);
    char path[4096], postscript[1024];
    CHECK(url && name);
    CHECK(CFURLGetFileSystemRepresentation(url, true, (UInt8*)path, sizeof(path)));
    CHECK(CFStringGetCString(name, postscript, sizeof(postscript), kCFStringEncodingUTF8));
    uint32_t tag = 0x77676874; // wght
    CHECK(cpuraster_ct_register_face(key, path, postscript, &tag, &weight, 1));
    CFRelease(name);
    CFRelease(url);
    CFRelease(descriptor);

    int before = atomic_load(&axes_queries), flags = -1;
    CTFontRef first = cpuraster_ct_font_for_face(key, 0, &flags);
    CHECK(first);
    CHECK(flags == expected_flags(first));
    int expected = flags;
    UniChar text[2] = { flags & 1 ? 0xd83d : 'A', 0xde00 };
    CGGlyph glyphs[2] = {0};
    CTFontGetGlyphsForCharacters(first, text, glyphs, flags & 1 ? 2 : 1);
    CGGlyph glyph = glyphs[0];
    CHECK(glyph);
    unsigned char pixels[48 * 48 * 4], next_pixels[48 * 48 * 4];
    CHECK(draw_face(first, glyph, pixels) == 0);
    CGSize advance;
    CGRect bounds = CTFontGetBoundingRectsForGlyphs(first, kCTFontOrientationHorizontal, &glyph, NULL, 1);
    CTFontGetAdvancesForGlyphs(first, kCTFontOrientationHorizontal, &glyph, &advance, 1);
    for (int i = 0; i < 16; ++i) {
        flags = -1;
        CTFontRef next = cpuraster_ct_font_for_face(key, 0, &flags);
        CHECK(next && flags == expected);
        CHECK(CGRectEqualToRect(bounds, CTFontGetBoundingRectsForGlyphs(next, kCTFontOrientationHorizontal, &glyph, NULL, 1)));
        CGSize next_advance;
        CTFontGetAdvancesForGlyphs(next, kCTFontOrientationHorizontal, &glyph, &next_advance, 1);
        CHECK(CGSizeEqualToSize(advance, next_advance));
        CHECK(draw_face(next, glyph, next_pixels) == 0);
        CHECK(memcmp(pixels, next_pixels, sizeof(pixels)) == 0);
        CFRelease(next);
    }
    CFRelease(first);
    const char* disabled = getenv("VOX_DISABLE_REGISTERED_FACE_FLAGS_CACHE");
    int queries = disabled && *disabled ? 17 : 1;
    CHECK(atomic_load(&axes_queries) - before == queries);
    printf("%s flags=%d; 17 opens, %d axes queries\n", key, expected, queries);
    return 0;
}

int main(int argc, char** argv) {
    CHECK(argc == 2);
    CTFontRef system = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 12, NULL);
    CTFontRef color = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 12, NULL);
    CHECK(system && color);
    CHECK(expected_flags(system) & 2);
    CHECK(expected_flags(color) & 1);
    CHECK(check_registered_face("flags-system-400", system, 400) == 0);
    CHECK(check_registered_face("flags-system-700", system, 700) == 0);
    CHECK(check_registered_face("flags-color", color, 400) == 0);
    CFRelease(color);
    CFRelease(system);

    // Ordinary file paths keep their existing lifetime and reload behavior.
    int before = atomic_load(&axes_queries);
    for (int i = 0; i < 2; ++i) {
        int flags = -1;
        CTFontRef font = cpuraster_ct_font_for_face(argv[1], 0, &flags);
        CHECK(font && flags == expected_flags(font));
        CFRelease(font);
    }
    CHECK(atomic_load(&axes_queries) - before == 2);
    int flags = -1;
    CHECK(!cpuraster_ct_font_for_face("/nonexistent/vox-font.ttf", 0, &flags));
    CHECK(flags == 0);
    return 0;
}
