#ifndef VOX_HYPHENATION_BRIDGE_H
#define VOX_HYPHENATION_BRIDGE_H

#include <stdint.h>
#include <string.h>
#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <strings.h>
#endif

// Offsets use UTF-16, as do DOM ranges and retained text fragments. Keep the
// platform dictionary behind this boundary; never guess another language.
static int32_t libweb_v_hyphen_locations(const uint16_t* text, int32_t length,
    const char* language, int32_t* locations, int32_t capacity)
{
#ifdef __APPLE__
    if (!text || length < 5 || !language || !*language || !locations || capacity <= 0)
        return 0;
    uint32_t first = text[0];
    if (first >= 0xd800 && first <= 0xdbff && length > 1
        && text[1] >= 0xdc00 && text[1] <= 0xdfff)
        first = 0x10000 + ((first - 0xd800) << 10) + text[1] - 0xdc00;
    // Blink avoids capitalized English words. Other dictionary languages,
    // including German nouns, retain their own capitalization conventions.
    if (!strncasecmp(language, "en", 2)
        && CFCharacterSetIsLongCharacterMember(
            CFCharacterSetGetPredefined(kCFCharacterSetUppercaseLetter), first))
        return 0;
    CFStringRef identifier = CFStringCreateWithCString(NULL, language, kCFStringEncodingUTF8);
    if (!identifier) return 0;
    CFLocaleRef locale = CFLocaleCreate(NULL, identifier);
    CFRelease(identifier);
    if (!locale) return 0;
    if (!CFStringIsHyphenationAvailableForLocale(locale)) {
        CFRelease(locale);
        return 0;
    }
    CFStringRef word = CFStringCreateWithCharactersNoCopy(NULL, text, length, kCFAllocatorNull);
    if (!word) { CFRelease(locale); return 0; }
    int32_t count = 0;
    CFIndex before = length - 1;
    while (count < capacity) {
        CFIndex location = CFStringGetHyphenationLocationBeforeIndex(
            word, before, CFRangeMake(0, length), 0, locale, NULL);
        if (location < 2 || location >= before) break;
        if (location <= length - 2) locations[count++] = (int32_t)location;
        before = location;
    }
    CFRelease(word);
    CFRelease(locale);
    return count;
#else
    (void)text; (void)length; (void)language; (void)locations; (void)capacity;
    return 0;
#endif
}
#endif
