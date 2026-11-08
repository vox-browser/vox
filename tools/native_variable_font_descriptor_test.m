#include "../native/include/native_variable_font_descriptor.h"
#include <assert.h>
#include <stdio.h>

int main(void)
{
    CFURLRef url = CFURLCreateWithFileSystemPath(NULL, CFSTR("/System/Library/Fonts/SFNS.ttf"), kCFURLPOSIXPathStyle, false);
    CFArrayRef descriptors = CTFontManagerCreateFontDescriptorsFromURL(url);
    CFRelease(url);
    assert(descriptors);
    uint32_t tags[] = { 0x6f70737a, 0x77676874 };
    float values[] = { 20, 500 };
    CFStringRef wanted = CFSTR(".SFNS-Regular_wdth_opsz140000_GRAD_wght1F40000");
    CTFontDescriptorRef selected = native_copy_variable_font_descriptor(descriptors, wanted, tags, 2);
    assert(selected);
    CFStringRef name = CTFontDescriptorCopyAttribute(selected, kCTFontNameAttribute);
    assert(CFEqual(name, CFSTR(".SFNS-Regular")));
    CFRelease(name);
    for (int i = 0; i < 2; ++i) {
        int32_t tag = (int32_t)tags[i];
        CFNumberRef number = CFNumberCreate(NULL, kCFNumberSInt32Type, &tag);
        CTFontDescriptorRef changed = CTFontDescriptorCreateCopyWithVariation(selected, number, values[i]);
        CFRelease(number);
        assert(changed);
        CFRelease(selected);
        selected = changed;
    }
    CTFontRef font = CTFontCreateWithFontDescriptor(selected, 20, NULL);
    assert(font);
    CFDictionaryRef variations = CTFontCopyVariation(font);
    assert(variations);
    for (int i = 0; i < 2; ++i) {
        int32_t tag = (int32_t)tags[i];
        CFNumberRef key = CFNumberCreate(NULL, kCFNumberSInt32Type, &tag);
        CFNumberRef coordinate = CFDictionaryGetValue(variations, key);
        float actual = 0;
        assert(coordinate && CFNumberGetValue(coordinate, kCFNumberFloat32Type, &actual));
        assert(actual == values[i]);
        CFRelease(key);
    }
    CFRelease(variations);
    CFRelease(font);
    CFRelease(selected);
    assert(!native_copy_variable_font_descriptor(descriptors, wanted, tags, 0));
    assert(!native_copy_variable_font_descriptor(descriptors, CFSTR("Missing-Regular_wght500"), tags, 2));
    uint32_t missing_axis = 0x62616421;
    assert(!native_copy_variable_font_descriptor(descriptors, wanted, &missing_axis, 1));
    assert(!native_copy_variable_font_descriptor(NULL, wanted, tags, 2));
    CFRelease(descriptors);
    puts("Variable system font descriptor and variation checks passed");
    return 0;
}
