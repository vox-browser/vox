module libjs

// Runtime/RegExpObject.{h,cpp}::ParseRegexPatternError and the preparation
// helpers preceding ParsePattern. Regex grammar compilation is a later step.
pub struct ParseRegexPatternError {
	Error
pub:
	error Utf16String
}

pub fn (err ParseRegexPatternError) msg() string {
	return err.error.str()
}

enum RegExpNameElementKind {
	code_point
	high_surrogate
	low_surrogate
}

enum RegExpNameElementOrigin {
	literal
	fixed_escape
	braced_escape
}

struct RegExpNameElement {
	kind       RegExpNameElementKind
	origin     RegExpNameElementOrigin
	next_index int
}

fn invalid_regexp_group_name_error() ParseRegexPatternError {
	return ParseRegexPatternError{
		error: utf16_string('invalid group name')
	}
}

fn parse_regexp_name_element(pattern Utf16String, index int) !RegExpNameElement {
	length := pattern.len()
	if index >= length { return invalid_regexp_group_name_error() }
	unit := pattern.data[index]
	if unit != u16(`\\`) {
		if is_utf16_high_surrogate(unit) {
			if index + 1 < length && is_utf16_low_surrogate(pattern.data[index + 1]) {
				return RegExpNameElement{
					kind:       .code_point
					origin:     .literal
					next_index: index + 2
				}
			}
			return RegExpNameElement{
				kind:       .high_surrogate
				origin:     .literal
				next_index: index + 1
			}
		}
		if is_utf16_low_surrogate(unit) {
			return RegExpNameElement{
				kind:       .low_surrogate
				origin:     .literal
				next_index: index + 1
			}
		}
		return RegExpNameElement{
			kind:       .code_point
			origin:     .literal
			next_index: index + 1
		}
	}
	if index + 1 >= length || pattern.data[index + 1] != u16(`u`) {
		return invalid_regexp_group_name_error()
	}
	mut cursor := index + 2
	if cursor < length && pattern.data[cursor] == u16(`{`) {
		cursor++
		mut value := u32(0)
		mut digits := 0
		for cursor < length && pattern.data[cursor] != u16(`}`) {
			digit := hex_digit(pattern.data[cursor]) or { return invalid_regexp_group_name_error() }
			value = value * 16 + u32(digit)
			if value > 0x10ffff { return invalid_regexp_group_name_error() }
			digits++
			cursor++
		}
		if digits == 0 || cursor >= length || pattern.data[cursor] != u16(`}`) {
			return invalid_regexp_group_name_error()
		}
		cursor++
		kind := if value >= 0xd800 && value <= 0xdbff {
			RegExpNameElementKind.high_surrogate
		} else if value >= 0xdc00 && value <= 0xdfff {
			RegExpNameElementKind.low_surrogate
		} else {
			RegExpNameElementKind.code_point
		}
		return RegExpNameElement{
			kind:       kind
			origin:     .braced_escape
			next_index: cursor
		}
	}
	if cursor + 4 > length { return invalid_regexp_group_name_error() }
	mut value := u16(0)
	for offset in 0 .. 4 {
		digit := hex_digit(pattern.data[cursor + offset]) or {
			return invalid_regexp_group_name_error()
		}
		value = value * 16 + digit
	}
	kind := if is_utf16_high_surrogate(value) {
		RegExpNameElementKind.high_surrogate
	} else if is_utf16_low_surrogate(value) {
		RegExpNameElementKind.low_surrogate
	} else {
		RegExpNameElementKind.code_point
	}
	return RegExpNameElement{
		kind:       kind
		origin:     .fixed_escape
		next_index: cursor + 4
	}
}

fn validate_regexp_name_surrogates(pattern Utf16String, name_start int) !int {
	mut index := name_start
	for index < pattern.len() {
		if pattern.data[index] == u16(`>`) { return index + 1 }
		element := parse_regexp_name_element(pattern, index)!
		if element.kind == .code_point {
			index = element.next_index
			continue
		}
		if element.kind == .low_surrogate { return invalid_regexp_group_name_error() }
		next := parse_regexp_name_element(pattern, element.next_index)!
		if next.kind != .low_surrogate || element.origin != next.origin
			|| element.origin == .braced_escape {
			return invalid_regexp_group_name_error()
		}
		index = next.next_index
	}
	return invalid_regexp_group_name_error()
}

fn pattern_has_named_capture_groups(pattern Utf16String) bool {
	length := pattern.len()
	mut in_class := false
	for index := 0; index < length; index++ {
		unit := pattern.data[index]
		if unit == u16(`\\`) {
			if index + 1 < length { index++ }
			continue
		}
		if unit == u16(`[`) && !in_class {
			in_class = true
			continue
		}
		if unit == u16(`]`) && in_class {
			in_class = false
			continue
		}
		if in_class { continue
		 }
		if unit == u16(`(`) && index + 2 < length && pattern.data[index + 1] == u16(`?`)
			&& pattern.data[index + 2] == u16(`<`) {
			if index + 3 >= length || (pattern.data[index + 3] != u16(`=`)
				&& pattern.data[index + 3] != u16(`!`)) {
				return true
			}
		}
	}
	return false
}

fn validate_named_group_name_surrogates(pattern Utf16String, unicode_aware bool) ! {
	length := pattern.len()
	mut in_class := false
	has_named_or_unicode := unicode_aware || pattern_has_named_capture_groups(pattern)
	for index := 0; index < length; index++ {
		unit := pattern.data[index]
		if unit == u16(`\\`) {
			if has_named_or_unicode && !in_class && index + 2 < length
				&& pattern.data[index + 1] == u16(`k`) && pattern.data[index + 2] == u16(`<`) {
				index = validate_regexp_name_surrogates(pattern, index + 3)! - 1
				continue
			}
			if index + 1 < length { index++ }
			continue
		}
		if unit == u16(`[`) && !in_class {
			in_class = true
			continue
		}
		if unit == u16(`]`) && in_class {
			in_class = false
			continue
		}
		if in_class { continue
		 }
		if unit == u16(`(`) && index + 2 < length && pattern.data[index + 1] == u16(`?`)
			&& pattern.data[index + 2] == u16(`<`) {
			if index + 3 < length && pattern.data[index + 3] != u16(`=`)
				&& pattern.data[index + 3] != u16(`!`) {
				index = validate_regexp_name_surrogates(pattern, index + 3)! - 1
			}
		}
	}
}

// ParsePattern's source preprocessing, not the ECMAScriptRegex compiler.
// It validates named-group surrogate forms and normalizes non-ASCII units.
pub fn parse_regex_pattern(pattern Utf16String, unicode bool, unicode_sets bool) !Utf16String {
	if unicode && unicode_sets {
		return ParseRegexPatternError{
			error: utf16_string(ErrorType.reg_exp_object_incompatible_flags.formatted('u', 'v'))
		}
	}
	validate_named_group_name_surrogates(pattern, unicode || unicode_sets)!
	mut output := []u16{}
	mut previous_backslash := false
	for index := 0; index < pattern.len(); index++ {
		unit := pattern.data[index]
		if unit > 0x7f {
			if !previous_backslash { output << u16(`\\`) }
			if (unicode || unicode_sets) && is_utf16_high_surrogate(unit)
				&& index + 1 < pattern.len() {
				next := pattern.data[index + 1]
				if is_utf16_low_surrogate(next) {
					combined := 0x10000 + (u32(unit - 0xd800) << 10) + u32(next - 0xdc00)
					output << utf16('u{${combined:x}}')
					index++
					previous_backslash = false
					continue
				}
			}
			output << utf16(if unicode || unicode_sets { 'u{${unit:04x}}' } else { 'u${unit:04x}' })
		} else {
			output << unit
		}
		if unit == u16(`\\`) {
			previous_backslash = !previous_backslash
		} else {
			previous_backslash = false
		}
	}
	return Utf16String{
		data: output
	}
}

pub fn parse_regex_pattern_with_vm(mut vm VM, pattern Utf16String, unicode bool, unicode_sets bool) !Utf16String {
	return parse_regex_pattern(pattern, unicode, unicode_sets) or {
		if err is ParseRegexPatternError { return vm.throw_error_utf16(.syntax_error, err.error) }
		panic(err)
	}
}
