module libjs

// These IDs are the supplied matcher records in libjs_regex_predicate_corpus.py.
// Only the source scan helpers execute them; no pattern parser is substituted.
fn regex_scan_fixture_matcher(index int) RegexSimpleMatch {
	return match index {
		0, 1 {
			RegexSimpleMatch(RegexAnyChar{
				dot_all: index == 1
			})
		}
		3 {
			RegexSimpleMatch(RegexLiteral{
				code_point: 83
			})
		}
		5 {
			RegexSimpleMatch(RegexLiteral{
				code_point: 0x10400
			})
		}
		8 {
			RegexSimpleMatch(RegexCharNoCase{
				first:  83
				second: 383
			})
		}
		11 {
			RegexSimpleMatch(RegexBytecodeCharClass{
				ranges: [RegexCharRange{ start: 65, end: 90 }]
			})
		}
		15 {
			RegexSimpleMatch(RegexBuiltinCharacterClass.word)
		}
		17 {
			RegexSimpleMatch(RegexBuiltinCharacterClass.digit)
		}
		21, 22 {
			RegexSimpleMatch(RegexUnicodePropertyData{
				name:    'Lowercase'
				negated: index == 22
			})
		}
		25 {
			RegexSimpleMatch(RegexUnicodePropertyData{
				name:  'Script'
				value: 'Greek'
			})
		}
		26 {
			RegexSimpleMatch(RegexUnicodePropertyData{
				name:    'scx'
				value:   'Hira'
				negated: true
			})
		}
		28 {
			RegexSimpleMatch(RegexUnicodePropertyData{
				name:     'unknown'
				value:    ''
				resolved: regex_resolve_property('ASCII', none)
			})
		}
		33, 34, 35, 36 {
			left := match index {
				33 { 3 }
				34 { 21 }
				35 { 33 }
				else { 34 }
			}

			right := match index {
				33 { 17 }
				34 { 22 }
				35 { 26 }
				else { 35 }
			}

			RegexSimpleMatch(RegexSimpleUnion{
				left:  box_regex_simple_match(regex_scan_fixture_matcher(left))
				right: box_regex_simple_match(regex_scan_fixture_matcher(right))
			})
		}
		else {
			panic('unknown native scan matcher fixture')
		}
	}
}

fn regex_scan_fixture_scanners() []RegexSimpleScan {
	mut scans := []RegexSimpleScan{}
	for line in $embed_file('testdata/regex-scans-scanners.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue
		 }
		row := line.split('\t')
		assert row.len == 2 && row[0].int() == scans.len
		fields := row[1].split(':')
		scan := match fields[0] {
			'literal' {
				RegexSimpleScan(RegexLiteral{
					code_point: fields[1].u32()
				})
			}
			'class' {
				RegexSimpleScan(RegexBytecodeCharClass{
					ranges:  [
						RegexCharRange{
							start: fields[2].u32()
							end:   fields[3].u32()
						},
					]
					negated: fields[1] == '1'
				})
			}
			'builtin' {
				RegexSimpleScan(RegexBuiltinCharacterClass.from_string([
					'digit',
					'non_digit',
					'word',
					'non_word',
					'whitespace',
					'non_whitespace',
				][fields[1].int()]) or { panic('unknown builtin character class') })
			}
			'greedy' {
				RegexSimpleScan(RegexGreedyLoop{
					matcher: regex_scan_fixture_matcher(fields[1].int())
					min:     fields[2].u32()
					max:     if fields[3] == '-' { ?u32(none) } else { ?u32(fields[3].u32()) }
				})
			}
			else {
				panic('unknown native scanner fixture')
			}
		}

		scans << scan
	}
	assert scans.len == 27
	return scans
}

fn regex_scan_fixture_input(text string) RegexInput {
	fields := text.split('!')
	assert fields.len == 2
	mut units := []u16{}
	if fields[1] != '-' {
		for unit in fields[1].split(',') {
			units << u16(unit.u32())
		}
	}
	if fields[0] == 'u' { return RegexUtf16Input{
			units: units
		} }
	assert fields[0] == 'a'
	mut bytes := []u8{cap: units.len}
	for unit in units {
		assert unit <= 255
		bytes << u8(unit)
	}
	return RegexAsciiInput{
		bytes: bytes
	}
}

fn regex_scan_fixture_text(program RegexProgram, input RegexInput, start usize, scan RegexSimpleScan) string {
	mut output := [i32(91), 92, 93, 94, 95]
	matched := regex_execute_simple_scan_into(program, input, start, scan, mut output)
	if scan is RegexGreedyLoop {
		mut direct := [i32(91), 92, 93, 94, 95]
		assert matched == regex_execute_simple_greedy_scan_into(program, input, start,
			scan.matcher, scan.min, scan.max, mut direct)
		assert output == direct
	}
	bit := if matched { 1 } else { 0 }
	mut parts := ['${bit}!${output.map(it.str()).join(',')}']
	for capacity in [0, 1, 2, 3, 4, 5, 8, 12] {
		mut all := []i32{len: capacity, init: 91}
		count := regex_find_all_simple_scan(program, input, start, scan, mut all)
		parts << '${count}!${all.map(it.str()).join(',')}'
	}
	return parts.join('|')
}

fn test_regex_simple_and_greedy_scan_execution_matches_exact_native_corpus() {
	scans := regex_scan_fixture_scanners()
	mut count := 0
	for corpus in [$embed_file('testdata/regex-scans-1.tsv').to_string(),
		$embed_file('testdata/regex-scans-2.tsv').to_string()] {
		for line in corpus.split_into_lines() {
			if line == '' || line.starts_with('#') { continue
			 }
			fields := line.split('\t')
			assert fields.len == 6 && fields[0] == 'scan'
			flags := fields[1].u32()
			program := RegexProgram{
				unicode:      flags & 1 != 0
				unicode_sets: flags & 2 != 0
				ignore_case:  flags & 4 != 0
				dot_all:      flags & 8 != 0
			}
			input := regex_scan_fixture_input(fields[4])
			actual := regex_scan_fixture_text(program, input, usize(fields[2].u64()),
				scans[fields[3].int()])
			assert actual == fields[5], '${line}: actual=${actual}'
			count++
		}
	}
	assert count == 32481
}
