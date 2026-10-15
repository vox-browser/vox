#ifndef VOX_BROWSERJS_SOURCE_STRING_DARWIN_H
#define VOX_BROWSERJS_SOURCE_STRING_DARWIN_H

#include <CoreFoundation/CoreFoundation.h>
#include <JavaScriptCore/JSStringRefCF.h>
#include <limits.h>

static JSStringRef vox_browserjs_source_utf8_string(const unsigned char *bytes,
    size_t length)
{
    // The old zero-unit constructor creates JSC's distinct null-string form.
    // CF also strips an initial UTF-8 BOM, unlike the existing rune decoder.
    if (length == 0 || length > LONG_MAX
        || (length >= 3 && bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf))
        return NULL;
    // Explicit length preserves embedded NULs. CF rejects malformed UTF-8,
    // leaving its existing decoding behavior to the V fallback.
    CFStringRef text = CFStringCreateWithBytes(kCFAllocatorDefault, bytes,
        (CFIndex)length, kCFStringEncodingUTF8, false);
    if (!text)
        return NULL;
    JSStringRef result = JSStringCreateWithCFString(text);
    CFRelease(text);
    return result;
}

#endif
