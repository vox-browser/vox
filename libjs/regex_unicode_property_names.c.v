module libjs

#flag -I @DIR
#flag darwin -licucore
// The property bridge binds ICU 78 explicitly. Homebrew's current ICU can have
// a different ABI, so use its pinned `icu4c@78` keg (`brew install icu4c@78`),
// or with `-d vox_vcpkg` the vcpkg ICU that the FFmpeg/Skia bridges load.
$if !vox_vcpkg ? {
	$if arm64 {
		#flag darwin /opt/homebrew/opt/icu4c@78/lib/libicuuc.78.dylib
	} $else {
		#flag darwin /usr/local/opt/icu4c@78/lib/libicuuc.78.dylib
	}
} $else $if arm64 {
	#flag darwin @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib/libicuuc.dylib
	#flag darwin -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic/lib
} $else {
	#flag darwin @DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib/libicuuc.dylib
	#flag darwin -Wl,-rpath,@DIR/../../3rd/ladybird/Build/release/vcpkg_installed/x64-osx-dynamic/lib
}
#flag linux -licuuc
#include "regex_unicode_property.h"

@[typedef]
struct C.Vox2UnicodePropertySet {}

fn C.vox2_regex_uset_closeOver(set &C.Vox2UnicodePropertySet, attributes int)
fn C.vox2_regex_uset_getRangeCount(set &C.Vox2UnicodePropertySet) int
fn C.vox2_regex_uset_getItem(set &C.Vox2UnicodePropertySet, index int, start &int, end &int, output &u16, capacity int, status &int) int
fn C.vox2_regex_u_isIDStart(point int) i8
fn C.vox2_regex_u_isIDPart(point int) i8

fn regex_unicode_property_set_range(set &C.Vox2UnicodePropertySet, index int) RegexCharRange {
	mut start := 0
	mut end := 0
	mut status := 0
	length := C.vox2_regex_uset_getItem(set, index, &start, &end, unsafe { nil }, 0, &status)
	assert length == 0 && status <= 0
	return RegexCharRange{
		start: u32(start)
		end:   u32(end)
	}
}

fn regex_unicode_property_id_start(point u32) bool {
	return C.vox2_regex_u_isIDStart(int(point)) != 0
}

fn regex_unicode_property_id_continue(point u32) bool {
	return C.vox2_regex_u_isIDPart(int(point)) != 0
}

fn C.vox2_regex_u_getPropertyValueName(property int, value int, choice int) &char
fn C.vox2_regex_u_getPropertyName(property int, choice int) &char
fn C.vox2_regex_u_charType(code_point int) i8
fn C.vox2_regex_u_hasBinaryProperty(code_point int, property int) i8
fn C.vox2_regex_u_isdefined(code_point int) i8
fn C.vox2_regex_uscript_getName(script int) &char
fn C.vox2_regex_uscript_getShortName(script int) &char
fn C.vox2_regex_uscript_getScript(code_point int, status &int) int
fn C.vox2_regex_uscript_hasScript(code_point int, script int) i8
fn C.vox2_regex_uset_openEmpty() &C.Vox2UnicodePropertySet
fn C.vox2_regex_uset_applyIntPropertyValue(set &C.Vox2UnicodePropertySet, property int, value int, status &int)
fn C.vox2_regex_uset_freeze(set &C.Vox2UnicodePropertySet)
fn C.vox2_regex_uset_contains(set &C.Vox2UnicodePropertySet, code_point int) i8

struct RegexUnicodePropertyNames {
	long_name       ?string
	short_name      ?string
	additional_name ?string
}

__global (
	regex_unicode_category_names []RegexUnicodePropertyNames
	regex_unicode_binary_names   []RegexUnicodePropertyNames
	regex_unicode_script_names   []RegexUnicodePropertyNames
	regex_unicode_category_sets  = map[u32]&C.Vox2UnicodePropertySet{}
	regex_unicode_binary_sets    = map[u32]&C.Vox2UnicodePropertySet{}
)

fn regex_unicode_optional_name(pointer &char) ?string {
	if unsafe { pointer == nil } { return none }
	// ICU owns these immutable alias strings for the process lifetime.
	return unsafe { cstring_to_vstring(pointer) }
}

fn (names RegexUnicodePropertyNames) matches(value string) bool {
	if name := names.long_name {
		if value == name { return true }
	}
	if name := names.short_name {
		if value == name { return true }
	}
	if name := names.additional_name {
		if value == name { return true }
	}
	return false
}

fn regex_unicode_value_names(property int, value int) RegexUnicodePropertyNames {
	return RegexUnicodePropertyNames{
		long_name:       regex_unicode_optional_name(C.vox2_regex_u_getPropertyValueName(property,
			value, 1))
		short_name:      regex_unicode_optional_name(C.vox2_regex_u_getPropertyValueName(property,
			value, 0))
		additional_name: regex_unicode_optional_name(C.vox2_regex_u_getPropertyValueName(property,
			value, 2))
	}
}

// LibUnicode/CharacterTypes.cpp::general_category_from_string/get_icu_mask.
pub fn regex_unicode_category_from_string(value string) ?u32 {
	if regex_unicode_category_names.len == 0 {
		mut names := []RegexUnicodePropertyNames{len: int(C.U_CHAR_CATEGORY_COUNT) + 9}
		for category in 0 .. int(C.U_CHAR_CATEGORY_COUNT) {
			names[category] = regex_unicode_value_names(C.UCHAR_GENERAL_CATEGORY, category)
		}
		for offset in 1 .. 9 {
			category := u32(C.U_CHAR_CATEGORY_COUNT) + u32(offset)
			names[int(category)] = regex_unicode_value_names(C.UCHAR_GENERAL_CATEGORY_MASK,
				int(regex_unicode_category_mask(category)))
		}
		regex_unicode_category_names = names.clone()
	}
	for index, names in regex_unicode_category_names {
		if names.matches(value) { return u32(index) }
	}
	return none
}

fn regex_unicode_category_mask(category u32) u32 {
	return match category - u32(C.U_CHAR_CATEGORY_COUNT) {
		1 { u32(C.U_GC_LC_MASK) }
		2 { u32(C.U_GC_L_MASK) }
		3 { u32(C.U_GC_M_MASK) }
		4 { u32(C.U_GC_N_MASK) }
		5 { u32(C.U_GC_P_MASK) }
		6 { u32(C.U_GC_S_MASK) }
		7 { u32(C.U_GC_Z_MASK) }
		8 { u32(C.U_GC_C_MASK) }
		else { u32(1) << category }
	}
}

fn regex_unicode_case_closed_set(property int, value int) &C.Vox2UnicodePropertySet {
	set := C.vox2_regex_uset_openEmpty()
	if unsafe { set == nil } { panic('ICU UnicodeSet allocation failed') }
	mut status := 0
	C.vox2_regex_uset_applyIntPropertyValue(set, property, value, &status)
	// The source retains the set even if applyIntPropertyValue reports failure.
	C.vox2_regex_uset_closeOver(set, C.USET_CASE_INSENSITIVE)
	C.vox2_regex_uset_freeze(set)
	return set
}

pub fn regex_unicode_has_general_category(point u32, category u32, ignore_case bool) bool {
	mask := regex_unicode_category_mask(category)
	if (u32(1) << u32(C.vox2_regex_u_charType(int(point)))) & mask != 0 { return true }
	if !ignore_case { return false }
	if category !in regex_unicode_category_sets {
		regex_unicode_category_sets[category] = regex_unicode_case_closed_set(C.UCHAR_GENERAL_CATEGORY_MASK,
			int(mask))
	}
	set := regex_unicode_category_sets[category] or { panic('Missing cached Unicode category set') }
	return C.vox2_regex_uset_contains(set, int(point)) != 0
}

// Property IDs and synthetic Any/ASCII/Assigned IDs retain upstream's ICU layout.
pub fn regex_unicode_property_from_string(value string) ?u32 {
	if regex_unicode_binary_names.len == 0 {
		mut names := []RegexUnicodePropertyNames{len: int(C.UCHAR_BINARY_LIMIT) + 4}
		for property in 0 .. int(C.UCHAR_BINARY_LIMIT) {
			names[property] = RegexUnicodePropertyNames{
				long_name:       regex_unicode_optional_name(C.vox2_regex_u_getPropertyName(property, 1))
				short_name:      regex_unicode_optional_name(C.vox2_regex_u_getPropertyName(property, 0))
				additional_name: regex_unicode_optional_name(C.vox2_regex_u_getPropertyName(property, 2))
			}
		}
		for index, name in ['Any', 'ASCII', 'Assigned'] {
			names[int(C.UCHAR_BINARY_LIMIT) + 1 + index] = RegexUnicodePropertyNames{
				long_name: name
			}
		}
		regex_unicode_binary_names = names.clone()
	}
	for index, names in regex_unicode_binary_names {
		if names.matches(value) { return u32(index) }
	}
	return none
}

pub fn regex_unicode_has_property(point u32, property u32, ignore_case bool) bool {
	if property == u32(C.UCHAR_BINARY_LIMIT) + 1 { return point <= 0x10ffff }
	if property == u32(C.UCHAR_BINARY_LIMIT) + 2 { return point < 128 }
	if property == u32(C.UCHAR_BINARY_LIMIT) + 3 { return C.vox2_regex_u_isdefined(int(point)) != 0 }
	if C.vox2_regex_u_hasBinaryProperty(int(point), int(property)) != 0 { return true }
	if !ignore_case { return false }
	if property !in regex_unicode_binary_sets {
		regex_unicode_binary_sets[property] = regex_unicode_case_closed_set(int(property), 1)
	}
	set := regex_unicode_binary_sets[property] or { panic('Missing cached Unicode property set') }
	return C.vox2_regex_uset_contains(set, int(point)) != 0
}

pub fn regex_unicode_script_from_string(value string) ?u32 {
	if regex_unicode_script_names.len == 0 {
		mut names := []RegexUnicodePropertyNames{len: int(C.VOX2_USCRIPT_CODE_LIMIT)}
		for script in 0 .. names.len {
			names[script] = RegexUnicodePropertyNames{
				long_name:       regex_unicode_optional_name(C.vox2_regex_uscript_getName(script))
				short_name:      regex_unicode_optional_name(C.vox2_regex_uscript_getShortName(script))
				additional_name: regex_unicode_optional_name(C.vox2_regex_u_getPropertyValueName(C.UCHAR_SCRIPT,
					script, 2))
			}
		}
		regex_unicode_script_names = names.clone()
	}
	for index, names in regex_unicode_script_names {
		if names.matches(value) { return u32(index) }
	}
	return none
}

pub fn regex_unicode_has_script(point u32, script u32) bool {
	mut status := 0
	actual := C.vox2_regex_uscript_getScript(int(point), &status)
	return status <= 0 && actual == int(script)
}

pub fn regex_unicode_has_script_extension(point u32, script u32) bool {
	return C.vox2_regex_uscript_hasScript(int(point), int(script)) != 0
}

pub fn regex_unicode_is_ecma262_property(property u32) bool {
	if property >= u32(C.UCHAR_BINARY_LIMIT) + 1 && property <= u32(C.UCHAR_BINARY_LIMIT) + 3 {
		return true
	}
	return int(property) in [int(C.UCHAR_ASCII_HEX_DIGIT), C.UCHAR_ALPHABETIC, C.UCHAR_BIDI_CONTROL,
		C.UCHAR_BIDI_MIRRORED, C.UCHAR_CASE_IGNORABLE, C.UCHAR_CASED, C.UCHAR_CHANGES_WHEN_CASEFOLDED,
		C.UCHAR_CHANGES_WHEN_CASEMAPPED, C.UCHAR_CHANGES_WHEN_LOWERCASED,
		C.UCHAR_CHANGES_WHEN_NFKC_CASEFOLDED, C.UCHAR_CHANGES_WHEN_TITLECASED,
		C.UCHAR_CHANGES_WHEN_UPPERCASED, C.UCHAR_DASH, C.UCHAR_DEFAULT_IGNORABLE_CODE_POINT,
		C.UCHAR_DEPRECATED, C.UCHAR_DIACRITIC, C.UCHAR_EMOJI, C.UCHAR_EMOJI_COMPONENT,
		C.UCHAR_EMOJI_MODIFIER, C.UCHAR_EMOJI_MODIFIER_BASE, C.UCHAR_EMOJI_PRESENTATION,
		C.UCHAR_EXTENDED_PICTOGRAPHIC, C.UCHAR_EXTENDER, C.UCHAR_GRAPHEME_BASE, C.UCHAR_GRAPHEME_EXTEND,
		C.UCHAR_HEX_DIGIT, C.UCHAR_IDS_BINARY_OPERATOR, C.UCHAR_IDS_TRINARY_OPERATOR,
		C.UCHAR_ID_CONTINUE, C.UCHAR_ID_START, C.UCHAR_IDEOGRAPHIC, C.UCHAR_JOIN_CONTROL,
		C.UCHAR_LOGICAL_ORDER_EXCEPTION, C.UCHAR_LOWERCASE, C.UCHAR_MATH,
		C.UCHAR_NONCHARACTER_CODE_POINT, C.UCHAR_PATTERN_SYNTAX, C.UCHAR_PATTERN_WHITE_SPACE,
		C.UCHAR_QUOTATION_MARK, C.UCHAR_RADICAL, C.UCHAR_REGIONAL_INDICATOR, C.UCHAR_S_TERM,
		C.UCHAR_SOFT_DOTTED, C.UCHAR_TERMINAL_PUNCTUATION, C.UCHAR_UNIFIED_IDEOGRAPH, C.UCHAR_UPPERCASE,
		C.UCHAR_VARIATION_SELECTOR, C.UCHAR_WHITE_SPACE, C.UCHAR_XID_CONTINUE, C.UCHAR_XID_START]
}

pub fn regex_unicode_is_ecma262_string_property(property u32) bool {
	return int(property) in [int(C.UCHAR_BASIC_EMOJI), C.UCHAR_EMOJI_KEYCAP_SEQUENCE, C.UCHAR_RGI_EMOJI,
		C.UCHAR_RGI_EMOJI_FLAG_SEQUENCE, C.UCHAR_RGI_EMOJI_TAG_SEQUENCE,
		C.UCHAR_RGI_EMOJI_MODIFIER_SEQUENCE, C.UCHAR_RGI_EMOJI_ZWJ_SEQUENCE]
}
