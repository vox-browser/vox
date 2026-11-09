module libjs

import encoding.hex

fn regex_engine_fixture_flags(mask int) RegexAstFlags {
	return RegexAstFlags{
		global:       mask & 1 != 0
		ignore_case:  mask & 2 != 0
		multiline:    mask & 4 != 0
		dot_all:      mask & 8 != 0
		unicode:      mask & 16 != 0
		unicode_sets: mask & 32 != 0
		sticky:       mask & 64 != 0
		has_indices:  mask & 128 != 0
	}
}

fn test_v_regex_engine_matches_pinned_rust_results_and_all_capture_slots() {
	mut count := 0
	for row in $embed_file('testdata/regex-engine.tsv').to_string().split_into_lines() {
		if row.len == 0 || row.starts_with('#') { continue }
		fields := row.split('\t')
		assert fields.len == 7, row
		pattern := hex.decode(fields[2])!.bytestr()
		mut actual := ''
		if mut engine := RegexEngine.compile(pattern.runes(), regex_engine_fixture_flags(fields[1].int())) {
			mut units := []u16{}
			for offset := 0; offset < fields[3].len; offset += 4 {
				units << u16(fields[3][offset..offset + 4].parse_uint(16, 16)!)
			}
			input := if fields[0] in ['a', 'b'] {
				RegexInput(RegexAsciiInput{ bytes: units.map(u8(it)) })
			} else {
				RegexInput(RegexUtf16Input{ units: units })
			}
			mut output := []i32{len: fields[5].int(), init: -77}
			start := uint(fields[4].u64())
			mut result := 0
			if fields[0] in ['f', 'b'] {
				result = int(engine.find_all(input, start, mut output))
			} else {
				status := if fields[0] == 't' {
					engine.test(input, start)
				} else {
					engine.exec(input, start, mut output)
				}
				result = match status {
					.match { 1 }
					.no_match { 0 }
					.limit_exceeded { -1 }
				}
			}
			actual = '${result};${output.map(it.str()).join(',')};${engine.program.capture_count};${if engine.is_single_non_bmp_literal() {
				1
			} else {
				0
			}}'
		} else {
			actual = '!${err.msg()}'
		}
		assert actual == fields[6], 'op=${fields[0]} flags=${fields[1]} pattern=${pattern} input=${fields[3]} start=${fields[4]} cap=${fields[5]}'
		count++
	}
	assert count == 26544
}
