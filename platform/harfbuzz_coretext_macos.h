// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
#pragma once

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)

#include <CoreText/CoreText.h>
#include <hb.h>
#include <stdlib.h>
#include <string.h>

// Blink's HarfBuzzGetGlyph also asks Skia/CoreText for U+2010 and U+2011
// when the OpenType cmap has no glyph. CoreText synthesizes these even for
// downloaded faces. Keep the original Unicode and clusters in the buffer;
// only nominal glyph lookup changes, before normal OpenType shaping.
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

typedef struct {
    hb_codepoint_t glyphs[2];
} vox_hb_coretext_hyphens;

static hb_user_data_key_t vox_hb_coretext_hyphens_key;

// The native probe always uses the selected face at 12pt, without variations.
// Its nominal glyph IDs therefore belong to the face, independently of the
// scaled HarfBuzz font. Retain misses too: a color emoji face can have hundreds
// of megabytes of tables and still supply neither synthesized hyphen.
static const vox_hb_coretext_hyphens *vox_hb_cached_coretext_hyphens(hb_face_t *face) {
    const vox_hb_coretext_hyphens *cached = hb_face_get_user_data(face,
        &vox_hb_coretext_hyphens_key);
    if (cached)
        return cached;
    vox_hb_coretext_hyphens *result = calloc(1, sizeof(*result));
    if (!result)
        return NULL;
    CTFontRef native = vox_hb_coretext_font(face);
    if (native) {
        for (int i = 0; i < 2; ++i) {
            UniChar character = 0x2010 + i;
            CGGlyph glyph = 0;
            if (CTFontGetGlyphsForCharacters(native, &character, &glyph, 1))
                result->glyphs[i] = glyph;
        }
        CFRelease(native);
    }
    // HarfBuzz releases this payload with the face during native cache
    // retirement. A concurrent publisher wins without replacing live data.
    if (!hb_face_set_user_data(face, &vox_hb_coretext_hyphens_key, result, free, false)) {
        free(result);
        return hb_face_get_user_data(face, &vox_hb_coretext_hyphens_key);
    }
    return result;
}

static hb_bool_t vox_hb_coretext_nominal_glyph(hb_font_t *font, void *font_data,
    hb_codepoint_t unicode, hb_codepoint_t *glyph, void *user_data) {
    (void)font_data;
    (void)user_data;
    if (hb_font_get_nominal_glyph(hb_font_get_parent(font), unicode, glyph))
        return *glyph != 0;
    if (unicode != 0x2010 && unicode != 0x2011)
        return false;
    const vox_hb_coretext_hyphens *native = vox_hb_cached_coretext_hyphens(hb_font_get_face(font));
    *glyph = native ? native->glyphs[unicode - 0x2010] : 0;
    return *glyph != 0;
}

// Install a lazy nominal-glyph override when the cmap lacks a hyphen. Ordinary
// text and emoji coverage never need CoreText's synthesized-hyphen lookup;
// opening a large color-font collection for those queries copies all its data.
// The first actual missing-hyphen query populates the face-owned cache, shared
// by every size. The parent still supplies advances, metrics and other glyphs.
static hb_font_t *vox_hb_with_coretext_hyphens(hb_font_t *parent) {
    hb_codepoint_t glyphs[2] = { 0, 0 };
    int missing[2];
    for (int i = 0; i < 2; ++i)
        missing[i] = !hb_font_get_nominal_glyph(parent, 0x2010 + i, &glyphs[i]) || !glyphs[i];
    if (!missing[0] && !missing[1])
        return NULL;
    hb_font_t *font = hb_font_create_sub_font(parent);
    hb_font_funcs_t *funcs = hb_font_funcs_create();
    if (font == hb_font_get_empty() || funcs == hb_font_funcs_get_empty()) {
        hb_font_destroy(font);
        hb_font_funcs_destroy(funcs);
        return NULL;
    }
    hb_font_funcs_set_nominal_glyph_func(funcs, vox_hb_coretext_nominal_glyph, NULL, NULL);
    hb_font_funcs_make_immutable(funcs);
    hb_font_set_funcs(font, funcs, NULL, NULL);
    hb_font_funcs_destroy(funcs);
    return font;
}

#endif
