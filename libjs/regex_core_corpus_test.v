module libjs

fn regex_core_fixture_units(text string) ![]u16 {
	mut units := []u16{}
	if text != '-' {
		assert text.len % 4 == 0
		for offset := 0; offset < text.len; offset += 4 {
			units << u16(text[offset..offset + 4].parse_uint(16, 16)!)
		}
	}
	return units
}

fn regex_core_fixture_integers(text string) ![]i32 {
	mut values := []i32{}
	if text != '-' {
		for field in text.split(',') {
			values << i32(field.parse_int(10, 32)!)
		}
	}
	return values
}

fn regex_core_fixture_hex(units []u16) string {
	if units.len == 0 { return '-' }
	return units.map('${it:04x}').join('')
}

fn test_regex_core_helpers_match_current_upstream_rust_corpus_exactly() {
	corpus := $embed_file('testdata/regex-core.tsv').to_string()
	mut count := 0
	for row in corpus.split_into_lines() {
		if row.len == 0 || row.starts_with('#') { continue
		 }
		fields := row.split('\t')
		assert fields.len == 8, row
		a := uint(fields[3].parse_uint(10, 64)!)
		b := uint(fields[4].parse_uint(10, 64)!)
		c := uint(fields[5].parse_uint(10, 64)!)
		mut actual := ''
		match fields[0] {
			'negate' {
				actual = int(unsafe { RegexBuiltinCharacterClass(a) }.negated()).str()
			}
			'quantifier' {
				quantifier := match a {
					0 { RegexQuantifier.zero_or_more(b != 0) }
					1 { RegexQuantifier.one_or_more(b != 0) }
					2 { RegexQuantifier.zero_or_one(b != 0) }
					else { panic(row) }
				}

				maximum := if value := quantifier.max { value.str() } else { '-' }
				actual = '${quantifier.min},${maximum},' + if quantifier.greedy { '1' } else { '0' }
			}
			'property' {
				actual = if kind := regex_property_kind_from_u8(u8(a)) {
					int(kind).str()
				} else {
					'-'
				}
			}
			'append' {
				mut output := regex_core_fixture_units(fields[2])!
				mut success := true
				regex_append_code_point_wtf16(mut output, u32(a)) or { success = false }
				actual = (if success { '1' } else { '0' }) + ',' + regex_core_fixture_hex(output)
			}
			'patch' {
				mut program := RegexProgram.new()
				program.emit(RegexNop{})
				instruction := if fields[1] == 'jump' { RegexInstruction(RegexJump{
						target: u32(a)
					}) } else { RegexInstruction(RegexSplit{
						prefer: u32(a)
						other:  u32(b)
					}) }
				index := program.emit(instruction)
				program.patch_jump(index, u32(c))
				if fields[6] != '-' { program.patch_jump(index, u32(fields[6].parse_uint(10, 32)!)) }
				patched := program.instructions[int(index)]
				actual = '${index},${program.current_offset()},'
				if patched is RegexJump {
					actual += patched.target.str()
				} else if patched is RegexSplit {
					actual += '${patched.prefer},${patched.other}'
				} else {
					assert false, row
				}
			}
			'captures' {
				registers := regex_core_fixture_integers(fields[2])!
				mut output := regex_core_fixture_integers(fields[6])!
				regex_copy_captures_to_out(registers, u32(a), mut output)
				actual = if output.len == 0 { '-' } else { output.map(it.str()).join(',') }
			}
			'search_position' {
				actual = regex_next_search_position(i32(a), i32(b)).str()
			}
			'classify' {
				actual = (if regex_is_line_terminator(u32(a)) { '1' } else { '0' }) + ',' +
					if regex_is_whitespace(u32(a)) { '1' } else { '0' }
			}
			else {
				units := regex_core_fixture_units(fields[2])!
				input := if fields[1] == 'u8' { RegexInput(RegexAsciiInput{
						bytes: units.map(u8(it))
					}) } else { RegexInput(RegexUtf16Input{
						units: units
					}) }
				match fields[0] {
					'find' { actual = if value := input.find_code_unit(a, b, u16(c)) {
							value.str()
						} else {
							'-'
						} }
					'next' { actual = if value := input.next_literal_start(a, u16(c)) {
							value.str()
						} else {
							'-'
						} }
					'at' { actual = if input.matches_u16_at(a, regex_core_fixture_units(fields[6])!) {
							'1'
						} else {
							'0'
						} }
					'ends' { actual = if input.ends_with_u16(regex_core_fixture_units(fields[6])!) {
							'1'
						} else {
							'0'
						} }
					'equal' { actual = if input.ranges_equal(a, b, c) { '1' } else { '0' } }
					'point' { actual = '${regex_decode_code_point(b != 0, input, a)},${regex_code_point_len(b != 0,
							input, a)}' }
					'unit' { actual = input.code_unit(a).str() }
					else { assert false, row }
				}
			}
		}

		assert actual == fields[7], row
		count++
	}
	assert count == 36166
}
