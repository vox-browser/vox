#pragma once
// CoreText family matching and character fallback for browser (non-layout-test)
// documents. Each result names the concrete face file, its collection index and
// the CoreText variation coordinates, so HarfBuzz shaping and native replay use
// exactly the face that CoreText selected.
typedef struct {
	char path[1024];
	char postscript[256];
	char family[256];
	double ascent;
	double descent;
	double leading;
	double x_height;
	double cap_height;
	double bbox_x_min, bbox_y_min, bbox_x_max, bbox_y_max;
	int face_index;
	int weight;
	int italic;
	int axis_count;
	unsigned int axis_tags[16];
	float axis_values[16];
} vox_ct_face;

#if !defined(V3CACHE_NATIVE_INTERFACE) || defined(V3CACHE_NATIVE_OWNER)
#include <CoreFoundation/CoreFoundation.h>
#include <CoreText/CoreText.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>



// CSS weights for the CoreText weight-trait values AppKit uses for the named
// weights. Faces between two named values select the nearer one.
static int vox_ct_css_weight(double trait) {
	static const double traits[] = { -0.8, -0.6, -0.4, 0.0, 0.23, 0.3, 0.4, 0.56, 0.62 };
	int best = 3;
	double best_distance = 10.0;
	for (int index = 0; index < 9; index++) {
		double distance = fabs(trait - traits[index]);
		if (distance < best_distance) {
			best_distance = distance;
			best = index;
		}
	}
	return (best + 1) * 100;
}

static double vox_ct_number(CFDictionaryRef dictionary, CFStringRef key) {
	double value = 0.0;
	CFNumberRef number = dictionary ? (CFNumberRef)CFDictionaryGetValue(dictionary, key) : NULL;
	if (number && CFGetTypeID(number) == CFNumberGetTypeID())
		CFNumberGetValue(number, kCFNumberDoubleType, &value);
	return value;
}

static unsigned int vox_ct_symbolic_traits(CFDictionaryRef traits) {
	unsigned int value = 0;
	CFNumberRef number = traits ? (CFNumberRef)CFDictionaryGetValue(traits, kCTFontSymbolicTrait) : NULL;
	if (number && CFGetTypeID(number) == CFNumberGetTypeID())
		CFNumberGetValue(number, kCFNumberSInt32Type, &value);
	return value;
}

typedef struct {
	CTFontDescriptorRef descriptor;
	int weight;
	int italic;
	int normal_width;
	int ornamental;
} vox_ct_candidate;

static void vox_ct_describe(CTFontDescriptorRef descriptor, vox_ct_candidate *candidate) {
	CFDictionaryRef traits = (CFDictionaryRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute);
	unsigned int symbolic = vox_ct_symbolic_traits(traits);
	candidate->descriptor = descriptor;
	candidate->weight = vox_ct_css_weight(vox_ct_number(traits, kCTFontWeightTrait));
	candidate->italic = (symbolic & kCTFontTraitItalic) != 0;
	candidate->normal_width = fabs(vox_ct_number(traits, kCTFontWidthTrait)) < 0.01
		&& (symbolic & (kCTFontTraitCondensed | kCTFontTraitExpanded)) == 0;
	unsigned int font_class = symbolic & kCTFontTraitClassMask;
	candidate->ornamental = font_class == kCTFontClassOrnamentals || font_class == kCTFontClassSymbolic;
	if (traits)
		CFRelease(traits);
}

// CSS Fonts 4 font-weight fallback order for a set already narrowed by width
// and style. Lower scores are better.
static int vox_ct_weight_score(int desired, int actual) {
	if (actual == desired)
		return 0;
	if (desired >= 400 && desired <= 500) {
		if (actual > desired && actual <= 500)
			return actual - desired;
		if (actual < desired)
			return 1000 + (desired - actual);
		return 2000 + (actual - desired);
	}
	if (desired < 400) {
		if (actual < desired)
			return desired - actual;
		return 1000 + (actual - desired);
	}
	if (actual > desired)
		return actual - desired;
	return 1000 + (desired - actual);
}

static CTFontDescriptorRef vox_ct_select(CFArrayRef members, int weight, int italic, int *selected_weight, int *selected_italic) {
	CFIndex count = CFArrayGetCount(members);
	if (count <= 0)
		return NULL;
	vox_ct_candidate *candidates = calloc((size_t)count, sizeof(vox_ct_candidate));
	if (!candidates)
		return NULL;
	int has_normal_width = 0, has_style = 0, has_plain = 0;
	for (CFIndex index = 0; index < count; index++) {
		vox_ct_describe((CTFontDescriptorRef)CFArrayGetValueAtIndex(members, index), &candidates[index]);
		has_normal_width |= candidates[index].normal_width;
		has_plain |= !candidates[index].ornamental;
	}
	for (CFIndex index = 0; index < count; index++) {
		vox_ct_candidate *candidate = &candidates[index];
		if ((has_normal_width && !candidate->normal_width) || (has_plain && candidate->ornamental))
			continue;
		has_style |= candidate->italic == (italic != 0);
	}
	int best = -1;
	int best_score = 1 << 30;
	for (CFIndex index = 0; index < count; index++) {
		vox_ct_candidate *candidate = &candidates[index];
		if ((has_normal_width && !candidate->normal_width) || (has_plain && candidate->ornamental))
			continue;
		if (has_style && candidate->italic != (italic != 0))
			continue;
		int score = vox_ct_weight_score(weight, candidate->weight);
		if (score < best_score) {
			best_score = score;
			best = (int)index;
		}
	}
	CTFontDescriptorRef result = NULL;
	if (best >= 0) {
		result = candidates[best].descriptor;
		*selected_weight = candidates[best].weight;
		*selected_italic = candidates[best].italic;
	}
	free(candidates);
	return result;
}

static unsigned int vox_ct_be32(const unsigned char *bytes) {
	return ((unsigned int)bytes[0] << 24) | ((unsigned int)bytes[1] << 16)
		| ((unsigned int)bytes[2] << 8) | (unsigned int)bytes[3];
}

// CoreText enumerates named instances as separate descriptors, so descriptor
// order is not the collection index for variable collections. Identify the
// collection member by comparing its 'name' table with the selected font's.
static int vox_ct_collection_index(const char *path, CTFontRef font) {
	FILE *file = fopen(path, "rb");
	if (!file)
		return 0;
	unsigned char header[12];
	int result = 0;
	if (fread(header, 1, 12, file) != 12 || memcmp(header, "ttcf", 4) != 0) {
		fclose(file);
		return 0;
	}
	unsigned int count = vox_ct_be32(header + 8);
	CFDataRef wanted = CTFontCopyTable(font, kCTFontTableName, kCTFontTableOptionNoOptions);
	if (!wanted || count == 0 || count > 4096) {
		if (wanted)
			CFRelease(wanted);
		fclose(file);
		return 0;
	}
	CFIndex wanted_length = CFDataGetLength(wanted);
	const unsigned char *wanted_bytes = CFDataGetBytePtr(wanted);
	unsigned char *offsets = malloc((size_t)count * 4);
	unsigned char *buffer = malloc((size_t)wanted_length);
	if (offsets && buffer && fread(offsets, 4, count, file) == count) {
		for (unsigned int index = 0; index < count; index++) {
			unsigned char directory[12];
			if (fseek(file, (long)vox_ct_be32(offsets + index * 4), SEEK_SET) != 0
				|| fread(directory, 1, 12, file) != 12)
				break;
			unsigned int tables = ((unsigned int)directory[4] << 8) | directory[5];
			unsigned int name_offset = 0, name_length = 0;
			for (unsigned int table = 0; table < tables; table++) {
				unsigned char record[16];
				if (fread(record, 1, 16, file) != 16)
					break;
				if (memcmp(record, "name", 4) == 0) {
					name_offset = vox_ct_be32(record + 8);
					name_length = vox_ct_be32(record + 12);
					break;
				}
			}
			if (name_length != (unsigned int)wanted_length || fseek(file, (long)name_offset, SEEK_SET) != 0
				|| fread(buffer, 1, (size_t)wanted_length, file) != (size_t)wanted_length)
				continue;
			if (memcmp(buffer, wanted_bytes, (size_t)wanted_length) == 0) {
				result = (int)index;
				break;
			}
		}
	}
	free(offsets);
	free(buffer);
	CFRelease(wanted);
	fclose(file);
	return result;
}

static int vox_ct_fill(CTFontRef font, vox_ct_face *face) {
	CFURLRef url = (CFURLRef)CTFontCopyAttribute(font, kCTFontURLAttribute);
	if (!url)
		return 0;
	int ok = CFURLGetFileSystemRepresentation(url, true, (UInt8 *)face->path, sizeof(face->path));
	face->face_index = ok ? vox_ct_collection_index(face->path, font) : 0;
	face->family[0] = 0;
	CFStringRef family = CTFontCopyFamilyName(font);
	if (family) {
		CFStringGetCString(family, face->family, sizeof(face->family), kCFStringEncodingUTF8);
		CFRelease(family);
	}
	// The metrics Skia's CoreText scaler reports, at the matched size.
	face->ascent = CTFontGetAscent(font);
	face->descent = CTFontGetDescent(font);
	face->leading = CTFontGetLeading(font);
	face->x_height = CTFontGetXHeight(font);
	// Blink measures the x-height from the top of the 'x' glyph's bounds,
	// rather than CoreText's value, so `ex` excludes descending parts.
	UniChar x_character = 'x';
	CGGlyph x_glyph = 0;
	if (CTFontGetGlyphsForCharacters(font, &x_character, &x_glyph, 1) && x_glyph) {
		CGRect bounds = CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationHorizontal, &x_glyph, NULL, 1);
		face->x_height = bounds.origin.y + bounds.size.height;
	}
	face->cap_height = CTFontGetCapHeight(font);
	// The face-wide glyph bounds (the 'head' box) at the matched size.
	CGRect bounds_box = CTFontGetBoundingBox(font);
	face->bbox_x_min = bounds_box.origin.x;
	face->bbox_y_min = bounds_box.origin.y;
	face->bbox_x_max = bounds_box.origin.x + bounds_box.size.width;
	face->bbox_y_max = bounds_box.origin.y + bounds_box.size.height;
	face->postscript[0] = 0;
	CFStringRef postscript = CTFontCopyPostScriptName(font);
	if (postscript) {
		CFStringGetCString(postscript, face->postscript, sizeof(face->postscript), kCFStringEncodingUTF8);
		CFRelease(postscript);
	}
	CFRelease(url);
	face->axis_count = 0;
	CFDictionaryRef variation = CTFontCopyVariation(font);
	if (variation) {
		CFIndex count = CFDictionaryGetCount(variation);
		if (count > 16)
			count = 16;
		const void *keys[16];
		const void *values[16];
		CFDictionaryGetKeysAndValues(variation, keys, values);
		for (CFIndex index = 0; index < count; index++) {
			unsigned int tag = 0;
			double value = 0.0;
			if (CFGetTypeID(keys[index]) != CFNumberGetTypeID() || CFGetTypeID(values[index]) != CFNumberGetTypeID())
				continue;
			CFNumberGetValue((CFNumberRef)keys[index], kCFNumberSInt32Type, &tag);
			CFNumberGetValue((CFNumberRef)values[index], kCFNumberDoubleType, &value);
			face->axis_tags[face->axis_count] = tag;
			face->axis_values[face->axis_count] = (float)value;
			face->axis_count++;
		}
		CFRelease(variation);
	}
	CFDictionaryRef traits = CTFontCopyTraits(font);
	if (traits) {
		face->weight = vox_ct_css_weight(vox_ct_number(traits, kCTFontWeightTrait));
		face->italic = (vox_ct_symbolic_traits(traits) & kCTFontTraitItalic) != 0;
		CFRelease(traits);
	}
	return ok;
}

static CTFontRef vox_ct_system_font(int weight, int italic, double size) {
	CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, size, NULL);
	if (!font)
		return NULL;
	CTFontSymbolicTraits desired = 0;
	if (italic)
		desired |= kCTFontTraitItalic;
	if (weight >= 600)
		desired |= kCTFontTraitBold;
	if (desired) {
		CTFontRef styled = CTFontCreateCopyWithSymbolicTraits(font, size, NULL, desired, desired);
		if (styled) {
			CFRelease(font);
			font = styled;
		}
	}
	// Blink retains the requested weight on the system UI variable face after
	// selecting its symbolic traits. Semibold must not become the bold master.
	if (weight != 400) {
		double value = weight;
		const int tag = 0x77676874; // wght
		CFArrayRef axes = CTFontCopyVariationAxes(font);
		for (CFIndex index = 0; axes && index < CFArrayGetCount(axes); ++index) {
			CFDictionaryRef axis = (CFDictionaryRef)CFArrayGetValueAtIndex(axes, index);
			if ((int)vox_ct_number(axis, kCTFontVariationAxisIdentifierKey) == tag) {
				value = fmax(vox_ct_number(axis, kCTFontVariationAxisMinimumValueKey),
					fmin(vox_ct_number(axis, kCTFontVariationAxisMaximumValueKey), value));
				break;
			}
		}
		if (axes) CFRelease(axes);
		CFNumberRef axis_tag = CFNumberCreate(NULL, kCFNumberIntType, &tag);
		CFNumberRef coordinate = CFNumberCreate(NULL, kCFNumberDoubleType, &value);
		const void *keys[] = { axis_tag };
		const void *values[] = { coordinate };
		CFDictionaryRef variations = CFDictionaryCreate(NULL, keys, values, 1,
			&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		const void *attribute_keys[] = { kCTFontVariationAttribute };
		const void *attribute_values[] = { variations };
		CFDictionaryRef attributes = CFDictionaryCreate(NULL, attribute_keys, attribute_values, 1,
			&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes(attributes);
		CTFontRef varied = CTFontCreateCopyWithAttributes(font, size, NULL, descriptor);
		if (varied) {
			CFRelease(font);
			font = varied;
		}
		CFRelease(descriptor);
		CFRelease(attributes);
		CFRelease(variations);
		CFRelease(coordinate);
		CFRelease(axis_tag);
	}
	return font;
}

static int vox_ct_is_system_ui_name(const char *family) {
	return !strcasecmp(family, "system-ui") || !strcasecmp(family, "systemui")
		|| !strcasecmp(family, "blinkmacsystemfont");
}

static CFArrayRef vox_ct_family_members(const char *family) {
	if (!family || !*family || family[0] == '.')
		return NULL;
	CFStringRef name = CFStringCreateWithCString(NULL, family, kCFStringEncodingUTF8);
	if (!name)
		return NULL;
	const void *keys[] = { kCTFontFamilyNameAttribute };
	const void *values[] = { name };
	CFDictionaryRef attributes = CFDictionaryCreate(NULL, keys, values, 1,
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithAttributes(attributes);
	CFSetRef mandatory = CFSetCreate(NULL, keys, 1, &kCFTypeSetCallBacks);
	CFArrayRef members = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, mandatory);
	CFRelease(mandatory);
	CFRelease(descriptor);
	CFRelease(attributes);
	CFRelease(name);
	if (members && CFArrayGetCount(members) == 0) {
		CFRelease(members);
		return NULL;
	}
	return members;
}

static int vox_ct_family_available(const char *family) {
	if (vox_ct_is_system_ui_name(family))
		return 1;
	CFArrayRef members = vox_ct_family_members(family);
	if (!members)
		return 0;
	CFRelease(members);
	return 1;
}

static int vox_ct_match_family(const char *family, int weight, int italic, double size, vox_ct_face *face) {
	memset(face, 0, sizeof(*face));
	CTFontRef font = NULL;
	if (vox_ct_is_system_ui_name(family)) {
		font = vox_ct_system_font(weight, italic, size);
	} else {
		CFArrayRef members = vox_ct_family_members(family);
		if (!members)
			return 0;
		int selected_weight = 400, selected_italic = 0;
		CTFontDescriptorRef selected = vox_ct_select(members, weight, italic, &selected_weight, &selected_italic);
		if (selected)
			font = CTFontCreateWithFontDescriptor(selected, size, NULL);
		CFRelease(members);
	}
	if (!font)
		return 0;
	int ok = vox_ct_fill(font, face);
	CFRelease(font);
	return ok;
}

// Character fallback through CoreText's language-aware cascade. The base font
// determines the cascade list; a result naming the base face means CoreText
// found no better face for the text.
static int vox_ct_fallback(const unsigned short *text, int length, const char *language,
	const char *base_family, int weight, int italic, double size, vox_ct_face *face) {
	memset(face, 0, sizeof(*face));
	if (!text || length <= 0)
		return 0;
	CTFontRef base = NULL;
	if (base_family && *base_family && !vox_ct_is_system_ui_name(base_family)) {
		CFStringRef name = CFStringCreateWithCString(NULL, base_family, kCFStringEncodingUTF8);
		if (name) {
			base = CTFontCreateWithName(name, size, NULL);
			CFRelease(name);
		}
	}
	if (!base)
		base = vox_ct_system_font(400, 0, size);
	if (!base)
		return 0;
	CFStringRef string = CFStringCreateWithCharacters(NULL, (const UniChar *)text, length);
	CFStringRef language_name = language && *language
		? CFStringCreateWithCString(NULL, language, kCFStringEncodingUTF8) : NULL;
	CTFontRef font = NULL;
	if (string) {
		if (__builtin_available(macOS 13.0, *))
			font = CTFontCreateForStringWithLanguage(base, string, CFRangeMake(0, length), language_name);
		else
			font = CTFontCreateForString(base, string, CFRangeMake(0, length));
	}
	if (language_name)
		CFRelease(language_name);
	int ok = 0;
	if (font) {
		CFStringRef base_name = CTFontCopyPostScriptName(base);
		CFStringRef name = CTFontCopyPostScriptName(font);
		int same = base_name && name && CFEqual(base_name, name);
		if (base_name)
			CFRelease(base_name);
		if (name)
			CFRelease(name);
		CTFontSymbolicTraits desired = 0;
		if (italic)
			desired |= kCTFontTraitItalic;
		if (weight >= 600)
			desired |= kCTFontTraitBold;
		// The result must cover the whole string; CoreText returns the base face
		// when its cascade has no glyph for it. A styled copy can move to another
		// family, so keep it only when it still covers the text.
		// Virtual cascade faces have no file URL; those keep the unstyled face.
		CGGlyph *glyphs = calloc((size_t)length, sizeof(CGGlyph));
		if (!same && desired && glyphs) {
			CTFontRef styled = CTFontCreateCopyWithSymbolicTraits(font, size, NULL, desired, desired);
			if (styled && CTFontGetGlyphsForCharacters(styled, (const UniChar *)text, glyphs, length))
				ok = vox_ct_fill(styled, face);
			if (styled)
				CFRelease(styled);
		}
		if (!ok && !same && glyphs && CTFontGetGlyphsForCharacters(font, (const UniChar *)text, glyphs, length))
			ok = vox_ct_fill(font, face);
		free(glyphs);
		CFRelease(font);
	}
	if (string)
		CFRelease(string);
	CFRelease(base);
	return ok;
}

#endif
