/* BSD-2-Clause. ICU ABI used by LibUnicode/CharacterTypes.cpp and String.cpp.
 * Apple's SDK omits ucasemap.h; these are declarations, not implementations. */
#ifndef VOX2_LIBJS_REGEX_CASE_FOLDING_H
#define VOX2_LIBJS_REGEX_CASE_FOLDING_H
#include <unicode/uchar.h>
#ifdef __APPLE__
typedef struct UCaseMap UCaseMap;
UCaseMap* ucasemap_open(char const*, uint32_t, UErrorCode*);
void ucasemap_close(UCaseMap*);
int32_t ucasemap_utf8ToUpper(UCaseMap const*, char*, int32_t, char const*, int32_t, UErrorCode*);
#else
#include <unicode/ucasemap.h>
#endif
#endif
