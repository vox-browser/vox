module libjs

// LibRegex/Rust/src/vm.rs::{first_char_matches,first_filter_matches,
// next_candidate_start}. These choose candidate positions; VM execution and
// consuming scans are separate translation slices.
pub fn regex_first_char_matches(program RegexProgram, input RegexInput, pos uint, target u32, case_insensitive bool) bool {
	if pos >= input.len() { return false }
	point := if program.unicode && is_utf16_high_surrogate(input.code_unit(pos))
		&& pos + 1 < input.len() && is_utf16_low_surrogate(input.code_unit(pos + 1)) {
		0x10000 + ((u32(input.code_unit(pos)) - 0xd800) << 10) + (u32(input.code_unit(pos + 1)) -
			0xdc00)
	} else {
		u32(input.code_unit(pos))
	}
	if case_insensitive { return regex_case_fold_eq(point, target, program.unicode) }
	return point == target
}

// The source caller checks pos < input.len() before invoking this predicate.
pub fn regex_first_filter_matches(program RegexProgram, input RegexInput, pos uint, filter RegexSimpleMatch) bool {
	point := regex_decode_code_point(program.unicode, input, pos)
	return match filter {
		RegexBuiltinCharacterClass {
			regex_match_builtin_class(point, filter, program.ignore_case && program.unicode)
		}
		RegexBytecodeCharClass {
			regex_char_in_ranges(point, filter.ranges) != filter.negated
		}
		RegexAnyChar {
			filter.dot_all || !regex_is_line_terminator(point)
		}
		RegexLiteral {
			point == filter.code_point
		}
		RegexCharNoCase {
			regex_case_fold_eq(point, filter.first, program.unicode)
		}
		RegexUnicodePropertyData {
			regex_match_unicode_property_resolved(point, filter.name, filter.value, filter.resolved) != filter.negated
		}
		RegexSimpleUnion {
			regex_first_filter_matches(program, input, pos, *filter.left)
				|| regex_first_filter_matches(program, input, pos, *filter.right)
		}
	}
}

pub fn regex_next_candidate_start(program RegexProgram, input RegexInput, hints RegexPatternHints, start uint) ?uint {
	mut pos := start
	for pos <= input.len() {
		// Ladybird aa125429b608: even an empty match must start at a
		// code-point boundary in Unicode mode.
		if program.unicode && pos > 0 && pos < input.len()
			&& is_utf16_low_surrogate(input.code_unit(pos))
			&& is_utf16_high_surrogate(input.code_unit(pos - 1)) {
			pos++
			continue
		}
		if hints.starts_with_anchor && pos != 0
			&& !regex_is_line_terminator(u32(input.code_unit(pos - 1))) {
			pos++
			continue
		}
		if first := hints.first_char {
			if !regex_first_char_matches(program, input, pos, first.code_point,
				first.case_insensitive) {
				if pos >= input.len() { return none }
				pos++
				continue
			}
		}
		if filter := hints.first_filter {
			if pos >= input.len() { return none }
			if !regex_first_filter_matches(program, input, pos, filter) {
				pos++
				continue
			}
		}
		return pos
	}
	return none
}
