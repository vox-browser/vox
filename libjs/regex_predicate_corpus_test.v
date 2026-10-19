module libjs

fn regex_predicate_fixture_bit(value bool) u32 {
	return if value { u32(1) } else { u32(0) }
}

fn regex_predicate_fixture_matchers() []RegexSimpleMatch {
	mut matchers := []RegexSimpleMatch{}
	for line in $embed_file('testdata/regex-predicates-matchers.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue
		 }
		row := line.split('\t')
		assert row.len == 2 && row[0].int() == matchers.len
		fields := row[1].split(':')
		matcher := match fields[0] {
			'any' {
				RegexSimpleMatch(RegexAnyChar{
					dot_all: fields[1] == '1'
				})
			}
			'literal' {
				RegexSimpleMatch(RegexLiteral{
					code_point: fields[1].u32()
				})
			}
			'nocase' {
				RegexSimpleMatch(RegexCharNoCase{
					first:  fields[1].u32()
					second: fields[2].u32()
				})
			}
			'class' {
				RegexSimpleMatch(RegexBytecodeCharClass{
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
				RegexSimpleMatch(RegexBuiltinCharacterClass.from_string(['digit', 'non_digit',
					'word', 'non_word', 'whitespace', 'non_whitespace'][fields[1].int()]) or {
					panic('unknown builtin character class')
				})
			}
			'property' {
				value := if fields[3] == '-' {
					?string(none)
				} else if fields[3] == '<empty>' {
					?string('')
				} else {
					?string(fields[3])
				}
				resolved := if fields[4] == '-' {
					?RegexResolvedProperty(none)
				} else {
					regex_resolve_property(fields[4], none)
				}
				RegexSimpleMatch(RegexUnicodePropertyData{
					name:     fields[2]
					value:    value
					resolved: resolved
					negated:  fields[1] == '1'
				})
			}
			'union' {
				RegexSimpleMatch(RegexSimpleUnion{
					left:  box_regex_simple_match(matchers[fields[1].int()].clone())
					right: box_regex_simple_match(matchers[fields[2].int()].clone())
				})
			}
			else {
				panic('unknown native predicate matcher')
			}
		}

		matchers << matcher
	}
	assert matchers.len == 37
	return matchers
}

fn regex_predicate_fixture_hints(index u32, matchers []RegexSimpleMatch) RegexPatternHints {
	return match index {
		0 {
			RegexPatternHints{}
		}
		1 {
			RegexPatternHints{
				can_match_empty: true
			}
		}
		2 {
			RegexPatternHints{
				starts_with_anchor: true
			}
		}
		3 {
			RegexPatternHints{
				starts_with_anchor: true
				can_match_empty:    true
				anchor_multiline:   true
			}
		}
		4 {
			RegexPatternHints{
				first_char: RegexFirstChar{
					code_point: 65
				}
			}
		}
		5 {
			RegexPatternHints{
				first_char: RegexFirstChar{
					code_point:       65
					case_insensitive: true
				}
			}
		}
		6 {
			RegexPatternHints{
				first_char: RegexFirstChar{
					code_point: 0x10400
				}
			}
		}
		7 {
			RegexPatternHints{
				first_filter: matchers[6]
			}
		}
		8 {
			RegexPatternHints{
				first_filter: matchers[0]
			}
		}
		9 {
			RegexPatternHints{
				first_filter: matchers[15]
			}
		}
		10 {
			RegexPatternHints{
				first_filter: matchers[21]
			}
		}
		11 {
			RegexPatternHints{
				first_filter: matchers[22]
			}
		}
		12 {
			RegexPatternHints{
				starts_with_anchor: true
				first_char:         RegexFirstChar{
					code_point:       65
					case_insensitive: true
				}
				first_filter:       matchers[17]
			}
		}
		13 {
			RegexPatternHints{
				starts_with_anchor: true
				first_filter:       matchers[33]
			}
		}
		14 {
			RegexPatternHints{
				trailing_literal: [u16(0x7a), 0x7a]
				required_literal: RegexRequiredLiteralHint{
					literal: [u16(0x7a)]
				}
			}
		}
		15 {
			RegexPatternHints{
				first_char:      RegexFirstChar{
					code_point:       0x10400
					case_insensitive: true
				}
				first_filter:    matchers[15]
				can_match_empty: true
			}
		}
		16 {
			RegexPatternHints{
				first_filter:    matchers[6]
				can_match_empty: true
			}
		}
		17 {
			RegexPatternHints{
				first_char:         RegexFirstChar{
					code_point: 10
				}
				first_filter:       matchers[1]
				starts_with_anchor: true
			}
		}
		else {
			panic('unknown native candidate hints')
		}
	}
}

fn regex_predicate_fixture_set_program(mut program RegexProgram, flags u32) {
	program.unicode = flags & 1 != 0
	program.unicode_sets = flags & 2 != 0
	program.ignore_case = flags & 4 != 0
	program.dot_all = flags & 8 != 0
}

fn regex_predicate_fixture_input(text string) RegexInput {
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

fn regex_predicate_fixture_simple_bits(point u32, matcher RegexSimpleMatch, mut program RegexProgram, mut vm RegexVm) string {
	raw := regex_predicate_fixture_bit(regex_match_simple_match(matcher, point))
	mut modifier_bits := u32(0)
	mut vm_bits := u32(0)
	mut first_bits := u32(0)
	for flag in 0 .. 4 {
		modifiers := RegexActiveModifiers{
			ignore_case: flag & 1 != 0
			multiline:   flag & 1 == 0
			dot_all:     flag & 2 != 0
		}
		modifier_bits |= regex_predicate_fixture_bit(regex_match_simple_with_modifiers(matcher,
			point, modifiers)) << flag
	}
	units := if point < 0x10000 { [u16(point)] } else { [
			u16(0xd800 + ((point - 0x10000) >> 10)),
			u16(0xdc00 + ((point - 0x10000) & 1023)),
		] }
	input := RegexInput(RegexUtf16Input{
		units: units
	})
	for flag in 0 .. 16 {
		regex_predicate_fixture_set_program(mut program, u32(flag))
		first_bits |= regex_predicate_fixture_bit(regex_first_filter_matches(program, input, 0,
			matcher)) << flag
		vm.modifiers = RegexActiveModifiers{
			ignore_case: flag & 4 != 0
			multiline:   flag & 4 == 0
			dot_all:     flag & 8 != 0
		}
		vm_bits |= regex_predicate_fixture_bit(vm.match_simple(point, matcher)) << flag
		assert vm.pos == 7 && vm.pc == 0 && vm.steps == 13
	}
	return '${raw}|${modifier_bits:x}|${vm_bits:04x}|${first_bits:04x}'
}

fn test_regex_simple_predicates_and_candidate_filters_match_exact_native_corpus() {
	matchers := regex_predicate_fixture_matchers()
	mut program := &RegexProgram{}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexUtf16Input{}, 7, mut scratch)
	vm.steps = 13
	mut count := 0
	for corpus in [$embed_file('testdata/regex-predicates-1.tsv').to_string(),
		$embed_file('testdata/regex-predicates-2.tsv').to_string(),
		$embed_file('testdata/regex-predicates-candidate.tsv').to_string(),
		$embed_file('testdata/regex-predicates-first-1.tsv').to_string(),
		$embed_file('testdata/regex-predicates-first-2.tsv').to_string()] {
		for line in corpus.split_into_lines() {
			if line == '' || line.starts_with('#') { continue
			 }
			fields := line.split('\t')
			assert fields.len == 6
			point := fields[1].u32()
			a := fields[2].u64()
			b := fields[3].u32()
			mut actual := ''
			match fields[0] {
				'simple' {
					actual = regex_predicate_fixture_simple_bits(point, matchers[int(a)], mut
						program, mut vm)
				}
				'first', 'candidate' {
					regex_predicate_fixture_set_program(mut program, point)
					input := regex_predicate_fixture_input(fields[4])
					if fields[0] == 'first' {
						actual = regex_predicate_fixture_bit(regex_first_char_matches(program,
							input, usize(a), b, point & 16 != 0)).str()
					} else if pos := regex_next_candidate_start(program, input, regex_predicate_fixture_hints(b,
						matchers), usize(a))
					{
						actual = pos.str()
					} else {
						actual = '-'
					}
				}
				else {
					panic('unknown native predicate operation')
				}
			}

			assert actual == fields[5], '${line}: actual=${actual}'
			count++
		}
	}
	assert count == 389048
}
