module dom

import vunicode

// CSS line-break tailoring; auto uses strict.
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

fn segmenter_line_boundaries(text string, mode LineBreakMode) []int {
	return vunicode.line_boundaries(text.runes().map(u32(it)), int(mode))
}
