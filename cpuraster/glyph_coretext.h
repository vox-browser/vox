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

// SkScalerContext_Mac::Offscreen::getCG() for an A8 glyph: a BGRX
// (kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host) device RGB context
// of context_width x context_height, the glyph's width x height rows at its
// bottom erased to white, and the glyph drawn in black through the text
// matrix at (x, y) mapped by its inverse. pixels receives the context's
// rows; the glyph occupies the last height rows' first width pixels.
static int cpuraster_ct_draw_glyph(void* font_ref, uint16_t glyph_id, double const* t, int invertible,
    double x, double y, uint32_t* pixels, int context_width, int context_height, int width, int height) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    size_t row_bytes = (size_t)context_width * 4;
    CGBitmapInfo info = kCGBitmapByteOrder32Host | (CGBitmapInfo)kCGImageAlphaNoneSkipFirst;
    CGContextRef cg = CGBitmapContextCreate(pixels, context_width, context_height, 8, row_bytes, space, info);
    CGColorSpaceRelease(space);
    if (!cg)
        return 0;
    CGContextSetAllowsFontSubpixelQuantization(cg, false);
    CGContextSetShouldSubpixelQuantizeFonts(cg, false);
    CGContextSetAllowsFontSubpixelPositioning(cg, true);
    CGContextSetShouldSubpixelPositionFonts(cg, true);
    CGContextSetTextDrawingMode(cg, kCGTextFill);
    CGContextSetGrayFillColor(cg, 0.0f, 1.0f);
    CGAffineTransform transform = cpuraster_ct_transform(t);
    CGContextSetTextMatrix(cg, transform);
    CGContextSetShouldAntialias(cg, true);
    CGContextSetShouldSmoothFonts(cg, false);
    uint32_t* image = pixels + (size_t)(context_height - height) * context_width;
    for (int row = 0; row < height; ++row)
        for (int column = 0; column < width; ++column)
            image[(size_t)row * context_width + column] = 0xFFFFFFFF;
    CGAffineTransform inverse = invertible ? CGAffineTransformInvert(transform) : transform;
    CGPoint point = cpuraster_ct_apply_point(CGPointMake(x, y), inverse);
    CGGlyph glyph = (CGGlyph)glyph_id;
    CTFontDrawGlyphs((CTFontRef)font_ref, &glyph, &point, 1, cg);
    CGContextRelease(cg);
    return 1;
}
