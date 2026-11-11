#pragma once

#include <stdint.h>
#include <unicode/utypes.h>
#include "../platform/native_state.h"

// LibUnicode/Segmenter.cpp creates ICU line break iterators. The production
// build includes the pinned ICU headers; Apple's SDK ships libicucore without
// ubrk.h, so declare the stable C API there. Both paths go through the same
// urename.h as the rest of the program's ICU callers.
#if __has_include(<unicode/ubrk.h>)
#include <unicode/ubrk.h>
#else
typedef struct UBreakIterator UBreakIterator;
typedef enum UBreakIteratorType {
    UBRK_CHARACTER = 0,
    UBRK_WORD = 1,
    UBRK_LINE = 2,
    UBRK_SENTENCE = 3,
} UBreakIteratorType;
#define UBRK_DONE ((int32_t)-1)
UBreakIterator* ubrk_open(UBreakIteratorType, char const*, UChar const*, int32_t, UErrorCode*);
void ubrk_setText(UBreakIterator*, UChar const*, int32_t, UErrorCode*);
int32_t ubrk_first(UBreakIterator*);
int32_t ubrk_next(UBreakIterator*);
#endif

// Segmenter.cpp::unicode_layout_segmenter_prototype keeps one line iterator
// per UnicodeLayoutLineBreakMode, in this order: Strict, Normal, Loose,
// LooseJapanese, LooseChinese.
#define LIBWEB_V_LINE_BREAK_MODE_COUNT 5
VOX_NATIVE_STATE _Thread_local UBreakIterator* libweb_v_line_break_iterators[LIBWEB_V_LINE_BREAK_MODE_COUNT];

static UBreakIterator* libweb_v_line_break_iterator(int32_t mode)
{
    if (mode < 0 || mode >= LIBWEB_V_LINE_BREAK_MODE_COUNT)
        mode = 0;
    if (libweb_v_line_break_iterators[mode])
        return libweb_v_line_break_iterators[mode];
    // https://drafts.csswg.org/css-text-3/#line-break-property
    // ICU's default rules forbid breaks before conditional Japanese starters
    // (strict). Its normal tailoring resolves CJ to ID, its loose tailoring also
    // allows breaks before iteration marks, and its Japanese and Chinese loose
    // tailorings implement the language-specific breaks before centered
    // punctuation, hyphens, and prefix/postfix characters.
    static char const* const locales[LIBWEB_V_LINE_BREAK_MODE_COUNT] = {
        "en",
        "en@lb=normal",
        "en@lb=loose",
        "ja@lb=loose",
        "zh@lb=loose",
    };
    UErrorCode status = U_ZERO_ERROR;
    UBreakIterator* iterator = ubrk_open(UBRK_LINE, locales[mode], NULL, 0, &status);
    if (U_FAILURE(status))
        return NULL;
    libweb_v_line_break_iterators[mode] = iterator;
    return iterator;
}

// Writes the soft wrap boundaries of the UTF-16 text, including 0 and length,
// into boundaries (capacity length + 1). Returns their count, or -1 when ICU
// cannot segment the text.
static int32_t libweb_v_line_break_boundaries(uint16_t const* text, int32_t length, int32_t mode, int32_t* boundaries)
{
    UBreakIterator* iterator = libweb_v_line_break_iterator(mode);
    if (!iterator)
        return -1;
    UErrorCode status = U_ZERO_ERROR;
    ubrk_setText(iterator, (UChar const*)text, length, &status);
    if (U_FAILURE(status))
        return -1;
    int32_t count = 0;
    for (int32_t boundary = ubrk_first(iterator); boundary != UBRK_DONE && count <= length; boundary = ubrk_next(iterator))
        boundaries[count++] = boundary;
    return count;
}
