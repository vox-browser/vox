/* BSD-2-Clause. ICU ABI declarations used by CharacterTypes.cpp.
 * Apple's SDK omits uscript.h and uset.h. No algorithms live here. */
#ifndef VOX2_LIBJS_REGEX_UNICODE_PROPERTY_H
#define VOX2_LIBJS_REGEX_UNICODE_PROPERTY_H
#include "regex_unicode_set.h"
typedef struct USet Vox2UnicodePropertySet;
#ifdef __APPLE__
/* Apple customizes private-use categories in libicucore. Bind the standard
 * ICU 78 property API explicitly, without renaming any platform ICU calls.
 * Opaque property sets stay entirely within this library's ABI. */
#define vox2_regex_u_getPropertyValueName u_getPropertyValueName_78
#define vox2_regex_u_getPropertyName u_getPropertyName_78
#define vox2_regex_u_charType u_charType_78
#define vox2_regex_u_hasBinaryProperty u_hasBinaryProperty_78
#define vox2_regex_u_isdefined u_isdefined_78
#define vox2_regex_u_isIDStart u_isIDStart_78
#define vox2_regex_u_isIDPart u_isIDPart_78
#define vox2_regex_uscript_getName uscript_getName_78
#define vox2_regex_uscript_getShortName uscript_getShortName_78
#define vox2_regex_uscript_getScript uscript_getScript_78
#define vox2_regex_uscript_hasScript uscript_hasScript_78
#define vox2_regex_uset_openEmpty uset_openEmpty_78
#define vox2_regex_uset_applyIntPropertyValue uset_applyIntPropertyValue_78
#define vox2_regex_uset_closeOver uset_closeOver_78
#define vox2_regex_uset_freeze uset_freeze_78
#define vox2_regex_uset_contains uset_contains_78
#define vox2_regex_u_getBinaryPropertySet u_getBinaryPropertySet_78
#define vox2_regex_uset_getRangeCount uset_getRangeCount_78
#define vox2_regex_uset_getItemCount uset_getItemCount_78
#define vox2_regex_uset_getItem uset_getItem_78
#define VOX2_USCRIPT_CODE_LIMIT 213
#else
#include <unicode/uscript.h>
#define vox2_regex_u_getPropertyValueName u_getPropertyValueName
#define vox2_regex_u_getPropertyName u_getPropertyName
#define vox2_regex_u_charType u_charType
#define vox2_regex_u_hasBinaryProperty u_hasBinaryProperty
#define vox2_regex_u_isdefined u_isdefined
#define vox2_regex_u_isIDStart u_isIDStart
#define vox2_regex_u_isIDPart u_isIDPart
#define vox2_regex_uscript_getName uscript_getName
#define vox2_regex_uscript_getShortName uscript_getShortName
#define vox2_regex_uscript_getScript uscript_getScript
#define vox2_regex_uscript_hasScript uscript_hasScript
#define vox2_regex_uset_openEmpty uset_openEmpty
#define vox2_regex_uset_applyIntPropertyValue uset_applyIntPropertyValue
#define vox2_regex_uset_closeOver uset_closeOver
#define vox2_regex_uset_freeze uset_freeze
#define vox2_regex_uset_contains uset_contains
#define vox2_regex_u_getBinaryPropertySet u_getBinaryPropertySet
#define vox2_regex_uset_getRangeCount uset_getRangeCount
#define vox2_regex_uset_getItemCount uset_getItemCount
#define vox2_regex_uset_getItem uset_getItem
#define VOX2_USCRIPT_CODE_LIMIT USCRIPT_CODE_LIMIT
#endif
#ifdef __APPLE__
const char* vox2_regex_u_getPropertyValueName(UProperty, int32_t, UPropertyNameChoice);
const char* vox2_regex_u_getPropertyName(UProperty, UPropertyNameChoice);
int8_t vox2_regex_u_charType(UChar32);
UBool vox2_regex_u_hasBinaryProperty(UChar32, UProperty);
UBool vox2_regex_u_isdefined(UChar32);
UBool vox2_regex_u_isIDStart(UChar32);
UBool vox2_regex_u_isIDPart(UChar32);
const char* vox2_regex_uscript_getName(int32_t);
const char* vox2_regex_uscript_getShortName(int32_t);
int32_t vox2_regex_uscript_getScript(UChar32, UErrorCode*);
UBool vox2_regex_uscript_hasScript(UChar32, int32_t);
Vox2UnicodePropertySet* vox2_regex_uset_openEmpty(void);
void vox2_regex_uset_applyIntPropertyValue(Vox2UnicodePropertySet*, UProperty, int32_t, UErrorCode*);
void vox2_regex_uset_closeOver(Vox2UnicodePropertySet*, int32_t);
void vox2_regex_uset_freeze(Vox2UnicodePropertySet*);
UBool vox2_regex_uset_contains(Vox2UnicodePropertySet const*, UChar32);
Vox2UnicodePropertySet const* vox2_regex_u_getBinaryPropertySet(UProperty, UErrorCode*);
int32_t vox2_regex_uset_getRangeCount(Vox2UnicodePropertySet const*);
int32_t vox2_regex_uset_getItemCount(Vox2UnicodePropertySet const*);
int32_t vox2_regex_uset_getItem(Vox2UnicodePropertySet const*, int32_t, UChar32*, UChar32*, UChar*, int32_t, UErrorCode*);
#endif
#endif
