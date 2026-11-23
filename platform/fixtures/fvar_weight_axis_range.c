#include <CoreText/CoreText.h>
#include <stdio.h>

static int axes_queries;
static CFArrayRef counted_variation_axes(CTFontRef font) {
    ++axes_queries;
    return CTFontCopyVariationAxes(font);
}
#define CTFontCopyVariationAxes counted_variation_axes
#include "../coretext_macos.h"
#undef CTFontCopyVariationAxes

#define CHECK(test) do { if (!(test)) { fprintf(stderr, "line %d: %s\n", __LINE__, #test); return 1; } } while (0)

// The wght range CoreText itself reports.
static int coretext_weight_range(CTFontRef font, double *minimum, double *maximum) {
    CFArrayRef axes = CTFontCopyVariationAxes(font);
    int found = 0;
    for (CFIndex index = 0; axes && index < CFArrayGetCount(axes) && !found; ++index) {
        CFDictionaryRef axis = (CFDictionaryRef)CFArrayGetValueAtIndex(axes, index);
        if ((int)vox_ct_number(axis, kCTFontVariationAxisIdentifierKey) == 0x77676874) {
            *minimum = vox_ct_number(axis, kCTFontVariationAxisMinimumValueKey);
            *maximum = vox_ct_number(axis, kCTFontVariationAxisMaximumValueKey);
            found = 1;
        }
    }
    if (axes) CFRelease(axes);
    return found;
}

static int check_font(CTFontRef font, const char *label, int expect_coretext_queries) {
    CHECK(font);
    double expected_minimum = 0, expected_maximum = 0, minimum = 0, maximum = 0;
    int expected = coretext_weight_range(font, &expected_minimum, &expected_maximum);
    int before = axes_queries;
    int found = vox_ct_weight_axis_range(font, &minimum, &maximum);
    int queries = axes_queries - before;
    printf("%s found=%d range=%g..%g coretext queries=%d\n", label, found, minimum, maximum, queries);
    CHECK(found == expected);
    CHECK(!found || (minimum == expected_minimum && maximum == expected_maximum));
    if (expect_coretext_queries >= 0) CHECK(queries == expect_coretext_queries);
    return 0;
}

int main(void) {
    const char *disabled = getenv("VOX_DISABLE_FVAR_WEIGHT_AXIS_RANGE");
    int table = !(disabled && *disabled);
    CTFontRef system = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 14, NULL);
    CHECK(check_font(system, "system", table ? 0 : 1) == 0);
    CTFontRef emphasized = CTFontCreateUIFontForLanguage(kCTFontUIFontEmphasizedSystem, 20, NULL);
    CHECK(check_font(emphasized, "emphasized system", table ? 0 : 1) == 0);
    // Skia's limits are fractional, so CoreText's rounding still decides them.
    CTFontRef skia = CTFontCreateWithName(CFSTR("Skia"), 14, NULL);
    CHECK(check_font(skia, "Skia", 1) == 0);
    const CFStringRef names[] = { CFSTR("Helvetica"), CFSTR("Menlo"), CFSTR("Avenir Next"), CFSTR("Apple Color Emoji") };
    for (int i = 0; i < 4; ++i) {
        CTFontRef font = CTFontCreateWithName(names[i], 14, NULL);
        CHECK(check_font(font, "installed face", -1) == 0);
        CFRelease(font);
    }
    CFRelease(skia);
    CFRelease(emphasized);
    CFRelease(system);
    return 0;
}
