module libjs

fn regex_backtrack_fixture_bit(value bool) u32 {
	return if value { u32(1) } else { u32(0) }
}

fn regex_backtrack_fixture_active(flags u32) RegexActiveModifiers {
	return RegexActiveModifiers{
		ignore_case: flags & 4 != 0
		multiline:   flags & 16 != 0
		dot_all:     flags & 8 != 0
	}
}

fn regex_backtrack_fixture_program(flags u32, matcher RegexSimpleMatch, variant u32, minimum u32) &RegexProgram {
	mut instructions := [RegexInstruction(RegexGreedyLoop{ matcher: matcher.clone(), min: minimum })]
	match variant {
		0 { instructions << RegexNop{} }
		1 { instructions << RegexLiteral{ code_point: 65 } }
		2 { instructions << RegexLiteral{ code_point: 0x10400 } }
		3 { instructions << RegexLiteral{ code_point: 0xdc00 } }
		4 {
			instructions << RegexGreedyLoop{ matcher: matcher.clone(), min: 2 }
			instructions << RegexLazyLoop{ matcher: matcher.clone(), min: 1 }
			instructions << RegexNop{}
		}
		5 {
			instructions << RegexLazyLoop{ matcher: matcher.clone() }
			instructions << RegexNop{}
		}
		6 {
			instructions << RegexLazyLoop{ matcher: RegexLiteral{ code_point: 66 }, min: 3 }
			instructions << RegexNop{}
		}
		7 {
			instructions << RegexGreedyLoop{ matcher: matcher.clone(), min: u32(0xffffffff) }
			instructions << RegexLazyLoop{ matcher: matcher.clone(), min: 1 }
		}
		8 {
			instructions = [
				RegexInstruction(RegexLazyLoop{ matcher: matcher.clone() }),
				RegexNop{},
			]
		}
		9 { instructions = [RegexInstruction(RegexNop{})] }
		10 {
			instructions << RegexGreedyLoop{ matcher: matcher.clone(), min: 1 }
			instructions << RegexNop{}
		}
		11 {}
		12 { instructions << RegexLiteral{ code_point: 0x10041 } }
		else { panic('unknown native loop fixture') }
	}
	return &RegexProgram{
		instructions:   instructions
		register_count: 4
		unicode:        flags & 1 != 0
		unicode_sets:   flags & 2 != 0
		ignore_case:    flags & 4 != 0
		dot_all:        flags & 8 != 0
		multiline:      flags & 16 != 0
	}
}

fn regex_backtrack_fixture_modifier_text(modifiers RegexActiveModifiers) u32 {
	return regex_backtrack_fixture_bit(modifiers.ignore_case) | (regex_backtrack_fixture_bit(modifiers.multiline) << 1) | (regex_backtrack_fixture_bit(modifiers.dot_all) << 2)
}

fn regex_backtrack_fixture_state(vm RegexVm) string {
	mut scopes := []string{}
	for modifiers in vm.scratch.modifier_stack {
		scopes << regex_backtrack_fixture_modifier_text(modifiers).str()
	}
	mut stack := []string{}
	for state in vm.scratch.backtrack_stack {
		modifiers := regex_backtrack_fixture_modifier_text(state.modifiers)
		match state {
			RegexSavedNormal {
				stack << 'n,${state.pc},${state.pos},${state.reg_snapshot_offset},${modifiers},${state.modifier_stack_len}'
			}
			RegexSavedGreedy {
				backward := regex_backtrack_fixture_bit(state.backward)
				stack << 'g,${state.pc},${state.start_pos},${state.current_pos},${state.reg_snapshot_offset},${state.min},${backward},${modifiers},${state.modifier_stack_len}'
			}
			RegexSavedLazy {
				maximum := if value := state.max { value.str() } else { '-' }
				stack << 'l,${state.pc},${state.pos},${state.reg_snapshot_offset},${maximum},${state.consumed},${modifiers},${state.modifier_stack_len}'
			}
		}
	}
	return '${vm.pc},${vm.pos},${vm.steps},${regex_backtrack_fixture_modifier_text(vm.modifiers)},${regex_backtrack_fixture_bit(vm.backward)},${vm.bt_floor}!${vm.scratch.registers.map(it.str()).join(',')}!${vm.scratch.register_pool.map(it.str()).join(',')}!${scopes.join(',')}!${stack.join(';')}'
}

fn regex_backtrack_fixture_operation(row []string, matchers []RegexSimpleMatch) string {
	op := row[0]
	flags := row[1].u32()
	pos := uint(row[2].u64())
	arg := row[3]
	matcher := matchers[row[4].int()]
	input := regex_backtrack_fixture_input(row[5])
	if op == 'consume' {
		maximum := if arg == '-' { ?u32(none) } else { ?u32(arg.u32()) }
		count, end := regex_greedy_consume_fast(input, pos, matcher, regex_backtrack_fixture_active(flags), maximum)
		return '${count},${end}'
	}
	spec := arg.split(':')
	variant := if op == 'available' { u32(0) } else { spec[0].u32() }
	minimum := if op == 'backtrack' { spec[2].u32() } else { u32(0) }
	program := regex_backtrack_fixture_program(flags, matcher, variant, minimum)
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, input, pos, mut scratch)
	vm.modifiers = regex_backtrack_fixture_active(flags)
	vm.backward = flags & 32 != 0
	vm.pc = 99
	vm.steps = 13
	if op == 'available' {
		count := vm.count_available_same_matcher_chars(pos, matcher, arg.u32(), flags & 64 != 0)
		assert vm.pos == pos && vm.pc == 99 && vm.steps == 13 && vm.backward == (flags & 32 != 0)
		return count.str()
	}
	if op == 'suffix' {
		result := vm.same_matcher_loop_suffix_deficit(0, pos, flags & 64 != 0)
		assert vm.pos == pos && vm.pc == 99 && vm.steps == 13 && vm.backward == (flags & 32 != 0)
		return if value := result { value.str() } else { '-' }
	}
	assert op == 'backtrack'
	choice := spec[1].u32()
	maximum := if spec[3] == '-' { ?u32(none) } else { ?u32(spec[3].u32()) }
	consumed := spec[4].u32()
	scratch.registers = [i32(11), 12, 13, 14]
	vm.push_backtrack(77, pos)
	vm.handle_push_modifiers(flags & 4 == 0, flags & 16 == 0, flags & 8 == 0)
	scratch.registers = [i32(21), 22, 23, 24]
	match choice {
		0 { vm.push_backtrack(55, pos) }
		1, 2 {
			vm.backward = choice == 2
			vm.push_greedy_backtrack(0, if choice == 2 { input.len() } else { uint(0) }, pos, minimum)
		}
		3 { vm.push_lazy_backtrack(0, pos, maximum, consumed) }
		else { panic('unknown native saved choice') }
	}
	vm.handle_push_modifiers(flags & 4 != 0, flags & 16 != 0, flags & 8 != 0)
	scratch.registers = [i32(31), 32, 33, 34]
	vm.pc = 99
	vm.pos = pos
	vm.steps = 13
	vm.backward = flags & 32 != 0
	vm.bt_floor = uint(spec[5].u64())
	mut trace := [regex_backtrack_fixture_state(vm)]
	for _ in 0 .. spec[6].u32() {
		result := vm.backtrack()
		trace << '${regex_backtrack_fixture_bit(result)}~${regex_backtrack_fixture_state(vm)}'
	}
	return trace.join('|')
}

fn test_regex_loop_and_backtrack_state_matches_unchanged_native_rust_exactly() {
	matchers := regex_backtrack_fixture_matchers()
	mut counts := map[string]int{}
	for corpus in [
		$embed_file('testdata/regex-backtracking-consume.tsv').to_string(),
		$embed_file('testdata/regex-backtracking-available-1.tsv').to_string(),
		$embed_file('testdata/regex-backtracking-available-2.tsv').to_string(),
		$embed_file('testdata/regex-backtracking-suffix.tsv').to_string(),
		$embed_file('testdata/regex-backtracking-backtrack.tsv').to_string(),
	] {
		for line in corpus.split_into_lines() {
			if line == '' || line.starts_with('#') { continue }
			row := line.split('\t')
			assert row.len == 7
			actual := regex_backtrack_fixture_operation(row, matchers)
			assert actual == row[6], '${line}\nactual: ${actual}'
			counts[row[0]]++
		}
	}
	assert counts == {
		'consume':   73632
		'available': 165672
		'suffix':    110448
		'backtrack': 6802
	}
}

fn regex_backtrack_fixture_matchers() []RegexSimpleMatch {
	mut matchers := []RegexSimpleMatch{}
	for line in $embed_file('testdata/regex-backtracking-matchers.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') {
			continue
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
	assert matchers.len == 39
	return matchers
}

fn regex_backtrack_fixture_input(text string) RegexInput {
	fields := text.split('!')
	assert fields.len == 2
	mut units := []u16{}
	if fields[1] != '-' {
		for unit in fields[1].split(',') {
			units << u16(unit.u32())
		}
	}
	if fields[0] == 'u' {
		return RegexUtf16Input{
			units: units
		}
	}
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
