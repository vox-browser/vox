module main

fn quoted_video_reference_has_extension(value string) bool {
	for index := 0; index + 3 < value.len; index++ {
		if value[index] != `.` { continue }
		first := value[index + 1] | u8(0x20)
		if first == `m` && (value[index + 2] | u8(0x20)) == `p` && value[index + 3] == `4` {
			return true
		}
		if first == `w` && index + 4 < value.len
			&& (value[index + 2] | u8(0x20)) == `e`
			&& (value[index + 3] | u8(0x20)) == `b`
			&& (value[index + 4] | u8(0x20)) == `m` {
			return true
		}
	}
	return false
}

fn javascript_video_reference_can_be_local(reference string, current_url string) bool {
	if !current_url.starts_with('http://') && !current_url.starts_with('https://') {
		return true
	}
	trimmed := reference.trim_space()
	mut position := 0
	// Match URL preprocessing before deciding whether an explicit scheme is
	// possible: trim leading C0 controls/spaces and ignore TAB, LF and CR.
	for position < trimmed.len && trimmed[position] <= 0x20 { position++ }
	mut first := true
	for position < trimmed.len {
		character := trimmed[position]
		position++
		if character == `\t` || character == `\n` || character == `\r` { continue }
		alpha := (character >= `A` && character <= `Z`)
			|| (character >= `a` && character <= `z`)
		if first {
			if !alpha { return false }
			first = false
			continue
		}
		// The legacy decoder also accepts opaque URLs without :// as local
		// names. Keep every explicit scheme as a conservative candidate.
		if character == `:` { return true }
		if !alpha && !(character >= `0` && character <= `9`)
			&& character != `+` && character != `-` && character != `.` { return false }
	}
	return false
}
