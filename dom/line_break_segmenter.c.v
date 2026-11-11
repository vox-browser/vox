// Translated from Libraries/LibUnicode/Segmenter.cpp (ICU line segmenters for
// each UnicodeLayoutLineBreakMode) and Libraries/LibWeb/Rust/src/layout/
// text_chunker.rs (LineBreakLanguage).
module dom

#flag darwin -licucore
#flag linux -licuuc
#include "@DIR/unicode_line_break_bridge.h"

fn C.libweb_v_line_break_boundaries(text &u16, length i32, mode i32, boundaries &i32) i32

// The ICU line segmenter tailoring for a text's `line-break` value and, for
// `loose`, its content language. The order matches the bridge's iterators.
// https://drafts.csswg.org/css-text-3/#line-break-property
// `auto` uses ICU's default rules, which are strict.
pub enum LineBreakMode {
	strict
	normal
	loose
	loose_japanese
	loose_chinese
}

pub enum LineBreakLanguage {
	other
	japanese
	chinese
}

fn line_break_language_subtag_is_alpha(subtag string) bool {
	for byte in subtag.bytes() {
		if !((byte >= `a` && byte <= `z`) || (byte >= `A` && byte <= `Z`)) {
			return false
		}
	}
	return true
}

fn line_break_language_subtag_matches(subtag string, names []string) bool {
	lowercase := to_ascii_lowercase(subtag)
	return lowercase in names
}

// LineBreakLanguage::from_tag(): the writing system a BCP 47 language tag
// names for line breaking.
pub fn LineBreakLanguage.from_tag(tag string) LineBreakLanguage {
	if tag.len == 0 {
		return .other
	}
	subtags := tag.split('-')
	primary := subtags[0]
	if primary.len < 2 || primary.len > 8 || !line_break_language_subtag_is_alpha(primary) {
		return .other
	}
	mut candidate_index := 1
	// BCP47 permits up to three extlang subtags, only after a two- or
	// three-letter primary language.
	if primary.len <= 3 {
		for _ in 0 .. 3 {
			if candidate_index >= subtags.len {
				break
			}
			extlang := subtags[candidate_index]
			if extlang.len != 3 || !line_break_language_subtag_is_alpha(extlang) {
				break
			}
			candidate_index++
		}
	}
	// https://drafts.csswg.org/css-text-4/#script-tagging
	// Only this position can name a script. Region, variant, extension and
	// private-use subtags cannot override it.
	if candidate_index < subtags.len {
		script := subtags[candidate_index]
		if script.len == 4 && line_break_language_subtag_is_alpha(script) {
			if line_break_language_subtag_matches(script, ['hant', 'hans', 'hani', 'hanb', 'bopo']) {
				return .chinese
			}
			if line_break_language_subtag_matches(script, ['jpan', 'hrkt', 'hira', 'kana']) {
				return .japanese
			}
			return .other
		}
	}
	if line_break_language_subtag_matches(primary, ['ja']) {
		return .japanese
	}
	if line_break_language_subtag_matches(primary, ['zh']) {
		return .chinese
	}
	return .other
}

// Unicode line breaking (UAX #14) through ICU, with the CSS `line-break`
// tailoring of the segmenter's mode. Boundaries are UTF-16 offsets and include
// the start and end of the text.
fn segmenter_line_boundaries(text string, mode LineBreakMode) []int {
	units := utf16_code_units_from_string(text)
	if units.len == 0 {
		return [0]
	}
	mut raw := []i32{len: units.len + 1}
	count := int(C.libweb_v_line_break_boundaries(units.data, i32(units.len), i32(mode),
		raw.data))
	if count <= 0 {
		return [0, units.len]
	}
	mut boundaries := []int{cap: count}
	for index in 0 .. count {
		boundaries << int(raw[index])
	}
	return boundaries
}
