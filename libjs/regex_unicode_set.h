/* BSD-2-Clause. LibUnicode/CharacterTypes.cpp's ICU UnicodeSet C ABI.
 * Apple's SDK omits uset.h. This header contains declarations only. */
#ifndef VOX2_LIBJS_REGEX_UNICODE_SET_H
#define VOX2_LIBJS_REGEX_UNICODE_SET_H
#include <unicode/uchar.h>
#ifdef __APPLE__
typedef struct USet USet;
USet* uset_open(UChar32, UChar32);
void uset_close(USet*);
void uset_closeOver(USet*, int32_t);
void uset_retain(USet*, UChar32, UChar32);
UBool uset_isEmpty(USet const*);
int32_t uset_getRangeCount(USet const*);
int32_t uset_getItem(USet const*, int32_t, UChar32*, UChar32*, UChar*, int32_t, UErrorCode*);
#define USET_CASE_INSENSITIVE 2
#else
#include <unicode/uset.h>
#endif
#endif
