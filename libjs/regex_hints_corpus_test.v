module libjs

fn regex_hint_fixture_units(text string) ![]u16 {
	mut units := []u16{}
	if text != '-' {
		assert text.len % 4 == 0
		for offset := 0; offset < text.len; offset += 4 {
			units << u16(text[offset..offset + 4].parse_uint(16, 16)!)
		}
	}
	return units
}

fn regex_hint_fixture_hex(units []u16) string {
	if units.len == 0 { return '-' }
	return units.map('${it:04x}').join('')
}

fn regex_hint_fixture_property() RegexUnicodePropertyData {
	return RegexUnicodePropertyData{
		negated:  true
		name:     'Script'
		value:    'Greek'
		resolved: RegexResolvedProperty{
			kind: .script
			id:   14
		}
	}
}

fn regex_hint_fixture_matcher(index u32) RegexSimpleMatch {
	return match index {
		0, 1 {
			RegexSimpleMatch(RegexAnyChar{
				dot_all: index == 1
			})
		}
		2 {
			RegexSimpleMatch(RegexLiteral{
				code_point: 97
			})
		}
		3 {
			RegexSimpleMatch(RegexCharNoCase{
				first:  97
				second: 65
			})
		}
		4, 5 {
			RegexSimpleMatch(RegexBytecodeCharClass{
				ranges:  [RegexCharRange{ start: 65, end: 90 }]
				negated: index == 5
			})
		}
		6 {
			RegexSimpleMatch(RegexBuiltinCharacterClass.word)
		}
		7 {
			RegexSimpleMatch(regex_hint_fixture_property())
		}
		8 {
			RegexSimpleMatch(RegexSimpleUnion{
				left:  box_regex_simple_match(regex_hint_fixture_matcher(4))
				right: box_regex_simple_match(RegexSimpleUnion{
					left:  box_regex_simple_match(regex_hint_fixture_matcher(2))
					right: box_regex_simple_match(regex_hint_fixture_matcher(7))
				})
			})
		}
		9 {
			RegexSimpleMatch(RegexBuiltinCharacterClass.non_whitespace)
		}
		else {
			panic('Unknown fixture matcher ${index}')
		}
	}
}

fn regex_hint_fixture_number(fields []string, index int) u32 {
	return u32(fields[index].parse_uint(10, 32) or { panic(err) })
}

fn regex_hint_fixture_maximum(fields []string, index int) ?u32 {
	if fields[index] == '-' { return none }
	return regex_hint_fixture_number(fields, index)
}

fn regex_hint_fixture_instruction(text string) RegexInstruction {
	f := text.split(',')
	n := fn [f] (index int) u32 {
		return regex_hint_fixture_number(f, index)
	}
	match f[0] {
		'c' {
			return RegexLiteral{
				code_point: n(1)
			}
		}
		'i' {
			return RegexCharNoCase{
				first:  n(1)
				second: n(2)
			}
		}
		'a' {
			return RegexAnyChar{
				dot_all: n(1) != 0
			}
		}
		'h' {
			mut ranges := []RegexCharRange{}
			for j := 2; j < f.len; j += 2 {
				ranges << RegexCharRange{
					start: n(j)
					end:   n(j + 1)
				}
			}
			return RegexBytecodeCharClass{
				ranges:  ranges
				negated: n(1) != 0
			}
		}
		'b' {
			return unsafe { RegexBuiltinCharacterClass(n(1)) }
		}
		'u' {
			return regex_hint_fixture_property()
		}
		'j' {
			return RegexJump{
				target: n(1)
			}
		}
		'x' {
			return RegexSplit{
				prefer: n(1)
				other:  n(2)
			}
		}
		's' {
			return RegexSave{
				reg: n(1)
			}
		}
		'e' {
			return RegexClearRegister{
				reg: n(1)
			}
		}
		'^' {
			return RegexAssertStart{
				multiline: n(1) != 0
			}
		}
		'$' {
			return RegexAssertEnd{
				multiline: n(1) != 0
			}
		}
		'w' {
			return RegexAssertWordBoundary{}
		}
		'W' {
			return RegexAssertNonWordBoundary{}
		}
		'M' {
			return RegexMatch{}
		}
		'F' {
			return RegexFail{}
		}
		'B' {
			return RegexIndexedBackreference{
				index: n(1)
			}
		}
		'N' {
			return RegexNamedBackreference{
				name: 'named'
			}
		}
		'r' {
			return RegexRepeatStart{
				counter_reg: n(1)
			}
		}
		'R' {
			return RegexRepeatCheck{
				counter_reg: n(1)
				min:         n(2)
				max:         regex_hint_fixture_maximum(f, 3)
				body:        n(4)
				greedy:      n(5) != 0
			}
		}
		'l' {
			return RegexLookStart{
				positive: n(1) != 0
				forward:  n(2) != 0
				end:      n(3)
			}
		}
		'L' {
			return RegexLookEnd{}
		}
		'p' {
			return RegexPushModifiers{
				ignore_case: false
				multiline:   none
				dot_all:     true
			}
		}
		'P' {
			return RegexPopModifiers{}
		}
		'n' {
			return RegexNop{}
		}
		't' {
			return RegexStringPropertyMatch{
				strings:  [u32(2), 97, 98, 1, 97]
				property: regex_hint_fixture_property()
			}
		}
		'k' {
			return RegexProgressCheck{
				reg:            n(1)
				clear_captures: [u32(2), 3]
			}
		}
		'g' {
			return RegexGreedyLoop{
				matcher: regex_hint_fixture_matcher(n(1))
				min:     n(2)
				max:     regex_hint_fixture_maximum(f, 3)
			}
		}
		'G' {
			return RegexLazyLoop{
				matcher: regex_hint_fixture_matcher(n(1))
				min:     n(2)
				max:     regex_hint_fixture_maximum(f, 3)
			}
		}
		else {
			panic('Unknown fixture instruction ${text}')
		}
	}
}

fn regex_hint_fixture_program(text string, flags u32) RegexProgram {
	mut p := RegexProgram.new()
	if text != '-' {
		for instruction in text.split(';') {
			p.instructions << regex_hint_fixture_instruction(instruction)
		}
	}
	p.unicode = flags & 1 != 0
	p.ignore_case = flags & 2 != 0
	p.multiline = flags & 4 != 0
	p.unicode_sets = flags & 8 != 0
	p.dot_all = flags & 16 != 0
	return p
}

fn regex_hint_fixture_bit(value bool) string {
	return if value { '1' } else { '0' }
}

fn regex_hint_fixture_matcher_text(matcher RegexSimpleMatch) string {
	return match matcher {
		RegexAnyChar {
			'a:' + regex_hint_fixture_bit(matcher.dot_all)
		}
		RegexLiteral {
			'c:${matcher.code_point}'
		}
		RegexCharNoCase {
			'i:${matcher.first}:${matcher.second}'
		}
		RegexBuiltinCharacterClass {
			'b:${int(matcher)}'
		}
		RegexBytecodeCharClass {
			'h:' + regex_hint_fixture_bit(matcher.negated) + ':' +
				matcher.ranges.map('${it.start}-${it.end}').join('/')
		}
		RegexUnicodePropertyData {
			resolved := matcher.resolved or { panic('Missing fixture property') }
			value := matcher.value or { '-' }
			'u:' + regex_hint_fixture_bit(matcher.negated) +
				':${matcher.name}:${value}:${int(resolved.kind)}:${resolved.id}'
		}
		RegexSimpleUnion {
			'(' + regex_hint_fixture_matcher_text(*matcher.left) + '+' +
				regex_hint_fixture_matcher_text(*matcher.right) + ')'
		}
	}
}

fn regex_hint_fixture_scan_text(scan RegexSimpleScan) string {
	return match scan {
		RegexBytecodeCharClass {
			regex_hint_fixture_matcher_text(RegexSimpleMatch(scan))
		}
		RegexBuiltinCharacterClass {
			regex_hint_fixture_matcher_text(RegexSimpleMatch(scan))
		}
		RegexLiteral {
			regex_hint_fixture_matcher_text(RegexSimpleMatch(scan))
		}
		RegexGreedyLoop {
			maximum := if value := scan.max { value.str() } else { '-' }
			'g:' + regex_hint_fixture_matcher_text(scan.matcher) + ':${scan.min}:${maximum}'
		}
	}
}

fn regex_hint_fixture_hint_text(h RegexPatternHints) string {
	first := if value := h.first_char {
		'${value.code_point}:' + regex_hint_fixture_bit(value.case_insensitive)
	} else {
		'-'
	}
	filter := if value := h.first_filter { regex_hint_fixture_matcher_text(value) } else { '-' }
	start := if value := h.start_position_hint {
		regex_hint_fixture_bit(value.includes_input_start) + ':' +
			regex_hint_fixture_hex(value.literal_code_units)
	} else {
		'none'
	}
	tail := if value := h.trailing_literal { regex_hint_fixture_hex(value) } else { 'none' }
	required := if value := h.required_literal {
		regex_hint_fixture_bit(value.ascii_case_insensitive) + ':' +
			regex_hint_fixture_hex(value.literal)
	} else {
		'none'
	}
	scan := if value := h.simple_scan { regex_hint_fixture_scan_text(value) } else { '-' }
	return [first, filter, start, regex_hint_fixture_bit(h.starts_with_anchor),
		regex_hint_fixture_bit(h.anchor_multiline), tail, required, scan,
		regex_hint_fixture_bit(h.can_match_empty)].join('|')
}

fn test_regex_hints_and_prefilters_match_current_upstream_rust_exactly() {
	corpus := $embed_file('testdata/regex-hints.tsv').to_string() +
		$embed_file('testdata/regex-hints-fold.tsv').to_string()
	mut count := 0
	for row in corpus.split_into_lines() {
		if row.len == 0 || row.starts_with('#') { continue
		 }
		f := row.split('\t')
		assert f.len == 8, row
		a := uint(f[3].parse_uint(10, 64)!)
		b := uint(f[4].parse_uint(10, 64)!)
		mut actual := ''
		match f[0] {
			'analyze' {
				p := regex_hint_fixture_program(f[2], u32(f[1].parse_uint(10, 32)!))
				mut ast := ?RegexRequiredLiteralHint(none)
				if f[6] != 'none' { ast = RegexRequiredLiteralHint{
						literal:                regex_hint_fixture_units(f[6])!
						ascii_case_insensitive: b != 0
					} }
				actual = regex_hint_fixture_hint_text(regex_analyze_pattern(p, a != 0, ast))
			}
			'suffix' {
				p := regex_hint_fixture_program(f[2], 0)
				actual = if value := regex_extract_trailing_literal(p.instructions, a) {
					regex_hint_fixture_hex(value)
				} else {
					'none'
				}
			}
			'linear' {
				p := regex_hint_fixture_program(f[2], 0)
				actual = regex_hint_fixture_bit(regex_suffix_has_linear_tail(p.instructions, a))
			}
			'successors' {
				mut out := &[]uint{}
				regex_for_each_successor(regex_hint_fixture_instruction(f[2]), a, b, fn [mut out] (successor uint) {
					out << successor
				})
				actual = if out.len == 0 { '-' } else { out.map(it.str()).join(',') }
			}
			'fold' {
				actual = regex_fold_ascii_for_compare(u16(a)).str()
			}
			else {
				units := regex_hint_fixture_units(f[2])!
				input := if f[1] == 'u8' { RegexInput(RegexAsciiInput{
						bytes: units.map(u8(it))
					}) } else { RegexInput(RegexUtf16Input{
						units: units
					}) }
				if f[0] == 'reject' {
					parts := f[6].split(':')
					mut hints := RegexPatternHints{}
					if parts[0] != 'none' {
						hints.trailing_literal = regex_hint_fixture_units(parts[0])!
					}
					if parts[1] != 'none' { hints.required_literal = RegexRequiredLiteralHint{
							literal:                regex_hint_fixture_units(parts[1])!
							ascii_case_insensitive: b != 0
						} }
					actual =
						regex_hint_fixture_bit(regex_fails_trailing_literal_hint(input, hints)) +
						',' +
						regex_hint_fixture_bit(regex_fails_required_literal_hint(input, a, hints))
				} else {
					needle := regex_hint_fixture_units(f[6])!
					match f[0] {
						'contains' {
							actual = regex_hint_fixture_bit(regex_contains_u16_from(input, a,
								needle))
						}
						'contains_i' {
							actual = regex_hint_fixture_bit(regex_contains_ascii_case_insensitive_u16_from(input,
								a, needle))
						}
						'at_i' {
							actual = regex_hint_fixture_bit(regex_matches_ascii_case_insensitive_u16_at(input,
								a, needle))
						}
						'start_scan' {
							actual = if value := regex_next_literal_start_from_hint(input, a, RegexStartPositionHint{
								includes_input_start: b != 0
								literal_code_units:   needle
							})
							{
								value.str()
							} else {
								'-'
							}
						}
						else {
							panic(row)
						}
					}
				}
			}
		}

		assert actual == f[7], row
		count++
	}
	assert count == 112458
}
