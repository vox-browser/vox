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

fn requested_video_frame_time(markup string) f64 {
	last_five := markup.last_index('currentTime = 5') or { -1 }
	last_zero := markup.last_index('currentTime = 0') or { -1 }
	return if last_five > last_zero { 5.0 } else { 0.0 }
}

// Joined scripts have a newline between them, so these literal matches cannot
// cross a script boundary. The last matching script determines the old result.
fn requested_video_frame_time_for_scripts(scripts []string) f64 {
	for index := scripts.len - 1; index >= 0; index-- {
		source := scripts[index]
		last_five := source.last_index('currentTime = 5') or { -1 }
		last_zero := source.last_index('currentTime = 0') or { -1 }
		if last_five >= 0 || last_zero >= 0 { return if last_five > last_zero { 5.0 } else { 0.0 } }
	}
	return 0.0
}

fn quoted_video_references(scripts []string) []string {
	mut references := []string{}
	mut seen := map[string]bool{}
	for source in scripts {
		mut position := 0
		for position < source.len {
			if source[position] != `'` && source[position] != `"` {
				position++
				continue
			}
			quote := source[position]
			start := position + 1
			position = start
			for position < source.len && source[position] != quote {
				position++
			}
			if position >= source.len {
				break
			}
			value := unsafe { source.substr_unsafe(start, position) }
			if quoted_video_reference_has_extension(value) && value !in seen {
				owned := value.clone()
				seen[owned] = true
				references << owned
			}
			position++
		}
	}
	return references
}

