module main

// JSON.stringify retains unpaired UTF-16 units as Unicode escapes. The
// private DOM replay transport stores those units as WTF-8 in V strings;
// json2 otherwise rejects them before the DOM/USVString owners can consume
// them. Keep paired escapes and all JSON syntax validation in json2.
fn compact_replay_json_text(source string) string {
	if !source.contains('\\u') { return source }
	mut output := []u8{cap: source.len}
	mut in_string := false
	mut position := 0
	for position < source.len {
		byte := source[position]
		if in_string && byte == `\\` {
			if unit := compact_replay_json_escape(source, position) {
				if unit >= 0xd800 && unit <= 0xdbff {
					if next := compact_replay_json_escape(source, position + 6) {
						if next >= 0xdc00 && next <= 0xdfff {
							output << source[position..position + 12].bytes()
							position += 12
							continue
						}
					}
				}
				if unit >= 0xd800 && unit <= 0xdfff {
					output << u8(0xe0 | (unit >> 12))
					output << u8(0x80 | ((unit >> 6) & 0x3f))
					output << u8(0x80 | (unit & 0x3f))
					position += 6
					continue
				}
			}
			output << byte
			position++
			if position < source.len {
				output << source[position]
				position++
			}
			continue
		}
		if byte == `"` { in_string = !in_string }
		output << byte
		position++
	}
	return output.bytestr()
}

// json2's ordinary encoder preserves string bytes. Escape only its WTF-8
// surrogate sequences before the UTF-8 C string crosses back into JavaScript.
// Encoding.escape_unicode validates UTF-8 and would replace these units.
fn compact_replay_json_result(source string) string {
	if source.index_u8(0xed) < 0 { return source }
	mut output := []u8{cap: source.len}
	mut position := 0
	for position < source.len {
		if position + 2 < source.len && source[position] == 0xed
			&& source[position + 1] >= 0xa0 && source[position + 1] <= 0xbf
			&& source[position + 2] & 0xc0 == 0x80 {
			unit := (u16(source[position] & 0x0f) << 12) |
				(u16(source[position + 1] & 0x3f) << 6) | u16(source[position + 2] & 0x3f)
			output << '\\u'.bytes()
			for shift in [12, 8, 4, 0] { output << '0123456789abcdef'[int((unit >> shift) & 0xf)] }
			position += 3
			continue
		}
		output << source[position]
		position++
	}
	return output.bytestr()
}

fn compact_replay_json_escape(source string, position int) ?u16 {
	if position + 6 > source.len || source[position] != `\\` || source[position + 1] != `u` {
		return none
	}
	mut unit := u16(0)
	for byte in source[position + 2..position + 6] {
		digit := match byte {
			`0`...`9` { byte - `0` }
			`a`...`f` { byte - `a` + 10 }
			`A`...`F` { byte - `A` + 10 }
			else { return none }
		}
		unit = (unit << 4) | u16(digit)
	}
	return unit
}
