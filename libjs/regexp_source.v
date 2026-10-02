module libjs

// Runtime/RegExpObject.cpp::escape_regexp_pattern, with the stored original
// pattern passed explicitly until the RegExp object and compiler are translated.
// Preserve the source's pending u/v-specific escaping and trailing-backslash
// behavior; this helper is not a regex grammar validator.
pub fn escape_regexp_pattern(pattern Utf16String) Utf16String {
	if pattern.is_empty() { return utf16_string('(?:)') }
	mut output := []u16{}
	mut escaped := false
	mut in_class := false
	mut index := 0
	for index < pattern.len() {
		point := string_code_point_at(pattern, index)
		code_point := point.code_point
		index += point.code_unit_count
		if escaped {
			escaped = false
			output << u16(`\\`)
			match code_point {
				0x0a { output << u16(`n`) }
				0x0d { output << u16(`r`) }
				0x2028 { output << utf16('u2028') }
				0x2029 { output << utf16('u2029') }
				else { append_utf16_code_point(mut output, code_point) }
			}

			continue
		}
		if code_point == u32(`\\`) {
			escaped = true
			continue
		}
		if code_point == u32(`[`) {
			in_class = true
		} else if code_point == u32(`]`) {
			in_class = false
		}
		match code_point {
			0x2f { output << utf16(if in_class { '/' } else { '\\/' }) }
			0x0a { output << utf16('\\n') }
			0x0d { output << utf16('\\r') }
			0x2028 { output << utf16('\\u2028') }
			0x2029 { output << utf16('\\u2029') }
			else { append_utf16_code_point(mut output, code_point) }
		}
	}
	return Utf16String{
		data: output
	}
}
