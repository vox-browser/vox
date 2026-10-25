// Exercise the versioned LibJS property bridge alongside the platform ICU.
// Homebrew may have a newer major version than the pinned upstream libraries.
#include "../libjs/regex_unicode_property.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    // These unprefixed calls use the selected platform headers and library.
    assert(u_isalpha('A'));
    assert(u_tolower('A') == 'a');
    // These calls use the pinned property ABI, including Apple's private-use
    // category difference that originally required this separate bridge.
    assert(vox2_regex_u_charType(0xF8FF) == U_PRIVATE_USE_CHAR);
    assert(vox2_regex_u_isIDStart('A'));
    assert(vox2_regex_u_isIDPart('5'));
    assert(vox2_regex_u_isdefined('A'));
    assert(vox2_regex_u_hasBinaryProperty('A', UCHAR_ALPHABETIC));
    assert(!strcmp(vox2_regex_u_getPropertyName(UCHAR_GENERAL_CATEGORY,
        U_LONG_PROPERTY_NAME), "General_Category"));
    assert(!strcmp(vox2_regex_u_getPropertyValueName(UCHAR_GENERAL_CATEGORY,
        U_UPPERCASE_LETTER, U_LONG_PROPERTY_NAME), "Uppercase_Letter"));
    UErrorCode status = U_ZERO_ERROR;
    int32_t script = vox2_regex_uscript_getScript('A', &status);
    assert(U_SUCCESS(status));
    assert(!strcmp(vox2_regex_uscript_getName(script), "Latin"));
    assert(!strcmp(vox2_regex_uscript_getShortName(script), "Latn"));
    assert(vox2_regex_uscript_hasScript('A', script));
    const Vox2UnicodePropertySet* set = vox2_regex_u_getBinaryPropertySet(
        UCHAR_ALPHABETIC, &status);
    assert(U_SUCCESS(status) && set);
    assert(vox2_regex_uset_contains(set, 'A'));
    assert(!vox2_regex_uset_contains(set, '5'));
    assert(vox2_regex_uset_getRangeCount(set) > 0);
    assert(vox2_regex_uset_getItemCount(set) > 0);
    UChar32 first = 0, last = 0;
    assert(vox2_regex_uset_getItem(set, 0, &first, &last, NULL, 0, &status) == 0);
    assert(U_SUCCESS(status) && first <= 'A' && last >= 'A');
    puts("Platform and pinned ICU property APIs linked and passed");
    return 0;
}
