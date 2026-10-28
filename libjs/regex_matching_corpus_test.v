module libjs

fn C.uloc_getDefault() &char
fn C.uloc_setDefault(locale &char, status &i32)

fn regex_matching_fixture_units(text string) []u16 {
	if text == '-' { return []u16{} }
	mut result := []u16{cap: text.len / 4}
	for index := 0; index < text.len; index += 4 {
		result << u16(text[index..index + 4].parse_uint(16, 16) or { panic(err) })
	}
	return result
}

fn regex_matching_fixture_registers(text string) []i32 {
	if text == '-' { return []i32{} }
	return text.split(',').map(i32(it.parse_int(10, 32) or { panic(err) }))
}

fn regex_matching_fixture_bit(value bool) string {
	return if value { '1' } else { '0' }
}

fn regex_matching_fixture_fold(point u32) string {
	classes := [RegexBuiltinCharacterClass.digit, .non_digit, .word, .non_word, .whitespace,
		.non_whitespace]
	mut sets := []string{}
	for flag in [false, true] {
		mut bits := ''
		for class in classes {
			bits += regex_matching_fixture_bit(regex_match_builtin_class(point, class, flag))
		}
		sets << bits
	}
	return '${regex_case_fold(point, false)}|${regex_case_fold(point, true)}|${regex_matching_fixture_bit(regex_is_word_char_unicode(point,
		false))}|${regex_matching_fixture_bit(regex_is_word_char_unicode(point, true))}|${sets[0]}|${sets[1]}'
}

fn regex_matching_fixture_result(fields []string) string {
	operation := fields[0]
	a := u32(fields[3].parse_uint(10, 32) or { panic(err) })
	b := uint(fields[4].parse_uint(10, 64) or { panic(err) })
	c := u32(fields[5].parse_uint(10, 32) or { panic(err) })
	if operation == 'fold' { return regex_matching_fixture_fold(a) }
	if operation == 'eq' { return regex_matching_fixture_bit(regex_case_fold_eq(a, u32(b), c != 0)) }
	flags := u32(fields[1].split(':')[1].parse_uint(10, 32) or { panic(err) })
	units := regex_matching_fixture_units(fields[2])
	input := if fields[1].starts_with('u8:') {
		assert units.all(it <= 255)
		RegexInput(RegexAsciiInput{
			bytes: units.map(u8(it))
		})
	} else {
		RegexInput(RegexUtf16Input{
			units: units
		})
	}
	mut registers := []i32{}
	mut groups := []RegexNamedGroupEntry{}
	mut name := ''
	if operation == 'backref' { registers = regex_matching_fixture_registers(fields[6]) }
	if operation == 'named' {
		parts := fields[6].split('!')
		assert parts.len == 3
		registers = regex_matching_fixture_registers(parts[1])
		name = parts[2]
		if parts[0] != '-' {
			for group in parts[0].split(',') {
				entry := group.split(':')
				groups << RegexNamedGroupEntry{
					name:  entry[0]
					index: u32(entry[1].parse_uint(10, 32) or { panic(err) })
				}
			}
		}
	}
	program := &RegexProgram{
		register_count: u32(registers.len)
		unicode:        flags & 1 != 0
		ignore_case:    flags & 2 != 0
		named_groups:   groups
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, input, b, mut scratch)
	for index, value in registers {
		scratch.registers[index] = value
	}
	vm.backward = c != 0
	matched := match operation {
		'char' { vm.match_char(a) }
		'boundary' { vm.at_word_boundary() }
		'backref' { vm.match_backref(a) }
		'named' { vm.match_backref_named(name) }
		else { panic('Unknown regex matching fixture ${operation}') }
	}

	return '${regex_matching_fixture_bit(matched)}|${vm.pos}'
}

fn test_regex_matching_helpers_match_every_native_output_exactly() {
	original := unsafe { cstring_to_vstring(C.uloc_getDefault()).clone() }
	defer {
		mut status := i32(0)
		C.uloc_setDefault(original.str, &status)
		assert status <= 0
	}
	mut status := i32(0)
	C.uloc_setDefault(c'en_US_POSIX', &status)
	assert status <= 0
	fixtures := [$embed_file('testdata/regex-matching.tsv').to_string(),
		$embed_file('testdata/regex-matching-fold.tsv').to_string()]
	mut count := 0
	for fixture in fixtures {
		for line in fixture.split_into_lines() {
			if line == '' || line.starts_with('#') { continue
			 }
			fields := line.split('\t')
			assert fields.len == 8, line
			actual := regex_matching_fixture_result(fields)
			assert actual == fields[7], '${line}\nactual: ${actual}'
			count++
		}
	}
	assert count == 113204
}
