/* BSD-2-Clause. Native ICU ABI used by LibUnicode/Utf16String.cpp and
 * Normalize.cpp. Apple's SDK omits unorm2.h and uloc.h although libicucore
 * exports their stable C APIs. This header contains declarations only. */
#ifndef VOX2_LIBJS_UNICODE_TRANSFORM_H
#define VOX2_LIBJS_UNICODE_TRANSFORM_H
#include <unicode/ustring.h>
#ifdef __APPLE__
char const* uloc_getDefault(void);
void uloc_setDefault(char const*, UErrorCode*);
typedef struct UNormalizer2 UNormalizer2;
UNormalizer2 const* unorm2_getNFDInstance(UErrorCode*);
UNormalizer2 const* unorm2_getNFCInstance(UErrorCode*);
UNormalizer2 const* unorm2_getNFKDInstance(UErrorCode*);
UNormalizer2 const* unorm2_getNFKCInstance(UErrorCode*);
int32_t unorm2_normalize(UNormalizer2 const*, UChar const*, int32_t, UChar*, int32_t, UErrorCode*);
#else
#include <unicode/uloc.h>
#include <unicode/unorm2.h>
#endif
#endif
