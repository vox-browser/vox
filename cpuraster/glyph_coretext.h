#pragma once
// CoreText services for cpuraster's glyph masks, matching what LibWeb
// Skia's SkTypeface_Mac and SkScalerContext_Mac ask of CoreText for an
// unhinted anti-aliased (A8) strike. Everything else about the strike (the
// matrices, subpixel positions, bounds rounding, mask gamma and blitting) is
// computed in V.
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "glyph_smoothing_probe.h"
#include <pthread.h>
#include "../platform/native_state.h"

// SkFontMgr_Mac::onMakeFromFile() -> SkTypeface_Mac::MakeFromStream():
// the file's bytes, CTFontManagerCreateFontDescriptorFromData() and
// CTFontCreateWithFontDescriptor(desc, 0, nullptr). flags receives bit 0 for
// kCTFontColorGlyphsTrait and bit 1 when the font has variation axes.
// Returns a retained CTFontRef or NULL.
static void* cpuraster_ct_font_from_file(const char* path, int* flags) {
    *flags = 0;
    FILE* file = fopen(path, "rb");
    if (!file)
        return NULL;
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }
    long size = ftell(file);
    if (size < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return NULL;
    }
    UInt8* bytes = (UInt8*)malloc(size > 0 ? (size_t)size : 1);
    if (!bytes || fread(bytes, 1, (size_t)size, file) != (size_t)size) {
        free(bytes);
        fclose(file);
        return NULL;
    }
    fclose(file);
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, bytes, size);
    free(bytes);
    if (!data)
        return NULL;
    CTFontDescriptorRef desc = CTFontManagerCreateFontDescriptorFromData(data);
    CFRelease(data);
    if (!desc)
        return NULL;
    CTFontRef font = CTFontCreateWithFontDescriptor(desc, 0, NULL);
    CFRelease(desc);
    if (!font)
        return NULL;
    if (CTFontGetSymbolicTraits(font) & kCTFontColorGlyphsTrait)
        *flags |= 1;
    CFArrayRef axes = CTFontCopyVariationAxes(font);
    if (axes) {
        if (CFArrayGetCount(axes) > 0)
            *flags |= 2;
        CFRelease(axes);
    }
    return (void*)font;
}

// Retained document text names faces two ways (platform/system_font_matching.v):
// a font file with its collection index, or a key that the browser registered
// for an installed face plus variation coordinates. The registry keeps those
// keys' descriptors, as the removed Skia bridge's system typefaces did.
typedef struct {
    char* key;
    CTFontDescriptorRef descriptor;
} cpuraster_ct_registered_face;

VOX_NATIVE_STATE pthread_mutex_t cpuraster_ct_registry_lock VOX_NATIVE_STATE_INIT(PTHREAD_MUTEX_INITIALIZER);
VOX_NATIVE_STATE cpuraster_ct_registered_face* cpuraster_ct_registry;
VOX_NATIVE_STATE int cpuraster_ct_registry_count;
VOX_NATIVE_STATE int cpuraster_ct_registry_capacity;

// A retained descriptor registered under key, or NULL.
static CTFontDescriptorRef cpuraster_ct_registered_descriptor(const char* key) {
    CTFontDescriptorRef found = NULL;
    pthread_mutex_lock(&cpuraster_ct_registry_lock);
    for (int i = 0; i < cpuraster_ct_registry_count && !found; ++i)
        if (strcmp(cpuraster_ct_registry[i].key, key) == 0)
            found = (CTFontDescriptorRef)CFRetain(cpuraster_ct_registry[i].descriptor);
    pthread_mutex_unlock(&cpuraster_ct_registry_lock);
    return found;
}

static int cpuraster_ct_postscript_matches(CTFontDescriptorRef descriptor, CFStringRef wanted) {
    CFStringRef name = (CFStringRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
    int same = name && CFEqual(name, wanted);
    if (name)
        CFRelease(name);
    return same;
}

// Registers the installed face at path named postscript_name, with the given
// variation coordinates, under key. Prefers the face CoreText registered under
// that name: a face re-created from its file loses system behavior Blink's
// CTFont keeps (Apple Color Emoji's strike advances, for one). Returns 1 when
// the key resolves to a face.
static int cpuraster_ct_register_face(const char* key, const char* path, const char* postscript_name,
    const uint32_t* tags, const float* values, int count) {
    if (!key || !*key || !path || !postscript_name)
        return 0;
    CTFontDescriptorRef existing = cpuraster_ct_registered_descriptor(key);
    if (existing) {
        CFRelease(existing);
        return 1;
    }
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8*)path,
        (CFIndex)strlen(path), false);
    if (!url)
        return 0;
    CFStringRef wanted = *postscript_name
        ? CFStringCreateWithCString(NULL, postscript_name, kCFStringEncodingUTF8) : NULL;
    CTFontDescriptorRef selected = NULL;
    if (wanted) {
        CTFontDescriptorRef named = CTFontDescriptorCreateWithNameAndSize(wanted, 12.0);
        CFURLRef named_url = named ? (CFURLRef)CTFontDescriptorCopyAttribute(named, kCTFontURLAttribute) : NULL;
        char named_path[4096];
        if (named_url && CFURLGetFileSystemRepresentation(named_url, true, (UInt8*)named_path, sizeof(named_path))
            && strcmp(named_path, path) == 0)
            selected = named;
        else if (named)
            CFRelease(named);
        if (named_url)
            CFRelease(named_url);
    }
    CFArrayRef descriptors = selected ? NULL : CTFontManagerCreateFontDescriptorsFromURL(url);
    CFRelease(url);
    if (!selected && descriptors) {
        CFIndex n = CFArrayGetCount(descriptors);
        // Downloaded standalone faces have no installed PostScript identity.
        if (!wanted && n > 0)
            selected = (CTFontDescriptorRef)CFRetain(CFArrayGetValueAtIndex(descriptors, 0));
        for (CFIndex i = 0; !selected && wanted && i < n; ++i) {
            CTFontDescriptorRef candidate = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, i);
            if (cpuraster_ct_postscript_matches(candidate, wanted))
                selected = (CTFontDescriptorRef)CFRetain(candidate);
        }
        // A named instance of a variable face: the coordinates select it.
        if (!selected && n > 0 && count > 0)
            selected = (CTFontDescriptorRef)CFRetain(CFArrayGetValueAtIndex(descriptors, 0));
    }
    if (wanted)
        CFRelease(wanted);
    if (descriptors)
        CFRelease(descriptors);
    if (!selected)
        return 0;
    for (int i = 0; i < count && tags && values; ++i) {
        int32_t tag = (int32_t)tags[i];
        CFNumberRef number = CFNumberCreate(NULL, kCFNumberSInt32Type, &tag);
        CTFontDescriptorRef copy = CTFontDescriptorCreateCopyWithVariation(selected, number, values[i]);
        CFRelease(number);
        if (copy) {
            CFRelease(selected);
            selected = copy;
        }
    }
    pthread_mutex_lock(&cpuraster_ct_registry_lock);
    if (cpuraster_ct_registry_count == cpuraster_ct_registry_capacity) {
        int capacity = cpuraster_ct_registry_capacity ? cpuraster_ct_registry_capacity * 2 : 32;
        cpuraster_ct_registered_face* grown = (cpuraster_ct_registered_face*)realloc(cpuraster_ct_registry,
            (size_t)capacity * sizeof(cpuraster_ct_registered_face));
        if (!grown) {
            pthread_mutex_unlock(&cpuraster_ct_registry_lock);
            CFRelease(selected);
            return 0;
        }
        cpuraster_ct_registry = grown;
        cpuraster_ct_registry_capacity = capacity;
    }
    cpuraster_ct_registry[cpuraster_ct_registry_count].key = strdup(key);
    cpuraster_ct_registry[cpuraster_ct_registry_count].descriptor = selected;
    ++cpuraster_ct_registry_count;
    pthread_mutex_unlock(&cpuraster_ct_registry_lock);
    return 1;
}

static void cpuraster_ct_face_flags(CTFontRef font, int* flags) {
    if (CTFontGetSymbolicTraits(font) & kCTFontColorGlyphsTrait)
        *flags |= 1;
    CFArrayRef axes = CTFontCopyVariationAxes(font);
    if (axes) {
        if (CFArrayGetCount(axes) > 0)
            *flags |= 2;
        CFRelease(axes);
    }
}

// The typeface for a retained run's face: a registered key (as
// SkMakeTypefaceFromCTFont() of a 12-point CTFont), the first face of a font
// file (cpuraster_ct_font_from_file()), or the face at a collection index,
// as SkFontMgr_Mac's makeFromStream() with SkFontArguments::setCollectionIndex()
// selects it from the file's descriptors. Returns a retained CTFontRef or NULL.
static void* cpuraster_ct_font_for_face(const char* path, int index, int* flags) {
    *flags = 0;
    if (!path || !*path)
        return NULL;
    CTFontDescriptorRef registered = cpuraster_ct_registered_descriptor(path);
    if (registered) {
        CTFontRef font = CTFontCreateWithFontDescriptor(registered, 12.0, NULL);
        CFRelease(registered);
        if (font)
            cpuraster_ct_face_flags(font, flags);
        return (void*)font;
    }
    if (index == 0)
        return cpuraster_ct_font_from_file(path, flags);
    if (index < 0)
        return NULL;
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8*)path,
        (CFIndex)strlen(path), false);
    if (!url)
        return NULL;
    CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL(url);
    CFRelease(url);
    if (!descriptors)
        return NULL;
    CTFontRef font = NULL;
    if (index < CFArrayGetCount(descriptors))
        font = CTFontCreateWithFontDescriptor(
            (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, index), 0, NULL);
    CFRelease(descriptors);
    if (font)
        cpuraster_ct_face_flags(font, flags);
    return (void*)font;
}

// Whether a face is itself bold (CoreText weight trait at or above
// SemiBold's) and italic, as SkTypeface_Mac's font style reports them.
// Returns 0 when the face cannot be opened.
static int cpuraster_ct_face_style(const char* path, int index, int* bold, int* italic) {
    *bold = 0;
    *italic = 0;
    int flags = 0;
    CTFontRef font = (CTFontRef)cpuraster_ct_font_for_face(path, index, &flags);
    if (!font)
        return 0;
    CTFontSymbolicTraits symbolic = CTFontGetSymbolicTraits(font);
    *italic = (symbolic & kCTFontItalicTrait) != 0;
    CFDictionaryRef traits = CTFontCopyTraits(font);
    double weight = 0;
    if (traits) {
        CFNumberRef number = (CFNumberRef)CFDictionaryGetValue(traits, kCTFontWeightTrait);
        if (number)
            CFNumberGetValue(number, kCFNumberDoubleType, &weight);
        CFRelease(traits);
    }
    *bold = weight >= 0.27 || (symbolic & kCTFontBoldTrait) != 0;
    CFRelease(font);
    return 1;
}

static void cpuraster_ct_release(void* ref) {
    if (ref)
        CFRelease((CFTypeRef)ref);
}

// SkCTFontCreateExactCopy() without an opsz variation: the base font's
// optical size attribute (or its size), no tracking, at text_size.
static void* cpuraster_ct_exact_copy(void* base_ref, double text_size) {
    CTFontRef base = (CTFontRef)base_ref;
    CFMutableDictionaryRef attr = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFStringRef opsz_key = CFSTR("NSCTFontOpticalSizeAttribute");
    CFTypeRef opsz = CTFontCopyAttribute(base, opsz_key);
    double opsz_val;
    if (!opsz || CFGetTypeID(opsz) != CFNumberGetTypeID()
        || !CFNumberGetValue((CFNumberRef)opsz, kCFNumberDoubleType, &opsz_val) || opsz_val <= 0)
        opsz_val = CTFontGetSize(base);
    if (opsz)
        CFRelease(opsz);
    CFNumberRef opsz_number = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &opsz_val);
    CFDictionarySetValue(attr, opsz_key, opsz_number);
    CFRelease(opsz_number);
    int zero = 0;
    CFNumberRef tracking = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &zero);
    CFDictionarySetValue(attr, CFSTR("NSCTFontUnscaledTrackingAttribute"), tracking);
    CFRelease(tracking);
    CTFontDescriptorRef desc = CTFontDescriptorCreateWithAttributes(attr);
    CFRelease(attr);
    CTFontRef font = CTFontCreateCopyWithAttributes(base, text_size, NULL, desc);
    CFRelease(desc);
    return (void*)font;
}

// Native strike advances before HarfBuzz's 16.16 positioning conversion.
// The exact copy disables AAT tracking, which HarfBuzz applies separately.
static int cpuraster_ct_advances(const char* path, int index, float size,
    const uint16_t* glyphs, int count, float* widths) {
    if (!glyphs || !widths || count <= 0 || !(size > 0)) return 0;
    int flags = 0;
    CTFontRef base = (CTFontRef)cpuraster_ct_font_for_face(path, index, &flags);
    if (!base) return 0;
    CTFontRef font = (CTFontRef)cpuraster_ct_exact_copy(base, size);
    CFRelease(base);
    if (!font) return 0;
    for (int i = 0; i < count; ++i) {
        CGSize advance;
        CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, glyphs + i, &advance, 1);
        widths[i] = (float)advance.width;
    }
    CFRelease(font);
    return 1;
}

// CTFontGetBoundingBox(): x, y, width, height.
static void cpuraster_ct_bounding_box(void* font, double* out) {
    CGRect r = CTFontGetBoundingBox((CTFontRef)font);
    out[0] = r.origin.x;
    out[1] = r.origin.y;
    out[2] = r.size.width;
    out[3] = r.size.height;
}

static CGAffineTransform cpuraster_ct_transform(double const* t) {
    return CGAffineTransformMake(t[0], t[1], t[2], t[3], t[4], t[5]);
}

// CGPointApplyAffineTransform() and CGSizeApplyAffineTransform() are inline
// in the CoreGraphics headers; LibWeb Skia compiles them without contracting
// their products and sums into fused multiply-adds, so these keep the same
// arithmetic.
static CGPoint cpuraster_ct_apply_point(CGPoint point, CGAffineTransform t) {
#pragma clang fp contract(off)
    CGPoint p;
    p.x = (CGFloat)((double)t.a * point.x + (double)t.c * point.y + t.tx);
    p.y = (CGFloat)((double)t.b * point.x + (double)t.d * point.y + t.ty);
    return p;
}

static CGSize cpuraster_ct_apply_size(CGSize size, CGAffineTransform t) {
#pragma clang fp contract(off)
    CGSize s;
    s.width = (CGFloat)((double)t.a * size.width + (double)t.c * size.height);
    s.height = (CGFloat)((double)t.b * size.width + (double)t.d * size.height);
    return s;
}

// SkScalerContext_Mac::generateMetrics()'s CoreText queries: the
// horizontal advance and bounding rect mapped through the transform
// (CGSizeApplyAffineTransform(), CGRectApplyAffineTransform()) into out:
// advance width, advance height, rect x, y, width, height. Returns 1 when a
// zero advance comes with an empty or missing path, which makes the glyph
// empty.
static int cpuraster_ct_glyph_metrics(void* font_ref, uint16_t glyph_id, double const* t, double* out) {
    CTFontRef font = (CTFontRef)font_ref;
    CGGlyph glyph = (CGGlyph)glyph_id;
    CGAffineTransform transform = cpuraster_ct_transform(t);
    CGSize advance;
    CTFontGetAdvancesForGlyphs(font, kCTFontOrientationHorizontal, &glyph, &advance, 1);
    advance = cpuraster_ct_apply_size(advance, transform);
    CGRect bounds;
    CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationHorizontal, &glyph, &bounds, 1);
    bounds = CGRectApplyAffineTransform(bounds, transform);
    out[0] = advance.width;
    out[1] = advance.height;
    out[2] = bounds.origin.x;
    out[3] = bounds.origin.y;
    out[4] = bounds.size.width;
    out[5] = bounds.size.height;
    if (0 == advance.width && 0 == advance.height) {
        CGPathRef path = CTFontCreatePathForGlyph(font, glyph, NULL);
        int empty = !path || CGPathIsEmpty(path);
        if (path)
            CGPathRelease(path);
        return empty;
    }
    return 0;
}

// SkScalerContext_Mac::Offscreen::getCG(): a device RGB context of
// context_width x context_height, BGRX (kCGImageAlphaNoneSkipFirst) for an
// A8 glyph or premultiplied BGRA (kCGImageAlphaPremultipliedFirst) for a
// color one, both kCGBitmapByteOrder32Host; the glyph's width x height rows
// at its bottom erased to white (transparent black for color), and the
// glyph drawn through the text matrix at (x, y) mapped by its inverse, in
// black, or for color glyphs in the opaque foreground color (an SkColor's
// RGB, as CGColorForSkColor() makes it). pixels receives the context's rows;
// the glyph occupies the last height rows' first width pixels.
static int cpuraster_ct_draw_glyph(void* font_ref, uint16_t glyph_id, double const* t, int invertible,
    double x, double y, uint32_t* pixels, int context_width, int context_height, int width, int height,
    int color, uint32_t foreground, int smoothing) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    size_t row_bytes = (size_t)context_width * 4;
    CGImageAlphaInfo alpha = color ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    CGBitmapInfo info = kCGBitmapByteOrder32Host | (CGBitmapInfo)alpha;
    CGContextRef cg = CGBitmapContextCreate(pixels, context_width, context_height, 8, row_bytes, space, info);
    if (!cg) {
        CGColorSpaceRelease(space);
        return 0;
    }
    CGContextSetAllowsFontSubpixelQuantization(cg, false);
    CGContextSetShouldSubpixelQuantizeFonts(cg, false);
    CGContextSetAllowsFontSubpixelPositioning(cg, true);
    CGContextSetShouldSubpixelPositionFonts(cg, true);
    CGContextSetTextDrawingMode(cg, kCGTextFill);
    if (!color) {
        CGContextSetGrayFillColor(cg, 0.0f, 1.0f);
    } else {
        CGFloat components[4];
        components[0] = (CGFloat)((foreground >> 16) & 0xFF) * (1 / 255.0f);
        components[1] = (CGFloat)((foreground >> 8) & 0xFF) * (1 / 255.0f);
        components[2] = (CGFloat)(foreground & 0xFF) * (1 / 255.0f);
        components[3] = 1.0f;
        CGColorRef fill = CGColorCreate(space, components);
        CGContextSetFillColorWithColor(cg, fill);
        CGColorRelease(fill);
    }
    CGColorSpaceRelease(space);
    CGAffineTransform transform = cpuraster_ct_transform(t);
    CGContextSetTextMatrix(cg, transform);
    int do_smooth = !color && smoothing != 1 && smoothing != 2
        && cpuraster_ct_smoothing_behavior() != 0;
    CGContextSetShouldAntialias(cg, color || smoothing != 1);
    CGContextSetShouldSmoothFonts(cg, do_smooth);
    uint32_t* image = pixels + (size_t)(context_height - height) * context_width;
    uint32_t background = color ? 0x00000000 : 0xFFFFFFFF;
    for (int row = 0; row < height; ++row)
        for (int column = 0; column < width; ++column)
            image[(size_t)row * context_width + column] = background;
    CGAffineTransform inverse = invertible ? CGAffineTransformInvert(transform) : transform;
    CGPoint point = cpuraster_ct_apply_point(CGPointMake(x, y), inverse);
    CGGlyph glyph = (CGGlyph)glyph_id;
    CTFontDrawGlyphs((CTFontRef)font_ref, &glyph, &point, 1, cg);
    CGContextRelease(cg);
    if (do_smooth) {
        for (int row = 0; row < height; ++row) {
            for (int column = 0; column < width; ++column) {
                uint32_t* p = image + (size_t)row * context_width + column;
                uint32_t r = *p >> 16 & 255, g = *p >> 8 & 255, b = *p & 255;
                *p = (((r*r + 128)/255) << 16) | (((g*g + 128)/255) << 8) | ((b*b + 128)/255);
            }
        }
    }
    return 1;
}

// SkScalerContext_Mac::generatePath()'s CoreText path: CTFontCreatePathForGlyph()
// through fTransform concatenated with a (sx, sy) scale, its elements
// collected by CGPathApply() as seven doubles each: the element type, then
// up to three points. Returns the element count, or -1 without a path; the
// caller frees *elements.
typedef struct {
    double* values;
    int count;
    int capacity;
} cpuraster_ct_path_sink;

static void cpuraster_ct_path_element(void* info, CGPathElement const* element) {
    cpuraster_ct_path_sink* sink = (cpuraster_ct_path_sink*)info;
    if (sink->count == sink->capacity) {
        int capacity = sink->capacity ? sink->capacity * 2 : 64;
        double* values = (double*)realloc(sink->values, (size_t)capacity * 7 * sizeof(double));
        if (!values)
            return;
        sink->values = values;
        sink->capacity = capacity;
    }
    double* v = sink->values + (size_t)sink->count * 7;
    int points = 0;
    switch (element->type) {
    case kCGPathElementMoveToPoint:
    case kCGPathElementAddLineToPoint:
        points = 1;
        break;
    case kCGPathElementAddQuadCurveToPoint:
        points = 2;
        break;
    case kCGPathElementAddCurveToPoint:
        points = 3;
        break;
    default:
        break;
    }
    v[0] = (double)element->type;
    for (int i = 0; i < 3; ++i) {
        v[1 + i * 2] = i < points ? element->points[i].x : 0;
        v[2 + i * 2] = i < points ? element->points[i].y : 0;
    }
    sink->count++;
}

static int cpuraster_ct_glyph_path(void* font_ref, uint16_t glyph_id, double const* t, double sx, double sy, double** elements) {
    *elements = NULL;
    CGAffineTransform scale = CGAffineTransformMakeScale(sx, sy);
    CGAffineTransform xform = CGAffineTransformConcat(cpuraster_ct_transform(t), scale);
    CGPathRef path = CTFontCreatePathForGlyph((CTFontRef)font_ref, (CGGlyph)glyph_id, &xform);
    if (!path)
        return -1;
    cpuraster_ct_path_sink sink = { NULL, 0, 0 };
    CGPathApply(path, &sink, cpuraster_ct_path_element);
    CGPathRelease(path);
    *elements = sink.values;
    return sink.count;
}
