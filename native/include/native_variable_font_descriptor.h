#pragma once

#include <CoreText/CoreText.h>
#include <stdint.h>

// CoreText appends variation coordinates to some system PostScript names.
// Those generated names are absent from the file's descriptor list. Retain
// the matching base face only when it supports every supplied axis.
static CTFontDescriptorRef native_copy_variable_font_descriptor(CFArrayRef descriptors,
    CFStringRef wanted, const uint32_t* tags, int count)
{
    if (!descriptors || !wanted || !tags || count <= 0)
        return NULL;
    for (CFIndex i = 0; i < CFArrayGetCount(descriptors); ++i) {
        CTFontDescriptorRef descriptor = (CTFontDescriptorRef)CFArrayGetValueAtIndex(descriptors, i);
        CFStringRef name = (CFStringRef)CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute);
        CFStringRef prefix = name ? CFStringCreateWithFormat(NULL, NULL, CFSTR("%@_"), name) : NULL;
        bool matches = prefix && CFStringHasPrefix(wanted, prefix);
        if (prefix) CFRelease(prefix);
        if (name) CFRelease(name);
        if (!matches) continue;
        CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, 12, NULL);
        CFArrayRef axes = font ? CTFontCopyVariationAxes(font) : NULL;
        bool supported = axes != NULL;
        for (int axis = 0; supported && axis < count; ++axis) {
            bool found = false;
            for (CFIndex j = 0; j < CFArrayGetCount(axes); ++j) {
                CFDictionaryRef record = (CFDictionaryRef)CFArrayGetValueAtIndex(axes, j);
                CFNumberRef identifier = (CFNumberRef)CFDictionaryGetValue(record, kCTFontVariationAxisIdentifierKey);
                int64_t value = 0;
                if (identifier && CFNumberGetValue(identifier, kCFNumberSInt64Type, &value)
                    && (uint32_t)value == tags[axis]) found = true;
            }
            supported = found;
        }
        if (axes) CFRelease(axes);
        if (font) CFRelease(font);
        if (supported) return (CTFontDescriptorRef)CFRetain(descriptor);
    }
    return NULL;
}
