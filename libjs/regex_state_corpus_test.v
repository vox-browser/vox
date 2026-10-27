module libjs

// Fixture argument codecs match the native oracle's input schema; every state
// and helper output is compared without overrides.
fn regex_state_fixture_ints(values []i32) string {
	return if values.len == 0 { '-' } else { values.map(it.str()).join(',') }
}

fn regex_state_fixture_mods(modifiers RegexActiveModifiers) u32 {
	mut flags := u32(0)
	if modifiers.ignore_case { flags |= 1 }
	if modifiers.multiline { flags |= 2 }
	if modifiers.dot_all { flags |= 4 }
	return flags
}

fn regex_state_fixture_saved(saved RegexSavedState) string {
	return match saved {
		RegexSavedNormal {
			'n:${saved.pc}:${saved.pos}:${saved.reg_snapshot_offset}:${regex_state_fixture_mods(saved.modifiers)}:${saved.modifier_stack_len}'
		}
		RegexSavedGreedy {
			'g:${saved.pc}:${saved.start_pos}:${saved.current_pos}:${saved.reg_snapshot_offset}:${saved.min}:' + (if saved.backward {
				'1'
			} else {
				'0'
			}) + ':${regex_state_fixture_mods(saved.modifiers)}:${saved.modifier_stack_len}'
		}
		RegexSavedLazy {
			maximum := if value := saved.max { value.str() } else { '-' }
			'l:${saved.pc}:${saved.pos}:${saved.reg_snapshot_offset}:${maximum}:${saved.consumed}:${regex_state_fixture_mods(saved.modifiers)}:${saved.modifier_stack_len}'
		}
	}
}

fn regex_state_fixture_text(vm RegexVm) string {
	choices := if vm.scratch.backtrack_stack.len == 0 {
		'-'
	} else {
		vm.scratch.backtrack_stack.map(regex_state_fixture_saved(it)).join('/')
	}
	modifiers := if vm.scratch.modifier_stack.len == 0 {
		'-'
	} else {
		vm.scratch.modifier_stack.map(regex_state_fixture_mods(it).str()).join(',')
	}
	backward := if vm.backward { '1' } else { '0' }
	return '${vm.pc}|${vm.pos}|${vm.steps}|${regex_state_fixture_mods(vm.modifiers)}|${backward}|${vm.bt_floor}|${vm.input_len()}|${regex_state_fixture_ints(vm.scratch.registers)}|${regex_state_fixture_ints(vm.scratch.register_pool)}|${choices}|${modifiers}'
}

fn regex_state_fixture_number(fields []string, index int) u64 {
	return fields[index].parse_uint(10, 64) or { panic(err) }
}

fn regex_state_fixture_signed(text string) i32 {
	return i32(text.parse_int(10, 32) or { panic(err) })
}

fn regex_state_fixture_bool(text string) ?bool {
	if text == '-' { return none }
	return text == '1'
}

fn regex_state_fixture_max(text string) ?u32 {
	if text == '-' { return none }
	return u32(text.parse_uint(10, 32) or { panic(err) })
}

fn regex_state_fixture_program(flags u32, count u32) &RegexProgram {
	return &RegexProgram{
		register_count: count
		unicode:        flags & 1 != 0
		ignore_case:    flags & 2 != 0
		multiline:      flags & 4 != 0
		unicode_sets:   flags & 8 != 0
		dot_all:        flags & 16 != 0
	}
}

fn regex_state_fixture_transcript(flags u32, input RegexInput, count u32, initial int, start uint, sequence string) string {
	program := regex_state_fixture_program(flags, count)
	mut scratch := RegexVmScratch.new()
	scratch.registers = []i32{len: initial, init: 99}
	scratch.register_pool << i32(9)
	scratch.modifier_stack << RegexActiveModifiers{
		multiline: true
	}
	scratch.backtrack_stack << RegexSavedNormal{
		pc:                 9
		modifiers:          scratch.modifier_stack[0]
		modifier_stack_len: 1
	}
	mut vm := RegexVm.new(program, input, start, mut scratch)
	mut output := [regex_state_fixture_text(vm)]
	for operation in sequence.split(';') {
		f := operation.split(',')
		n := fn [f] (index int) u64 {
			return regex_state_fixture_number(f, index)
		}
		match f[0] {
			'v' {
				scratch.registers[int(n(1))] = regex_state_fixture_signed(f[2])
			}
			's' {
				vm.snapshot_registers()
			}
			'o' {
				vm.restore_registers(uint(n(1)))
			}
			'n' {
				vm.push_backtrack(u32(n(1)), uint(n(2)))
			}
			'm' {
				vm.push_backtrack_modified(u32(n(1)), uint(n(2)), uint(n(3)),
					regex_state_fixture_signed(f[4]))
			}
			'g' {
				vm.push_greedy_backtrack(u32(n(1)), uint(n(2)), uint(n(3)), u32(n(4)))
			}
			'l' {
				vm.push_lazy_backtrack(u32(n(1)), uint(n(2)), regex_state_fixture_max(f[3]),
					u32(n(4)))
			}
			'p' {
				vm.handle_push_modifiers(regex_state_fixture_bool(f[1]),
					regex_state_fixture_bool(f[2]), regex_state_fixture_bool(f[3]))
			}
			'q' {
				vm.handle_pop_modifiers()
			}
			'd' {
				vm.backward = n(1) != 0
				vm.steps = n(2)
				vm.bt_floor = uint(n(3))
			}
			'c' {
				vm.pc = u32(n(1))
				vm.pos = uint(n(2))
			}
			'z' {
				vm.reset(uint(n(1)))
			}
			'r' {
				vm.handle_repeat_start(u32(n(1)))
			}
			't' {
				vm.handle_repeat_check(u32(n(1)), u32(n(2)), regex_state_fixture_max(f[3]),
					u32(n(4)), n(5) != 0)
			}
			else {
				panic(operation)
			}
		}

		output << regex_state_fixture_text(vm)
	}
	return output.join('~')
}

fn regex_state_fixture_optional(value ?uint) string {
	return if position := value { position.str() } else { '-' }
}

fn regex_state_fixture_walk(input RegexInput, unicode bool, pos uint, count u32) string {
	program := &RegexProgram{
		unicode: unicode
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, input, pos, mut scratch)
	forward := if point := vm.current_code_point() { point.str() } else { '-' }
	vm.advance_char()
	next := vm.pos
	vm.pos = pos
	vm.backward = true
	backward := if point := vm.current_code_point() { point.str() } else { '-' }
	vm.advance_char()
	previous := vm.pos
	return '${forward}|${backward}|${next}|${previous}|${vm.retreat_one_char(pos)}|${vm.advance_one_char(pos)}|${regex_state_fixture_optional(vm.retreat_n_chars(pos,
		count))}|${regex_state_fixture_optional(vm.advance_n_chars(pos, count))}'
}

fn regex_state_fixture_suffix(instructions string, start uint, matcher u32) string {
	mut program := &RegexProgram{}
	if instructions != '-' {
		for text in instructions.split(';') {
			f := text.split(',')
			if f[0] == 'n' {
				program.instructions << RegexNop{}
				continue
			}
			atom := regex_state_fixture_matcher(u32(regex_state_fixture_number(f, 1)))
			minimum := u32(regex_state_fixture_number(f, 2))
			maximum := regex_state_fixture_max(f[3])
			if f[0] == 'g' {
				program.instructions << RegexGreedyLoop{
					matcher: atom
					min:     minimum
					max:     maximum
				}
			} else if f[0] == 'G' {
				program.instructions << RegexLazyLoop{
					matcher: atom
					min:     minimum
					max:     maximum
				}
			} else {
				panic(text)
			}
		}
	}
	mut scratch := RegexVmScratch.new()
	vm := RegexVm.new(program, RegexUtf16Input{}, 0, mut scratch)
	return if value := vm.same_matcher_loop_suffix_min(start, regex_state_fixture_matcher(matcher)) {
		value.str()
	} else {
		'-'
	}
}

fn test_regex_vm_state_and_traversal_match_current_upstream_rust_exactly() {
	corpus := $embed_file('testdata/regex-state.tsv').to_string()
	mut count := 0
	for row in corpus.split_into_lines() {
		if row.len == 0 || row.starts_with('#') { continue
		 }
		f := row.split('\t')
		assert f.len == 8, row
		a := regex_state_fixture_number(f, 3)
		b := regex_state_fixture_number(f, 4)
		c := regex_state_fixture_number(f, 5)
		mut actual := ''
		match f[0] {
			'state' {
				actual = regex_state_fixture_transcript(u32(f[1].parse_uint(10, 32)!), RegexUtf16Input{
					units: regex_state_fixture_units(f[2])!
				}, u32(a), int(b), uint(c), f[6])
			}
			'walk' {
				units := regex_state_fixture_units(f[2])!
				input := if f[1] == 'u8' { RegexInput(RegexAsciiInput{
						bytes: units.map(u8(it))
					}) } else { RegexInput(RegexUtf16Input{
						units: units
					}) }
				actual = regex_state_fixture_walk(input, a != 0, uint(b), u32(c))
			}
			'steps' {
				program := &RegexProgram{}
				mut scratch := RegexVmScratch.new()
				vm := RegexVm.new(program, RegexUtf16Input{}, 0, mut scratch)
				actual = regex_state_fixture_optional(vm.retreat_n_chars(uint(b), u32(c))) + '|' +
					regex_state_fixture_optional(vm.advance_n_chars(uint(b), u32(c)))
			}
			'suffix' {
				actual = regex_state_fixture_suffix(f[6], uint(b), u32(c))
			}
			else {
				panic(row)
			}
		}

		assert actual == f[7], row
		count++
	}
	assert count == 14942
}

fn regex_state_fixture_units(text string) ![]u16 {
	mut units := []u16{}
	if text != '-' {
		assert text.len % 4 == 0
		for offset := 0; offset < text.len; offset += 4 {
			units << u16(text[offset..offset + 4].parse_uint(16, 16)!)
		}
	}
	return units
}

fn regex_state_fixture_hex(units []u16) string {
	if units.len == 0 { return '-' }
	return units.map('${it:04x}').join('')
}

fn regex_state_fixture_property() RegexUnicodePropertyData {
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

fn regex_state_fixture_matcher(index u32) RegexSimpleMatch {
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
			RegexSimpleMatch(regex_state_fixture_property())
		}
		8 {
			RegexSimpleMatch(RegexSimpleUnion{
				left:  box_regex_simple_match(regex_state_fixture_matcher(4))
				right: box_regex_simple_match(RegexSimpleUnion{
					left:  box_regex_simple_match(regex_state_fixture_matcher(2))
					right: box_regex_simple_match(regex_state_fixture_matcher(7))
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
