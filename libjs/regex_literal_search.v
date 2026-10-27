module libjs

// LibRegex/Rust/src/vm.rs literal prefilters and start-position hint scans.
// These reject impossible attempts; the regex VM remains responsible for matches.
pub fn regex_contains_u16_from(input RegexInput, start uint, needle []u16) bool {
	if needle.len == 0 { return true }
	if needle.len == 1 { return input.find_code_unit(start, input.len(), needle[0]) != none }
	if start > input.len() || uint(needle.len) > input.len() - start { return false }
	mut pos := start
	end := input.len() - uint(needle.len) + 1
	for pos < end {
		pos = input.find_code_unit(pos, end, needle[0]) or { return false }
		if input.matches_u16_at(pos, needle) { return true }
		pos++
	}
	return false
}

pub fn regex_fold_ascii_for_compare(unit u16) u16 {
	if unit >= 0x41 && unit <= 0x5a { return unit + 32 }
	return unit
}

pub fn regex_matches_ascii_case_insensitive_u16_at(input RegexInput, pos uint, needle []u16) bool {
	if pos > input.len() || uint(needle.len) > input.len() - pos { return false }
	for offset, expected in needle {
		actual := input.code_unit(pos + uint(offset))
		if actual > 0x7f
			|| regex_fold_ascii_for_compare(actual) != regex_fold_ascii_for_compare(expected) {
			return false
		}
	}
	return true
}

pub fn regex_contains_ascii_case_insensitive_u16_from(input RegexInput, start uint, needle []u16) bool {
	if needle.len == 0 { return true }
	needle_len := uint(needle.len)
	if start > input.len() || needle_len > input.len() - start { return false }
	folded_first := regex_fold_ascii_for_compare(needle[0])
	mut pos := start
	end := input.len() - needle_len + 1
	for pos < end {
		for pos < end {
			unit := input.code_unit(pos)
			if unit <= 0x7f && regex_fold_ascii_for_compare(unit) == folded_first { break
			 }
			pos++
		}
		if pos >= end { return false }
		if regex_matches_ascii_case_insensitive_u16_at(input, pos, needle) { return true }
		pos++
	}
	return false
}

pub fn regex_fails_trailing_literal_hint(input RegexInput, hints RegexPatternHints) bool {
	suffix := hints.trailing_literal or { return false }
	return !input.ends_with_u16(suffix)
}

pub fn regex_fails_required_literal_hint(input RegexInput, start uint, hints RegexPatternHints) bool {
	literal := hints.required_literal or { return false }
	matched := if literal.ascii_case_insensitive {
		regex_contains_ascii_case_insensitive_u16_from(input, start, literal.literal)
	} else {
		regex_contains_u16_from(input, start, literal.literal)
	}
	return !matched
}

pub fn regex_next_literal_start_from_hint(input RegexInput, start uint, hint RegexStartPositionHint) ?uint {
	if hint.includes_input_start && start == 0 { return 0 }
	match hint.literal_code_units.len {
		1 {
			return input.next_literal_start(start, hint.literal_code_units[0])
		}
		2 {
			first := hint.literal_code_units[0]
			second := hint.literal_code_units[1]
			for pos := start; pos < input.len(); pos++ {
				unit := input.code_unit(pos)
				if unit == first || unit == second { return pos }
			}
		}
		else {}
	}

	return none
}
