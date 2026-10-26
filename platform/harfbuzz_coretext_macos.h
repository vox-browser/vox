// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#pragma once

#include <CoreText/CoreText.h>
#include <hb.h>
#include <stdlib.h>
#include <string.h>

// Blink's HarfBuzzGetGlyph also asks Skia/CoreText for U+2010 and U+2011
// when the OpenType cmap has no glyph. CoreText synthesizes these even for
// downloaded faces. Keep the original Unicode and clusters in the buffer;
// only nominal glyph lookup changes, before normal OpenType shaping.
static hb_bool_t vox_hb_coretext_nominal_glyph(hb_font_t *font, void *font_data,
    hb_codepoint_t unicode, hb_codepoint_t *glyph, void *user_data) {
    (void)user_data;
    if (hb_font_get_nominal_glyph(hb_font_get_parent(font), unicode, glyph))
        return *glyph != 0;
    if (unicode != 0x2010 && unicode != 0x2011)
        return false;
    *glyph = ((hb_codepoint_t *)font_data)[unicode - 0x2010];
    return *glyph != 0;
}

// The descriptor list can contain named instances as well as collection
// members. Match the exact name table rather than assuming its array index
// is the sfnt collection index. No installed-family lookup may substitute a
// different font for a document face.
static CTFontRef vox_hb_coretext_font(hb_face_t *face) {
    hb_blob_t *blob = hb_face_reference_blob(face);
    unsigned int length = 0;
    const char *bytes = hb_blob_get_data(blob, &length);
    CFDataRef data = CFDataCreate(NULL, (const UInt8 *)bytes, length);
    hb_blob_destroy(blob);
    if (!data)
        return NULL;
    CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromData(data);
    CFRelease(data);
    if (!descriptors)
        return NULL;
    hb_blob_t *names = hb_face_reference_table(face, HB_TAG('n', 'a', 'm', 'e'));
    unsigned int name_length = 0;
    const char *name_bytes = hb_blob_get_data(names, &name_length);
    CTFontRef selected = NULL;
    for (CFIndex i = 0; name_length && i < CFArrayGetCount(descriptors); ++i) {
        CTFontRef font = CTFontCreateWithFontDescriptor(
            (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, i), 12, NULL);
        if (!font)
            continue;
        CFDataRef table = CTFontCopyTable(font, kCTFontTableName, kCTFontTableOptionNoOptions);
        int matches = table && CFDataGetLength(table) == name_length
            && !memcmp(CFDataGetBytePtr(table), name_bytes, name_length);
        if (table)
            CFRelease(table);
        if (matches) {
            selected = font;
            break;
        }
        CFRelease(font);
    }
    hb_blob_destroy(names);
    CFRelease(descriptors);
    return selected;
}

// Returns a new owned sub-font only when the native face supplies a missing
// hyphen. Its parent continues to supply all advances, metrics and other
// glyph mappings. HarfBuzz owns the small mapping until cache retirement.
static hb_font_t *vox_hb_with_coretext_hyphens(hb_font_t *parent) {
    hb_codepoint_t glyphs[2] = { 0, 0 };
    int missing[2];
    for (int i = 0; i < 2; ++i)
        missing[i] = !hb_font_get_nominal_glyph(parent, 0x2010 + i, &glyphs[i]) || !glyphs[i];
    if (!missing[0] && !missing[1])
        return NULL;
    CTFontRef native = vox_hb_coretext_font(hb_font_get_face(parent));
    if (!native)
        return NULL;
    int supplied = 0;
    for (int i = 0; i < 2; ++i) {
        if (!missing[i])
            continue;
        UniChar character = 0x2010 + i;
        CGGlyph glyph = 0;
        if (CTFontGetGlyphsForCharacters(native, &character, &glyph, 1) && glyph) {
            glyphs[i] = glyph;
            supplied = 1;
        }
    }
    CFRelease(native);
    if (!supplied)
        return NULL;
    hb_codepoint_t *mapping = malloc(sizeof(glyphs));
    if (!mapping)
        return NULL;
    memcpy(mapping, glyphs, sizeof(glyphs));
    hb_font_t *font = hb_font_create_sub_font(parent);
    hb_font_funcs_t *funcs = hb_font_funcs_create();
    if (font == hb_font_get_empty() || funcs == hb_font_funcs_get_empty()) {
        hb_font_destroy(font);
        hb_font_funcs_destroy(funcs);
        free(mapping);
        return NULL;
    }
    hb_font_funcs_set_nominal_glyph_func(funcs, vox_hb_coretext_nominal_glyph, NULL, NULL);
    hb_font_funcs_make_immutable(funcs);
    hb_font_set_funcs(font, funcs, mapping, free);
    hb_font_funcs_destroy(funcs);
    return font;
}
