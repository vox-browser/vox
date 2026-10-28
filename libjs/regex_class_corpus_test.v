module libjs

fn C.uloc_getDefault() &char
fn C.uloc_setDefault(locale &char, status &i32)

fn regex_class_fixture_bit(value bool) string {
	return if value { '1' } else { '0' }
}

fn regex_class_fixture_ranges(text string, definitions [][]RegexCharRange) []RegexCharRange {
	if text.starts_with('@') { return definitions[text[1..].int()] }
	if text == '-' { return []RegexCharRange{} }
	mut ranges := []RegexCharRange{}
	for item in text.split(',') {
		parts := item.split(':')
		assert parts.len == 2
		ranges << RegexCharRange{
			start: u32(parts[0].parse_uint(10, 32) or { panic(err) })
			end:   u32(parts[1].parse_uint(10, 32) or { panic(err) })
		}
	}
	return ranges
}

fn regex_class_fixture_result(fields []string, definitions [][]RegexCharRange) string {
	point := u32(fields[1].parse_uint(10, 32) or { panic(err) })
	a := u32(fields[2].parse_uint(10, 32) or { panic(err) })
	b := u32(fields[3].parse_uint(10, 32) or { panic(err) })
	return match fields[0] {
		'closure' {
			mut output := []u32{len: int(a), init: 0xffffffff}
			count := regex_get_case_closure(point, mut output)
			'${count}|${output.map(it.str()).join(',')}'
		}
		'expand' {
			ranges := regex_expand_range_case_insensitive(a, b)
			if ranges.len == 0 {
				'-'
			} else {
				ranges.map('${it.start}:${it.end}').join(',')
			}
		}
		'inverse' {
			mut result := ''
			for unicode in [false, true] {
				result += regex_class_fixture_bit(regex_code_point_matches_range_ignoring_case(point,
					a, b, unicode))
			}
			result
		}
		'member' {
			regex_class_fixture_bit(regex_char_in_ranges(point, regex_class_fixture_ranges(fields[4],
				definitions)))
		}
		'class' {
			ranges := regex_class_fixture_ranges(fields[4], definitions)
			mut result := ''
			for flags in 0 .. 8 {
				result += regex_class_fixture_bit(regex_match_char_class(point, ranges,
					flags & 1 != 0, flags & 2 != 0, flags & 4 != 0))
			}
			result
		}
		'scan' {
			parts := fields[4].split('!')
			assert parts.len == 2
			scan := match parts[0] {
				'class' {
					RegexSimpleScan(RegexBytecodeCharClass{
						ranges:  regex_class_fixture_ranges(parts[1], definitions)
						negated: a != 0
					})
				}
				'builtin' {
					classes := [RegexBuiltinCharacterClass.digit, .non_digit, .word, .non_word,
						.whitespace, .non_whitespace]
					RegexSimpleScan(classes[int(a)])
				}
				'literal' {
					RegexSimpleScan(RegexLiteral{
						code_point: a
					})
				}
				'greedy' {
					RegexSimpleScan(RegexGreedyLoop{
						matcher: RegexLiteral{
							code_point: a
						}
					})
				}
				else {
					panic('Unknown regex scan variant ${parts[0]}')
				}
			}

			regex_class_fixture_bit(regex_match_simple_scan(scan, point))
		}
		else {
			panic('Unknown regex class fixture ${fields[0]}')
		}
	}
}

fn test_regex_unicode_sets_classes_and_scans_match_every_native_output_exactly() {
	original := unsafe { cstring_to_vstring(C.uloc_getDefault()).clone() }
	defer {
		mut status := i32(0)
		C.uloc_setDefault(original.str, &status)
		assert status <= 0
	}
	mut status := i32(0)
	C.uloc_setDefault(c'en_US_POSIX', &status)
	assert status <= 0
	mut definitions := [][]RegexCharRange{}
	for line in $embed_file('testdata/regex-class-ranges.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue
		 }
		parts := line.split('\t')
		assert parts.len == 2 && parts[0].int() == definitions.len
		definitions << regex_class_fixture_ranges(parts[1], [][]RegexCharRange{})
	}
	assert definitions.len == 87
	fixtures := [$embed_file('testdata/regex-class.tsv').to_string(),
		$embed_file('testdata/regex-class-bmp.tsv').to_string(),
		$embed_file('testdata/regex-class-closure.tsv').to_string()]
	mut count := 0
	for fixture in fixtures {
		for line in fixture.split_into_lines() {
			if line == '' || line.starts_with('#') { continue
			 }
			fields := line.split('\t')
			assert fields.len == 6, line
			actual := regex_class_fixture_result(fields, definitions)
			assert actual == fields[5], '${line}\nactual: ${actual}'
			count++
		}
	}
	assert count == 255240
}
